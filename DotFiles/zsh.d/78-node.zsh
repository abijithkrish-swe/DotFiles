# 78) Node / npm (portable, toggle optional)
# Node tarballs live under: ~/Components/Node/<ver>

# List Node versions
node_versions() { ls -1 "$COMPONENTS/Node" 2>/dev/null; }

# Resolve a Node home with bin/ under ~/Components/Node/<ver>
_node_home() {
  local root="$COMPONENTS/Node/$1"
  if [ -d "$root/bin" ]; then
    echo "$root"; return 0
  fi
  return 1
}

# use_node <ver> — set NODE_HOME, append PATH, confirm node & npm
use_node() {
  local v="${1:?version}"
  local home; home="$(_node_home "$v")" || { echo "Node $v not found under $COMPONENTS/Node"; return 1; }
  export NODE_HOME="$home"
  export PATH="$PATH:$NODE_HOME/bin"   # append (safer)
  echo "Using Node $v from $NODE_HOME"
  node -v 2>/dev/null || echo "node not found in $NODE_HOME/bin"
  npm -v  2>/dev/null || echo "npm not found in $NODE_HOME/bin"
}

# Optional: set a per-user npm prefix (avoids sudo for globals)
# npm_prefix_user() {
#   local prefix="$HOME/.npm-global"
#   npm config set prefix "$prefix"
#   export PATH="$PATH:$prefix/bin"
#   echo "npm prefix set to $prefix (PATH updated)"
# }

# ---------------------------------------------------------------------
# 79) defaults
# ---------------------------------------------------------------------