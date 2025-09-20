# 70) components core & toolup

# Base folder for all portable tools
export COMPONENTS="$HOME/Components"

# Reset PATH to baseline (used by toolup)
_path_base() {
  if [ -d "/opt/homebrew/bin" ]; then
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
  fi
  export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
  
  if [ -d "/opt/homebrew/opt/mysql-client/bin" ]; then
    export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"
  fi
}

# toolup — reads .toolsrc to set versions
toolup() {
  local cfg=".toolsrc"
  [[ ! -f "$cfg" ]] && { echo "No $cfg in $(pwd)"; return 1; }
  _path_base
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    key="${line%%=*}"; val="${line#*=}"
    case "$key" in
      JDK) jdk "$val" ;;
      REDIS) use_redis "$val" ;;
      ANT) [[ -n "$val" ]] && use_ant "$val" ;;
      PROTOBUF) [[ -n "$val" ]] && use_protoc "$val" ;;
      MYSQL_DEFAULT_VER) mysql_set_default "$val" ;;
      MYSQL_START_VER) mysql_start "$val" ;;
      MYSQL_STOP_VER) mysql_stop "$val" ;;
      PATH_PREPEND) export PATH="$val:$PATH" ;;
      EXPORT) eval "export ${val}" ;;
      *) echo "Unknown directive in .toolsrc: $key" ;;
    esac
  done < "$cfg"
  echo "Activated from $cfg"
  echo "JAVA_HOME=${JAVA_HOME:-<unset>}"
}

# mkbin — create a .bin dir in repo and prepend PATH
mkbin() {
  mkdir -p .bin
  export PATH="$PWD/.bin:$PATH"
  echo "Using .bin at $PWD/.bin"
}

# ---------------------------------------------------------------------
# 71) JDK helpers
# ---------------------------------------------------------------------