-- Treat emails and usernames the same, whether uppercase or lowercase
create extension if not exists citext with schema extensions;

-- Possible account statuses
create type public.account_state as enum
  ('active', 'pending_approval', 'rejected', 'suspended', 'deactivated');

-- Every user who can sign in
create table public.accounts (
  id uuid primary key references auth.users(id) on delete cascade,
  account_type public.account_type not null,
  username extensions.citext unique,
  state public.account_state not null default 'active',
  must_change_password boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Usernames: 4 to 20 letters, numbers, or underscores
  constraint username_format
    check (username is null or username::text ~ '^[A-Za-z0-9_]{4,20}$')
);

-- Customer personal details
create table public.customer_profiles (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  display_id text not null unique
    default ('CUS-' || lpad(nextval('public.customer_display_seq')::text, 6, '0')),
  first_name text not null,
  middle_name text,
  last_name text not null,
  mobile text not null unique,
  email extensions.citext not null unique,
  birthdate date not null,
  consent_version text not null,
  consented_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Names: 2 to 50 letters; spaces, ñ, hyphens, apostrophes, and periods allowed
  constraint name_format check (
    first_name ~ '^[A-Za-zÑñ .''-]{2,50}$'
    and last_name ~ '^[A-Za-zÑñ .''-]{2,50}$'
    and (middle_name is null or middle_name ~ '^[A-Za-zÑñ .''-]{2,50}$')
  ),
  -- Mobile numbers: 11 digits starting with 09
  constraint mobile_format check (mobile ~ '^09[0-9]{9}$')
);

-- Administrator details
create table public.admins (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  display_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Failed sign-in tracking: 5 wrong passwords locks the account for 15 minutes
create table public.auth_attempts (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  failed_count int not null default 0 check (failed_count >= 0),
  first_failed_at timestamptz,
  locked_until timestamptz
);

-- Record the time whenever a row is edited
create trigger accounts_updated_at before update on public.accounts
  for each row execute function public.set_updated_at();
create trigger customer_profiles_updated_at before update on public.customer_profiles
  for each row execute function public.set_updated_at();

-- Lock these tables until access rules are added
alter table public.accounts enable row level security;
alter table public.customer_profiles enable row level security;
alter table public.admins enable row level security;
alter table public.auth_attempts enable row level security;