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
typeset -gA CM_IMAGES         # helper name -> pinned image (@image lines)
typeset -ga CM_ERRORS
typeset -g  CM_MTIME=""
# Result of components_resolve
typeset -g  CM_V="" CM_HOME="" CM_BIN_DIR=""

# Parse the manifest. On any error nothing is loaded (same rule as the MCP server).
components_load() {
  emulate -L zsh
  local file="$COMPONENTS_MANIFEST" line name ver kv k val flag n=0
  local -a words errs tools
  local -A dir root bin check homeenv versions defaults autoload onpath docker images

  CM_TOOLS=() CM_DIR=() CM_ROOT=() CM_BIN=() CM_CHECK=() CM_HOMEENV=()
  CM_VERSIONS=() CM_DEFAULT=() CM_AUTOLOAD=() CM_ONPATH=() CM_DOCKER=() CM_IMAGES=() CM_ERRORS=()
  CM_MTIME=""

  if [[ ! -f "$file" ]]; then
    CM_ERRORS=("manifest not found: $file (deploy dotfiles: install_copy.sh deploy)")
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    (( n++ ))
    line="${line%$'\r'}"             # CRLF files: same as toolshelf, which trims it
    words=(${=${line%%\#*}})
    (( $#words )) || continue

    if [[ "$words[1]" == "@tool" ]]; then
      name="$words[2]"
      if [[ -z "$name" ]]; then errs+=("line $n: @tool needs a name"); continue; fi
      if (( ${tools[(Ie)$name]} )); then errs+=("line $n: duplicate @tool $name"); continue; fi
      for kv in "${(@)words[3,-1]}"; do
        # key=value only: a bare "dir" must not silently mean dir=dir
        if [[ "$kv" != ?*=* ]]; then errs+=("line $n: unknown @tool key \"$kv\""); continue; fi
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

    # @image <name> <image@sha256:digest> — helper images (e.g. the docker-mode proxy forwarder)
    if [[ "$words[1]" == "@image" ]]; then
      if [[ -z "$words[2]" || -z "$words[3]" ]]; then errs+=("line $n: @image needs a name and an image"); continue; fi
      [[ "$words[3]" =~ '@sha256:[0-9a-f]{64}$' ]] || errs+=("line $n: @image $words[2] must be pinned by digest (image@sha256:<64 hex>)")
      images[$words[2]]="$words[3]"
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
  CM_DEFAULT=("${(@kv)defaults}") CM_AUTOLOAD=("${(@kv)autoload}") CM_ONPATH=("${(@kv)onpath}") CM_DOCKER=("${(@kv)docker}") CM_IMAGES=("${(@kv)images}")
  for name in "${tools[@]}"; do
    # numeric-aware sort; (@) + (s: :) because ${=…} doesn't split inside quotes
    CM_VERSIONS[$name]="${(j: :)${(@on)${(s: :)versions[$name]}}}"
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

# components_match <tool> [version] — pick the approved version, no disk check.
# Exact version, or a unique prefix on a segment boundary ("17" → 17,
# "3.9" → 3.9.12; "2" never matches 25). Empty → manifest default. Sets CM_V.
components_match() {
  emulate -L zsh
  local tool="$1" q="$2" v
  local -a vers matches
  CM_V=""

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
  CM_V="$v"
}

# components_resolve <tool> [version]
# components_match, then locate it on disk.
# Sets CM_V (version), CM_HOME (tool home) and CM_BIN_DIR (bin dir).
components_resolve() {
  emulate -L zsh
  local tool="$1" q="$2" v base cand home bindir
  CM_HOME="" CM_BIN_DIR=""

  components_match "$tool" "$q" || return 1
  v="$CM_V"; CM_V=""

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

# components_requests [clear] — versions AI agents asked for via the toolshelf
# MCP (request_component). Agents never install; you decide. `clear` archives
# the list to requests.done.jsonl.
components_requests() {
  emulate -L zsh
  local dir="${TOOLSHELF_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/toolshelf}"
  local file="$dir/requests.jsonl"
  if [[ "$1" == "clear" ]]; then
    [[ -s "$file" ]] || { echo "No pending requests."; return 0; }
    cat "$file" >> "$dir/requests.done.jsonl" && : >| "$file"
    echo "Archived to $dir/requests.done.jsonl"
    return 0
  fi
  [[ -s "$file" ]] || { echo "No pending requests."; return 0; }
  echo "Component requests from agents ($file):"
  /usr/bin/perl -MJSON::PP -ne '
    my $r = eval { decode_json($_) } or next;
    printf "  %d. %s  %s %s — %s%s\n", $., substr($r->{ts}, 0, 10), $r->{tool}, $r->{version},
      $r->{reason}, $r->{project} ? "  ($r->{project})" : "";
  ' "$file"
  echo "Approve: install it, add it to the manifest (devhelp components). Then: components_requests clear"
}

# toolshelf_report [days] — what agents ran and what was stopped, from
# toolshelf's run logs (runs/*.log) and blocked.jsonl (written by the guard
# hook and by `run`). Read-only. Default: everything; `toolshelf_report 7` =
# the last week. Use it to tune blocklist.txt and Claude's permissions.allow.
toolshelf_report() {
  emulate -L zsh
  local dir="${TOOLSHELF_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/toolshelf}"
  local days="${1:-0}"
  [[ "$days" == <-> ]] || { echo "usage: toolshelf_report [days]"; return 1; }
  [[ -d "$dir" ]] || { echo "No toolshelf state yet ($dir)."; return 0; }
  /usr/bin/perl -CSD -MJSON::PP -MPOSIX=strftime - "$dir" "$days" <<'PERL'
use strict; use warnings;
my ($dir, $days) = @ARGV;
my $since = $days ? strftime('%Y%m%d-%H%M%S', localtime(time - $days * 86400)) : '';
my $since_iso = $days ? strftime('%Y-%m-%dT%H:%M:%SZ', gmtime(time - $days * 86400)) : '';
my $home = $ENV{HOME};
sub short { my ($s, $n) = @_; $s =~ s/\Q$home\E/~/g; $s =~ s/\s*\n\s*/ ⏎ /g; length($s) > $n ? substr($s, 0, $n - 1) . '…' : $s }
sub local_ts {   # 2026-11-10T22:50:46Z -> local "2026-11-11 04:20"
  my @p = $_[0] =~ /^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)/ or return $_[0];
  require Time::Local;
  strftime('%Y-%m-%d %H:%M', localtime(Time::Local::timegm($p[5], $p[4], $p[3], $p[2], $p[1] - 1, $p[0])));
}
sub top { my ($h, $n) = @_; (sort { $h->{$b} <=> $h->{$a} || $a cmp $b } keys %$h)[0 .. ($n < keys %$h ? $n : keys %$h) - 1] }

# --- runs --------------------------------------------------------------------
my (@runs, %mode, %exit, %proj, %pat);
my %multi = map { $_ => 1 } qw(git npm npx pnpm yarn cargo go docker kubectl pip pip3 uv gradle ./gradlew mvn ./mvnw);
for my $f (sort glob("$dir/runs/*.log")) {
  my ($id) = $f =~ m{/([^/]+)\.log$};
  next if $since && $id lt $since;
  open(my $fh, '<', $f) or next;
  my %r = (id => $id, cmd => '', denied => 0);
  my $in_cmd = 0;
  while (my $l = <$fh>) {
    chomp $l;
    if ($. == 1) { $r{mode} = $l =~ /\((\w+)/ ? $1 : 'sandbox'; next }
    if ($l =~ /^# cwd: (.*?)(?: → .*)?$/) { $r{cwd} = $1; next }
    if ($l =~ /^# command: (.*)$/) { $r{cmd} = $1; $in_cmd = 1; next }
    if ($in_cmd) { if ($l eq '') { $in_cmd = 0 } else { $r{cmd} .= "\n$l" } next }
    if ($l =~ /^# exit: (\S+)( \(timed out\))? after (\d+) ms/) { @r{qw(exit timeout ms)} = ($1, $2 ? 1 : 0, $3) }
    $r{denied}++ if $l =~ /operation not permitted/i;
  }
  $r{exit} //= 'unfinished'; $r{ms} //= 0;
  push @runs, \%r;
  $mode{$r{mode}}++;
  $exit{$r{timeout} ? 'timeout' : $r{exit}}++;
  $proj{$r{cwd} // '?'}++;
  (my $code = $r{cmd}) =~ s/<<-?\s*(['"]?)(\w+)\1([^\n]*)\n.*?(?:\n\s*\2\s*(?=\n|$)|$)/$3/sg;  # heredoc bodies
  $code =~ s/'[^']*'/''/g; $code =~ s/"(?:\\.|[^"\\])*"/""/g;                          # quoted text
  for my $seg (split /\s*(?:&&|\|\||[;|\n]|\$\()\s*/, $code) {
    $seg =~ s/^[\s({!]*(?:(?:if|then|else|elif|do|while|until|time)\s+)*//;   # (  {  !  keywords
    $seg =~ s/^(?:\w+=\S*\s+)*//;               # VAR=value prefixes
    my @w = split ' ', $seg or next;
    next if $w[0] =~ /^(for|done|fi|esac|case|in|\$|[)}\]])/;
    my $p = $w[0] =~ m{^\.?/} ? $w[0] : ($w[0] =~ m{([^/]+)$})[0];
    next if $p =~ /^(cd|echo|true|false|exit|\[\[?)$/;
    if ($p =~ /^python[\d.]*$/ && ($w[1] // '') eq '-m') { $p .= " -m " . ($w[2] // '') }
    elsif ($multi{$p} || $multi{$w[0]}) { my ($sub) = grep { !/^-/ } @w[1 .. $#w]; $p .= " $sub" if $sub }
    elsif ($p eq 'sed' && grep { /^-i/ } @w) { $p = 'sed -i' }
    $pat{$p}++;
  }
}

my $period = $days ? "last $days day" . ($days == 1 ? '' : 's') : 'all time';
print "toolshelf report ($period)\n", '=' x 40, "\n\n";
if (@runs) {
  my $fail = grep { $_->{exit} ne '0' } @runs;
  printf "Runs: %d  (%s)   failed or unfinished: %d\n", scalar @runs,
    join(', ', map { "$_ $mode{$_}" } sort keys %mode), $fail;
  print "  exit codes: ", join(', ', map { "$_ ×$exit{$_}" } top(\%exit, 10)), "\n";
  print "  projects:\n";
  printf "    %4d  %s\n", $proj{$_}, short($_, 70) for top(\%proj, 8);

  print "\nMost common commands (each step of && ; | counted):\n";
  printf "    %4d  %s\n", $pat{$_}, $_ for top(\%pat, 15);

  my @slow = (sort { $b->{ms} <=> $a->{ms} } @runs)[0 .. (@runs < 5 ? $#runs : 4)];
  print "\nSlowest:\n";
  printf "    %6.1fs  %s  %s\n", $_->{ms} / 1000, $_->{id}, short($_->{cmd}, 60) for @slow;

  my @failed = grep { $_->{exit} ne '0' } @runs;
  if (@failed) {
    print "\nFailed or unfinished (newest last):\n";
    printf "    %-10s %s  %s\n", $_->{timeout} ? 'timeout' : "exit $_->{exit}", $_->{id}, short($_->{cmd}, 56)
      for @failed[($#failed > 9 ? $#failed - 9 : 0) .. $#failed];
  }

  my @denied = grep { $_->{denied} } @runs;
  if (@denied) {
    print "\nHit a sandbox wall (\"operation not permitted\" in the output — even if exit 0):\n";
    printf "    %3d×  %s  %s\n", $_->{denied}, $_->{id}, short($_->{cmd}, 56) for @denied;
  }

  my @edits = grep { $_->{cmd} =~ /\bsed\s+-i|\bcat\s*>|\btee\s|>\s*\/tmp\// } @runs;
  if (@edits) {
    printf "\nRuns that edit files or write /tmp (%d) — agents should use their edit tools:\n", scalar @edits;
    printf "    %s  %s\n", $_->{id}, short($_->{cmd}, 62) for @edits[($#edits > 4 ? $#edits - 4 : 0) .. $#edits];
  }
} else {
  print "Runs: none\n";
}

# --- blocked -----------------------------------------------------------------
my @blk;
if (open(my $fh, '<:raw', "$dir/blocked.jsonl")) {
  while (<$fh>) { my $r = eval { decode_json($_) } or next; push @blk, $r if !$since_iso || $r->{ts} ge $since_iso }
}
print "\nBlocked attempts: ", scalar @blk, "\n";
if (@blk) {
  my (%why, %src);
  $why{$_->{reason}}++, $src{$_->{source}}++ for @blk;
  print "  by source: ", join(', ', map { "$_ $src{$_}" } sort keys %src), "\n";
  printf "    %4d  %s\n", $why{$_}, $_ for top(\%why, 10);
  print "  latest:\n";
  printf "    %s %-5s %s\n", local_ts($_->{ts}), $_->{source}, short($_->{command}, 60)
    for @blk[($#blk > 9 ? $#blk - 9 : 0) .. $#blk];
}

# --- requests ----------------------------------------------------------------
my $req = 0;
if (open(my $fh, '<', "$dir/requests.jsonl")) { $req++ while <$fh> }
print "\nPending component requests: $req", ($req ? "  (components_requests)" : ''), "\n";
print "\nFiles: $dir/{runs/, blocked.jsonl}\n";
PERL
}

# components_images [prune] — Docker images pinned in the manifest (docker=,
# @image): pulled or not, and size. Every pinned image is remembered in
# $TOOLSHELF_STATE/images.log (toolshelf's run adds the ones it uses), so
# `prune` can remove images that were pinned once and are retired now — and
# only those: your own images (e.g. node:22) are never touched.
components_images() {
  emulate -L zsh
  local dir="${TOOLSHELF_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/toolshelf}"
  local log="$dir/images.log" ref sz total=0 k
  local -a pinned retired gone
  components_ensure_loaded || return 1
  (( $+commands[docker] )) || { echo "docker CLI not found"; return 1; }
  docker info >/dev/null 2>&1 || { echo "Docker isn't running (start Colima: costart)."; return 1; }

  pinned=(${(u)${(v)CM_DOCKER}} ${(u)${(v)CM_IMAGES}})
  mkdir -p "$dir"; touch "$log"
  for ref in $pinned; do grep -qxF -- "$ref" "$log" || print -r -- "$ref" >> "$log"; done

  # inspect needs name@digest (it doesn't resolve the name:tag@digest form run/pull accept)
  _cm_size() { local r="$1"; docker image inspect --format '{{.Size}}' "${${r%%@*}%:*}@${r#*@}" 2>/dev/null }
  _cm_human() { awk -v b="$1" 'BEGIN { split("B KB MB GB", u); i = 1; while (b >= 1000 && i < 4) { b /= 1000; i++ } printf "%.1f %s", b, u[i] }' }

  echo "Pinned images (components manifest):"
  for k in ${(ko)CM_DOCKER} ${(ko)CM_IMAGES}; do
    ref="${CM_DOCKER[$k]:-$CM_IMAGES[$k]}"
    sz="$(_cm_size "$ref")"
    if [[ -n "$sz" ]]; then
      (( total += sz ))
      printf '  %-18s %-36s %s\n' "$k" "${ref%%@*}" "pulled, $(_cm_human $sz)"
    else
      printf '  %-18s %-36s %s\n' "$k" "${ref%%@*}" "not pulled (downloads on first docker run)"
    fi
  done
  echo "  total pulled: $(_cm_human $total)"

  for ref in ${(f)"$(<"$log")"}; do
    [[ -n "$ref" ]] || continue
    (( ${pinned[(Ie)$ref]} )) && continue
    if [[ -n "$(_cm_size "$ref")" ]]; then retired+=("$ref"); else gone+=("$ref"); fi
  done
  echo ""
  if (( $#retired )); then
    echo "Retired (no longer in the manifest, still on disk):"
    for ref in $retired; printf '  %-46s %s\n' "${ref%%@*}" "$(_cm_human $(_cm_size "$ref"))"
  else
    echo "No retired images on disk."
  fi

  if [[ "$1" == "prune" ]]; then
    (( $#retired )) || { echo "Nothing to prune."; }
    if (( $#retired )); then
      local ans
      print -n "Remove these ${#retired} image(s)? [y/N] "; read -r ans
      [[ "$ans" == [yY]* ]] || { echo "Kept."; return 0; }
      for ref in $retired; do
        docker image rm "$ref" >/dev/null 2>&1 && echo "  removed ${ref%%@*}" || echo "  could not remove ${ref%%@*} (in use?)"
      done
      gone+=($retired)
    fi
    # forget refs that are gone from disk and no longer pinned
    if (( $#gone )); then
      grep -vxF -f <(print -rl -- $gone) "$log" >| "$log.tmp"; mv "$log.tmp" "$log"
    fi
  elif (( $#retired )); then
    echo "Remove them with: components_images prune"
  fi
  unfunction _cm_size _cm_human
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
