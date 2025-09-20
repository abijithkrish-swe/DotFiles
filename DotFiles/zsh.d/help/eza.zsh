# --- eza help module --------------------------------------------------------
# Place in: ~/.zsh.d/help/eza.zsh

_devhelp_eza() {
  cat <<'EOF'
eza — quick reference
=====================

Standard alphabetical (closer to prod `ls`):
  ll   → eza -lh              # long, human sizes
  la   → eza -lha             # all files
  lg   → eza -lh --git        # long, human + git status
  lt   → eza -T --level=2     # tree view (compact, 2 levels)

"Dirs first" variants (like GUI file browsers):
  lld  → eza -lh --group-directories-first
  lad  → eza -lha --group-directories-first
  lgd  → eza -lh --git --group-directories-first
  ltd  → eza -T --level=2 --group-directories-first

Optional (requires Nerd Fonts):
  lsi  → eza -lha --icons --group-directories-first

Tips:
  • Keep `ll`, `la`, `lg`, `lt` for muscle memory (closer to `ls` on prod).
  • Use the `d` variants when you want directories grouped first.
  • Add `--git` when working inside repos for status indicators.
EOF
}

# Register topic name
_devhelp_register "eza" _devhelp_eza