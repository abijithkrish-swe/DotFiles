# Developer Environment — Configured Dotfiles

> This file describes the user's shell environment and dev tool setup.
> Copy to `~/.claude/CLAUDE.md` for global context, or place in a project root.

## Shell Environment

The user runs a **modular Zsh** setup. Configuration lives in `~/.zsh.d/*.zsh` (numbered files loaded in order). The repo source is at `~/Important/zshrc/configured/`.

## Dev Tool Management (Component System)

All tools are installed under `~/Components/<Tool>/<Version>/` and activated via shell functions:

```
use_jdk 17          # Sets JAVA_HOME, updates PATH
use_maven 3.9.6     # Sets M2_HOME, MAVEN_HOME
use_gradle 8.6      # Sets GRADLE_HOME
use_python 3.11     # PATH only (no PYTHONHOME — venv safe)
use_node 20.0       # PATH only
use_go 1.22         # Sets GOROOT
use_ant 1.10        # Sets ANT_HOME
redis_use 7.2       # PATH + start/stop support
use_mysql 8.0       # Sets MYSQL_HOME + start/stop
protobuf_use 3.0    # PATH only
```

Each tool also has: `<tool>_list` (show installed), `<tool>_clear` (deactivate), `components_status` (show all active).

### Per-Project Versions (.toolsrc)

Projects can pin tool versions via a `.toolsrc` file in the project root:

```ini
JDK=17
MAVEN=3.9.6
GRADLE=8.6
NODE=20.0
```

Run `toolup` to activate all versions from the file.

## Default Versions

- JDK: 11
- MySQL client: 8.0.43
- Redis: 7.4.5
- Node: 20.19.5

These auto-activate on interactive shell login.

## Key Paths

| Purpose | Path |
|---------|------|
| Components root | `~/Components/` |
| Shell modules | `~/.zsh.d/` |
| App configs | `~/.config/` (starship, git, tmux, fzf, docker, colima) |
| Cache/state | `~/.zshcache/` (history, zcompdump, zoxide, sessions) |
| Secrets vault | `~/.config/secrets/vault.store` |
| Local overrides | `~/.zshrc.local` |

## History

Separate history per environment — normal terminal, VS Code, IntelliJ, and Eclipse each write to their own file in `~/.zshcache/`. Normal terminals share history live; IDE terminals do not.

## When Creating Projects

- If the project needs specific tool versions, create a `.toolsrc` file.
- Java projects: user has JDK 11/17/21/25, Maven, Gradle, Ant available.
- Python projects: use `use_python`, no virtualenv wrapper — user manages venvs directly.
- Node projects: `use_node` (component-based), NVM is available but disabled by default.
- Proxy: corporate zero-trust proxy is active by default (`http://127.0.0.1:3128`).

## Secrets

Use `vault_ls` to list stored secrets. Use `use_secret KEY` to export a secret to the current session. Never hardcode secrets — use the vault or environment variables.
