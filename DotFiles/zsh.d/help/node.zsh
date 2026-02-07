# --- Node help module (optimized) -------------------------------------------
# Place in: ~/.zsh.d/help/node.zsh

_devhelp_node() {
  cat <<'EOF'
Node — Command Reference
========================

node_list
  List all installed Node versions under ~/Components/Node.
  Example:
    node_list
    # 18.20.5
    # 20.11.1

use_node <version>|off
  Switch to a specific Node version.
  Removes old Component Node bins and appends new version’s bin to PATH.
  Example:
    use_node 20.11.1
    use_node off

node_clear
  Disable Node support and remove all Component Node paths from PATH.
  Example:
    node_clear

aliases
  node_versions -> node_list
  node_use      -> use_node
  node_off      -> node_clear

Notes:
  • npm and npx come with Node — available automatically when Node is enabled.

EOF
}

_devhelp_register "node" _devhelp_node