# vault-test.zsh — 65-secrets-vault.zsh in a throwaway vault.
#
#   zsh -f tests/vault/vault-test.zsh
#
# Guards the 2026-11-19 bugs:
# - show_secret printed its prompt on stdout, so use_secret exported
#   "Enter Password for 'KEY': \n<value>" (an API key header then failed
#   with Go's plain "400 Bad Request");
# - the password leaked into the shell as a global $pass;
# - the password went to openssl as argv (-k), visible in `ps`.
emulate -L zsh
here="${${(%):-%x}:A:h}"
repo="${here:h:h}"
local -i ok=0 bad=0
check() { if eval "$2"; then (( ok++ )); print -r -- "ok  $1"; else (( bad++ )); print -r -- "XX  $1"; fi }

export SECRETS_DIR=$(mktemp -d "${TMPDIR:-/tmp}/vault-test.XXXXXX")
export VAULT_FILE=$SECRETS_DIR/vault.store
source $repo/DotFiles/zsh.d/65-secrets-vault.zsh

secret='sk-live_1234 with spaces \n and a backslash'
add_secret API_KEY "$secret" 'pw one' >/dev/null

out=$(print 'pw one' | show_secret API_KEY 2>/dev/null)
check "show_secret prints exactly the value on stdout"   '[[ $out == $secret ]]'
err=$(print 'pw one' | show_secret API_KEY 2>&1 >/dev/null)
check "the prompt goes to stderr"                       "[[ \$err == *\"Enter Password for 'API_KEY'\"* ]]"

unset API_KEY pass
print 'pw one' | { use_secret API_KEY 2>/dev/null; print -r -- "${API_KEY}" >| $SECRETS_DIR/exported; print -r -- "${pass-unset}" >| $SECRETS_DIR/pass }
check "use_secret exports exactly the value (no prompt)" '[[ "$(<$SECRETS_DIR/exported)" == $secret ]]'
check "the password does not leak into \$pass"           '[[ "$(<$SECRETS_DIR/pass)" == unset ]]'

print 'wrong' | use_secret API_KEY >/dev/null 2>&1; rc=$?
check "a wrong password fails and exports nothing new"   '(( rc != 0 ))'
out=$(print 'wrong' | show_secret API_KEY 2>/dev/null)
check "a wrong password prints nothing on stdout"        '[[ -z $out ]]'

# Secrets stored before the fix (openssl -k) still decrypt: same key derivation.
legacy=$(print -rn -- 'old-value' | openssl enc -aes-256-cbc -a -A -salt -pbkdf2 -k 'pw two' 2>/dev/null)
print -r -- "LEGACY=$legacy" >> $VAULT_FILE
out=$(print 'pw two' | show_secret LEGACY 2>/dev/null)
check "secrets written with the old -k still decrypt"   '[[ $out == old-value ]]'

check "no openssl call passes the password in argv"      "! grep -q -- '-k \"\$pass\"' $repo/DotFiles/zsh.d/65-secrets-vault.zsh"
check "the vault holds no plaintext"                      "! grep -qF 'sk-live_1234' \$VAULT_FILE"

rm -rf $SECRETS_DIR
print "\n$ok passed, $bad failed"
(( bad == 0 ))
