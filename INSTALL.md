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
./install_copy.sh deploy   # install repo → $HOME
```

The installer is **verb-based**. Running it with no verb prints usage and changes
nothing.

### Verbs

| Command | What it does |
|---------|--------------|
| `deploy [--force]` | Fresh install, repo → `$HOME`. |
| `sync [--force]` | Bidirectional reconcile; pick a direction per change. |
| `backup list` | List backup timestamps under `Backup/`. |
| `backup show [ts]` | Summarize a backup (latest if no timestamp). |
| `backup create` | Manual snapshot of the `$HOME` paths the repo manages. |
| `backup restore [ts]` | Restore `$HOME` from a backup. |
| `help` | Show usage. |

### deploy

Runs in three steps:

1. **Drift review** — finds local `$HOME` edits that deploy would overwrite, and
   files under `~/.zsh.d/` that the mirror would delete. Shows a diff per file and
   asks whether to fold it back into the repo (`y`) or discard it (`n`); `a` folds
   everything, `q` aborts without writing. Extra files under `~/.config/<x>/` are
   preserved by deploy, so they are not treated as drift.
2. **Backup** — snapshots every touched `$HOME` path to `Backup/<timestamp>/home/`.
   Folded-back repo files are backed up to `Backup/<timestamp>/repo/` first.
3. **Apply** — writes the files:
   - `~/.zshrc`, `~/.vimrc` → copy
   - `~/.zsh.d/` → mirror (stale files **deleted**)
   - `~/.config/<x>/` → merge (untracked files kept)

`--force` skips the drift review (local edits are discarded) and the confirmation
prompt.

### sync

Reconciles repo and `$HOME` in **both** directions — neither side is authoritative.
Each difference is shown as a diff, then you choose:

- `>` repo → home
- `<` home → repo
- `x` delete (offered only when the file exists on just one side)
- `s` skip, `q` quit

Useful when you have edited `~/.zsh.d/` directly and want to fold changes back into
the repo without a full reinstall.

Both directions back up the file they replace before writing:

- `>` saves the old home file to `Backup/<timestamp>/home/`
- `<` saves the old repo file to `Backup/<timestamp>/repo/`
- `x` saves the deleted file to `Backup/<timestamp>/home/`

So picking the wrong direction is recoverable — from `Backup/`, or for repo files
from git directly (`git checkout -- <path>`).

`--force` here just auto-skips everything, so it is rarely useful.

> `~/.config/secrets/` is excluded from `deploy`, `sync`, and `backup` in all cases.

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

## 🧩 Optional Dev Tools (Mac only)

These are convenient on your Mac but **not required** (and not used on prod):

```sh
brew install btop tlrc procs
```
  - btop → modern system monitor UI (we keep top unchanged)
  - tlrc → simplified manuals (e.g., tlrc tar)
  - procs → a nicer ps (tree view, filters)
  
---

## 🛠 Troubleshooting

- **tmux-256color**: if remote server doesn’t support it, set `TERM=xterm-256color`
- **Starship config parse error**: check `~/.config/starship.toml` for stray spaces
- **Nerd Fonts**: install [Meslo Nerd Font](https://www.nerdfonts.com/) or FiraCode for icons
