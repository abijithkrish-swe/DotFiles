# parity.zsh — the shell and toolshelf must read components.conf the same way.
#
#   zsh tests/components/parity.zsh            all cases + the real manifest
#   zsh tests/components/parity.zsh -v         also print both dumps on success
#
# Each manifest in cases/ (plus DotFiles/config/components/components.conf) goes
# through both parsers: zsh's components_load/components_resolve (dump.zsh) and
# toolshelf's loadManifest/resolveVersion (dump.mjs). The outputs must match
# line for line: accept/reject, tools, versions + flags, images, and every
# "# query:" resolution. A case may also say "# expect: reject" or
# "# expect: accept" to pin the answer, not just agreement.
#
# Uses the installed toolshelf ($TOOLSHELF_DIST, default
# $COMPONENTS/toolshelf-mcp/dist) and the manifest's default node.
emulate -L zsh
setopt no_unset pipe_fail

here="${${(%):-%x}:A:h}"
repo="${here:h:h}"
verbose=false; [[ "${1:-}" == "-v" ]] && verbose=true
dist="${TOOLSHELF_DIST:-${COMPONENTS:-$HOME/Components}/toolshelf-mcp/dist}"
[[ -f "$dist/components.js" ]] || { print -u2 "toolshelf not installed at $dist (set TOOLSHELF_DIST)"; exit 2; }

# node: the manifest's default, resolved by the shell's own resolver
node="$(
  source "$repo/DotFiles/zsh.d/70-components-core.zsh"
  COMPONENTS_MANIFEST="$repo/DotFiles/config/components/components.conf" components_resolve node 2>/dev/null \
    && print -r -- "$CM_BIN_DIR/node"
)"
[[ -x "$node" ]] || { print -u2 "no default node from the manifest"; exit 2; }

local -i ok=0 bad=0
local f a b want got
for f in "$here"/cases/*.conf "$repo/DotFiles/config/components/components.conf"; do
  a="$(zsh -f "$here/dump.zsh" "$f" 2>&1)"
  b="$("$node" "$here/dump.mjs" "$dist" "$f" 2>&1)"
  want="$(sed -n 's/^# expect: *//p' "$f" | head -1 | tr -d '\r')"
  local -a lines=("${(@f)a}")
  got="$lines[1]"
  if [[ "$a" == "$b" && ( -z "$want" || "$got" == "${(U)want}" ) ]]; then
    (( ok++ )); print -r -- "ok  ${f:t}  ($got, $#lines lines)"
    $verbose && print -r -- "$a" | sed 's/^/      /'
  else
    (( bad++ )); print -r -- "XX  ${f:t}"
    [[ -n "$want" && "$got" != "${(U)want}" ]] && print -r -- "      expected ${(U)want}, zsh says $got"
    if [[ "$a" != "$b" ]]; then
      print -r -- "      --- zsh  +++ toolshelf"
      diff <(print -r -- "$a") <(print -r -- "$b") | sed -n 's/^</      -/p; s/^>/      +/p'
    fi
  fi
done
print "\n$ok passed, $bad failed"
(( bad == 0 ))
