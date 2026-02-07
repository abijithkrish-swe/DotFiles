# --- eza help module --------------------------------------------------------
_devhelp_eza() {
  cat <<'EOF'
eza — quick reference
=====================

Standard Aliases (replacing ls):
  ls   → eza --icons --git
  ll   → eza -l --icons --git --header
  la   → eza -la --icons --git --header
  lt   → eza --tree --level=2

Sorted Views:
  lS   → ll --sort=size       # Largest first
  lm   → ll --sort=modified   # Newest first

Note: All aliases use `--group-directories-first` by default.

Tree Views:
  lt   → 2 levels deep
  ltt  → 3 levels deep

Tips:
  • `eza` respects .gitignore if `--git` is passed (default in `ls` alias).
  • Use `\ls` to bypass eza and use standard ls.
EOF
}
_devhelp_register "eza" _devhelp_eza
