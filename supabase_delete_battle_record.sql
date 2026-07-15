create or replace function public.delete_battle_record(record_id_arg uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_battle_id uuid;
  target_user_id uuid;
  target_record_type text;
  next_value numeric;
begin
  select br.battle_id, br.user_id, b.record_type
    into target_battle_id, target_user_id, target_record_type
  from public.battle_records br
  join public.battles b on b.id = br.battle_id
  where br.id = record_id_arg;

  if target_user_id is null then
    raise exception 'record not found';
  end if;

  if target_user_id <> auth.uid() then
    raise exception 'not allowed';
  end if;

  delete from public.battle_record_likes
  where record_id = record_id_arg;

  delete from public.battle_record_comments
  where record_id = record_id_arg;

  delete from public.battle_records
  where id = record_id_arg
    and user_id = auth.uid();

  if target_record_type = 'current' then
    select coalesce(value, 0)
      into next_value
    from public.battle_records
    where battle_id = target_battle_id
      and user_id = target_user_id
    order by created_at desc
    limit 1;

    next_value := coalesce(next_value, 0);
  else
    select coalesce(sum(value), 0)
      into next_value
    from public.battle_records
    where battle_id = target_battle_id
      and user_id = target_user_id;
  end if;

  update public.battle_participants
  set current_value = next_value
  where battle_id = target_battle_id
    and user_id = target_user_id;
end;
$$;

grant execute on function public.delete_battle_record(uuid) to authenticated;

create or replace function public.update_battle_record(
  record_id_arg uuid,
  value_arg double precision,
  memo_arg text,
  image_url_arg text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_battle_id uuid;
  target_user_id uuid;
  target_record_type text;
  next_value numeric;
begin
  select br.battle_id, br.user_id, b.record_type
    into target_battle_id, target_user_id, target_record_type
  from public.battle_records br
  join public.battles b on b.id = br.battle_id
  where br.id = record_id_arg;

  if target_user_id is null then
    raise exception 'record not found';
  end if;

  if target_user_id <> auth.uid() then
    raise exception 'not allowed';
  end if;

  update public.battle_records
  set
    value = value_arg,
    memo = memo_arg,
    image_url = image_url_arg
  where id = record_id_arg
    and user_id = auth.uid();

  if target_record_type = 'current' then
    select coalesce(value, 0)
      into next_value
    from public.battle_records
    where battle_id = target_battle_id
      and user_id = target_user_id
    order by created_at desc
    limit 1;

    next_value := coalesce(next_value, 0);
  else
    select coalesce(sum(value), 0)
      into next_value
    from public.battle_records
    where battle_id = target_battle_id
      and user_id = target_user_id;
  end if;

  update public.battle_participants
  set current_value = next_value
  where battle_id = target_battle_id
    and user_id = target_user_id;
end;
$$;

grant execute on function public.update_battle_record(uuid, double precision, text, text)
to authenticated;

notify pgrst, 'reload schema';
