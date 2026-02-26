#!/usr/bin/env bash
# switch-ai.sh — AI API Key 交互式切换工具 (YAML 版，Bash/Zsh 双兼容)
#
# 用法:
#   source ~/.local/lib/switch-ai.sh   ← 只加载函数，不执行
#   switch_ai                          ← 交互选择
#   switch_ai sssaicode                ← 直接切换
#   clear_ai_env                       ← 清除变量
#   show_ai_env                        ← 查看当前变量
#
# 依赖:
#   - yq: 支持 mikefarah/yq (Go) 或 pip yq (Python) 两种
#   - fzf / gum / skim 任选一个用于交互选择

CONFIG_FILE="$HOME/.config/ai-keys/profiles.yaml"

# ---- 检测 yq 版本（Go 版 vs pip 版语法不同）----
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

# ---- 从 YAML 提取所有 profile 名称 ----
_list_profiles() {
  local yq_type=$(_detect_yq)
  if [ "$yq_type" = "go" ]; then
    yq 'keys | .[]' "$CONFIG_FILE" 2>/dev/null
  elif [ "$yq_type" = "pip" ]; then
    yq -r 'keys[]' "$CONFIG_FILE" 2>/dev/null
  else
    echo "❌ yq not found. Install: brew install yq (Go) or pip install yq (Python)"
    return 1
  fi
}

# ---- 从 YAML 动态提取所有变量名（去重）----
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

# ---- 加载指定 profile 的环境变量 ----
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

# ---- 兼容 Bash/Zsh 的间接变量引用 ----
_get_var() {
  if [ -n "$ZSH_VERSION" ]; then
    echo "${(P)1}"
  else
    echo "${!1}"
  fi
}

# ---- 清除所有 AI 相关环境变量 ----
clear_ai_env() {
  local var
  local vars
  vars=($(_load_all_vars))
  for var in "${vars[@]}"; do
    unset "$var"
  done
  echo "🧹 Cleared ${#vars[@]} variables: ${vars[*]}"
}

# ---- 显示当前生效的变量（Key 自动掩码）----
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
      if [[ "$var" == *"KEY"* ]]; then
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

# ---- 主切换函数（交互 + 传参两用）----
switch_ai() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config not found: $CONFIG_FILE"
    return 1
  fi

  # 如果传了参数，直接走非交互模式
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
        clear_ai_env
        _load_profile "$1"
        local _any_key
        _any_key="$(_get_var ANTHROPIC_API_KEY)$(_get_var OPENAI_API_KEY)$(_get_var OPENROUTER_API_KEY)"
        if [ -n "$_any_key" ]; then
          echo "✅ Switched to: $1"
          show_ai_env
        else
          echo "❌ Profile '$1' not found in $CONFIG_FILE"
          return 1
        fi
        return 0
        ;;
    esac
  fi

  # 无参数 → 交互选择
  local choices
  choices=$(_list_profiles)
  if [ $? -ne 0 ]; then
    return 1
  fi

  choices=$(printf "%s\n%s\n%s" "$choices" "🧹 clear" "📋 show")

  local selection
  selection=$(echo "$choices" | fzf --prompt="Select AI Profile (or action): " --height=40%)

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

# ---- 只在直接执行时才自动运行，source 时只加载函数 ----
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] 2>/dev/null; then
  switch_ai "$@"
fi
