# AI Context — Configured Dotfiles

## What This Project Is

A **modular Zsh dotfiles manager** that keeps `$HOME` clean. All shell configuration lives in numbered files under `DotFiles/zsh.d/`, loaded in lexical order by a minimal `~/.zshrc` loader. An installer (`install_copy.sh`) deploys everything into place, with drift review, bidirectional sync, backup, and restore support.

## Directory Layout

```
DotFiles/
  zshrc                  # Minimal loader → sources ~/.zsh.d/*.zsh in order
  vimrc                  # Vim configuration
  zsh.d/                 # Numbered shell modules (the core of this project)
    help/                # Per-tool help files for `devhelp` system
  config/                # App configs (starship, git, tmux, fzf, docker, colima)
    secrets/             # Encrypted vault storage
Docs/                    # Human documentation (UserGuide, Components, Advanced)
Backup/                  # Timestamped backups created by installer
install_copy.sh          # Deployment script
```

## zsh.d/ Numbering Convention

Files load in ascending order. Each range has a purpose:

| Range   | Category                | Files |
|---------|-------------------------|-------|
| 00–09   | Shell options & security | `00-options`, `01-security` |
| 10–19   | Environment, PATH, XDG, cache dirs | `10-env-path` |
| 20–29   | Oh-My-Zsh core          | `20-ohmyzsh` |
| 30–39   | Prompt (Starship)       | `30-prompt` |
| 40–49   | Navigation & CLI tools  | `40-navigation-search`, `41-eza`, `42-bat`, `43-fd`, `44-fzf`, `46-tmux` |
| 50–59   | History settings        | `50-history` |
| 60–69   | Aliases & utilities     | `60-aliases`, `61-aliases-extras`, `62-git-sync`, `63-colima`, `65-secrets-vault` |
| 70–79   | Component core + dev tools | `70-components-core`, `71-jdk`, `72-redis`, `73-ant`, `74-maven`, `74-protobuf`, `75-mysql`, `76-python`, `77-golang`, `78-node`, `79-defaults` |
| 80–89   | Completions & build tools | `80-completions`, `85-gradle` |
| 90–99   | NVM, local overrides    | `90-nvm`, `99-local-overrides` |
| zz-*    | Help system (loads last) | `zz-devhelp` |

**Known anomaly**: `74-maven.zsh` and `74-protobuf.zsh` share the same number prefix.

## Component System ("Rule of 5")

All developer tools are managed under `~/Components/<Tool>/<Version>/` with a standard API.

### Standard Functions per Component

```
<tool>_list          # List installed versions
use_<tool> <ver>     # Activate version (updates PATH + env vars)
use_<tool> off       # Deactivate
<tool>_clear         # Same as off
```

### Aliases per Component

```
<tool>_versions      → <tool>_list
<tool>_use           → use_<tool>
<tool>_off           → <tool>_clear
```

### Core Helpers (70-components-core.zsh)

- `component_switch_path <VAR> <PATH>` — Remove old PATH entry, add new one
- `component_set_status <NAME> <VER>` — Track active version in `COMPONENTS_STATUS`
- `components_status` — Display all active components
- `load_components_completion <FUNC> <DIR>` — Register tab completion

### Supported Components

| Tool     | File          | Use Function        | Env Vars Set              |
|----------|---------------|---------------------|---------------------------|
| JDK      | 71-jdk        | `use_jdk`           | `JAVA_HOME`               |
| Redis    | 72-redis      | `redis_use`         | —                         |
| Ant      | 73-ant        | `use_ant`           | `ANT_HOME`                |
| Maven    | 74-maven      | `use_maven`         | `M2_HOME`, `MAVEN_HOME`   |
| Protobuf | 74-protobuf   | `protobuf_use`      | —                         |
| MySQL    | 75-mysql      | `use_mysql`         | `MYSQL_HOME`              |
| Python   | 76-python     | `use_python`        | — (PATH only, no PYTHONHOME) |
| Go       | 77-golang     | `use_go`            | `GOROOT`                  |
| Node     | 78-node       | `use_node`          | —                         |
| Gradle   | 85-gradle     | `use_gradle`        | `GRADLE_HOME`             |

### Toolup (.toolsrc)

Per-project tool versions. Create `.toolsrc` in project root, run `toolup`.

```ini
JDK=17
MAVEN=3.9.6
GRADLE=8.6
NODE=20.0
REDIS=7.2
PYTHON=3.11
GO=1.22
ANT=1.10
PROTOBUF=3.0
MYSQL_DEFAULT_VER=8.0.43
MYSQL_START_VER=8.0.43
PATH_PREPEND=/custom/bin
EXPORT=MY_VAR=value
```

## History Isolation

History files live in `~/.zshcache/` with per-environment separation:

| Environment   | File                              | Sharing       |
|---------------|-----------------------------------|---------------|
| Normal terminal | `zsh_history`                   | `SHARE_HISTORY` ON (live across tabs) |
| VS Code       | `zsh_history_vscode`              | OFF — `INC_APPEND_HISTORY` instead |
| IntelliJ      | `zsh_history_jetbrains`           | OFF — `INC_APPEND_HISTORY` instead |
| Eclipse       | `zsh_history_eclipse`             | OFF — `INC_APPEND_HISTORY` instead |

Detection is in `10-env-path.zsh`; options are enforced in `50-history.zsh` (after Oh-My-Zsh loads).

## Secrets Vault (65-secrets-vault.zsh)

AES-256-CBC encrypted per-secret storage in `~/.config/secrets/vault.store`.

| Function        | Purpose                                      |
|-----------------|----------------------------------------------|
| `add_secret`    | Encrypt & store (prompts for value + password) |
| `show_secret`   | Decrypt & display                            |
| `use_secret`    | Decrypt & export to current session env      |
| `delete_secret` | Remove from vault                            |
| `vault_ls`      | List all keys                                |
| `vault_load`    | Bulk import from plaintext file              |

## Help System (zz-devhelp.zsh)

`devhelp <topic>` shows cheatsheets. Help modules register via `_devhelp_register "topic" _func`.

Available topics: bat, colima, default, docker-basics, eza, fd, fzf-basic, fzf-intermediate, fzf-advanced, git, git-advanced, gradle, jdk, k8s, maven, mysql, node, obs, python, redis, secrets, tmux, vim, vim-advanced.

## Installer (install_copy.sh)

Verb-based. Running with no verb prints usage and changes nothing.

```
./install_copy.sh deploy           # Install repo → $HOME (drift review, backup, apply)
./install_copy.sh deploy --force   # Skip drift review + confirmation (discards home edits)
./install_copy.sh sync             # Bidirectional reconcile, direction chosen per change
./install_copy.sh backup list      # Show available backups
./install_copy.sh backup show [ts] # Summarize a backup (latest if no ts)
./install_copy.sh backup create    # Manual snapshot of managed $HOME paths
./install_copy.sh backup restore [ts]  # Restore $HOME from backup
./install_copy.sh help
```

**What goes where:**
- `DotFiles/zshrc` → `~/.zshrc` (copy)
- `DotFiles/vimrc` → `~/.vimrc` (copy)
- `DotFiles/zsh.d/` → `~/.zsh.d/` (mirror — removes stale files)
- `DotFiles/config/*` → `~/.config/*` (merge copy — untracked files kept)
- `~/.config/secrets/` → always excluded, from deploy/sync/backup alike

**deploy** reviews local drift before overwriting anything: per file you can fold the
home edit back into the repo (`y`/`a`), discard it (`n`), or abort (`q`). Then it backs
up every touched home path to `Backup/<ts>/home/` and applies.

**sync** is the bidirectional counterpart — neither side authoritative, per change pick
`>` (repo→home), `<` (home→repo), `x` (delete, only-side), `s`, `q`. Note `<` writes over
the repo working tree; the replaced file is backed up to `Backup/<ts>/repo/` first, and
tracked files are also recoverable via git.

## Key Design Conventions

1. **New component file**: Pick a number in the correct range. Follow the `<tool>_list` / `use_<tool>` / `<tool>_clear` pattern. Call `load_components_completion`. Add a `TOOL=<ver>` case in `toolup()` inside `70-components-core.zsh`.
2. **New help topic**: Create `help/<topic>.zsh`, define `_devhelp_<topic>()`, call `_devhelp_register`.
3. **Feature toggles**: Many tools use `export ENABLE_<FEATURE>=true/false` (e.g., `ENABLE_STARSHIP`, `ENABLE_FZF_BASICS`, `ENABLE_NVM`, `ENABLE_TMUX`).
4. **XDG compliance**: All runtime state goes under `~/.zshcache/`. App configs go under `~/.config/`.
5. **No PYTHONHOME**: Python component only modifies PATH to avoid breaking venvs.
6. **Proxy**: Zero-trust proxy controlled by `KEEP_ZERO=true/false` in `01-security.zsh`.
7. **Machine-specific overrides**: Put in `~/.zshrc.local` (loaded by `99-local-overrides.zsh`, not in repo).
