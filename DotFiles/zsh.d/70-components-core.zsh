# 70) components core & toolup
#
# The approved list of components is the manifest
#   $COMPONENTS_MANIFEST  (default ~/.config/components/components.conf)
# Only versions listed there can be activated: use_<tool>, toolup, defaults and
# completion all go through components_resolve. The toolshelf MCP server reads
# the same file, so your shell and AI agents always agree.
# Design & runbooks: Docs/AgentComponents.md

# Base folder for all portable tools (respect an existing value)
export COMPONENTS="${COMPONENTS:-$HOME/Components}"
export COMPONENTS_MANIFEST="${COMPONENTS_MANIFEST:-${XDG_CONFIG_HOME:-$HOME/.config}/components/components.conf}"

zmodload -F zsh/stat b:zstat 2>/dev/null

# --- MANIFEST -------------------------------------------------------------

# Parsed manifest (CM_ = components manifest)
typeset -ga CM_TOOLS          # tool names, in manifest order
typeset -gA CM_DIR            # tool -> folder under $COMPONENTS
typeset -gA CM_ROOT           # tool -> home candidates, "|"-separated
typeset -gA CM_BIN            # tool -> bin candidates, "|"-separated
typeset -gA CM_CHECK          # tool -> binary that must exist in bin
typeset -gA CM_HOMEENV        # tool -> env vars set to the home, space-separated
typeset -gA CM_VERSIONS       # tool -> approved versions, space-separated, sorted
typeset -gA CM_DEFAULT        # tool -> default version
typeset -gA CM_AUTOLOAD       # tool -> version activated at interactive login
typeset -gA CM_ONPATH         # tool -> version whose bin dir is put on PATH at login (no activation)
typeset -gA CM_DOCKER         # "tool:version" -> pinned image
typeset -ga CM_ERRORS
typeset -g  CM_MTIME=""
# Result of components_resolve
typeset -g  CM_V="" CM_HOME="" CM_BIN_DIR=""

# Parse the manifest. On any error nothing is loaded (same rule as the MCP server).
components_load() {
  emulate -L zsh
  local file="$COMPONENTS_MANIFEST" line name ver kv k val flag n=0
  local -a words errs tools
  local -A dir root bin check homeenv versions defaults autoload onpath docker

  CM_TOOLS=() CM_DIR=() CM_ROOT=() CM_BIN=() CM_CHECK=() CM_HOMEENV=()
  CM_VERSIONS=() CM_DEFAULT=() CM_AUTOLOAD=() CM_ONPATH=() CM_DOCKER=() CM_ERRORS=()
  CM_MTIME=""

  if [[ ! -f "$file" ]]; then
    CM_ERRORS=("manifest not found: $file (deploy dotfiles: install_copy.sh deploy)")
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    (( n++ ))
    words=(${=${line%%\#*}})
    (( $#words )) || continue

    if [[ "$words[1]" == "@tool" ]]; then
      name="$words[2]"
      if [[ -z "$name" ]]; then errs+=("line $n: @tool needs a name"); continue; fi
      if (( ${tools[(Ie)$name]} )); then errs+=("line $n: duplicate @tool $name"); continue; fi
      for kv in "${(@)words[3,-1]}"; do
        k="${kv%%=*}"; val="${kv#*=}"
        case "$k" in
          dir)   dir[$name]="$val" ;;
          root)  root[$name]="$val" ;;
          bin)   bin[$name]="$val" ;;
          check) check[$name]="$val" ;;
          home)  homeenv[$name]="${val//,/ }" ;;
          *)     errs+=("line $n: unknown @tool key \"$kv\"") ;;
        esac
      done
      [[ -n "$dir[$name]" ]] || errs+=("line $n: @tool $name needs dir=")
      tools+=("$name")
      continue
    fi

    if [[ "$words[1]" == @* ]]; then errs+=("line $n: unknown directive $words[1]"); continue; fi

    name="$words[1]" ver="$words[2]"
    if ! (( ${tools[(Ie)$name]} )); then errs+=("line $n: version for undefined tool \"$name\""); continue; fi
    if [[ -z "$ver" ]]; then errs+=("line $n: missing version"); continue; fi
    if [[ " $versions[$name] " == *" $ver "* ]]; then errs+=("line $n: duplicate $name $ver"); continue; fi
    versions[$name]+=" $ver"
    for flag in "${(@)words[3,-1]}"; do
      case "$flag" in
        default)
          if [[ -n "$defaults[$name]" ]]; then errs+=("line $n: second default for $name")
          else defaults[$name]="$ver"; fi ;;
        autoload)
          if [[ -n "$autoload[$name]" ]]; then errs+=("line $n: second autoload for $name")
          else autoload[$name]="$ver"; fi ;;
        onpath)
          if [[ -n "$onpath[$name]" ]]; then errs+=("line $n: second onpath for $name")
          else onpath[$name]="$ver"; fi ;;
        docker=*)
          docker[$name:$ver]="${flag#docker=}"
          [[ "${flag#docker=}" =~ '@sha256:[0-9a-f]{64}$' ]] || \
            errs+=("line $n: docker image must be pinned by digest (image@sha256:<64 hex>)") ;;
        *) errs+=("line $n: unknown flag \"$flag\"") ;;
      esac
    done
  done < "$file"

  for name in ${(k)onpath}; do
    [[ -n "$autoload[$name]" ]] && errs+=("$name: autoload and onpath are exclusive (autoload already puts it on PATH)")
  done

  if (( $#errs )); then
    CM_ERRORS=("invalid manifest $file:" "${errs[@]}")
    return 1
  fi

  CM_TOOLS=("${tools[@]}")
  CM_DIR=("${(@kv)dir}") CM_ROOT=("${(@kv)root}") CM_BIN=("${(@kv)bin}")
  CM_CHECK=("${(@kv)check}") CM_HOMEENV=("${(@kv)homeenv}")
  CM_DEFAULT=("${(@kv)defaults}") CM_AUTOLOAD=("${(@kv)autoload}") CM_ONPATH=("${(@kv)onpath}") CM_DOCKER=("${(@kv)docker}")
  for name in "${tools[@]}"; do
    CM_VERSIONS[$name]="${(j: :)${(on)${=versions[$name]}}}"   # numeric-aware sort
  done
  CM_MTIME="$(zstat +mtime -- "$file" 2>/dev/null)"
  return 0
}

# Reload when the manifest changed since the last load; print errors once.
components_ensure_loaded() {
  local mtime
  mtime="$(zstat +mtime -- "$COMPONENTS_MANIFEST" 2>/dev/null)"
  if [[ -z "$CM_MTIME" || "$mtime" != "$CM_MTIME" ]]; then
    if ! components_load; then
      print -u2 -l -- "${(@)CM_ERRORS/#/components: }"
      return 1
    fi
  fi
}

components_reload() {
  CM_MTIME=""
  components_ensure_loaded && echo "components: loaded ${#CM_TOOLS} tools from $COMPONENTS_MANIFEST"
}

# components_resolve <tool> [version]
# Exact version, or a unique prefix on a segment boundary ("17" → 17,
# "3.9" → 3.9.12; "2" never matches 25). Empty → manifest default.
# Sets CM_V (version), CM_HOME (tool home) and CM_BIN_DIR (bin dir).
components_resolve() {
  emulate -L zsh
  local tool="$1" q="$2" v base cand home bindir
  local -a vers matches
  CM_V="" CM_HOME="" CM_BIN_DIR=""

  components_ensure_loaded || return 1
  if ! (( ${CM_TOOLS[(Ie)$tool]} )); then
    print -u2 "components: unknown tool \"$tool\". Known: ${CM_TOOLS[*]}"
    return 1
  fi
  vers=(${=CM_VERSIONS[$tool]})

  if [[ -z "$q" ]]; then
    v="$CM_DEFAULT[$tool]"
    [[ -n "$v" ]] || { print -u2 "$tool: no default version. Approved: ${vers[*]:-none}"; return 1; }
  elif (( ${vers[(Ie)$q]} )); then
    v="$q"
  else
    matches=(${(M)vers:#${(b)q}.*} ${(M)vers:#${(b)q}-*})
    if (( $#matches > 1 )); then
      print -u2 "$tool: \"$q\" is ambiguous: ${matches[*]}"
      return 1
    fi
    v="$matches[1]"
    if [[ -z "$v" ]]; then
      print -u2 "$tool $q is not approved. Approved: ${vers[*]:-none}"
      print -u2 "  (to approve it, add a line to $COMPONENTS_MANIFEST)"
      return 1
    fi
  fi

  base="$COMPONENTS/$CM_DIR[$tool]/$v"
  [[ -d "$base" ]] || { print -u2 "$tool $v: approved but missing on disk ($base)"; return 1; }
  for cand in ${(s:|:)${CM_ROOT[$tool]:-.}}; do
    [[ -d "$base/$cand" ]] && { home="$base/$cand"; home="${home%/.}"; break; }
  done
  [[ -n "$home" ]] || { print -u2 "$tool $v: no tool home (${CM_ROOT[$tool]}) under $base"; return 1; }
  for cand in ${(s:|:)${CM_BIN[$tool]:-bin}}; do
    if [[ -d "$home/$cand" ]] && [[ -z "$CM_CHECK[$tool]" || -x "$home/$cand/$CM_CHECK[$tool]" ]]; then
      bindir="$home/$cand"; break
    fi
  done
  [[ -n "$bindir" ]] || { print -u2 "$tool $v: no ${CM_CHECK[$tool]:-bin dir} under $home"; return 1; }

  CM_V="$v" CM_HOME="$home" CM_BIN_DIR="$bindir"
}

# components_is_approved <tool> <exact-version>
components_is_approved() {
  components_ensure_loaded 2>/dev/null || return 1
  (( ${${=CM_VERSIONS[$1]}[(Ie)$2]} ))
}

# components_list <tool> [label] — approved versions with flags and health.
components_list() {
  emulate -L zsh
  local tool="$1" label="${2:-$1}" v d
  local -a flags extra
  components_ensure_loaded || return 1
  echo "Available $label versions:"
  for v in ${=CM_VERSIONS[$tool]}; do
    flags=()
    [[ "$CM_DEFAULT[$tool]" == "$v" ]] && flags+=(default)
    [[ "$CM_AUTOLOAD[$tool]" == "$v" ]] && flags+=(autoload)
    [[ "$CM_ONPATH[$tool]" == "$v" ]] && flags+=(onpath)
    [[ -n "$CM_DOCKER[$tool:$v]" ]] && flags+=(docker)
    if components_resolve "$tool" "$v" 2>/dev/null; then
      echo "  $v${flags:+ (${(j:, :)flags})}"
    else
      echo "  $v  ! broken: $(components_resolve "$tool" "$v" 2>&1 >/dev/null)"
    fi
  done
  for d in "$COMPONENTS/$CM_DIR[$tool]"/*(/N:t); do
    (( ${${=CM_VERSIONS[$tool]}[(Ie)$d]} )) || extra+=("$d")
  done
  (( $#extra )) && echo "  (on disk, not approved: ${extra[*]})"
  return 0
}

# components_check — health of the whole manifest.
components_check() {
  emulate -L zsh
  local tool
  components_ensure_loaded || return 1
  echo "Manifest: $COMPONENTS_MANIFEST"
  for tool in "${CM_TOOLS[@]}"; do
    [[ -n "$CM_VERSIONS[$tool]" ]] || continue
    components_list "$tool" | sed "1s/.*/$tool:/"
  done
}

# components_activate <tool> <label> <state-var> [version]
# Resolve, export home env vars, swap PATH, record status. Prints nothing.
components_activate() {
  local tool="$1" label="$2" var="$3" e
  components_resolve "$tool" "$4" || return 1
  for e in ${=CM_HOMEENV[$tool]}; do export "$e=$CM_HOME"; done
  component_switch_path "$var" "$CM_BIN_DIR"
  component_set_status "$label" "$CM_V"
}

# components_deactivate <tool> <label> <state-var>
components_deactivate() {
  local tool="$1" label="$2" var="$3" e
  component_switch_path "$var" ""
  components_ensure_loaded 2>/dev/null
  for e in ${=CM_HOMEENV[$tool]}; do unset "$e"; done
  component_set_status "$label" "off"
}

# --- CORE PATH HELPER ---

# Helper to remove an old path (stored in a var name) and add a new one
component_switch_path() {
  local var_name="$1"      # e.g. "JAVA_ACTIVE_BIN"
  local new_path="$2"

  # 1. Read the old path from the variable name provided
  local old_path="${(P)var_name}"

  # 2. Remove old path from PATH if it exists
  if [[ -n "$old_path" ]]; then
    path=(${path:#$old_path})
  fi

  # 3. Add new path
  if [[ -n "$new_path" ]]; then
    # Prepend to PATH (components override system/Homebrew)
    path=("$new_path" $path)
    # 4. Update the state variable
    typeset -g "$var_name=$new_path"
  else
    # clear state if no new path
    unset "$var_name"
  fi
}

# --- STATUS & TRACKING ---

# Associative array to track what is active
typeset -gA COMPONENTS_STATUS

# Usage: component_set_status "JDK" "17"
component_set_status() {
  local name="$1"
  local ver="$2"
  if [[ -z "$ver" || "$ver" == "off" ]]; then
    unset "COMPONENTS_STATUS[$name]"
  else
    COMPONENTS_STATUS[$name]="$ver"
  fi
}

# Usage: components_status
components_status() {
  print -P "%BActive Components:%b"
  if (( ${#COMPONENTS_STATUS} == 0 )); then
    echo "  (none)"
    return
  fi
  for k in "${(@k)COMPONENTS_STATUS}"; do
    echo "  $k: ${COMPONENTS_STATUS[$k]}"
  done
}
alias status_components='components_status'

# Usage: components_prompt_info
# Can be used in your PROMPT or Starship config
components_prompt_info() {
  local parts=()
  for k in "${(@k)COMPONENTS_STATUS}"; do
    parts+=("$k:${COMPONENTS_STATUS[$k]}")
  done
  echo "${parts[*]}"
}


# --- GENERIC COMPLETION ---

# _components_comp <tool> — completes approved versions from the manifest
# Usage in other files: load_components_completion use_jdk jdk
_components_comp() {
  components_ensure_loaded 2>/dev/null || return 1
  local -a vers
  vers=(${=CM_VERSIONS[$1]})
  _arguments "1:version:($vers off)"
}

load_components_completion() {
  local func_name="$1"
  local tool="$2"
  (( $+functions[compdef] )) && compdef "_components_comp $tool" "$func_name"
}

# --- LOAD + DEFAULTS ---

# Load once at startup; export DEFAULT_<TOOL> for modules that read them
# (e.g. DEFAULT_REDIS, DEFAULT_MYSQL). Login autoload happens in 79-defaults.
if components_ensure_loaded; then
  for _cm_t in "${(@k)CM_DEFAULT}"; do
    export "DEFAULT_${(U)_cm_t}=${CM_DEFAULT[$_cm_t]}"
  done
  unset _cm_t
fi

# --- TOOLUP ---

# Reset PATH to baseline (used by toolup)
_path_base() {
  # Reset to: Homebrew > System   (typeset -U path deduplicates)
  path=(/usr/local/bin /usr/bin /bin /usr/sbin /sbin)

  if [ -d "/opt/homebrew/bin" ]; then
    path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
  fi

  if [ -d "/opt/homebrew/opt/mysql-client/bin" ]; then
    path=(/opt/homebrew/opt/mysql-client/bin $path)
  fi
}

# toolup — apply .toolsrc. Versions must be approved in the manifest
# (exact or unique prefix, same as use_<tool>). Returns 1 if any failed.
toolup() {
  local cfg=".toolsrc" line key val fn
  local -a failed
  [[ ! -f "$cfg" ]] && { echo "No $cfg in $(pwd)"; return 1; }
  _path_base
  COMPONENTS_STATUS=() # Reset status

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    key="${line%%=*}"; val="${line#*=}"
    case "$key" in
      JDK|MAVEN|GRADLE|ANT|NODE|GO|PYTHON|PROTOBUF|REDIS|RUST)
        [[ -n "$val" ]] || continue
        fn="use_${(L)key}"
        "$fn" "$val" || failed+=("$key=$val")
        ;;
      MYSQL_DEFAULT_VER) use_mysql "$val" || failed+=("$key=$val") ;;   # active client version
      MYSQL_START_VER) mysql_start "$val" || failed+=("$key=$val") ;;
      MYSQL_STOP_VER) mysql_stop "$val" || failed+=("$key=$val") ;;
      PATH_PREPEND) export PATH="$val:$PATH" ;;
      EXPORT) eval "export ${val}" ;;
      *) echo "Unknown directive in .toolsrc: $key"; failed+=("$key") ;;
    esac
  done < "$cfg"
  if (( $#failed )); then
    echo "⚠️  toolup: failed: ${failed[*]}"
    components_status
    return 1
  fi
  echo "Activated from $cfg"
  components_status
}

# mkbin helper
mkbin() {
  mkdir -p .bin
  export PATH="$PWD/.bin:$PATH"
  echo "Using .bin at $PWD/.bin"
}
