# --- Node help module -------------------------------------------------------
# Place in: ~/.zsh.d/help/node.zsh

_devhelp_node() {
  cat <<'EOF'
Node (Components-based)
=======================
Philosophy:
  • Node stays OFF by default (no PATH pollution).
  • npm & npx work automatically once Node is enabled.
  • Versions are stored under: ~/Components/Node/<version>/
  • You control activation explicitly or via .node-version per project.

Layout example:
  ~/Components/Node/20.11.1/bin/{node,npm,npx}
  ~/Components/Node/18.20.5/bin/{node,npm,npx}

Environment variables:
  COMPONENTS="$HOME/Components"
  NODE_DEFAULT_VERSION="20.11.1"   # optional default
  ENABLE_NODE_AUTOSWITCH=true      # optional (if using auto module)

-------------------------------------------------------------------------------
Commands
-------------------------------------------------------------------------------

node_versions
  List all installed Node versions under \$COMPONENTS/Node.

node_use <version>
  Switch to a specific version.
  • Removes old Component Node bins from PATH.
  • Appends new version's bin to PATH.
  Example:
    node_use 20.11.1

node_on [version]
  Enable Node support.
  • If version provided → use it.
  • Otherwise uses NODE_DEFAULT_VERSION.
  Example:
    node_on            # uses default if set
    node_on 18.20.5    # explicit version

node_off
  Disable Node support and remove all Component Node bins from PATH.
  Example:
    node_off

node_current
  Show currently active Node version (or "none" if disabled).

node_where
  Show the path of the node binary currently used.

node_set_project [version]
  Pin project Node version by writing .node-version in current directory.
  • If version omitted, uses current node -v (if active).
  Example:
    node_set_project 20.11.1
    node_set_project    # uses current active version

-------------------------------------------------------------------------------
Lazy bootstrapping (auto-enable)
-------------------------------------------------------------------------------
If Node is disabled and you run node/npm/npx:
  • If NODE_DEFAULT_VERSION is set → it auto-enables that version and executes.
  • If a system Node exists → shell respects that and does nothing.

Example:
  export NODE_DEFAULT_VERSION="20.11.1"
  node -v        # automatically enables and runs Node 20.11.1

-------------------------------------------------------------------------------
Manual install (macOS tarballs)
-------------------------------------------------------------------------------
cd ~/Components/Node
ver="v20.11.1"  # replace with version/arch
curl -LO "https://nodejs.org/dist/$ver/node-$ver-darwin-arm64.tar.xz"
tar -xf "node-$ver-darwin-arm64.tar.xz"
mv "node-$ver-darwin-arm64" "20.11.1"

-------------------------------------------------------------------------------
Typical workflow
-------------------------------------------------------------------------------
  node_versions                 # list available
  node_on 20.11.1               # enable default version
  npm -v / npx -v               # now available
  node_use 18.20.5              # switch
  node_off                      # disable again
  node_set_project 20.11.1      # pin project

-------------------------------------------------------------------------------
Optional companion (autoswitch)
-------------------------------------------------------------------------------
If you later add ~/.zsh.d/79-node-auto.zsh:
  • Reads .node-version / .nvmrc / .tool-versions when cd into a project.
  • Falls back to NODE_DEFAULT_VERSION.
  • Must set: export ENABLE_NODE_AUTOSWITCH=true

-------------------------------------------------------------------------------
Notes
-------------------------------------------------------------------------------
  • Node tarballs already include npm & npx.
  • Use 'corepack enable' to access yarn or pnpm if needed.
  • Global npm prefix → \$XDG_DATA_HOME/npm (no sudo required).
EOF
}

_devhelp_register "node" _devhelp_node