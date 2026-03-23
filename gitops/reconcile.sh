#!/usr/bin/env bash
# GitOps: track dev environment desired state in git
# Usage: dev gitops [push|pull|diff]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
MACHINES_DIR="$SCRIPT_DIR/machines"
HOST=$(hostname -s 2>/dev/null || echo "unknown")
STATE_FILE="$MACHINES_DIR/${HOST}.yaml"
PROFILE_FILE="${HOME}/.config/dev-setup/profile"

# shellcheck source=../telemetry/metrics.sh
source "$ROOT/telemetry/metrics.sh" 2>/dev/null || true

mkdir -p "$MACHINES_DIR"

_push() {
  local profile
  profile=$(cat "$PROFILE_FILE" 2>/dev/null || echo "unknown")
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  cat > "$STATE_FILE" <<YAML
# Auto-generated — do not edit manually
# Updated: ${ts}
host: ${HOST}
updated: ${ts}
profile: ${profile}
installed_brew: $(brew list --formula 2>/dev/null | tr '\n' ' ')
installed_cask: $(brew list --cask 2>/dev/null | tr '\n' ' ')
YAML

  cd "$ROOT"
  git add "gitops/machines/${HOST}.yaml"
  if git diff --cached --quiet; then
    echo "[gitops] Nothing changed for ${HOST}."
  else
    git commit -m "gitops: update state for ${HOST}"
    git push && echo "[gitops] Pushed state for ${HOST}." || echo "[gitops] Push failed (no remote or auth missing)."
  fi
  metric_gitops "push" 2>/dev/null || true
}

_pull() {
  cd "$ROOT"
  git pull --rebase 2>/dev/null && echo "[gitops] Pulled latest state." || echo "[gitops] Pull failed."

  if [[ -f "$STATE_FILE" ]]; then
    echo "[gitops] Remote desired state for ${HOST}:"
    cat "$STATE_FILE"
    echo ""
    echo "[gitops] Running drift detection..."
    "$ROOT/healing/drift-detect.sh" | jq '{count: .count, missing_brew: .missing_brew, missing_cask: .missing_cask}'
  else
    echo "[gitops] No state file for ${HOST} in git yet. Run: dev gitops push"
  fi
  metric_gitops "pull" 2>/dev/null || true
}

_diff() {
  echo "[gitops] Host: ${HOST}"
  echo ""

  if [[ -f "$STATE_FILE" ]]; then
    local git_profile
    git_profile=$(yq e '.profile' "$STATE_FILE" 2>/dev/null || grep 'profile:' "$STATE_FILE" | awk '{print $2}')
    echo "Git desired profile : ${git_profile}"
  else
    echo "Git state           : not committed yet (run: dev gitops push)"
  fi

  local local_profile
  local_profile=$(cat "$PROFILE_FILE" 2>/dev/null || echo "unknown")
  echo "Local active profile: ${local_profile}"
  echo ""

  echo "[gitops] Current drift:"
  "$ROOT/healing/drift-detect.sh" 2>/dev/null \
    | jq '{profile: .profile, missing_count: .count, missing_brew: .missing_brew, missing_cask: .missing_cask}'
  metric_gitops "diff" 2>/dev/null || true
}

case "${1:-diff}" in
  push) _push ;;
  pull) _pull ;;
  diff) _diff ;;
  *)    echo "Usage: dev gitops [push|pull|diff]" ;;
esac
