# 78) Node.js
node_list() {
  local d v; [[ -d "$COMPONENTS/Node" ]] || return 0
  echo "Available Node versions:"
  for d in "$COMPONENTS/Node"/*; do [[ -x "$d/bin/node" ]] && echo "  ${d:t}"; done | sort -V
}

use_node() {
  local v="$1"
  component_set_status "Node" "$v"
  if [[ "$v" == "off" || -z "$v" ]]; then node_clear; return; fi
  local home="$COMPONENTS/Node/$v"
  [[ -d "$home/bin" ]] || { echo "Node $v not found"; return 1; }
  component_switch_path "_NODE_ACTIVE_BIN" "$home/bin"
  echo "Switched to Node $v"; node --version
}

node_clear() { component_switch_path "_NODE_ACTIVE_BIN" ""; echo "Node removed"; }
alias node_versions='node_list'
alias node_use='use_node'
alias node_off='node_clear'

load_components_completion "use_node" "Node"
