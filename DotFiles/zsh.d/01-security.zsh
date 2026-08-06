# 01) security / zero-trust hardening
#
# This file restores hardening/zero-trust bits you had in your old zshrc.
# It is placed AFTER 00-options so any overrides here take effect.

# If your old file asked to turn OFF shared history later, keep that:
# unsetopt share_history   # (overrides setopt share_history from 00-options)

# --- Zero / proxy helpers (toggle) ---
# KEEP_ZERO=true enables local proxy env for http/https; false disables.
export KEEP_ZERO=true

if [[ "$KEEP_ZERO" == "true" ]]; then
  # Node.js: trust zero-trust CA for TLS connections
  if [ -f "$HOME/.config/zero-trust-certs.pem" ]; then
    export NODE_EXTRA_CA_CERTS="$HOME/.config/zero-trust-certs.pem"
  fi

  export ZERO_HELPER_STATUS=ON
  export http_proxy=http://127.0.0.1:3128
  export https_proxy=http://127.0.0.1:3128
  export no_proxy=127.0.0.1,localhost,::1
else
  unset http_proxy https_proxy no_proxy
fi

# ---------------------------------------------------------------------
# 10) environment & path
# ---------------------------------------------------------------------
