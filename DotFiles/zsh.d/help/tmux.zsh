# --- tmux help module --------------------------------------------------------
_devhelp_tmux() {
  cat <<'EOF'
Tmux — quick reference
======================
Shell helpers (outside tmux):
  tm <name>     # new OR attach session <name> (default: main)
  tl            # list sessions
  tk <name>     # kill a session
  tka           # kill all sessions (asks confirm; keeps current if inside tmux)

Sessions (inside tmux):
  C-b d         # detach
  C-b s         # session chooser

Windows:
  C-b c         # new window
  C-b ,         # rename window
  C-b w         # list windows
  C-b l         # last window
  C-b x         # kill pane/window (confirm)

Panes:
  C-b %         # vertical split
  C-b "         # horizontal split
  C-b q         # show pane numbers, then press number to jump
  C-b ←/→/↑/↓   # move between panes
  C-b { / }     # swap panes left/right

Copy mode (vi):
  C-b [         # enter copy mode
   Space        # start selection
   Enter        # copy selection
   q / Esc      # cancel/exit
  C-b ]         # paste

Misc:
  C-b :         # tmux command prompt
  Reload config: C-b :source-file ~/.tmux.conf
EOF
}

# Register topic names
_devhelp_register "tmux" _devhelp_tmux
_devhelp_register "tm"   _devhelp_tmux