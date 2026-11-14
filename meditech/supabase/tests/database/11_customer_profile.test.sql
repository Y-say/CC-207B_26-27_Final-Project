begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users (id, email) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'new.customer@test.com'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'other.customer@test.com');

select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}', true);

select lives_ok(
  $$ select public.create_customer_profile(
       'Ana', 'Marie', 'Reyes', '09178880001', '2000-01-01') $$,
  'a new customer profile can be saved');

select set_config('request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}', true);

select throws_ok(
  $$ select public.create_customer_profile(
       'Ben', null, 'Cruz', '09178880001', '2000-01-01') $$,
  'P0001', 'This mobile number is already used.',
  'a used mobile number is refused');

select throws_ok(
  $$ select public.create_customer_profile(
       'Ben', null, 'Cruz', '09178880002', '2999-01-01') $$,
  'P0001', 'Birthdate cannot be in the future.',
  'a future birthdate is refused');

select * from finish();
rollback;