-- Over/Under League: picks storage.
-- Run this once in your Supabase project's SQL Editor (Dashboard → SQL Editor → New query → paste → Run).
--
-- Who can do what (enforced by the database, not the website):
--   * Only emails listed in `members` can save picks or see anyone's picks.
--   * Before the deadline, each person can read and edit only their own sheet.
--   * After the deadline, nobody can edit, and every member can read every sheet.

-- 1. League members: the email each friend signs in with, and their name on the site.
--    Names must match "players" in data/config.json exactly.
create table if not exists public.members (
  email  text primary key,
  player text not null unique
);

-- 2. One pick sheet per person.
create table if not exists public.sheets (
  user_id    uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  player     text not null unique references public.members (player),
  picks      jsonb not null default '{}'::jsonb,   -- {"BOS": "O", "ATL": "U", ...}
  locks      jsonb not null default '[]'::jsonb,   -- ["BOS", ...] at most 5
  updated_at timestamptz not null default now(),
  constraint picks_is_object check (jsonb_typeof(picks) = 'object'),
  constraint locks_max_five  check (jsonb_typeof(locks) = 'array' and jsonb_array_length(locks) <= 5)
);

-- 3. The pick deadline: 10 minutes before the first tip-off (Celtics @ Pistons, 3:00 PM ET Oct 20, 2026).
--    Keep this in sync with "picksCloseAt" in data/config.json.
create or replace function public.picks_open() returns boolean
language sql stable as $$
  select now() < timestamptz '2026-10-20 18:50:00+00'
$$;

-- The league name for whoever is signed in (null if their email isn't a member).
create or replace function public.my_player() returns text
language sql stable security definer set search_path = public as $$
  select player from public.members where lower(email) = lower(auth.jwt() ->> 'email')
$$;

-- 4. Row-level security.
alter table public.members enable row level security;
alter table public.sheets  enable row level security;

drop policy if exists "members see their own row" on public.members;
create policy "members see their own row" on public.members
  for select to authenticated
  using (lower(email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "read own sheet, or all after deadline" on public.sheets;
create policy "read own sheet, or all after deadline" on public.sheets
  for select to authenticated
  using (public.my_player() is not null and (user_id = auth.uid() or not public.picks_open()));

drop policy if exists "create own sheet before deadline" on public.sheets;
create policy "create own sheet before deadline" on public.sheets
  for insert to authenticated
  with check (user_id = auth.uid() and public.picks_open() and player = public.my_player());

drop policy if exists "edit own sheet before deadline" on public.sheets;
create policy "edit own sheet before deadline" on public.sheets
  for update to authenticated
  using (user_id = auth.uid() and public.picks_open())
  with check (user_id = auth.uid() and public.picks_open() and player = public.my_player());

-- No delete policy: sheets can't be deleted from the website.

-- 5. Add your league. Replace the emails with the ones each friend will sign in with.
insert into public.members (email, player) values
  ('amaan@example.com',   'Amaan'),
  ('nadeem@example.com',  'Nadeem'),
  ('kaba@example.com',    'Kaba'),
  ('vishal@example.com',  'Vishal'),
  ('sina@example.com',    'Sina')
on conflict (email) do update set player = excluded.player;
