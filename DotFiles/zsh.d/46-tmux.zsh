# 46) tmux (helpers, optional)
# Install: brew install tmux
# Helpers to quickly manage sessions and panes.

export ENABLE_TMUX=true   # flip to true to enable

if [[ "$ENABLE_TMUX" == "true" ]] && command -v tmux >/dev/null 2>&1; then
  
  # ensure tmux reads config from ~/.config/tmux
  if [ -f "$HOME/.config/tmux/tmux.conf" ]; then
    export TMUX_CONF="$HOME/.config/tmux/tmux.conf"
  fi

  # Start or attach to session (default: "main")
  tm() { tmux new -As "${1:-main}"; }

  # Vertical split
  tms() { tmux split-window -v; tmux select-layout tiled; }

  # Horizontal split
  tml() { tmux split-window -h; tmux select-layout tiled; }
fi

# ---------------------------------------------------------------------
# 50) history settings
# ---------------------------------------------------------------------