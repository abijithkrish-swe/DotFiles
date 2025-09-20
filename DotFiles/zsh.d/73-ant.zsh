# 73) Ant helpers

# List Ant versions (must have bin/ant)
ant_versions() {
  local d v
  [[ -d "$COMPONENTS/Ant" ]] || return 0
  for d in "$COMPONENTS/Ant"/*; do
    [[ -d "$d/bin" && -x "$d/bin/ant" ]] || continue
    v="${d:t}"
    echo "$v"
  done | sort -V
}

# Use a specific Ant version (append PATH + set ANT_HOME)
# If no version passed, falls back to DEFAULT_ANT (if set).
use_ant() {
  local v="${1:-$DEFAULT_ANT}"
  [[ -z "$v" ]] && { echo "Usage: use_ant <version>  (or set DEFAULT_ANT)"; return 1; }

  local root="$COMPONENTS/Ant/$v"
  if [ -d "$root/bin" ]; then
    export ANT_HOME="$root"
    export PATH="$PATH:$ANT_HOME/bin"   # append (safer)
    echo "Using Ant $v from $ANT_HOME"
    ant -version 2>/dev/null || echo "ant not found in $ANT_HOME/bin"
  else
    echo "Ant $v not found under $COMPONENTS/Ant"
    return 1
  fi
}

# ---------------------------------------------------------------------
# 74) Protobuf helpers
# ---------------------------------------------------------------------