# ---------------------------------------------------------------------
# 75) MySQL helpers — safe list, switch, start/stop/cli
# Layout expected:
#   $COMPONENTS/Mysql/<version>/
#       Core/ → binaries
#       Data/ → database files
#       Conf/ → my.cnf
#	      Run/
#       Log/  → logs (error.log, slow.log, query.log)
# Only versions with Core/bin/mysql are considered valid.
# Valid version requires Core/bin/mysql AND Core/bin/mysqld.
# ---------------------------------------------------------------------

setopt LOCAL_OPTIONS

: "${COMPONENTS:="$HOME/Components"}"
: "${DEFAULT_MYSQL:="8.0.43"}"

typeset -g _MYSQL_ACTIVE_BINDIR=""
typeset -g MYSQL_VERSION=""
typeset -g MYSQL_HOME=""
typeset -g MYSQL_DATADIR=""
typeset -g MYSQL_LOGDIR=""
typeset -g MYSQL_RUNDIR=""
typeset -g MYSQL_SOCKET=""
typeset -g MYSQL_PIDFILE=""
typeset -g MYSQL_PORT=""

# --- Internals --------------------------------------------------------

_mysql_bindir_for() {
  local v="$1"
  local root="$COMPONENTS/Mysql/$v/Core/bin"
  if [[ ! -x "$root/mysql" ]]; then
    root="$COMPONENTS/Mysql/$v/bin"
  fi
  if [[ -x "$root/mysql" && -x "$root/mysqld" ]]; then
    print -r -- "$root"
    return 0
  fi
  return 1
}

_mysql_root_for() { print -r -- "$COMPONENTS/Mysql/$1"; }

_mysql_has_arg() {  # _mysql_has_arg "--socket" "$@"
  local needle="$1"; shift
  local a
  for a in "$@"; { [[ "$a" == ${needle}(|=*) ]] && return 0; }
  return 1
}

_mysql_running_pids_for_user() {
  # pids of mysqld owned by current user
  pgrep -u "$UID" -x mysqld 2>/dev/null
}

_find_free_port() {
  # find a free TCP port starting at $1 (default 3307)
  local p="${1:-3307}"
  while :; do
    if command -v lsof >/dev/null 2>&1; then
      lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 || { echo "$p"; return 0; }
    else
      # Fallback: try binding using nc if available; otherwise just return p
      if command -v nc >/dev/null 2>&1; then
        nc -z localhost "$p" >/dev/null 2>&1 || { echo "$p"; return 0; }
      else
        echo "$p"; return 0
      fi
    fi
    p=$((p+1))
  done
}

_write_runinfo() {
  local rundir="$1" pid="$2" socket="$3" port="$4"
  {
    print -r -- "PID=$pid"
    print -r -- "SOCKET=$socket"
    print -r -- "PORT=$port"
  } >| "$rundir/run.env"   # note the >|
}

_read_runinfo() {
  local rundir="$1"
  [[ -f "$rundir/run.env" ]] && source "$rundir/run.env"
}

# --- 1) view available versions --------------------------------------

mysql_versions() {
  local d v
  [[ -d "$COMPONENTS/Mysql" ]] || { echo "No Mysql components at $COMPONENTS/Mysql"; return 0; }
  for d in "$COMPONENTS/Mysql"/*; do
    [[ -d "$d" ]] || continue
    v="${d:t}"
    _mysql_bindir_for "$v" >/dev/null && echo "$v"
  done | { command -v sort >/dev/null && sort -V || sort; }
}

# --- PATH management --------------------------------------------------

mysql_clear_path() {
  [[ -n "$_MYSQL_ACTIVE_BINDIR" ]] || return 0
  path=(${^path:#$_MYSQL_ACTIVE_BINDIR})
  _MYSQL_ACTIVE_BINDIR=""
  rehash
}

# --- 2) use_mysql <version> ------------------------------------------

use_mysql() {
  local v="${1:-$DEFAULT_MYSQL}" bindir root
  [[ -n "$v" ]] || { echo "Usage: use_mysql <version> (tip: mysql_versions)"; return 1; }

  if ! bindir="$(_mysql_bindir_for "$v")"; then
    echo "❌ MySQL $v not found or invalid (need Core/bin with mysql & mysqld)."
    mysql_versions
    return 1
  fi

  root="$(_mysql_root_for "$v")"

  mysql_clear_path
  path+=("$bindir")
  _MYSQL_ACTIVE_BINDIR="$bindir"
  rehash

  # Set per-version envs
  MYSQL_VERSION="$v"
  MYSQL_HOME="$root"
  MYSQL_DATADIR="$root/Data"
  MYSQL_LOGDIR="$root/Log"
  MYSQL_RUNDIR="$root/Run"
  MYSQL_SOCKET="$MYSQL_RUNDIR/mysqld.sock"
  MYSQL_PIDFILE="$MYSQL_RUNDIR/mysqld.pid"
  # If a socket exists, make the mysql client auto-use it.
  if [[ -S "$MYSQL_SOCKET" ]]; then
    export MYSQL_UNIX_PORT="$MYSQL_SOCKET"
  fi

  echo "➡️ Using MySQL $v ($_MYSQL_ACTIVE_BINDIR)"
  command -v mysql >/dev/null && mysql --version
}

# --- 3) mysql_start [--port N] [version] ------------------------------
# If a mysqld is already running (yours), asks to stop it or start this one on a different port.

mysql_start() {
  local v= port= conf bindir root rundir datadir logdir socket pidfile init_needed=0 yn
  # allow optional --port and version
  if [[ "$1" == --port ]]; then port="$2"; shift 2; fi
  v="${1:-${MYSQL_VERSION:-$DEFAULT_MYSQL}}"

  if ! bindir="$(_mysql_bindir_for "$v")"; then echo "MySQL $v not found"; return 1; fi

  use_mysql "$v" >/dev/null

  root="$MYSQL_HOME"
  datadir="$MYSQL_DATADIR"; logdir="$MYSQL_LOGDIR"; rundir="$MYSQL_RUNDIR"
  socket="$MYSQL_SOCKET"; pidfile="$MYSQL_PIDFILE"
  conf="$root/Conf/my.cnf"

  mkdir -p "$datadir" "$logdir" "$rundir"

  # initialize if empty
  if [[ -z "$(ls -A "$datadir" 2>/dev/null)" ]]; then
    "$_MYSQL_ACTIVE_BINDIR/mysqld" --initialize-insecure --datadir="$datadir" || {
      echo "Initialization failed"; return 1; }
    init_needed=1
  fi

  # detect running mysqld for current user
  local running="$(_mysql_running_pids_for_user)"
  if [[ -n "$running" ]]; then
    echo "⚠️ Detected mysqld running for user $USER (PIDs: $running)"
    vared -p "Stop existing mysqld and start $v here? [y/N] " -c yn
    if [[ "$yn" == [yY] ]]; then
      mysql_stop 2>/dev/null || true
    else
      # run alongside on a different port/socket
      port="${port:-$(_find_free_port 3307)}"
      socket="$rundir/mysqld-$port.sock"
      pidfile="$rundir/mysqld-$port.pid"
      echo "→ Will start alongside on port $port (socket: $socket)"
    fi
  fi

  # choose port if still unset
  port="${port:-3306}"

  # launch
  if [[ -f "$conf" ]]; then
    nohup "$_MYSQL_ACTIVE_BINDIR/mysqld" \
      --defaults-file="$conf" \
      --datadir="$datadir" \
      --socket="$socket" \
      --pid-file="$pidfile" \
      --port="$port" \
      --log-error="$logdir/error.log" >/dev/null 2>&1 &
  else
    nohup "$_MYSQL_ACTIVE_BINDIR/mysqld" \
      --datadir="$datadir" \
      --socket="$socket" \
      --pid-file="$pidfile" \
      --port="$port" \
      --log-error="$logdir/error.log" >/dev/null 2>&1 &
  fi

  # verify (wait up to ~5s for socket/pid)
  typeset -i tries=0
  while (( tries++ < 10 )); do
    [[ -S "$socket" ]] && break
    [[ -f "$pidfile" ]] && pid="$(<"$pidfile")"
    sleep 0.5
  done

  # if PID still unknown, try to infer the last mysqld of this user
  [[ -z "$pid" ]] && pid="$(pgrep -u "$UID" -x mysqld | tail -n1)"

  if [[ ! -S "$socket" && -z "$pid" ]]; then
    echo "❌ mysqld failed to start. See: $logdir/error.log"
    tail -n 30 "$logdir/error.log"
    return 1
  fi

  _write_runinfo "$rundir" "$pid" "$socket" "$port"
  export MYSQL_UNIX_PORT="$socket"

  echo "✅ Started MySQL $v  PID=${pid:-?}  PORT=$port"
  echo "   Data:   $datadir"
  echo "   Socket: $socket"
  echo "   Logs:   $logdir"
  (( init_needed )) && echo "   (Initialized empty data directory)"
}

# --- 4) mysql_cli [args] ----------------------------------------------
# Q: shouldn't PATH auto use current version cli? → Yes. After use_mysql,
#    `mysql` resolves to the active bindir. This wrapper just injects the socket
#    if you didn’t specify one and a local socket exists.

mysql_cli() {
  command -v mysql >/dev/null 2>&1 || { echo "mysql not on PATH. Run: use_mysql <version>"; return 1; }

  # If user already specified a connection method (host/socket/protocol), don't touch.
  if ! _mysql_has_arg "--socket" "$@" && ! _mysql_has_arg "--host" "$@" && ! _mysql_has_arg "--protocol" "$@"; then
    if [[ -S "$MYSQL_SOCKET" ]]; then
      mysql --socket="$MYSQL_SOCKET" "$@"
      return $?
    fi
  fi
  mysql "$@"
}

# --- 5) stop ----------------------------------------------------------

mysql_stop() {
  local v="${1:-${MYSQL_VERSION:-$DEFAULT_MYSQL}}" bindir root rundir socket pidfile pid
  if ! bindir="$(_mysql_bindir_for "$v")"; then echo "MySQL $v not found"; return 1; fi
  root="$(_mysql_root_for "$v")"; rundir="$root/Run"; socket="$rundir/mysqld.sock"; pidfile="$rundir/mysqld.pid"

  _read_runinfo "$rundir"  # may set PID/PORT/SOCKET
  [[ -n "$SOCKET" ]] && socket="$SOCKET"
  [[ -n "$PID" ]] && pid="$PID"
  [[ -z "$pid" && -f "$pidfile" ]] && pid="$(<"$pidfile")"

  if [[ -S "$socket" ]]; then
    "$bindir/mysqladmin" --socket="$socket" -uroot shutdown 2>/dev/null && { echo "🛑 Stopped MySQL $v via mysqladmin"; return 0; }
  fi
  if [[ -n "$pid" ]]; then
    kill "$pid" && { echo "🛑 Stopped MySQL $v via PID $pid"; return 0; }
  fi

  # last resort for current user only
  local pids="$(_mysql_running_pids_for_user)"
  if [[ -n "$pids" ]]; then
    echo "Could not find socket/PID; stopping your mysqld processes: $pids"
    kill $pids && echo "🛑 Stopped."
  else
    echo "No mysqld found for user $USER."
  fi
}

# --- 6) mysql_current -------------------------------------------------

mysql_current() {
  local bin_mysql bin_mysqld state="stopped" root rundir datadir logdir socket pid port

  if command -v mysql >/dev/null 2>&1; then
    bin_mysql="$(command -v mysql)"
    echo "mysql -> $bin_mysql"
  else
    echo "mysql not on PATH"
  fi

  if command -v mysqld >/dev/null 2>&1; then
    bin_mysqld="$(command -v mysqld)"
    echo "mysqld -> $bin_mysqld"
  else
    echo "mysqld not on PATH"
  fi

  [[ -n "$MYSQL_VERSION" ]] && echo "Current version: $MYSQL_VERSION"

  root="$MYSQL_HOME"; datadir="$MYSQL_DATADIR"; logdir="$MYSQL_LOGDIR"; rundir="$MYSQL_RUNDIR"; socket="$MYSQL_SOCKET"
  [[ -n "$root" ]]   && echo "Home:   $root"
  [[ -n "$datadir" ]]&& echo "Data:   $datadir"
  [[ -n "$logdir" ]] && echo "Logs:   $logdir"
  [[ -n "$rundir" ]] && echo "Run:    $rundir"
  [[ -n "$socket" ]] && echo "Socket: $socket"

  # read saved run info (may define PID/PORT/SOCKET)
  _read_runinfo "$rundir"
  [[ -n "$SOCKET" ]] && socket="$SOCKET"
  [[ -n "$PID" ]]    && pid="$PID"
  [[ -n "$PORT" ]]   && port="$PORT"
  [[ -z "$pid" && -f "$MYSQL_PIDFILE" ]] && pid="$(<"$MYSQL_PIDFILE")"

  if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
    state="running"
  elif [[ -S "$socket" ]] && command -v mysqladmin >/dev/null 2>&1; then
    mysqladmin --socket="$socket" ping >/dev/null 2>&1 && state="running"
  fi

  echo "Status: $state"
  [[ -n "$pid"  ]] && echo "PID:  $pid"
  [[ -n "$port" ]] && echo "Port: $port"
}

_mysql_bindir_for_debug() {
  local v="$1"
  local root="$COMPONENTS/Mysql/$v/Core/bin"
  echo "Testing version: $v"
  echo "Expect path: $root"
  if [[ -x "$root/mysql" && -x "$root/mysqld" ]]; then
    echo "✅ Found valid MySQL binaries"
    print -r -- "$root"
    return 0
  else
    echo "❌ Invalid or missing binaries"
    return 1
  fi
}

# --- Autoload default -------------------------------------------------

if _mysql_bindir_for "$DEFAULT_MYSQL" >/dev/null; then
  use_mysql "$DEFAULT_MYSQL" >/dev/null
fi

# ---------------------------------------------------------------------
# 75) Python (portable)
# ---------------------------------------------------------------------
