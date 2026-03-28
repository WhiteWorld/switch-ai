#!/usr/bin/env bash
# switch-ai.sh — Interactive AI API Key switcher (YAML-based, Bash/Zsh compatible)
#
# Usage:
#   source ~/.local/lib/switch-ai.sh   ← load functions only, no execution
#   switch_ai                          ← interactive selection
#   switch_ai sssaicode                ← switch directly to a profile
#   clear_ai_env                       ← clear environment variables
#   show_ai_env                        ← show current variables
#
# Dependencies:
#   - yq: supports mikefarah/yq (Go) or pip yq (Python)
#   - fzf / gum / skim (any one) for interactive selection

CONFIG_FILE="$HOME/.config/ai-keys/profiles.yaml"

# ---- Detect yq version (Go vs pip have different syntax) ----
_detect_yq() {
  if command -v yq >/dev/null 2>&1; then
    if yq --version 2>&1 | grep -qi "mikefarah\|https://github.com/mikefarah"; then
      echo "go"
    else
      echo "pip"
    fi
  else
    echo "none"
  fi
}

# ---- Extract all profile names from YAML ----
_list_profiles() {
  local yq_type=$(_detect_yq)
  if [ "$yq_type" = "go" ]; then
    yq 'keys | .[]' "$CONFIG_FILE" 2>/dev/null | grep -v '^[[:space:]]*$'
  elif [ "$yq_type" = "pip" ]; then
    yq -r 'keys[]' "$CONFIG_FILE" 2>/dev/null | grep -v '^[[:space:]]*$'
  else
    echo "❌ yq not found. Install: brew install yq (Go) or pip install yq (Python)"
    return 1
  fi
}

# ---- Dynamically extract all variable names from YAML (deduplicated) ----
_load_all_vars() {
  local yq_type=$(_detect_yq)
  if [ "$yq_type" = "go" ]; then
    yq 'to_entries | .[].value | keys | .[]' "$CONFIG_FILE" 2>/dev/null | sort -u
  elif [ "$yq_type" = "pip" ]; then
    yq -r 'to_entries[].value | keys[]' "$CONFIG_FILE" 2>/dev/null | sort -u
  else
    echo ""
  fi
}

# ---- Load environment variables for the specified profile ----
_load_profile() {
  local profile="$1"
  local yq_type=$(_detect_yq)
  local lines

  if [ "$yq_type" = "go" ]; then
    lines=$(yq ".[\"$profile\"] | to_entries | .[] | .key + \"=\" + .value" "$CONFIG_FILE" 2>/dev/null)
  elif [ "$yq_type" = "pip" ]; then
    lines=$(yq -r ".[\"$profile\"] | to_entries[] | .key + \"=\" + .value" "$CONFIG_FILE" 2>/dev/null)
  else
    return 1
  fi

  while IFS= read -r line; do
    if [[ "$line" == *=* ]]; then
      local key="${line%%=*}"
      local value="${line#*=}"
      export "$key=$value"
    fi
  done <<< "$lines"
}

# ---- Bash/Zsh compatible indirect variable reference ----
_get_var() {
  if [ -n "$ZSH_VERSION" ]; then
    echo "${(P)1}"
  else
    echo "${!1}"
  fi
}

# ---- Clear all AI-related environment variables ----
clear_ai_env() {
  local var
  local vars
  vars=($(_load_all_vars))
  for var in "${vars[@]}"; do
    unset "$var"
  done
  echo "🧹 Cleared ${#vars[@]} variables: ${vars[*]}"
}

# ---- Show current active variables (keys automatically masked) ----
show_ai_env() {
  echo "📋 Current AI environment variables:"
  echo "---"
  local has_any=false
  local var val
  local vars
  vars=($(_load_all_vars))
  for var in "${vars[@]}"; do
    val=$(_get_var "$var")
    if [ -n "$val" ]; then
      if [[ "$var" == *"KEY"* || "$var" == *"TOKEN"* || "$var" == *"SECRET"* || "$var" == *"PASSWORD"* ]]; then
        echo "  $var=${val:0:8}...********"
      else
        echo "  $var=$val"
      fi
      has_any=true
    fi
  done
  if [ "$has_any" = false ]; then
    echo "  (none set)"
  fi
  echo "---"
}

# ---- Main switch function (interactive and direct-argument modes) ----
switch_ai() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config not found: $CONFIG_FILE"
    return 1
  fi

  # Check yq dependency
  if ! command -v yq >/dev/null 2>&1; then
    echo "❌ yq not found. Install: brew install yq  (or: pip install yq)"
    return 1
  fi

  # If an argument is provided, use non-interactive mode
  if [ -n "$1" ]; then
    case "$1" in
      "clear"|"--clear")
        clear_ai_env
        return 0
        ;;
      "show"|"--show")
        show_ai_env
        return 0
        ;;
      *)
        if ! _list_profiles | grep -qx "$1"; then
          echo "❌ Profile '$1' not found in $CONFIG_FILE"
          return 1
        fi
        clear_ai_env
        _load_profile "$1"
        echo "✅ Switched to: $1"
        show_ai_env
        return 0
        ;;
    esac
  fi

  # No argument → interactive selection, check for fzf
  if ! command -v fzf >/dev/null 2>&1; then
    echo "❌ fzf not found. Install: brew install fzf"
    return 1
  fi

  local choices
  choices=$(_list_profiles)
  if [ $? -ne 0 ]; then
    return 1
  fi

  choices=$(printf "%s\n%s\n%s" "$choices" "🧹 clear" "📋 show")

  local selection
  selection=$(echo "$choices" | fzf --prompt="Select AI Profile (or action): " --height=~40%)

  [ -z "$selection" ] && echo "Cancelled." && return 1

  case "$selection" in
    "🧹 clear")
      clear_ai_env
      ;;
    "📋 show")
      show_ai_env
      ;;
    *)
      clear_ai_env
      _load_profile "$selection"
      echo "✅ Switched to: $selection"
      show_ai_env
      ;;
  esac
}

# ---- Run automatically only when executed directly; source only loads functions ----
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] 2>/dev/null; then
  switch_ai "$@"
fi
