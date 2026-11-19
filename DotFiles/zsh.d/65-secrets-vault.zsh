# 65-secrets-vault.zsh - Shell Vault (Per-Secret Encryption)
#
# Stores secrets in ~/.config/secrets/vault.store as KEY=<base64_encrypted_blob>
# No plaintext temporary files are ever created during retrieval.

: "${SECRETS_DIR:=$HOME/.config/secrets}"
: "${VAULT_FILE:=$SECRETS_DIR/vault.store}"

[[ -d "$SECRETS_DIR" ]] || mkdir -p "$SECRETS_DIR"
[[ -f "$VAULT_FILE" ]] || touch "$VAULT_FILE"

# ---------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------

_vault_encrypt_str() {
  local plaintext="$1"
  local pass="$2"
  # -md sha256 ensures newer openssl compatibility
  # -a outputs base64 directly
  # -A prevents line wrapping in base64 output (keeps on single line)
  # -salt -pbkdf2 adds security against rainbow tables
  # -pass fd:3 from <(print …): a pipe, never argv (visible in `ps`) and never
  # a temp file (a <<< here-string would be one). Same key as the old -k.
  print -rn -- "$plaintext" | openssl enc -aes-256-cbc -a -A -salt -pbkdf2 -pass fd:3 3< <(print -r -- "$pass") 2>/dev/null
}

_vault_decrypt_str() {
  local cipher="$1"
  local pass="$2"
  # Ensure cipher is on a single line (handle legacy multi-line values)
  cipher=$(echo "$cipher" | tr -d '\n')
  echo "$cipher" | openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -pass fd:3 3< <(print -r -- "$pass") 2>/dev/null
}

_vault_get_raw() {
  local key="$1"
  grep "^${key}=" "$VAULT_FILE" | head -n1 | cut -d '=' -f2-
}

# ---------------------------------------------------------------------
# Core Functions
# ---------------------------------------------------------------------

add_secret() {
  local key="$1"
  local val="$2"
  local pass="$3"

  if [[ -z "$key" ]]; then
    echo -n "Enter Secret Key (e.g. API_TOKEN): "
    read key
  fi
  
  if [[ -z "$val" ]]; then
    echo -n "Enter Secret Value: "
    read -s val
    echo ""
  fi

  if [[ -z "$pass" ]]; then
    echo -n "Enter Password for this secret: "
    read -s pass
    echo ""
  fi

  if [[ -z "$key" || -z "$val" || -z "$pass" ]]; then
    echo "Error: Missing input."
    return 1
  fi

  # Encrypt
  local enc
  enc=$(_vault_encrypt_str "$val" "$pass")
  
  if [[ -z "$enc" ]]; then
    echo "Error: Encryption failed."
    return 1
  fi
  
  # Remove existing key if present
  delete_secret "$key" "quiet"
  
  # Append new key
  echo "${key}=${enc}" >> "$VAULT_FILE"
  echo "Secret '$key' stored securely."
}

# Prints only the secret on stdout; the prompt and errors go to stderr, so
# $(show_secret KEY) captures exactly the value. (They used to go to stdout,
# and use_secret exported "Enter Password for 'KEY': \n<value>".)
show_secret() {
  local key="$1" pass raw decrypted
  if [[ -z "$key" ]]; then echo "Usage: show_secret <KEY>" >&2; return 1; fi

  raw=$(_vault_get_raw "$key")
  if [[ -z "$raw" ]]; then
    echo "Secret '$key' not found in vault." >&2
    return 1
  fi

  echo -n "Enter Password for '$key': " >&2
  read -s pass
  echo "" >&2

  # Check openssl's exit status, not just the output: with a wrong password
  # it still prints the garbled blocks before failing with "bad decrypt".
  if ! decrypted=$(_vault_decrypt_str "$raw" "$pass") || [[ -z "$decrypted" ]]; then
    echo "Decryption failed (Wrong password?)" >&2
    return 1
  fi

  print -r -- "$decrypted"
}

# Helper to "use" a secret by exporting it to current session
use_secret() {
  local key="$1" val
  val=$(show_secret "$key") || return 1
  [[ -n "$val" ]] || return 1
  export "${key}=${val}"
  echo "Exported $key to environment." >&2
}

delete_secret() {
  local key="$1"
  local quiet="$2"
  
  if [[ -z "$key" ]]; then echo "Usage: delete_secret <KEY>"; return 1; fi

  if grep -q "^${key}=" "$VAULT_FILE"; then
    # Use generic sed pattern for backup compatibility (macOS vs GNU)
    sed -i.bak "/^${key}=/d" "$VAULT_FILE" && rm "${VAULT_FILE}.bak"
    [[ "$quiet" == "quiet" ]] || echo "Secret '$key' removed."
  else
    [[ "$quiet" == "quiet" ]] || echo "Secret '$key' not found."
  fi
}

vault_load() {
  local import_file="${SECRETS_DIR}/secrets.env"
  if [[ ! -f "$import_file" ]]; then
     echo "No secrets.env found at $import_file"
     return 1
  fi

  echo "Loading secrets from $import_file..."
  echo -n "Use a single password for all secrets? [y/N]: "
  read choice

  local batch_pass=""
  if [[ "$choice" =~ ^[Yy]$ ]]; then
    echo -n "Enter Batch Password: "
    read -s batch_pass
    echo ""
  fi

  # Read file line by line
  while IFS='=' read -r key val || [[ -n "$key" ]]; do
    # Skip comments/empty
    [[ "$key" =~ ^#.*$ ]] && continue
    [[ -z "$key" || -z "$val" ]] && continue
    
    # Strip quotes from value if present
    val="${val%\"}"
    val="${val#\"}"
    
    echo "Processing $key..."
    if [[ -n "$batch_pass" ]]; then
       add_secret "$key" "$val" "$batch_pass"
    else
       add_secret "$key" "$val"
    fi
  done < "$import_file"

  echo "Import complete."
  echo -n "Delete plain-text source file? [y/N]: "
  read del
  if [[ "$del" =~ ^[Yy]$ ]]; then
    rm "$import_file"
    echo "File deleted."
  fi
}

alias vault_ls="cut -d '=' -f1 $VAULT_FILE"
