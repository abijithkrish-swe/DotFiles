# INSTALL

Step-by-step instructions to set up these dotfiles on a new machine.

---

## 🖥 New device: full setup, in order

Each step needs the one before it. The sections below this one are reference.

1. **Base tools.**
   ```sh
   xcode-select --install
   # Homebrew: see brew.sh, then:
   brew install git fzf ripgrep bat fd eza zoxide tmux starship jq
   brew install colima docker docker-compose docker-buildx docker-credential-helper
   ```
2. **Dotfiles.** Clone anywhere, then deploy:
   ```sh
   git clone https://github.com/abijithkrish-swe/DotFiles.git ~/Projects/Personal/zshrc/configured
   cd ~/Projects/Personal/zshrc/configured && sh install_copy.sh deploy
   exec zsh
   ```
   - **Git identity:** deploy asks for this machine's identity, a default plus
     optional per-folder ones (`sh install_copy.sh identity`). It's stored in
     `~/.config/git/identity`, never in the repo.
   - **Agent guardrails:** deploy offers `agents`. It merges the guardrails
     into Claude Code (`~/.claude` and `~/.config/claude-personal`) and copies
     `AGENTS.md` to `~/.codex/`. Re-run it any time with
     `sh install_copy.sh agents`.
3. **Machine-specific settings** go in `~/.config/git/local` and `~/.zshrc.local`,
   never in the repo:
   - a git credential-helper path, if this Mac needs one, e.g. the CLT's
     `git-credential-osxkeychain`;
   - a corporate proxy. Its helper app appends exports to `~/.zshrc`; the next
     `deploy` offers `[m]` to move them to `~/.zshrc.local`.
4. **GitHub push access.** Create a fine-grained token: Contents read/write on
   the repos you push. Paste it at git's first password prompt; the macOS
   Keychain keeps it, one entry per repo (`useHttpPath`).
5. **Docker on Colima.** Link the Compose plugin as in
   `DotFiles/config/docker/cli-plugins/docker-readme.md`, then start Colima with
   `costart`. A new VM gets the template's 4 CPU, 8 GB, 100 GB and k3s. A VM
   that already existed keeps its own size; resize it with
   `colima stop && colima start --cpu 4 --memory 8 --kubernetes`.
6. **Components (tools).** Put each approved version in
   `~/Components/<Dir>/<version>/`, as the manifest lists them
   (`~/.config/components/components.conf`). Copy them from a backup, or
   download the same versions. Install **one Node first**, because toolshelf
   needs it. Layout notes:
   - **pnpm:** `Pnpm/<ver>/bin/` holds `pnpm` and its `dist/`;
   - **JDK:** `Contents/Home`;
   - **Rust:** its standalone installer with `--prefix`, not rustup.

   Check with `components_check`. Never approve or install a tool from an agent.
7. **toolshelf (the agents' tool server).**
   ```sh
   git clone https://github.com/abijithkrish-swe/toolshelf-mcp.git ~/Projects/Personal/toolshelf-mcp
   cd ~/Projects/Personal/toolshelf-mcp && sh install.sh --register   # tests, installs, registers Claude Code
   sh install.sh --print-config                                        # paste into Codex/ChatGPT, Claude app, Cursor
   ```
   Restart each app afterwards. The install tells you to redo this whenever
   the manifest's default Node changes.
8. **Observability (SigNoz, local).**
   ```sh
   obs_start        # first run: forges compose files offline, pulls ~1.5 GB of pinned images
   ```
   Then open **http://localhost:18080** and create the admin account. It's
   stored locally, and SigNoz won't open OTLP until an organization exists.
   Finish with `obs_status`, which should report OTLP answering on 4318.
9. **Verify.**
   - `components_check` and `devhelp`;
   - ask an agent "list my components", then "run `node --version` with Node 22";
   - repo checks: `zsh -f tests/components/parity.zsh`,
     `perl tests/agents/agents-md-test.pl`, and `npm test` in `toolshelf-mcp`.

Details: `Docs/AgentComponents.md` (agents, toolshelf, guardrails), `Docs/Observability.md` (AI-usage telemetry: what, why, how to change) and
`devhelp observability` / `devhelp toolshelf` / `devhelp components`.

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
sh install_copy.sh deploy   # install repo → $HOME
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
| `identity` | This machine's git identity (default + per-folder); stored outside the repo. |
| `agents` | Merge agent guardrails into Claude Code configs; copy `AGENTS.md` to `~/.codex/`. |
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
- **Corporate proxy** → set per machine in `~/.zshrc.local` (see step 3 above)

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
