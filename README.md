# LFCD AI Academy — Project Exhibition

A live showcase of student websites, with audience voting.

## Pages
- **index.html** — the home page: a gallery of student sites with live previews, plus the teacher tools (add / edit / delete, export, voting QR). The **★ Vote** button links to the voting page.
- **vote.html** — the public voting page: each project with its brief, a live preview, an Open-site link, a **Vote** button, and a live leaderboard (🥇🥈🥉).
- **sites.json** — the list of student projects shown to everyone.
- **vercel.json** — security headers (Content-Security-Policy, etc.).

## Live URLs
- Home / gallery: your Vercel link (e.g. `https://project-exhibition.vercel.app/`)
- Voting page: `…/vote.html`  ← this is what the QR opens

## Updating the projects
1. On the home page, add or edit student sites (the **Brief** is what voters read).
2. Click **⬇ Voting list (sites.json)**.
3. Replace `sites.json` in the repo with the downloaded file — Vercel redeploys automatically.

For instant, no-redeploy adding shared across everyone, connect the site to a free **Supabase** database (see `supabase-setup.sql`).

## Voting
Votes use a free shared counter; the status pill shows **🟢 Live shared results** or **🟡 This device only**. For a high-stakes event, switch to the Supabase database (see `supabase-setup.sql`).

## Security
- `vercel.json` sets a Content-Security-Policy plus `nosniff`, `Referrer-Policy: no-referrer`, `X-Frame-Options`, `Permissions-Policy`, and HSTS.
- Previews are **sandboxed** iframes (no top-navigation, popups, forms, or downloads).
- Links and iframe sources are restricted to **http/https** only (blocks `javascript:`/`data:` URLs).
- Supabase rules allow public read + add, but **not** public edit/delete.
