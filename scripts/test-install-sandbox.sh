#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d -t setup-dev-sandbox.XXXXXX)"
FAKE_HOME="$WORK_DIR/home"
FAKE_BIN="$WORK_DIR/fake-bin"
LOG_FILE="$WORK_DIR/test.log"

cleanup() {
  if [[ "${KEEP_SANDBOX:-0}" != "1" ]]; then
    rm -rf "$WORK_DIR"
  else
    echo "[INFO] Sandbox bleibt erhalten: $WORK_DIR"
  fi
}
trap cleanup EXIT

mkdir -p "$FAKE_HOME" "$FAKE_BIN"

cat > "$FAKE_BIN/brew" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "Homebrew 0.0-test"
  exit 0
fi
echo "[fake-brew] $*" >&2
exit 0
EOF

cat > "$FAKE_BIN/nix" <<'EOF'
#!/usr/bin/env bash
echo "nix (Nix) 0.0-test"
EOF

cat > "$FAKE_BIN/gofish" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "version" ]]; then
  echo "gofish test"
else
  echo "[fake-gofish] $*" >&2
fi
EOF

cat > "$FAKE_BIN/zb" <<'EOF'
#!/usr/bin/env bash
echo "zb 0.0-test"
EOF

cat > "$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "clone" ]]; then
  src="${@: -2:1}"
  dest="${@: -1}"
  mkdir -p "$dest"
  cp -a "$src/." "$dest/"
  exit 0
fi
if [[ "${1:-}" == "-C" && "${3:-}" == "pull" ]]; then
  exit 0
fi
if [[ "${1:-}" == "-C" && "${3:-}" == "rev-parse" ]]; then
  exit 0
fi
command git "$@"
EOF

chmod +x "$FAKE_BIN/brew" "$FAKE_BIN/nix" "$FAKE_BIN/gofish" "$FAKE_BIN/zb" "$FAKE_BIN/git"

export HOME="$FAKE_HOME"
export PATH="$FAKE_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
export SETUP_DEV_DIR="$FAKE_HOME/.local/share/setup-dev"
export SETUP_DEV_BIN_DIR="$FAKE_HOME/.local/bin"
export SETUP_DEV_REPO_URL="$ROOT_DIR"
export SKIP_BOOTSTRAP=1

mkdir -p "$FAKE_HOME/.zshrc.d"
: > "$FAKE_HOME/.zshrc"

printf '[INFO] Starte Sandbox-Test in %s\n' "$WORK_DIR"

bash "$ROOT_DIR/install.sh" >"$LOG_FILE" 2>&1

if [[ ! -L "$FAKE_HOME/.local/bin/dev" ]]; then
  echo "[FAIL] dev symlink fehlt"
  cat "$LOG_FILE"
  exit 1
fi

if [[ ! -x "$SETUP_DEV_DIR/dev" ]]; then
  echo "[FAIL] dev script im setup-dev Verzeichnis fehlt"
  cat "$LOG_FILE"
  exit 1
fi

if ! "$FAKE_HOME/.local/bin/dev" help >/dev/null 2>&1; then
  echo "[FAIL] dev help ist nicht lauffaehig"
  cat "$LOG_FILE"
  exit 1
fi

ui_output="$($FAKE_HOME/.local/bin/dev ui 2>&1 || true)"
if [[ "$ui_output" == *"No such file or directory"* ]]; then
  echo "[FAIL] dev ui hat noch ein Pfadproblem"
  echo "$ui_output"
  cat "$LOG_FILE"
  exit 1
fi

if [[ "$ui_output" != *"install gum"* ]]; then
  echo "[FAIL] dev ui lieferte unerwartete Ausgabe"
  echo "$ui_output"
  cat "$LOG_FILE"
  exit 1
fi

printf '[ OK ] Sandbox-Test erfolgreich\n'
printf '[INFO] Log: %s\n' "$LOG_FILE"
