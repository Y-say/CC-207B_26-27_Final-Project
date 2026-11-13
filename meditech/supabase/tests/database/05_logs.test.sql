begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- Check that both log tables exist
select has_table('public', 'audit_records', 'audit_records table exists');
select has_table('public', 'activity_log', 'activity_log table exists');

-- Create a sample pharmacy
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Demo Pharmacy', 'La Paz Branch',
   '12 Rizal St, La Paz, Iloilo City', '0333201234', 'demo@test.com',
   10.7202, 122.5621, 'LTO-0000-0001', '2028-12-31');

-- Writing a platform event works
select public.log_audit(null, 'Unknown', null, 'failed_sign_in',
  'Wrong password', 'Admin portal');
select is((select count(*) from public.audit_records), 1::bigint,
  'platform event is saved');

-- Writing a pharmacy event works
select public.log_activity('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', null, 'Maria Santos',
  'owner', 'Updated stock', 'inventory_item', 'INV-000001');
select is((select count(*) from public.activity_log), 1::bigint,
  'pharmacy event is saved');

-- Platform events can't be edited or deleted
select throws_ok($$ update public.audit_records set action = 'Changed' $$,
  'P0001', null, 'editing a platform event is blocked');
select throws_ok($$ delete from public.audit_records $$,
  'P0001', null, 'deleting a platform event is blocked');

-- Pharmacy events can't be edited or deleted
select throws_ok($$ update public.activity_log set action = 'Changed' $$,
  'P0001', null, 'editing a pharmacy event is blocked');
select throws_ok($$ delete from public.activity_log $$,
  'P0001', null, 'deleting a pharmacy event is blocked');

-- The app can't write logs directly
select ok(not has_function_privilege('anon',
  'public.log_audit(uuid, text, text, public.audit_event_type, text, text, jsonb)', 'execute'),
  'guests cannot write platform events');
select ok(not has_function_privilege('authenticated',
  'public.log_activity(uuid, uuid, text, text, text, text, text, jsonb)', 'execute'),
  'signed-in users cannot write pharmacy events');

-- Undo all test data
select * from finish();
rollback;