# 01) security
#
# Placed AFTER 00-options so any overrides here take effect.
#
# A corporate proxy (http_proxy / https_proxy / no_proxy) is NOT set here: a
# machine's own proxy helper appends those exports to ~/.zshrc, and
# `install_copy.sh deploy` offers [m] to move them into ~/.zshrc.local, which
# is never in this repo. Keep per-company network settings there.

# If your old file asked to turn OFF shared history later, keep that:
# unsetopt share_history   # (overrides setopt share_history from 00-options)

# Node.js: trust a proxy's CA for TLS, when this machine has one
if [ -f "$HOME/.config/zero-trust-certs.pem" ]; then
  export NODE_EXTRA_CA_CERTS="$HOME/.config/zero-trust-certs.pem"
fi
