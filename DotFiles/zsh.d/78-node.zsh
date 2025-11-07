# 78) Node / npm (portable, toggle optional)

# --- Node (Components-based, off-by-default) --------------------------------
# Layout (you manage tarballs manually):
#   ~/Components/Node/20.11.1/bin/{node,npm,npx}
#   ~/Components/Node/18.20.5/bin/{node,npm,npx}
#
# Philosophy:
# - Nothing is added to PATH unless you explicitly enable or a shim auto-enables.
# - npm & npx are provided by Node; no separate install.
# - We APPEND to PATH (your preference).
#
# Optional environment you can set in .zshrc:
#   export COMPONENTS="$HOME/Components"
#   export NODE_DEFAULT_VERSION="20.11.1"   # used by lazy shims & node_on (if no arg)

# --- constants / helpers -----------------------------------------------------

# --- PATH management helpers (safe Zsh array versions) -----------------------

# Append a directory to PATH safely using the Zsh 'path' array.
# Removes duplicates before appending to keep order stable.
__append_path() {
  local d="$1"
  [[ -d "$d" ]] || return 1
  # Remove if already present, then append at the end.
  path=(${path:#$d})
  path+=("$d")
}

# Remove ALL ~/Components/Node/*/bin entries from PATH.
# This filters any Node versions previously added by node_on/node_use.
__node_path_strip_all() {
  # Filter out any path element matching */Node/*/bin
  path=(${path:#*/Node/*/bin})
}

# De-duplicate PATH entries while preserving the first occurrence order.
# (Usually unnecessary now, since __append_path and __node_path_strip_all keep PATH clean.)
__dedupe_path() {
  # (u) = unique; preserves order of first appearance
  path=(${(u)path})
}


# Recompute __node_root from $COMPONENTS (in case it changed)
__node_refresh_root() {
  local comp="${COMPONENTS:-$HOME/Components}"
  comp="${comp%/}"
  if [[ "${comp:t}" == "Node" && -d "$comp" ]]; then
    __node_root="$comp"
  elif [[ -d "$comp/Node" ]]; then
    __node_root="$comp/Node"
  else
    __node_root="$HOME/Components/Node"
  fi
}

# Initialize once at load
__node_refresh_root

# compute absolute bin dir for a version
__node_bin_for() {
  local v="$1"
  local base="$__node_root/$v"
  [[ -x "$base/bin/node" ]] && printf '%s/bin\n' "$base" || return 1
}

# normalize version strings: allow "v20.11.1" or "20.11.1"
__node_normver() {
  local v="${1:-}"
  [[ -n "$v" ]] || return 1
  v="${v#v}"
  printf '%s\n' "$v"
}

# npm global prefix to XDG location (no sudo globally)
export NPM_CONFIG_PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/npm"
__append_path "${NPM_CONFIG_PREFIX}/bin"

# track last explicitly enabled version (for info)
typeset -g __NODE_ACTIVE_VERSION=""
typeset -g __NODE_ENABLED_FLAG="false"

# --- public commands ---------------------------------------------------------

# list available versions in Components (only valid installs)
node_versions() {
  __node_refresh_root
  local d
  for d in "$__node_root"/*; do
    [[ -x "$d/bin/node" ]] && basename "$d"
  done 2>/dev/null | sort -V
}

# show where the current node comes from
node_where() {
  __node_refresh_root
  if command -v node >/dev/null 2>&1; then
    command -v node
  else
    echo "node: not in PATH"
  fi
}

# current node -v (or 'none')
node_current() {
  __node_refresh_root
  if command -v node >/dev/null 2>&1; then node -v; else echo "none"; fi
}

# explicitly switch to a version (appends bin, strips previous Component bins)
# If no arg: use version from CWD, else NODE_DEFAULT_VERSION (if set).
node_use() {
  __node_refresh_root
  local want

  if [[ -n "$1" ]]; then
    want="$(__node_normver "$1")"
  else
    local vf
    if vf="$(__node_find_version_here)"; then
      want="$(__node_read_version_file "$vf")"
    fi
    [[ -z "$want" ]] && want="$(__node_normver "${NODE_DEFAULT_VERSION:-}")"
  fi

  [[ -n "$want" ]] || { echo "No version in CWD and NODE_DEFAULT_VERSION unset. Usage: node_use <version>"; return 1; }

  local bindir
  bindir="$(__node_bin_for "$want")" || { echo "Node $want not found under $__node_root"; return 1; }

  __node_path_strip_all
  __append_path "$bindir"

  if command -v node >/dev/null 2>&1; then
    __NODE_ACTIVE_VERSION="$want"
    __NODE_ENABLED_FLAG="true"
    echo "Node → $(node -v)  [from $bindir]"
  else
    echo "Failed to enable Node $want"
    return 1
  fi
}

# turn node support ON; optional arg; else use CWD pin, else NODE_DEFAULT_VERSION
node_on() {
  __node_refresh_root
  local v

  if [[ -n "$1" ]]; then
    v="$(__node_normver "$1")"
  else
    local vf
    if vf="$(__node_find_version_here)"; then
      v="$(__node_read_version_file "$vf")"
    fi
    [[ -z "$v" ]] && v="$(__node_normver "${NODE_DEFAULT_VERSION:-}")"
  fi

  [[ -n "$v" ]] || { echo "No version in CWD and NODE_DEFAULT_VERSION unset. Usage: node_on <version>"; return 1; }
  node_use "$v"
}

# Turn Node OFF completely (strip all Node bins from PATH)
node_off() {
  __node_refresh_root
  __node_path_strip_all
  #__dedupe_path
  __NODE_ACTIVE_VERSION=""
  __NODE_ENABLED_FLAG="false"
  echo "Node support disabled (removed Components Node bins from PATH)."
}

# write per-project version file (.node-version in cwd). If no arg, use current node -v
node_set_project() {
  local v
  local norm
  if [[ -n "$1" ]]; then
    norm="$(__node_normver "$1")"
  else
    # if node is active, capture trimmed version; else require arg
    if command -v node >/dev/null 2>&1; then
      v="$(node -v)"
      norm="$(__node_normver "$v")"
    else
      echo "No active node. Usage: node_set_project <version>"; return 1
    fi
  fi
  printf '%s\n' "$norm" > .node-version
  echo "Pinned project Node to $norm  (wrote .node-version)"
}

# --- project version detection (current dir only) ----------------------------
# Checks ONLY the CWD for one of: .node-version, .nvmrc, .tool-versions
__node_find_version_here() {
  local f
  for f in .node-version .nvmrc .tool-versions; do
    [[ -f "./$f" ]] && { printf '%s\n' "./$f"; return 0; }
  done
  return 1
}

__node_read_version_file() {
  local file="$1"
  local v=""
  case "${file:t}" in
    .node-version|.nvmrc)
      v="$(grep -E '^[[:space:]]*[0-9v]' "$file" | head -1 | tr -d '[:space:]')"
      ;;
    .tool-versions)
      v="$(awk '$1=="nodejs"{print $2; exit}' "$file")"
      ;;
  esac
  [[ -n "$v" ]] && printf '%s\n' "${v#v}"
}

# --- lazy shims --------------------------------------------------------------
# If node/npm/npx are not found but a default is set, auto-enable then exec.
# If a system node exists (outside Components), we respect it and just exec.

__node_lazy_bootstrap() {
  # If already enabled via node_use/node_on, do nothing
  [[ "$__NODE_ENABLED_FLAG" == "true" ]] && return 0

  # If a non-Components node exists, do nothing (respect system install)
  if command -v node >/dev/null 2>&1; then
    local realbin
    realbin="$(command -v node)"
    [[ "$realbin" != "$__node_root/"*"/bin/node" ]] && return 0
  fi

  # Else try default
  local def
  def="$(__node_normver "${NODE_DEFAULT_VERSION:-}")"
  [[ -n "$def" ]] || return 0
  node_use "$def" >/dev/null 2>&1 || true
}

# --- node debug -------------------------------------------------------------
# Diagnose why a version isn't detected
node_diag() {
  local v="$1"
  local root="${COMPONENTS:-$HOME/Components}/Node"
  local base="$root/$v"
  echo "COMPONENTS=$root"
  echo "Checking: $base"
  ls -ld "$base" 2>/dev/null || echo "❌ $base missing"
  ls -l "$base/bin" 2>/dev/null || echo "ℹ️ No direct bin/ under $base"
  command -v node >/dev/null && echo "Current node: $(command -v node)" || echo "Current node: none"
  echo "Searching for */bin/node under $base (maxdepth 2):"
  find "$base" -maxdepth 2 -type f -name node -path "*/bin/node" -print 2>/dev/null
}

# Define function shims only if "node" is not an external command right now.
# This lets you keep a system node untouched, if present.
if ! command -v node >/dev/null 2>&1; then
  node() { __node_lazy_bootstrap; command node "$@"; }
fi
if ! command -v npm >/dev/null 2>&1; then
  npm()  { __node_lazy_bootstrap; command npm  "$@"; }
fi
if ! command -v npx >/dev/null 2>&1; then
  npx()  { __node_lazy_bootstrap; command npx  "$@"; }
fi

# --- notes -------------------------------------------------------------------
# • To install a version into Components:
#     cd "$HOME/Components/Node"
#     ver="v20.11.1"  # example; pick proper darwin-arm64/x64 build
#     curl -LO "https://nodejs.org/dist/$ver/node-$ver-darwin-arm64.tar.xz"
#     tar -xf "node-$ver-darwin-arm64.tar.xz"
#     mv "node-$ver-darwin-arm64" "20.11.1"
#
# • Typical workflow:
#     node_versions
#     node_on 20.11.1       # enable once per shell (or just run `node` if NODE_DEFAULT_VERSION set)
#     node_use 18.20.5       # switch when needed
#     node_off               # remove from PATH again
#
# • Per-project:
#     node_set_project 20.11.1   # writes .node-version
#     # Later you can read this and call node_use "$(cat .node-version)" on cd (autoswitch module).
#
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