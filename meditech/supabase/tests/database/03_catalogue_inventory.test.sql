begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

-- Check that the main tables exist
select has_table('public', 'medicines', 'medicines table exists');
select has_table('public', 'inventory_items', 'inventory_items table exists');

-- Create a sample approved pharmacy
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Demo Pharmacy', 'La Paz Branch',
   '12 Rizal St, La Paz, Iloilo City', '0333201234', 'demo@test.com',
   10.7202, 122.5621, 'LTO-0000-0001', '2028-12-31', 'active');

-- Create a sample active medicine
insert into public.medicines
  (id, brand_name, generic_name, strength, dosage_form_id, unit_sold_id, status)
values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Biogesic', 'Paracetamol', '500 mg',
   (select id from public.dosage_forms where name = 'Tablet'),
   (select id from public.units where name = 'tablet'), 'active');

-- Stock it at the pharmacy: 240 tablets at ₱4.50
insert into public.inventory_items
  (branch_id, medicine_id, stock_quantity, price_per_unit, low_stock_threshold)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   240, 4.50, 20);

-- Reserved units can't be more than the stock
select throws_ok(
  $$ update public.inventory_items set held_quantity = 241 $$,
  '23514', null, 'holding more than the stock is rejected');

-- Prices can't have more than 2 decimal places
select throws_ok(
  $$ update public.inventory_items set price_per_unit = 4.555 $$,
  '23514', null, 'price with 3 decimal places is rejected');

-- The same medicine can't be listed twice by one pharmacy
select throws_ok(
  $$ insert into public.inventory_items (branch_id, medicine_id, stock_quantity, price_per_unit)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
             'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 10, 5.00) $$,
  '23505', null, 'duplicate listing is rejected');

-- Labels follow the agreed order
select is(public.availability_of(240, 0, 20, false, now()),
  'available'::public.availability_status, 'plenty of stock shows Available');
select is(public.availability_of(15, 0, 20, false, now()),
  'low_stock'::public.availability_status, 'stock at or below the level shows Low Stock');
select is(public.availability_of(240, 240, 20, false, now()),
  'unavailable'::public.availability_status, 'all units reserved shows Unavailable');
select is(public.availability_of(240, 0, 20, true, now()),
  'unavailable'::public.availability_status, 'out-of-stock switch shows Unavailable');
select is(public.availability_of(240, 0, 20, false, now() - interval '8 days'),
  'unconfirmed'::public.availability_status, 'not updated in 7 days shows Unconfirmed');
select is(public.availability_of(0, 0, 20, false, now() - interval '8 days'),
  'unavailable'::public.availability_status, 'no stock beats Unconfirmed');

-- The public view shows the active listing
select is((select count(*) from public.public_availability
  where medicine_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'), 1::bigint,
  'public view shows the active listing');

-- The public view hides a medicine once it is deactivated
update public.medicines set status = 'inactive'
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
select is((select count(*) from public.public_availability
  where medicine_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'), 0::bigint,
  'public view hides inactive medicines');

-- Undo all test data
select * from finish();
rollback;