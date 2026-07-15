create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('comment_on_record', 'reply_to_comment')),
  battle_id uuid not null references public.battles(id) on delete cascade,
  record_id uuid not null references public.battle_records(id) on delete cascade,
  comment_id uuid not null references public.battle_record_comments(id) on delete cascade,
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_battle_created_at_idx
on public.notifications (user_id, battle_id, created_at desc);

create index if not exists notifications_user_unread_idx
on public.notifications (user_id, created_at desc)
where read_at is null;

alter table public.notifications enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'Users can read own notifications'
  ) then
    create policy "Users can read own notifications"
    on public.notifications
    for select
    to authenticated
    using (user_id = auth.uid());
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'Users can update own notifications'
  ) then
    create policy "Users can update own notifications"
    on public.notifications
    for update
    to authenticated
    using (user_id = auth.uid())
    with check (user_id = auth.uid());
  end if;
end;
$$;

create or replace function public.create_battle_comment_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_user_id uuid;
  target_battle_id uuid;
  notification_type text;
begin
  select br.battle_id, br.user_id
    into target_battle_id, target_user_id
  from public.battle_records br
  where br.id = new.record_id;

  if target_battle_id is null then
    return new;
  end if;

  if new.parent_comment_id is null then
    notification_type := 'comment_on_record';
  else
    select c.user_id
      into target_user_id
    from public.battle_record_comments c
    where c.id = new.parent_comment_id
      and c.record_id = new.record_id;

    notification_type := 'reply_to_comment';
  end if;

  if target_user_id is null or target_user_id = new.user_id then
    return new;
  end if;

  insert into public.notifications (
    user_id,
    type,
    battle_id,
    record_id,
    comment_id,
    actor_user_id
  ) values (
    target_user_id,
    notification_type,
    target_battle_id,
    new.record_id,
    new.id,
    new.user_id
  );

  return new;
end;
$$;

drop trigger if exists create_battle_comment_notification_trigger
on public.battle_record_comments;

create trigger create_battle_comment_notification_trigger
after insert on public.battle_record_comments
for each row
execute function public.create_battle_comment_notification();

notify pgrst, 'reload schema';
