#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="/home/lewis/work/aida.md"
API="http://localhost:8484"
DATA_DIR="${REPO_DIR}/data"
CAMPAIGNS_DIR="${REPO_DIR}/campaigns"

mkdir -p "$DATA_DIR"

# Sync campaigns from markdown files to API
if [ -d "$CAMPAIGNS_DIR" ]; then
    for md_file in "$CAMPAIGNS_DIR"/*.md; do
        [ -f "$md_file" ] || continue
        python3 << EOF
import yaml
import json
import urllib.request

with open('$md_file') as f:
    content = f.read()

if not content.startswith('---'):
    exit(0)

parts = content.split('---', 2)
if len(parts) < 3:
    exit(0)

frontmatter = yaml.safe_load(parts[1])
description = parts[2].strip()

campaign = {
    "id": frontmatter.get("id"),
    "title": frontmatter.get("title"),
    "topic": frontmatter.get("topic"),
    "description": description,
    "goal": frontmatter.get("goal", ""),
    "target_metrics": frontmatter.get("target_metrics"),
    "agents": frontmatter.get("agents", [])
}

# POST campaign
url = "${API}/campaigns"
data = json.dumps(campaign).encode()
req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
try:
    urllib.request.urlopen(req)
except: pass

# Start if active
if frontmatter.get("status") == "active":
    url = f"${API}/campaigns/{frontmatter.get('id')}/start"
    req = urllib.request.Request(url, method="POST")
    try:
        urllib.request.urlopen(req)
    except: pass
EOF
    done
fi

# Core graph data
curl -sf "${API}/graph" -o "${DATA_DIR}/graph.json"
curl -sf "${API}/engrams" -o "${DATA_DIR}/engrams.json"

# Stats with last_updated timestamp
STATS=$(curl -sf "${API}/stats")
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "$STATS" | python3 -c "import json,sys; d=json.load(sys.stdin); d['last_updated']='${TS}'; json.dump(d,sys.stdout,indent=2)" > "${DATA_DIR}/stats.json"

# Export active campaigns with agents and metrics
curl -sf "${API}/campaigns?status=active" -o "${DATA_DIR}/campaigns.json" || echo "[]" > "${DATA_DIR}/campaigns.json"

# Per-agent graph data
for agent in Aida Alpha Beta Gamma Delta; do
    curl -sf "${API}/graph/agent?name=${agent}" -o "${DATA_DIR}/graph-${agent}.json" || echo '{"nodes":[],"edges":[]}' > "${DATA_DIR}/graph-${agent}.json"
done

cd "$REPO_DIR"
git add data/
git diff --cached --quiet && { echo "No changes"; exit 0; }
git commit -m "Update graph data $(date -u +'%Y-%m-%d %H:%M UTC')"
git push origin main
