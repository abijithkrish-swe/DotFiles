# 42) bat (pretty cat) — optional
# https://github.com/sharkdp/bat
# Install: brew install bat

if (( $+commands[bat] )); then
  export BAT_THEME="TwoDark"
  
  # 1. Use bat as a colorizing pager for man pages
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  
  # 2. Safety alias: prevent accidental large file prints? 
  # (User choice, but 'cat' -> 'bat' allows paging automatically)
  alias cat='bat -p' 
  
  # 3. Explicit aliases
  alias batp='bat --style=plain'        # Plain text (copy-paste friendly)
  alias batn='bat --style=numbers'      # Numbers only
  alias batt='bat --style=numbers,changes' # Track git changes
  
  # 4. Help integration: Highlight help output
  # Usage: git commit --help
  alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'

fi
