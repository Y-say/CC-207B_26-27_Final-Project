-- Store pharmacy photos sourced from OpenStreetMap tags (image, wikimedia_commons, …).
alter table public.osm_listings
  add column if not exists image_url text;

comment on column public.osm_listings.image_url is
  'Optional photo URL from OSM tags when syncing via osm-sync.';

drop function if exists public.find_nearby_osm_listings(numeric, numeric, int);

create or replace function public.find_nearby_osm_listings(
  p_latitude numeric,
  p_longitude numeric,
  p_radius_meters int default 100
)
returns table (
  id uuid,
  osm_id text,
  name text,
  address text,
  latitude numeric,
  longitude numeric,
  distance_meters int,
  image_url text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    o.id,
    o.osm_id,
    o.name,
    o.address,
    o.latitude,
    o.longitude,
    round(
      6371000 * 2 * asin(sqrt(
        power(sin(radians((o.latitude - p_latitude) / 2)), 2) +
        cos(radians(p_latitude)) * cos(radians(o.latitude)) *
        power(sin(radians((o.longitude - p_longitude) / 2)), 2)
      ))
    )::int as distance_meters,
    o.image_url
  from public.osm_listings o
  where o.status = 'shown'
    and (
      6371000 * 2 * asin(sqrt(
        power(sin(radians((o.latitude - p_latitude) / 2)), 2) +
        cos(radians(p_latitude)) * cos(radians(o.latitude)) *
        power(sin(radians((o.longitude - p_longitude) / 2)), 2)
      ))
    ) <= coalesce(p_radius_meters, 100)
  order by distance_meters asc;
$$;

revoke execute on function public.find_nearby_osm_listings(numeric, numeric, int) from public;
grant execute on function public.find_nearby_osm_listings(numeric, numeric, int) to anon, authenticated;