# --- default help module -----------------------------------------------------
_devhelp_default() {

cat <<-'EOF'
Developer Help — General Cheatsheet
==================================

# Navigation & Search
z <fragment>           # zoxide jump (fast cd)
Ctrl-R                 # fzf history search (if fzf installed)

# Search / Grep
rg -n <pat>            # ripgrep (respects .gitignore, very fast)
grep -nr <pat> .       # portable fallback (always available)
find . -type f         # portable file listing (fallback to fd)

# Listing
ls / ll / la / lt      # eza-enhanced ls (if ENABLE_EZA=true)
catn / batp            # bat wrappers (numbers / pager)

# Env Management
direnv allow           # load .envrc in current dir
eval "$(toolup)"       # activate versions per .toolsrc

# Ant / Protobuf
use_ant <ver>          # sets ANT_HOME, appends PATH, confirms
use_protoc <ver>       # sets PROTOBUF_HOME, appends PATH, confirms

# Python / Go / Node (portable)
python_versions        # ~/Components/Python
use_python <ver>       # append PATH, confirm python3 --version
go_versions            # ~/Components/Golang
use_golang <ver>       # set GOROOT, append PATH, confirm
node_versions          # ~/Components/Node
use_node <ver>         # set NODE_HOME, append PATH, confirm

# Git sync helpers
syncm                  # stash, checkout master, fetch, pull --rebase
syncc                  # stash, pull --rebase current branch, stash pop
syncs                  # stash, update master, rebase current, stash pop

# Secrets helper
load_secrets           # source ~/.secrets
show_secret KEY        # print value from ~/.secrets

# Misc
mkbin                  # create .bin in repo and add to PATH

What's next?
------------
• devhelp tmux   → multiplexer & workflow
• devhelp jdk    → jdk basics
• devhelp git    → version control
• devhelp mysql  → database basics
• devhelp redis  → cache basics
EOF
}

_devhelp_register "default" _devhelp_default