#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROFILE=""
SKIP_NIX_INSTALL="${SKIP_NIX_INSTALL:-1}"

usage() {
  cat <<'EOF'
update.sh - setup-dev aktualisieren und erneut anwenden

Usage:
  ./update.sh
  ./update.sh -p dp
  ./update.sh --profile yp
  SKIP_NIX_INSTALL=0 ./update.sh

Optionen:
  -p, --profile <name>   Profil fuer bootstrap.sh
  -h, --help             Diese Hilfe anzeigen

Hinweis:
  Standardmaessig wird Nix beim Update uebersprungen (SKIP_NIX_INSTALL=1),
  um erneute Installer-Konflikte zu vermeiden.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile)
      [[ $# -lt 2 ]] && { echo "[ERR ] Fehlender Wert fuer $1" >&2; exit 1; }
      PROFILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERR ] Unbekanntes Argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

echo "[INFO] Aktualisiere setup-dev in ${SCRIPT_DIR}..."
if git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$SCRIPT_DIR" pull --ff-only
else
  echo "[WARN] Kein Git-Repo erkannt - ueberspringe git pull"
fi

if [[ ! -x "$SCRIPT_DIR/bootstrap.sh" ]]; then
  echo "[ERR ] bootstrap.sh nicht gefunden oder nicht ausfuehrbar" >&2
  exit 1
fi

echo "[INFO] Starte bootstrap.sh..."
if [[ -n "$PROFILE" ]]; then
  SKIP_NIX_INSTALL="$SKIP_NIX_INSTALL" bash "$SCRIPT_DIR/bootstrap.sh" -p "$PROFILE"
else
  SKIP_NIX_INSTALL="$SKIP_NIX_INSTALL" bash "$SCRIPT_DIR/bootstrap.sh"
fi

echo "[ OK ] Update abgeschlossen"
