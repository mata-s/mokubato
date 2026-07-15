create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists push_tokens_user_id_idx
on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'push_tokens'
      and policyname = 'Users can read own push tokens'
  ) then
    create policy "Users can read own push tokens"
    on public.push_tokens
    for select
    to authenticated
    using (user_id = auth.uid());
  end if;
end;
$$;

create or replace function public.upsert_push_token(
  token_arg text,
  platform_arg text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  delete from public.push_tokens
  where token = token_arg;

  insert into public.push_tokens (
    user_id,
    token,
    platform,
    updated_at
  ) values (
    auth.uid(),
    token_arg,
    platform_arg,
    now()
  );
end;
$$;

grant execute on function public.upsert_push_token(text, text) to authenticated;

notify pgrst, 'reload schema';
