begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

-- Check that all tables exist
select has_table('public', 'branches', 'branches table exists');
select has_table('public', 'branch_hours', 'branch_hours table exists');
select has_table('public', 'staff_members', 'staff_members table exists');

-- Create a sample pharmacy
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Demo Pharmacy', 'La Paz Branch',
   '12 Rizal St, La Paz, Iloilo City', '0333201234', 'demo@test.com',
   10.7202, 122.5621, 'LTO-0000-0001', '2028-12-31');

-- Create three sample staff logins
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner1@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'owner2@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'pharma@test.com');
insert into public.accounts (id, account_type) values
  ('11111111-1111-1111-1111-111111111111', 'staff'),
  ('22222222-2222-2222-2222-222222222222', 'staff'),
  ('33333333-3333-3333-3333-333333333333', 'staff');

-- Add the first owner
insert into public.staff_members (account_id, branch_id, role, first_name, last_name)
values ('11111111-1111-1111-1111-111111111111',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'owner', 'Maria', 'Santos');

-- The same LTO number cannot be used twice
select throws_ok(
  $$ insert into public.branches
       (pharmacy_name, branch_name, address, contact_number, email,
        latitude, longitude, lto_number, lto_expiry)
     values ('Copy Pharmacy', 'Main', 'Somewhere', '0333201235', 'copy@test.com',
             10.7, 122.5, 'LTO-0000-0001', '2028-12-31') $$,
  '23505', null, 'duplicate LTO number is rejected');

-- A branch cannot have two owners
select throws_ok(
  $$ insert into public.staff_members (account_id, branch_id, role, first_name, last_name)
     values ('22222222-2222-2222-2222-222222222222',
             'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'owner', 'Pedro', 'Cruz') $$,
  '23505', null, 'second owner for the same branch is rejected');

-- A pharmacist must have a license number
select throws_ok(
  $$ insert into public.staff_members (account_id, branch_id, role, first_name, last_name)
     values ('33333333-3333-3333-3333-333333333333',
             'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'pharmacist', 'Jose', 'Reyes') $$,
  '23514', null, 'pharmacist without a license number is rejected');

-- Weekdays only go from 0 to 6
select throws_ok(
  $$ insert into public.branch_hours (branch_id, weekday, opens_at, closes_at)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 7, '08:00', '20:00') $$,
  '23514', null, 'invalid weekday is rejected');

-- Undo all test data
select * from finish();
rollback;