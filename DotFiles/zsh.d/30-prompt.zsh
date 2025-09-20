# 3 ) PROMPT (Optional: Starship)

# Toggle starship prompt (disabled by default)
export ENABLE_STARSHIP=true

if [[ "$ENABLE_STARSHIP" == "true" ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
# ---------------------------------------------------------------------
# 40) NAVIGATION & SEARCH
# ---------------------------------------------------------------------
