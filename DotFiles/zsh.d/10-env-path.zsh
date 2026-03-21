# -----------------------------------------------------------------------------
# 10-env.zsh — base environment & path, cache & state locations (XDG-ish)
# -----------------------------------------------------------------------------
# This centralizes all the “dotty” runtime files so $HOME stays clean.
# After adding this, you can remove your previous 50-history.zsh and
# 80-completions.zsh (we set variables here and let oh-my-zsh run compinit).
# -----------------------------------------------------------------------------

export EDITOR="vim"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Enable vi-style keybindings in Zsh
bindkey -v
export KEYTIMEOUT=1  # faster ESC response (optional)

if [ -d "/opt/homebrew/bin" ]; then
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
fi
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

if [ -d "/usr/local/mysql/bin" ]; then
  export PATH=$PATH:/usr/local/mysql/bin
fi

# Add Claude to PATH if it exists
if [ -f "$HOME/.local/bin/claude" ]; then
  export PATH="$PATH:$HOME/.local/bin"
fi

# --- XDG Base Directory ------------------------------------------------------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# Main cache dir for Zsh-related state
export ZSH_CACHE_DIR="$HOME/.zshcache"
mkdir -p "$ZSH_CACHE_DIR"

# --- Zsh history (state) -----------------------------------------------------
# Larger history & single location
# We determine the filename here, but options are set later (in 50-history.zsh)
# to avoid conflicts with Oh-My-Zs.

local _hist_name="zsh_history"

if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  _hist_name="zsh_history_vscode"
elif [[ "$TERMINAL_EMULATOR" == "JetBrains"* || -n "$INTELLIJ_IDEA_CONSOLE" ]]; then
  _hist_name="zsh_history_jetbrains"
elif [[ -n "$ECLIPSE_CONSOLE" || -n "$ECLIPSE_HOME" ]]; then
  _hist_name="zsh_history_eclipse"
fi

export HISTFILE="$ZSH_CACHE_DIR/$_hist_name"
export HISTSIZE=200000
export SAVEHIST=200000

# --- Completions dump (cache) -----------------------------------------------
# Move .zcompdump out of $HOME and let OMZ use it.
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"

# NOTE: oh-my-zsh will autoload+run compinit for you using $ZSH_COMPDUMP.
# If you ever disable OMZ’s completion layer, uncomment the two lines below:
# autoload -Uz compinit
# compinit -C

# --- Less history (state) ----------------------------------------------------
export LESSHISTFILE="$ZSH_CACHE_DIR/lesshst"

# --- MySQL history (state) ---------------------------------------------------
export MYSQL_HISTFILE="$ZSH_CACHE_DIR/mysql_history"

# --- Oh-My-Zsh sessions (if plugin enabled) ---------------------------------
export ZSH_SESSION_DIR="$ZSH_CACHE_DIR/sessions"
mkdir -p "$ZSH_SESSION_DIR"

# --- zoxide DB (data) --------------------------------------------------------
# Keep zoxide’s database under our cache dir instead of ~/.local/share/zoxide
export _ZO_DATA_DIR="$ZSH_CACHE_DIR/zoxide"
mkdir -p "$_ZO_DATA_DIR"

# --- (Optional) FZF tunables (uncomment if you want to keep fzf state here) --
# export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
# export FZF_CTRL_R_OPTS="--sort --exact"
# export FZF_TMUX=1
# export FZF_TMUX_HEIGHT="70%"

# ---------------------------------------------------------------------
# 20) OH-MY-ZSH (Core)
# ---------------------------------------------------------------------
