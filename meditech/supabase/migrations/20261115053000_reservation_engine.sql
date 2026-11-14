-- Reservation engine: submit, confirm, reject, mark ready, check pickup code,
-- complete, and cancel reservations

-- =====================================================================
-- Helper: build a staff label like "Jose Reyes (Pharmacist)"
-- =====================================================================
create or replace function public._staff_label(p_account_id uuid)
returns text
language sql stable security definer
set search_path = ''
as $$
  select sm.first_name || ' ' || sm.last_name || ' (' || initcap(sm.role::text) || ')'
  from public.staff_members sm
  where sm.account_id = p_account_id and sm.is_active
$$;

-- Only used internally by the reservation engine
revoke execute on function public._staff_label(uuid) from public, anon, authenticated;

-- =====================================================================
-- Helper: build a customer label like "Juan Dela Cruz"
-- =====================================================================
create or replace function public._customer_label(p_account_id uuid)
returns text
language sql stable security definer
set search_path = ''
as $$
  select cp.first_name || ' ' || cp.last_name
  from public.customer_profiles cp
  where cp.account_id = p_account_id
$$;

-- Only used internally by the reservation engine
revoke execute on function public._customer_label(uuid) from public, anon, authenticated;

-- =====================================================================
-- 1. SUBMIT RESERVATION
-- A customer places a reservation from their cart. Stock is checked but
-- nothing is held (team rule: stock is held only when a pharmacist confirms).
-- =====================================================================
create or replace function public.submit_reservation(
  p_idempotency_key uuid,
  p_acknowledged boolean default false
)
returns table (reservation_id uuid, reference_no text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := auth.uid();
  v_cart record;
  v_ref text;
  v_reservation_id uuid;
  v_total numeric := 0;
  v_has_rx boolean := false;
  v_line int := 0;
  v_item record;
  v_rx_file record;
  v_customer_label text;
begin
  -- Only customers may place reservations
  if public.my_account_type() <> 'customer' then
    raise exception 'Only customers can place reservations';
  end if;

  -- Look up the customer's cart
  select * into v_cart
  from public.carts
  where customer_id = v_customer_id;

  if v_cart is null then
    raise exception 'Your cart is empty';
  end if;

  -- Check that the cart has items
  if not exists (select 1 from public.cart_items where customer_id = v_customer_id) then
    raise exception 'Your cart is empty';
  end if;

  -- Check that the branch is still active
  if not exists (
    select 1 from public.branches
    where id = v_cart.branch_id and status = 'active'
  ) then
    raise exception 'This pharmacy is no longer available';
  end if;

  -- Check every item: active listing, active medicine, and enough stock
  for v_item in
    select ci.medicine_id, ci.quantity,
           inv.id as inventory_item_id,
           inv.stock_quantity, inv.held_quantity,
           inv.is_active as listing_active,
           inv.price_per_unit,
           inv.out_of_stock_flag,
           m.brand_name, m.generic_name, m.strength,
           m.is_rx, m.status as medicine_status,
           df.name as dosage_form, u.name as unit_sold
    from public.cart_items ci
    join public.inventory_items inv
      on inv.branch_id = v_cart.branch_id and inv.medicine_id = ci.medicine_id
    join public.medicines m on m.id = ci.medicine_id
    join public.dosage_forms df on df.id = m.dosage_form_id
    join public.units u on u.id = m.unit_sold_id
    where ci.customer_id = v_customer_id
  loop
    -- Medicine must be active in the catalogue
    if v_item.medicine_status <> 'active' then
      raise exception 'The medicine "%" is no longer available', v_item.brand_name;
    end if;

    -- Listing must be active and not switched off
    if not v_item.listing_active or v_item.out_of_stock_flag then
      raise exception '"%" is currently unavailable at this pharmacy', v_item.brand_name;
    end if;

    -- Enough stock must be available (stock minus what is already held by others)
    if v_item.stock_quantity - v_item.held_quantity < v_item.quantity then
      raise exception 'Not enough stock for "%"', v_item.brand_name;
    end if;

    -- Track whether any item needs a prescription
    if v_item.is_rx then
      v_has_rx := true;
    end if;
  end loop;

  -- If any item requires a prescription, the customer must have uploaded files
  if v_has_rx then
    if not exists (
      select 1 from public.cart_prescription_files
      where customer_id = v_customer_id
    ) then
      raise exception 'Prescription file required for Rx items';
    end if;
  end if;

  -- The customer must acknowledge reservation terms
  if not p_acknowledged then
    raise exception 'You must acknowledge the reservation terms';
  end if;

  -- Generate the reservation number (RM-MMDDYY-0001)
  v_ref := public.next_reference_number();
  v_reservation_id := gen_random_uuid();

  -- Create the reservation
  insert into public.reservations
    (id, reference_no, customer_id, branch_id, status, has_rx,
     total_amount, submitted_at, expires_at, idempotency_key)
  values
    (v_reservation_id, v_ref, v_customer_id, v_cart.branch_id, 'pending', v_has_rx,
     0, now(), now() + interval '7 days', p_idempotency_key);

  -- Save each item with a snapshot of its current details and price
  for v_item in
    select ci.medicine_id, ci.quantity,
           inv.id as inventory_item_id,
           inv.price_per_unit,
           m.brand_name, m.generic_name, m.strength,
           m.is_rx,
           df.name as dosage_form, u.name as unit_sold
    from public.cart_items ci
    join public.inventory_items inv
      on inv.branch_id = v_cart.branch_id and inv.medicine_id = ci.medicine_id
    join public.medicines m on m.id = ci.medicine_id
    join public.dosage_forms df on df.id = m.dosage_form_id
    join public.units u on u.id = m.unit_sold_id
    where ci.customer_id = v_customer_id
    order by ci.added_at
  loop
    v_line := v_line + 1;
    v_total := v_total + (v_item.price_per_unit * v_item.quantity);

    insert into public.reservation_items
      (reservation_id, line_no, medicine_id, inventory_item_id, quantity,
       held_quantity, brand_name, generic_name, strength, dosage_form,
       unit_sold, is_rx, unit_price)
    values
      (v_reservation_id, v_line, v_item.medicine_id, v_item.inventory_item_id,
       v_item.quantity, 0, v_item.brand_name, v_item.generic_name,
       v_item.strength, v_item.dosage_form, v_item.unit_sold,
       v_item.is_rx, v_item.price_per_unit);
  end loop;

  -- Update the total amount on the reservation
  update public.reservations
  set total_amount = v_total
  where id = v_reservation_id;

  -- Move prescription files from the cart to the reservation
  for v_rx_file in
    select id, storage_path, mime_type, size_bytes
    from public.cart_prescription_files
    where customer_id = v_customer_id
  loop
    insert into public.reservation_prescriptions
      (reservation_id, storage_path, mime_type, size_bytes)
    values
      (v_reservation_id, v_rx_file.storage_path, v_rx_file.mime_type, v_rx_file.size_bytes);
  end loop;

  -- Record the first status change (null to pending)
  insert into public.reservation_status_history
    (reservation_id, from_status, to_status, actor_id, actor_role)
  values
    (v_reservation_id, null, 'pending', v_customer_id, 'customer');

  -- Notify every active staff member at the branch
  v_customer_label := public._customer_label(v_customer_id);

  insert into public.notifications (recipient_id, type, title, body, reservation_id)
  select sm.account_id, 'new_reservation',
         'New reservation ' || v_ref,
         coalesce(v_customer_label, 'A customer') || ' placed a new reservation.',
         v_reservation_id
  from public.staff_members sm
  where sm.branch_id = v_cart.branch_id and sm.is_active;

  -- Log the activity for the pharmacy owner
  perform public.log_activity(
    v_cart.branch_id, v_customer_id,
    coalesce(v_customer_label, 'Customer'),
    'customer', 'Placed reservation',
    'reservation', v_ref
  );

  -- Clear the cart
  delete from public.cart_prescription_files where customer_id = v_customer_id;
  delete from public.cart_items where customer_id = v_customer_id;
  delete from public.carts where customer_id = v_customer_id;

  return query select v_reservation_id, v_ref;
end
$$;

-- =====================================================================
-- 2. CONFIRM RESERVATION
-- A licensed pharmacist confirms a pending reservation, holds stock,
-- and generates the pickup code for the customer.
-- =====================================================================
create or replace function public.confirm_reservation(p_reservation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_res record;
  v_item record;
  v_code text;
  v_label text;
  v_customer_label text;
begin
  -- Only staff with a valid license can confirm
  if public.my_account_type() <> 'staff' then
    raise exception 'Only pharmacy staff can confirm reservations';
  end if;
  if not public.has_valid_license() then
    raise exception 'A verified and unexpired pharmacist license is required';
  end if;

  -- Look up the reservation and lock the row
  select * into v_res
  from public.reservations
  where id = p_reservation_id
  for update;

  if v_res is null then
    raise exception 'Reservation not found';
  end if;

  -- Must be at the same branch
  if v_res.branch_id <> public.my_branch_id() then
    raise exception 'This reservation belongs to a different branch';
  end if;

  -- Only pending reservations can be confirmed
  if v_res.status <> 'pending' then
    raise exception 'Only pending reservations can be confirmed';
  end if;

  -- Re-check stock and place holds on each item
  for v_item in
    select ri.line_no, ri.inventory_item_id, ri.quantity, ri.brand_name
    from public.reservation_items ri
    where ri.reservation_id = p_reservation_id
    order by ri.line_no
  loop
    -- Lock the inventory row and check available stock
    if not exists (
      select 1 from public.inventory_items
      where id = v_item.inventory_item_id
        and is_active
        and not out_of_stock_flag
        and stock_quantity - held_quantity >= v_item.quantity
      for update
    ) then
      raise exception 'Not enough stock for "%" to confirm this reservation', v_item.brand_name;
    end if;

    -- Place the hold
    update public.inventory_items
    set held_quantity = held_quantity + v_item.quantity
    where id = v_item.inventory_item_id;

    -- Record the held amount on the reservation item
    update public.reservation_items
    set held_quantity = v_item.quantity
    where reservation_id = p_reservation_id and line_no = v_item.line_no;
  end loop;

  -- Generate a 4-character pickup code (no O, 0, I, or 1)
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', floor(random() * 30 + 1)::int, 1), '')
  into v_code
  from generate_series(1, 4);

  insert into public.pickup_codes (reservation_id, code_suffix)
  values (p_reservation_id, v_code);

  -- Update the reservation status
  update public.reservations
  set status = 'confirmed',
      confirmed_at = now(),
      confirmed_by = v_actor_id
  where id = p_reservation_id;

  -- Record the status change
  insert into public.reservation_status_history
    (reservation_id, from_status, to_status, actor_id, actor_role)
  values
    (p_reservation_id, 'pending', 'confirmed', v_actor_id, public.my_staff_role()::text);

  -- Notify the customer
  v_customer_label := public._customer_label(v_res.customer_id);
  insert into public.notifications (recipient_id, type, title, body, reservation_id)
  values (v_res.customer_id, 'reservation_confirmed',
          'Reservation ' || v_res.reference_no || ' confirmed',
          'Your reservation has been confirmed. Your pickup code is ' || v_code || '.',
          p_reservation_id);

  -- Log the activity
  v_label := public._staff_label(v_actor_id);
  perform public.log_activity(
    v_res.branch_id, v_actor_id,
    coalesce(v_label, 'Staff'), public.my_staff_role()::text,
    'Confirmed reservation', 'reservation', v_res.reference_no
  );
end
$$;

-- =====================================================================
-- 3. REJECT RESERVATION
-- A licensed pharmacist rejects a pending reservation with a reason.
-- Nothing was held, so nothing is released.
-- =====================================================================
create or replace function public.reject_reservation(
  p_reservation_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_res record;
  v_label text;
begin
  -- Only staff with a valid license can reject
  if public.my_account_type() <> 'staff' then
    raise exception 'Only pharmacy staff can reject reservations';
  end if;
  if not public.has_valid_license() then
    raise exception 'A verified and unexpired pharmacist license is required';
  end if;

  -- Reason must be 5 to 200 characters
  if p_reason is null or length(trim(p_reason)) < 5 or length(trim(p_reason)) > 200 then
    raise exception 'Reason must be between 5 and 200 characters';
  end if;

  -- Look up the reservation and lock the row
  select * into v_res
  from public.reservations
  where id = p_reservation_id
  for update;

  if v_res is null then
    raise exception 'Reservation not found';
  end if;

  -- Must be at the same branch
  if v_res.branch_id <> public.my_branch_id() then
    raise exception 'This reservation belongs to a different branch';
  end if;

  -- Only pending reservations can be rejected (team rule: pending is rejected, not cancelled)
  if v_res.status <> 'pending' then
    raise exception 'Only pending reservations can be rejected';
  end if;

  -- Update the reservation
  update public.reservations
  set status = 'rejected',
      closed_reason = trim(p_reason),
      closed_by = v_actor_id
  where id = p_reservation_id;

  -- Record the status change
  insert into public.reservation_status_history
    (reservation_id, from_status, to_status, actor_id, actor_role, reason)
  values
    (p_reservation_id, 'pending', 'rejected', v_actor_id,
     public.my_staff_role()::text, trim(p_reason));

  -- Notify the customer
  insert into public.notifications (recipient_id, type, title, body, reservation_id)
  values (v_res.customer_id, 'reservation_rejected',
          'Reservation ' || v_res.reference_no || ' rejected',
          'Your reservation was rejected. Reason: ' || trim(p_reason),
          p_reservation_id);

  -- Log the activity
  v_label := public._staff_label(v_actor_id);
  perform public.log_activity(
    v_res.branch_id, v_actor_id,
    coalesce(v_label, 'Staff'), public.my_staff_role()::text,
    'Rejected reservation', 'reservation', v_res.reference_no,
    jsonb_build_object('reason', trim(p_reason))
  );
end
$$;

-- =====================================================================
-- 4. MARK READY FOR PICKUP
-- A staff member marks a confirmed reservation as ready for pickup.
-- =====================================================================
create or replace function public.mark_ready(p_reservation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_res record;
  v_label text;
begin
  -- Only pharmacy staff can mark ready
  if public.my_account_type() <> 'staff' then
    raise exception 'Only pharmacy staff can mark reservations as ready';
  end if;

  -- Look up the reservation and lock the row
  select * into v_res
  from public.reservations
  where id = p_reservation_id
  for update;

  if v_res is null then
    raise exception 'Reservation not found';
  end if;

  -- Must be at the same branch
  if v_res.branch_id <> public.my_branch_id() then
    raise exception 'This reservation belongs to a different branch';
  end if;

  -- Only confirmed reservations can be marked ready
  if v_res.status <> 'confirmed' then
    raise exception 'Only confirmed reservations can be marked as ready';
  end if;

  -- Update the reservation
  update public.reservations
  set status = 'ready_for_pickup',
      ready_at = now(),
      ready_by = v_actor_id
  where id = p_reservation_id;

  -- Record the status change
  insert into public.reservation_status_history
    (reservation_id, from_status, to_status, actor_id, actor_role)
  values
    (p_reservation_id, 'confirmed', 'ready_for_pickup', v_actor_id,
     public.my_staff_role()::text);

  -- Notify the customer
  insert into public.notifications (recipient_id, type, title, body, reservation_id)
  values (v_res.customer_id, 'reservation_ready',
          'Reservation ' || v_res.reference_no || ' is ready',
          'Your reservation is ready for pickup.',
          p_reservation_id);

  -- Log the activity
  v_label := public._staff_label(v_actor_id);
  perform public.log_activity(
    v_res.branch_id, v_actor_id,
    coalesce(v_label, 'Staff'), public.my_staff_role()::text,
    'Marked reservation ready for pickup', 'reservation', v_res.reference_no
  );
end
$$;

-- =====================================================================
-- 5. CHECK PICKUP CODE
-- Pharmacy staff verifies a pickup code without changing anything.
-- 5 wrong codes within 15 minutes locks that code for 15 minutes.
-- =====================================================================
create or replace function public.check_pickup_code(
  p_reservation_id uuid,
  p_code text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_res record;
  v_pickup record;
begin
  -- Only pharmacy staff can check codes
  if public.my_account_type() <> 'staff' then
    raise exception 'Only pharmacy staff can check pickup codes';
  end if;

  -- Look up the reservation
  select * into v_res
  from public.reservations
  where id = p_reservation_id;

  if v_res is null then
    raise exception 'Reservation not found';
  end if;

  -- Must be at the same branch
  if v_res.branch_id <> public.my_branch_id() then
    raise exception 'This reservation belongs to a different branch';
  end if;

  -- Only confirmed or ready reservations have a pickup code
  if v_res.status not in ('confirmed', 'ready_for_pickup') then
    raise exception 'This reservation does not have a pickup code yet';
  end if;

  -- Look up the pickup code and lock the row
  select * into v_pickup
  from public.pickup_codes
  where reservation_id = p_reservation_id
  for update;

  if v_pickup is null then
    raise exception 'Pickup code not found';
  end if;

  -- Check if the code is locked
  if v_pickup.locked_until is not null and v_pickup.locked_until > now() then
    raise exception 'Too many wrong attempts. Code is locked for 15 minutes.';
  end if;

  -- Already used
  if v_pickup.used_at is not null then
    raise exception 'This pickup code has already been used';
  end if;

  -- Compare the code
  if upper(trim(p_code)) = v_pickup.code_suffix then
    -- Correct: reset failed attempts (but don't mark as used; that's complete_reservation)
    update public.pickup_codes
    set failed_attempts = 0, locked_until = null
    where reservation_id = p_reservation_id;
    return true;
  else
    -- Wrong: count the failed attempt
    update public.pickup_codes
    set failed_attempts = failed_attempts + 1,
        locked_until = case
          when failed_attempts + 1 >= 5 then now() + interval '15 minutes'
          else locked_until
        end
    where reservation_id = p_reservation_id;
    return false;
  end if;
end
$$;

-- =====================================================================
-- 6. COMPLETE RESERVATION
-- Re-checks the pickup code, deducts stock from inventory, marks the
-- code as used, and completes the reservation in one transaction.
-- Releasing Rx items needs a valid pharmacist license.
-- =====================================================================
create or replace function public.complete_reservation(
  p_reservation_id uuid,
  p_code text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_res record;
  v_pickup record;
  v_item record;
  v_label text;
  v_has_rx boolean := false;
begin
  -- Only pharmacy staff can complete reservations
  if public.my_account_type() <> 'staff' then
    raise exception 'Only pharmacy staff can complete reservations';
  end if;

  -- Look up the reservation and lock the row
  select * into v_res
  from public.reservations
  where id = p_reservation_id
  for update;

  if v_res is null then
    raise exception 'Reservation not found';
  end if;

  -- Must be at the same branch
  if v_res.branch_id <> public.my_branch_id() then
    raise exception 'This reservation belongs to a different branch';
  end if;

  -- Only confirmed or ready reservations can be completed
  if v_res.status not in ('confirmed', 'ready_for_pickup') then
    raise exception 'Only confirmed or ready reservations can be completed';
  end if;

  -- Check if the reservation has Rx items
  select exists (
    select 1 from public.reservation_items
    where reservation_id = p_reservation_id and is_rx
  ) into v_has_rx;

  -- Releasing Rx items needs a valid license
  if v_has_rx and not public.has_valid_license() then
    raise exception 'A verified and unexpired pharmacist license is required to release Rx items';
  end if;

  -- Look up and verify the pickup code
  select * into v_pickup
  from public.pickup_codes
  where reservation_id = p_reservation_id
  for update;

  if v_pickup is null then
    raise exception 'Pickup code not found';
  end if;

  -- Check if the code is locked
  if v_pickup.locked_until is not null and v_pickup.locked_until > now() then
    raise exception 'Too many wrong attempts. Code is locked for 15 minutes.';
  end if;

  -- Already used
  if v_pickup.used_at is not null then
    raise exception 'This pickup code has already been used';
  end if;

  -- Compare the code
  if upper(trim(p_code)) <> v_pickup.code_suffix then
    -- Wrong: count failed attempt, then raise
    update public.pickup_codes
    set failed_attempts = failed_attempts + 1,
        locked_until = case
          when failed_attempts + 1 >= 5 then now() + interval '15 minutes'
          else locked_until
        end
    where reservation_id = p_reservation_id;
    raise exception 'Incorrect pickup code';
  end if;

  -- Code is correct: mark it as used
  update public.pickup_codes
  set used_at = now(), failed_attempts = 0, locked_until = null
  where reservation_id = p_reservation_id;

  -- Deduct stock and release holds for each item
  for v_item in
    select ri.line_no, ri.inventory_item_id, ri.quantity, ri.held_quantity
    from public.reservation_items ri
    where ri.reservation_id = p_reservation_id
    order by ri.line_no
  loop
    update public.inventory_items
    set stock_quantity = stock_quantity - v_item.quantity,
        held_quantity = held_quantity - v_item.held_quantity
    where id = v_item.inventory_item_id;

    -- Clear the held quantity on the reservation item
    update public.reservation_items
    set held_quantity = 0
    where reservation_id = p_reservation_id and line_no = v_item.line_no;
  end loop;

  -- Update the reservation status
  update public.reservations
  set status = 'completed',
      completed_at = now(),
      completed_by = v_actor_id
  where id = p_reservation_id;

  -- Record the status change
  insert into public.reservation_status_history
    (reservation_id, from_status, to_status, actor_id, actor_role)
  values
    (p_reservation_id, v_res.status, 'completed', v_actor_id,
     public.my_staff_role()::text);

  -- Notify the customer
  insert into public.notifications (recipient_id, type, title, body, reservation_id)
  values (v_res.customer_id, 'reservation_completed',
          'Reservation ' || v_res.reference_no || ' completed',
          'Your reservation has been released. Thank you!',
          p_reservation_id);

  -- Log the activity
  v_label := public._staff_label(v_actor_id);
  perform public.log_activity(
    v_res.branch_id, v_actor_id,
    coalesce(v_label, 'Staff'), public.my_staff_role()::text,
    'Completed reservation', 'reservation', v_res.reference_no
  );
end
$$;

-- =====================================================================
-- 7. CANCEL RESERVATION
-- An Owner or Pharmacist cancels a confirmed or ready-for-pickup
-- reservation with a reason. Releases any held stock.
-- =====================================================================
create or replace function public.cancel_reservation(
  p_reservation_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_res record;
  v_item record;
  v_label text;
  v_role text;
begin
  -- Only pharmacy staff can cancel
  if public.my_account_type() <> 'staff' then
    raise exception 'Only pharmacy staff can cancel reservations';
  end if;

  -- Only Owners and Pharmacists can cancel (not regular staff)
  v_role := public.my_staff_role()::text;
  if v_role not in ('owner', 'pharmacist') then
    raise exception 'Only the Owner or a Pharmacist can cancel reservations';
  end if;

  -- Reason must be 5 to 200 characters
  if p_reason is null or length(trim(p_reason)) < 5 or length(trim(p_reason)) > 200 then
    raise exception 'Reason must be between 5 and 200 characters';
  end if;

  -- Look up the reservation and lock the row
  select * into v_res
  from public.reservations
  where id = p_reservation_id
  for update;

  if v_res is null then
    raise exception 'Reservation not found';
  end if;

  -- Must be at the same branch
  if v_res.branch_id <> public.my_branch_id() then
    raise exception 'This reservation belongs to a different branch';
  end if;

  -- Only confirmed or ready-for-pickup reservations can be cancelled
  if v_res.status not in ('confirmed', 'ready_for_pickup') then
    raise exception 'Only confirmed or ready-for-pickup reservations can be cancelled';
  end if;

  -- Release held stock for each item
  for v_item in
    select ri.line_no, ri.inventory_item_id, ri.held_quantity
    from public.reservation_items ri
    where ri.reservation_id = p_reservation_id and ri.held_quantity > 0
    order by ri.line_no
  loop
    update public.inventory_items
    set held_quantity = held_quantity - v_item.held_quantity
    where id = v_item.inventory_item_id;

    update public.reservation_items
    set held_quantity = 0
    where reservation_id = p_reservation_id and line_no = v_item.line_no;
  end loop;

  -- Update the reservation
  update public.reservations
  set status = 'cancelled',
      closed_reason = trim(p_reason),
      closed_by = v_actor_id
  where id = p_reservation_id;

  -- Record the status change
  insert into public.reservation_status_history
    (reservation_id, from_status, to_status, actor_id, actor_role, reason)
  values
    (p_reservation_id, v_res.status, 'cancelled', v_actor_id,
     v_role, trim(p_reason));

  -- Notify the customer
  insert into public.notifications (recipient_id, type, title, body, reservation_id)
  values (v_res.customer_id, 'reservation_cancelled',
          'Reservation ' || v_res.reference_no || ' cancelled',
          'Your reservation was cancelled. Reason: ' || trim(p_reason),
          p_reservation_id);

  -- Log the activity
  v_label := public._staff_label(v_actor_id);
  perform public.log_activity(
    v_res.branch_id, v_actor_id,
    coalesce(v_label, 'Staff'), v_role,
    'Cancelled reservation', 'reservation', v_res.reference_no,
    jsonb_build_object('reason', trim(p_reason))
  );
end
$$;
