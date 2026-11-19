-- ===========================================================================
-- TuklasRizal — Community review guardrails (anti-abuse)
-- ===========================================================================
-- Idempotent migration for public.event_reviews. Safe to re-run.
--
-- Enforces, server-side, everything the mobile app checks in the UI:
--   * one review per user per event         -> UNIQUE (event_id, user_id)
--   * the reviewer must not be the organizer -> events.created_by <> auth.uid()
--   * the event must have started            -> events.start_date <= now()
--   * the reviewer must have RSVP'd "going"  -> event_participation.status
--   * rating 1–5 and comment 10–500 chars    -> CHECK constraints + policy
--
-- The mobile app writes `author_name` and `review_text`; both are kept.
-- ===========================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Table (created only if the project never provisioned it)
-- ---------------------------------------------------------------------------
create table if not exists public.event_reviews (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  author_name text,
  rating integer not null default 5,
  review_text text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Older deployments may predate some columns.
alter table public.event_reviews
  add column if not exists author_name text,
  add column if not exists user_id uuid,
  add column if not exists updated_at timestamptz default now();

-- Deduplicate before adding the unique constraint so the script is safe on a
-- table that already accumulated duplicate rows.
do $$
begin
  delete from public.event_reviews a
  using public.event_reviews b
  where a.event_id = b.event_id
    and a.user_id = b.user_id
    and a.user_id is not null
    and a.ctid < b.ctid;
exception
  when undefined_table then null;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'event_reviews_event_id_user_id_key'
      and conrelid = 'public.event_reviews'::regclass
  ) then
    alter table public.event_reviews
      add constraint event_reviews_event_id_user_id_key
      unique (event_id, user_id);
  end if;
end;
$$;

-- Data sanity constraints (idempotent).
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'event_reviews_rating_check'
      and conrelid = 'public.event_reviews'::regclass
  ) then
    alter table public.event_reviews
      add constraint event_reviews_rating_check check (rating between 1 and 5);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'event_reviews_comment_length_check'
      and conrelid = 'public.event_reviews'::regclass
  ) then
    alter table public.event_reviews
      add constraint event_reviews_comment_length_check
      check (char_length(btrim(review_text)) between 10 and 500);
  end if;
end;
$$;

create index if not exists event_reviews_event_idx
  on public.event_reviews (event_id);

-- ---------------------------------------------------------------------------
-- 2. Eligibility helper — SECURITY DEFINER so the RLS policy can read events
--    and event_participation without depending on the caller's row visibility.
-- ---------------------------------------------------------------------------
create or replace function public.can_review_event(target_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1
      from public.events e
      where e.id = target_event_id
        and e.created_by is distinct from auth.uid()
        and e.start_date <= now()
        and coalesce(e.status::text, 'approved') <> 'cancelled'
    )
    and exists (
      select 1
      from public.event_participation p
      where p.event_id = target_event_id
        and p.user_id = auth.uid()
        and p.status = 'going'
    );
$$;

revoke all on function public.can_review_event(uuid) from public;
grant execute on function public.can_review_event(uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. RLS policies
-- ---------------------------------------------------------------------------
alter table public.event_reviews enable row level security;

drop policy if exists "event_reviews_public_read" on public.event_reviews;
create policy "event_reviews_public_read"
  on public.event_reviews
  for select
  to public
  using (true);

drop policy if exists "event_reviews_verified_insert" on public.event_reviews;
create policy "event_reviews_verified_insert"
  on public.event_reviews
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and public.can_review_event(event_id)
    and rating between 1 and 5
    and char_length(btrim(review_text)) between 10 and 500
  );

drop policy if exists "event_reviews_author_update" on public.event_reviews;
create policy "event_reviews_author_update"
  on public.event_reviews
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and public.can_review_event(event_id)
    and rating between 1 and 5
    and char_length(btrim(review_text)) between 10 and 500
  );

drop policy if exists "event_reviews_author_delete" on public.event_reviews;
create policy "event_reviews_author_delete"
  on public.event_reviews
  for delete
  to authenticated
  using (auth.uid() = user_id or public.is_level4_admin());

commit;

-- ---------------------------------------------------------------------------
-- Verification (read-only)
-- ---------------------------------------------------------------------------
-- select conname from pg_constraint where conrelid = 'public.event_reviews'::regclass;
-- select public.can_review_event('<event-uuid>');
-- ===========================================================================
