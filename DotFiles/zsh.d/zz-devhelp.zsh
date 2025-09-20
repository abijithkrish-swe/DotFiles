# ============================================================================ #
# zz-devhelp.zsh — Unified developer help system
# ---------------------------------------------------------------------------- #
# - Loads help modules from ~/.zsh.d/help/*.zsh
# - Provides `devhelp <topic>` to show a cheatsheet
# - If no topic is given, falls back to "default"
# ============================================================================ #

: "${DEVHELP_DIR:=$HOME/.zsh.d/help}"

typeset -gA DEVHELP_MAP

# register function: topic → func
_devhelp_register() {
  local topic="$1" func="$2"
  [[ -z "$topic" || -z "$func" ]] && return 1
  DEVHELP_MAP[$topic]="$func"
}

# load all help modules
if [ -d "$DEVHELP_DIR" ]; then
  for f in "$DEVHELP_DIR"/*.zsh(N); do
    [ -r "$f" ] && source "$f"
  done
fi

# list topics
devhelp_list() {
  if (( ${#DEVHELP_MAP[@]} == 0 )); then
    echo "No devhelp topics loaded. Add files to: $DEVHELP_DIR"
    return
  fi
  echo "Available help topics:"
  for k in ${(ko)DEVHELP_MAP}; do
    echo "  - $k"
  done
}

# dispatcher
devhelp() {
  local topic="$1"
  if [[ -z "$topic" ]]; then
    topic="default"
  fi
  if [[ -n "${DEVHELP_MAP[$topic]}" ]]; then
    "${DEVHELP_MAP[$topic]}"
  else
    echo "No help for '$topic'."
    devhelp_list
    return 1
  fi
}