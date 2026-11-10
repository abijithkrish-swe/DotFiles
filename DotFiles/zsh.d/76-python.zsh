# 76) Python (portable, toggle optional)
# Versions come from the components manifest.

python_list() { components_list python Python; }

# use_python <ver>  — prepend PATH and confirm
# Notes:
#   - We DO NOT set PYTHONHOME (it can break venvs). Just PATH.
#   - Works great with `python -m venv` or direnv layouts.
use_python() {
  if [[ "$1" == "off" || "$1" == "system" ]]; then python_clear; return; fi
  components_activate python Python _PYTHON_ACTIVE_BIN "$1" || return 1
  echo "Switched to Python $CM_V"
  python3 --version
}

python_clear() {
  components_deactivate python Python _PYTHON_ACTIVE_BIN
  echo "Python removed from managed PATH (system python active)"
}

# Aliases
alias python_versions='python_list'
alias py='use_python'
alias python_use='use_python'
alias python_off='python_clear'

load_components_completion "use_python" "python"
