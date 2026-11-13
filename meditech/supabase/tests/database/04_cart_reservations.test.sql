begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

-- Check that the main tables exist
select has_table('public', 'carts', 'carts table exists');
select has_table('public', 'reservations', 'reservations table exists');
select has_table('public', 'reservation_items', 'reservation_items table exists');
select has_table('public', 'pickup_codes', 'pickup_codes table exists');
select has_table('public', 'notifications', 'notifications table exists');

-- Reservation numbers count up per day
select is(public.next_reference_number(),
  'RM-' || to_char(public.app_today(), 'MMDDYY') || '-0001', 'first number of the day is 0001');
select is(public.next_reference_number(),
  'RM-' || to_char(public.app_today(), 'MMDDYY') || '-0002', 'second number of the day is 0002');

-- After 9999, the number grows to 5 digits instead of being cut off
update public.daily_counters set last_value = 9999;
select is(public.next_reference_number(),
  'RM-' || to_char(public.app_today(), 'MMDDYY') || '-10000', 'number after 9999 is 10000');

-- Create a sample customer, pharmacy, medicine, and listing
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'cust@test.com');
insert into public.accounts (id, account_type) values
  ('11111111-1111-1111-1111-111111111111', 'customer');
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Demo Pharmacy', 'La Paz Branch',
   '12 Rizal St, La Paz, Iloilo City', '0333201234', 'demo@test.com',
   10.7202, 122.5621, 'LTO-0000-0001', '2028-12-31', 'active');
insert into public.medicines
  (id, brand_name, generic_name, strength, dosage_form_id, unit_sold_id, status)
values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Biogesic', 'Paracetamol', '500 mg',
   (select id from public.dosage_forms where name = 'Tablet'),
   (select id from public.units where name = 'tablet'), 'active');
insert into public.inventory_items
  (id, branch_id, medicine_id, stock_quantity, price_per_unit)
values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 240, 4.50);

-- Cart quantities must be at least 1
insert into public.carts (customer_id, branch_id)
values ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
select throws_ok(
  $$ insert into public.cart_items (customer_id, medicine_id, quantity)
     values ('11111111-1111-1111-1111-111111111111',
             'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 0) $$,
  '23514', null, 'cart quantity of 0 is rejected');

-- Create a sample reservation
insert into public.reservations
  (id, reference_no, customer_id, branch_id, total_amount, expires_at, idempotency_key)
values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'RM-111326-0001',
   '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   45.00, now() + interval '7 days', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee');

-- The same tap can't create two reservations
select throws_ok(
  $$ insert into public.reservations
       (reference_no, customer_id, branch_id, total_amount, expires_at, idempotency_key)
     values ('RM-111326-0002', '11111111-1111-1111-1111-111111111111',
             'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 45.00, now() + interval '7 days',
             'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') $$,
  '23505', null, 'repeated tap is rejected');

-- Reserved units can't be more than what was ordered
select throws_ok(
  $$ insert into public.reservation_items
       (reservation_id, line_no, medicine_id, inventory_item_id, quantity, held_quantity,
        brand_name, generic_name, strength, dosage_form, unit_sold, is_rx, unit_price)
     values ('dddddddd-dddd-dddd-dddd-dddddddddddd', 1,
             'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'cccccccc-cccc-cccc-cccc-cccccccccccc',
             10, 11, 'Biogesic', 'Paracetamol', '500 mg', 'Tablet', 'tablet', false, 4.50) $$,
  '23514', null, 'holding more than ordered is rejected');

-- Pickup codes can't use look-alike characters such as O
select throws_ok(
  $$ insert into public.pickup_codes (reservation_id, code_suffix)
     values ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'K7O4') $$,
  '23514', null, 'pickup code with the letter O is rejected');

-- The same notification can't be sent twice
insert into public.notifications (recipient_id, type, title, body, dedupe_key)
values ('11111111-1111-1111-1111-111111111111', 'reminder', 'Expiring soon',
        'Your reservation expires tomorrow.', 'reminder:test');
select throws_ok(
  $$ insert into public.notifications (recipient_id, type, title, body, dedupe_key)
     values ('11111111-1111-1111-1111-111111111111', 'reminder', 'Expiring soon',
             'Your reservation expires tomorrow.', 'reminder:test') $$,
  '23505', null, 'duplicate notification is rejected');

-- Undo all test data
select * from finish();
rollback;