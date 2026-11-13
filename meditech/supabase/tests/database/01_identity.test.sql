begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

-- Check that all tables exist
select has_table('public', 'accounts', 'accounts table exists');
select has_table('public', 'customer_profiles', 'customer_profiles table exists');
select has_table('public', 'admins', 'admins table exists');
select has_table('public', 'auth_attempts', 'auth_attempts table exists');

-- Create two sample users
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.com');
insert into public.accounts (id, account_type) values
  ('11111111-1111-1111-1111-111111111111', 'customer'),
  ('22222222-2222-2222-2222-222222222222', 'customer');
insert into public.customer_profiles
  (account_id, first_name, last_name, mobile, email, birthdate, consent_version)
values
  ('11111111-1111-1111-1111-111111111111', 'Juan', 'Dela Cruz',
   '09171234567', 'a@test.com', '2000-01-01', 'v1');

-- The same mobile number cannot be used twice
select throws_ok(
  $$ insert into public.customer_profiles
       (account_id, first_name, last_name, mobile, email, birthdate, consent_version)
     values ('22222222-2222-2222-2222-222222222222', 'Ana', 'Reyes',
             '09171234567', 'b@test.com', '2000-01-01', 'v1') $$,
  '23505', null, 'duplicate mobile number is rejected');

-- Mobile numbers must follow the 09XXXXXXXXX format
select throws_ok(
  $$ insert into public.customer_profiles
       (account_id, first_name, last_name, mobile, email, birthdate, consent_version)
     values ('22222222-2222-2222-2222-222222222222', 'Ana', 'Reyes',
             '12345', 'b@test.com', '2000-01-01', 'v1') $$,
  '23514', null, 'badly formatted mobile number is rejected');

-- Undo all test data
select * from finish();
rollback;