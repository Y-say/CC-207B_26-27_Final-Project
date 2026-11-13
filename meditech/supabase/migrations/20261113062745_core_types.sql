-- 1. "Today" in Philippine time (used for license and LTO expiry checks)
create or replace function public.app_today()
returns date
language sql stable
set search_path = ''
as $$ select (now() at time zone 'Asia/Manila')::date $$;

-- 2. Fixed lists of allowed values (enums)
create type public.account_type as enum ('customer', 'staff', 'admin');
create type public.staff_role as enum ('owner', 'pharmacist', 'staff');
create type public.license_status as enum ('none', 'pending', 'verified', 'expired');
create type public.branch_status as enum ('pending_approval', 'active', 'inactive', 'rejected');
create type public.reservation_status as enum
  ('pending', 'confirmed', 'ready_for_pickup', 'completed', 'rejected', 'cancelled', 'expired');

-- 3. Counters for display IDs (CUS-000001, MED-000001…)
create sequence public.customer_display_seq;
create sequence public.medicine_display_seq;
create sequence public.branch_display_seq;

-- 4. Helper that stamps updated_at on every row change
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$ begin new.updated_at = now(); return new; end $$;