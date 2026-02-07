# 60) aliases

# Directory movement
alias ..='cd ..'
alias ...='cd ../..'

# Listing
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

# Processes
alias psa='ps aux'

# sudo helper
alias please='sudo $(fc -ln -1)'

# Git quality-of-life
alias gs='git status -sb'
alias ga='git add'
alias gcm='git commit -m'
alias gc='git checkout'
alias gp='git push'
alias gl='git log --oneline --graph --decorate --all'
alias undo='git reset --soft HEAD~1'
alias unpushed='git log @{u}..'

# ---------------------------------------------------------------------
# 61) Aliases Extras
# ---------------------------------------------------------------------