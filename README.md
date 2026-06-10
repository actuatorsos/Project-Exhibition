# LFCD AI Academy — Project Exhibition

A live showcase of student websites, with audience voting.

## Pages
- **`index.html`** — homepage; redirects to the exhibition.
- **`vote.html`** — the public exhibition + voting page (each project shows a live preview, a brief, an "Open site" link, a Vote button, and a live leaderboard). This is what the QR code opens.
- **`admin.html`** — teacher tool to add/edit student sites, export the list, and generate the voting QR. Manages data in your own browser.
- **`sites.json`** — the list of student projects shown to voters.

## Live URLs (after enabling Pages)
Settings → Pages → Source: **Deploy from a branch**, Branch: **main** / **/ (root)**.
- Exhibition: `https://actuatorsos.github.io/Project-Exhibition/`
- Voting page: `https://actuatorsos.github.io/Project-Exhibition/vote.html`

## How to update the projects
1. Open **`admin.html`** and add or edit student sites (the **Brief** is what voters read).
2. Click **⬇ Voting list (sites.json)**.
3. Replace **`sites.json`** in this repo with the downloaded file.

The exhibition and voting pages both read `sites.json`, so everyone sees the same list.

## Voting
Votes use a free, no-sign-up shared counter. The status pill shows **🟢 Live shared results** when the tally server is reachable, or **🟡 This device only** as a fallback. For a high-stakes event, the counter can be swapped for a free Supabase database (see `vote.html` CONFIG block).
