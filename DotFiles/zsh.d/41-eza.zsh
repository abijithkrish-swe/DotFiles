# 41) eza (modern ls) — optional
# Install: brew install eza
export ENABLE_EZA=true   # flip to false to disable

if [[ "$ENABLE_EZA" == "true" ]] && command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lh --group-directories-first'   # long, human sizes
  alias la='eza -lha --group-directories-first'  # all files
  alias lt='eza -lT --level=2'                   # tree, 2 levels
fi

# ---------------------------------------------------------------------
# 42) bat (pretty cat, optional)
# ---------------------------------------------------------------------