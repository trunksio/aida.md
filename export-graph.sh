#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="/home/lewis/work/aida.md"
API="http://localhost:8484"
DATA_DIR="${REPO_DIR}/data"

mkdir -p "$DATA_DIR"
curl -sf "${API}/graph" -o "${DATA_DIR}/graph.json"
curl -sf "${API}/engrams" -o "${DATA_DIR}/engrams.json"

# Stats with last_updated timestamp
STATS=$(curl -sf "${API}/stats")
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "$STATS" | python3 -c "import json,sys; d=json.load(sys.stdin); d['last_updated']='${TS}'; json.dump(d,sys.stdout,indent=2)" > "${DATA_DIR}/stats.json"

cd "$REPO_DIR"
git add data/
git diff --cached --quiet && { echo "No changes"; exit 0; }
git commit -m "Update graph data $(date -u +'%Y-%m-%d %H:%M UTC')"
git push origin main
