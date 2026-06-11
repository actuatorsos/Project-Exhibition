# LFCD AI Academy — Project Exhibition

A live showcase of student websites, with secure "pick your top 3" audience voting.

## Pages
- **index.html** — the home page: a gallery of student sites with live previews, plus the teacher tools (add / edit / delete, export, voting QR). The **⭐ Vote now** button links to the voting page.
- **vote.html** — the public voting page: voters tap **Pick** on **1 to 3** projects, then submit their ballot with the one-time code from their ticket. Live results (bars, medals, podium) update on the page.
- **codes.html** — teacher-only ticket maker: generates unique one-time codes, **⚡ activates them** (teacher passcode), prints cut-out tickets (each with a QR that opens vote.html with the code pre-filled), remembers your batch across refreshes, and shows a **live status panel** of which tickets have voted.
- **sites.json** — the list of student projects shown to everyone.
- **supabase-setup.sql** — the database that makes voting secure.
- **vercel.json** — security headers (Content-Security-Policy, etc.).

## Setting up secure voting (one time, ~5 minutes)
1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor**, paste the whole of `supabase-setup.sql`, press **Run**.
3. In **Settings → API**, copy the **Project URL** and the **anon public** key.
4. Open `vote.html` and paste them into `SUPABASE_URL` and `SUPABASE_ANON_KEY` at the top of the script. Redeploy.
5. Open `codes.html` → generate tickets → **Copy SQL for Supabase** → run it in the SQL Editor → **Print tickets**.

Until Supabase is connected, vote.html runs in **🟡 Practice mode** (votes stay on each device) so you can rehearse safely.

## Running the vote
1. Hand each voter one printed ticket.
2. They scan their ticket's QR (or open the voting page and type the code).
3. They pick 1–3 different projects and press **Send my votes**.
4. Each code works exactly once — enforced by the database, so clearing the browser or calling the API directly can't double-vote.
5. Results appear live on the voting page (and with `select * from vote_results order by votes desc;` in Supabase).

## Updating the projects
1. On the home page, add or edit student sites (the **Brief** is what voters read).
2. Click **⬇ Voting list (sites.json)**.
3. Replace `sites.json` in the repo with the downloaded file — Vercel redeploys automatically.

## Security
- One ballot per code, 1–3 distinct picks, enforced **server-side** in `cast_ballot` (atomic, race-safe).
- Codes and individual ballots are not publicly readable; only aggregate totals are exposed (`vote_results`).
- Codes use an unambiguous alphabet (no 0/O/1/I/L) with ~900M combinations — guessing is impractical.
- `vercel.json` sets a Content-Security-Policy plus `nosniff`, `Referrer-Policy: no-referrer`, `X-Frame-Options`, `Permissions-Policy`, and HSTS.
- Previews are **sandboxed** iframes; links and iframe sources are restricted to **http/https** only (blocks `javascript:`/`data:` URLs).

## Testing tips
- `vote.html?reset` clears this device's ballot + practice tallies (server votes are untouched).
- `vote.html?code=ABC123` pre-fills a ticket code (this is what ticket QRs do).
