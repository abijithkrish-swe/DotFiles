# Developer Environment — Configured Dotfiles

> This file describes the user's shell environment and dev tool setup.
> Copy to `~/.claude/CLAUDE.md` for global context, or place in a project root.

## Shell Environment

The user runs a **modular Zsh** setup. Configuration lives in `~/.zsh.d/*.zsh` (numbered files loaded in order). The repo source is at `~/Projects/Personal/zshrc/configured/`.

Layout: `DotFiles/zsh.d/` (modules), `DotFiles/config/` (XDG configs), `Docs/` (UserGuide, Components, Advanced, AgentComponents — agent/MCP design & runbooks), `install_copy.sh` (installer).

## Dev Tool Management (Component System)

All tools are installed under `~/Components/<Tool>/<Version>/`. **Only versions listed in the manifest `~/.config/components/components.conf` can be used.** It is the approved list (source: `DotFiles/config/components/components.conf`). Shell functions, `toolup`, login defaults, tab completion and the `toolshelf` MCP server all read it. An unlisted folder on disk is rejected. Design: `Docs/AgentComponents.md`.

**AI agents:** don't use the `use_*` functions; they depend on zsh helpers that agent shells don't load. Use the `toolshelf` MCP: `list_components`, `get_component_env` (prefix commands with its exports), `resolve_toolsrc` (a project's pinned versions), and `run`, which runs builds and tests in the macOS sandbox (project-only writes, proxy-only network, no secrets). For untrusted code, use `run` with `mode: "docker"`: a throwaway container from a pinned image, with no network unless `network: "proxy"`. Never install or upgrade tools. For a missing version, call `request_component` and tell the user, who reviews it with `components_requests`.

Activation is via **`use_<tool> [version]`**. The version can be exact or a unique prefix on a segment boundary: `17` → 17, `3.9` → 3.9.12, `22` → 22.21.1, but `2` is rejected rather than guessed. With no version it uses the manifest default; `off` deactivates. Inverse aliases (`<tool>_use`) exist for nearly all tools.

```
use_jdk 17          # Sets JAVA_HOME, updates PATH (aliases: jdk, jdk_use, jdk11/17/25, jdkoff)
use_maven 3.9       # Sets M2_HOME, MAVEN_HOME (alias: maven_use)
use_gradle 8.14     # Sets GRADLE_HOME (alias: gradle_use)
use_ant 1.9         # Sets ANT_HOME (alias: ant_use)
use_python 3.15     # PATH only — no PYTHONHOME (venv safe). Alias: python_use, py
use_node 22         # PATH only (alias: node_use)
use_go 1.27         # Sets GOROOT (alias: go_use)
use_rust            # PATH only; CARGO_HOME is $XDG_DATA_HOME/cargo (alias: rust_use)
use_redis 7         # PATH + start/stop (alias: redis_use)
use_mysql 8         # PATH + MYSQL_HOME/data dirs + start/stop (alias: mysql_use)
use_protoc 25       # PATH only (aliases: protobuf_use, use_protobuf)
```

Installed now: JDK 11/17/25/26.0.2 (no 21; plan is 17 → 25), Maven 3.9.12/4.0.0-rc-5, Gradle 8.14.4/9.3.1, Ant 1.9.6, Node 20/22/24/25/26, Go 1.24.5/1.27.4, Rust 1.99.1, Python 3.15.2, Protobuf 3.16.3/25.5, Redis 6.2.14/7.4.5, MySQL 5.7.30/8.0.43. Run `components_check` for the live list.

Each tool also has:
- `<tool>_list`: approved versions with default/autoload flags, plus broken or unapproved folders.
- `<tool>_clear`: deactivate.

Shared commands: `components_status` (what's active; alias `status_components`), `components_check` (health of the whole manifest), `components_requests [clear]` (versions agents asked for), `toolshelf_report [days]` (what agents ran via toolshelf and what the guard hook or `run` blocked; read-only), `dockrun [--net|--internet] [-p PORT] [-n] <tool>[=ver] ['cmd']` (the user's own way to try untrusted code: a throwaway container from the version's pinned image, current folder at `/work`, no network by default, `--net` = proxy only; `70-components-dockrun.zsh`; not for agents, which use toolshelf `run` with `mode: "docker"`), `components_images [prune]` (pinned Docker images: pulled or not, sizes; `prune` removes only retired pins, never your own images), and `components_reload`. Reload is rarely needed: edits to the manifest are picked up automatically.

Redis/MySQL extras: `redis_start`/`redis_stop` (aliases `rstart`/`rstop`/`rcli`); `mysql_start`/`mysql_stop`/`mysql_restart`/`mysql_cli`/`mysql_current`.

### Adding or updating a component

1. Unpack to `~/Components/<Dir>/<version>/`.
2. Add `<tool> <version>` to `DotFiles/config/components/components.conf`, plus `default`/`autoload` if wanted.
3. Deploy with `install_copy.sh deploy`, then check with `components_check`.

Changing the manifest *format* (the parser in `70-components-core.zsh` or toolshelf's `components.ts`) means changing both, then running `zsh -f tests/components/parity.zsh`, which must pass.

A new tool type also needs a `@tool` line, and a ~15-line `7x-<tool>.zsh` wrapper over `components_activate`.

### Per-Project Versions (.toolsrc)

Projects can pin tool versions via a `.toolsrc` file in the project root, then run `toolup` to apply. The same approval and prefix rules apply. An empty value skips that tool. `toolup` returns 1 and lists anything that failed.

```ini
JDK=17
MAVEN=3.9.12
GRADLE=8.14
NODE=22
GO=1.27
RUST=1.99
REDIS=7.4
ANT=1.9.6
PROTOBUF=25.5
PYTHON=3.11
MYSQL_DEFAULT_VER=8.0.43   # active MySQL client version
MYSQL_START_VER=8.0.43
PATH_PREPEND=/some/dir
EXPORT=FOO=bar
```

`toolup` resets PATH to baseline (Homebrew + system) before applying directives. There is also `mkbin` to create and prepend a project-local `.bin/`.

## Default Versions

Set in the manifest, not in zsh. `default` is used when no version is given, and is exported as `DEFAULT_<TOOL>`. On interactive login, `79-defaults.zsh` activates `autoload` versions (`use_<tool>`: PATH, env vars, status). For `onpath` versions it only puts the bin dir on PATH, without activating them or starting anything.

- Autoload: JDK 11
- On PATH only: MySQL 8.0.43 client (for remote instances; no `MYSQL_HOME`/socket set, server not started)
- Defaults: JDK 11, Maven 3.9.12, Gradle 8.14.4, Ant 1.9.6, Node 20.19.5, Go 1.27.4, Rust 1.99.1, Python 3.15.2, Protobuf 3.16.3, Redis 7.4.5, MySQL 8.0.43

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

Keys:
- `C-b Tab` jumps to the last session. `C-b H/J/K/L` resizes.
- `C-b c` and the splits open in the current pane's folder.
- Copy mode uses vi keys (`v`/`y`, mouse drag), and copies go to the macOS clipboard (`copy-command pbcopy`).
- Windows renumber when one closes.

Tools in `~/.config/tmux/bin` (appended to PATH):
- `tmux-check` reports whether the running server matches `tmux.conf`, with fixes.
- `tmux-snapshot` saves sessions, windows, folders and Claude conversations into a restore script. It handles any Claude config (e.g. `myclaude`) by reading each process's `CLAUDE_CONFIG_DIR`, and keeps the newest 5 snapshots (`TMUX_SNAPSHOT_KEEP`).
- Restore with `zsh ~/.local/state/tmux-snapshots/latest.zsh`.

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

### devhelp system (`zz-devhelp.zsh`)

`devhelp <topic>` shows cheatsheets. Topics auto-loaded from `~/.zsh.d/help/*.zsh`. Available: `bat`, `colima`, `components` (approved versions, manifest flags), `docker-basics`, `eza`, `fd`, `fzf-basic/intermediate/advanced`, `git`, `git-advanced`, `gradle`, `jdk`, `k8s`, `maven`, `mysql`, `node`, `obs`, `python`, `redis`, `rust`, `secrets`, `tmux`, `toolshelf` (running projects via agents: sandbox vs docker mode), `vim`, `vim-advanced`, `default`. List with `devhelp_list`.

### Proxy (`01-security.zsh`, `~/.zshrc.local`)

The repo sets no proxy. A machine's own proxy helper appends `http_proxy`/`https_proxy`/`no_proxy` to `~/.zshrc`; `install_copy.sh deploy` offers `[m]` to move them into `~/.zshrc.local` (never in the repo). `01-security.zsh` only sets `NODE_EXTRA_CA_CERTS` when `~/.config/zero-trust-certs.pem` exists. toolshelf and `dockrun --net` use whatever `https_proxy` is set (localhost only).

### Installer (`install_copy.sh`)

Verb-based; no verb prints usage and changes nothing.

- `deploy [--force]` — repo → `$HOME`. Reviews local drift first (fold back to repo or discard); when `~/.zshrc` is the repo version plus lines appended by apps, it also offers `[m]`, which moves those lines to `~/.zshrc.local` (no duplicates, backed up) and handles text glued onto the last line, backs up touched home paths to `Backup/<ts>/home/`, then applies: `~/.zshrc`/`~/.vimrc` copy, `~/.zsh.d/` mirror (deletes stale), `~/.config/<x>/` merge. `--force` skips review and confirmation.
- `sync [--force]` — bidirectional reconcile, no side authoritative. Per change: `>` repo→home, `<` home→repo, `x` delete, `s` skip, `q` quit. For a `~/.zshrc` with app-appended lines, `m` moves them to `~/.zshrc.local`, then restores the repo version. Whichever side gets overwritten is backed up first (`Backup/<ts>/home/` or `Backup/<ts>/repo/`).
- `backup list | show [ts] | create | restore [ts]` — snapshots under `Backup/<ts>/`.
- `identity` — prompts for this machine's git identity (default + optional per-folder, e.g. `~/Projects/Personal`); stored in `~/.config/git/identity` + `identity.d/`, never in the repo. `deploy` offers it when missing; `[user]` folded back into the repo config is stripped. Other per-machine git settings (e.g. this Mac's absolute credential-helper path) go in `~/.config/git/local`, included last.
- `agents` — merges agent guardrails into every Claude Code config (`~/.claude` and `~/.config/claude-personal`, the one `myclaude` uses):
  - `settings.json` gets toolshelf permissions (read tools allowed, `run` asks), a short allowlist of read-only Bash commands (`docker image inspect`, `colima status`, `shasum` …), install-command denies, edit denies on the rules themselves (`~/.config/agents/**`, `~/.config/components/**`, Claude `settings*.json`, and the other apps' rules/MCP configs: `~/.codex/{AGENTS.md,config.toml,rules/}`, the Claude app's config, `~/.cursor/mcp.json`; plus a read deny on `~/.codex/auth.json`; Bash writes there are blocklisted too, so change them in this repo and deploy), and a `PreToolUse` Bash hook, `~/.config/agents/guard.sh`, which enforces `~/.config/agents/blocklist.txt`. It also gets sound hooks: `Notification` plays Sosumi when Claude needs input or approval, and `Stop` plays Glass when a reply is done.
  - `CLAUDE.md` gets an import of `~/.config/agents/AGENTS.md`.
  - Codex (CLI and Codex in the ChatGPT app), if `~/.codex` exists: a copy of `AGENTS.md` at `~/.codex/AGENTS.md`, since Codex has no import. It's backed up when it differs.

  It merges only, makes a backup first, and is safe to re-run. `deploy` offers it. Hook tests: `tests/agents/guard-test.pl`. `AGENTS.md` is the single source of the agent rules (toolshelf also sends it to every MCP client). Write it in ASD-STE100 style and keep it under 1600 bytes; check with `perl tests/agents/agents-md-test.pl`.

`~/.config/secrets/` is excluded from all three.

## When Creating Projects

- If the project needs specific tool versions, create a `.toolsrc` file.
- Java projects: JDK 11/17/25/26, Maven, Gradle, Ant available (see `components_check`). Gradle toolchains are limited to approved JDKs (`jdk_gradle_sync`); never enable auto-provisioning.
- Rust projects: `use_rust` (standalone toolchain, no rustup).
- Python projects: use `use_python`; user manages venvs directly (no wrapper).
- Node projects: use `use_node` (component-based; there is no nvm).
- Proxy: corporate zero-trust proxy is active by default (`http://127.0.0.1:3128`).
