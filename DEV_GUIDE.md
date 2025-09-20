# DEV GUIDE

Daily usage cheatsheet for tools configured in this dotfiles setup.

---

## ⌨️ Zsh Basics

- Modular configs live in `~/.zsh.d/`
- Help system:
  ```sh
  devhelp           # default help
  devhelp git       # git-specific help
  devhelp tmux      # tmux-specific help
  ```
- Secrets:
  ```sh
  load_secrets      # load ~/.config/secrets/secrets.env
  show_secret KEY   # print a secret
  ```

---

## 📂 Navigation

- `z` → jump to recent dirs (zoxide)
- `eza -l` → modern `ls` with icons
- `fzf` → fuzzy finder (`Ctrl-R` for history)
- `bat file.txt` → pretty `cat` with syntax highlighting

---

## 🔍 Search & Preview

- `rg -n <pattern>` → ripgrep, fast search respecting `.gitignore`
- `grep -nr <pattern> .` → fallback grep (portable)
- `fd <name>` → fast file search
- `find . -type f -name <pattern>` → portable fallback

---

## 🖥️ tmux

Aliases:
```sh
tm     # create/attach main session
tl     # list sessions
tk     # kill a session
```

Common bindings (prefix = Ctrl-B):
- `c` → new window
- `%` / `"` → split panes
- `arrows` → move between panes
- `,` → rename window
- `w` → list windows/sessions
- `d` → detach
- `x` → kill pane
- `q` → show pane numbers
- `{` / `}` → move panes
- `space` → cycle layouts
- `[` (copy mode), `space` (start), `enter` (yank), `q` (cancel)

Help:
```sh
devhelp tmux
```

---

## 🌱 Git

Aliases:
```sh
lg          # log with graph
tags        # list tags
branches    # list branches
remotes     # show remotes
unpushed    # commits not pushed
undo        # reset --hard HEAD~1
prune-branches # remove gone branches
```

Sync helpers:
```sh
gsync1   # stash, checkout master, fetch, pull --rebase
gsync2   # stash, pull --rebase origin, stash pop
gsync3   # stash, checkout master, fetch, pull --rebase, rebase current branch, stash pop
```

Help:
```sh
devhelp git
```

---

## ☕ JDK Management

```sh
jdk8       # use Java 8
jdk11      # use Java 11 (default)
jdk17      # use Java 17
```

---

## 🐬 MySQL

```sh
mysql_start 8.0.43   # start server
mysql_stop          # stop server
mysql_cli           # client
```

Default client = 8.0.43

---

## 🔴 Redis

```sh
use_redis 7.0   # set redis-cli 7.0 on PATH (default)
use_redis 6.4   # switch to 6.4
```

---

## 📦 Ant & Protobuf

- Ant: `use_ant` loads ANT_HOME, bin on PATH
- Protobuf: `use_proto` loads protoc

Defaults: off unless enabled

---

## 🐍 Python / 🐹 Go / ⬢ Node

- Python: use `python3 -m venv venv` or project `.envrc`
- Go: `go env GOPATH`, per-project toggle planned
- Node: managed via nvm or Components dir

---

## 🌟 Starship Prompt

- Config at `~/.config/starship.toml`
- Default theme shows: directory, git branch/status, hg branch, prompt symbol
- Customize symbols, colors, Nerd Font icons

---

## 🧩 Tips

- On prod machines: remember base tools (`grep`, `find`, `ls`, `cat`)  
- Use toggles only on dev machine  
- Machine-specific tweaks go on feature branches, not `main`
