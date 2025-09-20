# --- redis help module -------------------------------------------------------
_devhelp_redis() {
cat <<'EOF'
Redis — Quick Reference
=======================

Your portable layout (per version)
----------------------------------
~/Components/Redis/<VER>/
  ├─ bin/         # redis-server, redis-cli
  ├─ redis.conf   # optional (you can keep per-version)
  └─ data/        # if you keep persistence AOF/RDB here

Helper commands (from your zsh modules)
---------------------------------------
redis_versions           # list installed versions under ~/Components/Redis
use_redis <ver>          # append that version's bin/ to PATH (session only)
rstart <ver> [conf]      # start redis-server (uses redis.conf if present)
rcli   [ver] [args...]   # redis-cli (uses default or specific version)
rstop                    # stop all redis-server PIDs owned by you

redis-cli quickies
------------------
redis-cli PING
redis-cli INFO memory | head -n 20
redis-cli MONITOR                    # live stream (dev only)
redis-cli KEYS 'prefix:*'            # beware on prod; prefer SCAN
redis-cli --cluster help             # cluster subcommands

Config flags you often tweak
----------------------------
• port 6379
• dir ./data
• dbfilename dump.rdb
• appendonly yes        # AOF on (dev)
• save ""               # disable RDB snapshots (if AOF only)
• maxmemory 1gb
• maxmemory-policy allkeys-lru

Troubleshooting
---------------
• Port busy: lsof -i :6379 | awk 'NR>1{print $2}' | xargs kill -9
• Persistence folder perms: ensure 'dir' exists and writable
• Large KEYS commands: use SCAN 0 MATCH 'pat:*' COUNT 1000
EOF
}

_devhelp_register "redis" _devhelp_redis
# (optional) alias in your zshrc: alias redishelp='devhelp redis'