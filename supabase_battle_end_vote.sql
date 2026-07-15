alter table public.battles
add column if not exists force_ended_at timestamptz;

create table if not exists public.battle_end_proposals (
  id uuid primary key default gen_random_uuid(),
  battle_id uuid not null references public.battles(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  reason text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  threshold_ratio numeric not null default 0.7,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create unique index if not exists battle_end_proposals_one_pending_idx
on public.battle_end_proposals (battle_id)
where status = 'pending';

create index if not exists battle_end_proposals_battle_created_at_idx
on public.battle_end_proposals (battle_id, created_at desc);

create table if not exists public.battle_end_votes (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.battle_end_proposals(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  vote text not null check (vote in ('continue', 'end')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (proposal_id, user_id)
);

create index if not exists battle_end_votes_proposal_idx
on public.battle_end_votes (proposal_id);

alter table public.battle_end_proposals enable row level security;
alter table public.battle_end_votes enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'battle_end_proposals'
      and policyname = 'Participants can read battle end proposals'
  ) then
    create policy "Participants can read battle end proposals"
    on public.battle_end_proposals
    for select
    to authenticated
    using (
      exists (
        select 1
        from public.battle_participants bp
        where bp.battle_id = battle_end_proposals.battle_id
          and bp.user_id = auth.uid()
      )
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'battle_end_votes'
      and policyname = 'Participants can read battle end votes'
  ) then
    create policy "Participants can read battle end votes"
    on public.battle_end_votes
    for select
    to authenticated
    using (
      exists (
        select 1
        from public.battle_end_proposals bep
        join public.battle_participants bp on bp.battle_id = bep.battle_id
        where bep.id = battle_end_votes.proposal_id
          and bp.user_id = auth.uid()
      )
    );
  end if;
end;
$$;

create or replace function public.create_battle_end_proposal(
  battle_id_arg uuid,
  reason_arg text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_created_by uuid;
  proposal_id uuid;
begin
  select created_by
    into target_created_by
  from public.battles
  where id = battle_id_arg;

  if target_created_by is null then
    raise exception 'battle not found';
  end if;

  if target_created_by <> auth.uid() then
    raise exception 'only host can create end proposal';
  end if;

  if exists (
    select 1
    from public.battles
    where id = battle_id_arg
      and force_ended_at is not null
  ) then
    raise exception 'battle already ended';
  end if;

  insert into public.battle_end_proposals (
    battle_id,
    created_by,
    reason
  ) values (
    battle_id_arg,
    auth.uid(),
    nullif(trim(reason_arg), '')
  )
  returning id into proposal_id;

  return proposal_id;
end;
$$;

grant execute on function public.create_battle_end_proposal(uuid, text)
to authenticated;

create or replace function public.vote_battle_end_proposal(
  proposal_id_arg uuid,
  vote_arg text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_battle_id uuid;
  target_status text;
  target_threshold numeric;
  participant_count integer;
  end_count integer;
  continue_count integer;
begin
  if vote_arg not in ('continue', 'end') then
    raise exception 'invalid vote';
  end if;

  select battle_id, status, threshold_ratio
    into target_battle_id, target_status, target_threshold
  from public.battle_end_proposals
  where id = proposal_id_arg;

  if target_battle_id is null then
    raise exception 'proposal not found';
  end if;

  if target_status <> 'pending' then
    raise exception 'proposal already resolved';
  end if;

  if not exists (
    select 1
    from public.battle_participants
    where battle_id = target_battle_id
      and user_id = auth.uid()
  ) then
    raise exception 'only participants can vote';
  end if;

  insert into public.battle_end_votes (
    proposal_id,
    user_id,
    vote,
    updated_at
  ) values (
    proposal_id_arg,
    auth.uid(),
    vote_arg,
    now()
  )
  on conflict (proposal_id, user_id)
  do update set
    vote = excluded.vote,
    updated_at = now();

  select count(*)
    into participant_count
  from public.battle_participants
  where battle_id = target_battle_id;

  select count(*)
    into end_count
  from public.battle_end_votes
  where proposal_id = proposal_id_arg
    and vote = 'end';

  select count(*)
    into continue_count
  from public.battle_end_votes
  where proposal_id = proposal_id_arg
    and vote = 'continue';

  if participant_count > 0 and end_count >= ceil(participant_count * target_threshold) then
    update public.battle_end_proposals
    set status = 'approved',
        resolved_at = now()
    where id = proposal_id_arg;

    update public.battles
    set force_ended_at = now()
    where id = target_battle_id
      and force_ended_at is null;
  elsif participant_count > 0 and continue_count >= ceil(participant_count * target_threshold) then
    update public.battle_end_proposals
    set status = 'rejected',
        resolved_at = now()
    where id = proposal_id_arg;
  end if;
end;
$$;

grant execute on function public.vote_battle_end_proposal(uuid, text)
to authenticated;

notify pgrst, 'reload schema';
