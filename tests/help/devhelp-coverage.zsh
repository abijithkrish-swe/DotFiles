# devhelp-coverage.zsh — every user-facing function and alias in zsh.d appears
# in some devhelp topic (help/*.zsh).
#
#   zsh -f tests/help/devhelp-coverage.zsh
#
# Names starting with _ are internal. INTERNAL lists the public-looking helpers
# that other modules call but users don't type.
emulate -L zsh
here="${${(%):-%x}:A:h}"
zd="${here:h:h}/DotFiles/zsh.d"
INTERNAL=(components_load components_ensure_loaded components_match components_resolve
  components_is_approved components_list components_activate components_deactivate
  component_switch_path component_set_status components_prompt_info load_components_completion)

help=$(cat $zd/help/*.zsh $zd/zz-devhelp.zsh)
local -i bad=0
for f in $zd/[0-9]*.zsh; do
  names=( ${(f)"$(grep -oE '^(alias +[A-Za-z0-9_-]+=|[A-Za-z][A-Za-z0-9_-]*\(\) *\{|function +[A-Za-z][A-Za-z0-9_-]*)' $f \
    | sed -E 's/^alias +//; s/=$//; s/\(\).*//; s/^function +//')"} )
  missing=()
  for n in $names; do
    [[ $n == _* ]] && continue
    (( ${INTERNAL[(Ie)$n]} )) && continue
    print -r -- "$help" | grep -qw -- "$n" || missing+=$n
  done
  if (( ${#missing} )); then (( bad++ )); print -r -- "XX  ${f:t}: ${missing[*]}"; fi
done
(( bad )) && print "\nAdd them to the matching help/<topic>.zsh." || print "ok  every command is in devhelp"
(( bad == 0 ))
