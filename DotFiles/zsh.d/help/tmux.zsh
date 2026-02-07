# --- tmux help module --------------------------------------------------------
_devhelp_tmux() {
  cat <<'EOF'
Tmux — quick reference
======================

Configuration:
  ~/.config/tmux/tmux.conf

Shell Helpers (Aliases):
  tm <name>     # Smart attach: join session <name> or create it (def: main)
  tl            # List sessions
  tk <name>     # Kill session <name>
  tka           # Kill ALL sessions

Inside Tmux:
  tms           # Split Verify (Top/Bottom)
  tml           # Split Horiz (Left/Right)

Keybindings (Prefix: C-b):
  C-b d         # Detach
  C-b s         # Choose session (tree view)
  C-b c         # New window
  C-b ,         # Rename window
  C-b %         # Split vertical (standard)
  C-b "         # Split horizontal (standard)
  C-b z         # Zoom pane
EOF
}
_devhelp_register "tmux" _devhelp_tmux
