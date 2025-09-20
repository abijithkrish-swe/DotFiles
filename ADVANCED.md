# ADVANCED

Deep dive topics, optional extras, and troubleshooting.

---

## 🔄 Toolup + direnv

- **toolup**: lightweight tool version manager
- **direnv**: auto-load environment per project

Workflow:
```sh
# in project folder
echo 'use toolup go 1.21' > .envrc
direnv allow
```

This sets Go version automatically when entering the project.

---

## 🔐 Zero-Trust & Proxy Toggles

Enable/disable corp network settings in `~/.zsh.d/` by flipping variables:
```sh
export ZERO_HELPER_STATUS=ON
```

---

## 🧩 Local Overrides

Per-machine tweaks go into branches or local files:
```sh
~/.zshrc.local
```
This is sourced automatically if present.

---

## 📂 XDG Philosophy

To keep `$HOME` clean, configs and caches are redirected:

- Configs → `~/.config/`
- Caches → `~/.zshcache/`

Examples:
- `~/.zsh_history` → `~/.zshcache/zsh_history`
- `~/.mysql_history` → `~/.zshcache/mysql_history`
- `~/.viminfo` → `~/.zshcache/viminfo`

---

## 🛠 Troubleshooting

### tmux terminfo
Error: `Error opening terminal: tmux-256color`
- Fix: `export TERM=xterm-256color`

### starship parse errors
- Check for stray spaces in `~/.config/starship.toml`
- Run `starship explain` to debug

### nerd fonts
- Install Meslo Nerd Font or FiraCode Nerd Font
- Set in terminal preferences

### restoring backups
- Use installer restore mode:
```sh
./install_copy.sh --list-backups
./install_copy.sh --restore <timestamp> --apply
```

---

## 🛠 Extending the System

- Add new modules → `~/.zsh.d/20-newtool.zsh`
- Add new help → `~/.zsh.d/help/newtool.zsh`
- Update defaults in `~/.zsh.d/10-env.zsh`

---
