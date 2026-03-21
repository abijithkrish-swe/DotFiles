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
use_ant <ver>          # Ant (sets ANT_HOME)
use_maven <ver>        # Maven (sets M2_HOME, MAVEN_HOME)
use_protoc <ver>       # Protobuf (sets PATH)
use_python <ver>       # Python (sets PATH)
use_go <ver>           # Go (sets GOROOT, PATH)
use_node <ver>         # Node (sets PATH)
use_jdk <ver>          # JDK (sets JAVA_HOME, PATH)
use_redis <ver>        # Redis (sets PATH) [Service: redis_start/stop]
use_mysql <ver>        # MySQL (sets PATH) [Service: mysql_start/stop]

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
