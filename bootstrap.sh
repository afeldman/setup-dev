#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK="${SCRIPT_DIR}/software-stack.yaml"
PROFILE_FILE="${HOME}/.config/dev-setup/profile"

# DEV_PATH: Zielverzeichnis für geklonte Git-Repos
# Setze via: export DEV_PATH=/opt/dev  (oder in ~/.zshrc)
DEV_PATH="${DEV_PATH:-/opt/dev}"
export DEV_PATH

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }

# Portable current timestamp in milliseconds (GNU date and BSD/macOS compatible)
now_ms() {
  local ms
  ms=$(date +%s%3N 2>/dev/null || true)
  if [[ "$ms" =~ ^[0-9]+$ ]]; then
    echo "$ms"
  else
    echo "$(( $(date +%s) * 1000 ))"
  fi
}

# Fragt einmalig nach dem sudo-Passwort und hält es per Keepalive aktiv
sudo_keepalive() {
  if ! sudo -n true 2>/dev/null; then
    echo "[INFO] Einige Schritte benötigen Administrator-Rechte (sudo)."
    sudo -v || { echo "[ERROR] sudo-Authentifizierung fehlgeschlagen. Abbruch."; exit 1; }
  fi
  # Keepalive: sudo-Timeout alle 50 Sekunden erneuern bis Script endet
  (while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
}

# Prüft ob der Bootstrap innerhalb eines Containers läuft
is_container() {
  [[ -f "/.dockerenv" ]] && return 0
  grep -q "docker\|lxc\|containerd" /proc/1/cgroup 2>/dev/null && return 0
  return 1
}

# Source telemetry (graceful — may not exist on first run)
# shellcheck source=telemetry/metrics.sh
source "$SCRIPT_DIR/telemetry/metrics.sh" 2>/dev/null || true

# -----------------------------------------
# CORE INSTALLS (idempotent)
# -----------------------------------------

install_brew() {
  command -v brew >/dev/null && return
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

install_zb() {
  command -v zb >/dev/null && return
  info "Installing ZeroBrew..."
  curl -fsSL https://zerobrew.rs/install | bash
}

install_mise() {
  command -v mise >/dev/null && return
  brew install mise
}

install_nix() {
  if [[ "${SKIP_NIX_INSTALL:-0}" == "1" ]]; then
    warn "Skipping Nix install (SKIP_NIX_INSTALL=1)"
    return
  fi

  command -v nix >/dev/null && return

  # macOS: old Nix backup artifacts can make the official installer abort.
  # Skip here so the rest of the setup can continue.
  if [[ "$(uname -s)" == "Darwin" ]]; then
    local backup_files=(
      "/etc/bashrc.backup-before-nix"
      "/etc/zshrc.backup-before-nix"
      "/etc/bash.bashrc.backup-before-nix"
    )
    local found=0
    local bf
    for bf in "${backup_files[@]}"; do
      if [[ -e "$bf" ]]; then
        found=1
        break
      fi
    done

    if [[ "$found" -eq 1 ]]; then
      warn "Detected previous Nix backup artifacts on macOS; skipping Nix install to avoid installer abort."
      warn "If you want to fix Nix later, review and clean up *.backup-before-nix files under /etc and rerun with SKIP_NIX_INSTALL=0."
      return
    fi
  fi

  sh <(curl -L https://nixos.org/nix/install)
}

install_auto_upgrade() {
  local script="$HOME/.local/bin/auto_upgrade_dev.sh"
  mkdir -p "$(dirname "$script")"
  cat > "$script" <<'UPGRADE'
#!/usr/bin/env bash
# Auto-upgrade: ZeroBrew (fast) + Homebrew (fallback/casks)
LAST_RUN="$HOME/.config/brew/last_update"
INTERVAL_HOURS=24
mkdir -p "$(dirname "$LAST_RUN")"
now=$(date +%s)
last=$(cat "$LAST_RUN" 2>/dev/null || echo 0)
diff_h=$(( (now - last) / 3600 ))
(( diff_h < INTERVAL_HOURS )) && exit 0

echo "[upgrade] Starting dev environment upgrade..."

# ZeroBrew: fast, parallel updates
if command -v zb >/dev/null 2>&1; then
  echo "[upgrade] zb upgrade..."
  zb upgrade 2>/dev/null || true
fi

# Homebrew: casks + formulae not in zb
if command -v brew >/dev/null 2>&1; then
  echo "[upgrade] brew upgrade..."
  brew update --quiet && brew upgrade --quiet && brew cleanup --quiet
fi

echo "$now" > "$LAST_RUN"
echo "[upgrade] Done."
UPGRADE

  chmod +x "$script"
  # Only add auto-upgrade once
  grep -q "auto_upgrade_dev" ~/.zshrc 2>/dev/null \
    || echo "$script &" >> ~/.zshrc
  grep -q "auto_upgrade_dev" ~/.bashrc 2>/dev/null \
    || echo "$script &" >> ~/.bashrc 2>/dev/null || true

  # Export DEV_PATH if not already set in shell profile
  local dev_path_export="export DEV_PATH=\"${DEV_PATH}\""
  grep -q "DEV_PATH" ~/.zshrc 2>/dev/null \
    || echo "$dev_path_export" >> ~/.zshrc
  grep -q "DEV_PATH" ~/.bashrc 2>/dev/null \
    || echo "$dev_path_export" >> ~/.bashrc 2>/dev/null || true


  if [[ -w "${DEV_PATH}" ]]; then
    info "DEV_PATH '${DEV_PATH}' is writable."
    mkdir -p "$DEV_PATH"
  else
    warn "DEV_PATH '${DEV_PATH}' is not writable. Please ensure it exists and has appropriate permissions."
    sudo mkdir -p "$DEV_PATH"
    sudo chown "$USER" "$DEV_PATH"
    info "Created DEV_PATH '${DEV_PATH}' with user ownership."
  fi
}

# -----------------------------------------
# PACKAGE INSTALL
# -----------------------------------------

install_tap() {
  local tap="$1"
  brew tap | grep -q "^${tap}$" && return
  info "Adding tap: $tap"
  brew tap "$tap" || warn "tap failed: $tap"
}

install_taps() {
  command -v yq >/dev/null || return
  while IFS= read -r tap; do
    [[ -z "$tap" || "$tap" == "null" ]] && continue
    install_tap "$tap"
  done < <(yq e '.taps[]' "$STACK" 2>/dev/null || true)
}

install_pkg() {
  local pkg="$1"
  brew list --formula "$pkg" &>/dev/null && return
  metric_install_start "$pkg" 2>/dev/null || true
  local t_start; t_start=$(now_ms)
  if brew install "$pkg"; then
    local t_end; t_end=$(now_ms)
    metric_install_ok "$pkg" $(( t_end - t_start )) 2>/dev/null || true
  else
    metric_install_fail "$pkg" 2>/dev/null || true
    warn "failed: $pkg"
  fi
}

install_cask() {
  local pkg="$1"
  brew list --cask "$pkg" &>/dev/null && return
  metric_install_start "$pkg" 2>/dev/null || true
  local t_start; t_start=$(now_ms)
  if brew install --cask "$pkg"; then
    local t_end; t_end=$(now_ms)
    metric_install_ok "$pkg" $(( t_end - t_start )) 2>/dev/null || true
  else
    metric_install_fail "$pkg" 2>/dev/null || true
    warn "failed cask: $pkg"
  fi
}

install_group() {
  local group="$1"
  
  # Im Container: host_only Gruppen überspringen
  if is_container; then
    local host_only
    host_only=$(yq e ".groups.${group}.host_only // false" "$STACK" 2>/dev/null || echo "false")
    if [[ "$host_only" == "true" ]]; then
      info "Skipping host_only group in container: $group"
      return 0
    fi
  fi

  # apple_only: nur auf macOS Apple Silicon (arm64) installieren
  local apple_only
  apple_only=$(yq e ".groups.${group}.apple_only // false" "$STACK" 2>/dev/null || echo "false")
  if [[ "$apple_only" == "true" ]]; then
    if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
      info "Skipping apple_only group (requires macOS Apple Silicon): $group"
      return 0
    fi
  fi
  
  command -v yq >/dev/null || { warn "yq not found, skipping YAML install for $group"; return; }
  info "Installing group: $group"

  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == "null" ]] && continue
    install_pkg "$pkg"
  done < <(yq e ".groups.${group}.brew[]" "$STACK" 2>/dev/null || true)

  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == "null" ]] && continue
    install_cask "$pkg"
  done < <(yq e ".groups.${group}.cask[]" "$STACK" 2>/dev/null || true)

  while IFS= read -r repo_url; do
    [[ -z "$repo_url" || "$repo_url" == "null" ]] && continue
    local dest
    dest=$(yq e ".groups.${group}.git_repos[] | select(.repo == \"${repo_url}\") | .dest" "$STACK" 2>/dev/null || true)
    dest="${dest/#\~/$HOME}"
    dest="${dest/\$DEV_PATH/$DEV_PATH}"
    mkdir -p "$(dirname "$dest")"
    [[ -d "$dest" ]] && continue
    git clone "$repo_url" "$dest" || warn "clone failed: $repo_url"
  done < <(yq e ".groups.${group}.git_repos[].repo" "$STACK" 2>/dev/null || true)

  # post_install per git_repo
  while IFS= read -r repo_url; do
    [[ -z "$repo_url" || "$repo_url" == "null" ]] && continue
    local post_cmd
    post_cmd=$(yq e ".groups.${group}.git_repos[] | select(.repo == \"${repo_url}\") | .post_install" "$STACK" 2>/dev/null || true)
    [[ -z "$post_cmd" || "$post_cmd" == "null" ]] && continue
    local dest
    dest=$(yq e ".groups.${group}.git_repos[] | select(.repo == \"${repo_url}\") | .dest" "$STACK" 2>/dev/null || true)
    dest="${dest/#\~/$HOME}"
    dest="${dest/\$DEV_PATH/$DEV_PATH}"
    post_cmd="${post_cmd/\$DEV_PATH/$DEV_PATH}"
    if [[ -d "$dest" ]]; then
      info "Running post_install for $repo_url..."
      eval "$post_cmd" || warn "post_install failed for $repo_url"
    fi
  done < <(yq e ".groups.${group}.git_repos[].repo" "$STACK" 2>/dev/null || true)
}

install_profile() {
  local profile="$1"
  info "Installing profile: $profile"
  while IFS= read -r group; do
    [[ -z "$group" || "$group" == "null" ]] && continue
    install_group "$group"
  done < <(yq e ".profiles.${profile}.groups[]" "$STACK" 2>/dev/null)
  mkdir -p "$(dirname "$PROFILE_FILE")"
  echo "$profile" > "$PROFILE_FILE"
  metric_profile_set "$profile" 2>/dev/null || true
  info "Profile '${profile}' saved."
}

# -----------------------------------------
# FLAGS + MAIN
# -----------------------------------------

PROFILE="" INSTALL_GROUPS=""
DO_BASE=0 DO_GO=0 DO_IAC=0 DO_DOCKER=0 DO_ALL=0

while getopts "p:g:bGIDA" opt; do
  case "$opt" in
    p) PROFILE="$OPTARG" ;;
    g) INSTALL_GROUPS="$OPTARG" ;;
    b) DO_BASE=1 ;;
    G) DO_GO=1 ;;
    I) DO_IAC=1 ;;
    D) DO_DOCKER=1 ;;
    A) DO_ALL=1 ;;
  esac
done

main() {
  sudo_keepalive
  install_brew
  install_zb
  install_mise
  install_nix
  install_auto_upgrade

  brew update --quiet

  install_taps

  # Ensure core tools first (yq needed for YAML parsing)
  for p in git curl jq yq; do
    command -v "$p" &>/dev/null || brew install "$p" || true
  done

  if [[ -n "$PROFILE" ]]; then
    install_profile "$PROFILE"
  elif [[ -n "$INSTALL_GROUPS" ]]; then
    IFS=',' read -ra group_list <<< "$INSTALL_GROUPS"
    for g in "${group_list[@]}"; do
      install_group "$(echo "$g" | tr -d ' ')"
    done
  else
    # Shortcut flags
    [[ "$DO_ALL" -eq 1 ]]    && install_profile dp && return
    [[ "$DO_BASE" -eq 1 ]]   && install_group base
    [[ "$DO_GO" -eq 1 ]]     && install_group go-dev
    [[ "$DO_IAC" -eq 1 ]]    && install_group iac
    [[ "$DO_DOCKER" -eq 1 ]] && install_group docker
    # Default: base tools only
    [[ "$DO_BASE$DO_GO$DO_IAC$DO_DOCKER" == "0000" ]] && install_group base
  fi

  info "Setup complete. Run 'dev metrics' to see install history."
}

main "$@"
