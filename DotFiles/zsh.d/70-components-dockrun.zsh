# 70) dockrun — try code you don't trust in a throwaway container
#
#   dockrun [options] <tool>[=version] ['command']
#
# Runs the command (or, with none, an interactive shell) in the tool's pinned
# image from the components manifest (docker=…, see <tool>_list), with the
# current folder at /work. Nothing else from your Mac is visible: no home, no
# SSH keys, no caches, no Docker socket. The container is removed afterwards.
# Same limits as toolshelf's docker mode for agents (no capabilities, your
# uid, cpu/memory/pids caps, fresh /tmp as HOME).
#
#   (no flag)    no network at all
#   --net        only the zero-trust proxy ($https_proxy on localhost), enforced
#   --internet   normal network (needed for -p, and where there is no proxy)
#   -p PORT[:C]  publish a port on 127.0.0.1 only (needs --internet)
#   -n           print the docker commands instead of running them
#
# Quote compound commands: dockrun node=22 'npm ci && npm test'
# (unquoted, your shell would run "npm test" on the Mac after dockrun).
# Design: Docs/AgentComponents.md

_dockrun_usage() {
  print -r -- "usage: dockrun [--net|--internet] [-p PORT[:C]]... [-n] <tool>[=version] ['command']"
  print -r -- "  e.g. dockrun node=22 'npm ci && npm test'   dockrun python   dockrun --internet -p 8080 node 'npx serve'"
  print -r -- "  tools with a docker image: ${(j:, :)${(u)${(k)CM_DOCKER[@]%%:*}}}"
}

dockrun() {
  emulate -L zsh
  setopt local_traps
  local net=none dry=false spec="" tool q v img dir rid netname fwd pp port tmpd hostp contp
  local -a ports cmd dargs envs pre post
  components_ensure_loaded || return 1

  while (( $# )); do
    case "$1" in
      --net)       net=proxy ;;
      --internet)  net=internet ;;
      -p|--port)   [[ -n "${2:-}" ]] || { _dockrun_usage >&2; return 2; }; ports+=("$2"); shift ;;
      -n|--dry-run) dry=true ;;
      -h|--help)   _dockrun_usage; return 0 ;;
      --)          shift; break ;;
      -*)          print -u2 "dockrun: unknown option $1"; _dockrun_usage >&2; return 2 ;;
      *)           spec="$1"; shift; break ;;
    esac
    shift
  done
  [[ -z "$spec" && $# -gt 0 ]] && { spec="$1"; shift; }
  [[ -n "$spec" ]] || { _dockrun_usage >&2; return 2; }
  cmd=("$@")

  # --- image: the approved version's pinned image, nothing else -------------
  tool="${spec%%[=@]*}"; q=""; [[ "$spec" == *[=@]* ]] && q="${spec#*[=@]}"
  components_match "$tool" "$q" || return 1
  v="$CM_V"
  img="${CM_DOCKER[$tool:$v]:-}"
  if [[ -z "$img" ]]; then
    local -a with=(${${(M)${(k)CM_DOCKER[@]}:#$tool:*}#$tool:})
    print -u2 "dockrun: $tool $v has no docker image in the manifest${with:+ (versions with one: ${(j:, :)${(on)with}})}"
    return 1
  fi
  [[ "$img" =~ '@sha256:[0-9a-f]{64}$' ]] || { print -u2 "dockrun: refusing unpinned image $img"; return 1; }

  # --- folder: a project, never home itself or private dirs -----------------
  dir="${PWD:A}"
  case "$dir" in
    /|/Users|"$HOME") print -u2 "dockrun: won't mount $dir; cd into the project folder"; return 1 ;;
    "$HOME"/.ssh(|/*)|"$HOME"/.gnupg(|/*)|"$HOME"/.aws(|/*)|"$HOME"/.config(|/*)|"$HOME"/.local(|/*)|"$HOME"/Library(|/*)|"$HOME"/.claude(|/*))
      print -u2 "dockrun: won't mount private folder $dir"; return 1 ;;
  esac
  [[ "$HOME" == "$dir"/* ]] && { print -u2 "dockrun: won't mount $dir (it contains your home)"; return 1; }
  # Colima shares only your home with its VM; anything else would silently
  # mount as an empty, root-owned /work.
  if [[ "$dir" != "$HOME"/* ]]; then
    print -u2 "dockrun: $dir is outside $HOME, which is all Colima shares with Docker; copy the project under ~ first"
    return 1
  fi

  # --- network ---------------------------------------------------------------
  (( $#ports )) && [[ "$net" != internet ]] && { print -u2 "dockrun: -p needs --internet (the other modes have no host network)"; return 2; }
  if [[ "$net" == proxy ]]; then
    pp="${https_proxy:-${HTTPS_PROXY:-}}"
    if [[ ! "$pp" =~ '^https?://(127\.0\.0\.1|localhost):([0-9]+)/?$' ]]; then
      print -u2 "dockrun: --net needs a local proxy in \$https_proxy (got '${pp:-none}'); use --internet for a normal network"
      return 2
    fi
    port="$match[2]"
    fwd="${CM_IMAGES[proxy-forwarder]:-}"
    [[ -n "$fwd" ]] || { print -u2 "dockrun: --net needs '@image proxy-forwarder <image@sha256:…>' in the manifest"; return 1; }
  fi

  if ! $dry; then
    (( $+commands[docker] )) || { print -u2 "dockrun: docker CLI not found"; return 1; }
    docker info >/dev/null 2>&1 || { print -u2 "dockrun: Docker isn't running (start Colima: costart)"; return 1; }
  fi

  rid="dockrun-$$-$RANDOM"
  dargs=(run --rm --name "$rid" --pull missing
    --cap-drop ALL --security-opt no-new-privileges
    --pids-limit 1024 --memory 4g --cpus 2
    --user "$(id -u):$(id -g)"
    --tmpfs /tmp:rw,exec,size=2g
    -v "$dir:/work" -w /work)
  [[ -t 0 && -t 1 ]] && dargs+=(-it) || dargs+=(-i)
  # Your uid has no passwd entry in the image; keep every tool's home in /tmp.
  envs=(HOME=/tmp DOCKRUN=1 GRADLE_USER_HOME=/tmp/.gradle CARGO_HOME=/tmp/.cargo GOPATH=/tmp/go
    GOFLAGS=-modcacherw GOTOOLCHAIN=local MAVEN_CONFIG= PIP_DISABLE_PIP_VERSION_CHECK=1)
  local jopts="-Duser.home=/tmp"

  case "$net" in
    none) dargs+=(--network none) ;;
    internet)
      for pp in $ports; do
        hostp="${pp%%:*}" contp="${pp#*:}"
        dargs+=(-p "127.0.0.1:$hostp:$contp")
      done ;;
    proxy)
      netname="$rid-net"
      pre=(
        "docker network create --internal $netname"
        "docker run -d --rm --pull missing --name $rid-fwd --network $netname --network-alias proxy --cap-drop ALL --security-opt no-new-privileges $fwd TCP-LISTEN:$port,fork,reuseaddr TCP:host.lima.internal:$port"
        "docker network connect bridge $rid-fwd"
      )
      post=("docker rm -f $rid-fwd" "docker network rm $netname")
      local p="http://proxy:$port"
      envs+=(http_proxy=$p https_proxy=$p HTTP_PROXY=$p HTTPS_PROXY=$p no_proxy=localhost,127.0.0.1 NO_PROXY=localhost,127.0.0.1
        npm_config_proxy=$p npm_config_https_proxy=$p CARGO_HTTP_PROXY=$p MAVEN_ARGS="-s /opt/toolshelf/m2-settings.xml")
      jopts+=" -Dhttp.proxyHost=proxy -Dhttp.proxyPort=$port -Dhttps.proxyHost=proxy -Dhttps.proxyPort=$port"
      # Maven ignores proxy env vars and JVM properties; give it a settings.xml
      tmpd="$(mktemp -d "${TMPDIR:-/tmp}/dockrun.XXXXXX")"
      print -r -- "<settings><proxies>
  <proxy><id>p-https</id><active>true</active><protocol>https</protocol><host>proxy</host><port>$port</port></proxy>
  <proxy><id>p-http</id><active>true</active><protocol>http</protocol><host>proxy</host><port>$port</port></proxy>
</proxies></settings>" >| "$tmpd/m2-settings.xml"
      dargs+=(--network "$netname" -v "$tmpd/m2-settings.xml:/opt/toolshelf/m2-settings.xml:ro") ;;
  esac
  envs+=("MAVEN_OPTS=$jopts" "GRADLE_OPTS=$jopts")
  for pp in $envs; do dargs+=(-e "$pp"); done

  if (( $#cmd )); then dargs+=(--entrypoint sh "$img" -c "${(j: :)cmd}")
  else dargs+=(--entrypoint sh "$img"); fi

  print -u2 -r -- "dockrun: $tool $v  ${img%%@*}@${${img#*@sha256:}[1,12]}…  /work = $dir  network: $net${ports:+  ports: 127.0.0.1:${(j:, :)ports}}"
  if $dry; then
    for pp in $pre; do print -r -- "$pp"; done
    print -r -- "docker ${(j: :)${(@q-)dargs}}"
    for pp in $post; do print -r -- "$pp"; done
    [[ -n "$tmpd" ]] && rm -rf "$tmpd"
    return 0
  fi

  # Remember pinned images, so components_images can show and prune them.
  local state="${TOOLSHELF_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/toolshelf}"
  mkdir -p "$state" && touch "$state/images.log"
  for pp in "$img" ${fwd:+"$fwd"}; do grep -qxF -- "$pp" "$state/images.log" || print -r -- "$pp" >> "$state/images.log"; done

  local rc=0
  {
    for pp in $pre; do eval "$pp" >/dev/null || { rc=1; break; }; done
    (( rc )) || { docker "${dargs[@]}"; rc=$?; }
  } always {
    for pp in $post; do eval "$pp" >/dev/null 2>&1; done
    [[ -n "$tmpd" ]] && rm -rf "$tmpd"
  }
  return $rc
}

# Completion: tools that have a docker image, as tool or tool=version
_dockrun_comp() {
  local -a specs; local k
  for k in ${(k)CM_DOCKER}; do specs+=("${k%%:*}" "${k%%:*}=${k#*:}"); done
  compadd -- ${(u)specs} --net --internet -p -n
}
(( $+functions[compdef] )) && compdef _dockrun_comp dockrun
