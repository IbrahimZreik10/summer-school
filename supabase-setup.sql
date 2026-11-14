-- Summer School Is Cool: database set-up for Supabase.
-- Run this once in Supabase: SQL Editor, New query, paste everything, Run.
-- It is safe to run again: it only adds what is missing.
--
-- Who can see what (row level security):
--   * a student can read and change only their own record;
--   * professors (people listed in the staff table) can read every student's
--     record and change the shared site settings (assignments, console);
--   * nobody can add themselves to the staff table from the website;
--     the site owner adds professors here in Supabase (see the end of this file).

-- 1. Tables ---------------------------------------------------------------

create table if not exists public.students (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  username   text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  state      jsonb not null default '{}'::jsonb,
  events     jsonb not null default '[]'::jsonb
);

create table if not exists public.staff (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  email        text,
  professor_id text not null
);

create table if not exists public.site (
  id         text primary key,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz
);

create table if not exists public.staff_chats (
  user_id uuid primary key references auth.users (id) on delete cascade,
  chats   jsonb not null default '{}'::jsonb
);

-- 2. Helper: is the signed-in person a professor? -------------------------

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.staff where user_id = auth.uid());
$$;

revoke all on function public.is_staff() from public;
grant execute on function public.is_staff() to authenticated;

-- 3. Row level security ---------------------------------------------------

alter table public.students    enable row level security;
alter table public.staff       enable row level security;
alter table public.site        enable row level security;
alter table public.staff_chats enable row level security;

-- Nothing is readable without signing in.
revoke all on public.students, public.staff, public.site, public.staff_chats from anon;
grant select, insert, update on public.students    to authenticated;
grant select                 on public.staff       to authenticated;
grant select, insert, update on public.site        to authenticated;
grant select, insert, update on public.staff_chats to authenticated;

drop policy if exists "students read own or staff" on public.students;
create policy "students read own or staff" on public.students
  for select to authenticated
  using (user_id = auth.uid() or public.is_staff());

drop policy if exists "students add own" on public.students;
create policy "students add own" on public.students
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "students change own" on public.students;
create policy "students change own" on public.students
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "staff read own row" on public.staff;
create policy "staff read own row" on public.staff
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "site read" on public.site;
create policy "site read" on public.site
  for select to authenticated
  using (true);

drop policy if exists "site staff add" on public.site;
create policy "site staff add" on public.site
  for insert to authenticated
  with check (public.is_staff());

drop policy if exists "site staff change" on public.site;
create policy "site staff change" on public.site
  for update to authenticated
  using (public.is_staff())
  with check (public.is_staff());

drop policy if exists "chats own staff" on public.staff_chats;
create policy "chats own staff" on public.staff_chats
  for all to authenticated
  using (user_id = auth.uid() and public.is_staff())
  with check (user_id = auth.uid() and public.is_staff());

-- 4. Live updates (professors see new results without reloading) ----------

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'students') then
    alter publication supabase_realtime add table public.students;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'site') then
    alter publication supabase_realtime add table public.site;
  end if;
end $$;

-- 5. Adding a professor ---------------------------------------------------
-- The professor first signs in once on the website with their email and a
-- password they choose. Then run this (change the email and the professor
-- id, which must match an id in PROFESSORS in index.html, e.g. 'prof-a'):
--
--   insert into public.staff (user_id, email, professor_id)
--   select id, email, 'prof-a' from auth.users where email = 'name@hw.ac.uk'
--   on conflict (user_id) do update set professor_id = excluded.professor_id;
--
--   delete from public.students
--   where user_id = (select id from auth.users where email = 'name@hw.ac.uk');
--
-- To remove a professor:  delete from public.staff where email = 'name@hw.ac.uk';
