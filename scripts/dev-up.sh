#!/usr/bin/env bash
set -euo pipefail

echo "🚀 dev up starting..."

# mise runtimes
if command -v mise >/dev/null; then
  mise install
fi

# nix shell (optional)
if [[ -f "nix/flake.nix" ]]; then
  echo "❄️ entering nix dev shell"
  nix develop -c $SHELL
  exit 0
fi

echo "✅ dev environment ready"
