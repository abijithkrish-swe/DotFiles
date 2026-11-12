# 78) pnpm
# Versions come from the components manifest. It's the standalone pnpm binary
# (no Node needed to run it), in ~/Components/Pnpm/<version>/bin/pnpm. Its
# store and cache follow XDG here ($XDG_DATA_HOME/pnpm, $XDG_CACHE_HOME/pnpm).
pnpm_list() { components_list pnpm Pnpm; }

use_pnpm() {
  if [[ "$1" == "off" ]]; then pnpm_clear; return; fi
  components_activate pnpm Pnpm _PNPM_ACTIVE_BIN "$1" || return 1
  echo "Switched to pnpm $CM_V"; pnpm --version
}

pnpm_clear() { components_deactivate pnpm Pnpm _PNPM_ACTIVE_BIN; echo "pnpm removed"; }
alias pnpm_versions='pnpm_list'
alias pnpm_use='use_pnpm'
alias pnpm_off='pnpm_clear'

load_components_completion "use_pnpm" "pnpm"
