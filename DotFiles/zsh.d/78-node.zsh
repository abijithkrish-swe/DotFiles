# 78) Node.js
# Versions come from the components manifest.
node_list() { components_list node Node; }

use_node() {
  if [[ "$1" == "off" ]]; then node_clear; return; fi
  components_activate node Node _NODE_ACTIVE_BIN "$1" || return 1
  echo "Switched to Node $CM_V"; node --version
}

node_clear() { components_deactivate node Node _NODE_ACTIVE_BIN; echo "Node removed"; }
alias node_versions='node_list'
alias node_use='use_node'
alias node_off='node_clear'

load_components_completion "use_node" "node"
