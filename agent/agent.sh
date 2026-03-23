#!/usr/bin/env bash
# LLM Agent: analyzes project context and recommends dev tool groups
# Usage: ./agent.sh [--install] [--dir /path/to/project]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
STACK="$ROOT/software-stack.yaml"

# shellcheck source=../telemetry/metrics.sh
source "$ROOT/telemetry/metrics.sh" 2>/dev/null || true

AUTO_INSTALL=0
PROJECT_DIR="$(pwd)"

for arg in "$@"; do
  case "$arg" in
    --install) AUTO_INSTALL=1 ;;
    --dir=*)   PROJECT_DIR="${arg#--dir=}" ;;
  esac
done

# --- Gather context ---
gather_context() {
  local ctx="OS: $(uname -s) $(uname -m)\n"
  ctx+="Dir: ${PROJECT_DIR}\n"
  ctx+="Files: $(ls -1 "$PROJECT_DIR" 2>/dev/null | head -20 | tr '\n' ' ')\n"

  [[ -f "$PROJECT_DIR/go.mod" ]]                                     && ctx+="has:go.mod\n"
  [[ -f "$PROJECT_DIR/package.json" ]]                               && ctx+="has:package.json\n"
  [[ -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/setup.py" || -f "$PROJECT_DIR/requirements.txt" ]] \
                                                                     && ctx+="has:python\n"
  [[ -f "$PROJECT_DIR/Cargo.toml" ]]                                 && ctx+="has:Cargo.toml\n"
  find "$PROJECT_DIR" -name "*.tf" -maxdepth 3 -quit 2>/dev/null    && ctx+="has:terraform\n"
  [[ -f "$PROJECT_DIR/docker-compose.yml" || -f "$PROJECT_DIR/Dockerfile" ]] \
                                                                     && ctx+="has:docker\n"
  [[ -f "$PROJECT_DIR/flake.nix" ]]                                  && ctx+="has:nix\n"

  printf "%b" "$ctx"
}

# --- Heuristic fallback ---
heuristic_recommend() {
  local context="$1"
  local groups=("base")

  echo "$context" | grep -q "has:go.mod"      && groups+=("go-dev")
  echo "$context" | grep -q "has:package.json" && groups+=("nodejs")
  echo "$context" | grep -q "has:python"       && groups+=("python-dev")
  echo "$context" | grep -q "has:Cargo.toml"  && groups+=("rust-dev")
  echo "$context" | grep -q "has:terraform"   && groups+=("iac")
  echo "$context" | grep -q "has:docker"      && groups+=("docker")

  printf '%s\n' "${groups[@]}" | sort -u | tr '\n' ' '
}

# --- Ollama-based recommendation ---
ollama_recommend() {
  local context="$1"
  command -v ollama &>/dev/null || return 1
  local model
  model=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -E "llama|mistral|gemma" | head -1)
  [[ -z "$model" ]] && return 1

  local available_groups
  available_groups=$(yq e '.groups | keys | .[]' "$STACK" 2>/dev/null | tr '\n' ', ')

  local prompt
  prompt="Dev environment setup assistant. Context:
${context}

Available groups: ${available_groups}

Reply with ONLY a JSON array of group names. Example: [\"base\",\"go-dev\"]
Pick minimum necessary groups. No explanation, no markdown."

  local result
  result=$(ollama run "$model" "$prompt" 2>/dev/null | grep -o '\[.*\]' | head -1 || true)
  [[ -z "$result" ]] && return 1

  echo "$result" | jq -r '.[]' 2>/dev/null | tr '\n' ' '
}

# --- Main ---
main() {
  local context
  context=$(gather_context)

  echo "[agent] Analyzing: ${PROJECT_DIR}"
  echo ""

  local groups=""

  if groups=$(ollama_recommend "$context" 2>/dev/null) && [[ -n "$groups" ]]; then
    echo "[agent] LLM (Ollama) recommendation:"
  else
    groups=$(heuristic_recommend "$context")
    echo "[agent] Heuristic recommendation:"
  fi

  echo "  Groups: $groups"
  echo ""

  # Emit telemetry
  for g in $groups; do
    metric_agent_suggest "$g" 2>/dev/null || true
  done

  if [[ "$AUTO_INSTALL" -eq 1 ]]; then
    local group_csv
    group_csv=$(echo "$groups" | tr ' ' ',' | sed 's/,$//')
    echo "[agent] Installing: $group_csv"
    "$ROOT/bootstrap.sh" -g "$group_csv"
  else
    echo "To install: dev install -g $(echo "$groups" | tr ' ' ',')"
    echo "Auto-mode:  dev agent --install"
  fi
}

main
