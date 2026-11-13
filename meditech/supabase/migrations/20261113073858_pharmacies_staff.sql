-- Number counter for staff IDs
create sequence public.staff_display_seq;

-- Each pharmacy branch
create table public.branches (
  id uuid primary key default gen_random_uuid(),
  display_id text not null unique
    default ('PHM-' || lpad(nextval('public.branch_display_seq')::text, 6, '0')),
  pharmacy_name text not null,
  branch_name text not null,
  address text not null,
  contact_number text not null,
  email extensions.citext not null,
  latitude numeric(9,6) not null,
  longitude numeric(9,6) not null,
  status public.branch_status not null default 'pending_approval',
  lto_number text not null unique,
  lto_expiry date not null,
  possible_duplicate boolean not null default false,
  rejection_reason text,
  deactivation_reason text,
  submitted_at timestamptz not null default now(),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Contact number: digits only, starting with 0 (landline or mobile)
  constraint contact_format check (contact_number ~ '^0[0-9]{9,10}$'),
  -- Map pin must be a real location
  constraint latitude_range check (latitude between -90 and 90),
  constraint longitude_range check (longitude between -180 and 180),
  -- Reasons must be 5 to 200 characters
  constraint rejection_reason_length
    check (rejection_reason is null or length(rejection_reason) between 5 and 200),
  constraint deactivation_reason_length
    check (deactivation_reason is null or length(deactivation_reason) between 5 and 200)
);

-- Opening hours for each day of the week (0 = Sunday, 6 = Saturday)
create table public.branch_hours (
  branch_id uuid not null references public.branches(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  opens_at time,
  closes_at time,
  is_closed boolean not null default false,
  primary key (branch_id, weekday),
  -- An open day needs both opening and closing times
  constraint hours_complete
    check (is_closed or (opens_at is not null and closes_at is not null))
);

-- Owners, pharmacists, and staff of a branch
create table public.staff_members (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  display_id text not null unique
    default ('EMP-' || lpad(nextval('public.staff_display_seq')::text, 6, '0')),
  branch_id uuid not null references public.branches(id) on delete restrict,
  role public.staff_role not null,
  first_name text not null,
  middle_name text,
  last_name text not null,
  prc_license_no text,
  prc_license_expiry date,
  license_status public.license_status not null default 'none',
  license_verified_by uuid references public.accounts(id),
  license_verified_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Names: 2 to 50 letters; spaces, ñ, hyphens, apostrophes, and periods allowed
  constraint staff_name_format check (
    first_name ~ '^[A-Za-zÑñ .''-]{2,50}$'
    and last_name ~ '^[A-Za-zÑñ .''-]{2,50}$'
    and (middle_name is null or middle_name ~ '^[A-Za-zÑñ .''-]{2,50}$')
  ),
  -- PRC license number: exactly 7 digits
  constraint prc_format check (prc_license_no is null or prc_license_no ~ '^[0-9]{7}$'),
  -- Pharmacists must have a license number
  constraint pharmacist_has_license
    check (role <> 'pharmacist' or prc_license_no is not null),
  -- A verified license needs both a number and an expiry date
  constraint verified_license_complete check (
    license_status <> 'verified'
    or (prc_license_no is not null and prc_license_expiry is not null)
  )
);

-- Only one owner per branch
create unique index one_owner_per_branch
  on public.staff_members (branch_id) where role = 'owner';

-- Faster lookups of a branch's staff
create index staff_members_branch on public.staff_members (branch_id);

-- Record the time whenever a row is edited
create trigger branches_updated_at before update on public.branches
  for each row execute function public.set_updated_at();
create trigger staff_members_updated_at before update on public.staff_members
  for each row execute function public.set_updated_at();

-- Lock these tables until access rules are added
alter table public.branches enable row level security;
alter table public.branch_hours enable row level security;
alter table public.staff_members enable row level security;