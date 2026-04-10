#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.config/dev/state.json"

mkdir -p "$(dirname "$STATE_FILE")"

echo "📡 collecting state..."

jq -n \
  --arg host "$(hostname)" \
  --arg date "$(date)" \
  --arg brew "$(brew list --formula | tr '\n' ',')" \
  --arg zb "$(zb list 2>/dev/null | tr '\n' ',')" \
  '{
    host: $host,
    date: $date,
    brew: $brew,
    zerobrew: $zb
  }' > "$STATE_FILE"

echo "⬆️ pushing to S3..."

aws s3 cp "$STATE_FILE" s3://dev-setup-state/machines/$(hostname).json

echo "⬇️ pulling global state..."

aws s3 sync s3://dev-setup-state/machines ./infra/state/

echo "✅ sync complete"
