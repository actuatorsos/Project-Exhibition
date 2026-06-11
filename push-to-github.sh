#!/usr/bin/env bash
# ============================================================
#  Push the LFCD AI Academy exhibition to GitHub
#  Repo: https://github.com/actuatorsos/Project-Exhibition
#
#  HOW TO RUN (on your Mac):
#    1. Open the Terminal app
#    2. Paste this and press Enter:
#         cd "$HOME/Documents/Claude/Projects/projects canvas"
#         bash push-to-github.sh
#
#  AUTH: the push needs your GitHub login. Easiest options:
#    • Install GitHub CLI and run:  gh auth login   (then re-run this script)
#    • OR when git asks for a password, paste a Personal Access Token
#      (github.com → Settings → Developer settings → Tokens → Fine-grained,
#       give it access to the Project-Exhibition repo with Contents: Read/Write)
#
#  If the repo already has files and the push is rejected, re-run with:
#         FORCE=1 bash push-to-github.sh
# ============================================================

set -e
REPO_URL="https://github.com/actuatorsos/Project-Exhibition.git"
BRANCH="main"

# Work inside the folder that contains this script
cd "$(dirname "$0")"
echo "📂 Working in: $(pwd)"

# index.html IS the home page (gallery), edited directly — not generated from another file.
# Remove the old separate admin page if it was pushed in an earlier version.
git rm -q -f admin.html >/dev/null 2>&1 || true
rm -f admin.html 2>/dev/null || true

# Make sure all website files exist
missing=0
for f in index.html vote.html sites.json README.md vercel.json; do
  [ -f "$f" ] || { echo "❌ MISSING: $f"; missing=1; }
done
[ "$missing" = "1" ] && { echo "Create the missing files first, then re-run."; exit 1; }

# Git identity (only set if you don't already have one)
git config user.name  >/dev/null 2>&1 || git config user.name  "actuatorsos"
git config user.email >/dev/null 2>&1 || git config user.email "3dtitanssyria@gmail.com"

# Initialise the repo if needed
[ -d ".git" ] || git init -q
git branch -M "$BRANCH"

# Point "origin" at your GitHub repo
if git remote | grep -q '^origin$'; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi

# Stage only the website files
git add index.html vote.html sites.json README.md vercel.json

# Commit (ok if there is nothing new)
git commit -m "Add LFCD AI Academy exhibition + voting page" || echo "ℹ️  Nothing new to commit."

# Push
echo "🚀 Pushing to $REPO_URL ($BRANCH)…"
if [ "${FORCE:-0}" = "1" ]; then
  git push -u origin "$BRANCH" --force
else
  if ! git push -u origin "$BRANCH"; then
    echo ""
    echo "⚠️  Push was rejected. If the repo already has commits and you're OK"
    echo "    overwriting them, re-run:   FORCE=1 bash push-to-github.sh"
    exit 1
  fi
fi

cat <<'EOF'

✅ Uploaded!

Next — turn on the live website (one time):
  GitHub → your repo → Settings → Pages
  Source: "Deploy from a branch"  →  Branch: main  →  /(root)  →  Save

Give it ~1 minute, then your links are:
  Exhibition : https://actuatorsos.github.io/Project-Exhibition/
  Voting page: https://actuatorsos.github.io/Project-Exhibition/vote.html

The voting QR (in admin.html) is already pre-filled with the voting link.
EOF
