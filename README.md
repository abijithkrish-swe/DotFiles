# DotFiles

A modular **zsh + developer environment** setup that keeps `$HOME` clean, portable, and productive.

- 🧩 **Modular design** → configs live in `zsh.d/`, easy to extend per tool  
- 🧹 **Clean home** → histories, caches, swap files all redirected into `~/.zshcache`  
- 📦 **XDG-compliant** → configs under `~/.config/` (`git`, `tmux`, `fzf`, `starship`, …)  
- 🔑 **Toggle system** → enable/disable tools (JDK, MySQL, Redis, Ant, Protobuf, etc.)  
- ⚡ **Productivity tooling** → fzf, ripgrep, bat, fd, eza, zoxide, tmux, starship  
- 🔐 **Secrets support** → load from `~/.config/secrets/secrets.env`  

---

## 📂 Structure

```text
DotFiles/             → main config folder
  zshrc               → ~/.zshrc loader
  vimrc               → ~/.vimrc (cache paths, undo/backup)
  zsh.d/              → modular zsh configs
  config/             → XDG configs (git, tmux, fzf, starship, secrets, …)

~/.zshcache/          → runtime cache (history, compdump, vim swap/undo/backup, mysql, zoxide)
~/.config/            → tool configs (populated from DotFiles/config/*)
~/Components/         → language/db installs (JDK, Redis, MySQL, Ant, Protobuf, …)
```

---

## 🚀 Quick Usage Highlights

### Shell & Navigation
- `z` → jump to recent dirs (zoxide)  
- `eza` → modern `ls` replacement  
- `fzf` → fuzzy finder (`Ctrl-R` for history search)  
- `bat file.txt` → pretty `cat` with syntax highlighting  

### Git
- `lg` → graphical log  
- `gsync1` / `gsync2` / `gsync3` → safe sync flows  
- `git prune-branches` → remove gone branches  
- `devhelp git` → list git helpers  

### tmux
- `tm` → create/attach to main session  
- `tl` → list sessions  
- `tk` → kill a session  
- `devhelp tmux` → tmux keybindings + aliases  

### JDK / MySQL / Redis
- `jdk11` → switch to Java 11 (default)  
- `mysql_start 8.0.43` → start MySQL with fixed `Core/Data/Conf/Log` dirs  
- `use_redis 7.0` → put redis-cli 7.0 on PATH  
- defaults set for: **JDK 11**, **MySQL client 8.0.43**, **Redis 7.0**  

### Secrets
- `load_secrets` → source `~/.config/secrets/secrets.env`  
- `show_secret KEY` → print a single secret  

---

## 📖 Documentation

- [INSTALL.md](INSTALL.md) → full setup guide  
- [DEV_GUIDE.md](DEV_GUIDE.md) → daily usage cheatsheets  
- [TEST.md](TEST.md) → verification checklist after install  
- [ADVANCED.md](ADVANCED.md) → deep dive, troubleshooting, philosophy  

---

## ✨ Philosophy

- **Modular** → every tool has its own `.zsh.d/NN-tool.zsh`  
- **Explicit** → nothing loaded unless toggled ON  
- **Reproducible** → machine-specific changes live on branches, main stays clean  
- **Portable** → one-liner bootstrap with `install_copy.sh` (dry-run by default)  

---
