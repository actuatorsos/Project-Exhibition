-- ============================================================
--  LFCD AI Academy — secure "pick 3" voting setup
--  Paste this WHOLE script into:  Supabase -> SQL Editor -> Run
--
--  How it works
--  ------------
--  • You print tickets with one-time codes (codes.html makes them).
--  • Each code submits exactly ONE ballot containing 1 to 3 different
--    project ids — enforced here, in the database, so nobody can vote
--    twice even if they clear their browser or call the API directly.
--  • The public can only: (a) call cast_ballot, (b) read the totals.
--    Codes and individual ballots are NOT publicly readable.
-- ============================================================

-- 1) One-time voting codes (one row per printed ticket)
create table if not exists public.vote_codes (
  code       text primary key,
  used_at    timestamptz,
  created_at timestamptz not null default now()
);
alter table public.vote_codes enable row level security;
-- No policies on purpose: anonymous users cannot read or write codes directly.

-- 2) Ballots (one row per voter; their 1–3 picks live in site_ids)
create table if not exists public.ballots (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique references public.vote_codes(code),
  site_ids   text[] not null,
  created_at timestamptz not null default now(),
  constraint picks_one_to_three check (array_length(site_ids, 1) between 1 and 3)
);
-- Migration for older installs (safe to re-run):
alter table public.ballots drop constraint if exists exactly_three_picks;
alter table public.ballots drop constraint if exists picks_one_to_three;
alter table public.ballots add constraint picks_one_to_three check (array_length(site_ids, 1) between 1 and 3);
alter table public.ballots enable row level security;
-- No policies on purpose: ballots are only written via cast_ballot below,
-- and only read in aggregate via the vote_results view.

-- 3) The ONLY way to vote: atomic, race-safe, one ballot per code.
--    Returns: 'OK' | 'ERR_CODE' (unknown) | 'ERR_USED' | 'ERR_PICKS'
create or replace function public.cast_ballot(p_code text, p_site_ids text[])
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code  text;
  v_clean text[];
begin
  -- Normalize and validate the picks: 1 to 3 distinct, non-empty, sane length.
  select array_agg(distinct t) into v_clean
  from (select trim(x) as t from unnest(coalesce(p_site_ids, '{}')) as x) s
  where t <> '' and length(t) <= 80;

  if v_clean is null or array_length(v_clean, 1) < 1 or array_length(v_clean, 1) > 3 then
    return 'ERR_PICKS';
  end if;

  -- Atomically claim the code (works once, even under simultaneous requests).
  update public.vote_codes
     set used_at = now()
   where code = upper(trim(p_code))
     and used_at is null
  returning code into v_code;

  if v_code is null then
    if exists (select 1 from public.vote_codes where code = upper(trim(p_code))) then
      return 'ERR_USED';
    end if;
    return 'ERR_CODE';
  end if;

  insert into public.ballots (code, site_ids) values (v_code, v_clean);
  return 'OK';
end;
$$;

revoke all on function public.cast_ballot(text, text[]) from public;
grant execute on function public.cast_ballot(text, text[]) to anon, authenticated;

-- 4) Public live totals (aggregate only — no codes, no individual ballots).
--    The view runs with owner rights, so it can read ballots while RLS
--    keeps the raw table private.
create or replace view public.vote_results as
  select x.site_id, count(*)::int as votes
  from public.ballots b, unnest(b.site_ids) as x(site_id)
  group by x.site_id;

grant usage on schema public to anon, authenticated;
grant select on public.vote_results to anon, authenticated;

-- ============================================================
--  Adding voting codes
-- ============================================================
-- Preferred: open codes.html, generate + print tickets, then click
-- "Copy SQL for Supabase" and run the pasted INSERT here.
--
-- Quick alternative — create 50 random codes directly (then read them
-- back with the query below and write them on tickets yourself):
--
--   insert into public.vote_codes (code)
--   select upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6))
--   from generate_series(1, 50)
--   on conflict (code) do nothing;

-- ============================================================
--  Handy teacher queries (run anytime)
-- ============================================================
-- All codes and whether they were used:
--   select code, used_at from public.vote_codes order by created_at;
--
-- Live results:
--   select * from public.vote_results order by votes desc;
--
-- How many ballots are in:
--   select count(*) as ballots from public.ballots;
--
-- Start completely fresh (careful — deletes all votes!):
--   truncate public.ballots; update public.vote_codes set used_at = null;

-- ============================================================
--  PART 2 — Shared project list (the +Add button saves here)
--  Re-running this whole file is always safe (idempotent).
-- ============================================================

-- 5) The projects everyone sees (replaces sites.json as the source of truth)
create table if not exists public.sites (
  id         text primary key default replace(gen_random_uuid()::text, '-', ''),
  name       text not null default '',
  url        text not null,
  brief      text not null default '',
  created_at timestamptz not null default now()
);
alter table public.sites enable row level security;
drop policy if exists "public read sites" on public.sites;
create policy "public read sites" on public.sites for select using (true);
-- No public insert/update/delete: changes only happen through the
-- passcode-protected functions below.

-- 6) Teacher passcode (kept in a table nobody can read from the website)
create table if not exists public.teacher_secret ( pass text primary key );
alter table public.teacher_secret enable row level security;
-- Sets the initial passcode ONLY if none exists yet.
-- To change it later:  update public.teacher_secret set pass = 'MY-NEW-PASS';
insert into public.teacher_secret (pass)
select 'LFCD-SAZK-G3WF'
where not exists (select 1 from public.teacher_secret);

-- 7) Teacher actions (each checks the passcode first)
create or replace function public.site_add(p_pass text, p_name text, p_url text, p_brief text)
returns text language plpgsql security definer set search_path = public as $$
declare v_id text;
begin
  if not exists (select 1 from public.teacher_secret where pass = p_pass) then return 'ERR_PASS'; end if;
  if p_url is null or p_url !~* '^https?://' or length(p_url) > 500
     or length(coalesce(p_name,'')) > 120 or length(coalesce(p_brief,'')) > 500 then
    return 'ERR_INPUT';
  end if;
  insert into public.sites (name, url, brief)
  values (trim(coalesce(p_name,'')), trim(p_url), trim(coalesce(p_brief,'')))
  returning id into v_id;
  return v_id;
end; $$;

create or replace function public.site_update(p_pass text, p_id text, p_name text, p_url text, p_brief text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.teacher_secret where pass = p_pass) then return 'ERR_PASS'; end if;
  if p_url is null or p_url !~* '^https?://' or length(p_url) > 500
     or length(coalesce(p_name,'')) > 120 or length(coalesce(p_brief,'')) > 500 then
    return 'ERR_INPUT';
  end if;
  update public.sites
     set name = trim(coalesce(p_name,'')), url = trim(p_url), brief = trim(coalesce(p_brief,''))
   where id = p_id;
  if not found then return 'ERR_NOTFOUND'; end if;
  return 'OK';
end; $$;

create or replace function public.site_delete(p_pass text, p_id text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.teacher_secret where pass = p_pass) then return 'ERR_PASS'; end if;
  delete from public.sites where id = p_id;
  if not found then return 'ERR_NOTFOUND'; end if;
  return 'OK';
end; $$;

revoke all on function public.site_add(text,text,text,text) from public;
revoke all on function public.site_update(text,text,text,text,text) from public;
revoke all on function public.site_delete(text,text) from public;
grant execute on function public.site_add(text,text,text,text) to anon, authenticated;
grant execute on function public.site_update(text,text,text,text,text) to anon, authenticated;
grant execute on function public.site_delete(text,text) to anon, authenticated;

-- 8) Activate voting tickets straight from codes.html (teacher passcode required).
--    Returns 'OK:<number-of-new-codes>' | 'ERR_PASS' | 'ERR_INPUT'
create or replace function public.codes_add(p_pass text, p_codes text[])
returns text language plpgsql security definer set search_path = public as $$
declare v_n int := 0; v_c text;
begin
  if not exists (select 1 from public.teacher_secret where pass = p_pass) then return 'ERR_PASS'; end if;
  if p_codes is null or array_length(p_codes, 1) is null or array_length(p_codes, 1) > 1000 then return 'ERR_INPUT'; end if;
  foreach v_c in array p_codes loop
    v_c := upper(trim(v_c));
    if v_c ~ '^[A-Z0-9]{4,12}$' then
      insert into public.vote_codes (code) values (v_c) on conflict (code) do nothing;
      if found then v_n := v_n + 1; end if;
    end if;
  end loop;
  return 'OK:' || v_n;
end; $$;
revoke all on function public.codes_add(text, text[]) from public;
grant execute on function public.codes_add(text, text[]) to anon, authenticated;

-- 8b) Ticket status for the teacher (codes.html "Ticket status" panel).
--     Wrong passcode raises an error containing ERR_PASS.
create or replace function public.codes_status(p_pass text)
returns table(code text, used_at timestamptz, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.teacher_secret where pass = p_pass) then
    raise exception 'ERR_PASS';
  end if;
  return query
    select c.code, c.used_at, c.created_at
    from public.vote_codes c
    order by c.used_at desc nulls last, c.created_at desc, c.code;
end; $$;
revoke all on function public.codes_status(text) from public;
grant execute on function public.codes_status(text) to anon, authenticated;

-- 9) Bring in the current 7 projects (skipped if they already exist)
insert into public.sites (id, name, url, brief, created_at) values
  ('mq9j9gj5ejkok', 'NBA Team',             'https://basketball-hub.replit.app/',             '(Nabil & Adam)',      now() - interval '7 minutes'),
  ('mq9jb9z4o7o4u', 'The Hackers Team',     'https://chess-quest-farajabdulhafiz.replit.app/','(Laila & Sultan)',    now() - interval '6 minutes'),
  ('mq9jcjfprtzxy', 'Chocolate Team',       'https://home-gadget-hub.replit.app/',            '(ghaith & Khaldoun)', now() - interval '5 minutes'),
  ('mq9jem52cb8fj', 'Pokemon Legends Team', 'https://pokemon-spin-wheel.replit.app/',         '(Karam & Karim)',     now() - interval '4 minutes'),
  ('mq9jh4hcjdhsq', 'NoName',               'https://fantasy-draft-buddy.replit.app/',        'Munzer Al-Akrami',    now() - interval '3 minutes'),
  ('mq9jhw0ks8239', 'NoName',               'https://score-streak.replit.app/',               '(Talal & Marcio)',    now() - interval '2 minutes'),
  ('mq9lzg1ekrfae', 'Yahya''s Website',     'https://yahyademeriah.com/',                     '',                    now() - interval '1 minute')
on conflict (id) do nothing;

-- ============================================================
--  Cleanup from the very first setup (only if you ran the
--  ORIGINAL version of this file long ago). Safe to skip.
-- ============================================================
-- drop function if exists public.increment_vote(uuid);
