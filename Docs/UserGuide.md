# User Guide

## Overview
This configuration is designed for modularity, safety, and hygiene.
- **Zsh.d**: Configuration is split into numbered files in `~/.zsh.d/`.
- **Hygiene**: Runtime artifacts (history, swap files) are forced into `~/.zshcache/`.

## Core Aliases
### Navigation & Listing
- `..`, `...`: Move up directories.
- `ll`: List detailed (`ls -lah`).
- `la`: List all (`ls -A`).

### Git
- `gs`: Status short.
- `ga`: Add.
- `gcm`: Commit message.
- `undo`: Soft reset last commit (`HEAD~1`).
- `unpushed`: Show commits not yet pushed.
- `gl`: Graph log.

### System
- `please`: Rerun last command with sudo.
- `tm`: Tmux helper.

## Help System
Run `devhelp` to see a cheatsheet of available commands.
