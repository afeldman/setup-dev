# Setup Dev - Lokaler AI/Dev-Stack Bootstrapper

Dieses Projekt automatisiert die Installation und Konfiguration deines lokalen Entwicklungs- und AI-Stacks auf macOS und Linux.

## 📋 Überblick

Das Bootstrap-Script (`bootstrap.sh`) liest die Konfiguration aus `software-stack.yaml` und installiert:

- **CLI-Tools** via Homebrew (git, curl, jq, yq, uv, etc.)
- **AI-Frameworks** (Ollama, Fabric-AI)
- **Apps** (LM Studio, Obsidian) als macOS Casks
- **Git-Repositories** (z.B. Personal AI Infrastructure)

## 🚀 Schnellstart

```bash
# Alle Gruppen installieren (Standard)
./bootstrap.sh

# Spezifisches Profil verwenden
./bootstrap.sh -p yp

# Nur bestimmte Gruppen installieren
./bootstrap.sh -g base,ollama,fabric
```

## 📦 Verfügbare Profile

### `yp` - Your Personal AI Stack (Standard)

Vollständiger lokaler AI-Stack mit allen Tools:

- Base Tools (git, curl, jq, yq, uv)
- Ollama (lokale LLMs)
- Fabric-AI (Prompt-Framework)
- Personal AI Infrastructure
- Obsidian (Second Brain)

### `dp` - Developer Pro

Vollständiger Dev-Stack mit AI, Docker, Python, Node.js:

- Base Tools
- Ollama + Fabric + PAI
- Docker Desktop & CLI
- VS Code + Cursor
- Python Development Tools
- Node.js & npm/yarn/pnpm
- Produktivitäts-Tools

### `jp` - Just Prompts / Journaling

Leichtgewichtiger Stack für Schreiben und Notizen:

## 🎯 Verfügbare Gruppen

| Gruppe       | Beschreibung               | Pakete                                 |
| ------------ | -------------------------- | -------------------------------------- |
| `base`       | Basis-Tools                | git, curl, jq, yq, uv, fzf, dos2unix   |
| `ollama`     | Ollama Runtime             | ollama                                 |
| `lmstudio`   | LM Studio GUI              | lm-studio (macOS Cask)                 |
| `obsidian`   | Obsidian Notizen           | obsidian (macOS Cask)                  |
| `fabric`     | Fabric-AI CLI              | fabric-ai                              |
| `pai`        | Personal AI Infrastructure | bun + Git Repo                         |
| `docker`     | Docker Desktop & Tools     | docker, docker-compose, lazydocker     |
| `vscode`     | VS Code & Cursor           | visual-studio-code, cursor             |
| `python-dev` | Python Development         | python3.11/3.12, poetry, jupyter, ruff |
| `harbor`     | Harbor Container Registry  | harbor, docker-compose, helm           |
| `fluxcd`     | FluxCD GitOps              | flux-cli, kubectl, helm                |

### Optionen

````bash
Usage: ./bootstrap.sh [OPTIONEN]

Optionen:
  -f PATH    Pfad zur YAML-Config (Default: ./software-stack.yaml)
  -p NAME    Profilname (z.B. yp, dp, jp, mp)
  -g LISTE   Kommagetrennte Gruppen (z.B. base,ollama,pai,docker,vscode)
  -h         Hilfe anzeigen

Dev-Stack Shortcut-Flags (können kombiniert werden):
### Beispiele

```bash
# Standard: Profil 'yp' (falls vorhanden), sonst alle Gruppen
./bootstrap.sh

# Profil 'dp' (Developer Pro) verwenden
./bootstrap.sh -p dp

# Profil 'jp' verwenden
./bootstrap.sh -p jp

# Nur bestimmte Gruppen installieren
./bootstrap.sh -g base,ollama,obsidian

# Dev-Stack Shortcuts: Nur Basis + Docker
./bootstrap.sh -b -D

# Alle Dev-Tools installieren
./bootstrap.sh -A

# Kombiniert: Gruppen + Dev-Shortcuts
./bootstrap.sh -g obsidian,fabric -G -I

# Eigene YAML-Config verwenden
./bootstrap.sh -f ~/my-custom-stack.yaml -p yp
````

## ⚡ Dev-Stack Shortcuts

Das Script bietet praktische Shortcut-Flags für häufige Entwickler-Setups:

| Flag | Gruppe | Installiert                                               |
| ---- | ------ | --------------------------------------------------------- |
| `-b` | base   | git, curl, jq, yq, fzf, uv, dos2unix, fabric-ai           |
| `-G` | go-dev | go, go-task, goreleaser, golangci-lint, graphviz          |
| `-I` | iac    | terraform, kubernetes-cli, awscli, tflint, checkov        |
| `-D` | docker | docker, docker-compose, lazydocker                        |
| `-A` | alle   | Kombiniert alle obigen Gruppen (Base + Go + IaC + Docker) |

**Vorteile:**

- Schneller als lange Gruppenlisten tippen
- Kombinierbar mit Profilen und Gruppen
- Ideal für CI/CD oder schnelle Dev-Umgebungen

**Beispiele:**

````bash
# Basis-Setup für Go-Entwicklung
./bootstrap.sh -b -G

# Vollständige IaC-Umgebung
./bootstrap.sh -b -I -D

# Alles für Backend-Entwicklung
./bootstrap.sh -A -g python-dev,nodejs
```🛠️ Verwendung

### Optionen

```bash
Usage: ./bootstrap.sh [OPTIONEN]

Optionen:
  -f PATH    Pfad zur YAML-Config (Default: ./software-stack.yaml)
  -p NAME    Profilname (z.B. yp, jp, mp)
  -g LISTE   Kommagetrennte Gruppen (z.B. base,ollama,pai)
  -h         Hilfe anzeigen
````

### Beispiele

```bash
# Standard: Profil 'yp' (falls vorhanden), sonst alle Gruppen
./bootstrap.sh

# Profil 'jp' verwenden
./bootstrap.sh -p jp

# Nur bestimmte Gruppen installieren
./bootstrap.sh -g base,ollama,obsidian

# Eigene YAML-Config verwenden
./bootstrap.sh -f ~/my-custom-stack.yaml -p yp
```

## 🔧 Konfiguration erweitern

Du kannst `software-stack.yaml` anpassen:

### Neues Profil hinzufügen

```yaml
profiles:
  my_profile:
    description: "Mein Custom Stack"
    groups:
      - base
      - ollama
      - fabric
```

### Neue Gruppe definieren

```yaml
groups:
  my_group:
    description: "Meine Tools"
    brew:
      - neofetch
      - htop
    cask:
      - visual-studio-code
    git_repos:
      - repo: "https://github.com/user/repo.git"
        dest: "~/Projects/repo"
```

## 📝 Nach der Installation

### Ollama

```bash
# Ollama-Server starten
ollama serve

# Modell herunterladen und verwenden
ollama pull llama3
ollama run llama3
```

### Fabric-AI

```bash
# Fabric konfigurieren
fabric --setup

# Beispiel: YouTube-Transkript zusammenfassen
yt --transcript "VIDEO_URL" | fabric --pattern summarize
```

### Personal AI Infrastructure (PAI)

Das Repository wird nach `~/Projects/Personal_AI_Infrastructure` geklont.

## 🧪 Voraussetzungen

- **macOS** oder **Linux** (Ubuntu, Debian, etc.)
- **Bash** 4.0+
- **Internet-Verbindung** für Downloads

Das Script installiert automatisch:

- Homebrew (falls nicht vorhanden)
- yq (YAML-Parser, falls nicht vorhanden)

## 🔍 Fehlerbehandlung

Das Script verwendet `set -euo pipefail` für robuste Fehlerbehandlung:

- Stoppt bei Fehlern
- Zeigt klare Fehler-/Info-Meldungen
- Validiert, dass nur existierende Gruppen installiert werden

## 💡 Empfohlene Software-Ergänzungen

### Entwickler-Tools

- **Docker Desktop** (Container-Verwaltung)
- **VS Code / Cursor** (Code-Editor mit AI)
- **iTerm2** (besseres Terminal für macOS)
- **Postman** (API-Testing)

### AI/ML Tools

- **Cursor** (AI-basierter Code-Editor)
- **Continue.dev** (VS Code AI-Extension)
- **LocalAI** (Alternative zu Ollama)
- **Qdrant / ChromaDB** (Vector-Datenbanken)

### Produktivität

- **Raycast** (macOS Launcher mit AI)
- **Rectangle** (Fenster-Management)
- **Fork / SourceTree** (Git GUI)
- **Bruno** (API-Client, Postman-Alternative)

### Python/Data Science

- **Python** (via uv bereits dabei)
- **Jupyter Lab** (Notebooks)
- **PyCharm Community** (Python IDE)
- **Conda / Miniconda** (Environment-Management)

### Node.js Ecosystem

- **Node.js / nvm** (JavaScript Runtime)
- **pnpm / yarn** (Package Manager)

## 🤝 Beitragen

Vorschläge für neue Gruppen oder Profile? Erstelle einen Issue oder Pull Request!

## 📄 Lizenz

MIT License - Frei verwendbar für persönliche und kommerzielle Projekte.

---

## Hybride & lokale Cloud-Entwicklung

Das Setup installiert alle Tools für moderne Plattform-Entwicklung:

- Docker, Kubernetes, Terraform, AWS CLI, Helm
- Harbor (Container Registry) und FluxCD (GitOps) sind als eigene Gruppen verfügbar

**Installation:**

```sh
./bootstrap.sh -p dp -g harbor,fluxcd
```

Damit werden alle Tools für lokale, hybride und Cloud-Entwicklung installiert.

**Harbor:**

- Wird als Container (docker-compose) oder Helm-Chart installiert
- Images können lokal gebaut und in Harbor gepusht werden

**FluxCD:**

- CLI für GitOps-Deployments
- Playground/Dev/Stage/Prod werden automatisiert aus dem Git-Repo deployed

Weitere Infos zu den Gruppen findest du in `software-stack.yaml`.
