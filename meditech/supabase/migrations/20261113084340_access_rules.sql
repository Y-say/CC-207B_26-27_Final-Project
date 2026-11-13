-- ===== Accounts =====

-- Users see their own account; admins see all accounts
create policy "Own account" on public.accounts
  for select to authenticated using (id = auth.uid());
create policy "Admins see accounts" on public.accounts
  for select to authenticated using (public.is_admin());

-- Customers see only their own profile
create policy "Own profile" on public.customer_profiles
  for select to authenticated using (account_id = auth.uid());

-- Admins see the admin list
create policy "Admins see admins" on public.admins
  for select to authenticated using (public.is_admin());

-- auth_attempts has no rules: only the sign-in system uses it

-- ===== Pharmacies and staff =====

-- Staff see their own branch; admins see all branches
create policy "Own branch" on public.branches
  for select to authenticated using (id = public.my_branch_id());
create policy "Admins see branches" on public.branches
  for select to authenticated using (public.is_admin());

-- Staff see their own branch's hours; admins see all
create policy "Own branch hours" on public.branch_hours
  for select to authenticated using (branch_id = public.my_branch_id());
create policy "Admins see hours" on public.branch_hours
  for select to authenticated using (public.is_admin());

-- Staff see co-workers in their branch; admins see only owners
create policy "Same branch staff" on public.staff_members
  for select to authenticated using (branch_id = public.my_branch_id());
create policy "Own staff record" on public.staff_members
  for select to authenticated using (account_id = auth.uid());
create policy "Admins see owners" on public.staff_members
  for select to authenticated using (public.is_admin() and role = 'owner');

-- ===== Catalogue and inventory =====

-- Everyone can read the dosage form and unit lists
create policy "Anyone reads dosage forms" on public.dosage_forms
  for select to anon, authenticated using (true);
create policy "Anyone reads units" on public.units
  for select to anon, authenticated using (true);

-- Everyone sees active medicines; admins see all, including drafts
create policy "Anyone reads active medicines" on public.medicines
  for select to anon, authenticated using (status = 'active');
create policy "Admins see all medicines" on public.medicines
  for select to authenticated using (public.is_admin());

-- Only a branch's own staff see its inventory (admins never do)
create policy "Own branch inventory" on public.inventory_items
  for select to authenticated using (branch_id = public.my_branch_id());

-- ===== Carts =====

create policy "Own cart" on public.carts
  for select to authenticated using (customer_id = auth.uid());
create policy "Own cart items" on public.cart_items
  for select to authenticated using (customer_id = auth.uid());
create policy "Own cart prescriptions" on public.cart_prescription_files
  for select to authenticated using (customer_id = auth.uid());

-- ===== Reservations =====

-- Customers see their own reservations; staff see their branch's (admins never do)
create policy "Own reservations" on public.reservations
  for select to authenticated using (customer_id = auth.uid());
create policy "Branch reservations" on public.reservations
  for select to authenticated using (branch_id = public.my_branch_id());

-- Reservation details follow the reservation they belong to
create policy "Visible reservation items" on public.reservation_items
  for select to authenticated
  using (exists (select 1 from public.reservations r where r.id = reservation_id));
create policy "Visible reservation prescriptions" on public.reservation_prescriptions
  for select to authenticated
  using (exists (select 1 from public.reservations r where r.id = reservation_id));
create policy "Visible status history" on public.reservation_status_history
  for select to authenticated
  using (exists (select 1 from public.reservations r where r.id = reservation_id));

-- Only the customer can see their pickup code, never the pharmacy
create policy "Own pickup code" on public.pickup_codes
  for select to authenticated
  using (exists (select 1 from public.reservations r
                 where r.id = reservation_id and r.customer_id = auth.uid()));

-- daily_counters has no rules: only the system uses it

-- ===== Notifications =====

-- Users see their own notifications
create policy "Own notifications" on public.notifications
  for select to authenticated using (recipient_id = auth.uid());

-- Users can mark their own notifications as read, and change nothing else
create policy "Mark own notifications read" on public.notifications
  for update to authenticated
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

-- ===== Logs =====

-- Only admins see platform records
create policy "Admins see audit records" on public.audit_records
  for select to authenticated using (public.is_admin());

-- Only the branch owner sees the pharmacy's activity log
create policy "Owner sees activity log" on public.activity_log
  for select to authenticated
  using (branch_id = public.my_branch_id() and public.my_staff_role() = 'owner');

-- ===== Public views for guests and customers =====

-- Approved pharmacies, without private details
create view public.public_branches as
select id, display_id, pharmacy_name, branch_name, address, contact_number,
       latitude, longitude
from public.branches
where status = 'active';

-- Opening hours of approved pharmacies
create view public.public_branch_hours as
select h.branch_id, h.weekday, h.opens_at, h.closes_at, h.is_closed
from public.branch_hours h
join public.branches b on b.id = h.branch_id and b.status = 'active';

-- Anyone may read the public views
grant select on public.public_branches, public.public_branch_hours, public.public_availability
  to anon, authenticated;