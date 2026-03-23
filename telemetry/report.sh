#!/usr/bin/env bash
set -euo pipefail

METRICS_FILE="${HOME}/.local/share/dev-setup/metrics.jsonl"

if [[ ! -f "$METRICS_FILE" ]]; then
  echo "No metrics yet. Run 'dev install' first."
  exit 0
fi

total=$(wc -l < "$METRICS_FILE" | tr -d ' ')

echo "=== Dev Setup Metrics === (${total} events total)"
echo ""

echo "--- Events by type ---"
jq -r '.event' "$METRICS_FILE" | sort | uniq -c | sort -rn

echo ""
echo "--- Failed installs ---"
if grep -q '"status":"error"' "$METRICS_FILE" 2>/dev/null; then
  grep '"status":"error"' "$METRICS_FILE" | jq -r '"  \(.ts)  \(.tool)"'
else
  echo "  none"
fi

echo ""
echo "--- Drift history ---"
if grep -q '"event":"drift_detected"' "$METRICS_FILE" 2>/dev/null; then
  grep '"event":"drift_detected"' "$METRICS_FILE" | jq -r '"  \(.ts)  \(.tool)"'
else
  echo "  none"
fi

echo ""
echo "--- Last 10 events ---"
tail -10 "$METRICS_FILE" \
  | jq -r '"  \(.ts)  \(.event)  \(.tool)  [\(.status)]"'
