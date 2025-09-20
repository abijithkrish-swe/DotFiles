# --- vim help module (Advanced) ---------------------------------------------
# Place in: ~/.zsh.d/help/vim-advanced.zsh

_devhelp_vim_advanced() {
  cat <<'EOF'
Vim — advanced reference
========================

Windows / Splits:
  :sp / :vsp        → split horizontally / vertically
  Ctrl-w h/j/k/l    → move between splits
  Ctrl-w =          → equalize sizes
  :close            → close current split
  :only             → close all other splits

Tabs & Buffers:
  :e file           → open file in current buffer
  :bnext / :bprev   → next / previous buffer
  :ls               → list buffers
  :tabnew file      → open in new tab
  gt / gT           → next / previous tab

Marks:
  m{a-z}            → set mark
  '{a-z}            → jump to line of mark
  `'{a-z}           → jump to exact position of mark
  `` / ''           → jump back to previous location

Registers & Macros:
  \"ayy / \"ap        → yank line to register a / paste from a
  q{a-z}            → start recording macro in register
  q                 → stop recording
  @{a-z} / @@       → play macro / replay last macro

Text Objects (super useful):
  ciw / diw         → change / delete inner word
  ci\" / di\"         → change / delete inside quotes
  ci( / di(         → inside parentheses (same for [ { <)
  va\" / vi\"         → visual around / inside quotes

Searching & Replacing:
  :%s/foo/bar/g     → replace all
  :%s/foo/bar/gc    → confirm each
  :%s/\\<old\\>/new/g → whole-word replace
  :noh              → clear search highlight

Indent / Format:
  =                 → reindent selection (use in visual mode)
  gg=G              → reindent entire file
  gwip              → reflow paragraph (format)

Navigation boosts:
  } / {             → next / previous paragraph or block
  Ctrl-o / Ctrl-i   → jump back / forward in jump list
  * / #             → search word under cursor forward/backward

Visual Block tricks:
  Ctrl-v, select, then:
   I<text> ESC      → insert <text> at start of each selected line
   A<text> ESC      → append <text> at end of each selected line

Sessions / Projects:
  :mksession! sess.vim  → save session
  :source sess.vim      → load session

Write with sudo (when opened read-only):
  :w !sudo tee %        → save current file using sudo

Tips:
  • Learn one new text object each week (ciw, ci\", ci( are game-changers).
  • Combine operators + motions + counts: e.g., 3dw (delete 3 words), 5j (down 5 lines).
  • Use macros for repetitive edits (qa … q, then @a).
EOF
}

# Register topic names
_devhelp_register "vim-adv" _devhelp_vim_advanced
_devhelp_register "vim-advanced" _devhelp_vim_advanced
