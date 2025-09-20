# 42) bat (pretty cat, optional)
# Install: brew install bat
# Aliases extend cat functionality with line numbers and paging.

if command -v bat >/dev/null 2>&1; then
  alias catn='bat --style=numbers --paging=never'  # numbered cat
  alias batp='bat --paging=always'                 # paged bat
fi

# ---------------------------------------------------------------------
# 43) fd (modern find, optional)
# ---------------------------------------------------------------------