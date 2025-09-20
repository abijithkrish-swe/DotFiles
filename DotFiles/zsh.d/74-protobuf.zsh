# 74) Protobuf helpers

# List Protobuf versions (must have bin/protoc)
protoc_versions() {
  local d v
  [[ -d "$COMPONENTS/Protobuf" ]] || return 0
  for d in "$COMPONENTS/Protobuf"/*; do
    [[ -d "$d/bin" && -x "$d/bin/protoc" ]] || continue
    v="${d:t}"
    echo "$v"
  done | sort -V
}

# Use a specific Protobuf version (append PATH + set PROTOBUF_HOME)
# If no version passed, falls back to DEFAULT_PROTOBUF (if set).
use_protoc() {
  local v="${1:-$DEFAULT_PROTOBUF}"
  [[ -z "$v" ]] && { echo "Usage: use_protoc <version>  (or set DEFAULT_PROTOBUF)"; return 1; }

  local root="$COMPONENTS/Protobuf/$v"
  if [ -d "$root/bin" ]; then
    export PROTOBUF_HOME="$root"
    export PATH="$PATH:$PROTOBUF_HOME/bin"   # append (safer)
    echo "Using Protobuf $v from $PROTOBUF_HOME"
    protoc --version 2>/dev/null || echo "protoc not found in $PROTOBUF_HOME/bin"
  else
    echo "Protobuf $v not found under $COMPONENTS/Protobuf"
    return 1
  fi
}

# ---------------------------------------------------------------------
# 75) MySQL helpers
# ---------------------------------------------------------------------