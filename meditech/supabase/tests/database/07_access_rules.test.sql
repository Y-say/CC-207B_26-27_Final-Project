begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

-- Every table must have access rules turned on
select is(
  (select count(*) from pg_tables where schemaname = 'public' and not rowsecurity),
  0::bigint, 'every table has access rules turned on');

-- Two approved pharmacies: X and Y
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Pharmacy X', 'Main', 'Iloilo City',
   '0333201234', 'x@test.com', 10.72, 122.56, 'LTO-X', '2028-12-31', 'active'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Pharmacy Y', 'Main', 'Iloilo City',
   '0333201235', 'y@test.com', 10.73, 122.57, 'LTO-Y', '2028-12-31', 'active');

-- Users: pharmacist at X, staff at Y, owner at X, customers A and B, admin
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'pharma.x@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'staff.y@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'owner.x@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'cust.a@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'cust.b@test.com'),
  ('66666666-6666-6666-6666-666666666666', 'admin@test.com');
insert into public.accounts (id, account_type) values
  ('11111111-1111-1111-1111-111111111111', 'staff'),
  ('22222222-2222-2222-2222-222222222222', 'staff'),
  ('33333333-3333-3333-3333-333333333333', 'staff'),
  ('44444444-4444-4444-4444-444444444444', 'customer'),
  ('55555555-5555-5555-5555-555555555555', 'customer'),
  ('66666666-6666-6666-6666-666666666666', 'admin');
insert into public.staff_members
  (account_id, branch_id, role, first_name, last_name, prc_license_no)
values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'pharmacist', 'Jose', 'Reyes', '0123456'),
  ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'staff', 'Ana', 'Lim', null),
  ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'owner', 'Maria', 'Santos', null);
insert into public.admins (account_id, display_name)
values ('66666666-6666-6666-6666-666666666666', 'Paolo Reyes');

-- A medicine stocked at both pharmacies
insert into public.medicines
  (id, brand_name, generic_name, strength, dosage_form_id, unit_sold_id, status)
values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Biogesic', 'Paracetamol', '500 mg',
   (select id from public.dosage_forms where name = 'Tablet'),
   (select id from public.units where name = 'tablet'), 'active');
insert into public.inventory_items (branch_id, medicine_id, stock_quantity, price_per_unit)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 240, 4.50),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 100, 4.75);

-- Customer A's reservation at Pharmacy X, with a pickup code and a notification
insert into public.reservations
  (id, reference_no, customer_id, branch_id, total_amount, expires_at, idempotency_key)
values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'RM-111326-0001',
   '44444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   45.00, now() + interval '7 days', gen_random_uuid());
insert into public.pickup_codes (reservation_id, code_suffix)
values ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'K7M4');
insert into public.notifications (id, recipient_id, type, title, body)
values ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '44444444-4444-4444-4444-444444444444',
        'confirmed', 'Reservation confirmed', 'Your pickup code is ready.');

-- One log entry of each kind
select public.log_activity('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', null, 'Jose Reyes',
  'pharmacist', 'Updated stock', 'inventory_item', 'INV-000001');
select public.log_audit(null, 'Unknown', null, 'failed_sign_in', 'Wrong password', 'Admin portal');

-- Customer A sees only their own things
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444"}', true);
select is((select count(*) from public.reservations), 1::bigint, 'customer sees own reservation');
select is((select count(*) from public.pickup_codes), 1::bigint, 'customer sees own pickup code');
select is((select count(*) from public.inventory_items), 0::bigint, 'customer cannot read inventory');

-- Customer A can mark a notification read, but cannot change its text
select lives_ok(
  $$ update public.notifications set read_at = now()
     where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' $$,
  'customer can mark own notification as read');
select throws_ok(
  $$ update public.notifications set title = 'Changed'
     where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' $$,
  '42501', null, 'customer cannot change notification text');

-- Customer B sees nothing of customer A's
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555"}', true);
select is((select count(*) from public.reservations), 0::bigint, 'other customer sees no reservations');
select is((select count(*) from public.pickup_codes), 0::bigint, 'other customer sees no pickup codes');
select is((select count(*) from public.notifications), 0::bigint, 'other customer sees no notifications');

-- Pharmacist at X sees X only, and never the pickup code
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
select is((select count(*) from public.reservations), 1::bigint, 'pharmacist sees own branch reservation');
select is((select count(*) from public.pickup_codes), 0::bigint, 'pharmacist cannot see pickup codes');
select is((select count(*) from public.inventory_items), 1::bigint, 'pharmacist sees only own branch inventory');
select is((select count(*) from public.activity_log), 0::bigint, 'pharmacist cannot see the activity log');

-- Owner at X sees the activity log
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', true);
select is((select count(*) from public.activity_log), 1::bigint, 'owner sees the activity log');

-- Staff at Y sees Y only
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', true);
select is((select count(*) from public.reservations), 0::bigint, 'other branch sees no reservations');
select is((select count(*) from public.inventory_items), 1::bigint, 'other branch sees only its own inventory');

-- Admin sees platform data, never pharmacy operations
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"66666666-6666-6666-6666-666666666666"}', true);
select is((select count(*) from public.reservations), 0::bigint, 'admin cannot see reservations');
select is((select count(*) from public.inventory_items), 0::bigint, 'admin cannot see inventory');
select is((select count(*) from public.audit_records), 1::bigint, 'admin sees audit records');
select is((select count(*) from public.branches), 2::bigint, 'admin sees all branches');

-- Guests see only the public views
reset role;
set local role anon;
select set_config('request.jwt.claims', '', true);
select is((select count(*) from public.branches), 0::bigint, 'guest cannot read the branches table');
select is((select count(*) from public.public_branches), 2::bigint, 'guest sees approved pharmacies');
select is((select count(*) from public.public_availability), 2::bigint, 'guest sees medicine availability');

-- Undo all test data
reset role;
select * from finish();
rollback;