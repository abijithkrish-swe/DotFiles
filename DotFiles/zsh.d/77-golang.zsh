# 77) Golang
# Versions come from the components manifest.
go_list() { components_list go Go; }

use_go() {
  if [[ "$1" == "off" ]]; then go_clear; return; fi
  components_activate go Go _GO_ACTIVE_BIN "$1" || return 1   # sets GOROOT
  echo "Switched to Go $CM_V"; go version
}

go_clear() { components_deactivate go Go _GO_ACTIVE_BIN; echo "Go removed"; }
alias go_versions='go_list'
alias go_use='use_go'
alias go_off='go_clear'

load_components_completion "use_go" "go"
