# ---------------------------------------------------------------------
# 75) MySQL helpers — safe list, switch, start/stop/cli
# Layout expected:
#   $COMPONENTS/Mysql/<version>/
#       Core/ → binaries
#       Data/ → database files
#       Conf/ → my.cnf
#       Log/  → logs (error.log, slow.log, query.log)
# Only versions with Core/bin/mysql are considered valid.
# ---------------------------------------------------------------------

: "${COMPONENTS:="$HOME/Components"}"
: "${DEFAULT_MYSQL:="8.0.43"}"

typeset -g _MYSQL_ACTIVE_BINDIR=""

# Internal: echo the bin dir for a version if valid
_mysql_bindir_for() {
  local v="$1"
  local root="$COMPONENTS/Mysql/$v/Core/bin"
  if [[ -x "$root/mysql" && -x "$root/mysqld" ]]; then
    print -r -- "$root"
    return 0
  fi
  return 1
}

# List ONLY valid versions
mysql_versions() {
  local d v
  [[ -d "$COMPONENTS/Mysql" ]] || { echo "No Mysql components at $COMPONENTS/Mysql"; return 0; }
  for d in "$COMPONENTS/Mysql"/*; do
    [[ -d "$d" ]] || continue
    v="${d:t}"
    _mysql_bindir_for "$v" >/dev/null && echo "$v"
  done | sort -V
}

# Remove previously added mysql bin dir from PATH
mysql_clear_path() {
  [[ -n "$_MYSQL_ACTIVE_BINDIR" ]] || return 0
  path=(${^path:#$_MYSQL_ACTIVE_BINDIR})
  _MYSQL_ACTIVE_BINDIR=""
}

# Switch PATH to the given mysql version
use_mysql() {
  local v="${1:-$DEFAULT_MYSQL}" bindir
  if [[ -z "$v" ]]; then
    echo "Usage: use_mysql <version>   (tip: mysql_versions to list)"
    return 1
  fi
  if ! bindir="$(_mysql_bindir_for "$v")"; then
    echo "❌ MySQL $v not found or invalid (need Core/bin with mysql & mysqld)."
    mysql_versions
    return 1
  fi

  mysql_clear_path
  path+=("$bindir")
  _MYSQL_ACTIVE_BINDIR="$bindir"

  echo "➡️ Using MySQL $v ($bindir)"
  command -v mysql >/dev/null && mysql --version
}

# Start MySQL server with its Conf/Data/Log dirs
mysql_start() {
  local v="${1:-$DEFAULT_MYSQL}" bindir root conf datadir logdir
  if ! bindir="$(_mysql_bindir_for "$v")"; then
    echo "MySQL $v not found"; return 1
  fi
  root="$COMPONENTS/Mysql/$v"
  conf="$root/Conf/my.cnf"
  datadir="$root/Data"
  logdir="$root/Log"

  [[ -d "$datadir" ]] || mkdir -p "$datadir"
  [[ -d "$logdir" ]]  || mkdir -p "$logdir"

  if [[ -f "$conf" ]]; then
    "$bindir/mysqld" --defaults-file="$conf" --datadir="$datadir" --log-error="$logdir/error.log" &
  else
    "$bindir/mysqld" --datadir="$datadir" --log-error="$logdir/error.log" &
  fi
  echo "Started MySQL $v"
}

# Stop MySQL server
mysql_stop() {
  pkill -f mysqld || echo "No mysqld found"
}

# Run mysql client (defaults to current version)
mysql_cli() {
  local v="${1:-$DEFAULT_MYSQL}" bindir
  if ! bindir="$(_mysql_bindir_for "$v")"; then
    echo "MySQL $v not found"; return 1
  fi
  "$bindir/mysql" "$@"
}

# Convenience: show which mysql is active
mysql_current() {
  if command -v mysql >/dev/null 2>&1; then
    echo "mysql -> $(command -v mysql)"
  else
    echo "mysql not on PATH"
  fi
  if command -v mysqld >/dev/null 2>&1; then
    echo "mysqld -> $(command -v mysqld)"
  else
    echo "mysqld not on PATH"
  fi
}

# Auto-load the default if valid
if _mysql_bindir_for "$DEFAULT_MYSQL" >/dev/null; then
  use_mysql "$DEFAULT_MYSQL" >/dev/null
fi

# ---------------------------------------------------------------------
# 75) Python (portable)
# ---------------------------------------------------------------------