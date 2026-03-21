# 85) Gradle
# Layout: ~/Components/Gradle/<ver>/bin/gradle

gradle_list() {
  local d
  [[ -d "$COMPONENTS/Gradle" ]] || return 0
  echo "Available Gradle versions:"
  for d in "$COMPONENTS/Gradle"/*; do
     [[ -x "$d/bin/gradle" ]] && echo "  ${d:t}"
  done | sort -V
}

use_gradle() {
  local v="$1"
  component_set_status "Gradle" "$v"
  
  if [[ "$v" == "off" || -z "$v" ]]; then
    gradle_clear
    return
  fi
  local home="$COMPONENTS/Gradle/$v"
  [[ -d "$home" ]] || { echo "Gradle $v not found"; return 1; }
  
  export GRADLE_HOME="$home"
  component_switch_path "_GRADLE_ACTIVE_BIN" "$home/bin"
  echo "Switched to Gradle $v"; gradle --version
}

gradle_clear() {
  component_switch_path "_GRADLE_ACTIVE_BIN" ""
  unset GRADLE_HOME
  component_set_status "Gradle" "off"
  echo "Gradle removed"
}

alias gradle_versions='gradle_list'
alias gradle_use='use_gradle'
alias gradle_off='gradle_clear'

load_components_completion "use_gradle" "Gradle"
