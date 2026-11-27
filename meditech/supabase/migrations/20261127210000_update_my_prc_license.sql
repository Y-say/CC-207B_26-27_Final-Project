-- Pharmacists submit or refresh their own PRC details (pending until owner verifies).

create or replace function public.update_my_prc_license(
  p_prc_license_no text,
  p_prc_license_expiry date
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_emp public.staff_members%rowtype;
  v_no text := trim(coalesce(p_prc_license_no, ''));
  v_status public.license_status;
begin
  if public.my_account_type() <> 'staff' then
    raise exception 'Only pharmacy staff can update a license';
  end if;

  if not exists (
    select 1
    from public.branches b
    join public.staff_members sm on sm.branch_id = b.id and sm.account_id = v_uid
    where b.status = 'active' and sm.is_active
  ) then
    raise exception 'Your pharmacy must be active to update your license';
  end if;

  select * into v_emp
  from public.staff_members
  where account_id = v_uid
  for update;

  if v_emp.role = 'staff' then
    raise exception 'Change your role to pharmacist before adding a license';
  end if;

  if v_emp.role = 'owner' then
    raise exception 'Owners update their license from Profile or Employees';
  end if;

  if v_no !~ '^[0-9]{7}$' then
    raise exception 'PRC license number must be exactly 7 digits';
  end if;

  if p_prc_license_expiry is null then
    raise exception 'License expiry date is required';
  end if;

  if p_prc_license_expiry < public.app_today() then
    v_status := 'expired';
  else
    v_status := 'pending';
  end if;

  update public.staff_members
  set prc_license_no = v_no,
      prc_license_expiry = p_prc_license_expiry,
      license_status = v_status,
      license_verified_by = null,
      license_verified_at = null
  where account_id = v_uid;
end;
$$;

revoke execute on function public.update_my_prc_license(text, date) from public, anon;
grant execute on function public.update_my_prc_license(text, date) to authenticated;