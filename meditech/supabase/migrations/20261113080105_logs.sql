-- Number counter for audit record IDs
create sequence public.audit_display_seq;

-- Kinds of platform events
create type public.audit_event_type as enum
  ('sign_in', 'failed_sign_in', 'account_security', 'pharmacy_application',
   'admin_action', 'data_export');

-- Platform and security events, seen only by administrators
create table public.audit_records (
  id uuid primary key default gen_random_uuid(),
  display_id text not null unique
    default ('AUD-' || lpad(nextval('public.audit_display_seq')::text, 6, '0')),
  actor_id uuid references public.accounts(id),
  actor_label text not null,
  actor_role text,
  event_type public.audit_event_type not null,
  action text not null,
  record_ref text,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index audit_records_by_time on public.audit_records (created_at desc);
create index audit_records_by_type on public.audit_records (event_type, created_at desc);

-- Each pharmacy's own history, seen only by its owner
create table public.activity_log (
  id bigint generated always as identity primary key,
  branch_id uuid not null references public.branches(id),
  actor_id uuid references public.accounts(id),
  actor_label text not null,
  actor_role text,
  action text not null,
  entity_type text,
  entity_id text,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index activity_log_by_branch on public.activity_log (branch_id, created_at desc);

-- Stop anyone from changing or deleting a log record
create or replace function public.block_log_changes()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Log records cannot be changed or deleted';
end
$$;

create trigger audit_records_locked
  before update or delete on public.audit_records
  for each row execute function public.block_log_changes();
create trigger audit_records_no_truncate
  before truncate on public.audit_records
  for each statement execute function public.block_log_changes();

create trigger activity_log_locked
  before update or delete on public.activity_log
  for each row execute function public.block_log_changes();
create trigger activity_log_no_truncate
  before truncate on public.activity_log
  for each statement execute function public.block_log_changes();

-- Add a platform event
create or replace function public.log_audit(
  p_actor_id uuid,
  p_actor_label text,
  p_actor_role text,
  p_event public.audit_event_type,
  p_action text,
  p_record_ref text,
  p_details jsonb default '{}'
)
returns void
language sql
set search_path = ''
as $$
  insert into public.audit_records
    (actor_id, actor_label, actor_role, event_type, action, record_ref, details)
  values
    (p_actor_id, p_actor_label, p_actor_role, p_event, p_action, p_record_ref, p_details);
$$;

-- Add a pharmacy event
create or replace function public.log_activity(
  p_branch_id uuid,
  p_actor_id uuid,
  p_actor_label text,
  p_actor_role text,
  p_action text,
  p_entity_type text,
  p_entity_id text,
  p_details jsonb default '{}'
)
returns void
language sql
set search_path = ''
as $$
  insert into public.activity_log
    (branch_id, actor_id, actor_label, actor_role, action, entity_type, entity_id, details)
  values
    (p_branch_id, p_actor_id, p_actor_label, p_actor_role, p_action,
     p_entity_type, p_entity_id, p_details);
$$;

-- Only the system may write logs, never the app directly
revoke execute on function public.log_audit(uuid, text, text, public.audit_event_type, text, text, jsonb)
  from public, anon, authenticated;
revoke execute on function public.log_activity(uuid, uuid, text, text, text, text, text, jsonb)
  from public, anon, authenticated;

-- Lock these tables until access rules are added
alter table public.audit_records enable row level security;
alter table public.activity_log enable row level security;