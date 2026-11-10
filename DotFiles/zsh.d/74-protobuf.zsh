# 74) Protobuf
# Versions come from the components manifest.

protobuf_list() { components_list protobuf Protobuf; }

use_protoc() {
  if [[ "$1" == "off" ]]; then protobuf_clear; return; fi
  components_activate protobuf Protobuf _PROTO_ACTIVE_BIN "$1" || return 1
  echo "Switched to Protobuf $CM_V"; protoc --version
}
# Manifest/toolup name (PROTOBUF=…) → same as use_protoc
use_protobuf() { use_protoc "$@"; }

protobuf_clear() {
  components_deactivate protobuf Protobuf _PROTO_ACTIVE_BIN
  echo "Protobuf removed"
}

alias protobuf_versions='protobuf_list'
alias protobuf_use='use_protoc'  # Legacy/Inverse alias
alias protobuf_off='protobuf_clear'

load_components_completion "use_protoc" "protobuf"
