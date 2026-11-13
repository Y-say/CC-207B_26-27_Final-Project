begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- Create a sample pharmacy
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Demo Pharmacy', 'La Paz Branch',
   '12 Rizal St, La Paz, Iloilo City', '0333201234', 'demo@test.com',
   10.7202, 122.5621, 'LTO-0000-0001', '2028-12-31', 'active');

-- Create sample users: valid pharmacist, expired pharmacist, staff,
-- admin, customer, deactivated staff, and a locked customer
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'valid@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'expired@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'staff@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'admin@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'customer@test.com'),
  ('66666666-6666-6666-6666-666666666666', 'gone@test.com'),
  ('77777777-7777-7777-7777-777777777777', 'locked@test.com');
insert into public.accounts (id, account_type, state) values
  ('11111111-1111-1111-1111-111111111111', 'staff', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'staff', 'active'),
  ('33333333-3333-3333-3333-333333333333', 'staff', 'active'),
  ('44444444-4444-4444-4444-444444444444', 'admin', 'active'),
  ('55555555-5555-5555-5555-555555555555', 'customer', 'active'),
  ('66666666-6666-6666-6666-666666666666', 'staff', 'deactivated'),
  ('77777777-7777-7777-7777-777777777777', 'customer', 'active');
insert into public.staff_members
  (account_id, branch_id, role, first_name, last_name,
   prc_license_no, prc_license_expiry, license_status)
values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'pharmacist', 'Jose', 'Reyes', '0123456', '2030-12-31', 'verified'),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'pharmacist', 'Rina', 'Cruz', '0345678', '2020-01-01', 'verified'),
  ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'staff', 'Ana', 'Lim', null, null, 'none');
insert into public.admins (account_id, display_name)
values ('44444444-4444-4444-4444-444444444444', 'Paolo Reyes');
insert into public.auth_attempts (account_id, failed_count, locked_until)
values ('77777777-7777-7777-7777-777777777777', 5, now() + interval '15 minutes');

-- The login hook adds the pharmacist's role
select is(
  public.custom_access_token_hook(jsonb_build_object(
    'user_id', '11111111-1111-1111-1111-111111111111', 'claims', '{}'::jsonb))
    -> 'claims' ->> 'app_role',
  'pharmacist', 'login includes the pharmacist role');

-- The login hook refuses deactivated and locked accounts
select ok(
  public.custom_access_token_hook(jsonb_build_object(
    'user_id', '66666666-6666-6666-6666-666666666666', 'claims', '{}'::jsonb)) ? 'error',
  'deactivated account cannot sign in');
select ok(
  public.custom_access_token_hook(jsonb_build_object(
    'user_id', '77777777-7777-7777-7777-777777777777', 'claims', '{}'::jsonb)) ? 'error',
  'locked account cannot sign in');

-- Act as a signed-in app user from here on
set local role authenticated;

-- Valid pharmacist
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
select is(public.my_branch_id(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'pharmacist belongs to the demo branch');
select is(public.my_staff_role(), 'pharmacist'::public.staff_role,
  'pharmacist role is detected');
select ok(public.has_valid_license(), 'valid license is accepted');

-- Pharmacist whose license expired
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', true);
select ok(not public.has_valid_license(), 'expired license is refused');

-- Staff with no license
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', true);
select ok(not public.has_valid_license(), 'staff without a license is refused');

-- Admin and customer
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444"}', true);
select ok(public.is_admin(), 'admin is detected');
select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555"}', true);
select ok(not public.is_admin(), 'customer is not an admin');

-- Undo all test data
select * from finish();
rollback;