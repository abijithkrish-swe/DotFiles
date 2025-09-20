# ---------------------------------------------------------------------
# 72) Redis helpers — safe list, switch, cli, start/stop
# Layout expected:
#   $COMPONENTS/Redis/<version>/src/{redis-server,redis-cli}
#   (or .../bin/{redis-server,redis-cli})
# Only versions with real binaries are considered valid.
# ---------------------------------------------------------------------

: "${COMPONENTS:="$HOME/Components"}"
: "${DEFAULT_REDIS:="7.4.5"}"

typeset -g _REDIS_ACTIVE_BINDIR=""

# Internal: echo the bin dir for a version if valid
_redis_bindir_for() {
  local v="$1"
  local root="$COMPONENTS/Redis/$v"
  local d
  for d in "$root/src" "$root/bin"; do
    if [[ -x "$d/redis-server" && -x "$d/redis-cli" ]]; then
      print -r -- "$d"
      return 0
    fi
  done
  return 1
}

# List ONLY valid versions
redis_versions() {
  local d v
  [[ -d "$COMPONENTS/Redis" ]] || { echo "No Redis components at $COMPONENTS/Redis"; return 0; }
  for d in "$COMPONENTS/Redis"/*; do
    [[ -d "$d" ]] || continue
    v="${d:t}"
    _redis_bindir_for "$v" >/dev/null && echo "$v"
  done | sort -V
}

# Remove previously added redis bin dir from PATH
redis_clear_path() {
  [[ -n "$_REDIS_ACTIVE_BINDIR" ]] || return 0
  path=(${^path:#$_REDIS_ACTIVE_BINDIR})
  _REDIS_ACTIVE_BINDIR=""
}

# Switch PATH to the given redis version
use_redis() {
  local v="${1:-$DEFAULT_REDIS}" bindir
  if [[ -z "$v" ]]; then
    echo "Usage: use_redis <version>   (tip: redis_versions to list)"
    return 1
  fi
  if ! bindir="$(_redis_bindir_for "$v")"; then
    echo "❌ Redis $v not found or invalid (expected src/bin with redis-server & redis-cli)."
    redis_versions
    return 1
  fi

  redis_clear_path
  path+=("$bindir")
  _REDIS_ACTIVE_BINDIR="$bindir"

  echo "➡️ Using Redis $v ($bindir)"
  command -v redis-cli >/dev/null && redis-cli --version
}

# Start redis-server (with optional redis.conf if present)
rstart() {
  local v="${1:-$DEFAULT_REDIS}" bin
  if ! bin="$(_redis_bindir_for "$v")/redis-server" 2>/dev/null; then
    echo "Redis $v not found"; return 1
  fi
  if [[ -f "$COMPONENTS/Redis/$v/redis.conf" ]]; then
    "$bin" "$COMPONENTS/Redis/$v/redis.conf" &
  else
    "$bin" &
  fi
  echo "Started Redis $v"
}

# Stop redis-server
rstop() {
  pkill -f redis-server || echo "No redis-server found"
}

# Run redis-cli (defaults to current version)
rcli() {
  local v arg
  if [[ -z "$1" || "$1" == -* ]]; then
    v="$DEFAULT_REDIS"
    shift || true
  else
    v="$1"; shift
  fi
  local bin
  if ! bin="$(_redis_bindir_for "$v")/redis-cli" 2>/dev/null; then
    echo "Redis $v not found"; return 1
  fi
  "$bin" "$@"
}

# Convenience: show which redis is active
redis_current() {
  if command -v redis-server >/dev/null 2>&1; then
    echo "redis-server -> $(command -v redis-server)"
  else
    echo "redis-server not on PATH"
  fi
  if command -v redis-cli >/dev/null 2>&1; then
    echo "redis-cli    -> $(command -v redis-cli)"
  else
    echo "redis-cli not on PATH"
  fi
}

# Auto-load the default if valid
if _redis_bindir_for "$DEFAULT_REDIS" >/dev/null; then
  use_redis "$DEFAULT_REDIS" >/dev/null
fi

# ---------------------------------------------------------------------
# 73) Ant helpers
# ---------------------------------------------------------------------