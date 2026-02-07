# --- secrets help module -----------------------------------------------------
_devhelp_secrets() {
  cat <<-'EOF'
Shell Vault — Secure Secrets Management
======================================

The Shell Vault encrypts secrets individually using OpenSSL (AES-256-CBC).
Keys are stored in `~/.config/secrets/vault.store`.

Core Commands
-------------
add_secret <KEY_NAME>   # Interactive prompt to add/update a secret
use_secret <KEY_NAME>   # Decrypts and exports KEY_NAME to current session
show_secret <KEY_NAME>  # Prints the decrypted value to stdout
vault_ls               # List all available secret keys (names only)

Migration / Setup
-----------------
vault_load             # Connects to vault

Examples
--------
1. Add a token:
   $ add_secret OPENAI_API_KEY
   > Enter value for OPENAI_API_KEY: ***********
   > Enter vault password: *****

2. Use in current shell:
   $ use_secret OPENAI_API_KEY
   $ echo $OPENAI_API_KEY
   sk-...

file: DotFiles/SECRETS.md
EOF
}

_devhelp_register "secrets" _devhelp_secrets
_devhelp_register "secret" _devhelp_secrets
_devhelp_register "vault" _devhelp_secrets
