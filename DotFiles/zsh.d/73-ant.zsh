# 73) Ant
# Versions come from the components manifest.

ant_list() { components_list ant Ant; }

use_ant() {
  if [[ "$1" == "off" ]]; then ant_clear; return; fi
  components_activate ant Ant _ANT_ACTIVE_BIN "$1" || return 1
  echo "Switched to Ant $CM_V"; ant -version
}

ant_clear() {
  components_deactivate ant Ant _ANT_ACTIVE_BIN
  echo "Ant removed"
}

alias ant_versions='ant_list'
alias ant_use='use_ant'  # Legacy/Inverse alias
alias ant_off='ant_clear'

load_components_completion "use_ant" "ant"
