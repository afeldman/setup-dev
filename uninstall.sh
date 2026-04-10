#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${SETUP_DEV_DIR:-${HOME}/.local/share/setup-dev}"
BIN_LINK="${HOME}/.local/bin/dev"
REMOVE_DIR=0
YES=0

usage() {
  cat <<'EOF'
uninstall.sh - setup-dev entfernen

Usage:
  ./uninstall.sh
  ./uninstall.sh --purge
  ./uninstall.sh --purge --yes

Optionen:
  --purge      Entfernt zusaetzlich das Installationsverzeichnis
  -y, --yes    Keine Rueckfrage
  -h, --help   Diese Hilfe anzeigen

Standard:
  Entfernt nur den dev-Link in ~/.local/bin.
EOF
}

confirm() {
  local prompt="$1"
  if [[ "$YES" -eq 1 ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge)
      REMOVE_DIR=1
      shift
      ;;
    -y|--yes)
      YES=1
      shift
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

echo "[INFO] setup-dev uninstall startet..."

if [[ -L "$BIN_LINK" || -e "$BIN_LINK" ]]; then
  if confirm "dev-Link entfernen (${BIN_LINK})?"; then
    rm -f "$BIN_LINK"
    echo "[ OK ] Link entfernt: ${BIN_LINK}"
  else
    echo "[INFO] Link beibehalten: ${BIN_LINK}"
  fi
else
  echo "[SKIP] Kein dev-Link gefunden: ${BIN_LINK}"
fi

if [[ "$REMOVE_DIR" -eq 1 ]]; then
  if [[ -d "$TARGET_DIR" ]]; then
    if confirm "Installationsverzeichnis entfernen (${TARGET_DIR})?"; then
      rm -rf "$TARGET_DIR"
      echo "[ OK ] Verzeichnis entfernt: ${TARGET_DIR}"
    else
      echo "[INFO] Verzeichnis beibehalten: ${TARGET_DIR}"
    fi
  else
    echo "[SKIP] Kein Installationsverzeichnis gefunden: ${TARGET_DIR}"
  fi
else
  echo "[INFO] Installationsverzeichnis bleibt erhalten (nutze --purge zum Entfernen)"
fi

echo "[ OK ] Uninstall abgeschlossen"
