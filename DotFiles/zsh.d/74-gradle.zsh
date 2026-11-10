# 74) Gradle
# Versions come from the components manifest.
# (Was 85-gradle.zsh; now loads before 79-defaults so it can be autoloaded.)

gradle_list() { components_list gradle Gradle; }

use_gradle() {
  if [[ "$1" == "off" ]]; then gradle_clear; return; fi
  components_activate gradle Gradle _GRADLE_ACTIVE_BIN "$1" || return 1   # sets GRADLE_HOME
  echo "Switched to Gradle $CM_V"; gradle --version
}

gradle_clear() {
  components_deactivate gradle Gradle _GRADLE_ACTIVE_BIN
  echo "Gradle removed"
}

alias gradle_versions='gradle_list'
alias gradle_use='use_gradle'
alias gradle_off='gradle_clear'

load_components_completion "use_gradle" "gradle"
