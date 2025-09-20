# 90) nvm (Node Version Manager) — optional, guarded
# Install: brew install nvm
# Note: Not required if you use ~/Components/Node + use_node <ver>

export ENABLE_NVM=false

if [[ "$ENABLE_NVM" == "true" ]]; then
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
fi

# ---------------------------------------------------------------------
# 99) local overrides
# ---------------------------------------------------------------------