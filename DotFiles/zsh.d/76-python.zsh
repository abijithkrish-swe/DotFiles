# 76) Python (portable, toggle optional)

# List Python versions (must have bin/python3)
python_list() {
  local d v
  if [[ ! -d "$COMPONENTS/Python" ]]; then
     echo "No Python components at $COMPONENTS/Python"
     return 0
  fi
  
  echo "Available Python versions:"
  for d in "$COMPONENTS/Python"/*; do
    [[ -d "$d/bin" && -x "$d/bin/python3" ]] || continue
    v="${d:t}"
    echo "  $v"
  done | sort -V
}

# Resolve a Python home with bin/ under ~/Components/Python/<ver>
_python_home() {
  local root="$COMPONENTS/Python/$1"
  if [ -d "$root/bin" ]; then
    echo "$root"; return 0
  fi
  return 1
}

# use_python <ver>  — prepend PATH and confirm
# Notes:
#   - We DO NOT set PYTHONHOME (it can break venvs). Just PATH.
#   - Works great with `python -m venv` or direnv layouts.
use_python() {
  local v="$1"
  if [[ "$v" == "off" || -z "$v" ]]; then
     python_clear
     return
  fi

  local home; home="$(_python_home "$v")" || { echo "Python $v not found under $COMPONENTS/Python"; return 1; }
  
  # Swap path
  component_switch_path "_PYTHON_ACTIVE_BIN" "$home/bin"
  
  echo "Switched to Python $v"
  python3 --version
}

python_clear() {
  component_switch_path "_PYTHON_ACTIVE_BIN" ""
  echo "Python removed from managed PATH (system python active)"
}

# Aliases
alias python_versions='python_list'
alias py='use_python'
alias python_use='use_python'
alias python_off='python_clear'
