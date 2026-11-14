-- The signed-in person has finished changing a temporary password
create or replace function public.finish_password_change()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in before changing your password.';
  end if;

  update public.accounts
  set must_change_password = false
  where id = auth.uid();
end
$$;

revoke execute on function public.finish_password_change() from public, anon;
grant execute on function public.finish_password_change() to authenticated;