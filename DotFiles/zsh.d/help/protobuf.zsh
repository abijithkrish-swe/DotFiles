# --- protobuf help module -----------------------------------------------------
_devhelp_protobuf() {

cat <<-'EOF2'
Protobuf (protoc) Component Management
======================================

protobuf_list           # Approved protoc versions (from the components manifest)
use_protoc [version]    # Activate (exact or prefix: 25 → 25.5; none = default)
use_protobuf [version]  # Same as use_protoc
use_protoc off          # Deactivate
protobuf_clear          # Same as 'use_protoc off'
                        # aliases: protobuf_use, protobuf_off, protobuf_versions

Examples
--------
use_protoc 25           # Switch to protoc 25.5
protoc --version
protoc --java_out=build/gen -I proto proto/*.proto

Per project
-----------
.toolsrc:  PROTOBUF=25.5   then: toolup

Status
------
components_status       # See the active protoc version
EOF2
}

_devhelp_register "protobuf" _devhelp_protobuf
