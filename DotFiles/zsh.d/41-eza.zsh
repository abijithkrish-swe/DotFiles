# 41) eza (modern ls) — optional
# https://github.com/eza-community/eza
# Install: brew install eza

export ENABLE_EZA=true   # flip to false to disable

if [[ "$ENABLE_EZA" == "true" ]] && (( $+commands[eza] )); then
  # Standard overrides
  alias ls='eza --icons --git --group-directories-first'
  alias ll='eza -l --icons --git --group-directories-first --header'
  alias la='eza -la --icons --git --group-directories-first --header'
  
  # Tree views (Utilizing eza's tree feature)
  alias lt='eza --tree --level=2 --icons'
  alias ltt='eza --tree --level=3 --icons'
  
  # Sort by specific attributes
  alias lS='ll --sort=size'      # Sort by size
  alias lm='ll --sort=modified'  # Sort by time
  
else
  # Fallbacks if eza is missing
  alias ll='ls -lh'
  alias la='ls -lha'
fi
