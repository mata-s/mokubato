create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_user_id uuid;
begin
  target_user_id := auth.uid();

  if target_user_id is null then
    raise exception 'not authenticated';
  end if;

  delete from auth.users
  where id = target_user_id;
end;
$$;

grant execute on function public.delete_own_account() to authenticated;

notify pgrst, 'reload schema';
