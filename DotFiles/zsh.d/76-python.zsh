# 76) Python (portable, toggle optional)

# List Python versions under ~/Components/Python
python_versions() { ls -1 "$COMPONENTS/Python" 2>/dev/null; }

# Resolve a Python home with bin/ under ~/Components/Python/<ver>
_python_home() {
  local root="$COMPONENTS/Python/$1"
  if [ -d "$root/bin" ]; then
    echo "$root"; return 0
  fi
  return 1
}

# use_python <ver>  — append PATH and confirm
# Notes:
#   - We DO NOT set PYTHONHOME (it can break venvs). Just PATH.
#   - Works great with `python -m venv` or direnv layouts.
use_python() {
  local v="${1:?version}"
  local home; home="$(_python_home "$v")" || { echo "Python $v not found under $COMPONENTS/Python"; return 1; }
  export PATH="$PATH:$home/bin"     # append (safer)
  echo "Using Python $v from $home"
  python3 --version 2>/dev/null || python --version 2>/dev/null || echo "python not found in $home/bin"
}

# Quick check
pyv() { command -v python3 >/dev/null && python3 --version || python --version; }

# ---------------------------------------------------------------------
# 77) Golang (portable)
# ---------------------------------------------------------------------