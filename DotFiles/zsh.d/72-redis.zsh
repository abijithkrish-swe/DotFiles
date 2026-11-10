# ---------------------------------------------------------------------
# 72) Redis helpers — safe list, switch, cli, start/stop
# ---------------------------------------------------------------------

: "${COMPONENTS:="$HOME/Components"}"
# DEFAULT_REDIS comes from the components manifest (70-components-core.zsh).

# Bin dir for an approved (manifest-listed) version; fails for anything else.
_redis_bindir_for() {
  local v="$1"
  components_is_approved redis "$v" || return 1
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

_redis_write_default_conf() {
  local conf="$1"
  cat > "$conf" <<'EOF'
# Redis Configuration
# Generated for version-specific customization

# Disable disk save (in-memory only)
save ""
appendonly no

# Network & Persistence
port 6379
bind 127.0.0.1
timeout 0

# Memory Management
maxmemory 256mb
maxmemory-policy allkeys-lru

# Logging
loglevel notice
logfile ""

# Database
databases 16

# To enable disk save, uncomment below:
# save 900 1        # 900 sec (15 min): if at least 1 key changed
# save 300 10       # 300 sec (5 min): if at least 10 keys changed
# save 60 10000     # 60 sec: if at least 10000 keys changed
# appendonly yes
# appendfilename "appendonly.aof"
EOF
}

_redis_conf_value() {
  local conf="$1" key="$2"
  awk -v k="$key" '$0 !~ /^[[:space:]]*#/ && $1 == k {print $2; exit}' "$conf" 2>/dev/null
}

redis_list() { components_list redis Redis; }

# use_redis [ver]  — approved version (exact or unique prefix), default if omitted
use_redis() {
  if [[ "$1" == "off" ]]; then
    redis_clear
    return
  fi

  components_activate redis Redis _REDIS_ACTIVE_BIN "$1" || return 1

  echo "➡️ Using Redis $CM_V ($CM_BIN_DIR)"
  command -v redis-cli >/dev/null && redis-cli --version
}

redis_clear() {
  components_deactivate redis Redis _REDIS_ACTIVE_BIN
  echo "Redis removed from PATH"
}

# Start redis-server (with optional redis.conf if present)
redis_start() {
  local v="${1:-$DEFAULT_REDIS}" bin
  setopt local_options no_monitor
  # Accept a unique prefix like use_redis does ("7" → 7.4.5)
  components_resolve redis "$v" 2>/dev/null && v="$CM_V"

  # Ensure we have the bin in path or find it
  if ! bin="$(_redis_bindir_for "$v")/redis-server" 2>/dev/null; then
     # Try current PATH if no version arg
     if ! bin="$(command -v redis-server)"; then
        echo "Redis $v not found (and not in PATH)"; return 1
     fi
  fi
  
  echo "Starting $bin..."
  
  local root="$COMPONENTS/Redis/$v"
  local confdir="$root/Conf"
  local conf="$confdir/redis.conf"
  
  # Auto-initialize conf if it doesn't exist
  if [[ ! -f "$conf" ]]; then
    mkdir -p "$confdir"
    _redis_write_default_conf "$conf"
    echo "✅ Created default conf at: $conf (disk save disabled)"
  fi
  
  rm -f "/tmp/redis_$v.log"
  
  nohup "$bin" "$conf" > "/tmp/redis_$v.log" 2>&1 &
  local pid=$!
  
  sleep 2
  
  # Check if process is still running
  if kill -0 $pid 2>/dev/null; then
    local redis_host redis_port
    redis_host="$(_redis_conf_value "$conf" "bind")"
    redis_port="$(_redis_conf_value "$conf" "port")"
    [[ -n "$redis_host" ]] || redis_host="127.0.0.1"
    [[ -n "$redis_port" ]] || redis_port="6379"

    # Process is running, also verify connection
    if command -v redis-cli >/dev/null 2>&1; then
      if redis-cli -h "$redis_host" -p "$redis_port" ping >/dev/null 2>&1; then
        echo "✅ Redis started successfully (logs: /tmp/redis_$v.log)"
      else
        echo "⚠️  Process started but connection failed. Logs:"
        cat "/tmp/redis_$v.log"
      fi
    else
      echo "✅ Redis started (PID: $pid). Install redis-cli to verify connection."
    fi
  else
    echo "❌ Redis failed to start. Logs:"
    cat "/tmp/redis_$v.log"
  fi
}

redis_stop() {
  echo "Stopping all User redis-server processes..."
  pkill -u "$USER" redis-server
}

# Initialize a conf file for a Redis version (no disk save by default)
redis_init_conf() {
  local v="$1"
  [[ -z "$v" ]] && { echo "Usage: redis_init_conf <version>"; return 1; }
  
  local root="$COMPONENTS/Redis/$v"
  [[ -d "$root" ]] || { echo "Redis $v not found at $root"; return 1; }
  
  local confdir="$root/Conf"
  mkdir -p "$confdir"
  
  local conf="$confdir/redis.conf"
  if [[ -f "$conf" ]]; then
    echo "Config already exists at $conf"
    return 0
  fi
  
  _redis_write_default_conf "$conf"
  
  echo "✅ Created $conf (disk save disabled by default)"
}

# Aliases
alias redis_versions='redis_list'
alias redis_use='use_redis'   # Legacy/Inverse alias
alias rstart='redis_start'
alias rstop='redis_stop'
alias rcli='redis-cli'

load_components_completion "use_redis" "Redis"
