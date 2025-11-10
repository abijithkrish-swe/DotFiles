# 79) defaults at login
# Core tools you want always available:
export DEFAULT_JDK=11
export DEFAULT_MYSQL_CLIENT=8.0.43
export DEFAULT_REDIS=7.4.5

# Optional tools — recorded only (not auto-applied):
export DEFAULT_ANT=1.10
export DEFAULT_PROTOBUF=3.0
# export DEFAULT_GO=1.22.0
export NODE_DEFAULT_VERSION="20.19.5"
# export DEFAULT_PYTHON=3.11.6

export COLIMA_HOME="$HOME/.config/colima"
# XDG for Docker
export DOCKER_CONFIG="$HOME/.config/docker"   # -> ~/.config/docker

# Apply only for interactive shells
case $- in
  *i*)
    # --- JDK ---
    if typeset -f jdk >/dev/null 2>&1 && [[ -n "$DEFAULT_JDK" ]]; then
      jdk "$DEFAULT_JDK" >/dev/null 2>&1 || echo "Note: JDK $DEFAULT_JDK not found"
    fi

    # --- MySQL client (adds to PATH; does NOT start server) ---
    if typeset -f mysql_set_default >/dev/null 2>&1 && [[ -n "$DEFAULT_MYSQL_CLIENT" ]]; then
      mysql_set_default "$DEFAULT_MYSQL_CLIENT" >/dev/null 2>&1 || echo "Note: MySQL $DEFAULT_MYSQL_CLIENT not found"
    fi

    # --- Redis client (adds to PATH; does NOT start server) ---
    if typeset -f use_redis >/dev/null 2>&1 && [[ -n "$DEFAULT_REDIS" ]]; then
      use_redis "$DEFAULT_REDIS" >/dev/null 2>&1 || echo "Note: Redis $DEFAULT_REDIS not found"
    fi
  ;;
esac

# ---------------------------------------------------------------------
# 80) completions
# ---------------------------------------------------------------------