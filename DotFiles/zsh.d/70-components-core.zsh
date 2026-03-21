# 70) components core & toolup

# Base folder for all portable tools
export COMPONENTS="$HOME/Components"

# --- CORE PATH HELPER ---

# Helper to remove an old path (stored in a var name) and add a new one
component_switch_path() {
  local var_name="$1"      # e.g. "JAVA_ACTIVE_BIN"
  local new_path="$2"
  
  # 1. Read the old path from the variable name provided
  local old_path="${(P)var_name}"
  
  # 2. Remove old path from PATH if it exists
  if [[ -n "$old_path" ]]; then
    path=(${path:#$old_path})
  fi
  
  # 3. Add new path
  if [[ -n "$new_path" ]]; then
    # Append to PATH (keep system paths first)
    path=($path "$new_path")
    # 4. Update the state variable
    eval "$var_name='$new_path'"
  else
    # clear state if no new path
    unset "$var_name"
  fi
}

# --- STATUS & TRACKING ---

# Associative array to track what is active
typeset -gA COMPONENTS_STATUS

# Usage: component_set_status "JDK" "17"
component_set_status() {
  local name="$1"
  local ver="$2"
  if [[ -z "$ver" || "$ver" == "off" ]]; then
    unset "COMPONENTS_STATUS[$name]"
  else
    COMPONENTS_STATUS[$name]="$ver"
  fi
}

# Usage: components_status
components_status() {
  print -P "%BActive Components:%b"
  if (( ${#COMPONENTS_STATUS} == 0 )); then
    echo "  (none)"
    return
  fi
  for k in "${(@k)COMPONENTS_STATUS}"; do
    echo "  $k: ${COMPONENTS_STATUS[$k]}"
  done
}
alias status_components='components_status'

# Usage: components_prompt_info
# Can be used in your PROMPT or Starship config
components_prompt_info() {
  local parts=()
  for k in "${(@k)COMPONENTS_STATUS}"; do
    parts+=("$k:${COMPONENTS_STATUS[$k]}")
  done
  echo "${parts[*]}"
}


# --- GENERIC COMPLETION ---

# _components_comp <COMPONENT_DIR_NAME>
# Usage in other files: compdef '_components_comp JDK' use_jdk
_components_comp() {
  local context state line
  local comp_dir="$COMPONENTS/$1"
  
  # only auto-complete if directory exists
  if [[ -d "$comp_dir" ]]; then
      local -a subdirs
      # glob only directories, get tail name
      subdirs=(${comp_dir}/*(/N:t))
      _arguments "1:version:($subdirs off)"
  fi
}

load_components_completion() {
  local func_name="$1"
  local component_dir="$2"
  compdef "_components_comp $component_dir" "$func_name"
}

# --- TOOLUP ---

# Reset PATH to baseline (used by toolup)
_path_base() {
  if [ -d "/opt/homebrew/bin" ]; then
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
  fi
  export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
  
  if [ -d "/opt/homebrew/opt/mysql-client/bin" ]; then
    export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"
  fi
}

toolup() {
  local cfg=".toolsrc"
  [[ ! -f "$cfg" ]] && { echo "No $cfg in $(pwd)"; return 1; }
  _path_base
  COMPONENTS_STATUS=() # Reset status
  
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    key="${line%%=*}"; val="${line#*=}"
    case "$key" in
      JDK) use_jdk "$val" ;;
      REDIS) redis_use "$val" ;;
      ANT) [[ -n "$val" ]] && ant_use "$val" ;;
      MAVEN) [[ -n "$val" ]] && use_maven "$val" ;;
      GRADLE) [[ -n "$val" ]] && use_gradle "$val" ;;
      PROTOBUF) [[ -n "$val" ]] && protobuf_use "$val" ;;
      NODE) [[ -n "$val" ]] && node_use "$val" ;;
      GO) [[ -n "$val" ]] && go_use "$val" ;;
      PYTHON) [[ -n "$val" ]] && python_use "$val" ;;
      MYSQL_DEFAULT_VER) mysql_set_default "$val" ;;
      MYSQL_START_VER) mysql_start "$val" ;;
      MYSQL_STOP_VER) mysql_stop "$val" ;;
      PATH_PREPEND) export PATH="$val:$PATH" ;;
      EXPORT) eval "export ${val}" ;;
      *) echo "Unknown directive in .toolsrc: $key" ;;
    esac
  done < "$cfg"
  echo "Activated from $cfg"
  components_status
}

# mkbin helper
mkbin() {
  mkdir -p .bin
  export PATH="$PWD/.bin:$PATH"
  echo "Using .bin at $PWD/.bin"
}
