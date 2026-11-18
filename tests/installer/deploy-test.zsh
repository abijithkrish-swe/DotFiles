# deploy-test.zsh — install_copy.sh deploy/agents into throwaway fake homes.
#
#   zsh -f tests/installer/deploy-test.zsh
#
# Guards against the installer stopping silently under `set -e`: a function
# whose last command is a false `[ test ] && …` returns 1, and inside the
# `deploy_pairs | while …` loops that ended the whole run after the backup,
# before anything was applied. The fake homes are small on purpose: never
# copy real ~/.config folders (Colima's holds a 100 GB VM disk).
emulate -L zsh
here="${${(%):-%x}:A:h}"
repo="${here:h:h}"
tmp="${TMPDIR:-/tmp}"
local -i ok=0 bad=0
check() { if eval "$2"; then (( ok++ )); print -r -- "ok  $1"; else (( bad++ )); print -r -- "XX  $1"; fi }

mkhome() {   # minimal home + the states that used to break deploy
  local h=$(mktemp -d "$tmp/deploy-test-home.XXXXXX")
  mkdir -p $h/.config/colima/default $h/.config/git $h/.zsh.d
  print 'cpu: 2' >| $h/.config/colima/default/colima.yaml   # a VM's own file, no template yet
  print -r -- "[user]\n  name = Test\n  email = test@example.com" >| $h/.config/git/identity
  print -r -- "$h"
}

# 1. deploy completes and applies everything
h=$(mkhome)
out=$(cd $repo && HOME=$h sh install_copy.sh deploy --force 2>&1); rc=$?
check "deploy exits 0"                             "(( rc == 0 ))"
check "deploy reports completion"                  "[[ \$out == *'deploy complete'* ]]"
check "~/.zshrc deployed"                          "cmp -s $repo/DotFiles/zshrc $h/.zshrc"
check "~/.zsh.d mirrored (same file list)"         "[[ \"\$(cd $repo/DotFiles/zsh.d && find . -type f | sort)\" == \"\$(cd $h/.zsh.d && find . -type f | sort)\" ]]"
check "merge dir that existed without the repo file gets it (colima template)" "[[ -f $h/.config/colima/_templates/default.yaml ]]"
check "the VM's own colima file is left alone"     "[[ \$(<$h/.config/colima/default/colima.yaml) == 'cpu: 2' ]]"
check "a new config dir is created (signoz)"       "[[ -f $h/.config/signoz/casting.yaml ]]"
rm -rf $h

# 2. agents with only ~/.claude (no ~/.config/claude-personal), and with neither
h=$(mkhome); mkdir -p $h/.claude
(cd $repo && HOME=$h sh install_copy.sh deploy --force >/dev/null 2>&1)
out=$(cd $repo && HOME=$h sh install_copy.sh agents 2>&1); rc=$?
check "agents exits 0 with only ~/.claude"         "(( rc == 0 ))"
check "agents merged ~/.claude/settings.json"      "grep -q guard.sh $h/.claude/settings.json"
check "telemetry label for ~/.claude is claude"    "grep -q '\"OTEL_RESOURCE_ATTRIBUTES\": \"agent.config=claude\"' $h/.claude/settings.json"
check "telemetry goes to 127.0.0.1 (not localhost)" "grep -q '\"OTEL_EXPORTER_OTLP_ENDPOINT\": \"http://127.0.0.1:4317\"' $h/.claude/settings.json"
# both configs: each gets its own label; an existing env key of the user's is kept
mkdir -p $h/.config/claude-personal
print -r -- '{"env": {"MY_OWN_VAR": "keep-me"}}' >| $h/.config/claude-personal/settings.json
out=$(cd $repo && HOME=$h sh install_copy.sh agents 2>&1); rc=$?
check "agents exits 0 with both configs"           "(( rc == 0 ))"
check "telemetry label for claude-personal is myclaude" "grep -q '\"OTEL_RESOURCE_ATTRIBUTES\": \"agent.config=myclaude\"' $h/.config/claude-personal/settings.json"
check "the user's own env keys are kept"           "grep -q '\"MY_OWN_VAR\": \"keep-me\"' $h/.config/claude-personal/settings.json"
check "a re-run changes nothing"                   "[[ \"\$(cd $repo && HOME=$h sh install_copy.sh agents 2>&1 | grep -c 'env\\.')\" == 0 ]]"
rm -rf $h/.claude $h/.config/claude-personal
out=$(cd $repo && HOME=$h sh install_copy.sh agents 2>&1); rc=$?
check "agents exits 0 with no Claude config at all" "(( rc == 0 ))"
rm -rf $h

# 3. fold-back warns when both sides changed (2026-11-19: folding the home
# manifest dropped a docker pin the repo had). Answers go to /dev/tty, so
# `script` gives the run a terminal. Only "q" is ever sent: it aborts before
# anything is written, so the real repo is never touched.
h=$(mkhome)
(cd $repo && HOME=$h sh install_copy.sh deploy --force >/dev/null 2>&1)
conf=$h/.config/components/components.conf
repo_line=$(grep -m1 '^node .*docker=' $conf)
grep -vxF -- "$repo_line" $conf >| $conf.new && print 'jdk       99.0.1' >> $conf.new && mv $conf.new $conf
before=$(cd $repo && git status --porcelain)
out=$(cd $repo && { sleep 3; print q; sleep 1 } | HOME=$h script -q /dev/null sh install_copy.sh deploy 2>&1 | tr -d '\r')
check "fold warns that the repo has lines home lacks" "[[ \$out == *'[y] fold would DROP them from the repo'* ]]"
check "it names the repo-only line"                 "[[ \$out == *\"repo only: \$repo_line\"* ]]"
check "and the home-only line"                      "[[ \$out == *'home only: jdk       99.0.1'* ]]"
check "q aborts with nothing written"               "[[ \$out == *'deploy aborted. Nothing was written.'* && \"\$(cd $repo && git status --porcelain)\" == \"\$before\" ]]"
(( bad )) && print -r -- "--- deploy output (last 15 lines):" && print -r -- "${(F)${(f)out}[-15,-1]}"
rm -rf $h

print "\n$ok passed, $bad failed"
(( bad == 0 ))
