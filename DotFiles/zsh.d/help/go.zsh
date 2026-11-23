# --- go help module -----------------------------------------------------------
_devhelp_go() {

cat <<-'EOF2'
Go Component Management
=======================

go_list                 # Approved Go versions (from the components manifest)
use_go [version]        # Activate (exact or prefix: 1.27 → 1.27.4; none = default)
use_go off              # Deactivate Go
go_clear                # Same as 'use_go off'
                        # aliases: go_use, go_off, go_versions

Environment Variables
---------------------
GOROOT                  # Go install dir (set by use_go)
GOTOOLCHAIN=local       # never let go download another toolchain

Examples
--------
use_go 1.27             # Switch to Go 1.27.4
go build ./... && go test ./...

Per project
-----------
.toolsrc:  GO=1.27      then: toolup
Agents: toolshelf run with tools {"go": "1.27"} (devhelp toolshelf)

Status
------
components_status       # See the active Go version
EOF2
}

_devhelp_register "go" _devhelp_go
