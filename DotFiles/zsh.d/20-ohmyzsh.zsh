# 2 ) OH-MY-ZSH (Core)

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(git)

# Source oh-my-zsh
if [ -d "$ZSH" ]; then
  source "$ZSH/oh-my-zsh.sh"
fi

# ---------------------------------------------------------------------
# 30) PROMPT (Optional: Starship)
# ---------------------------------------------------------------------
