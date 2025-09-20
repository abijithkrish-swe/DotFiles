# 75) MySQL helpers — portable layout:
#   ~/Components/Mysql/<ver>/Core
#   ~/Components/Mysql/<ver>/Data
#   ~/Components/Mysql/<ver>/Conf/my.cnf
#   ~/Components/Mysql/<ver>/Log      # non-bin logs live here

# Root path for MySQL portable installs
export MYSQL_ROOT="$COMPONENTS/Mysql"

# --- internal: read a key from my.cnf (ignores commented lines)
_mysql_conf_get() {
  local cnf="$1" key="$2"
  awk -v k="$key" '
    /^[[:space:]]*#/ { next }           # skip comments
    /^[[:space:]]*$/ { next }           # skip blank
    {
      # normalize "key = value" or "key=value"
      match($0, /^[[:space:]]*([^=[:space:]]+)[[:space:]]*=[[:space:]]*(.*)$/, m)
      if (m[1] == k) { print m[2]; exit }
    }
  ' "$cnf"
}

# --- internal: verify my.cnf matches expected Core/Data/Log paths
_mysql_conf_check() {
  local ver="$1"
  local base="$MYSQL_ROOT/$ver"
  local core="$base/Core"
  local data="$base/Data"
  local conf="$base/Conf/my.cnf"
  local logdir="$base/Log"

  [[ -f "$conf" ]] || { echo "ERROR: Missing $conf"; return 1; }

  # Create Log/ and Data/ if missing
  mkdir -p "$logdir" "$data"

  local basedir datadir socket pidfile logerr slowfile genfile binbase
  basedir="$(_mysql_conf_get "$conf" basedir)"
  datadir="$(_mysql_conf_get "$conf" datadir)"
  socket="$(_mysql_conf_get "$conf" socket)"
  pidfile="$(_mysql_conf_get "$conf" pid-file)"
  logerr="$(_mysql_conf_get "$conf" log-error)"
  slowfile="$(_mysql_conf_get "$conf" slow_query_log_file)"
  genfile="$(_mysql_conf_get "$conf" general_log_file)"
  binbase="$(_mysql_conf_get "$conf" log-bin)"

  # Required: basedir/datadir must match our layout
  if [[ "$basedir" != "$core" ]]; then
    echo "ERROR: basedir in my.cnf ($basedir) != $core"; return 1;
  fi
  if [[ "$datadir" != "$data" ]]; then
    echo "ERROR: datadir in my.cnf ($datadir) != $data"; return 1;
  fi

  # Ensure parent dirs for configured files exist
  for f in "$socket" "$pidfile" "$logerr" "$slowfile" "$genfile"; do
    [[ -n "$f" ]] || continue
    mkdir -p "$(dirname "$f")" 2>/dev/null
  done
  if [[ -n "$binbase" ]]; then
    mkdir -p "$(dirname "$binbase")" 2>/dev/null
  fi

  # Enforce non-bin logs go to Log/
  for f in "$logerr" "$slowfile" "$genfile"; do
    [[ -n "$f" ]] || continue
    case "$f" in
      "$logdir"/*) ;;                 # OK
      *) echo "WARNING: $f not under $logdir (recommended)";;
    esac
  done

  # Enforce binlog base lives under Data/
  if [[ -n "$binbase" ]]; then
    case "$binbase" in
      "$data"/*) ;;                   # OK
      *) echo "WARNING: log-bin base ($binbase) not under $data (recommended)";;
    esac
  fi

  return 0
}

# Show a quick view of important my.cnf values
mysql_conf_inspect() {
  local ver="${1:?version}"
  local base="$MYSQL_ROOT/$ver"
  local conf="$base/Conf/my.cnf"
  [[ -f "$conf" ]] || { echo "Missing $conf"; return 1; }
  echo "== $conf =="
  for k in basedir datadir socket pid-file port bind-address \
           log-error slow_query_log slow_query_log_file general_log general_log_file log-bin; do
    printf "%-22s %s\n" "$k" "$(_mysql_conf_get "$conf" "$k")"
  done
}

# Set a default MySQL client version (append PATH + confirm)
mysql_set_default() {
  local v="${1:?version}"
  local core="$MYSQL_ROOT/$v/Core"
  if [ -d "$core/bin" ]; then
    export PATH="$PATH:$core/bin"   # append (safer)
    echo "Default MySQL client set to $v"
    mysql --version 2>/dev/null || echo "mysql not found in $core/bin"
  else
    echo "MySQL $v not found under $MYSQL_ROOT"
    return 1
  fi
}

# Initialize a MySQL instance (safe: refuses if Data/ not empty; checks my.cnf)
# NOTE: stays EXPLICIT on version (no default fallback) to avoid mistakes.
mysql_init() {
  local v="${1:?version}"
  local base="$MYSQL_ROOT/$v"
  local core="$base/Core"
  local data="$base/Data"
  local conf="$base/Conf/my.cnf"

  [[ -d "$core/bin" ]] || { echo "MySQL $v Core not found under $MYSQL_ROOT"; return 1; }
  _mysql_conf_check "$v" || return 1

  if [ -d "$data" ] && [ "$(ls -A "$data" 2>/dev/null)" ]; then
    echo "Refusing to initialize: $data already exists and is NOT empty."
    echo "If you really want a fresh init, move/backup the directory first."
    return 1
  fi
  mkdir -p "$data"

  "$core/bin/mysqld" --defaults-file="$conf" --initialize-insecure --basedir="$core" --datadir="$data" || return $?
  echo "Initialized MySQL $v data dir at $data"
}

# Start MySQL instance (falls back to DEFAULT_MYSQL_CLIENT if not provided)
mysql_start() {
  local v="${1:-$DEFAULT_MYSQL_CLIENT}"
  if [[ -z "$v" ]]; then
    echo "Usage: mysql_start <version>  (or set DEFAULT_MYSQL_CLIENT)"
    return 1
  fi
  local base="$MYSQL_ROOT/$v"
  local core="$base/Core"
  local data="$base/Data"
  local conf="$base/Conf/my.cnf"

  _mysql_conf_check "$v" || return 1

  # Avoid double-start if a running pid exists
  local pidfile="$(_mysql_conf_get "$conf" pid-file)"
  if [[ -n "$pidfile" && -f "$pidfile" ]] && ps -p "$(cat "$pidfile" 2>/dev/null)" >/dev/null 2>&1; then
    echo "MySQL $v appears to be running (pid $(cat "$pidfile"))."; return 0
  fi

  nohup "$core/bin/mysqld" --defaults-file="$conf" --basedir="$core" --datadir="$data" >/dev/null 2>&1 &
  sleep 0.5
  echo "Started MySQL $v with $conf"
}

# Stop MySQL instance (falls back to DEFAULT_MYSQL_CLIENT if not provided)
mysql_stop() {
  local v="${1:-$DEFAULT_MYSQL_CLIENT}"
  if [[ -z "$v" ]]; then
    echo "Usage: mysql_stop <version>  (or set DEFAULT_MYSQL_CLIENT)"
    return 1
  fi
  local base="$MYSQL_ROOT/$v"
  local core="$base/Core"
  local conf="$base/Conf/my.cnf"

  if "$core/bin/mysqladmin" --defaults-file="$conf" shutdown 2>/dev/null; then
    echo "Stopped MySQL $v"
    return 0
  fi

  # Fallback to pidfile kill if mysqladmin fails
  local pidfile="$(_mysql_conf_get "$conf" pid-file)"
  if [[ -n "$pidfile" && -f "$pidfile" ]]; then
    kill "$(cat "$pidfile")" && echo "Stopped MySQL $v (kill pid)"
  else
    echo "Could not find pidfile; try: pkill mysqld"
  fi
}

# Wait until MySQL is ready (socket or TCP), with timeout
# Usage: mysql_ready <ver> [timeout_sec]
mysql_ready() {
  local v="${1:?version}"; shift
  local timeout="${1:-30}"

  local base="$MYSQL_ROOT/$v"
  local conf="$base/Conf/my.cnf"
  [[ -f "$conf" ]] || { echo "Missing $conf"; return 1; }

  local sock port host
  sock="$(_mysql_conf_get "$conf" socket)"
  port="$(_mysql_conf_get "$conf" port)"
  host="$(_mysql_conf_get "$conf" bind-address)"; [[ -z "$host" ]] && host="127.0.0.1"

  local start ts; start="$(date +%s)"
  while :; do
    if [[ -n "$sock" && -S "$sock" ]]; then
      echo "MySQL $v is ready (socket: $sock)"; return 0
    fi
    if [[ -n "$port" ]]; then
      if (exec 3<>"/dev/tcp/$host/$port") >/dev/null 2>&1; then
        exec 3>&- 2>/dev/null || true
        echo "MySQL $v is ready (tcp: $host:$port)"; return 0
      fi
    fi
    ts="$(date +%s)"
    (( ts - start >= timeout )) && { echo "Timeout waiting for MySQL $v (socket=$sock port=$host:$port)"; return 1; }
    sleep 1
  done
}

# Client wrapper — uses DEFAULT_MYSQL_CLIENT if no version is passed
mysql_cli() {
  local v="$1"
  if [[ -z "$v" || "$v" == -* ]]; then
    v="$DEFAULT_MYSQL_CLIENT"
    [[ -z "$v" ]] && { echo "Set DEFAULT_MYSQL_CLIENT or pass a version"; return 1; }
    mysql "$@"
  else
    shift
    local core="$MYSQL_ROOT/$v/Core"
    "$core/bin/mysql" "$@"
  fi
}

# Shortcut: list versions
mysqlv() { ls -1 "$MYSQL_ROOT"; }

# ---------------------------------------------------------------------
# 75) Python (portable)
# ---------------------------------------------------------------------