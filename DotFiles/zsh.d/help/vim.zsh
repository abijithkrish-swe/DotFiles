# --- vim help module (Basics) -----------------------------------------------
# Place in: ~/.zsh.d/help/vim.zsh

_devhelp_vim_basic() {
  cat <<'EOF'
Vim / Vi — quick reference (Basics)
===================================

Modes:
  i           → Insert mode
  ESC         → Normal mode
  v / V       → Visual (char/line)
  Ctrl-v      → Visual block

Movement:
  h j k l     → left/down/up/right
  0 / ^ / $   → line start / first non-space / end
  w / e / b   → next word / word end / prev word
  gg / G      → top / bottom of file
  H / M / L   → top/middle/bottom of screen
  f<char>     → find char on line (to the right), F<char> to the left
  t<char>     → till char (stops before), T<char> to the left
  Ctrl-d / Ctrl-u → half-page down / up

Editing (Normal mode):
  x           → delete char
  dw / de     → delete to next word / word end
  dd / D      → delete line / to end of line
  cw / ciw    → change word / change inner word
  cc          → change whole line
  r<char>     → replace one char with <char>
  u / Ctrl-r  → undo / redo
  .           → repeat last change

Yank/Paste:
  yy / yw     → yank line / yank word
  p / P       → paste after / before

Search:
  /text       → forward search
  ?text       → backward search
  n / N       → next / previous match
  * / #       → search word under cursor forward/backward

Save/Quit:
  :w          → write (save)
  :q          → quit
  :wq / ZZ    → save & quit
  :q!         → quit without saving

Visual mode:
  v / V / Ctrl-v → start visual (char/line/block)
  y / d / c      → yank / delete / change selection
  > / <          → indent / unindent

Notes:
  • Operators + motions = power (e.g., daw = delete a word; ci\" = change inside quotes).
  • Most of these motions also work in Zsh vi-mode (enable with: bindkey -v).
EOF
}

# Register topic names
_devhelp_register "vim" _devhelp_vim_basic
_devhelp_register "vi"  _devhelp_vim_basic
