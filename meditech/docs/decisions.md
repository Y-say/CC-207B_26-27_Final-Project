# MediTech — Decision Register
---

## D-01 — When Inventory Stock Is Held

**Status:** Confirmed

**Decision:** Hold stock only upon pharmacist confirmation.

**Implementation Notes:**
- Reservation submission checks available stock but does not change `held_quantity`.
- When a pharmacist confirms the reservation, increase `held_quantity`.
- Align Plan §1 with §5.6 so both sections follow the same rule.

**Blocks:** T3-04, T3-07

---

## D-04 — Pharmacy Cancellation or Rejection of Pending Reservations

**Status:** Confirmed

**Decision:** Pharmacy users reject Pending reservations. System actions may cancel them.

**Implementation Notes:**
- Pharmacy users use the Reject action for Pending reservations.
- `cancel_reservation` accepts Pending reservations only for system actions, such as pharmacy deactivation.

**Blocks:** T7-04, T10-04

---

## D-06 — Pickup Verification Process

**Status:** Confirmed

**Decision:** Use two UI steps and one server-side completion transaction. Lock the pickup code after 5 incorrect attempts within 15 minutes.

**Implementation Notes:**
- `check_pickup_code` verifies the code without changing the reservation state.
- `complete_reservation` rechecks the code and completes the reservation in one transaction.
- Track failed attempts and lock the pickup code after 5 incorrect attempts within a 15-minute window.

**Blocks:** T3-09

---

## D-07 — Expired Pharmacist License and Existing Sessions

**Status:** Confirmed

**Decision:** Existing sessions remain active, but privileged actions are blocked when the pharmacist’s license expires.

**Implementation Notes:**
- Check license validity whenever a privileged action is performed.
- Require `license_status = verified` and `license_expiry >=` the current date in Asia/Manila.
- Existing sessions may continue, but Confirm, Reject, and prescription-release actions must be blocked after the next refresh when the license is expired.
- Previously completed actions remain valid.
- A nightly job updates the license status to Expired and displays a warning on the pharmacy owner's dashboard.

**Blocks:** T3-07, T8-02

---

## D-10 — Availability Label Precedence

**Status:** Confirmed

**Decision:** Apply the following availability-label priority, from highest to lowest:

1. Unavailable — switched off.
2. Unavailable — zero stock.
3. Unconfirmed — stale stock information.
4. Low Stock.
5. Available.

**Implementation Notes:**
- Apply the priority consistently wherever availability labels are displayed.
- Correct Wireframe Ph-21 to match this precedence.
- Unconfirmed medicines remain non-reservable, consistent with §3.3.

**Blocks:** T3-01, T6-03

---

## D-11 — What Resets the 7-Day Unconfirmed Timer

**Status:** Confirmed

**Decision:** Use `stock_confirmed_at` and `updated_at` separately. Only explicit stock confirmation resets the 7-day Unconfirmed timer.

**Implementation Notes:**
- Update `stock_confirmed_at` when a user saves a manual stock count, publishes an imported stock row (even if unchanged), or marks an item Back in Stock.
- Update `updated_at` whenever any medicine information changes.
- Price-only edits do not reset `stock_confirmed_at`.
- Automatic stock deductions after reservation completion do not reset `stock_confirmed_at`.

**Blocks:** T1-03, T6-01

---

## D-12 — Reservation Expiry Boundary

**Status:** Confirmed

**Decision:** A reservation expires exactly 7 days after submission.

**Implementation Notes:**
- Set `expires_at = submitted_at + 7 days`.
- Send the reminder 24 hours before `expires_at`.
- Run the expiry job every 10 minutes.
- Use a database row lock so that if expiry and completion race, whichever transaction commits first determines the outcome.

**Blocks:** T3-04, T7-05

---

## D-13 — Daily Reservation Reference Number

**Status:** Confirmed

**Decision:** Use the Asia/Manila date for the daily reference number and expand the sequence to five digits after 9,999.

**Implementation Notes:**
- Retain the `RM-MMDDYY-0001` reference-number pattern.
- Determine the date using the `Asia/Manila` timezone.
- Maintain a `daily_counters` row for each date.
- Increment the counter inside `submit_reservation` to prevent duplicate numbers during concurrent submissions.
- Expand the sequence to five digits when it exceeds 9,999 (for example, `10000`).
- Enforce a unique database constraint on `reference_no`.

**Blocks:** T1-04, T3-04

---

## D-14 — Manual Stock Edit Below Held Units

**Status:** Confirmed

**Decision:** Enforce `stock_quantity >= held_quantity` for every stock update. Resolve affected reservations before reducing stock below held units.

**Implementation Notes:**
- Apply the rule to manual edits, imports, and all other stock-update paths.
- Enforce the invariant at the database level.
- If physical stock is insufficient to cover held units, resolve the affected reservation(s), such as by cancelling them, before reducing the stock quantity.

**Blocks:** T1-03

---

## D-16 — Login Identifiers

**Status:** Confirmed

**Decision:** Use one `sign-in` Supabase Edge Function to support the required login identifiers.

**Implementation Notes:**

The function must:

1. Receive the user's identifier and password.
2. Resolve usernames or mobile numbers to the account email address.
3. Check account lockout rules.
4. Authenticate through Supabase Auth.
5. Write a login-attempt record to the audit log.

**Blocks:** T1-08, T2-06, T2-07

---

## D-20 — Rx Setting Changes

**Status:** Confirmed

**Decision:** Snapshot `is_rx`, medicine name, strength, dosage form, and unit in each reservation item at submission.

**Implementation Notes:**
- Store these values with the reservation item when the reservation is submitted.
- Later catalogue edits must not unexpectedly change the medicine details or prescription requirement recorded for an existing reservation.

**Blocks:** T1-04

---

## Register Summary

All 11 selected decisions have been confirmed.

- [x] D-01 — When Inventory Stock Is Held
- [x] D-04 — Pharmacy Cancellation or Rejection of Pending Reservations
- [x] D-06 — Pickup Verification Process
- [x] D-07 — Expired Pharmacist License and Existing Sessions
- [x] D-10 — Availability Label Precedence
- [x] D-11 — What Resets the 7-Day Unconfirmed Timer
- [x] D-12 — Reservation Expiry Boundary
- [x] D-13 — Daily Reservation Reference Number
- [x] D-14 — Manual Stock Edit Below Held Units
- [x] D-16 — Login Identifiers
- [x] D-20 — Rx Setting Changes