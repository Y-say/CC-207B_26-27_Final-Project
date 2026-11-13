begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

select has_function('public', 'app_today', 'app_today() exists');
select is(public.app_today(),
          (now() at time zone 'Asia/Manila')::date,
          'app_today() uses Manila time');

select * from finish();
rollback;