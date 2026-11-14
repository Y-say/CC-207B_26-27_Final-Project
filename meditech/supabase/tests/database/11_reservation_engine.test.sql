begin;
create extension if not exists pgtap with schema extensions;
select plan(42);

-- =====================================================================
-- TEST DATA SETUP
-- Create test users, a pharmacy, medicines, and inventory
-- =====================================================================

-- Customer
insert into auth.users (id, email) values
  ('a1000000-0000-0000-0000-000000000001', 'test.customer@test.com');
insert into public.accounts (id, account_type) values
  ('a1000000-0000-0000-0000-000000000001', 'customer');
insert into public.customer_profiles
  (account_id, first_name, last_name, mobile, email, birthdate, consent_version)
values
  ('a1000000-0000-0000-0000-000000000001', 'Test', 'Customer', '09990000001',
   'test.customer@test.com', '1995-01-01', 'v1');

-- Another customer (for cross-user tests)
insert into auth.users (id, email) values
  ('a1000000-0000-0000-0000-000000000002', 'other.customer@test.com');
insert into public.accounts (id, account_type) values
  ('a1000000-0000-0000-0000-000000000002', 'customer');
insert into public.customer_profiles
  (account_id, first_name, last_name, mobile, email, birthdate, consent_version)
values
  ('a1000000-0000-0000-0000-000000000002', 'Other', 'Customer', '09990000002',
   'other.customer@test.com', '1996-02-02', 'v1');

-- Pharmacy branch (active)
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status, approved_at)
values
  ('a2000000-0000-0000-0000-000000000001', 'Test Pharmacy', 'Test Branch',
   '1 Test St, Test City', '0330000001', 'test@pharmacy.com',
   10.7202, 122.5621, 'TEST-LTO-0001', '2028-12-31', 'active', now());

-- Owner (no license, for cancel tests)
insert into auth.users (id, email) values
  ('a3000000-0000-0000-0000-000000000001', 'owner@test.com');
insert into public.accounts (id, account_type) values
  ('a3000000-0000-0000-0000-000000000001', 'staff');
insert into public.staff_members
  (account_id, branch_id, role, first_name, last_name)
values
  ('a3000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001',
   'owner', 'Test', 'Owner');

-- Licensed pharmacist (verified, unexpired)
insert into auth.users (id, email) values
  ('a3000000-0000-0000-0000-000000000002', 'pharmacist@test.com');
insert into public.accounts (id, account_type) values
  ('a3000000-0000-0000-0000-000000000002', 'staff');
insert into public.staff_members
  (account_id, branch_id, role, first_name, last_name,
   prc_license_no, prc_license_expiry, license_status)
values
  ('a3000000-0000-0000-0000-000000000002', 'a2000000-0000-0000-0000-000000000001',
   'pharmacist', 'Test', 'Pharmacist', '9999999', '2030-12-31', 'verified');

-- Regular staff (no license, limited actions)
insert into auth.users (id, email) values
  ('a3000000-0000-0000-0000-000000000003', 'staff@test.com');
insert into public.accounts (id, account_type) values
  ('a3000000-0000-0000-0000-000000000003', 'staff');
insert into public.staff_members
  (account_id, branch_id, role, first_name, last_name)
values
  ('a3000000-0000-0000-0000-000000000003', 'a2000000-0000-0000-0000-000000000001',
   'staff', 'Test', 'Staff');

-- Admin (should be refused by all reservation actions)
insert into auth.users (id, email) values
  ('a4000000-0000-0000-0000-000000000001', 'admin@test.com');
insert into public.accounts (id, account_type) values
  ('a4000000-0000-0000-0000-000000000001', 'admin');
insert into public.admins (account_id, display_name)
values ('a4000000-0000-0000-0000-000000000001', 'Test Admin');

-- OTC medicine
insert into public.medicines
  (id, brand_name, generic_name, strength, dosage_form_id, unit_sold_id, is_rx, status)
values
  ('a5000000-0000-0000-0000-000000000001', 'TestMed', 'TestGeneric', '500 mg',
   (select id from public.dosage_forms where name = 'Tablet'),
   (select id from public.units where name = 'tablet'), false, 'active');

-- Rx medicine
insert into public.medicines
  (id, brand_name, generic_name, strength, dosage_form_id, unit_sold_id, is_rx, status)
values
  ('a5000000-0000-0000-0000-000000000002', 'TestRx', 'TestRxGeneric', '250 mg',
   (select id from public.dosage_forms where name = 'Capsule'),
   (select id from public.units where name = 'capsule'), true, 'active');

-- Inventory items for the test pharmacy
insert into public.inventory_items
  (id, branch_id, medicine_id, stock_quantity, price_per_unit)
values
  ('a6000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001',
   'a5000000-0000-0000-0000-000000000001', 100, 5.00),
  ('a6000000-0000-0000-0000-000000000002', 'a2000000-0000-0000-0000-000000000001',
   'a5000000-0000-0000-0000-000000000002', 50, 12.00);

-- =====================================================================
-- HELPER: switch the current user for RLS and auth.uid()
-- =====================================================================
create or replace function set_auth_user(p_user_id uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user_id::text, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end
$$;

-- helper to reset to superuser
create or replace function reset_auth()
returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end
$$;

-- =====================================================================
-- 1. SUBMIT RESERVATION TESTS
-- =====================================================================

-- Check that the functions exist
select has_function('public', 'submit_reservation', 'submit_reservation function exists');
select has_function('public', 'confirm_reservation', 'confirm_reservation function exists');
select has_function('public', 'reject_reservation', 'reject_reservation function exists');
select has_function('public', 'mark_ready', 'mark_ready function exists');
select has_function('public', 'check_pickup_code', 'check_pickup_code function exists');
select has_function('public', 'complete_reservation', 'complete_reservation function exists');
select has_function('public', 'cancel_reservation', 'cancel_reservation function exists');

-- Set up: fill the customer's cart with an OTC item
select set_auth_user('a1000000-0000-0000-0000-000000000001');
select reset_auth();

insert into public.carts (customer_id, branch_id)
values ('a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001');
insert into public.cart_items (customer_id, medicine_id, quantity)
values ('a1000000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000001', 10);

-- An admin can't submit a reservation
select set_auth_user('a4000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select * from public.submit_reservation('11111111-0000-0000-0000-000000000001', true) $$,
  null, 'Only customers can place reservations',
  'admin cannot submit a reservation');
select reset_auth();

-- A staff member can't submit a reservation
select set_auth_user('a3000000-0000-0000-0000-000000000002');
select throws_ok(
  $$ select * from public.submit_reservation('11111111-0000-0000-0000-000000000002', true) $$,
  null, 'Only customers can place reservations',
  'staff cannot submit a reservation');
select reset_auth();

-- A customer with an empty cart is refused
select set_auth_user('a1000000-0000-0000-0000-000000000002');
select throws_ok(
  $$ select * from public.submit_reservation('11111111-0000-0000-0000-000000000003', true) $$,
  null, 'Your cart is empty',
  'empty cart is rejected');
select reset_auth();

-- A customer must acknowledge to submit
select set_auth_user('a1000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select * from public.submit_reservation('11111111-0000-0000-0000-000000000004', false) $$,
  null, 'You must acknowledge the reservation terms',
  'unacknowledged submission is rejected');
select reset_auth();

-- Successful OTC submission
select set_auth_user('a1000000-0000-0000-0000-000000000001');

select lives_ok(
  $$ select * from public.submit_reservation('22222222-0000-0000-0000-000000000001', true) $$,
  'OTC reservation submits successfully');
select reset_auth();

-- Reservation was created with pending status
select is(
  (select status from public.reservations
   where idempotency_key = '22222222-0000-0000-0000-000000000001'),
  'pending'::public.reservation_status,
  'new reservation has pending status');

-- Reservation items saved with price snapshot
select is(
  (select unit_price from public.reservation_items ri
   join public.reservations r on r.id = ri.reservation_id
   where r.idempotency_key = '22222222-0000-0000-0000-000000000001'),
  5.00::numeric,
  'price was saved as a snapshot');

-- Total amount calculated correctly (10 items at 5.00 each)
select is(
  (select total_amount from public.reservations
   where idempotency_key = '22222222-0000-0000-0000-000000000001'),
  50.00::numeric,
  'total amount is correct');

-- Held quantity is 0 (stock is not held at submission)
select is(
  (select held_quantity from public.reservation_items ri
   join public.reservations r on r.id = ri.reservation_id
   where r.idempotency_key = '22222222-0000-0000-0000-000000000001'),
  0,
  'no stock is held at submission');

-- Cart was cleared after submission
select is(
  (select count(*) from public.cart_items
   where customer_id = 'a1000000-0000-0000-0000-000000000001'),
  0::bigint,
  'cart items are cleared after submission');

-- Status history was recorded
select is(
  (select to_status from public.reservation_status_history rsh
   join public.reservations r on r.id = rsh.reservation_id
   where r.idempotency_key = '22222222-0000-0000-0000-000000000001'
   limit 1),
  'pending'::public.reservation_status,
  'status history records the initial pending status');

-- Notifications were sent to staff
select ok(
  (select count(*) from public.notifications
   where type = 'new_reservation'
     and reservation_id = (select id from public.reservations
                           where idempotency_key = '22222222-0000-0000-0000-000000000001'))
  >= 1,
  'staff were notified about the new reservation');

-- Idempotency: the same key can't create a second reservation
select set_auth_user('a1000000-0000-0000-0000-000000000001');
-- Refill the cart for the retry
insert into public.carts (customer_id, branch_id)
values ('a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001');
insert into public.cart_items (customer_id, medicine_id, quantity)
values ('a1000000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000001', 5);
select throws_ok(
  $$ select * from public.submit_reservation('22222222-0000-0000-0000-000000000001', true) $$,
  '23505', null,
  'same idempotency key is rejected on second submit');
select reset_auth();

-- =====================================================================
-- 2. CONFIRM RESERVATION TESTS
-- =====================================================================

-- Get the reservation ID for the one we just created
-- (Using a savepoint approach: work with the known idempotency key)

-- Unlicensed staff can't confirm
select set_auth_user('a3000000-0000-0000-0000-000000000003');
select throws_ok(
  $$ select public.confirm_reservation(
       (select id from public.reservations
        where idempotency_key = '22222222-0000-0000-0000-000000000001')) $$,
  null, 'A verified and unexpired pharmacist license is required',
  'unlicensed staff cannot confirm');
select reset_auth();

-- Licensed pharmacist can confirm
select set_auth_user('a3000000-0000-0000-0000-000000000002');
select lives_ok(
  $$ select public.confirm_reservation(
       (select id from public.reservations
        where idempotency_key = '22222222-0000-0000-0000-000000000001')) $$,
  'licensed pharmacist confirms successfully');
select reset_auth();

-- Status changed to confirmed
select is(
  (select status from public.reservations
   where idempotency_key = '22222222-0000-0000-0000-000000000001'),
  'confirmed'::public.reservation_status,
  'reservation status is now confirmed');

-- Stock was held
select is(
  (select held_quantity from public.reservation_items ri
   join public.reservations r on r.id = ri.reservation_id
   where r.idempotency_key = '22222222-0000-0000-0000-000000000001'),
  10,
  'held quantity matches the reserved quantity');

-- Pickup code was created (4 characters, valid charset)
select ok(
  (select code_suffix ~ '^[A-HJ-NP-Z2-9]{4}$' from public.pickup_codes
   where reservation_id = (select id from public.reservations
                           where idempotency_key = '22222222-0000-0000-0000-000000000001')),
  'pickup code is 4 valid characters');

-- Customer was notified
select ok(
  (select count(*) from public.notifications
   where type = 'reservation_confirmed'
     and recipient_id = 'a1000000-0000-0000-0000-000000000001') >= 1,
  'customer was notified of confirmation');

-- Can't confirm an already-confirmed reservation
select set_auth_user('a3000000-0000-0000-0000-000000000002');
select throws_ok(
  $$ select public.confirm_reservation(
       (select id from public.reservations
        where idempotency_key = '22222222-0000-0000-0000-000000000001')) $$,
  null, 'Only pending reservations can be confirmed',
  'already confirmed reservation cannot be confirmed again');
select reset_auth();

-- =====================================================================
-- 3. REJECT RESERVATION TESTS
-- =====================================================================

-- Create a second reservation for reject testing
delete from public.carts where customer_id = 'a1000000-0000-0000-0000-000000000001';
delete from public.cart_items where customer_id = 'a1000000-0000-0000-0000-000000000001';
insert into public.carts (customer_id, branch_id)
values ('a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001');
insert into public.cart_items (customer_id, medicine_id, quantity)
values ('a1000000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000001', 2);

select set_auth_user('a1000000-0000-0000-0000-000000000001');
select * from public.submit_reservation('33333333-0000-0000-0000-000000000001', true);
select reset_auth();

-- Reason too short is rejected
select set_auth_user('a3000000-0000-0000-0000-000000000002');
select throws_ok(
  $$ select public.reject_reservation(
       (select id from public.reservations
        where idempotency_key = '33333333-0000-0000-0000-000000000001'), 'No') $$,
  null, 'Reason must be between 5 and 200 characters',
  'too-short reason is rejected');
select reset_auth();

-- Licensed pharmacist can reject with a valid reason
select set_auth_user('a3000000-0000-0000-0000-000000000002');
select lives_ok(
  $$ select public.reject_reservation(
       (select id from public.reservations
        where idempotency_key = '33333333-0000-0000-0000-000000000001'),
       'Medicine not in stock anymore') $$,
  'licensed pharmacist rejects successfully');
select reset_auth();

-- Status changed to rejected
select is(
  (select status from public.reservations
   where idempotency_key = '33333333-0000-0000-0000-000000000001'),
  'rejected'::public.reservation_status,
  'reservation status is now rejected');

-- =====================================================================
-- 4. MARK READY TESTS
-- =====================================================================

-- Mark the confirmed reservation as ready
select set_auth_user('a3000000-0000-0000-0000-000000000003');
select lives_ok(
  $$ select public.mark_ready(
       (select id from public.reservations
        where idempotency_key = '22222222-0000-0000-0000-000000000001')) $$,
  'any staff member can mark a confirmed reservation as ready');
select reset_auth();

select is(
  (select status from public.reservations
   where idempotency_key = '22222222-0000-0000-0000-000000000001'),
  'ready_for_pickup'::public.reservation_status,
  'reservation status is now ready_for_pickup');

-- =====================================================================
-- 5. CHECK PICKUP CODE TESTS
-- =====================================================================

-- Get the actual pickup code for testing
select set_auth_user('a3000000-0000-0000-0000-000000000003');
  select ok(
    not public.check_pickup_code(
      (select id from public.reservations
       where idempotency_key = '22222222-0000-0000-0000-000000000001'),
      'ZZZZ'),
    'wrong pickup code returns false');

  select ok(
    public.check_pickup_code(
      (select id from public.reservations
       where idempotency_key = '22222222-0000-0000-0000-000000000001'),
      (select code_suffix from public.pickup_codes
       where reservation_id = (select id from public.reservations
                                where idempotency_key = '22222222-0000-0000-0000-000000000001'))),
    'correct pickup code returns true');
select reset_auth();

-- =====================================================================
-- 6. COMPLETE RESERVATION TESTS
-- =====================================================================

-- Wrong code on complete also fails
select set_auth_user('a3000000-0000-0000-0000-000000000002');
select throws_ok(
  $$ select public.complete_reservation(
       (select id from public.reservations
        where idempotency_key = '22222222-0000-0000-0000-000000000001'),
       'ZZZZ') $$,
  null, 'Incorrect pickup code',
  'wrong code on complete raises an error');
select reset_auth();

-- Complete with the correct code
select set_auth_user('a3000000-0000-0000-0000-000000000002');
select lives_ok(
  format(
    'select public.complete_reservation(%L, %L)',
    (select id from public.reservations
     where idempotency_key = '22222222-0000-0000-0000-000000000001'),
    (select code_suffix from public.pickup_codes
     where reservation_id = (select id from public.reservations
                              where idempotency_key = '22222222-0000-0000-0000-000000000001'))
  ),
  'reservation completes with the correct pickup code');
select reset_auth();

-- Status changed to completed
select is(
  (select status from public.reservations
   where idempotency_key = '22222222-0000-0000-0000-000000000001'),
  'completed'::public.reservation_status,
  'reservation status is now completed');

-- Stock was deducted (started at 100, reserved 10)
select is(
  (select stock_quantity from public.inventory_items
   where id = 'a6000000-0000-0000-0000-000000000001'),
  90,
  'stock was deducted after completion');

-- =====================================================================
-- 7. CANCEL RESERVATION TESTS
-- =====================================================================

-- Create and confirm a third reservation for cancel testing
delete from public.carts where customer_id = 'a1000000-0000-0000-0000-000000000001';
delete from public.cart_items where customer_id = 'a1000000-0000-0000-0000-000000000001';
insert into public.carts (customer_id, branch_id)
values ('a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001');
insert into public.cart_items (customer_id, medicine_id, quantity)
values ('a1000000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000001', 5);

select set_auth_user('a1000000-0000-0000-0000-000000000001');
select * from public.submit_reservation('44444444-0000-0000-0000-000000000001', true);
select reset_auth();

select set_auth_user('a3000000-0000-0000-0000-000000000002');
select public.confirm_reservation(
  (select id from public.reservations
   where idempotency_key = '44444444-0000-0000-0000-000000000001'));
select reset_auth();

-- Regular staff can't cancel
select set_auth_user('a3000000-0000-0000-0000-000000000003');
select throws_ok(
  $$ select public.cancel_reservation(
       (select id from public.reservations
        where idempotency_key = '44444444-0000-0000-0000-000000000001'),
       'Customer did not come') $$,
  null, 'Only the Owner or a Pharmacist can cancel reservations',
  'regular staff cannot cancel');
select reset_auth();

-- Owner can cancel
select set_auth_user('a3000000-0000-0000-0000-000000000001');
select lives_ok(
  $$ select public.cancel_reservation(
       (select id from public.reservations
        where idempotency_key = '44444444-0000-0000-0000-000000000001'),
       'Customer did not come') $$,
  'owner cancels a confirmed reservation');
select reset_auth();

-- Status changed to cancelled
select is(
  (select status from public.reservations
   where idempotency_key = '44444444-0000-0000-0000-000000000001'),
  'cancelled'::public.reservation_status,
  'reservation status is now cancelled');

-- Held stock was released (5 held, now 0)
select is(
  (select held_quantity from public.inventory_items
   where id = 'a6000000-0000-0000-0000-000000000001'),
  0,
  'held stock was released after cancellation');

-- Undo all test data
select * from finish();
rollback;
