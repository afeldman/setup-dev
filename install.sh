#!/usr/bin/env bash
# install.sh — Remote-Installer für setup-dev
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/afeldman/setup-dev/refs/heads/master/install.sh | bash
#
# Installiert:
#   1. Homebrew   (macOS + Linux)
#   2. Nix        (optional, multi-user auf Linux / single-user auf macOS)
#   3. GoFish     (cross-platform package manager)
#   4. ZeroBrew   (schnelle parallele Updates)
#   5. Klont setup-dev und startet bootstrap.sh
#
# Läuft auf: macOS 12+ (Intel + Apple Silicon), Ubuntu/Debian/Fedora/Arch (x86_64 + arm64)

set -euo pipefail

# ─── Argumente ───────────────────────────────────────────────────────────────
PROFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2 ;;
    -y|--yes)     SKIP_CONFIRM=1; shift ;;
    *) shift ;;
  esac
done
SKIP_CONFIRM="${SKIP_CONFIRM:-0}"

# ─── Farben ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
ok()      { echo -e "${GREEN}[ OK ]${RESET} $*"; }
skip()    { echo -e "${GREEN}[SKIP]${RESET} $* 👍"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()     { echo -e "${RED}[ERR ]${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}$*${RESET}"; }
die()     { err "$*"; exit 1; }

# ─── OS + Architektur erkennen ────────────────────────────────────────────────
detect_platform() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"

  case "$OS" in
    Darwin)  PLATFORM="macos" ;;
    Linux)   PLATFORM="linux" ;;
    *)       die "Nicht unterstütztes Betriebssystem: $OS" ;;
  esac

  case "$ARCH" in
    x86_64)           ARCH_NORM="x86_64" ;;
    arm64 | aarch64)  ARCH_NORM="arm64"  ;;
    *)                die "Nicht unterstützte Architektur: $ARCH" ;;
  esac

  info "Plattform: ${PLATFORM} / ${ARCH_NORM}"
}

# ─── Voraussetzungen prüfen ───────────────────────────────────────────────────
check_prerequisites() {
  header "Voraussetzungen prüfen..."
  local missing=()

  for cmd in curl git bash; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    err "Fehlende Abhängigkeiten: ${missing[*]}"
    if [[ "$PLATFORM" == "linux" ]]; then
      info "Installiere mit: sudo apt-get install -y ${missing[*]}  (oder dnf/pacman)"
    fi
    die "Bitte fehlende Tools installieren und erneut ausführen."
  fi

  ok "Alle Voraussetzungen erfüllt"
}

# ─── Homebrew ─────────────────────────────────────────────────────────────────
install_homebrew() {
  header "Homebrew..."

  if command -v brew &>/dev/null; then
    skip "Homebrew schon da: $(brew --version | head -1)"
    return
  fi

  info "Installiere Homebrew..."

  if [[ "$PLATFORM" == "macos" ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    # Linux: Linuxbrew in $HOME/.linuxbrew oder /home/linuxbrew/.linuxbrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Shellkonfiguration für Linuxbrew
    local brew_paths=(
      "/home/linuxbrew/.linuxbrew/bin/brew"
      "${HOME}/.linuxbrew/bin/brew"
    )
    for brew_bin in "${brew_paths[@]}"; do
      if [[ -x "$brew_bin" ]]; then
        eval "$("$brew_bin" shellenv)"
        _add_to_profile "eval \"\$(${brew_bin} shellenv)\""
        break
      fi
    done
  fi

  command -v brew &>/dev/null || die "Homebrew-Installation fehlgeschlagen"
  ok "Homebrew installiert: $(brew --version | head -1)"
}

# ─── Nix ──────────────────────────────────────────────────────────────────────
install_nix() {
  header "Nix..."

  if command -v nix &>/dev/null; then
    skip "Nix schon da: $(nix --version)"
    return
  fi

  info "Installiere Nix (Determinate Systems Installer)..."

  # Determinate Systems Installer: zuverlässiger als der offizielle auf macOS + Linux
  if curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm; then
    # Nix in PATH laden (Installer hinterlässt Profile-Eintrag)
    if [[ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]]; then
      # shellcheck source=/dev/null
      source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    ok "Nix installiert: $(nix --version 2>/dev/null || echo 'verfügbar nach Neustart')"
  else
    warn "Nix-Installation fehlgeschlagen — wird übersprungen (nicht kritisch)"
  fi
}

# ─── GoFish ───────────────────────────────────────────────────────────────────
install_gofish() {
  header "GoFish..."

  if command -v gofish &>/dev/null; then
    skip "GoFish schon da: $(gofish version 2>/dev/null || echo 'ok')"
    return
  fi

  info "Installiere GoFish..."

  # GoFish benötigt Go — via Homebrew sicherstellen
  if ! command -v go &>/dev/null; then
    info "Go nicht gefunden — installiere via Homebrew..."
    brew install go
  fi

  # GoFish aus unserem Fork installieren
  GOBIN="${HOME}/.local/bin" go install github.com/afeldman/gofish@latest 2>/dev/null \
    || go install github.com/nicholasgasior/gsfmt@latest 2>/dev/null \
    || {
      # Fallback: offizieller GoFish via curl-Installer
      info "Installiere GoFish via offiziellen Installer..."
      curl -fsSL https://raw.githubusercontent.com/fishworks/gofish/main/scripts/install.sh | bash
    }

  _add_to_profile 'export PATH="${HOME}/.local/bin:${PATH}"'
  export PATH="${HOME}/.local/bin:${PATH}"

  if command -v gofish &>/dev/null; then
    gofish init 2>/dev/null || true
    ok "GoFish installiert"
  else
    warn "GoFish konnte nicht installiert werden — wird übersprungen"
  fi
}

# ─── ZeroBrew ─────────────────────────────────────────────────────────────────
install_zerobrew() {
  header "ZeroBrew..."

  if command -v zb &>/dev/null; then
    skip "ZeroBrew schon da: $(zb --version 2>/dev/null || echo 'ok')"
    return
  fi

  info "Installiere ZeroBrew..."

  if curl -fsSL https://zerobrew.rs/install | bash; then
    ok "ZeroBrew installiert"
  else
    warn "ZeroBrew-Installation fehlgeschlagen — wird übersprungen (nicht kritisch)"
  fi
}

# ─── setup-dev klonen und ausführen ───────────────────────────────────────────
install_setup_dev() {
  header "setup-dev..."

  local repo_url="${SETUP_DEV_REPO_URL:-https://github.com/afeldman/setup-dev.git}"
  local dest="${SETUP_DEV_DIR:-${HOME}/.local/share/setup-dev}"
  local run_bootstrap="${SKIP_BOOTSTRAP:-0}"

  if [[ -d "$dest/.git" ]]; then
    skip "setup-dev schon da in ${dest} (Klonen wird ausgelassen)"
    info "Aktualisiere setup-dev Checkout..."
    git -C "$dest" pull --ff-only --quiet || warn "git pull fehlgeschlagen - nutze vorhandenen Stand"
  else
    info "Klone setup-dev nach ${dest}..."
    git clone --depth 1 "$repo_url" "$dest" || die "git clone fehlgeschlagen: ${repo_url}"
  fi

  [[ -f "${dest}/bootstrap.sh" ]] || die "bootstrap.sh nicht gefunden in ${dest}"
  chmod +x "${dest}/bootstrap.sh" "${dest}/dev" 2>/dev/null || true

  # Symlink: dev-Befehl global verfügbar machen
  local bin_dir="${SETUP_DEV_BIN_DIR:-${HOME}/.local/bin}"
  mkdir -p "$bin_dir"
  ln -sf "${dest}/dev" "${bin_dir}/dev" 2>/dev/null || true
  ln -sf "${dest}/scripts" "${bin_dir}/scripts" 2>/dev/null || true
  ln -sf "${dest}/healing" "${bin_dir}/healing" 2>/dev/null || true
  ln -sf "${dest}/agent" "${bin_dir}/agent" 2>/dev/null || true
  in -sf "${dest}/telemetry" "${bin_dir}/telemetry" 2>/dev/null || true
  ln -sf "${dest}/gitops" "${bin_dir}/gitops" 2>/dev/null || true
  if [[ "$bin_dir" == "${HOME}/.local/bin" ]]; then
    _add_to_profile 'export PATH="${HOME}/.local/bin:${PATH}"'
  fi
  export PATH="${bin_dir}:${PATH}"

  ok "setup-dev installiert in ${dest}"
  echo ""
  if [[ "$run_bootstrap" == "1" ]]; then
    info "SKIP_BOOTSTRAP=1 - bootstrap.sh wird ausgelassen"
    return
  fi

  if [[ -n "$PROFILE" ]]; then
    info "Starte bootstrap.sh mit Profil: ${PROFILE}..."
    SKIP_NIX_INSTALL=1 bash "${dest}/bootstrap.sh" -p "$PROFILE" || warn "bootstrap.sh mit Fehlern beendet"
  else
    info "Starte bootstrap.sh (base-Gruppe)..."
    SKIP_NIX_INSTALL=1 bash "${dest}/bootstrap.sh" || warn "bootstrap.sh mit Fehlern beendet"
  fi
}

# ─── Shell-Profil aktualisieren ───────────────────────────────────────────────
_add_to_profile() {
  local line="$1"
  local profiles=("${HOME}/.zshrc" "${HOME}/.bashrc" "${HOME}/.bash_profile")

  for profile in "${profiles[@]}"; do
    [[ -f "$profile" ]] || continue
    grep -qF "$line" "$profile" 2>/dev/null && continue
    echo "$line" >> "$profile"
  done
}

# ─── Abschluss-Zusammenfassung ────────────────────────────────────────────────
print_summary() {
  header "Installation abgeschlossen"
  echo ""
  echo "  Installierte Tools:"
  for cmd in brew nix gofish zb dev; do
    if command -v "$cmd" &>/dev/null; then
      echo -e "    ${GREEN}✓${RESET} $cmd"
    else
      echo -e "    ${YELLOW}~${RESET} $cmd (ggf. Neustart nötig)"
    fi
  done
  echo ""
  echo "  Nächste Schritte:"
  if [[ -z "$PROFILE" ]]; then
    echo "    dev install -p work    # Arbeits-Stack (Homebrew Casks)"
    echo "    dev install -p dp      # Developer Pro Stack"
    echo "    dev install -p yp      # Personal AI Stack"
    echo "    dev install -p devops  # DevOps Stack (Source-Build)"
    echo "    dev ui                 # Interaktiver Installer"
  else
    echo "    Profil '${PROFILE}' wurde bereits installiert."
    echo "    dev doctor             # Zustand prüfen"
    echo "    dev drift              # Abweichungen anzeigen"
  fi
  echo ""
  echo -e "  ${YELLOW}Hinweis:${RESET} Shell neu starten oder 'source ~/.zshrc' ausführen,"
  echo "  damit alle PATH-Änderungen aktiv werden."
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║        setup-dev Installer           ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
  echo ""

  detect_platform
  check_prerequisites
  install_homebrew
  install_nix
  install_gofish
  install_zerobrew
  install_setup_dev
  print_summary
}

main "$@"
