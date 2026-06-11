-- ============================================================
--  LFCD AI Academy — secure "pick 3" voting setup
--  Paste this WHOLE script into:  Supabase -> SQL Editor -> Run
--
--  How it works
--  ------------
--  • You print tickets with one-time codes (codes.html makes them).
--  • Each code submits exactly ONE ballot containing THREE different
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

-- 2) Ballots (one row per voter; the 3 picks live in site_ids)
create table if not exists public.ballots (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique references public.vote_codes(code),
  site_ids   text[] not null,
  created_at timestamptz not null default now(),
  constraint exactly_three_picks check (array_length(site_ids, 1) = 3)
);
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
  -- Normalize and validate the 3 picks: distinct, non-empty, sane length.
  select array_agg(distinct t) into v_clean
  from (select trim(x) as t from unnest(coalesce(p_site_ids, '{}')) as x) s
  where t <> '' and length(t) <= 80;

  if v_clean is null or array_length(v_clean, 1) <> 3 then
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
--  Cleanup from the OLD setup (only if you ran the previous
--  version of this file). Safe to skip otherwise.
-- ============================================================
-- drop function if exists public.increment_vote(uuid);
-- drop table if exists public.sites;
