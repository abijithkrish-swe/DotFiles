# 4 ) NAVIGATION & SEARCH

# zoxide (smart cd)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# direnv hook (optional; no effect unless direnv installed)
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# ---------------------------------------------------------------------
# 41) eza (ls replacement)
# ---------------------------------------------------------------------