# --- redis help module -------------------------------------------------------
_devhelp_redis() {
cat <<'EOF'
Redis — Quick Reference
=======================

Helper commands (Standard)
---------------------------------------
redis_list               # approved versions (from the components manifest)
use_redis [ver]          # switch to version (prefix ok: 7 → 7.4.5; none = default)
redis_clear              # remove Redis from PATH

Service Control
---------------------------------------
redis_start [ver]        # start redis-server (approved versions; default if omitted)
redis_stop               # stop all redis-server processes owned by you
redis_init_conf <ver>    # initialize Conf/redis.conf (disk save disabled)

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
  ├─ src/ or bin/       # redis-server, redis-cli
  └─ Conf/
      └─ redis.conf    # version-specific config (disk save disabled by default)

Not started or put on PATH at login — run use_redis or redis_start when needed.

Configuration
---------------------------------------
1. First install: redis_init_conf <ver>
   Creates Conf/redis.conf with disk save DISABLED

2. To enable disk save:
   Edit Conf/redis.conf and uncomment the 'save' directives
   
3. Run: redis_start <ver>
   Will use Conf/redis.conf if present, else in-memory-only mode
EOF
}

_devhelp_register "redis" _devhelp_redis
