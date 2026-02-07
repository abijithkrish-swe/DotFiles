# 77) Golang
go_list() {
  local d v; [[ -d "$COMPONENTS/Go" ]] || return 0
  echo "Available Go versions:"
  for d in "$COMPONENTS/Go"/*; do [[ -x "$d/bin/go" ]] && echo "  ${d:t}"; done | sort -V
}

use_go() {
  local v="$1"
  component_set_status "Go" "$v"
  if [[ "$v" == "off" || -z "$v" ]]; then go_clear; return; fi
  local home="$COMPONENTS/Go/$v"
  [[ -d "$home/bin" ]] || { echo "Go $v not found"; return 1; }
  export GOROOT="$home"
  component_switch_path "_GO_ACTIVE_BIN" "$home/bin"
  echo "Switched to Go $v"; go version
}

go_clear() { component_switch_path "_GO_ACTIVE_BIN" ""; unset GOROOT; echo "Go removed"; }
alias go_versions='go_list'
alias go_use='use_go'
alias go_off='go_clear'

load_components_completion "use_go" "Go"
