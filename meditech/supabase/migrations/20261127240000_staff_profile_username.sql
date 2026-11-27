-- Staff may update their sign-in username when editing profile.

drop function if exists public.update_my_staff_profile(text, text, text);

create or replace function public.update_my_staff_profile(
  p_first_name text,
  p_middle_name text,
  p_last_name text,
  p_username text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_middle text := nullif(trim(p_middle_name), '');
  v_username text := nullif(trim(p_username), '');
begin
  if auth.uid() is null or public.my_account_type() <> 'staff' then
    raise exception 'Sign in as pharmacy staff to edit your profile';
  end if;

  if p_first_name is null or p_first_name !~ '^[A-Za-zÑñ .''-]{2,50}$' then
    raise exception 'First name: 2 to 50 letters';
  end if;
  if p_last_name is null or p_last_name !~ '^[A-Za-zÑñ .''-]{2,50}$' then
    raise exception 'Last name: 2 to 50 letters';
  end if;
  if v_middle is not null and v_middle !~ '^[A-Za-zÑñ .''-]{2,50}$' then
    raise exception 'Middle name: 2 to 50 letters';
  end if;

  if v_username is not null then
    if v_username !~ '^[A-Za-z0-9_]{4,20}$' then
      raise exception 'Username: 4 to 20 letters, numbers, or underscores';
    end if;
    update public.accounts
    set username = v_username
    where id = auth.uid();
    if not found then
      raise exception 'Profile not found';
    end if;
  end if;

  update public.staff_members
  set first_name = trim(p_first_name),
      middle_name = v_middle,
      last_name = trim(p_last_name)
  where account_id = auth.uid();

  if not found then
    raise exception 'Profile not found';
  end if;
end;
$$;

revoke execute on function public.update_my_staff_profile(text, text, text, text) from public, anon;
grant execute on function public.update_my_staff_profile(text, text, text, text) to authenticated;