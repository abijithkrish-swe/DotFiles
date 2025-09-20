# help/obs.zsh — devhelp page for observability tools

_devhelp_obs() {
  cat <<'EOF'
Observability (Mac only)

btop         – modern system monitor UI (CPU, mem, disk, net)
tldr <cmd>   – concise manuals with examples (e.g., 'tldr tar')
procs        – better ps (tree view, filters)
  procs -t                 # process tree
  procs -Q java            # filter by "java"
  procs -u $USER           # your processes

Notes:
- We do NOT override 'top'/'ps'/'man' to keep prod muscle memory intact.
- These are optional on your Mac; prod boxes won’t have them.
EOF
}

# register with devhelp
_devhelp_register "obs" _devhelp_obs