begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

-- A sign-in for the applicant
insert into auth.users (id, email)
values ('11111111-1111-1111-1111-111111111111', 'ana@test.com');

-- Submit a full application
select is(public.create_pharmacy_application(jsonb_build_object(
  'account_id', '11111111-1111-1111-1111-111111111111',
  'branch_id', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'username', 'areyes',
  'pharmacy_name', 'Farmacia Uno', 'branch_name', 'Main Branch',
  'address', '12 Rizal St, Molo, Iloilo City', 'contact_number', '0333361111',
  'pharmacy_email', 'uno@test.com', 'latitude', 10.7202, 'longitude', 122.5621,
  'lto_number', 'LTO-TEST-0001', 'lto_expiry', '2028-02-28',
  'first_name', 'Ana', 'last_name', 'Reyes', 'mobile', '09171234567',
  'hours', (select jsonb_agg(jsonb_build_object('weekday', d, 'opens_at', '08:00', 'closes_at', '20:00'))
            from generate_series(0, 6) d),
  'lto_path', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/lto/x.pdf', 'lto_mime', 'application/pdf', 'lto_size', 1000,
  'storefront_path', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/storefront/y.jpg',
  'storefront_mime', 'image/jpeg', 'storefront_size', 2000
)) like 'PHM-%', true, 'application returns a pharmacy ID');

-- Everything was saved, waiting for approval
select is((select status from public.branches where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'pending_approval'::public.branch_status, 'branch waits for approval');
select is((select state from public.accounts where id = '11111111-1111-1111-1111-111111111111'),
  'pending_approval'::public.account_state, 'owner account waits for approval');
select is((select count(*) from public.branch_hours where branch_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  7::bigint, 'hours saved for all 7 days');
select is((select count(*) from public.branch_documents where branch_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  2::bigint, 'both documents saved');
select is((select count(*) from public.audit_records where record_ref like 'PHM-%'
           and event_type = 'pharmacy_application'), 1::bigint, 'application recorded for admins');

-- The app can't save applications directly
select ok(not has_function_privilege('anon', 'public.create_pharmacy_application(jsonb)', 'execute'),
  'guests cannot save applications directly');

select * from finish();
rollback;