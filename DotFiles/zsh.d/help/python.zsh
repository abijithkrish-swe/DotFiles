# --- Python help module ----------------------------------------------------
_devhelp_python() {
cat <<'EOF'
Python — Quick Reference
========================

Your portable layout
--------------------
~/Components/Python/<ver>/
  ├─ bin/         # python3, pip3
  └─ ...

Helper commands (from your zsh modules)
---------------------------------------
python_list          # list available Python versions
use_python <ver>|off # switch active Python version (appends bin/ to PATH)
  e.g. use_python 3.12
       use_python off

python_clear         # explicitly remove Python path components

Aliases
-------
python_versions -> python_list
py              -> use_python
python_use      -> use_python
python_off      -> python_clear

Notes
-----
• This manages PATH only, not PYTHONHOME (to allow venvs to work).
• Use `python -m venv` to create virtual environments.
EOF
}

_devhelp_register "python" _devhelp_python
