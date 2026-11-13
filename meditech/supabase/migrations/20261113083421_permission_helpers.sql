-- The signed-in user's account type (customer, staff, or admin)
create or replace function public.my_account_type()
returns public.account_type
language sql stable security definer
set search_path = ''
as $$
  select account_type from public.accounts where id = auth.uid()
$$;

-- The pharmacy branch the signed-in staff member works at
create or replace function public.my_branch_id()
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select branch_id from public.staff_members
  where account_id = auth.uid() and is_active
$$;

-- The signed-in staff member's role (owner, pharmacist, or staff)
create or replace function public.my_staff_role()
returns public.staff_role
language sql stable security definer
set search_path = ''
as $$
  select role from public.staff_members
  where account_id = auth.uid() and is_active
$$;

-- Is the signed-in user an active administrator?
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admins
    where account_id = auth.uid() and is_active
  )
$$;

-- Does the signed-in user have a verified, unexpired pharmacist license?
create or replace function public.has_valid_license()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.staff_members
    where account_id = auth.uid()
      and is_active
      and license_status = 'verified'
      and prc_license_expiry >= public.app_today()
  )
$$;

-- Runs every time someone signs in: adds their role details to their login,
-- and refuses deactivated or temporarily locked accounts
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  uid uuid := (event->>'user_id')::uuid;
  claims jsonb := coalesce(event->'claims', '{}'::jsonb);
  acc record;
  staff record;
begin
  select account_type, state into acc from public.accounts where id = uid;

  -- Deactivated accounts can't sign in
  if acc.state = 'deactivated' then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 403, 'message', 'This account has been deactivated.'));
  end if;

  -- Locked accounts wait 15 minutes
  if exists (select 1 from public.auth_attempts
             where account_id = uid and locked_until > now()) then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 429, 'message', 'Too many wrong passwords. Try again in 15 minutes.'));
  end if;

  select branch_id, role into staff from public.staff_members
  where account_id = uid and is_active;

  -- Add role details so the app knows where to send the user
  claims := claims
    || jsonb_build_object('app_account_type', acc.account_type)
    || jsonb_build_object('app_state', acc.state)
    || jsonb_build_object('app_role', staff.role)
    || jsonb_build_object('app_branch_id', staff.branch_id);

  return jsonb_set(event, '{claims}', claims);
end
$$;

-- Only the sign-in system may run the login hook
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook(jsonb) from public, anon, authenticated;