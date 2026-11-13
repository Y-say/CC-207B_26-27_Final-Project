-- Number counters for prescription and notification IDs
create sequence public.prescription_display_seq;
create sequence public.notification_display_seq;

-- Each customer's cart (one pharmacy per cart)
create table public.carts (
  customer_id uuid primary key references public.accounts(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  updated_at timestamptz not null default now()
);

-- Medicines inside a cart
create table public.cart_items (
  customer_id uuid not null references public.carts(customer_id) on delete cascade,
  medicine_id uuid not null references public.medicines(id),
  quantity int not null check (quantity > 0),
  added_at timestamptz not null default now(),
  primary key (customer_id, medicine_id)
);

-- Prescription photos uploaded before placing a reservation
create table public.cart_prescription_files (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.accounts(id) on delete cascade,
  storage_path text not null,
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'application/pdf')),
  size_bytes int not null check (size_bytes between 1 and 5242880),
  uploaded_at timestamptz not null default now()
);

-- Each reservation
create table public.reservations (
  id uuid primary key default gen_random_uuid(),
  reference_no text not null unique,
  customer_id uuid not null references public.accounts(id),
  branch_id uuid not null references public.branches(id),
  status public.reservation_status not null default 'pending',
  has_rx boolean not null default false,
  total_amount numeric not null check (total_amount >= 0),
  submitted_at timestamptz not null default now(),
  expires_at timestamptz not null,
  confirmed_at timestamptz,
  confirmed_by uuid references public.accounts(id),
  ready_at timestamptz,
  ready_by uuid references public.accounts(id),
  completed_at timestamptz,
  completed_by uuid references public.accounts(id),
  closed_reason text,
  closed_by uuid references public.accounts(id),
  reminder_sent_at timestamptz,
  idempotency_key uuid not null,
  updated_at timestamptz not null default now(),
  -- Reference number looks like RM-111326-0001
  constraint reference_format check (reference_no ~ '^RM-[0-9]{6}-[0-9]{4,5}$'),
  -- Reservations expire exactly 7 days after they are placed
  constraint expires_in_7_days check (expires_at = submitted_at + interval '7 days'),
  -- Rejection or cancellation reasons must be 5 to 200 characters
  constraint reason_length
    check (closed_reason is null or length(closed_reason) between 5 and 200),
  -- Pressing "Place reservation" twice can't create two reservations
  constraint one_reservation_per_tap unique (customer_id, idempotency_key)
);

-- Faster lists for pharmacies, customers, and the expiry check
create index reservations_by_branch on public.reservations (branch_id, status, submitted_at desc);
create index reservations_by_customer on public.reservations (customer_id, status);
create index reservations_by_expiry on public.reservations (status, expires_at);

-- Medicines in a reservation, with details saved as they were when placed
create table public.reservation_items (
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  line_no smallint not null,
  medicine_id uuid not null references public.medicines(id),
  inventory_item_id uuid not null references public.inventory_items(id),
  quantity int not null check (quantity > 0),
  held_quantity int not null default 0,
  brand_name text not null,
  generic_name text not null,
  strength text not null,
  dosage_form text not null,
  unit_sold text not null,
  is_rx boolean not null,
  unit_price numeric not null,
  primary key (reservation_id, line_no),
  -- Reserved units can't be negative or more than what was ordered
  constraint held_within_quantity check (held_quantity between 0 and quantity),
  -- Saved price must be above zero, with at most 2 decimal places
  constraint unit_price_valid check (unit_price > 0 and unit_price = round(unit_price, 2))
);

-- Pickup codes, kept apart so pharmacy staff can't read them
create table public.pickup_codes (
  reservation_id uuid primary key references public.reservations(id) on delete cascade,
  code_suffix text not null,
  failed_attempts int not null default 0 check (failed_attempts >= 0),
  locked_until timestamptz,
  used_at timestamptz,
  created_at timestamptz not null default now(),
  -- 4 characters, leaving out look-alikes such as O, 0, I, and 1
  constraint code_format check (code_suffix ~ '^[A-HJ-NP-Z2-9]{4}$')
);

-- Prescriptions attached to a placed reservation
create table public.reservation_prescriptions (
  id uuid primary key default gen_random_uuid(),
  display_id text not null unique
    default ('PRX-' || lpad(nextval('public.prescription_display_seq')::text, 6, '0')),
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  storage_path text not null,
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'application/pdf')),
  size_bytes int not null check (size_bytes between 1 and 5242880),
  uploaded_at timestamptz not null default now()
);

-- Every status change, who made it, and why
create table public.reservation_status_history (
  id bigint generated always as identity primary key,
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  from_status public.reservation_status,
  to_status public.reservation_status not null,
  actor_id uuid references public.accounts(id),
  actor_role text,
  reason text,
  created_at timestamptz not null default now()
);
create index status_history_by_reservation on public.reservation_status_history (reservation_id);

-- Daily counters for reservation numbers
create table public.daily_counters (
  counter_date date not null,
  kind text not null,
  last_value int not null check (last_value >= 0),
  primary key (counter_date, kind)
);

-- In-app notifications
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  display_id text not null unique
    default ('NTF-' || lpad(nextval('public.notification_display_seq')::text, 6, '0')),
  recipient_id uuid not null references public.accounts(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  reservation_id uuid references public.reservations(id) on delete cascade,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  -- Stops the same reminder from being sent twice
  dedupe_key text unique
);
create index notifications_by_recipient on public.notifications (recipient_id, created_at desc);

-- Give the next reservation number for today (Philippine time)
create or replace function public.next_reference_number()
returns text
language plpgsql
set search_path = ''
as $$
declare
  today date := public.app_today();
  n int;
begin
  insert into public.daily_counters (counter_date, kind, last_value)
  values (today, 'reservation', 1)
  on conflict (counter_date, kind)
  do update set last_value = public.daily_counters.last_value + 1
  returning last_value into n;

  return 'RM-' || to_char(today, 'MMDDYY') || '-' ||
    case when n > 9999 then n::text else lpad(n::text, 4, '0') end;
end
$$;

-- Only the system may hand out reservation numbers
revoke execute on function public.next_reference_number() from public, anon, authenticated;

-- Record the time whenever a row is edited
create trigger carts_updated_at before update on public.carts
  for each row execute function public.set_updated_at();
create trigger reservations_updated_at before update on public.reservations
  for each row execute function public.set_updated_at();

-- Lock these tables until access rules are added
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.cart_prescription_files enable row level security;
alter table public.reservations enable row level security;
alter table public.reservation_items enable row level security;
alter table public.pickup_codes enable row level security;
alter table public.reservation_prescriptions enable row level security;
alter table public.reservation_status_history enable row level security;
alter table public.daily_counters enable row level security;
alter table public.notifications enable row level security;