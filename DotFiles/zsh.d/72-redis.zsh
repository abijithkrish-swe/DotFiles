# ---------------------------------------------------------------------
# 72) Redis helpers — safe list, switch, cli, start/stop
# ---------------------------------------------------------------------

: "${COMPONENTS:="$HOME/Components"}"
: "${DEFAULT_REDIS:="7.4.5"}"

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

redis_list() {
  local d v
  [[ -d "$COMPONENTS/Redis" ]] || { echo "No Redis components at $COMPONENTS/Redis"; return 0; }
  echo "Available Redis versions:"
  for d in "$COMPONENTS/Redis"/*; do
     v="${d:t}"
     if _redis_bindir_for "$v" >/dev/null; then
        echo "  $v"
     fi
  done | sort -V
}

# use_redis <ver>
use_redis() {
  local v="$1"
  component_set_status "Redis" "$v"
  
  if [[ "$v" == "off" || -z "$v" ]]; then
    redis_clear
    return
  fi

  local bindir
  bindir="$(_redis_bindir_for "$v")" || { echo "Redis $v (or binaries) not found."; return 1; }

  # Use core helper
  component_switch_path "_REDIS_ACTIVE_BIN" "$bindir"

  echo "➡️ Using Redis $v ($bindir)"
  command -v redis-cli >/dev/null && redis-cli --version
}

redis_clear() {
  component_switch_path "_REDIS_ACTIVE_BIN" ""
  echo "Redis removed from PATH"
}

# Start redis-server (with optional redis.conf if present)
redis_start() {
  local v="${1:-$DEFAULT_REDIS}" bin
  
  # Ensure we have the bin in path or find it
  if ! bin="$(_redis_bindir_for "$v")/redis-server" 2>/dev/null; then
     # Try current PATH if no version arg
     if ! bin="$(command -v redis-server)"; then
        echo "Redis $v not found (and not in PATH)"; return 1
     fi
  fi
  
  echo "Starting $bin..."
  local conf="$COMPONENTS/Redis/$v/redis.conf"
  if [[ -f "$conf" ]]; then
    nohup "$bin" "$conf" >/tmp/redis_$v.log 2>&1 &
  else
    nohup "$bin" >/tmp/redis_$v.log 2>&1 &
  fi
  sleep 1
  if pgrep -x redis-server >/dev/null; then
    echo "Redis started (logs: /tmp/redis_$v.log)"
  else
    echo "Failed to start. Check /tmp/redis_$v.log"
  fi
}

redis_stop() {
  echo "Stopping all User redis-server processes..."
  pkill -u "$USER" redis-server
}

# Aliases
alias redis_versions='redis_list'
alias redis_use='use_redis'   # Legacy/Inverse alias
alias rstart='redis_start'
alias rstop='redis_stop'
alias rcli='redis-cli'

load_components_completion "use_redis" "Redis"
