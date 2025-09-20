# ---------------------------------------------------------------------
# 44-fzf.zsh — Fuzzy Finder (fzf) integrations, layered by toggle
# ---------------------------------------------------------------------
# Philosophy:
# - Nothing binds/overrides by default.
# - Enable features gradually via booleans below.
# - Safe on prod: relies on standard tools when present.
#
# How to enable:
#   export ENABLE_FZF_BASICS=true
#   export ENABLE_FZF_INTERMEDIATE=true
#   export ENABLE_FZF_ADVANCED=true
#   export ENABLE_FZF_CTRL_R=true            # bind Ctrl-R history
#   export ENABLE_FZF_CTRL_T=true            # bind Ctrl-T file picker (optional)
#   export ENABLE_FZF_ALT_C=true             # bind Alt-C cd picker (optional)
#   export ENABLE_FZF_PREVIEW=true           # enable preview pane (bat)
#
# You can set these in .zshrc before sourcing your ~/.zsh.d loader.
# ---------------------------------------------------------------------

# --- quick exit if fzf is not installed -------------------------------------
if ! command -v fzf >/dev/null 2>&1; then
  return
fi

# --- Prefer config files under ~/.config/fzf/ (XDG-friendly) ----------------
# These are standard fzf distro configs; they won't bind keys unless they contain such lines.
[ -f "$HOME/.config/fzf/fzf.zsh" ]  && source "$HOME/.config/fzf/fzf.zsh"
[ -f "$HOME/.config/fzf/fzf.bash" ] && source "$HOME/.config/fzf/fzf.bash"

# --- Defaults (light, safe) -------------------------------------------------
# Fast file list using ripgrep; respects .gitignore; includes dotfiles; follows symlinks.
# (Only set if user hasn't already.)
if [[ -z "${FZF_DEFAULT_COMMAND:-}" ]] && command -v rg >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
fi

# Keep Ctrl-R results ranked & exact by default (only matters if Ctrl-R is enabled later)
export FZF_CTRL_R_OPTS="${FZF_CTRL_R_OPTS:---sort --exact}"

# Tmux integration (only when inside tmux)
if [[ -n "${TMUX:-}" ]]; then
  export FZF_TMUX=1
  export FZF_TMUX_HEIGHT="${FZF_TMUX_HEIGHT:-70%}"
fi

# Optional preview (off by default)
# Requires: bat
if [[ "${ENABLE_FZF_PREVIEW:-false}" == "true" ]] && command -v bat >/dev/null 2>&1; then
  # Merge with any existing FZF_DEFAULT_OPTS
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }--preview 'bat --style=numbers --color=always {} | head -200' --preview-window=right:60%:wrap"
fi

# Optional UI niceties (enabled only with INTERMEDIATE or ADVANCED toggles below)
__fzf_add_ui_opts() {
  # height: use screen estate better; reverse: prompt at bottom; border: clean frame
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }--height=70% --reverse --border"
}

# ---------------------------------------------------------------------
# BASICS (opt-in): tiny helpers, no keybinding changes
# ---------------------------------------------------------------------
if [[ "${ENABLE_FZF_BASICS:-false}" == "true" ]]; then
  # Pick a file → open in Vim (Esc to cancel, no action)
  fvim()   { local f; f="$(fzf)" || return; vim -- "$f"; }

  # Pick a file → print absolute path (handy in scripts)
  fpath()  { local f; f="$(fzf)" || return; command -v realpath >/dev/null 2>&1 && realpath -- "$f" || printf '%s\n' "$PWD/$f"; }

  # History picker → copy to clipboard (mac: pbcopy; Linux: xclip/wl-copy if present)
  fhcopy() {
    local line
    line="$(fc -rl 1 | fzf | sed 's/^[[:space:]]*[0-9]\+[[:space:]]\+//')" || return
    if command -v pbcopy >/dev/null 2>&1; then printf '%s' "$line" | pbcopy; echo "Copied to clipboard."
    elif command -v wl-copy >/dev/null 2>&1; then printf '%s' "$line" | wl-copy; echo "Copied to clipboard."
    elif command -v xclip >/dev/null 2>&1; then printf '%s' "$line" | xclip -selection clipboard; echo "Copied to clipboard."
    else printf '%s\n' "$line"; fi
  }
fi

# ---------------------------------------------------------------------
# INTERMEDIATE (opt-in): nicer UI + a few quality helpers
# ---------------------------------------------------------------------
if [[ "${ENABLE_FZF_INTERMEDIATE:-false}" == "true" ]]; then
  __fzf_add_ui_opts

  # Pick a directory and cd into it (fast dir list using fd if available)
  fcd() {
    local cmd
    if command -v fd >/dev/null 2>&1; then
      cmd='fd --hidden --type d --follow --exclude .git'
    else
      cmd='find . -type d -not -path "*/\.git/*"'
    fi
    local dir
    dir="$(eval "$cmd" | fzf)" || return
    builtin cd -- "$dir"
  }

  # Ripgrep search → open selected match in vim at the right line
  frg() {
    command -v rg >/dev/null 2>&1 || { echo "ripgrep (rg) not found."; return 1; }
    local q="${*:-}"
    local sel
    sel="$(rg -n --hidden --follow --glob '!.git' -- "$q" | fzf)" || return
    # Expect "file:line:match"
    local file line
    file="${sel%%:*}"; line="${sel#*:}"; line="${line%%:*}"
    vim "+${line}" -- "$file"
  }
fi

# ---------------------------------------------------------------------
# ADVANCED (opt-in): power helpers (git/docker/logs)
# ---------------------------------------------------------------------
if [[ "${ENABLE_FZF_ADVANCED:-false}" == "true" ]]; then
  __fzf_add_ui_opts

  # Choose a git branch (local/remotes) → checkout
  gcof() {
    command -v git >/dev/null 2>&1 || { echo "git not found."; return 1; }
    local b
    b="$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null | sort -u | fzf)" || return
    # If remote branch like origin/foo → strip remote prefix
    b="${b#origin/}"
    git checkout -- "$b"
  }

  # Pick a running Docker container → shell in (bash or sh)
  dsh() {
    command -v docker >/dev/null 2>&1 || { echo "docker not found."; return 1; }
    local cid
    cid="$(docker ps --format '{{.ID}}  {{.Image}}  {{.Names}}' | fzf | awk '{print $1}')" || return
    docker exec -it "$cid" sh -lc 'bash || sh'
  }

  # Pick a log file under ~/logs (or current) → tail -f
  flog() {
    local root="${1:-$HOME/logs}"
    local picker
    if command -v fd >/dev/null 2>&1; then
      picker="fd -t f . \"$root\""
    else
      picker="find \"$root\" -type f"
    fi
    local f
    f="$(eval "$picker" | fzf)" || return
    tail -f -- "$f"
  }
fi

# ---------------------------------------------------------------------
# KEYBINDINGS (opt-in): Ctrl-R, Ctrl-T, Alt-C
# ---------------------------------------------------------------------
# Note: Homebrew installs fzf key-bindings under ~/.fzf/shell/key-bindings.zsh
# We'll source it only if the corresponding toggles are enabled.

# Ctrl-R: fuzzy history search (replaces default reverse-i-search)
if [[ "${ENABLE_FZF_CTRL_R:-false}" == "true" ]]; then
  if [[ -f "$HOME/.fzf/shell/key-bindings.zsh" ]]; then
    source "$HOME/.fzf/shell/key-bindings.zsh"
    # Optional: disable other bindings unless explicitly requested
    if [[ "${ENABLE_FZF_CTRL_T:-false}" != "true" ]]; then bindkey '^T' undefined-key 2>/dev/null || true; fi
    if [[ "${ENABLE_FZF_ALT_C:-false}" != "true" ]]; then bindkey '^[c' undefined-key 2>/dev/null || true; fi
  else
    # Fallback: light-weight Ctrl-R implementation without sourcing full key-bindings
    # (Opens fzf over history and inserts the selection at prompt)
    fzf-history-widget() {
      local selected
      selected="$(fc -rl 1 | fzf +s --tac --no-sort --exact --height=70% --reverse --border | sed 's/^[[:space:]]*[0-9]\+[[:space:]]\+//')"
      [[ -n "$selected" ]] && LBUFFER="$selected"
      zle reset-prompt
    }
    zle     -N   fzf-history-widget
    bindkey '^R' fzf-history-widget
  fi
fi

# Ctrl-T: file picker → inserts path at cursor
if [[ "${ENABLE_FZF_CTRL_T:-false}" == "true" ]]; then
  if [[ -f "$HOME/.fzf/shell/key-bindings.zsh" ]]; then
    source "$HOME/.fzf/shell/key-bindings.zsh"
  else
    # Minimal manual binding using FZF_DEFAULT_COMMAND
    fzf-file-widget() {
      local sel
      sel="$((eval "${FZF_DEFAULT_COMMAND:-fzf}") 2>/dev/null | fzf)" || return
      LBUFFER+="${LBUFFER:+ }$sel"
      zle reset-prompt
    }
    zle     -N   fzf-file-widget
    bindkey '^T' fzf-file-widget
  fi
fi

# Alt-C: cd into a selected directory
if [[ "${ENABLE_FZF_ALT_C:-false}" == "true" ]]; then
  if [[ -f "$HOME/.fzf/shell/key-bindings.zsh" ]]; then
    source "$HOME/.fzf/shell/key-bindings.zsh"
  else
    fzf-cd-widget() {
      local d
      if command -v fd >/dev/null 2>&1; then
        d="$(fd --hidden --type d --follow --exclude .git | fzf)" || return
      else
        d="$(find . -type d -not -path '*/\.git/*' | fzf)" || return
      fi
      builtin cd -- "$d"
      zle reset-prompt
    }
    zle     -N     fzf-cd-widget
    bindkey '^[c'  fzf-cd-widget
  fi
fi