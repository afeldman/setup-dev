#!/usr/bin/env bash
set -euo pipefail

echo "🤖 analyzing setup..."

LOCAL=$(mktemp)
REMOTE=$(mktemp)

brew list > "$LOCAL"

cat infra/state/*.json | jq -r '.brew' | tr ',' '\n' | sort -u > "$REMOTE"

echo "🔍 missing tools:"

comm -13 "$LOCAL" "$REMOTE" > missing.txt

cat missing.txt

echo
read -p "Install missing tools? (y/n): " yn

if [[ "$yn" == "y" ]]; then
  while read -r tool; do
    [[ -z "$tool" ]] && continue
    echo "installing $tool..."
    ./bootstrap.sh -g base
  done < missing.txt
fi
