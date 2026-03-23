#!/usr/bin/env bash
# Auto-fix drift: reinstalls missing tools from desired profile
# Usage: ./drift-fix.sh [--auto]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."

# Telemetry (graceful if not present)
# shellcheck source=../telemetry/metrics.sh
source "$ROOT/telemetry/metrics.sh" 2>/dev/null || true

AUTO="${1:-}"

echo "[heal] Checking environment against desired state..."
drift=$("$SCRIPT_DIR/drift-detect.sh" 2>/dev/null) || {
  echo "[heal] Could not detect drift (is a profile set?)"
  exit 1
}

count=$(echo "$drift" | jq -r '.count')
profile=$(echo "$drift" | jq -r '.profile')

if [[ "$count" -eq 0 ]]; then
  echo "[heal] No drift. Environment matches profile '${profile}'."
  exit 0
fi

echo "[heal] Found ${count} missing tools for profile '${profile}':"
echo "$drift" | jq -r '(.missing_brew[], .missing_cask[]) // empty' | sed 's/^/  - /'
echo ""

# Emit telemetry for each missing tool
while IFS= read -r pkg; do
  [[ -z "$pkg" || "$pkg" == "null" ]] && continue
  metric_drift "$pkg" 2>/dev/null || true
done < <(echo "$drift" | jq -r '(.missing_brew[], .missing_cask[]) // empty')

if [[ "$AUTO" != "--auto" ]]; then
  read -rp "Fix drift now? [y/N] " yn
  [[ "${yn,,}" != "y" ]] && echo "Aborted." && exit 0
fi

# Install missing formulae
while IFS= read -r pkg; do
  [[ -z "$pkg" || "$pkg" == "null" ]] && continue
  echo "[heal] Installing formula: $pkg"
  t_start=$(date +%s%3N 2>/dev/null || date +%s)
  if brew install "$pkg"; then
    t_end=$(date +%s%3N 2>/dev/null || date +%s)
    metric_healed "$pkg" $(( t_end - t_start )) 2>/dev/null || true
  else
    metric_install_fail "$pkg" 2>/dev/null || true
    echo "[heal] WARN: failed to install $pkg"
  fi
done < <(echo "$drift" | jq -r '.missing_brew[] // empty')

# Install missing casks
while IFS= read -r pkg; do
  [[ -z "$pkg" || "$pkg" == "null" ]] && continue
  echo "[heal] Installing cask: $pkg"
  t_start=$(date +%s%3N 2>/dev/null || date +%s)
  if brew install --cask "$pkg"; then
    t_end=$(date +%s%3N 2>/dev/null || date +%s)
    metric_healed "$pkg" $(( t_end - t_start )) 2>/dev/null || true
  else
    metric_install_fail "$pkg" 2>/dev/null || true
    echo "[heal] WARN: failed to install cask $pkg"
  fi
done < <(echo "$drift" | jq -r '.missing_cask[] // empty')

echo ""
echo "[heal] Done. Run 'dev metrics' to see full history."
