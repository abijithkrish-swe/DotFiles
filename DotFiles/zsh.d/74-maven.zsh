# 74) Maven
# Layout: ~/Components/Maven/<ver>/bin/mvn

maven_list() {
  local d
  [[ -d "$COMPONENTS/Maven" ]] || return 0
  echo "Available Maven versions:"
  for d in "$COMPONENTS/Maven"/*; do
     [[ -x "$d/bin/mvn" ]] && echo "  ${d:t}"
  done | sort -V
}

use_maven() {
  local v="$1"
  component_set_status "Maven" "$v"
  
  if [[ "$v" == "off" || -z "$v" ]]; then
    maven_clear
    return
  fi
  local home="$COMPONENTS/Maven/$v"
  [[ -d "$home" ]] || { echo "Maven $v not found"; return 1; }
  
  export M2_HOME="$home"
  export MAVEN_HOME="$home"
  component_switch_path "_MAVEN_ACTIVE_BIN" "$home/bin"
  echo "Switched to Maven $v"; mvn -version
}

maven_clear() {
  component_switch_path "_MAVEN_ACTIVE_BIN" ""
  unset M2_HOME
  unset MAVEN_HOME
  component_set_status "Maven" "off"
  echo "Maven removed"
}

alias maven_versions='maven_list'
alias maven_use='use_maven'
alias maven_off='maven_clear'

load_components_completion "use_maven" "Maven"
