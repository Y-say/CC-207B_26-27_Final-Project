-- Number counter for inventory IDs
create sequence public.inventory_display_seq;

-- Possible medicine statuses
create type public.medicine_status as enum ('draft', 'active', 'inactive');

-- What customers see about a medicine's stock
create type public.availability_status as enum
  ('available', 'low_stock', 'unavailable', 'unconfirmed');

-- List of dosage forms (tablet, syrup, and so on)
create table public.dosage_forms (
  id smallint generated always as identity primary key,
  name text not null unique
);

-- List of selling units (per tablet, per bottle, and so on)
create table public.units (
  id smallint generated always as identity primary key,
  name text not null unique
);

-- Starting values for both lists
insert into public.dosage_forms (name) values
  ('Tablet'), ('Capsule'), ('Syrup'), ('Suspension'), ('Solution'), ('Cream'), ('Drops');
insert into public.units (name) values
  ('tablet'), ('capsule'), ('bottle'), ('tube'), ('sachet'), ('vial');

-- The shared medicine list every pharmacy picks from
create table public.medicines (
  id uuid primary key default gen_random_uuid(),
  display_id text not null unique
    default ('MED-' || lpad(nextval('public.medicine_display_seq')::text, 6, '0')),
  brand_name text not null,
  generic_name text not null,
  strength text not null,
  dosage_form_id smallint not null references public.dosage_forms(id),
  unit_sold_id smallint not null references public.units(id),
  pack_description text,
  is_rx boolean not null default false,
  status public.medicine_status not null default 'draft',
  deactivation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A pharmacy's stock and price for one medicine
create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  display_id text not null unique
    default ('INV-' || lpad(nextval('public.inventory_display_seq')::text, 6, '0')),
  branch_id uuid not null references public.branches(id) on delete cascade,
  medicine_id uuid not null references public.medicines(id),
  stock_quantity int not null default 0,
  held_quantity int not null default 0,
  price_per_unit numeric not null,
  low_stock_threshold int not null default 10,
  nearest_expiry date,
  out_of_stock_flag boolean not null default false,
  is_active boolean not null default true,
  stock_confirmed_at timestamptz not null default now(),
  updated_by uuid references public.accounts(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Each medicine appears only once per pharmacy
  constraint one_listing_per_medicine unique (branch_id, medicine_id),
  -- Stock and held units can't go below zero
  constraint stock_not_negative check (stock_quantity >= 0),
  constraint held_not_negative check (held_quantity >= 0),
  -- Reserved units can never be more than the stock
  constraint held_within_stock check (held_quantity <= stock_quantity),
  -- Price must be above zero, with at most 2 decimal places
  constraint price_valid check (price_per_unit > 0 and price_per_unit = round(price_per_unit, 2)),
  -- Low-stock level must be at least 1
  constraint threshold_valid check (low_stock_threshold >= 1)
);

-- Faster search for pharmacies carrying a medicine
create index inventory_by_medicine on public.inventory_items (medicine_id) where is_active;

-- Work out the label customers see, in this order:
-- switched off → no stock left → not updated in 7 days → low stock → available
create or replace function public.availability_of(
  stock int, held int, threshold int, out_of_stock boolean, confirmed_at timestamptz
)
returns public.availability_status
language sql stable
set search_path = ''
as $$
  select case
    when out_of_stock then 'unavailable'::public.availability_status
    when stock - held <= 0 then 'unavailable'::public.availability_status
    when confirmed_at < now() - interval '7 days' then 'unconfirmed'::public.availability_status
    when stock - held <= threshold then 'low_stock'::public.availability_status
    else 'available'::public.availability_status
  end
$$;

-- Public window: only approved pharmacies, active medicines, and active listings,
-- and only the details customers are allowed to see (no stock counts)
create view public.public_availability as
select
  i.id as inventory_id,
  i.branch_id,
  i.medicine_id,
  i.price_per_unit,
  public.availability_of(i.stock_quantity, i.held_quantity, i.low_stock_threshold,
                         i.out_of_stock_flag, i.stock_confirmed_at) as availability,
  i.stock_confirmed_at
from public.inventory_items i
join public.branches b on b.id = i.branch_id and b.status = 'active'
join public.medicines m on m.id = i.medicine_id and m.status = 'active'
where i.is_active;

-- Record the time whenever a row is edited
create trigger medicines_updated_at before update on public.medicines
  for each row execute function public.set_updated_at();
create trigger inventory_items_updated_at before update on public.inventory_items
  for each row execute function public.set_updated_at();

-- Lock these tables until access rules are added
alter table public.dosage_forms enable row level security;
alter table public.units enable row level security;
alter table public.medicines enable row level security;
alter table public.inventory_items enable row level security;