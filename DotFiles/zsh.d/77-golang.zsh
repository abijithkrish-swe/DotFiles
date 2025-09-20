# 77) Golang (portable, toggle optional)

# List Go versions (must have bin/go)
go_versions() {
  local d v
  [[ -d "$COMPONENTS/Golang" ]] || return 0
  for d in "$COMPONENTS/Golang"/*; do
    [[ -d "$d/bin" && -x "$d/bin/go" ]] || continue
    v="${d:t}"
    echo "$v"
  done | sort -V
}

# Resolve a GOROOT with bin/ under ~/Components/Golang/<ver>
_go_root() {
  local root="$COMPONENTS/Golang/$1"
  if [ -d "$root/bin" ]; then
    echo "$root"; return 0
  fi
  return 1
}

# use_golang <ver> — set GOROOT, append PATH, confirm
# Tip: set GOPATH per-project (direnv) or globally: export GOPATH="$HOME/go"
use_golang() {
  local v="${1:?version}"
  local root; root="$(_go_root "$v")" || { echo "Go $v not found under $COMPONENTS/Golang"; return 1; }
  export GOROOT="$root"
  export PATH="$PATH:$GOROOT/bin"   # append (safer)
  echo "Using Go $v from $GOROOT"
  go version 2>/dev/null || echo "go not found in $GOROOT/bin"
}

# Print Go env pointers
go_env() {
  echo "GOROOT=${GOROOT:-<unset>}"
  echo "GOPATH=${GOPATH:-$HOME/go}"
  echo "GOBIN=${GOBIN:-$GOPATH/bin}"
}

# ---------------------------------------------------------------------
# 78) Node / npm (portable)
# ---------------------------------------------------------------------