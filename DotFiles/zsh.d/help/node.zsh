# --- Node help module (optimized) -------------------------------------------
# Place in: ~/.zsh.d/help/node.zsh

_devhelp_node() {
  cat <<'EOF2'
Node — Command Reference
========================

node_list
  Approved Node versions (from the components manifest), with flags.
  Example:
    node_list
    #   20.19.5 (default)
    #   22.21.1

use_node [version]|off
  Switch to an approved Node version: exact or unique prefix (22 → 22.21.1).
  No version = manifest default. Swaps the previous Node bin out of PATH.
  Example:
    use_node 22
    use_node off

node_clear
  Remove the component Node from PATH.

aliases
  node_versions -> node_list
  node_use      -> use_node
  node_off      -> node_clear

Notes:
  • npm and npx come with Node — available automatically when Node is enabled.
  • New version? Add it to the manifest first — see 'devhelp components'.

EOF2
}

_devhelp_register "node" _devhelp_node
