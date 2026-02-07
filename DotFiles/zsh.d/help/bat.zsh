# --- bat help module --------------------------------------------------------
_devhelp_bat() {
  cat <<'EOF'
bat — quick reference
=====================

Aliases:
  cat  → bat -p            # Safe pager (like cat but paging supported)
  batp → bat --style=plain # Copy-paste friendly (no line numbers/grid)
  batn → bat --style=numbers
  batt → bat --style=numbers,changes

Features:
  • Replaces `man` pager automatically (syntax highlighted man pages).
  • Highlights `--help` output: `git commit --help`.

Theme:
  BAT_THEME="TwoDark"
EOF
}
_devhelp_register "bat" _devhelp_bat
