#!/usr/bin/env bash
# Telemetry library — source this file, don't execute directly
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/../telemetry/metrics.sh"

METRICS_DIR="${HOME}/.local/share/dev-setup"
METRICS_FILE="${METRICS_DIR}/metrics.jsonl"

_metric_emit() {
  local event="$1" tool="${2:-}" status="${3:-ok}" duration_ms="${4:-0}"
  mkdir -p "$METRICS_DIR"
  printf '{"ts":"%s","host":"%s","event":"%s","tool":"%s","status":"%s","duration_ms":%s}\n' \
    "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    "$(hostname -s 2>/dev/null || echo unknown)" \
    "$event" "$tool" "$status" "$duration_ms" \
    >> "$METRICS_FILE"
}

metric_install_start() { _metric_emit "install_start"  "$1" "running" 0; }
metric_install_ok()    { _metric_emit "install_ok"     "$1" "ok"      "${2:-0}"; }
metric_install_fail()  { _metric_emit "install_fail"   "$1" "error"   "${2:-0}"; }
metric_drift()         { _metric_emit "drift_detected" "$1" "drift"   0; }
metric_healed()        { _metric_emit "drift_healed"   "$1" "ok"      "${2:-0}"; }
metric_agent_suggest() { _metric_emit "agent_suggest"  "$1" "ok"      0; }
metric_gitops()        { _metric_emit "gitops_sync"    "$1" "ok"      0; }
metric_profile_set()   { _metric_emit "profile_set"    "$1" "ok"      0; }
