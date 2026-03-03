#!/bin/bash
# Auto-sync maia repo to GitHub
# Runs via Windows Task Scheduler

cd /c/Users/olli.ojala/maia || exit 1

# Only sync if there are changes
if [ -n "$(git status --porcelain)" ]; then
    git add -A -- . ":!get_path_manager*" ":!nul"
    git commit -m "Auto-sync $(date '+%Y-%m-%d %H:%M')"
    git push origin main
fi
