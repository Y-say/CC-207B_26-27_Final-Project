-- Owner's mobile number (shown to admins when reviewing)
alter table public.staff_members add column mobile text;
alter table public.staff_members add constraint staff_mobile_format
  check (mobile is null or mobile ~ '^09[0-9]{9}$');

-- Kinds of pharmacy documents
create type public.document_kind as enum ('lto', 'storefront', 'lto_renewal');

-- Files sent with a pharmacy application
create table public.branch_documents (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  kind public.document_kind not null,
  storage_path text not null,
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'application/pdf')),
  size_bytes int not null check (size_bytes between 1 and 5242880),
  uploaded_by uuid references public.accounts(id),
  uploaded_at timestamptz not null default now()
);
create index branch_documents_by_branch on public.branch_documents (branch_id);
alter table public.branch_documents enable row level security;

-- Admins see all documents; owners see their own branch's
create policy "Admins see documents" on public.branch_documents
  for select to authenticated using (public.is_admin());
create policy "Owner sees own documents" on public.branch_documents
  for select to authenticated
  using (branch_id = public.my_branch_id() and public.my_staff_role() = 'owner');

-- Private storage for pharmacy documents: photos or PDFs, 5 MB at most
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pharmacy-documents', 'pharmacy-documents', false, 5242880,
        array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do nothing;

-- Admins can open any pharmacy document; owners only their own
create policy "Admins read pharmacy documents" on storage.objects
  for select to authenticated
  using (bucket_id = 'pharmacy-documents' and public.is_admin());
create policy "Owner reads own pharmacy documents" on storage.objects
  for select to authenticated
  using (bucket_id = 'pharmacy-documents'
         and (storage.foldername(name))[1] = public.my_branch_id()::text
         and public.my_staff_role() = 'owner');

-- Save a whole pharmacy application at once
create or replace function public.create_pharmacy_application(p jsonb)
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  owner_id uuid := (p->>'account_id')::uuid;
  new_branch uuid := (p->>'branch_id')::uuid;
  owner_name text := (p->>'first_name') || ' ' || (p->>'last_name');
  new_display_id text;
begin
  -- An expired license can't be submitted
  if (p->>'lto_expiry')::date < public.app_today() then
    raise exception 'LTO_EXPIRED';
  end if;

  -- The owner's account, waiting for approval
  insert into public.accounts (id, account_type, username, state)
  values (owner_id, 'staff', p->>'username', 'pending_approval');

  -- The branch, waiting for approval
  insert into public.branches
    (id, pharmacy_name, branch_name, address, contact_number, email,
     latitude, longitude, lto_number, lto_expiry)
  values
    (new_branch, p->>'pharmacy_name', p->>'branch_name', p->>'address',
     p->>'contact_number', p->>'pharmacy_email',
     (p->>'latitude')::numeric, (p->>'longitude')::numeric,
     p->>'lto_number', (p->>'lto_expiry')::date)
  returning display_id into new_display_id;

  -- Opening hours, one row per day
  insert into public.branch_hours (branch_id, weekday, opens_at, closes_at, is_closed)
  select new_branch, (h->>'weekday')::smallint, (h->>'opens_at')::time,
         (h->>'closes_at')::time, coalesce((h->>'is_closed')::boolean, false)
  from jsonb_array_elements(p->'hours') as h;

  -- The owner
  insert into public.staff_members
    (account_id, branch_id, role, first_name, middle_name, last_name, mobile)
  values
    (owner_id, new_branch, 'owner', p->>'first_name', nullif(p->>'middle_name', ''),
     p->>'last_name', p->>'mobile');

  -- The two documents
  insert into public.branch_documents
    (branch_id, kind, storage_path, mime_type, size_bytes, uploaded_by)
  values
    (new_branch, 'lto', p->>'lto_path', p->>'lto_mime', (p->>'lto_size')::int, owner_id),
    (new_branch, 'storefront', p->>'storefront_path', p->>'storefront_mime',
     (p->>'storefront_size')::int, owner_id);

  -- Record the application for admins
  perform public.log_audit(owner_id, owner_name, 'owner', 'pharmacy_application',
    'Submitted a pharmacy application', new_display_id);

  return new_display_id;
end
$$;

-- Only the server function may save applications
revoke execute on function public.create_pharmacy_application(jsonb) from public, anon, authenticated;
grant execute on function public.create_pharmacy_application(jsonb) to service_role;