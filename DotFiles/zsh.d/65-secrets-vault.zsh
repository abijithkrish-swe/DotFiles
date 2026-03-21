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
  echo -n "$plaintext" | openssl enc -aes-256-cbc -a -A -salt -pbkdf2 -k "$pass" 2>/dev/null
}

_vault_decrypt_str() {
  local cipher="$1"
  local pass="$2"
  # Ensure cipher is on a single line (handle legacy multi-line values)
  cipher=$(echo "$cipher" | tr -d '\n')
  echo "$cipher" | openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -k "$pass" 2>/dev/null
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

show_secret() {
  local key="$1"
  if [[ -z "$key" ]]; then echo "Usage: show_secret <KEY>"; return 1; fi

  local raw
  raw=$(_vault_get_raw "$key")
  
  if [[ -z "$raw" ]]; then
    echo "Secret '$key' not found in vault."
    return 1
  fi

  echo -n "Enter Password for '$key': "
  read -s pass
  echo ""

  local decrypted
  decrypted=$(_vault_decrypt_str "$raw" "$pass")

  if [[ -z "$decrypted" ]]; then
    echo "Decryption failed (Wrong password?)"
    return 1
  fi

  echo "$decrypted"
}

# Helper to "use" a secret by exporting it to current session
use_secret() {
  local key="$1"
  local val
  val=$(show_secret "$key")
  if [[ $? -eq 0 && -n "$val" ]]; then
    export "${key}=${val}"
    echo "Exported $key to environment."
  fi
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
