# dockrun-test.zsh — checks for dockrun (DotFiles/zsh.d/70-components-dockrun.zsh)
#
#   zsh -f tests/components/dockrun-test.zsh          dry-run checks (no Docker)
#   zsh -f tests/components/dockrun-test.zsh --live   also real containers from
#       your manifest's python image (pulled once if missing; needs Colima)
#
# Dry-run checks use cases/01-basic.conf, so they never depend on this machine.
emulate -L zsh
setopt no_unset pipe_fail

here="${${(%):-%x}:A:h}"
repo="${here:h:h}"
live=false; [[ "${1:-}" == "--live" ]] && live=true
source "$repo/DotFiles/zsh.d/70-components-core.zsh"
source "$repo/DotFiles/zsh.d/70-components-dockrun.zsh"

local -i ok=0 bad=0
local out rc
# Under ~ on purpose: Colima shares only the home folder with Docker.
mkdir -p "$HOME/.cache"
proj="$(mktemp -d "$HOME/.cache/dockrun-test.XXXXXX")"; proj="${proj:A}"
trap 'rm -rf "$proj"' EXIT
print '{}' >| "$proj/package.json"

# run <label> <expected rc> <args...>: sets $out (stdout+stderr) and $rc
run() {
  local label="$1" want="$2"; shift 2
  out="$(cd "$proj" && dockrun "$@" 2>&1)"; rc=$?
  if (( rc == want )); then return 0; fi
  (( bad++ )); print -r -- "XX  $label: rc $rc, expected $want"; print -r -- "$out" | sed 's/^/      /'
  return 1
}
has()   { if [[ "$out" == *"$2"* ]]; then (( ok++ )); else (( bad++ )); print -r -- "XX  $1: missing: $2"; print -r -- "$out" | sed 's/^/      /'; fi }
lacks() { if [[ "$out" != *"$2"* ]]; then (( ok++ )); else (( bad++ )); print -r -- "XX  $1: unexpected: $2"; fi }

export COMPONENTS_MANIFEST="$here/cases/01-basic.conf"
CM_MTIME=""
export https_proxy="http://127.0.0.1:3128"
D17="eclipse-temurin:17-jdk@sha256:$(printf '1%.0s' {1..64})"

# --- usage and refusals ------------------------------------------------------
run "no args" 2 && has "no args" "usage: dockrun"
run "unknown option" 2 --bogus jdk && has "unknown option" "unknown option --bogus"
run "unknown tool" 1 nope && has "unknown tool" 'unknown tool "nope"'
run "unapproved version" 1 jdk=21 && has "unapproved version" "jdk 21 is not approved"
run "prefix on a segment boundary only" 1 node=2 && has "prefix on a segment boundary only" "node 2 is not approved"
run "version without image" 1 jdk=25 && has "version without image" "jdk 25 has no docker image in the manifest (versions with one: 17)"
run "-p without --internet" 2 -p 8080 jdk=17 && has "-p without --internet" "-p needs --internet"
( https_proxy="" HTTPS_PROXY=""; run "--net without proxy" 2 --net jdk=17 && has "--net without proxy" "needs a local proxy" ) ; (( ok += 0 ))
https_proxy="http://proxy.corp.example:8080" run "--net with remote proxy" 2 --net jdk=17

for d in "$HOME" / "$HOME/.ssh" "$HOME/.config/agents"; do
  [[ -d "$d" ]] || continue
  out="$(cd "$d" && dockrun -n jdk=17 2>&1)"; rc=$?
  if (( rc == 1 )) && [[ "$out" == *"won't mount"* ]]; then (( ok++ )); else (( bad++ )); print -r -- "XX  refuse $d: rc $rc: $out"; fi
done
outside="$(mktemp -d "${TMPDIR:-/tmp}/dockrun-outside.XXXXXX")"
out="$(cd "$outside" && dockrun -n jdk=17 2>&1)"; rc=$?; rm -rf "$outside"
if (( rc == 1 )) && [[ "$out" == *"outside $HOME"* ]]; then (( ok++ )); else (( bad++ )); print -r -- "XX  refuse outside home: rc $rc: $out"; fi

# --- the docker command (dry run) --------------------------------------------
run "default" 0 -n jdk=17 'java -version && ls'
has "default" "docker run --rm"
has "default" "--network none"
has "default" "--cap-drop ALL"
has "default" "--security-opt no-new-privileges"
has "default" "--user $(id -u):$(id -g)"
has "default" "-v $proj:/work -w /work"
has "default" "--tmpfs /tmp:rw,exec,size=2g"
has "default" "-e HOME=/tmp"
has "default" "--entrypoint sh $D17 -c 'java -version && ls'"
has "default" "jdk 17  eclipse-temurin:17-jdk@111111111111…  /work = $proj  network: none"
lacks "default" "network create"

run "default version" 0 -n jdk && has "default version" "$D17"
run "tool@version form" 0 -n jdk@17 true && has "tool@version form" "$D17"
run "interactive shell" 0 -n jdk=17
[[ "$out" == *"--entrypoint sh $D17" ]] && (( ok++ )) || { (( bad++ )); print -r -- "XX  interactive shell: should end with the image, no -c"; print -r -- "$out"; }

run "--net" 0 -n --net maven 'mvn -q verify'
has "--net" "docker network create --internal dockrun-"
has "--net" "--network-alias proxy"
has "--net" "TCP-LISTEN:3128,fork,reuseaddr TCP:host.lima.internal:3128"
has "--net" "alpine/socat:1.8.0.3@sha256:3333"
has "--net" "-e https_proxy=http://proxy:3128"
has "--net" "'MAVEN_ARGS=-s /opt/toolshelf/m2-settings.xml'"
has "--net" "/opt/toolshelf/m2-settings.xml:ro"
has "--net" "-Dhttps.proxyHost=proxy"
has "--net" "docker network rm dockrun-"
lacks "--net" "--network none"

run "no image for that tool" 1 node=22 && has "no image for that tool" "node 22.21.1 has no docker image in the manifest"
run "--internet + ports" 0 -n --internet -p 8080 -p 9000:80 jdk=17 'jwebserver -b 0.0.0.0'
has "--internet + ports" "-p 127.0.0.1:8080:8080"
has "--internet + ports" "-p 127.0.0.1:9000:80"
lacks "--internet + ports" "--network none"
lacks "--internet + ports" "--network dockrun"

run "options after --" 0 -n -- jdk=17 'echo hi' && has "options after --" "-c 'echo hi'"

# --- live: real containers from the real manifest ------------------------------
if $live; then
  export COMPONENTS_MANIFEST="$repo/DotFiles/config/components/components.conf"; CM_MTIME=""
  print -r -- "secret" >| "$proj/inside.txt"
  run "live: isolation" 0 python \
    'echo "uid=$(id -u) home=$HOME"; ls /work; touch /work/made-inside; ls /Users 2>&1 | head -1; python3 -c "import socket; socket.create_connection((\"1.1.1.1\", 443), 3)" 2>&1 | tail -1'
  has "live: isolation" "uid=$(id -u) home=/tmp"
  has "live: isolation" "inside.txt"
  has "live: isolation" "No such file or directory"   # no /Users: home not mounted
  has "live: isolation" "Network is unreachable"
  [[ -f "$proj/made-inside" ]] && (( ok++ )) || { (( bad++ )); print -r -- "XX  live: write to /work didn't reach the project"; }
  run "live: exit code passes through" 7 python 'exit 7'
  run "live: no capabilities" 0 python 'grep CapEff /proc/self/status' && has "live: no capabilities" "0000000000000000"
fi

print "\n$ok passed, $bad failed"
(( bad == 0 ))
