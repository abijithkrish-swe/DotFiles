# INSTALL

Step-by-step instructions to set up these dotfiles on a new machine.

---

## 📋 Prerequisites

Before installing, make sure you have:

- **zsh** (default on macOS, install on Linux if needed)
- **git** (for cloning this repo)
- **Homebrew** (macOS) or your package manager
- Core CLI tools:
  ```sh
  brew install fzf ripgrep bat fd eza zoxide tmux starship
  ```

---

## 📦 Clone & Install

Clone this repo and run the installer:

```sh
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
./install_copy.sh         # dry run (default, preview actions)
./install_copy.sh --apply # actually copy files
```

### Installer modes
- `--apply` → copy files into `$HOME`
- `--force` → overwrite existing files (with backups in `Backup/<timestamp>/`)
- `--restore [ts]` → restore from backup (latest or specific timestamp)
- `--list-backups` → list all backups

---

## 📂 Directory Structure

```text
~/.zshrc            → loader for modular zsh
~/.vimrc            → vim config (undo/backup/swap paths)
~/.zsh.d/           → modular zsh configs (split per tool)
~/.config/          → XDG configs (git, tmux, fzf, starship, secrets, …)
~/.zshcache/        → runtime cache (history, compdump, vim swap/undo/backup, mysql, zoxide)
~/Components/       → language/db installs (JDK, Redis, MySQL, Ant, Protobuf, …)
```

---

## 🗂 Components Layout

Each language/database is stored in versioned directories:

```text
~/Components/JDK/17/
  └─ bin/ lib/ …

~/Components/Redis/7.0/
  └─ redis-server, redis-cli

~/Components/Mysql/8.0.43/
  ├─ Core/  → binaries
  ├─ Data/  → database files
  ├─ Conf/  → my.cnf
  └─ Log/   → error.log, slow.log, query.log
```

Default versions are toggled in `.zsh.d/`:
- JDK 11
- MySQL client 8.0.43
- Redis 7.0

---

## 🔄 Migration Guide

To keep `$HOME` clean, histories and configs are redirected:

- `~/.zsh_history` → `~/.zshcache/zsh_history`
- `~/.mysql_history` → `~/.zshcache/mysql_history`
- `~/.viminfo` → `~/.zshcache/viminfo`
- `~/.gitconfig` → `~/.config/git/config`
- `~/.tmux.conf` → `~/.config/tmux/tmux.conf`

One-time move:
```sh
mkdir -p ~/.zshcache
mv ~/.zsh_history ~/.zshcache/zsh_history 2>/dev/null || true
mv ~/.mysql_history ~/.zshcache/mysql_history 2>/dev/null || true
mv ~/.viminfo ~/.zshcache/viminfo 2>/dev/null || true
```

---

## ✨ Optional Extras

- **Starship** → minimal prompt with git status/icons
- **direnv** → per-project environment loading
- **Zero-trust toggles** → enable/disable corp network settings in `.zsh.d/`

---

## 🛠 Troubleshooting

- **tmux-256color**: if remote server doesn’t support it, set `TERM=xterm-256color`
- **Starship config parse error**: check `~/.config/starship.toml` for stray spaces
- **Nerd Fonts**: install [Meslo Nerd Font](https://www.nerdfonts.com/) or FiraCode for icons
