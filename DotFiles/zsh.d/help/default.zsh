# --- default help module -----------------------------------------------------
_devhelp_default() {

cat <<-'EOF'
Developer Help — General Cheatsheet
==================================

# Navigation & Search
z <fragment>           # zoxide jump (fast cd)
Ctrl-R                 # fzf history search (if fzf installed)
f <pat>                # fd (general find) - see 'devhelp fd'

# Listing
ls / ll / la           # eza wrappers (modern ls) - see 'devhelp eza'
catn / batp            # bat wrappers (numbers / pager) - see 'devhelp bat'

# Dev Components (Standard API: list, use, start, stop, clear)
-------------------------------------------------------------
# Only versions in the components manifest; [ver] = exact or prefix, none = default
use_ant [ver]          # Ant (sets ANT_HOME)
use_maven [ver]        # Maven (sets M2_HOME, MAVEN_HOME)
use_protoc [ver]       # Protobuf (sets PATH)
use_python [ver]       # Python (sets PATH)
use_go [ver]           # Go (sets GOROOT, PATH)
use_node [ver]         # Node (sets PATH)
use_jdk [ver]          # JDK (sets JAVA_HOME, PATH)
use_redis [ver]        # Redis (sets PATH) [Service: redis_start/stop]
use_mysql [ver]        # MySQL (sets PATH) [Service: mysql_start/stop]
use_gradle [ver]       # Gradle (sets GRADLE_HOME)
use_rust [ver]         # Rust (sets PATH) - see 'devhelp rust'
components_check       # approved versions + health - see 'devhelp components'
toolup                 # apply .toolsrc in current dir

# AI agents: run projects via toolshelf - see 'devhelp toolshelf'
-------------------------------------------------------------
# Agents build/test with the toolshelf `run` tool; you just ask in plain words.
#   sandbox (default)  your ~/Components tools; writes: project only; net: proxy only
#   docker             untrusted code; pinned image, project only, no net unless "proxy"
"Run the tests in ~/Projects/x with JDK 17"            # → sandbox
"This repo is untrusted, run its tests in docker"      # → docker (needs: costart)
components_images      # docker-mode images: pulled? size; 'prune' retired ones
components_requests    # versions agents asked for (they never install)
toolshelf_report [d]   # what agents ran, failed, or got blocked (last d days)
# Yourself: try untrusted code in a throwaway container (current folder = /work)
dockrun node=22 'npm ci && npm test'    # no network; quote compound commands
dockrun --net python 'pip install -r requirements.txt && pytest'   # proxy-only net
dockrun --internet -p 8080 node 'npx serve -l 8080'   # UI on 127.0.0.1:8080
dockrun python         # no command = a shell inside; -n = print docker cmds

# Observability: self-hosted SigNoz (local) - see 'devhelp observability'
obs_start / obs_status / obs_stop     # UI http://localhost:8080, OTLP :4317/:4318

# Git sync helpers
syncm                  # stash, checkout master, fetch, pull --rebase
syncc                  # stash, pull --rebase current branch, stash pop
syncs                  # stash, update master, rebase current, stash pop

# Vault (Secrets) - see 'devhelp secrets' or 'DotFiles/SECRETS.md'
vault_load             # import secrets.env
add_secret             # add new key
show_secret KEY        # show key
vault_ls               # list keys

# Env Management
direnv allow           # load .envrc in current dir

EOF
}

_devhelp_register "default" _devhelp_default
