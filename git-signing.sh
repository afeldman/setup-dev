#!/usr/bin/env bash
set -euo pipefail

# Git Signing Manager
# Interaktives Script zum Konfigurieren von GPG-Signierung für git.
# Benötigt: gpg, gum (via brew install gum)

if ! command -v gpg >/dev/null 2>&1; then
  echo "[ERR] gpg ist nicht installiert." >&2
  exit 1
fi

if ! command -v gum >/dev/null 2>&1; then
  echo "[ERR] gum ist nicht installiert. Installiere mit: brew install gum" >&2
  exit 1
fi

# GPG-Schlüssel einlesen: "Name <email> (KEYID)"
mapfile -t PROFILES < <(
  gpg --list-secret-keys --with-colons 2>/dev/null \
  | awk -F: '
    /^sec/ { key=$5 }
    /^uid/ {
      uid=$10
      if (uid ~ /.+ <.+>/) {
        print uid " (" key ")"
      }
    }
  '
)

if [[ ${#PROFILES[@]} -eq 0 ]]; then
  echo "[ERR] Keine GPG-Schlüssel gefunden. Erstelle einen mit: gpg --gen-key" >&2
  exit 1
fi

# Profil auswählen
SELECTED=$(printf "%s\n" "${PROFILES[@]}" | gum choose --header "GPG-Profil auswählen:")

# Key-ID extrahieren (letztes Wort ohne Klammern)
KEYID=$(echo "$SELECTED" | grep -oE '\([^)]+\)$' | tr -d '()')

# Name und Email extrahieren
NAME=$(echo "$SELECTED" | sed 's/ <.*//')
EMAIL=$(echo "$SELECTED" | grep -oE '<[^>]+>' | tr -d '<>')

# Scope
SCOPE=$(gum choose --header "Scope:" "global" "local (nur dieses Repo)")

if [[ "$SCOPE" == local* ]]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[ERR] Nicht in einem git-Repository." >&2
    exit 1
  fi
  PREFIX=""
else
  PREFIX="--global"
fi

# Konfiguration anwenden
git config $PREFIX user.name "$NAME"
git config $PREFIX user.email "$EMAIL"
git config $PREFIX user.signingkey "$KEYID"
git config $PREFIX commit.gpgsign true

echo ""
gum style --foreground 2 "Konfiguration angewendet:"
echo "  Name:    $NAME"
echo "  Email:   $EMAIL"
echo "  Key-ID:  $KEYID"
echo "  Scope:   ${PREFIX:---local}"

# Test-Commit anbieten
if gum confirm "Test-Commit erstellen?"; then
  git commit --allow-empty -m "Test: GPG-Signierung"
  git log --show-signature -1
fi
