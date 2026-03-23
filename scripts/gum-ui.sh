#!/usr/bin/env bash
set -euo pipefail

if ! command -v gum >/dev/null; then
  echo "install gum: brew install gum"
  exit 1
fi

PROFILE=$(gum choose --header "🚀 Choose profile" yp dp jp mp)

GROUPS=$(gum choose \
  --no-limit \
  --header "📦 Select groups" \
  base go-dev iac docker ollama obsidian)

CONFIRM=$(gum confirm "Install now?")

if [[ "$CONFIRM" == "true" ]]; then
  ./bootstrap.sh -p "$PROFILE" -g "$(echo "$GROUPS" | tr ' ' ',')"
fi
