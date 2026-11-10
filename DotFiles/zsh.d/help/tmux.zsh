# --- tmux help module --------------------------------------------------------
_devhelp_tmux() {
  cat <<'EOF'
Tmux — quick reference
======================

Configuration:
  ~/.config/tmux/tmux.conf       (source: DotFiles/config/tmux/tmux.conf)

Shell Helpers (Aliases):
  tm <name>     # Smart attach: join session <name> or create it (def: main)
  tl            # List sessions
  tk <name>     # Kill session <name>
  tka           # Kill ALL sessions

Inside Tmux:
  tms           # Split vertical (top/bottom)
  tml           # Split horizontal (left/right)

Keybindings (Prefix: C-b):
  C-b d         # Detach
  C-b s         # Choose session (tree view)
  C-b Tab       # Last session (L is taken by resize)
  C-b c         # New window, in the current pane's folder
  C-b ,         # Rename window
  C-b %  C-b "  # Split, in the current pane's folder
  C-b z         # Zoom pane
  C-b H/J/K/L   # Resize pane (repeatable)
  C-b S         # Toggle synchronized panes
  C-b r         # Reload tmux.conf

Copy mode (vi keys; copies go to the macOS clipboard):
  C-b [         # Enter copy mode
  v / Space     # Start selection
  y / Enter     # Copy and exit
  mouse drag    # Copy, stay where you were (q to leave)

Windows renumber when one closes (1 2 3 → close 2 → 1 2).

Tools (~/.config/tmux/bin, on PATH):
  tmux-check            # Does the running server match tmux.conf? ✓/✗ + fixes.
                        #   tmux reads the file only at start, and C-b r never
                        #   undoes a deleted line, so they can drift.
  tmux-check -L name    # Check another server (tmux -L name)
  tmux-snapshot         # Save sessions, windows, folders and Claude conversations
                        #   (any Claude config, e.g. myclaude) to a restore script.
                        #   Keeps the newest 5 (TMUX_SNAPSHOT_KEEP).
  tmux-snapshot list    # List saved snapshots
  zsh ~/.local/state/tmux-snapshots/latest.zsh
                        # Restore: recreates missing sessions only, types
                        #   `claude --resume <id>` where Claude was running.
EOF
}
_devhelp_register "tmux" _devhelp_tmux
