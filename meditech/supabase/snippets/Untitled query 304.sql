   insert into public.accounts (id, account_type)
   select id, 'customer' from auth.users where email = 'test@meditech.dev';