# 73) Ant
# Layout: ~/Components/Ant/<ver>/bin/ant

ant_list() {
  local d
  [[ -d "$COMPONENTS/Ant" ]] || return 0
  echo "Available Ant versions:"
  for d in "$COMPONENTS/Ant"/*; do
     [[ -x "$d/bin/ant" ]] && echo "  ${d:t}"
  done | sort -V
}

use_ant() {
  local v="$1"
  component_set_status "Ant" "$v"
  
  if [[ "$v" == "off" || -z "$v" ]]; then
    ant_clear
    return
  fi
  local home="$COMPONENTS/Ant/$v"
  [[ -d "$home" ]] || { echo "Ant $v not found"; return 1; }
  
  export ANT_HOME="$home"
  component_switch_path "_ANT_ACTIVE_BIN" "$home/bin"
  echo "Switched to Ant $v"; ant -version
}

ant_clear() {
  component_switch_path "_ANT_ACTIVE_BIN" ""
  unset ANT_HOME
  echo "Ant removed"
}

alias ant_versions='ant_list'
alias ant_use='use_ant'  # Legacy/Inverse alias
alias ant_off='ant_clear'

load_components_completion "use_ant" "Ant"
