# --- fzf help: Intermediate (with functions) --------------------------------
# Place in: ~/.zsh.d/help/fzf-intermediate.zsh

_devhelp_fzf_intermediate() {
  cat <<'EOF'
fzf — Intermediate
==================
Toggles:
  ENABLE_FZF_INTERMEDIATE=true   # nicer UI + directory & ripgrep helpers
  ENABLE_FZF_PREVIEW=true        # enable preview pane with 'bat' (optional)

Functions (enabled by ENABLE_FZF_INTERMEDIATE):
  fcd         Fuzzy-pick a directory and cd into it
              Usage: fcd
              Search: uses 'fd --hidden --type d --follow --exclude .git' when available,
                      otherwise falls back to 'find . -type d -not -path "*/.git/*"'.

  frg         ripgrep search → fuzzy-pick match → open in Vim at the line
              Usage: frg "pattern"
              Examples:
                frg Exception
                frg "TODO|FIXME"

UI tweaks you can enable (optional):
  export FZF_DEFAULT_OPTS="--height=70% --reverse --border"

Preview pane (optional; needs bat):
  export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --preview 'bat --style=numbers --color=always {} | head -200' --preview-window=right:60%:wrap"

Ad‑hoc recipes:
  Pick a directory then cd:
    (fd --hidden --type d --follow --exclude .git || find . -type d -not -path "*/.git/*") | fzf | xargs -r -I{} bash -lc 'cd "{}"; $SHELL'

  ripgrep → pick → open at line:
    rg -n --hidden --follow --glob '!.git' "term" | fzf | awk -F: '{print "+"$2" "$1}' | xargs -r -o vim

Tmux integration (open fzf in a popup area automatically when inside tmux):
  export FZF_TMUX=1
  export FZF_TMUX_HEIGHT="70%"
EOF
}

_devhelp_register "fzf-int" _devhelp_fzf_intermediate
