begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

-- A customer with a mobile number, and a staff member with a username
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'juan@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'jreyes@staff.test');
insert into public.accounts (id, account_type, username) values
  ('11111111-1111-1111-1111-111111111111', 'customer', null),
  ('22222222-2222-2222-2222-222222222222', 'staff', 'jreyes');
insert into public.customer_profiles
  (account_id, first_name, last_name, mobile, email, birthdate, consent_version)
values ('11111111-1111-1111-1111-111111111111', 'Juan', 'Dela Cruz',
        '09171234567', 'juan@test.com', '2000-01-01', 'v1');

-- Accounts can be found by email, mobile number, or username
select is((select account_id from public.find_account_for_sign_in('JUAN@test.com')),
  '11111111-1111-1111-1111-111111111111'::uuid, 'found by email, any capitals');
select is((select account_id from public.find_account_for_sign_in('09171234567')),
  '11111111-1111-1111-1111-111111111111'::uuid, 'found by mobile number');
select is((select account_id from public.find_account_for_sign_in('JReyes')),
  '22222222-2222-2222-2222-222222222222'::uuid, 'found by username, any capitals');
select is((select count(*) from public.find_account_for_sign_in('nobody')),
  0::bigint, 'unknown account finds nothing');

-- Four wrong passwords: not locked yet
select public.record_failed_sign_in('11111111-1111-1111-1111-111111111111', 'Juan', 'juan@test.com', 'Customer app');
select public.record_failed_sign_in('11111111-1111-1111-1111-111111111111', 'Juan', 'juan@test.com', 'Customer app');
select public.record_failed_sign_in('11111111-1111-1111-1111-111111111111', 'Juan', 'juan@test.com', 'Customer app');
select is(public.record_failed_sign_in('11111111-1111-1111-1111-111111111111', 'Juan', 'juan@test.com', 'Customer app'),
  null, 'fourth wrong password does not lock');

-- The fifth one locks the account
select isnt(public.record_failed_sign_in('11111111-1111-1111-1111-111111111111', 'Juan', 'juan@test.com', 'Customer app'),
  null, 'fifth wrong password locks the account');

-- Every failed try is recorded for admins
select is((select count(*) from public.audit_records where event_type = 'failed_sign_in'),
  5::bigint, 'all five failed tries are recorded');

-- A successful sign-in clears the failed tries
select public.record_successful_sign_in('11111111-1111-1111-1111-111111111111', 'Juan', 'Customer app');
select is((select count(*) from public.auth_attempts), 0::bigint, 'successful sign-in clears failed tries');

-- The app can't look up accounts directly
select ok(not has_function_privilege('anon', 'public.find_account_for_sign_in(text)', 'execute'),
  'guests cannot look up accounts');

-- Undo all test data
select * from finish();
rollback;