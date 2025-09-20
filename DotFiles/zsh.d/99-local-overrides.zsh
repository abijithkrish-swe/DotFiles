# 99) local overrides
# Put machine-specific tweaks in ~/.zshrc.local — it won't be checked in.

if [ -f "$HOME/.zshrc.local" ]; then
  source "$HOME/.zshrc.local"
fi

# ---------------------------------------------------------------------
# zz) devhelp
# ---------------------------------------------------------------------