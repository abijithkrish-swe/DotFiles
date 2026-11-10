# 46) tmux (helpers) — optional
# Install: brew install tmux

export ENABLE_TMUX=true

if [[ "$ENABLE_TMUX" == "true" ]] && (( $+commands[tmux] )); then

  # 1. Alias to force config path (XDG standard)
  # Newer tmux versions check ~/.config/tmux/tmux.conf by default, but this ensures it.
  if [[ -f "$HOME/.config/tmux/tmux.conf" ]]; then
     alias tmux='tmux -f "$HOME/.config/tmux/tmux.conf"'
  fi
  
  # 2. Smart Session Manager
  # Usage: tm [name]
  # - If 'name' session exists: attach to it.
  # - If not: create new session 'name'.
  # - If no name provided: attach to 'main' or create it.
  tm() {
      [[ -n "$TMUX" ]] && { echo "Already in tmux."; return; }
      local name="${1:-main}"
      tmux new-session -A -s "$name"
  }

  # 3. Helpers
  alias tl='tmux list-sessions'
  alias tk='tmux kill-session -t'
  alias tka='tmux kill-server' # Kill all
  
  # 4. Split helpers (inside tmux)
  alias tms='tmux split-window -v'
  alias tml='tmux split-window -h'

  # 5. tmux tools (tmux-check, tmux-snapshot), deployed from DotFiles/config/tmux/bin
  # Appended (low priority), so nothing in it can shadow a system command.
  [[ -d "$HOME/.config/tmux/bin" ]] && path+=("$HOME/.config/tmux/bin")
fi
