-- ===========================================================================
-- TuklasRizal — Level 4 Admin & User Approvals
-- ===========================================================================
-- Idempotent migration backing the web admin "Admin & User Approvals" screen.
-- Safe to run more than once against the live Supabase project.
--
-- Adds:
--   * approval audit columns on public.users (approval_status, approved_at,
--     approved_by),
--   * a SECURITY DEFINER helper that answers "is the caller a Level 4 /
--     Provincial Super Admin?",
--   * RLS policies so Level 4 admins can read every profile and update roles
--     and approval state, while everyone else keeps their existing access,
--   * a trigger that stamps the audit columns whenever is_approved changes.
--
-- The web admin degrades gracefully if this file has not been applied yet:
-- `select('*')` simply returns no approval_status key and the UI derives the
-- status from is_approved.
-- ===========================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Audit columns
-- ---------------------------------------------------------------------------
alter table public.users
  add column if not exists approval_status text,
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid;

-- Applicant-submitted verification details (mobile "Apply as an LGU
-- Coordinator" and the web admin "Request Higher Access" form).
alter table public.users
  add column if not exists requested_role_tier integer,
  add column if not exists requested_municipality text,
  add column if not exists department_office text,
  add column if not exists official_position text,
  add column if not exists contact_number text,
  add column if not exists request_reason text,
  add column if not exists verification_doc_urls text[] default '{}',
  add column if not exists review_notes text,
  add column if not exists verified_lgu_id boolean default false,
  add column if not exists verified_endorsement boolean default false,
  add column if not exists requested_at timestamptz;

-- Backfill existing rows from the single source of truth we already trust.
update public.users
set approval_status = case
  when is_approved then 'approved'
  else 'pending'
end
where approval_status is null;

alter table public.users
  alter column approval_status set default 'pending';

update public.users
set approval_status = 'pending'
where approval_status is null;

alter table public.users
  drop constraint if exists users_approval_status_check;

alter table public.users
  add constraint users_approval_status_check
  check (approval_status in ('pending', 'approved', 'rejected'));

create index if not exists users_approval_status_idx
  on public.users (approval_status);

-- ---------------------------------------------------------------------------
-- 2. Role helper — SECURITY DEFINER so the RLS policy can read public.users
--    without recursing into its own policy.
-- ---------------------------------------------------------------------------
create or replace function public.is_level4_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role_tier >= 4
      and u.is_approved = true
  );
$$;

revoke all on function public.is_level4_admin() from public;
grant execute on function public.is_level4_admin() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Audit trigger — keeps approved_at / approved_by honest no matter which
--    client performs the update (web admin portal, SQL editor, RPC).
-- ---------------------------------------------------------------------------
create or replace function public.stamp_user_approval()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_approved is distinct from old.is_approved then
    new.approved_at := now();
    new.approved_by := auth.uid();
    if new.is_approved then
      new.approval_status := 'approved';
    elsif new.approval_status is distinct from 'pending' then
      new.approval_status := 'rejected';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_stamp_user_approval on public.users;
create trigger trg_stamp_user_approval
  before update of is_approved on public.users
  for each row
  execute function public.stamp_user_approval();

-- RLS cannot restrict columns, so applicants may write their request fields on
-- their own row but must never be able to self-approve. This trigger forces the
-- privileged columns back to their previous values for non-Level-4 callers.
create or replace function public.guard_user_self_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null
     and auth.uid() = old.id
     and not public.is_level4_admin() then
    new.role_tier := old.role_tier;
    new.role_title := old.role_title;
    new.is_approved := old.is_approved;
    new.municipality_id := old.municipality_id;
    new.barangay_id := old.barangay_id;
    new.approved_at := old.approved_at;
    new.approved_by := old.approved_by;
    if new.approval_status is distinct from 'pending'
       and new.approval_status is distinct from 'rejected' then
      new.approval_status := old.approval_status;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_user_self_update on public.users;
create trigger trg_guard_user_self_update
  before update on public.users
  for each row
  execute function public.guard_user_self_update();

-- ---------------------------------------------------------------------------
-- 4. RLS policies for Level 4 administration
-- ---------------------------------------------------------------------------
alter table public.users enable row level security;

drop policy if exists "level4_read_all_users" on public.users;
create policy "level4_read_all_users"
  on public.users
  for select
  to authenticated
  using (public.is_level4_admin());

drop policy if exists "level4_update_users" on public.users;
create policy "level4_update_users"
  on public.users
  for update
  to authenticated
  using (public.is_level4_admin())
  with check (public.is_level4_admin());

-- Applicants may submit/refresh their own access request while it is pending.
-- They cannot change role_tier or is_approved: the columns they write are the
-- request_* fields, and approval decisions stay with Level 4.
drop policy if exists "applicant_update_own_request" on public.users;
create policy "applicant_update_own_request"
  on public.users
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- 5. Private verification-document bucket
--    Applicants upload into <auth.uid()>/<file>; only the owner and Level 4
--    admins can read them. The bucket is NOT public.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'admin-verification-docs',
  'admin-verification-docs',
  false,
  10485760, -- 10 MB per document
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "verification_docs_owner_insert" on storage.objects;
create policy "verification_docs_owner_insert" on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'admin-verification-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "verification_docs_read" on storage.objects;
create policy "verification_docs_read" on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'admin-verification-docs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_level4_admin()
    )
  );

drop policy if exists "verification_docs_owner_delete" on storage.objects;
create policy "verification_docs_owner_delete" on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'admin-verification-docs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_level4_admin()
    )
  );

commit;

-- ===========================================================================
-- Verification (read-only)
-- ===========================================================================
-- select id, email, full_name, role_tier, is_approved, approval_status,
--        municipality_id, requested_role_tier, requested_municipality,
--        department_office, official_position, contact_number,
--        verification_doc_urls, review_notes, approved_at, approved_by
-- from public.users
-- order by created_at desc
-- limit 50;
--
-- select public.is_level4_admin();
-- ===========================================================================
