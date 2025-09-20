# --- fzf help: Advanced (with functions) ------------------------------------
# Place in: ~/.zsh.d/help/fzf-advanced.zsh

_devhelp_fzf_advanced() {
  cat <<'EOF'
fzf — Advanced
==============
Toggles:
  ENABLE_FZF_ADVANCED=true   # enables git/docker/log helpers

Functions (enabled by ENABLE_FZF_ADVANCED):
  gcof        Fuzzy-pick a git branch (locals + remotes) and checkout
              Usage: gcof
              Notes: 'origin/foo' automatically checked out as 'foo'

  dsh         Fuzzy-pick a running Docker container and shell in
              Usage: dsh
              Shell: tries bash, falls back to sh

  flog        Fuzzy-pick a log file then tail -f (defaults to ~/logs)
              Usage: flog [root_dir]
              Examples:
                flog                 # searches under ~/logs
                flog /var/log        # search system logs

Ad‑hoc power recipes:
  Pick a JAR → inspect contents
    fd -e jar | fzf | xargs -I{} sh -c 'jar tf "{}" | fzf'

  Ports in use → choose → kill process (careful!)
    lsof -i -P -n | fzf | awk 'NR>1{print $2}' | sort -u | xargs -r kill -9
    # Prefer investigating first:
    lsof -i -P -n | fzf

Optional keybindings (Ctrl-R only):
  # Homebrew helper:
  $(brew --prefix)/opt/fzf/install
  # Or source keybindings & keep only Ctrl-R:
  if [[ -f ~/.fzf/shell/key-bindings.zsh ]]; then
    source ~/.fzf/shell/key-bindings.zsh
    bindkey '^T' undefined-key
    bindkey '^[c' undefined-key
    export FZF_CTRL_R_OPTS="--sort --exact"
  fi
EOF
}

_devhelp_register "fzf-adv" _devhelp_fzf_advanced
