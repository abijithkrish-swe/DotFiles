# Developer Environment — Configured Dotfiles

> This file describes the user's shell environment and dev tool setup.
> Copy to `~/.claude/CLAUDE.md` for global context, or place in a project root.

## Shell Environment

The user runs a **modular Zsh** setup. Configuration lives in `~/.zsh.d/*.zsh` (numbered files loaded in order). The repo source is at `~/Projects/Personal/zshrc/configured/`.

Layout: `DotFiles/zsh.d/` (modules), `DotFiles/config/` (XDG configs), `Docs/` (UserGuide, Components, Advanced), `install_copy.sh` (installer).

## Dev Tool Management (Component System)

All tools are installed under `~/Components/<Tool>/<Version>/` and activated via shell functions. The canonical form is **`use_<tool>`**; inverse-form aliases (`<tool>_use`) exist for nearly all tools, so both styles work.

```
use_jdk 17          # Sets JAVA_HOME, updates PATH (alias: jdk_use, jdk11/17/21/25)
use_maven 3.9.6     # Sets M2_HOME, MAVEN_HOME (alias: maven_use)
use_gradle 8.6      # Sets GRADLE_HOME (alias: gradle_use)
use_ant 1.10        # Sets ANT_HOME (alias: ant_use)
use_python 3.11     # PATH only — no PYTHONHOME (venv safe). Alias: python_use, py
use_node 20.0       # PATH only (alias: node_use)
use_go 1.22         # Sets GOROOT (alias: go_use)
use_redis 7.2       # PATH + start/stop (alias: redis_use)
use_mysql 8.0       # Sets MYSQL_HOME + start/stop (alias: mysql_use)
use_protoc 3.0      # PATH only (alias: protobuf_use) — note: canonical is `use_protoc`
```

Each tool also has `<tool>_list` (show installed), `<tool>_clear` (deactivate), and `components_status` (show all active; alias `status_components`).

Redis/MySQL extras: `redis_start`/`redis_stop` (aliases `rstart`/`rstop`/`rcli`); `mysql_start`/`mysql_stop`/`mysql_restart`/`mysql_cli`/`mysql_current`.

### Per-Project Versions (.toolsrc)

Projects can pin tool versions via a `.toolsrc` file in the project root, then run `toolup` to apply.

```ini
JDK=17
MAVEN=3.9.6
GRADLE=8.6
NODE=20.0
REDIS=7.2
ANT=1.10
PROTOBUF=3.0
GO=1.22
PYTHON=3.11
MYSQL_DEFAULT_VER=8.0.43
MYSQL_START_VER=8.0.43
PATH_PREPEND=/some/dir
EXPORT=FOO=bar
```

`toolup` resets PATH to baseline (Homebrew + system) before applying directives. There is also `mkbin` to create and prepend a project-local `.bin/`.

## Default Versions (auto-activated on interactive login)

- JDK: 11
- MySQL client: 8.0.43
- Redis: 7.4.5
- Python: not auto-applied (only if `DEFAULT_PYTHON` is set)
- Node: `NODE_DEFAULT_VERSION=20.19.5` is recorded but **not** auto-activated

Recorded-only defaults (not auto-applied): `DEFAULT_ANT=1.10`, `DEFAULT_PROTOBUF=3.0`.

## Key Paths

| Purpose | Path |
|---------|------|
| Components root | `~/Components/` |
| Shell modules | `~/.zsh.d/` |
| App configs | `~/.config/` (starship, git, tmux, fzf, docker, colima, secrets) |
| Cache/state | `~/.zshcache/` (history, zcompdump, zoxide, mysql_history, viminfo) |
| Secrets vault | `~/.config/secrets/vault.store` |
| Local overrides | `~/.zshrc.local` (loaded by `99-local-overrides.zsh`) |

XDG vars (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME`) are exported. `~/.local/bin` is added to PATH if it contains anything.

## History

Separate history per environment — normal terminal, VS Code, IntelliJ, and Eclipse each write to their own file in `~/.zshcache/`. Normal terminals share history live (`SHARE_HISTORY`); IDE terminals use `INC_APPEND_HISTORY` only (no live sharing) to keep IDE noise out.

## Secrets Vault (`65-secrets-vault.zsh`)

Per-secret AES-256-CBC encryption (PBKDF2, base64-stored) in `~/.config/secrets/vault.store`. No plaintext temp files at any point.

- `add_secret [KEY] [VALUE] [PASS]` — prompts if args omitted
- `show_secret KEY` — prints decrypted value
- `use_secret KEY` — exports decrypted value as env var
- `delete_secret KEY` — remove entry
- `vault_load` — bulk-load multiple secrets
- `vault_ls` — list keys (alias)

Never hardcode secrets; use the vault or environment variables.

## Other Functionality

### Git helpers (`60-aliases`, `61-aliases-extras`, `62-git-sync`)

- Aliases: `gs` (status -sb), `ga`, `gcm`, `gc`, `gp`, `gl` (graph log), `undo` (soft reset HEAD~1), `unpushed`, `please` (sudo last command), `update` / `rebasem` (rebase master), `rebasei`, `stash`, `branch`, `push` (force push — careful).
- Sync flows:
  - `syncm` — stash, checkout master, fetch, pull --rebase
  - `syncc` — stash, pull --rebase current branch, stash pop
  - `syncs` — stash, update master, rebase current onto master, stash pop

### Colima / Docker (`63-colima.zsh`)

`costart` (start with kubernetes), `corest`, `costop`, `codrop` (delete VM), `colist`, `couse` (set docker context), `coinfo` (status summary). Nothing auto-starts.

### tmux (`46-tmux.zsh`)

Smart session: `tm [name]` (attach or create; defaults to `main`). `tl` list, `tk <name>` kill, `tka` kill server. Splits: `tms` (vertical), `tml` (horizontal). Forces XDG config at `~/.config/tmux/tmux.conf`.

### fzf (`44-fzf.zsh`) — opt-in toggles

Off by default. Set before sourcing zshrc:
- `ENABLE_FZF_BASICS`, `ENABLE_FZF_INTERMEDIATE`, `ENABLE_FZF_ADVANCED`
- `ENABLE_FZF_CTRL_R` (history), `ENABLE_FZF_CTRL_T` (file picker), `ENABLE_FZF_ALT_C` (cd)
- `ENABLE_FZF_PREVIEW` (bat preview pane)

Auto-prefers `fd` then `rg` for the default file source.

### Other tooling integrations

- **zoxide** (`z` command) and **direnv** auto-init if installed (`40-navigation-search.zsh`).
- **eza/bat/fd** alias overlays (`41–43`).
- **starship** prompt (toggle `ENABLE_STARSHIP`, default on).
- **NVM** support exists at `90-nvm.zsh` but disabled by default in favor of `use_node`.

### devhelp system (`zz-devhelp.zsh`)

`devhelp <topic>` shows cheatsheets. Topics auto-loaded from `~/.zsh.d/help/*.zsh`. Available: `bat`, `colima`, `docker-basics`, `eza`, `fd`, `fzf-basic/intermediate/advanced`, `git`, `git-advanced`, `gradle`, `jdk`, `k8s`, `maven`, `mysql`, `node`, `obs`, `python`, `redis`, `secrets`, `tmux`, `vim`, `vim-advanced`, `default`. List with `devhelp_list`.

### Zero-trust / Proxy (`01-security.zsh`)

`KEEP_ZERO=true` (default) enables `http_proxy`/`https_proxy=http://127.0.0.1:3128` plus a long corporate `no_proxy` list and `NODE_EXTRA_CA_CERTS` (if `~/.config/zero-trust-certs.pem` exists). Set `KEEP_ZERO=false` to disable.

### Installer (`install_copy.sh`)

Verb-based; no verb prints usage and changes nothing.

- `deploy [--force]` — repo → `$HOME`. Reviews local drift first (fold back to repo or discard), backs up touched home paths to `Backup/<ts>/home/`, then applies: `~/.zshrc`/`~/.vimrc` copy, `~/.zsh.d/` mirror (deletes stale), `~/.config/<x>/` merge. `--force` skips review and confirmation.
- `sync [--force]` — bidirectional reconcile, no side authoritative. Per change: `>` repo→home, `<` home→repo, `x` delete, `s` skip, `q` quit. Whichever side gets overwritten is backed up first (`Backup/<ts>/home/` or `Backup/<ts>/repo/`).
- `backup list | show [ts] | create | restore [ts]` — snapshots under `Backup/<ts>/`.

`~/.config/secrets/` is excluded from all three.

## When Creating Projects

- If the project needs specific tool versions, create a `.toolsrc` file.
- Java projects: user has JDK 11/17/21/25, Maven, Gradle, Ant available.
- Python projects: use `use_python`; user manages venvs directly (no wrapper).
- Node projects: prefer `use_node` (component-based); NVM is present but disabled.
- Proxy: corporate zero-trust proxy is active by default (`http://127.0.0.1:3128`).
