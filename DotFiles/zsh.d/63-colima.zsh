# 62) Colima Helpers
# --- Colima (Docker/Kubernetes) ---------------------------------------------
# No effect unless you run the aliases below (does NOT auto-start anything).

# Basic lifecycle
alias costart='colima start --kubernetes'
alias corest='colima restart'
alias costop='colima stop'
alias codrop='colima delete -f'            # destroy VM (images/volumes inside are lost)
alias colist='colima list'

# Ensure Docker CLI targets Colima after (re)start
alias couse='docker context use colima'

# Quick status
coinfo() {
  echo "Colima:"
  colima status 2>/dev/null || true
  echo
  echo "Docker context: $(docker context show 2>/dev/null || echo none)"
  echo "Kubernetes context: $(kubectl config current-context 2>/dev/null || echo none)"
}

# Optional: switch to containerd+nerdctl (advanced)
# alias costart_ctd='colima start --runtime containerd --kubernetes'
# Then use: nerdctl ps / nerdctl build ...

# ---------------------------------------------------------------------
# 65) secrets helper
# ---------------------------------------------------------------------