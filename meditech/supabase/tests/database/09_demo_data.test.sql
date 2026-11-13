begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

-- The demo world is in place
select is((select count(*) from public.branches where lto_number like 'DEMO-%' and status = 'active'),
  2::bigint, 'two approved demo pharmacies');
select is((select count(*) from public.medicines where pack_description = 'DEMO DATA'),
  15::bigint, 'fifteen demo medicines');
select is((select account_type from public.find_account_for_sign_in('demo_pharma')),
  'staff'::public.account_type, 'demo pharmacist can be found by username');
select is((select account_id from public.find_account_for_sign_in('09170000001')),
  '30000000-0000-0000-0000-000000000001'::uuid, 'demo customer can be found by mobile');

-- Every label appears at least once at La Paz
select is((select count(distinct availability) from public.public_availability
           where branch_id = 'b0000000-0000-0000-0000-000000000001'),
  4::bigint, 'La Paz shows all four labels');

select * from finish();
rollback;