# 4 ) NAVIGATION & SEARCH

# zoxide (smart cd)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# fzf (fuzzy finder, Ctrl-R etc.)
if command -v fzf >/dev/null 2>&1; then
  # Prefer config files under ~/.config/fzf/
  [ -f ~/.config/fzf/fzf.zsh ] && source ~/.config/fzf/fzf.zsh
  [ -f ~/.config/fzf/fzf.bash ] && source ~/.config/fzf/fzf.bash

  # Default behavior: list files with ripgrep (hidden, follows symlinks)
  export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
  export FZF_CTRL_R_OPTS="--sort --exact"

  # Tmux integration (if inside tmux)
  export FZF_TMUX=1
  export FZF_TMUX_HEIGHT="70%"

  # Optional preview with bat (toggle with ENABLE_FZF_PREVIEW=true)
  if [[ "${ENABLE_FZF_PREVIEW}" == "true" ]]; then
    export FZF_DEFAULT_OPTS="--preview 'bat --style=numbers --color=always {} | head -200' --preview-window=right:60%:wrap"
  fi
fi


# direnv hook (optional; no effect unless direnv installed)
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# ---------------------------------------------------------------------
# 41) eza (ls replacement)
# ---------------------------------------------------------------------