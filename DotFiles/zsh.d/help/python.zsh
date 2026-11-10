# --- Python help module ----------------------------------------------------
_devhelp_python() {
cat <<'EOF2'
Python — Quick Reference
========================

Your portable layout
--------------------
~/Components/Python/<ver>/
  ├─ bin/         # python3, pip3
  └─ ...
Approved: see python_list (3.15.2 is the default).
New versions: python-build-standalone "install_only" tarballs (binary,
aarch64-apple-darwin) — verify with the release's SHA256SUMS, extract with
--strip-components 1 into ~/Components/Python/<ver>, then add the version to
the components manifest ('devhelp components').

Helper commands (from your zsh modules)
---------------------------------------
python_list          # approved Python versions (from the components manifest)
use_python [ver]|off # switch active Python (prepends bin/ to PATH; prefix ok)
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
EOF2
}

_devhelp_register "python" _devhelp_python
