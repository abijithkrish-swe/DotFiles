# ---------------------------------------------------------------------
# 75) MySQL helpers — safe list, switch, start/stop/cli
# Portable per-version layout:
#   $COMPONENTS/Mysql/<version>/
#       Core/ → binaries (bin/mysql, bin/mysqld)
#       Data/ → database files (datadir)
#       Conf/ → my.cnf (optional)
#       Run/  → runtime files (mysqld.sock, mysqld.pid, run.env)
#       Log/  → logs (error.log, slow.log, query.log)
# Only versions with Core/bin/mysql AND Core/bin/mysqld are valid.
# ---------------------------------------------------------------------

setopt LOCAL_OPTIONS

: "${COMPONENTS:="$HOME/Components"}"
: "${DEFAULT_MYSQL:="8.0.43"}"

# Optional: set to "1" to keep a stable client socket symlink at ~/.mysql/current.sock
: "${MYSQL_UPDATE_SYMLINK:="0"}"

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

# Return Core/bin path for a valid version
_mysql_bindir_for() {
  local v="$1" root="$COMPONENTS/Mysql/$v/Core/bin"
  [[ -x "$root/mysql" && -x "$root/mysqld" ]] || return 1
  print -r -- "$root"
}

_mysql_root_for() { print -r -- "$COMPONENTS/Mysql/$1"; }

_mysql_has_arg() {  # _mysql_has_arg "--socket" "$@"
  local needle="$1"; shift
  local a
  for a in "$@"; do [[ "$a" == ${needle}(|=*) ]] && return 0; done
  return 1
}

_mysql_running_pids_for_user() {
  pgrep -u "$UID" -x mysqld 2>/dev/null
}

_find_free_port() {
  local p="${1:-3307}"
  while :; do
    if command -v lsof >/dev/null 2>&1; then
      lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 || { echo "$p"; return 0; }
    elif command -v nc >/dev/null 2>&1; then
      nc -z localhost "$p" >/dev/null 2>&1 || { echo "$p"; return 0; }
    else
      echo "$p"; return 0
    fi
    p=$((p+1))
  done
}

# overwrite even if 'noclobber' is set
_write_runinfo() {
  local rundir="$1" pid="$2" socket="$3" port="$4"
  {
    print -r -- "PID=$pid"
    print -r -- "SOCKET=$socket"
    print -r -- "PORT=$port"
  } >| "$rundir/run.env"
}

_read_runinfo() {
  local rundir="$1"
  [[ -f "$rundir/run.env" ]] && source "$rundir/run.env"
}

# A datadir is considered initialized if it contains the mysql system DB
_datadir_initialized() {
  local d="$1"
  [[ -d "$d/mysql" ]]
}

# Consider empty if only harmless junk like .DS_Store / empty lost+found
_datadir_only_ignorable_junk() {
  local d="$1"
  local -a items
  items=($(ls -A "$d" 2>/dev/null))
  (( ${#items} == 0 )) && return 0
  items=(${items:#.DS_Store})
  if [[ -d "$d/lost+found" && -z "$(ls -A "$d/lost+found" 2>/dev/null)" ]]; then
    items=(${items:#lost+found})
  fi
  (( ${#items} == 0 ))
}

# --- 1) view available versions --------------------------------------

mysql_list() {
  local d v
  [[ -d "$COMPONENTS/Mysql" ]] || { echo "No Mysql components at $COMPONENTS/Mysql"; return 0; }
  echo "Available MySQL versions:"
  for d in "$COMPONENTS/Mysql"/*; do
    [[ -d "$d" ]] || continue
    v="${d:t}"
    _mysql_bindir_for "$v" >/dev/null && echo "  $v"
  done | { command -v sort >/dev/null && sort -V || sort; }
}

# --- PATH management --------------------------------------------------

mysql_clear() {
  component_switch_path "_MYSQL_ACTIVE_BINDIR" ""
  echo "MySQL removed from PATH"
}

# --- 2) use_mysql <version> ------------------------------------------

use_mysql() {
  local v="${1:-$DEFAULT_MYSQL}" bindir root
  
  if [[ "$v" == "off" ]]; then
    mysql_clear
    return
  fi

  [[ -n "$v" ]] || { echo "Usage: use_mysql <version> (tip: mysql_list)"; return 1; }

  if ! bindir="$(_mysql_bindir_for "$v")"; then
    echo "❌ MySQL $v not found or invalid (need Core/bin with mysql & mysqld)."
    mysql_list
    return 1
  fi

  root="$(_mysql_root_for "$v")"

  component_switch_path "_MYSQL_ACTIVE_BINDIR" "$bindir"
  rehash

  # Set per-version envs
  MYSQL_VERSION="$v"
  MYSQL_HOME="$root"
  MYSQL_DATADIR="$root/Data"
  MYSQL_LOGDIR="$root/Log"
  MYSQL_RUNDIR="$root/Run"
  MYSQL_SOCKET="$MYSQL_RUNDIR/mysqld.sock"
  MYSQL_PIDFILE="$MYSQL_RUNDIR/mysqld.pid"

  mkdir -p "$MYSQL_RUNDIR"

  # Update stable client symlink if enabled
  if [[ "$MYSQL_UPDATE_SYMLINK" == "1" ]]; then
    mkdir -p "$HOME/.mysql"
    ln -snf "$MYSQL_SOCKET" "$HOME/.mysql/current.sock"
  fi

  # Auto-point client to socket when it exists
  if [[ -S "$MYSQL_SOCKET" ]]; then
    export MYSQL_UNIX_PORT="$MYSQL_SOCKET"
  fi

  echo "➡️ Using MySQL $v ($_MYSQL_ACTIVE_BINDIR)"
  command -v mysql >/dev/null && mysql --version
}

# --- 3) mysql_start [--port N] [version] ------------------------------
# If a mysqld is already running (for your user), ask to stop it or start alongside on a free port.

mysql_start() {
  local v= port= conf bindir root rundir datadir logdir socket pidfile init_needed=0 yn
  # optional --port
  if [[ "$1" == --port ]]; then port="$2"; shift 2; fi
  v="${1:-${MYSQL_VERSION:-$DEFAULT_MYSQL}}"

  if ! bindir="$(_mysql_bindir_for "$v")"; then echo "MySQL $v not found"; return 1; fi

  use_mysql "$v" >/dev/null

  root="$MYSQL_HOME"
  datadir="$MYSQL_DATADIR"; logdir="$MYSQL_LOGDIR"; rundir="$MYSQL_RUNDIR"
  socket="$MYSQL_SOCKET"; pidfile="$MYSQL_PIDFILE"
  conf="$root/Conf/my.cnf"

  mkdir -p "$datadir" "$logdir" "$rundir"

  # initialize if not actually initialized
  if ! _datadir_initialized "$datadir"; then
    if _datadir_only_ignorable_junk "$datadir"; then
      "$_MYSQL_ACTIVE_BINDIR/mysqld" --initialize-insecure --datadir="$datadir" || {
        echo "Initialization failed"; return 1; }
      init_needed=1
    else
      echo "❌ Datadir not initialized and not empty: $datadir"
      echo "   Move it aside or choose a clean directory, then try again."
      return 1
    fi
  fi

  # detect running mysqld for current user
  local running="$(_mysql_running_pids_for_user)"
  if [[ -n "$running" ]]; then
    print -n -- "⚠️ Detected mysqld running for $USER (PIDs: $running). Stop and continue? [y/N] "
    read -r yn
    if [[ "$yn" == [yY] ]]; then
      mysql_stop 2>/dev/null || true
    else
      port="${port:-$(_find_free_port 3307)}"
      socket="$rundir/mysqld-$port.sock"
      pidfile="$rundir/mysqld-$port.pid"
      echo "→ Starting alongside on port $port (socket: $socket)"
    fi
  fi

  port="${port:-3306}"

  # launch
  if [[ -f "$conf" ]]; then
    "$_MYSQL_ACTIVE_BINDIR/mysqld" \
      --defaults-file="$conf" \
      --datadir="$datadir" \
      --socket="$socket" \
      --pid-file="$pidfile" \
      --port="$port" \
      --log-error="$logdir/error.log" &
  else
    "$_MYSQL_ACTIVE_BINDIR/mysqld" \
      --datadir="$datadir" \
      --socket="$socket" \
      --pid-file="$pidfile" \
      --port="$port" \
      --log-error="$logdir/error.log" &
  fi

  # verify (wait up to ~5s for socket/pid)
  typeset -i tries=0
  local pid=""
  while (( tries++ < 10 )); do
    [[ -S "$socket" ]] && break
    [[ -f "$pidfile" ]] && pid="$(<"$pidfile")"
    sleep 0.5
  done
  [[ -z "$pid" ]] && pid="$(pgrep -u "$UID" -x mysqld | tail -n1)"

  if [[ ! -S "$socket" && -z "$pid" ]]; then
    echo "❌ mysqld failed to start. See: $logdir/error.log"
    tail -n 30 "$logdir/error.log" 2>/dev/null || true
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
# After use_mysql, `mysql` resolves to the active version.
# This wrapper injects --socket if you didn't specify host/protocol/socket.
mysql_cli() {
  command -v mysql >/dev/null 2>&1 || { echo "mysql not on PATH. Run: use_mysql <version>"; return 1; }

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

# --- Autoload default -------------------------------------------------

if _mysql_bindir_for "$DEFAULT_MYSQL" >/dev/null; then
  use_mysql "$DEFAULT_MYSQL" >/dev/null
fi

# --- mysql help module ------------------------------------------------
_devhelp_mysql() {
cat <<'EOF'
MySQL — Quick Reference
=======================

Portable layout (per version)
-----------------------------
~/Components/Mysql/<VER>/
  ├─ Core/      # binaries (mysql, mysqld)
  ├─ Data/      # datadir (InnoDB, binlogs, ib*)
  ├─ Conf/      # my.cnf (optional)
  ├─ Log/       # error.log, slow.log, query.log
  └─ Run/       # mysqld.sock, mysqld.pid, run.env (auto-generated)

Core helper commands
--------------------
mysql_versions                 # list available valid versions
use_mysql <ver>                # switch PATH & envs to version (adds Core/bin)
mysql_start [--port N] [ver]   # start server; asks to stop or auto-picks free port
mysql_stop [ver]               # cleanly stop server (mysqladmin or pid)
mysql_cli [args...]            # mysql client for current version; auto uses socket
mysql_current                  # show active version, status, port, pid, paths

Quick examples
--------------
use_mysql 8.0.43
mysql_start
mysql_cli -uroot -p
mysql_start --port 3310 5.7.44   # run another version in parallel
mysql_stop
mysql_current

Config & data locations
-----------------------
Default components root:   $HOME/Components/Mysql
Default version:           (from $DEFAULT_MYSQL)
Each version defines:
  Data/:      actual MySQL datadir
  Log/:       error / slow / query logs
  Run/:       socket, pid, run.env (port, pid info)
  Conf/my.cnf optional configuration file

Maintenance & CLI basics
------------------------
mysql -u root -p
mysql -h 127.0.0.1 -P 3306 -u root -p
mysqldump -u root -p --single-transaction appdb > dump.sql
mysqladmin -u root -p shutdown

Common SQL
----------
SHOW DATABASES;
CREATE DATABASE appdb;
CREATE USER 'app'@'%' IDENTIFIED BY 'secret';
GRANT ALL ON appdb.* TO 'app'@'%';
FLUSH PRIVILEGES;
SHOW VARIABLES LIKE 'log_error';
SHOW GLOBAL STATUS LIKE 'Threads_connected';
SHOW ENGINE INNODB STATUS\G

Troubleshooting
---------------
• Can't connect: check socket vs TCP; use -h 127.0.0.1 to force TCP.
• Data init fails: ensure Data/ is clean or initialized (helper will refuse if junk found).
• Port busy: mysql_start can auto-pick a free port (starting 3307) or ask to stop existing.
• To reset: mv Data Data.bad.$(date +%s); mkdir Data; mysql_start
EOF
}

# Restart helper
mysql_restart() {
   local v="$1"
   echo "Restarting MySQL ${v:-associated with current path}..."
   mysql_stop "$v"
   sleep 2
   mysql_start "$v"
}

# Rule of 5 Aliases
alias mysql_versions='mysql_list'
alias mysql_use='use_mysql'
alias mysql_off='mysql_clear'

# If you use devhelp:
(( $+functions[_devhelp_register] )) && _devhelp_register "mysql" _devhelp_mysql

# ---------------------------------------------------------------------
# 75) Python (portable)
# (Your Python section can follow here, unchanged)
# ---------------------------------------------------------------------
