# 43) fd (modern find, optional)
# Install: brew install fd
# fd is a simpler, faster alternative to find.

export ENABLE_FD=false   # flip to true to enable

if [[ "$ENABLE_FD" == "true" ]] && command -v fd >/dev/null 2>&1; then
  alias fdf='fd --type f'   # find files
  alias fdd='fd --type d'   # find directories
fi

# ---------------------------------------------------------------------
# 46) tmux (helpers, optional)
# ---------------------------------------------------------------------