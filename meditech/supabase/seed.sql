-- DEMO DATA for local development only. Every demo password is Demo1234.
-- Never load this into the real database.

-- ===== Helper: create a demo sign-in with a password =====
create or replace function pg_temp.demo_user(p_id uuid, p_email text)
returns void
language plpgsql
as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change)
  values (
    '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', p_email,
    extensions.crypt('Demo1234', extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');

  insert into auth.identities (
    id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (
    gen_random_uuid(), p_id, p_id::text,
    jsonb_build_object('sub', p_id::text, 'email', p_email, 'email_verified', true),
    'email', now(), now(), now());
end
$$;

-- ===== Sign-ins =====
select pg_temp.demo_user('10000000-0000-0000-0000-000000000001', 'admin@demo.meditech.dev');
select pg_temp.demo_user('20000000-0000-0000-0000-000000000001', 'owner@demo.meditech.dev');
select pg_temp.demo_user('20000000-0000-0000-0000-000000000002', 'pharmacist@demo.meditech.dev');
select pg_temp.demo_user('20000000-0000-0000-0000-000000000003', 'staff@demo.meditech.dev');
select pg_temp.demo_user('20000000-0000-0000-0000-000000000004', 'pending.owner@demo.meditech.dev');
select pg_temp.demo_user('30000000-0000-0000-0000-000000000001', 'juan@demo.meditech.dev');
select pg_temp.demo_user('30000000-0000-0000-0000-000000000002', 'luke@demo.meditech.dev');

-- ===== Accounts =====
insert into public.accounts (id, account_type, username, state) values
  ('10000000-0000-0000-0000-000000000001', 'admin', 'demo_admin', 'active'),
  ('20000000-0000-0000-0000-000000000001', 'staff', 'demo_owner', 'active'),
  ('20000000-0000-0000-0000-000000000002', 'staff', 'demo_pharma', 'active'),
  ('20000000-0000-0000-0000-000000000003', 'staff', 'demo_staff', 'active'),
  ('20000000-0000-0000-0000-000000000004', 'staff', 'demo_pending', 'pending_approval'),
  ('30000000-0000-0000-0000-000000000001', 'customer', null, 'active'),
  ('30000000-0000-0000-0000-000000000002', 'customer', null, 'active');

insert into public.admins (account_id, display_name)
values ('10000000-0000-0000-0000-000000000001', 'Demo Admin');

insert into public.customer_profiles
  (account_id, first_name, last_name, mobile, email, birthdate, consent_version)
values
  ('30000000-0000-0000-0000-000000000001', 'Juan', 'Dela Cruz', '09170000001',
   'juan@demo.meditech.dev', '1995-06-15', 'v1'),
  ('30000000-0000-0000-0000-000000000002', 'Luke', 'Dela Cruz', '09170000002',
   'luke@demo.meditech.dev', '1998-02-03', 'v1');

-- ===== Pharmacies: two approved, one waiting for approval =====
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status, approved_at)
values
  ('b0000000-0000-0000-0000-000000000001', 'Demo Pharmacy', 'La Paz Branch',
   '12 Rizal St, La Paz, Iloilo City', '0333200001', 'lapaz@demo.meditech.dev',
   10.7202, 122.5621, 'DEMO-LTO-0001', '2028-12-31', 'active', now()),
  ('b0000000-0000-0000-0000-000000000002', 'Demo Pharmacy', 'Jaro Branch',
   '45 Lopez Jaena St, Jaro, Iloilo City', '0333200002', 'jaro@demo.meditech.dev',
   10.7275, 122.5577, 'DEMO-LTO-0002', '2028-12-31', 'active', now()),
  ('b0000000-0000-0000-0000-000000000003', 'Demo Waiting Pharmacy', 'Molo Branch',
   '8 Molo Plaza, Molo, Iloilo City', '0333200003', 'molo@demo.meditech.dev',
   10.6969, 122.5446, 'DEMO-LTO-0003', '2028-12-31', 'pending_approval', null);

-- Open every day, 7 AM to 10 PM
insert into public.branch_hours (branch_id, weekday, opens_at, closes_at)
select b, d, '07:00', '22:00'
from unnest(array['b0000000-0000-0000-0000-000000000001',
                  'b0000000-0000-0000-0000-000000000002']::uuid[]) as b,
     generate_series(0, 6) as d;

-- ===== Staff at La Paz, and the waiting pharmacy's owner =====
insert into public.staff_members
  (account_id, branch_id, role, first_name, last_name,
   prc_license_no, prc_license_expiry, license_status)
values
  ('20000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
   'owner', 'Maria', 'Santos', null, null, 'none'),
  ('20000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001',
   'pharmacist', 'Jose', 'Reyes', '0123456', '2030-12-31', 'verified'),
  ('20000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001',
   'staff', 'Ana', 'Lim', null, null, 'none'),
  ('20000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000003',
   'owner', 'Rosa', 'Villareal', null, null, 'none');

-- ===== 15 demo medicines =====
insert into public.medicines
  (brand_name, generic_name, strength, dosage_form_id, unit_sold_id, is_rx, status, pack_description)
select v.brand, v.generic, v.strength, f.id, u.id, v.rx, 'active', 'DEMO DATA'
from (values
  ('Biogesic', 'Paracetamol', '500 mg', 'Tablet', 'tablet', false),
  ('Amoxil', 'Amoxicillin', '500 mg', 'Capsule', 'capsule', true),
  ('Cozaar', 'Losartan', '50 mg', 'Tablet', 'tablet', true),
  ('Virlix', 'Cetirizine', '10 mg', 'Tablet', 'tablet', false),
  ('Glucophage', 'Metformin', '500 mg', 'Tablet', 'tablet', true),
  ('Ceelin', 'Ascorbic Acid', '100 mg/5 mL', 'Syrup', 'bottle', false),
  ('Dolfenal', 'Mefenamic Acid', '500 mg', 'Tablet', 'tablet', false),
  ('Norvasc', 'Amlodipine', '5 mg', 'Tablet', 'tablet', true),
  ('Alaxan FR', 'Ibuprofen + Paracetamol', '200/325 mg', 'Tablet', 'tablet', false),
  ('Neozep Forte', 'Phenylephrine + Chlorphenamine + Paracetamol', '10/2/500 mg', 'Tablet', 'tablet', false),
  ('Tempra', 'Paracetamol', '120 mg/5 mL', 'Syrup', 'bottle', false),
  ('Myra-E', 'Vitamin E', '400 IU', 'Capsule', 'capsule', false),
  ('Betadine', 'Povidone-Iodine', '10%', 'Solution', 'bottle', false),
  ('Kremil-S', 'Aluminum Hydroxide + Magnesium Hydroxide + Simeticone', '178/233/30 mg', 'Tablet', 'tablet', false),
  ('Solmux', 'Carbocisteine', '500 mg', 'Capsule', 'capsule', false)
) as v(brand, generic, strength, form, unit, rx)
join public.dosage_forms f on f.name = v.form
join public.units u on u.name = v.unit;

-- ===== La Paz stock, with one of every label =====
insert into public.inventory_items
  (branch_id, medicine_id, stock_quantity, price_per_unit, low_stock_threshold,
   nearest_expiry, out_of_stock_flag, stock_confirmed_at)
select 'b0000000-0000-0000-0000-000000000001', m.id, v.stock, v.price, v.threshold,
       v.expiry, v.switched_off, now() - v.age
from (values
  ('Biogesic', 240, 4.50, 20, date '2027-08-26', false, interval '0 days'),
  ('Amoxil', 96, 12.00, 20, date '2027-03-15', false, interval '0 days'),
  ('Cozaar', 50, 18.00, 10, date '2027-06-30', false, interval '0 days'),
  -- Not updated in 10 days: shows Unconfirmed
  ('Virlix', 60, 7.00, 10, date '2027-01-20', false, interval '10 days'),
  -- Switched off: shows Unavailable
  ('Glucophage', 8, 6.00, 10, date '2027-05-01', true, interval '0 days'),
  ('Dolfenal', 300, 3.00, 20, date '2027-09-10', false, interval '0 days'),
  -- Below the low-stock level: shows Low Stock
  ('Norvasc', 15, 9.50, 20, date '2027-04-12', false, interval '0 days'),
  ('Alaxan FR', 18, 8.00, 20, date '2027-02-28', false, interval '0 days'),
  -- Expires within 60 days: shows in Expiring soon
  ('Betadine', 30, 85.00, 5, current_date + 30, false, interval '0 days'),
  ('Ceelin', 24, 95.00, 5, date '2027-02-28', false, interval '0 days'),
  ('Myra-E', 120, 9.00, 20, date '2027-12-14', false, interval '0 days'),
  ('Solmux', 80, 10.50, 20, date '2027-07-01', false, interval '0 days')
) as v(brand, stock, price, threshold, expiry, switched_off, age)
join public.medicines m on m.brand_name = v.brand;

-- ===== Jaro stock, with different prices for comparing =====
insert into public.inventory_items
  (branch_id, medicine_id, stock_quantity, price_per_unit, low_stock_threshold)
select 'b0000000-0000-0000-0000-000000000002', m.id, v.stock, v.price, v.threshold
from (values
  ('Biogesic', 18, 4.25, 20),
  ('Amoxil', 140, 11.50, 20),
  ('Cozaar', 90, 18.50, 10),
  ('Virlix', 75, 6.50, 10),
  ('Tempra', 40, 110.00, 5),
  ('Neozep Forte', 200, 6.50, 20),
  ('Kremil-S', 150, 8.75, 20)
) as v(brand, stock, price, threshold)
join public.medicines m on m.brand_name = v.brand;