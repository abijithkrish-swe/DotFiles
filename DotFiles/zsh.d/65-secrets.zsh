# 65) secrets helper
# Manage sensitive values you keep in ~/.secrets

SECRETS_FILE="$HOME/.config/secrets/secrets.env"

# Load secrets into environment
load_secrets() {
  if [[ -f "$SECRETS_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$SECRETS_FILE"
    echo "Secrets loaded from $SECRETS_FILE"
  else
    echo "Secrets file not found at $SECRETS_FILE"
  fi
}

# Show a specific secret
show_secret() {
  local key="$1"
  if [[ -z "$key" ]]; then
    echo "Usage: show_secret KEY"
    return 1
  fi
  grep "^$key=" "$SECRETS_FILE" 2>/dev/null | cut -d '=' -f2-
}

# ---------------------------------------------------------------------
# 70) components core & toolup
# ---------------------------------------------------------------------