-- Find an account by email, mobile number, or username
create or replace function public.find_account_for_sign_in(p_identifier text)
returns table (account_id uuid, email text, account_type public.account_type, display_name text)
language sql stable security definer
set search_path = ''
as $$
  select a.id,
         u.email::text,
         a.account_type,
         coalesce(cp.first_name || ' ' || cp.last_name,
                  sm.first_name || ' ' || sm.last_name,
                  ad.display_name,
                  u.email::text)
  from public.accounts a
  join auth.users u on u.id = a.id
  left join public.customer_profiles cp on cp.account_id = a.id
  left join public.staff_members sm on sm.account_id = a.id
  left join public.admins ad on ad.account_id = a.id
  where lower(u.email) = lower(p_identifier)
     or cp.mobile = p_identifier
     or lower(a.username::text) = lower(p_identifier)
  limit 1
$$;

-- Count a wrong password; after 5 within 15 minutes, lock the account for 15 minutes
create or replace function public.record_failed_sign_in(
  p_account_id uuid, p_label text, p_identifier text, p_app text
)
returns timestamptz
language plpgsql security definer
set search_path = ''
as $$
declare
  locked timestamptz;
begin
  -- Unknown account: just record the attempt
  if p_account_id is null then
    perform public.log_audit(null, 'Unknown', null, 'failed_sign_in', 'Wrong password',
      p_app, jsonb_build_object('identifier_tried', p_identifier));
    return null;
  end if;

  -- Add one failed try, starting over if the last one was over 15 minutes ago
  insert into public.auth_attempts (account_id, failed_count, first_failed_at)
  values (p_account_id, 1, now())
  on conflict (account_id) do update set
    failed_count = case
      when public.auth_attempts.first_failed_at < now() - interval '15 minutes' then 1
      else public.auth_attempts.failed_count + 1 end,
    first_failed_at = case
      when public.auth_attempts.first_failed_at < now() - interval '15 minutes' then now()
      else public.auth_attempts.first_failed_at end;

  -- Lock on the 5th try
  update public.auth_attempts
  set locked_until = now() + interval '15 minutes'
  where account_id = p_account_id and failed_count >= 5
    and (locked_until is null or locked_until < now())
  returning locked_until into locked;

  perform public.log_audit(p_account_id, p_label, null, 'failed_sign_in',
    case when locked is not null
      then '5 wrong passwords. Sign-in locked for 15 minutes.'
      else 'Wrong password' end,
    p_app, jsonb_build_object('identifier_tried', p_identifier));

  return locked;
end
$$;

-- Successful sign-in: clear failed tries and record it
create or replace function public.record_successful_sign_in(
  p_account_id uuid, p_label text, p_app text
)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  delete from public.auth_attempts where account_id = p_account_id;
  perform public.log_audit(p_account_id, p_label, null, 'sign_in', 'Signed in', p_app);
end
$$;

-- Only the sign-in function may use these, never the app directly
revoke execute on function public.find_account_for_sign_in(text) from public, anon, authenticated;
revoke execute on function public.record_failed_sign_in(uuid, text, text, text) from public, anon, authenticated;
revoke execute on function public.record_successful_sign_in(uuid, text, text) from public, anon, authenticated;
grant execute on function public.find_account_for_sign_in(text) to service_role;
grant execute on function public.record_failed_sign_in(uuid, text, text, text) to service_role;
grant execute on function public.record_successful_sign_in(uuid, text, text) to service_role;