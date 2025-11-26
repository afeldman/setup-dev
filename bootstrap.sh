#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------
# Helper Output
# -----------------------------------------
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERR ]\033[0m $*"; }

usage() {
  cat <<EOF
Usage: $0 [OPTIONEN]

Ohne Optionen:
  - falls Profile definiert sind: Profil "yp" verwenden (wenn vorhanden),
    sonst alle Gruppen installieren.

Optionen:
  -f PATH    Pfad zur YAML-Config (Default: ./software-stack.yaml)
  -p NAME    Profilname (z.B. yp, dp, jp, mp)
  -g LISTE   Kommagetrennte Gruppen (z.B. base,ollama,pai,docker,vscode)
  -h         Hilfe anzeigen

Dev-Stack Shortcut-Flags (können kombiniert werden):
  -b         Basis-Tools (git, curl, jq, yq, fzf, uv, dos2unix, fabric-ai)
  -G         Go-Stack (go, go-task, goreleaser, golangci-lint, graphviz)
  -I         IaC-Stack (terraform, kubernetes-cli, awscli, tflint, checkov)
  -D         Docker-Stack (docker, docker-compose, lazydocker)
  -A         Alle Dev-Tools (Base + Go + IaC + Docker)

Beispiele:
  $0
    -> benutzt Profil 'yp' (falls vorhanden), sonst alle Gruppen

  $0 -p dp
    -> installiert das Developer Pro Profil

  $0 -g base,ollama,obsidian
    -> installiert nur diese Gruppen, ohne Profil

  $0 -b -D
    -> installiert Basis-Tools + Docker (Dev-Stack Shortcuts)

  $0 -A
    -> installiert alle Dev-Tools (Base + Go + IaC + Docker)
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YAML_FILE="$SCRIPT_DIR/software-stack.yaml"

PROFILE=""
GROUPS_CLI=""
OS="$(uname -s)"

# Dev-Stack Flags
DEV_BASE=0
DEV_GO=0
DEV_IAC=0
DEV_DOCKER=0
DEV_ALL=0

if [[ "$OS" != "Darwin" && "$OS" != "Linux" ]]; then
  error "Dieses Script unterstützt nur macOS und Linux. Aktuelles OS: $OS"
  exit 1
fi

# -----------------------------------------
# Argument Parsing
# -----------------------------------------
while getopts ":f:p:g:bGIDAh" opt; do
  case "$opt" in
    f) YAML_FILE="$OPTARG" ;;
    p) PROFILE="$OPTARG" ;;
    g) GROUPS_CLI="$OPTARG" ;;
    b) DEV_BASE=1 ;;
    G) DEV_GO=1 ;;
    I) DEV_IAC=1 ;;
    D) DEV_DOCKER=1 ;;
    A) DEV_ALL=1 ;;
    h)
      usage
      exit 0
      ;;
    \?)
      error "Unbekannte Option: -$OPTARG"
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# -----------------------------------------
# Homebrew & yq Setup
# -----------------------------------------
install_brew_if_missing() {
  if command -v brew >/dev/null 2>&1; then
    info "Homebrew bereits installiert."
    return
  fi

  info "Homebrew nicht gefunden – installiere Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi

  local shell_rc=""
  case "${SHELL:-}" in
    */bash) shell_rc="$HOME/.bashrc" ;;
    */zsh)  shell_rc="$HOME/.zshrc" ;;
  esac

  if [[ -n "$shell_rc" && -x "$(command -v brew)" ]]; then
    {
      echo
      echo "# Homebrew (auto-added by bootstrap.sh)"
      brew shellenv
    } >> "$shell_rc"
  fi
}

install_yq_if_missing() {
  if command -v yq >/dev/null 2>&1; then
    info "yq bereits installiert."
    return
  fi

  install_brew_if_missing
  info "Installiere yq über Homebrew..."
  brew install yq
}

# -----------------------------------------
# YAML Parsing Helpers
# -----------------------------------------
dedupe_array() {
  local array_name="$1"
  local temp_val
  local count
  
  # Prüfe Anzahl der Elemente
  eval "count=\${#${array_name}[@]}"
  
  if [[ "$count" -gt 0 ]]; then
    # Temporärer String mit allen Werten
    eval "temp_val=\"\${${array_name}[@]}\""
    
    # Array leeren und deduplizierte Werte wieder hinzufügen
    eval "${array_name}=()"
    while IFS= read -r line; do
      [[ -n "$line" ]] && eval "${array_name}+=(\"\$line\")"
    done < <(printf "%s\n" $temp_val | sort -u)
  fi
}

profile_exists() {
  local name="$1"
  yq -e ".profiles.\"$name\"" "$YAML_FILE" >/dev/null 2>&1
}

group_exists() {
  local name="$1"
  yq -e ".groups.\"$name\"" "$YAML_FILE" >/dev/null 2>&1
}

resolve_groups_from_profile() {
  local name="$1"
  yq -r ".profiles.\"$name\".groups[]?" "$YAML_FILE" 2>/dev/null || true
}

all_groups_from_yaml() {
  yq -r '.groups | keys[]' "$YAML_FILE" 2>/dev/null || true
}

default_profile() {
  # Falls 'yp' existiert, nimm das als Default
  if profile_exists "yp"; then
    echo "yp"
  else
    echo ""
  fi
}

# -----------------------------------------
# Main Logic
# -----------------------------------------
main() {
  if [[ ! -f "$YAML_FILE" ]]; then
    error "YAML-File nicht gefunden: $YAML_FILE"
    exit 1
  fi

  install_yq_if_missing

  info "Verwende YAML-Config: $YAML_FILE"

  INSTALL_GROUPS=()

  # Dev-Stack Shortcuts hinzufügen
  DEV_GROUPS=()
  if (( DEV_ALL )); then
    DEV_BASE=1
    DEV_GO=1
    DEV_IAC=1
    DEV_DOCKER=1
  fi
  
  if (( DEV_BASE )); then
    DEV_GROUPS+=("base")
    info "Dev-Stack: Basis-Tools hinzugefügt"
  fi
  if (( DEV_GO )); then
    DEV_GROUPS+=("go-dev")
    info "Dev-Stack: Go-Tools hinzugefügt"
  fi
  if (( DEV_IAC )); then
    DEV_GROUPS+=("iac")
    info "Dev-Stack: IaC-Tools hinzugefügt"
  fi
  if (( DEV_DOCKER )); then
    DEV_GROUPS+=("docker")
    info "Dev-Stack: Docker hinzugefügt"
  fi

  if [[ -n "$GROUPS_CLI" ]]; then
    # Direkte Gruppen via -g
    IFS=',' read -r -a INSTALL_GROUPS <<< "$GROUPS_CLI"
    # Dev-Gruppen hinzufügen
    INSTALL_GROUPS+=("${DEV_GROUPS[@]}")
    info "Verwende explizit angegebene Gruppen: ${INSTALL_GROUPS[*]}"
  elif ((${#DEV_GROUPS[@]} > 0)); then
    # Nur Dev-Stack Shortcuts verwendet
    INSTALL_GROUPS=("${DEV_GROUPS[@]}")
    info "Verwende Dev-Stack Gruppen: ${INSTALL_GROUPS[*]}"
  else
    # Profil-basiert
    local prof="$PROFILE"
    if [[ -z "$prof" ]]; then
      prof="$(default_profile)"
      if [[ -n "$prof" ]]; then
        info "Kein Profil angegeben – verwende Default-Profil: $prof"
      fi
    fi

    if [[ -n "$prof" ]]; then
      if ! profile_exists "$prof"; then
        error "Profil '$prof' existiert nicht im YAML."
        exit 1
      fi
      mapfile -t INSTALL_GROUPS < <(resolve_groups_from_profile "$prof")
      info "Profil '$prof' gewählt – Gruppen: ${INSTALL_GROUPS[*]}"
    else
      # kein Profil, keine Gruppen: alle Gruppen
      mapfile -t INSTALL_GROUPS < <(all_groups_from_yaml)
      info "Kein Profil / keine Gruppen – installiere alle Gruppen: ${INSTALL_GROUPS[*]}"
    fi
  fi

  # Safety: nur existierende Gruppen behalten
  VALID_GROUPS=()
  for g in "${INSTALL_GROUPS[@]}"; do
    if group_exists "$g"; then
      VALID_GROUPS+=("$g")
    else
      warn "Gruppe '$g' existiert nicht im YAML – überspringe."
    fi
  done

  if ((${#VALID_GROUPS[@]} == 0)); then
    error "Es sind keine gültigen Gruppen übrig – Abbruch."
    exit 1
  fi

  dedupe_array VALID_GROUPS
  info "Finale Gruppenliste: ${VALID_GROUPS[*]}"

  BREW_FORMULAS=()
  CASKS=()
  GIT_REPOS=()

  # Gruppen-Inhalte einsammeln
  for grp in "${VALID_GROUPS[@]}"; do
    info "Lese Gruppe: $grp"

    local formulas
    formulas=$(yq -r ".groups.\"$grp\".brew[]?" "$YAML_FILE" 2>/dev/null || true)
    if [[ -n "${formulas:-}" ]]; then
      while IFS= read -r f; do
        [[ -n "$f" ]] && BREW_FORMULAS+=("$f")
      done <<< "$formulas"
    fi

    local casks
    casks=$(yq -r ".groups.\"$grp\".cask[]?" "$YAML_FILE" 2>/dev/null || true)
    if [[ -n "${casks:-}" ]]; then
      while IFS= read -r c; do
        [[ -n "$c" ]] && CASKS+=("$c")
      done <<< "$casks"
    fi

    local repos
    repos=$(yq -r ".groups.\"$grp\".git_repos[]? | \"\(.repo)|\(.dest)\"" "$YAML_FILE" 2>/dev/null || true)
    if [[ -n "${repos:-}" ]]; then
      while IFS= read -r line; do
        # Nur Zeilen mit repo UND dest hinzufügen (nicht "|" alleine)
        [[ -n "$line" && "$line" != "|" && "$line" =~ .*\|.+ ]] && GIT_REPOS+=("$line")
      done <<< "$repos"
    fi
  done

  dedupe_array BREW_FORMULAS
  dedupe_array CASKS
  dedupe_array GIT_REPOS

  install_brew_if_missing

  # 1) Brew CLI Pakete
  if ((${#BREW_FORMULAS[@]} > 0)); then
    info "Installiere/aktualisiere Brew-Formulas: ${BREW_FORMULAS[*]}"
    brew update
    for pkg in "${BREW_FORMULAS[@]}"; do
      if brew list --versions "$pkg" >/dev/null 2>&1; then
        info "$pkg ist bereits installiert – versuche Upgrade..."
        brew upgrade "$pkg" 2>/dev/null || warn "$pkg konnte nicht aktualisiert werden (evtl. schon aktuell)."
      else
        info "Installiere $pkg ..."
        brew install "$pkg" 2>/dev/null || warn "$pkg konnte nicht installiert werden."
      fi
    done
  else
    warn "Keine Brew-Formulas zu installieren."
  fi

  # 2) Brew Casks (nur macOS)
  if [[ "$OS" == "Darwin" ]] && ((${#CASKS[@]} > 0)); then
    info "Installiere/aktualisiere Casks: ${CASKS[*]}"
    for c in "${CASKS[@]}"; do
      if brew list --cask --versions "$c" >/dev/null 2>&1; then
        info "Cask $c ist bereits installiert – versuche Upgrade..."
        brew upgrade --cask "$c" 2>/dev/null || warn "Cask $c konnte nicht aktualisiert werden (evtl. schon aktuell oder manuell installiert)."
      else
        info "Installiere Cask $c ..."
        brew install --cask "$c" 2>/dev/null || warn "Cask $c konnte nicht installiert werden (evtl. bereits manuell installiert)."
      fi
    done
  elif [[ "$OS" != "Darwin" ]] && ((${#CASKS[@]} > 0)); then
    warn "Casks sind auf Linux nicht verfügbar – überspringe: ${CASKS[*]}"
  fi

  # 3) Git-Repos (z.B. PAI)
  if ((${#GIT_REPOS[@]} > 0)); then
    if ! command -v git >/dev/null 2>&1; then
      info "git nicht gefunden – installiere via brew..."
      brew install git
    fi

    for entry in "${GIT_REPOS[@]}"; do
      local repo dest
      repo="${entry%%|*}"
      dest="${entry#*|}"

      dest="${dest/#\~/$HOME}"  # ~ expandieren

      info "Verarbeite Repo: $repo -> $dest"

      if [[ -d "$dest/.git" ]]; then
        info "Repo existiert bereits, führe git pull aus..."
        git -C "$dest" pull --ff-only || warn "git pull für $dest fehlgeschlagen."
      else
        mkdir -p "$(dirname "$dest")"
        info "Klonen nach $dest ..."
        git clone "$repo" "$dest"
      fi
    done
  fi

  info "FERTIG 🎉 AI-Stack Installation abgeschlossen."
  info "Hinweise:"
  echo " - Ollama: 'ollama serve' und z.B. 'ollama pull llama3'"
  echo " - LM Studio & Obsidian: als Apps (macOS Launchpad)"
  echo " - PAI: liegt unter dem Pfad aus dem YAML (z.B. ~/Projects/Personal_AI_Infrastructure)"
}

main "$@"
