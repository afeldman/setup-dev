#!/usr/bin/env bash
# Drift detection: desired state (YAML profile) vs installed tools
# Output: JSON  {"profile":"dp","count":3,"missing_brew":[...],"missing_cask":[...]}
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
STACK="$ROOT/software-stack.yaml"
PROFILE_FILE="${HOME}/.config/dev-setup/profile"

profile="${1:-$(cat "$PROFILE_FILE" 2>/dev/null || true)}"

if [[ -z "$profile" ]]; then
  echo '{"error":"no profile set. Run: dev install -p <profile>","count":0,"missing_brew":[],"missing_cask":[]}' >&2
  exit 1
fi

if ! command -v yq &>/dev/null; then
  echo '{"error":"yq required (brew install yq)","count":0,"missing_brew":[],"missing_cask":[]}' >&2
  exit 1
fi

installed_brew=$(brew list --formula 2>/dev/null | sort)
installed_cask=$(brew list --cask 2>/dev/null | sort)

missing_brew=()
missing_cask=()

while IFS= read -r group; do
  [[ -z "$group" || "$group" == "null" ]] && continue

  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == "null" ]] && continue
    if ! echo "$installed_brew" | grep -qx "$pkg"; then
      missing_brew+=("$pkg")
    fi
  done < <(yq e ".groups.${group}.brew[]" "$STACK" 2>/dev/null || true)

  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == "null" ]] && continue
    if ! echo "$installed_cask" | grep -qx "$pkg"; then
      missing_cask+=("$pkg")
    fi
  done < <(yq e ".groups.${group}.cask[]" "$STACK" 2>/dev/null || true)

done < <(yq e ".profiles.${profile}.groups[]" "$STACK" 2>/dev/null)

total=$(( ${#missing_brew[@]} + ${#missing_cask[@]} ))

brew_arr=$(
  if [[ ${#missing_brew[@]} -gt 0 ]]; then
    printf '%s\n' "${missing_brew[@]}" | jq -R . | jq -s .
  else
    echo '[]'
  fi
)
cask_arr=$(
  if [[ ${#missing_cask[@]} -gt 0 ]]; then
    printf '%s\n' "${missing_cask[@]}" | jq -R . | jq -s .
  else
    echo '[]'
  fi
)

jq -n \
  --arg profile "$profile" \
  --argjson count "$total" \
  --argjson missing_brew "$brew_arr" \
  --argjson missing_cask "$cask_arr" \
  '{profile: $profile, count: $count, missing_brew: $missing_brew, missing_cask: $missing_cask}'
