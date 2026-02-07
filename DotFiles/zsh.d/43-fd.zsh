# 43) fd (modern find) — optional
# https://github.com/sharkdp/fd
# Install: brew install fd

export ENABLE_FD=true   # flip to false to disable

if [[ "$ENABLE_FD" == "true" ]] && (( $+commands[fd] )); then
  
  # Basic aliases (The user specifically requested fdf/fdd)
  alias f='fd'
  alias fdf='fd --type f'   # find files
  alias fdd='fd --type d'   # find directories

  # Extended aliases
  alias fdh='fd -H'      # find including hidden
  alias fde='fd -e'      # find by extension (usage: fde py)
  alias fdg='fd -g'      # find by glob (default anyway)
  
  # Integration: Make fd colorful relative to terminal
  export FD_OPTIONS="--follow --exclude .git"

  # Find and delete (careful!)
  # usage: fd_rm <pattern>
  fd_rm() {
      print -P "%B%F{red}Deleting files matching: $*%f%b"
      echo "Press [Enter] to confirm, [Ctrl-C] to cancel..."
      read
      fd -H --no-ignore "$@" -X rm -rf
  }
fi
