# 64) observability: self-hosted SigNoz on Colima (local only)
#
#   obs_forge     casting.yaml → compose files (foundryctl, offline, pinned image)
#   obs_start     start SigNoz; waits until the UI answers
#   obs_stop      stop it (data kept)
#   obs_status    containers + health
#   obs_logs [s]  follow logs (all, or one service, e.g. signoz-signoz-0)
#   obs_down      remove the containers (data kept in docker volumes)
#
# UI http://localhost:18080 (port set in the casting's patch) · OTLP gRPC localhost:4317 · OTLP HTTP localhost:4318
# Input:  ~/.config/signoz/casting.yaml (dotfiles: DotFiles/config/signoz/), every
#         image pinned by digest, telemetry to SigNoz off.
# Output: ~/.local/share/signoz/pours/ (generated; never edit, re-forge instead).
# Data:   docker volumes signoz-*; removing them is a manual, deliberate step.
# Help:   devhelp observability

OBS_CASTING="${XDG_CONFIG_HOME:-$HOME/.config}/signoz/casting.yaml"
OBS_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/signoz"
OBS_COMPOSE="$OBS_HOME/pours/deployment/compose.yaml"

_obs_docker_ok() {
  (( $+commands[docker] )) || { print -u2 "obs: docker CLI not found"; return 1; }
  docker info >/dev/null 2>&1 || { print -u2 "obs: Docker isn't running (start Colima: costart)"; return 1; }
}
_obs_compose() { docker compose -p signoz -f "$OBS_COMPOSE" "$@"; }
# The UI's host port, from the generated compose (the casting's patch sets it):
# the host side of the "<host>:8080" mapping. Falls back to 18080.
_obs_ui_port() {
  local p
  p=$(grep -oE '"?[0-9]+:8080"?' "$OBS_COMPOSE" 2>/dev/null | head -1 | tr -d '"')
  print -r -- "${${p%%:*}:-18080}"
}
# SigNoz configures collectors (and so opens OTLP 4317/4318) only once an
# organization exists, i.e. after the first account is created in the UI.
_obs_needs_signup() { docker logs --since 5m signoz-signoz-0 2>&1 | grep -q 'cannot create agent without orgId'; }
_obs_signup_hint() {
  # only while OTLP is closed: old log lines linger after the account exists
  curl -sS --noproxy '*' -o /dev/null -m 3 http://localhost:4318/ 2>/dev/null && return 0
  _obs_needs_signup || return 0
  print "!!  First run: create the admin account at http://localhost:$(_obs_ui_port) (stored locally)."
  print "    Until then SigNoz doesn't configure the collector, so OTLP on 4317/4318 isn't open."
}

obs_forge() {
  emulate -L zsh
  local img
  [[ -f "$OBS_CASTING" ]] || { print -u2 "obs: no casting at $OBS_CASTING (install_copy.sh deploy)"; return 1; }
  _obs_docker_ok || return 1
  components_ensure_loaded || return 1
  img="${CM_IMAGES[foundryctl]:-}"
  [[ "$img" =~ '@sha256:[0-9a-f]{64}$' ]] || { print -u2 "obs: no pinned '@image foundryctl' in the components manifest"; return 1; }
  mkdir -p "$OBS_HOME"
  cp "$OBS_CASTING" "$OBS_HOME/casting.yaml"
  rm -rf "$OBS_HOME/pours.new"
  # Offline (no network), as you, telemetry and update checks off.
  docker run --rm --network none --user "$(id -u):$(id -g)" -v "$OBS_HOME:/work" -w /work "$img" \
    forge -f /work/casting.yaml -p /work/pours.new --no-ledger --no-updater --format text >/dev/null \
    || { print -u2 "obs: forge failed"; rm -rf "$OBS_HOME/pours.new"; return 1; }
  if grep -E '^\s*image:' "$OBS_HOME/pours.new/deployment/compose.yaml" | grep -qv '@sha256:'; then
    print -u2 "obs: refusing: the generated compose has unpinned images:"
    grep -E '^\s*image:' "$OBS_HOME/pours.new/deployment/compose.yaml" | grep -v '@sha256:' >&2
    rm -rf "$OBS_HOME/pours.new"; return 1
  fi
  grep -q 'SIGNOZ_STATSREPORTER_ENABLED=false' "$OBS_HOME/pours.new/deployment/compose.yaml" \
    || { print -u2 "obs: refusing: the stats reporter isn't disabled in the generated compose"; rm -rf "$OBS_HOME/pours.new"; return 1; }
  rm -rf "$OBS_HOME/pours" && mv "$OBS_HOME/pours.new" "$OBS_HOME/pours"
  print "obs: forged $OBS_COMPOSE (all images pinned, telemetry off)"
}

obs_start() {
  emulate -L zsh
  local i
  _obs_docker_ok || return 1
  [[ -f "$OBS_COMPOSE" ]] || { obs_forge || return 1; }
  _obs_compose up -d --pull missing --quiet-pull || return 1
  printf 'obs: waiting for the UI'
  for i in {1..60}; do
    curl -fsS --noproxy '*' -o /dev/null http://localhost:$(_obs_ui_port)/api/v1/health 2>/dev/null && { print " — ready"; break; }
    printf '.'; sleep 3
  done
  (( i == 60 )) && print " — not answering yet (obs_status, obs_logs signoz-signoz-0)"
  print "UI   http://localhost:$(_obs_ui_port)\nOTLP grpc localhost:4317 · http localhost:4318"
  sleep 5; _obs_signup_hint
}

obs_stop()   { _obs_docker_ok && _obs_compose stop; }
obs_down()   { _obs_docker_ok && _obs_compose down; }   # volumes (data) are kept
obs_logs()   { _obs_docker_ok && _obs_compose logs -f --tail 100 "$@"; }
obs_status() {
  _obs_docker_ok || return 1
  [[ -f "$OBS_COMPOSE" ]] || { print "obs: not forged yet (obs_forge)"; return 0; }
  _obs_compose ps --format 'table {{.Service}}\t{{.State}}\t{{.Status}}'
  if curl -fsS --noproxy '*' -o /dev/null http://localhost:$(_obs_ui_port)/api/v1/health 2>/dev/null; then
    print "UI: http://localhost:$(_obs_ui_port) (healthy)"
  else
    print "UI: not answering"
  fi
  if curl -sS --noproxy '*' -o /dev/null -m 3 http://localhost:4318/ 2>/dev/null; then
    print "OTLP: http localhost:4318 answering"
  else
    print "OTLP: http localhost:4318 not answering"
  fi
  _obs_signup_hint
}
