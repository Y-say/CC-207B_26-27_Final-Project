-- Real-world PRC flow: pharmacists submit on Profile (pending); owners verify on Employees.
-- Block ad-hoc table updates to license columns outside approved RPCs.

create or replace function public.guard_prc_license_columns()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') = 'service_role' then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.prc_license_no is distinct from old.prc_license_no
       or new.prc_license_expiry is distinct from old.prc_license_expiry
       or new.license_status is distinct from old.license_status
       or new.license_verified_by is distinct from old.license_verified_by
       or new.license_verified_at is distinct from old.license_verified_at
    then
      if current_setting('meditech.prc_license_update', true) is distinct from '1' then
        raise exception
          'PRC license records are updated from Profile (submit) or Employees (owner verification)';
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists staff_members_guard_prc on public.staff_members;
create trigger staff_members_guard_prc
  before update on public.staff_members
  for each row execute function public.guard_prc_license_columns();

drop policy if exists "Staff updates own PRC" on public.staff_members;

create policy "Staff updates own profile names"
  on public.staff_members
  for update to authenticated
  using (account_id = auth.uid())
  with check (account_id = auth.uid());

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
  perform set_config('meditech.prc_license_update', '1', true);

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

  if v_emp.role <> 'pharmacist' then
    raise exception 'Only pharmacists submit a PRC license on Profile. Owners update under Profile or Employees.';
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

create or replace function public.update_employee_license(
  p_employee_id uuid,
  p_prc_license_no text,
  p_prc_license_expiry date,
  p_mark_verified boolean default false,
  p_owner_confirmed boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_branch_id uuid := public.my_branch_id();
  v_emp record;
  v_no text := trim(coalesce(p_prc_license_no, ''));
  v_status public.license_status;
  v_label text;
begin
  perform set_config('meditech.prc_license_update', '1', true);

  if public.my_account_type() <> 'staff' or public.my_staff_role() <> 'owner' then
    raise exception 'Only the pharmacy owner can update employee licenses';
  end if;

  if not exists (
    select 1 from public.branches where id = v_branch_id and status = 'active'
  ) then
    raise exception 'Your pharmacy must be active to manage employees';
  end if;

  select * into v_emp
  from public.staff_members
  where account_id = p_employee_id and branch_id = v_branch_id
  for update;

  if v_emp is null then
    raise exception 'Employee not found';
  end if;

  if v_emp.role = 'staff' then
    raise exception 'Change the employee role to pharmacist before adding a license';
  end if;

  if v_no !~ '^[0-9]{7}$' then
    raise exception 'PRC license number must be exactly 7 digits';
  end if;

  if p_prc_license_expiry is null then
    raise exception 'License expiry date is required';
  end if;

  if p_employee_id = v_actor_id and not p_owner_confirmed then
    raise exception 'Confirm your own PRC license details before saving';
  end if;

  if p_mark_verified then
    if p_prc_license_expiry < public.app_today() then
      raise exception 'Cannot verify an expired PRC license';
    end if;
    v_status := 'verified';
  elsif p_prc_license_expiry < public.app_today() then
    v_status := 'expired';
  else
    v_status := 'pending';
  end if;

  update public.staff_members
  set prc_license_no = v_no,
      prc_license_expiry = p_prc_license_expiry,
      license_status = v_status,
      license_verified_by = case when p_mark_verified then v_actor_id else null end,
      license_verified_at = case when p_mark_verified then now() else null end
  where account_id = p_employee_id;

  if p_mark_verified and p_employee_id <> v_actor_id then
    insert into public.notifications (recipient_id, type, title, body)
    values (p_employee_id, 'license_verified',
            'Your PRC license was verified',
            'You can now confirm and release reservations.');
  end if;

  v_label := public._staff_label(v_actor_id);
  perform public.log_activity(
    v_branch_id, v_actor_id, coalesce(v_label, 'Owner'), 'owner',
    case when p_mark_verified then 'Verified employee license' else 'Updated employee license' end,
    'employee', v_emp.display_id,
    jsonb_build_object('status', v_status::text, 'expires', p_prc_license_expiry)
  );
end;
$$;

create or replace function public.change_employee_role(
  p_employee_id uuid,
  p_new_role public.staff_role,
  p_prc_license_no text default null,
  p_prc_license_expiry date default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_branch_id uuid := public.my_branch_id();
  v_emp record;
  v_no text;
  v_expiry date;
  v_label text;
begin
  perform set_config('meditech.prc_license_update', '1', true);

  if public.my_account_type() <> 'staff' or public.my_staff_role() <> 'owner' then
    raise exception 'Only the pharmacy owner can change employee roles';
  end if;

  if not exists (
    select 1 from public.branches where id = v_branch_id and status = 'active'
  ) then
    raise exception 'Your pharmacy must be active to manage employees';
  end if;

  if p_employee_id = v_actor_id then
    raise exception 'You cannot change your own role';
  end if;

  if p_new_role = 'owner' then
    raise exception 'Cannot assign the owner role here';
  end if;

  select * into v_emp
  from public.staff_members
  where account_id = p_employee_id and branch_id = v_branch_id
  for update;

  if v_emp is null then
    raise exception 'Employee not found';
  end if;

  if v_emp.role = 'owner' then
    raise exception 'The owner role cannot be changed here';
  end if;

  if v_emp.role = p_new_role then
    return;
  end if;

  if p_new_role = 'pharmacist' then
    v_no := coalesce(nullif(trim(p_prc_license_no), ''), v_emp.prc_license_no);
    v_expiry := coalesce(p_prc_license_expiry, v_emp.prc_license_expiry);

    if v_no is null or v_no !~ '^[0-9]{7}$' then
      raise exception 'PRC license number must be exactly 7 digits';
    end if;

    if v_expiry is null or v_expiry < public.app_today() then
      raise exception 'PRC license expiry must be today or later';
    end if;

    update public.staff_members
    set role = 'pharmacist',
        prc_license_no = v_no,
        prc_license_expiry = v_expiry,
        license_status = 'pending',
        license_verified_by = null,
        license_verified_at = null
    where account_id = p_employee_id;
  else
    update public.staff_members
    set role = 'staff',
        license_status = 'none',
        license_verified_by = null,
        license_verified_at = null
    where account_id = p_employee_id;
  end if;

  v_label := public._staff_label(v_actor_id);
  perform public.log_activity(
    v_branch_id, v_actor_id, coalesce(v_label, 'Owner'), 'owner',
    'Changed employee role', 'employee', v_emp.display_id,
    jsonb_build_object('from', v_emp.role::text, 'to', p_new_role::text)
  );
end;
$$;