# 62) Colima Helpers
# --- Colima (Docker/Kubernetes) ---------------------------------------------
# No effect unless you run the aliases below (does NOT auto-start anything).

# Basic lifecycle
alias costart='colima start --kubernetes'
alias corest='colima restart'
alias costop='colima stop'
alias codrop='colima delete -f'            # destroy VM (images/volumes inside are lost)
alias colist='colima list'

# Ensure Docker CLI targets Colima after (re)start
alias couse='docker context use colima'

# Quick status
coinfo() {
  echo "Colima:"
  colima status 2>/dev/null || true
  echo
  echo "Docker context: $(docker context show 2>/dev/null || echo none)"
  echo "Kubernetes context: $(kubectl config current-context 2>/dev/null || echo none)"
}

# Without Kubernetes: a few hundred MiB less RAM and less idle CPU
alias costart_lite='colima start'

# ---------------------------------------------------------------------
# docker_usage: where Docker's memory and disk go (read-only)
# docker_clean: remove what you choose, with a confirmation each time.
#   Never touches images pinned in the components manifest, images a
#   container uses, or SigNoz's volumes (signoz-*).
# ---------------------------------------------------------------------

docker_usage() {
  emulate -L zsh
  docker info >/dev/null 2>&1 || { echo "Docker isn't reachable (start Colima: costart)"; return 1; }
  print -P "%BVM%b"
  colima list 2>/dev/null | sed -n 2p | awk '{printf "  allowed: %s CPUs, %s RAM, %s disk\n", $4, $5, $6}'
  ps -axo rss,comm | awk '/Virtualization.VirtualMachine/ {s+=$1} END {printf "  using on this Mac: %.1f GiB RAM\n", s/1048576}'
  # awk for all parsing: macOS sed doesn't understand \t
  print -P "\n%BMemory per container%b (running)"
  docker stats --no-stream --format '{{.MemUsage}}|{{.CPUPerc}}|{{.Name}}' | awk -F'|' '
    { split($1, m, " / "); u = m[1]; n = u + 0
      if (u ~ /GiB$/) n *= 1024; else if (u ~ /KiB$/) n /= 1024; else if (u ~ /B$/ && u !~ /iB$/) n /= 1048576
      name = $3; if (name ~ /^k8s_/) { split(name, a, "_"); name = "k8s: " a[2] }
      printf "%012.3f|  %-10s %6s  %s\n", n, u, $2, name }' | sort -r | cut -d'|' -f2-
  local df; df=$(docker system df -v 2>/dev/null)
  print -P "\n%BDisk%b"
  docker system df | sed 's/^/  /'
  print -P "\n%BImages by repository%b (unique size, count; clean with: docker_clean images <repo>)"
  print -r -- "$df" | awk '/^Images space usage/{f=1;next} /^Containers space usage/{f=0} f && NF>=8 && $1!="REPOSITORY" {
      u=$(NF-1); n=u+0; if (u ~ /kB$/) n/=1e6; else if (u ~ /MB$/) n/=1e3; else if (u !~ /GB$/) n/=1e9
      c[$1]++; s[$1]+=n } END { for (r in c) printf "%7.2f GB  %3d  %s\n", s[r], c[r], r }' | sort -r | head -12 | sed 's/^/  /'
  print -P "\n%BVolumes no container uses%b (app data! docker_clean volumes asks one by one)"
  print -r -- "$df" | awk '/^Local Volumes space usage/{f=1;next} /^Build cache usage/{f=0}
      f && NF==3 && $1!="VOLUME" && $2=="0" {
        u=$3; n=u+0; if (u ~ /GB$/) n*=1e9; else if (u ~ /MB$/) n*=1e6; else if (u ~ /kB$/) n*=1e3
        if (n >= 1e6) printf "%015.0f|  %-9s %s\n", n, u, $1; else small++ }
      END { if (small) printf "000000000000000|  (+ %d small or empty ones under 1 MB)\n", small }' | sort -r | cut -d'|' -f2-
  print -P "\n%BStopped containers%b (docker_clean containers)"
  docker ps -a --filter status=exited --filter status=created --format '{{.Status}}|{{.Names}}' | awk -F'|' '
    { name = $2; if (name ~ /^k8s_/) { split(name, a, "_"); name = "k8s: " a[2] }
      printf "  %-28s %s\n", $1, name }'
  return 0
}

# Images that must stay: pinned in the manifest (docker= / @image), or used by a
# container. Prints name:tag, short image IDs and pin digests (sha256:…): pinned
# images are pulled by digest, so they show as <repo>:<none> with no tag to match.
_docker_protected() {
  local m="${COMPONENTS_MANIFEST:-$HOME/.config/components/components.conf}"
  local -a pins
  pins=( $(grep -oE 'docker=[^[:space:]]+' "$m" 2>/dev/null | sed 's/^docker=//')
         $(awk '$1=="@image" {print $3}' "$m" 2>/dev/null) )
  { print -rl -- ${pins%%@*}                       # name:tag
    print -rl -- ${(M)${pins##*@}:#sha256:*}       # digest
    docker ps -a --format '{{.Image}}' | sed -E 's/@sha256:.*//'
    # and by image ID: another tag of the same image counts as in use
    docker ps -aq | xargs docker inspect -f '{{.Image}}' 2>/dev/null | sed 's/^sha256://' | cut -c1-12
  } | sort -u
}

docker_clean() {
  emulate -L zsh
  local what="$1" ans
  docker info >/dev/null 2>&1 || { echo "Docker isn't reachable (start Colima: costart)"; return 1; }
  case "$what" in
    cache)
      docker builder du 2>/dev/null | tail -1
      read -q "ans?Remove all build cache (next builds are slower)? [y/N] "; echo
      [[ $ans == y ]] && docker builder prune -af ;;
    dangling)
      docker images -f dangling=true
      read -q "ans?Remove these untagged images? [y/N] "; echo
      [[ $ans == y ]] && docker image prune -f ;;
    images)
      local repo="$2" keep="${3:-3}" dry=0
      [[ "$4" == "-n" || "$3" == "-n" ]] && dry=1 && [[ "$3" == "-n" ]] && keep=3
      [[ -n "$repo" && "$keep" == <-> ]] || { echo "usage: docker_clean images <repo> [keep=3] [-n]"; return 1; }
      local -a protected doomed; protected=( ${(f)"$(_docker_protected)"} )
      local line ref id dig i=0
      # newest first; keep the newest $keep, plus anything protected
      for line in ${(f)"$(docker images --digests "$repo" --format '{{.CreatedAt}}|{{.Repository}}:{{.Tag}}|{{.ID}}|{{.Digest}}' | sort -r)"}; do
        local -a f; f=( "${(@s:|:)line}" ); ref=$f[2]; id=$f[3]; dig=$f[4]; (( i++ ))
        (( i <= keep )) && { echo "  keep  $ref (newest $keep)"; continue }
        if (( ${protected[(Ie)$ref]} || ${protected[(Ie)$id]} || ${protected[(Ie)$dig]} )); then
          echo "  keep  $ref ${dig:+(${dig:0:19}…) }(pinned or used by a container)"; continue
        fi
        # an untagged image is removed by ID (name:<none> isn't a valid reference)
        [[ $ref == *:\<none\> ]] && ref=$id
        doomed+=("$ref")
      done
      (( ${#doomed} )) || { echo "Nothing to remove."; return 0 }
      printf '  rm    %s\n' "${doomed[@]}"
      (( dry )) && { echo "(dry run: nothing removed)"; return 0 }
      read -q "ans?Remove these ${#doomed} images? [y/N] "; echo
      [[ $ans == y ]] && docker rmi "${doomed[@]}" >/dev/null && echo "Removed ${#doomed}." && docker system df | sed -n '1,2p' ;;
    containers)
      docker ps -a --filter status=exited --filter status=created --format '  {{.Names}}  ({{.Image}}, {{.Status}})'
      read -q "ans?Remove all stopped containers? [y/N] "; echo
      [[ $ans == y ]] && docker container prune -f ;;
    volumes)
      local v size
      for v in $(docker volume ls -q --filter dangling=true); do
        [[ $v == signoz-* ]] && continue
        size=$(docker system df -v 2>/dev/null | awk -v v="$v" '$1==v {print $3}')
        read -q "ans?Delete volume $v ($size)? Its data is lost. [y/N] "; echo
        [[ $ans == y ]] && docker volume rm "$v" >/dev/null && echo "  deleted $v"
      done ;;
    *)
      cat <<'EOF'
usage: docker_clean <what>        (see docker_usage first; each step asks before deleting)
  cache                    build cache
  dangling                 untagged images
  images <repo> [N] [-n]   all tags of <repo> except the newest N (default 3); -n = dry run.
                           Keeps images pinned in the components manifest or used by a container.
  containers               stopped containers
  volumes                  unused volumes, one by one (never signoz-*)
Afterwards, give the space back to macOS (the VM disk file doesn't shrink by itself):
  colima ssh -- sudo fstrim -av
EOF
      return 1 ;;
  esac
}

# Optional: switch to containerd+nerdctl (advanced)
# alias costart_ctd='colima start --runtime containerd --kubernetes'
# Then use: nerdctl ps / nerdctl build ...

# ---------------------------------------------------------------------
# 65) secrets helper
# ---------------------------------------------------------------------