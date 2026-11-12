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

pnpm (its own component: the standalone binary, no Node needed to run it)
  use_pnpm [ver]   /  pnpm_list  /  pnpm_clear     (aliases pnpm_use, pnpm_off)
  Install a version: download the macOS arm64 asset from github.com/pnpm/pnpm/releases,
    mkdir -p ~/Components/Pnpm/<ver>/bin, move it there as `pnpm`, chmod +x,
    xattr -d com.apple.quarantine it, then add "pnpm <ver> default" to the manifest.
  Projects still need Node for scripts: use_node 22 && use_pnpm.
  Agents: run with tools {"node": "22", "pnpm": ""}. In the sandbox pnpm's store,
    cache and state live in ~/.cache/toolshelf/pnpm, and it never switches itself
    to the version in a project's "packageManager" field. (pnpm ≥ 11 reads
    pnpm_config_* rather than npm_config_*; toolshelf sets both. pnpm 12 locks in
    /tmp/pnpm-store-operation-locks-<uid>, the one /tmp folder the sandbox allows.)
  Docker mode has no pnpm image: use node's, with corepack inside the container:
    dockrun --net node=22 'COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack pnpm install'

EOF2
}

_devhelp_register "node" _devhelp_node
