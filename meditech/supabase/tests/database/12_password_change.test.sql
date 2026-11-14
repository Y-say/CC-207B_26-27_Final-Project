begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

insert into auth.users (id, email) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'temp.staff@test.com');
insert into public.accounts (id, account_type, must_change_password)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'staff', true);

select set_config('request.jwt.claims',
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc"}', true);

select lives_ok(
  $$ select public.finish_password_change() $$,
  'a signed-in person can finish a password change');

select is(
  (select must_change_password from public.accounts
   where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  false,
  'the temporary-password flag is cleared');

select * from finish();
rollback;