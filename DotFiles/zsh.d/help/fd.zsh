# --- fd help module --------------------------------------------------------
_devhelp_fd() {
  cat <<'EOF'
fd — quick reference
====================

Basic:
  f <pat>       # fd (general find)
  fdf <pat>     # find files only
  fdd <pat>     # find directories only

Advanced:
  fdh <pat>     # find including hidden files
  fde <ext>     # find by extension (e.g. `fde py`)

Actions:
  fd_rm <pat>   # Interactive delete finder
                # 1. Shows files to be deleted in RED
                # 2. Asks for ENTER to confirm
EOF
}
_devhelp_register "fd" _devhelp_fd
