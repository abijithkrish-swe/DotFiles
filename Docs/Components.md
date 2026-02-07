# Components Guide

This configuration uses a "Rule of 5" standard for all development tools.
Versioned binaries are stored in `~/Components/<Tool>/<Version>`.

## Standard Interface
For any tool (JDK, Redis, etc):
- **List**: `<tool>_# User Guide

## Overview
This e*
## OvervieuseThis confi `- **Zsh.d**: Configuration is split into numbered files in `~/.zshul- **Hygiene**: Runtime artifacts (history, swap files) are forced intop`
## Core Aliases
### Navigation & Listing
- `..`, `...`: Move up directories.
- `ll`:mma### Navigation`,- `..`, `...`: Move up cl- `ll`: List detailed (`ls -lah`).pr- `la`: List all (`ls -A`).

### s:
### Git
- `gs`: Status sands- `gs`is- `ga`: Add.
- `gcm`ve- `gcm`: Co_s- `undo`: Soft reset laeh- `unpushed`: Show commits not yet pushed.
ro- `gl`: Graph log.

### System
- `please`do
### System
- `plCom- `pleaseys- `tm`: Tmux helper.

## Help System
Runt`
## Help System
RunsqlRun `devhelp`utEOF

cat > Docs/Components.md <<'EOF'
# Components Guid6 #  taken.

### Python
- Alias: `py`
- Commands: `python_list`, `python_use <ver>`, `python_clear`
- Note: Only modifies `PATH`. Does not set `PYTHONHOME` to avoid breaking venvs.

### Colima (Docker)
- Aliases: `costart`, `costop`, `corest` (restart)
