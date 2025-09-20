# 72) Redis helpers

# List redis versions
redis_versions() {
  ls -1 "$COMPONENTS/Redis"
}

# Resolve redis-server or redis-cli path
_redis_bin() {
  local v="$1" cmd="$2"
  local root="$COMPONENTS/Redis/$v"
  if [ -x "$root/src/$cmd" ]; then
    echo "$root/src/$cmd"; return 0
  fi
  if [ -x "$root/bin/$cmd" ]; then
    echo "$root/bin/$cmd"; return 0
  fi
  return 1
}

# Start redis (falls back to DEFAULT_REDIS if not provided)
rstart() {
  local v="${1:-$DEFAULT_REDIS}"
  if [[ -z "$v" ]]; then
    echo "Usage: rstart <version>  (or set DEFAULT_REDIS)"
    return 1
  fi
  local bin="$(_redis_bin "$v" redis-server)" || { echo "Redis $v not found"; return 1; }
  if [ -f "$COMPONENTS/Redis/$v/redis.conf" ]; then
    "$bin" "$COMPONENTS/Redis/$v/redis.conf" &
  else
    "$bin" &
  fi
  echo "Started redis $v"
}

# Stop redis
rstop() {
  pkill -f redis-server || echo "No redis-server found"
}

# Redis CLI (falls back to DEFAULT_REDIS if not provided)
rcli() {
  local v="$1"
  if [[ -z "$v" || "$v" == -* ]]; then
    v="$DEFAULT_REDIS"
    [[ -z "$v" ]] && { echo "Set DEFAULT_REDIS or pass a version"; return 1; }
    local bin="$(_redis_bin "$v" redis-cli)" || { echo "Redis $v not found"; return 1; }
    "$bin" "$@"
  else
    shift
    local bin="$(_redis_bin "$v" redis-cli)" || { echo "Redis $v not found"; return 1; }
    "$bin" "$@"
  fi
}

# Use a redis version in current shell (append PATH + confirm; falls back to default)
use_redis() {
  local v="${1:-$DEFAULT_REDIS}"
  if [[ -z "$v" ]]; then
    echo "Usage: use_redis <version>  (or set DEFAULT_REDIS)"
    return 1
  fi
  local server_bin="$(_redis_bin "$v" redis-server)" || { echo "Redis $v not found"; return 1; }
  local bindir; bindir="$(dirname "$server_bin")"
  export PATH="$PATH:$bindir"   # append (safer)
  echo "Using Redis $v from $bindir"
  redis-cli --version 2>/dev/null || echo "redis-cli not found in $bindir"
}

# ---------------------------------------------------------------------
# 73) Ant helpers
# ---------------------------------------------------------------------