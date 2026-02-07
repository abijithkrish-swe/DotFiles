# 74) Protobuf
# Layout: ~/Components/Protobuf/<ver>/bin/protoc

protobuf_list() {
  local d
  [[ -d "$COMPONENTS/Protobuf" ]] || return 0
  echo "Available Protobuf versions:"
  for d in "$COMPONENTS/Protobuf"/*; do
     [[ -x "$d/bin/protoc" ]] && echo "  ${d:t}"
  done | sort -V
}

use_protoc() {
  local v="$1"
  component_set_status "Protobuf" "$v"
  
  if [[ "$v" == "off" || -z "$v" ]]; then
    protobuf_clear
    return
  fi
  local home="$COMPONENTS/Protobuf/$v"
  [[ -d "$home" ]] || { echo "Protobuf $v not found"; return 1; }
  
  # Usually just needs PATH
  component_switch_path "_PROTO_ACTIVE_BIN" "$home/bin"
  echo "Switched to Protobuf $v"; protoc --version
}

protobuf_clear() {
  component_switch_path "_PROTO_ACTIVE_BIN" ""
  echo "Protobuf removed"
}

alias protobuf_versions='protobuf_list'
alias protobuf_use='use_protoc'  # Legacy/Inverse alias
alias protobuf_off='protobuf_clear'

load_components_completion "use_protoc" "Protobuf"
