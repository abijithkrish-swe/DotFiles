# --- redis help module -------------------------------------------------------
_devhelp_redis() {
cat <<'EOF'
Redis — Quick Reference
=======================

Helper commands (Standard)
---------------------------------------
redis_list               # list installed versions under ~/Components/Redis
use_redis <ver>          # switch to version (append bin/ to PATH)
redis_clear              # remove Redis from PATH

Service Control
---------------------------------------
redis_start [ver]        # start redis-server (uses redis.conf if present)
redis_stop               # stop all redis-server processes owned by you

Aliases
-------
redis_versions -> redis_list
redis_use      -> use_redis (legacy)
rstart         -> redis_start
rstop          -> redis_stop
rcli           -> redis-cli

Layout
---------------------------------------
~/Components/Redis/<VER>/
  ├─ bin/         # redis-server, redis-cli
  ├─ redis.conf   # optional config
EOF
}

_devhelp_register "redis" _devhelp_redis
