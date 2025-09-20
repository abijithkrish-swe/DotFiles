# --- fzf help: Basics (with functions) --------------------------------------
# Place in: ~/.zsh.d/help/fzf-basic.zsh

_devhelp_fzf_basic() {
  cat <<'EOF'
fzf — Basics
============
Mental model:
  fzf reads a list from stdin, lets you fuzzy-filter, and prints your selection.
  No daemons. It only runs when you call it.

Toggles:
  ENABLE_FZF_BASICS=true   # enables basic helper functions (no keybinding changes)

Functions (enabled by ENABLE_FZF_BASICS):
  fvim        Pick a file and open in Vim
              Usage: fvim
              Flow:  type part of filename → Enter → opens in Vim
              Impl:  local f; f="$(fzf)" || return; vim -- "$f"

  fpath       Pick a file and print absolute path (useful for scripts)
              Usage: fpath
              Impl:  realpath "$f" (falls back to "$PWD/$f" if realpath missing)

  fhcopy      Pick a command from history and copy to clipboard
              Usage: fhcopy
              Notes: Uses pbcopy/wl-copy/xclip when available; otherwise prints to stdout.

Ad‑hoc one‑liners (no functions needed):

  Pick a file → open in Vim
    vim "$(fzf)"
    # Example: type part of the filename, press Enter

  List ONLY git‑tracked files
    git ls-files | fzf
    # Example: git ls-files | fzf | xargs -r -o vim

  Filter processes → choose PID
    ps aux | fzf | awk '{print $2}' | xargs -r echo
    # Replace 'echo' with 'kill -9' once you confirm

  Search text in files (ripgrep) → open match in Vim
    rg -n "" | fzf | awk -F: '{print "+"$2" "$1}' | xargs -r -o vim
    # Example: rg -n "TODO" | fzf | awk -F: '{print "+"$2" "$1}' | xargs -r -o vim

Recommended defaults (safe; no keybinding changes):
  export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
  # Optional UI:
  # export FZF_DEFAULT_OPTS="--height=70% --reverse --border"
EOF
}

_devhelp_register "fzf" _devhelp_fzf_basic
