# 41) eza (modern ls) — optional
# Install: brew install eza
export ENABLE_EZA=true   # flip to false to disable

if [[ "$ENABLE_EZA" == "true" ]] && command -v eza >/dev/null 2>&1; then
  # --- eza aliases (without overriding ls) ---

  # Standard alphabetical (closer to prod `ls`)
  alias ll='eza -lh'            # long, human sizes
  alias la='eza -lha'           # all files
  alias lg='eza -lh --git'      # long, human + git status
  alias lt='eza -T --level=2'   # tree view (compact, 2 levels)

  # "Dirs first" variants (convenience, like GUI file browsers)
  alias lld='eza -lh --group-directories-first'
  alias lad='eza -lha --group-directories-first'
  alias lgd='eza -lh --git --group-directories-first'
  alias ltd='eza -T --level=2 --group-directories-first'

  # Optional: icons (only if Nerd Fonts render correctly)
  alias lsi='eza -lha --icons --group-directories-first'
fi

# ---------------------------------------------------------------------
# 42) bat (pretty cat, optional)
# ---------------------------------------------------------------------