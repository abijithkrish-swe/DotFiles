# --- Node help module (optimized) -------------------------------------------
# Place in: ~/.zsh.d/help/node.zsh

_devhelp_node() {
  cat <<'EOF'
Node — Command Reference
========================

node_versions
  List all installed Node versions under ~/Components/Node.
  Example:
    node_versions
    # 18.20.5
    # 20.11.1

node_use <version>
  Switch to a specific Node version.
  Removes old Component Node bins and appends new version’s bin to PATH.
  Example:
    node_use 20.11.1

node_on [version]
  Enable Node support.
  • With argument → enables that version.
  • Without argument → enables NODE_DEFAULT_VERSION if defined.
  Example:
    node_on
    node_on 18.20.5

node_off
  Disable Node support and remove all Component Node paths from PATH.
  Example:
    node_off

node_current
  Show the currently active Node version (or "none" if disabled).
  Example:
    node_current

node_where
  Show the full path of the Node binary in use.
  Example:
    node_where

node_set_project [version]
  Pin project Node version by writing .node-version in current directory.
  • With argument → writes that version.
  • Without argument → writes currently active Node version.
  Example:
    node_set_project 20.11.1
    node_set_project

Notes:
  • npm and npx come with Node — available automatically when Node is enabled.
  • Use node_on or node_use before running npm/npx if Node is disabled.
EOF
}

_devhelp_register "node" _devhelp_node