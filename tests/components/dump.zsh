# dump.zsh <manifest> — what the zsh parser (70-components-core.zsh) makes of a
# manifest, in the format parity.zsh compares (dump.mjs prints the same for
# toolshelf's parser):
#   REJECT                                    the manifest was refused, or:
#   tool <name> dir=… root=… bin=… check=… home=…
#   version <tool> <version> [default] [autoload] [onpath] [docker=…]   (sorted)
#   image <name> <ref>                        (sorted by name)
#   resolve <tool> <query> => <version>|ERROR  for each "# query: <tool> <q>" line
#                                             ("-" = empty query = default)
# Each version gets a fake install under a temp $COMPONENTS so resolution
# isn't limited by what's on this machine.
emulate -L zsh
setopt no_unset pipe_fail

manifest="$1"
here="${${(%):-%x}:A:h}"
export COMPONENTS_MANIFEST="$manifest"
export COMPONENTS="$(mktemp -d "${TMPDIR:-/tmp}/cm-parity.XXXXXX")"
trap 'rm -rf "$COMPONENTS"' EXIT
source "$here/../../DotFiles/zsh.d/70-components-core.zsh" 2>/dev/null

if ! components_load 2>/dev/null; then
  print REJECT
  exit 0
fi
print ACCEPT

local t v line q root bin check flags
for t in "${CM_TOOLS[@]}"; do
  print -r -- "tool $t dir=$CM_DIR[$t] root=${CM_ROOT[$t]:-.} bin=${CM_BIN[$t]:-bin} check=${CM_CHECK[$t]:-} home=${${CM_HOMEENV[$t]:-}// /,}"
done
for t in "${CM_TOOLS[@]}"; do
  for v in ${=CM_VERSIONS[$t]}; do
    flags=""
    [[ "${CM_DEFAULT[$t]:-}" == "$v" ]] && flags+=" default"
    [[ "${CM_AUTOLOAD[$t]:-}" == "$v" ]] && flags+=" autoload"
    [[ "${CM_ONPATH[$t]:-}" == "$v" ]] && flags+=" onpath"
    [[ -n "${CM_DOCKER[$t:$v]:-}" ]] && flags+=" docker=${CM_DOCKER[$t:$v]}"
    print -r -- "version $t $v$flags"
    # fake install: first root and bin candidate, plus the check binary
    # via arrays: "${${(s:|:)x}[1]}" gives the first *character* of a one-item list
    local -a roots=(${(s:|:)${CM_ROOT[$t]:-.}}) bins=(${(s:|:)${CM_BIN[$t]:-bin}})
    root="$roots[1]" bin="$bins[1]"
    mkdir -p "$COMPONENTS/$CM_DIR[$t]/$v/$root/$bin"
    check="${CM_CHECK[$t]:-}"
    if [[ -n "$check" ]]; then
      : >| "$COMPONENTS/$CM_DIR[$t]/$v/$root/$bin/$check"
      chmod +x "$COMPONENTS/$CM_DIR[$t]/$v/$root/$bin/$check"
    fi
  done
done
for k in ${(ko)CM_IMAGES}; do print -r -- "image $k $CM_IMAGES[$k]"; done

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ "$line" == "# query: "* ]] || continue
  local -a w=(${=line#\# query: })
  q="${w[2]:--}"
  if components_resolve "$w[1]" "${q:#-}" 2>/dev/null; then
    print -r -- "resolve $w[1] $q => $CM_V"
  else
    print -r -- "resolve $w[1] $q => ERROR"
  fi
done < "$manifest"
