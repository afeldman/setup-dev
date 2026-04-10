# setup-dev — Lokaler AI/Dev-Stack Bootstrapper

Automatisiert die Installation und Konfiguration eines lokalen Entwicklungs- und AI-Stacks auf macOS und Linux. Die gesamte Konfiguration liegt in `software-stack.yaml`.

## Remote-Installation (empfohlen)

Installiert Homebrew, Nix, GoFish, ZeroBrew, klont setup-dev und startet `bootstrap.sh` — ein Befehl, frischer Rechner:

```bash
curl -fsSL https://raw.githubusercontent.com/afeldman/setup-dev/refs/heads/master/install.sh | bash
```

Läuft auf macOS (Intel + Apple Silicon) und Linux (x86_64 + arm64).

## Manuelle Installation

```bash
git clone https://github.com/afeldman/setup-dev.git
cd setup-dev
./bootstrap.sh
```

## Schnellstart

```bash
# Basis-Tools installieren (Standard)
./bootstrap.sh

# setup-dev selbst aktualisieren und erneut anwenden
./update.sh

# setup-dev entfernen (nur dev-Link)
./uninstall.sh

# setup-dev komplett entfernen (inkl. Installationsordner)
./uninstall.sh --purge

# Profil wählen
./bootstrap.sh -p yp    # Personal AI Stack
./bootstrap.sh -p dp    # Developer Pro (vollständig)
./bootstrap.sh -p jp    # Just Prompts (leicht)

# Einzelne Gruppen
./bootstrap.sh -g base,ollama,fabric

# Shortcut-Flags (kombinierbar)
./bootstrap.sh -b        # base
./bootstrap.sh -b -G     # base + go-dev
./bootstrap.sh -b -I -D  # base + iac + docker
./bootstrap.sh -A        # alles (dp-Profil)
```

Das Script fragt **einmalig am Anfang nach dem sudo-Passwort** und hält die Session automatisch aktiv — es wird nicht mehr mitten in einer Installation unterbrochen.

## `dev` — Zentrales CLI

Nach dem ersten Bootstrap steht das `./dev`-Script als Einstiegspunkt zur Verfügung:

```bash
./dev install [-p profil] [-g gruppen] [-b -G -I -D -A]
./dev doctor          # Tool-Status + aktives Profil anzeigen
./dev ui              # Interaktiver Profil-Selektor (TUI)
./dev up              # mise + nix initialisieren

./dev drift           # Soll- vs. Ist-Zustand anzeigen (JSON)
./dev heal            # Drift interaktiv beheben
./dev heal --auto     # Drift automatisch beheben

./dev metrics         # Install-History anzeigen
./dev test-install    # Nicht-invasiven Sandbox-Test fuer install.sh ausfuehren

./dev agent           # Gruppen für aktuelles Projekt empfehlen (Ollama/Heuristik)
./dev agent --install # Empfehlung direkt installieren

./dev gitops diff     # Lokaler vs. Git-Desired-State
./dev gitops push     # Machine-State in Git committen
./dev gitops pull     # Letzten State pullen + Drift prüfen

./dev container dp    # Dev Container starten (dp | devops | yp)
./dev git-signing     # GPG Commit-Signing konfigurieren
./dev sync            # State zu/von AWS S3 synchronisieren
```

## Profile

| Profil    | Beschreibung                                              |
|-----------|-----------------------------------------------------------|
| `yp`      | Personal AI Stack: base + Ollama + Fabric + PAI + Obsidian |
| `dp`      | Developer Pro: alles (AI, Docker, Go, Rust, Python, IaC)  |
| `jp`      | Just Prompts: base + Fabric + Obsidian                    |
| `mp`      | Model Playground: base + Ollama + LM Studio               |
| `devops`  | DevOps Stack: base + IaC + Docker + K8s + GitOps          |

## Gruppen

| Gruppe        | Enthält                                                  |
|---------------|----------------------------------------------------------|
| `base`        | git, curl, jq, yq, uv, fzf, dos2unix, gum, goose-cli    |
| `ollama`      | ollama                                                   |
| `lmstudio`    | lm-studio (Cask, nur macOS)                              |
| `obsidian`    | obsidian (Cask, nur macOS)                               |
| `fabric`      | fabric-ai                                                |
| `pai`         | bun + Personal AI Infrastructure (Git Repo)              |
| `docker`      | docker, docker-compose, lazydocker, docker-desktop       |
| `vscode`      | visual-studio-code, cursor, code-server                  |
| `python-dev`  | python 3.11/3.12, poetry, pyenv, jupyter, ruff, mypy     |
| `nodejs`      | node, nvm, pnpm, yarn                                    |
| `go-dev`      | go, go-task, goreleaser, golangci-lint, graphviz         |
| `rust-dev`    | rust, rust-analyzer, cargo-watch, cargo-edit             |
| `iac`         | terraform, kubectl, awscli, tflint, checkov, k9s         |
| `databases`   | postgresql@16, redis, sqlite                             |
| `vectordb`    | qdrant                                                   |
| `fluxcd`      | flux (GitOps CLI)                                        |
| `harbor`      | docker-compose (Harbor läuft als Compose/Helm)           |
| `gofish`      | GoFish Package Manager + fish-food klonen + `gotofish setup` |
| `my-tools`    | Eigene Go-Tools via `gotofish sync` (setzt `gofish` voraus) |
| `productivity`| raycast, rectangle, fork, iterm2, bruno (nur macOS)      |

Gruppen mit `host_only: true` werden in Dev Containern automatisch übersprungen.

## Konfiguration erweitern

Alle Änderungen gehören in `software-stack.yaml` — das ist die einzige Quelle der Wahrheit.

### Neue Gruppe

```yaml
groups:
  my-tools:
    description: "Meine Tools"
    brew:
      - htop
    cask:
      - visual-studio-code
    git_repos:
      - repo: "https://github.com/user/repo.git"
        dest: "~/Projects/repo"
        post_install: "cd ~/Projects/repo && make install"
```

### Neues Profil

```yaml
profiles:
  my-profile:
    description: "Mein Stack"
    groups:
      - base
      - my-tools
```

### DEV_PATH anpassen

Zielverzeichnis für geklonte Git-Repos (Standard: `/opt/dev`):

```bash
export DEV_PATH=~/Projects  # in ~/.zshrc setzen
```

## GoFish Tools

Das `dp`-Profil installiert [GoFish](https://github.com/afeldman/gofish) und richtet automatisch das [fish-food](https://github.com/afeldman/fish-food)-Rig ein. Danach sind alle eigenen Tools direkt installierbar:

```bash
gofish install batch-cost
gofish install cloudlogin
gofish install cpctl
```

`gotofish` (aus [afeldman/scripts](https://github.com/afeldman/scripts)) verwaltet alle Tools auf einmal:

```bash
gotofish sync       # update + install missing + upgrade outdated
gotofish list       # verfügbare vs. installierte Versionen
gotofish upgrade    # alle Tools upgraden
gotofish remove batch-cost
```

## Self-Healing

Das System erkennt automatisch Abweichungen zwischen dem gewünschten Zustand (Profil in `software-stack.yaml`) und dem tatsächlich installierten Stand:

```bash
./dev drift           # zeigt fehlende Pakete als JSON
./dev heal            # fragt nach, dann installiert Fehlendes
./dev heal --auto     # installiert ohne Rückfrage
```

## AI Agent

Analysiert ein Projektverzeichnis und empfiehlt passende Gruppen — erst via lokalem Ollama-Modell, bei Fehlen als regelbasierte Heuristik:

```bash
./dev agent                        # Empfehlung für aktuelles Verzeichnis
./dev agent --dir=/pfad/zu/projekt # Anderes Verzeichnis analysieren
./dev agent --install              # Direkt installieren
```

## Dev Container

Für jedes Profil gibt es einen fertigen Dev Container unter `.devcontainer/<profil>/`:

```bash
./dev container dp      # Developer Pro
./dev container devops  # DevOps Stack
./dev container yp      # Personal AI Stack
```

Benötigt entweder die `devcontainer`-CLI oder Docker.

## Telemetrie

Alle Installationen werden lokal in `~/.local/share/dev-setup/metrics.jsonl` geloggt (JSONL-Format, kein Netzwerkzugriff):

```bash
./dev metrics   # Report anzeigen
```

## Voraussetzungen

- macOS oder Linux (Ubuntu, Debian, ...)
- Bash 4.0+
- Internetverbindung
- Homebrew und `yq` werden automatisch installiert, falls nicht vorhanden
- Für einige Schritte werden Admin-Rechte benötigt (sudo) — das Script fragt einmalig am Start

## Installer testen (nicht-invasiv)

Der Installer kann lokal in einer isolierten Sandbox getestet werden, ohne dein echtes HOME zu veraendern:

```bash
./dev test-install
```

Optional bleibt die Sandbox zur Analyse erhalten:

```bash
KEEP_SANDBOX=1 ./dev test-install
```

## Lizenz

MIT
