# 74) Maven
# Versions come from the components manifest.

maven_list() { components_list maven Maven; }

use_maven() {
  if [[ "$1" == "off" ]]; then maven_clear; return; fi
  components_activate maven Maven _MAVEN_ACTIVE_BIN "$1" || return 1   # sets M2_HOME, MAVEN_HOME
  echo "Switched to Maven $CM_V"; mvn -version
}

maven_clear() {
  components_deactivate maven Maven _MAVEN_ACTIVE_BIN
  echo "Maven removed"
}

alias maven_versions='maven_list'
alias maven_use='use_maven'
alias maven_off='maven_clear'

load_components_completion "use_maven" "maven"
