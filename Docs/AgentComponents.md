# Agent Components — Design & Runbook

How AI coding agents (Claude Code, Codex, Copilot, any MCP client) consume the
tools under `~/Components/` — and only those — without installing or updating
anything on their own.

Read this when you: set up a new machine, add/update a component, or wire up a
new coding agent.

> Status: **steps 1–5 done** for Claude Code: manifest-driven MCP + zsh, sandboxed and Docker `run`, rules + guard hook + permissions. Left: step 6 cleanup; Codex later. See [Implementation order](#implementation-order).

---

## 1. Goals

1. **One approved list.** Agents use only component versions you planned. No
   ad-hoc downloads, no `:latest` images, no "I'll just brew install it".
2. **Agent-agnostic.** Works for any agent that speaks MCP; doesn't depend on
   zsh functions being present in the agent's shell.
3. **Ask before change.** Agents never install, upgrade or remove tools. They
   request; you decide.
4. **Contained execution.** Default: host sandbox. Untrusted code: Docker.
5. **Easy to evolve.** Adding a component version = unpack + one manifest line.

## 2. Architecture

```
                 ~/.config/components/components.conf
                 (approved list — lives in this repo)
                  │               │                 │
           zsh use_* / toolup   MCP server        AGENTS.md rules
           (you, interactive)   (every agent)     (every agent)
                                  │
                   ┌──────────────┴───────────────┐
             mode=sandbox (default)          mode=docker (untrusted)
             your macOS binaries             pinned image @sha256 digest
             sandbox-exec profile            Colima, project mount only
```

Three layers, from weakest to strongest:

| Layer | What | Strength |
|---|---|---|
| Rules | `AGENTS.md` telling agents to use the MCP, never install | Advisory |
| Interface | MCP server exposes only manifest entries; no install tool | Structural |
| Enforcement | Claude Code deny/ask + PreToolUse hook + sandbox, Codex approval/sandbox | Enforced |

Rules alone are not enough — every important rule must also exist as an
enforcement layer where the agent supports one.

## 3. The manifest (`components.conf`)

**Source:** `DotFiles/config/components/components.conf`
**Deployed to:** `~/.config/components/components.conf` (by `install_copy.sh deploy`)

Line-based on purpose: zsh and Node can both parse it with no dependencies
(zsh has no TOML/JSON parser; `jq`/Python aren't guaranteed on a fresh Mac).

Excerpt (see the real file for the full list):

```conf
# ---- tool definitions (rarely change) ----------------------------------
# @tool <name> dir=<folder under ~/Components> [key=value ...]
#   root=   tool home inside the version folder; `|` = candidates (default .)
#   bin=    bin dir relative to root; `|` = candidates (default bin)
#   check=  binary that must exist in bin for a version to be healthy
#   home=   env vars set to the tool home, comma-separated
@tool jdk       dir=JDK       root=Contents/Home|.  check=java      home=JAVA_HOME
@tool maven     dir=Maven     check=mvn             home=M2_HOME,MAVEN_HOME
@tool go        dir=GO        check=go              home=GOROOT
@tool redis     dir=Redis     bin=src|bin           check=redis-server
@tool mysql     dir=Mysql     bin=Core/bin          check=mysql          home=MYSQL_HOME
@tool rust      dir=Rust      check=cargo

# ---- approved versions (change often) -----------------------------------
# <tool> <version> [default] [autoload] [docker=<image>@sha256:<digest>]
jdk       11        default autoload
jdk       17
maven     3.9.12    default
node      20.19.5   default
redis     7.4.5     default autoload
mysql     8.0.43    default autoload
```

The parser rejects the whole file (with line numbers) on: unknown keys/flags,
versions for undefined tools, duplicates, a second `default`, or a `docker=`
image that isn't `@sha256:<64 hex>`.

Two parsers read it: zsh (`70-components-core.zsh`) and toolshelf
(`src/components.ts`). **`zsh -f tests/components/parity.zsh`** runs the
manifests in `tests/components/cases/` plus the real one through both, and
compares accept/reject, tools, versions + flags (sorted), images and every
`# query:` resolution line for line. Run it after changing either parser, and
change both together. Its first run found four differences, all fixed:
- zsh never sorted versions (a quoting slip);
- zsh read `@tool t dir` as `dir=dir`;
- zsh rejected CRLF files;
- toolshelf rejected CRLF files that contain comments.

Rules for the manifest:

- **A version not listed does not exist** to agents, even if its folder is on
  disk. A listed version whose folder is missing is reported as broken.
- `default` = what `toolup`/agents pick when no version is given.
  `autoload` = activated on interactive login (replaces `79-defaults.zsh`).
  `onpath` = only the bin dir goes on PATH at login, e.g. a database client for
  remote hosts. Nothing is activated or started. It is exclusive with `autoload`.
- **Docker images are pinned by digest, never by tag.** Use the multi-arch
  *index* digest (`docker buildx imagetools inspect <image:tag>`) so it
  resolves to arm64 on Apple Silicon.
- Version matching is **exact or unique-prefix only**. `17` → `17`; `2` with
  `20.x` and `22.x` installed → error listing candidates (never a silent pick).
  Versions sort numerically, not lexically.

Who reads it:

| Consumer | How |
|---|---|
| `70-components-core.zsh` | Parses at shell start; `use_<tool>` validates against it |
| `79-defaults.zsh` | Replaced by `autoload` flags |
| `toolup` / `.toolsrc` | Rejects versions not in manifest |
| MCP server | Re-reads on **every** call (no rebuild/restart after edits) |
| Rules file | `components_status` / MCP `list_components` are the source agents quote |

## 4. MCP server — `toolshelf-mcp`

- **Source:** `~/Projects/Personal/toolshelf-mcp` (its own git repo). Never run in place.
- **Installed copy:** `~/Components/toolshelf-mcp`. Built by the repo's `install.sh`,
  the same copy-don't-symlink idea as `install_copy.sh` for the dotfiles.
  `install.sh` stages a copy and builds it with the manifest's default Node.
  It runs the test suite (`npm test`: 71 tests in a fake `$HOME`, including real
  `sandbox-exec` runs) and a smoke test, then swaps it in. Any failure leaves the
  live install alone. `INSTALLED` records the revision.
- **Server name:** `toolshelf`, so agents see its tools as `mcp__toolshelf__*`.
- **Update flow:** edit source → commit → `./install.sh`. Agents pick it up on
  their next start. Manifest edits need no reinstall.

### Tools

| Tool | Kind | Purpose |
|---|---|---|
| `list_components` ✅ | read | Manifest entries + on-disk health (ok / broken / on-disk-but-unapproved) |
| `get_component_versions(tool)` ✅ | read | Approved versions for one tool |
| `get_defaults` ✅ | read | `default` / `autoload` versions from the manifest |
| `get_component_env(tools)` ✅ | read | Returns `export JAVA_HOME=…` / `export PATH=…` lines computed from the manifest. Agents prefix their commands with it. No zsh dependency. |
| `resolve_toolsrc(dir)` ✅ | read | A project's `.toolsrc` → exports + the `tools` map for `run`. Shell-only keys (`PATH_PREPEND`, `EXPORT`, MySQL start/stop) are reported, not applied |
| `run(command, cwd, tools?, timeout_seconds?)` ✅ | exec | Runs a command in the macOS sandbox with those versions; `tools` omitted → the project's `.toolsrc`. Applies the blocklist first. Docker mode: step 5 |
| `request_component(tool, version, reason, project?)` ✅ | write-request | Appends to `$XDG_STATE_HOME/toolshelf/requests.jsonl`; you review with `components_requests`. **Never installs.** Says so if the version is already approved |
| `colima_status` | read | One zsh invocation, not five (currently still five) |

Registered in Claude Code (user scope) with the pinned node, via `./install.sh --register`:
`claude mcp add toolshelf -s user -- ~/Components/Node/20.19.5/bin/node ~/Components/toolshelf-mcp/dist/index.js`.
Snippets for VS Code / Codex: `toolshelf-mcp/config/`.

Removed/changed from the first version of the server:

- `activate_component` / `deactivate_component` → replaced by `get_component_env`
  (shell-function commands fail in agent shells — see [Known issues](#8-known-issues--risks)).
- `get_active_versions` → removed; a fresh `zsh -i` only ever shows login defaults.
- Colima start/stop/delete → stay as "returns command for you to run"; not executed.
- No `install`, `upgrade`, `remove`, `download` tool. Ever.

### `run` — sandbox mode (default) ✅

Order of checks, then the run (`toolshelf-mcp/src/sandbox.ts`):

1. **Blocklist:** `~/.config/agents/blocklist.txt` (source:
   `DotFiles/config/agents/blocklist.txt`), `<regex> ## <reason>` per line. A
   match returns the reason and nothing runs, and is logged to
   `$XDG_STATE_HOME/toolshelf/blocked.jsonl` (the guard hook logs there too).
   A missing or invalid list refuses every run (fail closed).
2. **Project dir:** must be a real directory at least two levels under `$HOME`, and
   it or a parent (no higher than two levels below `$HOME`) must contain a project
   marker: `.git`, `.toolsrc`, `package.json`, `pom.xml`, `build.gradle*`,
   `settings.gradle*`, `build.xml`, `Cargo.toml`, `go.mod`, `pyproject.toml`,
   `Makefile`, or an empty `.toolshelf`. A folder of projects such as
   `~/Projects/Personal` is therefore rejected. It is never inside `~/.config`,
   `~/.local`, `~/.cache`, `~/Library`, `~/Components`, `~/.ssh`, and similar.
3. **Versions:** approved only, with the same matching rules as everywhere else.
4. **Environment:** built from scratch, nothing inherited (no tokens, no `use_secret` values):
   - PATH = approved component bins + `/usr/bin:/bin:/usr/sbin:/sbin` (no Homebrew);
   - the tools' home variables (`JAVA_HOME`, `GOROOT`, …);
   - proxy variables;
   - cache variables pointing at the sandbox caches;
   - `GOTOOLCHAIN=local`;
   - `MAVEN_OPTS` / `GRADLE_OPTS` with `-Djava.io.tmpdir`, because macOS Java ignores `TMPDIR`.
5. **Sandbox-only caches** under `$XDG_CACHE_HOME/toolshelf/`:
   - **Maven:** a generated `settings.xml` with proxy and local repo, passed via `MAVEN_ARGS`.
   - **Gradle:** a generated `gradle.properties` with proxy, `daemon=false` (a daemon
     would outlive the run's sandbox), and toolchains limited to approved JDKs.
   - **npm, Cargo, Go:** caches set through environment variables.

   The generated files are rewritten before every run, so a run can't change them
   for the next one. Your own caches are never writable.
6. **Sandbox profile** (`sandbox-exec`, generated per run into `$XDG_STATE_HOME/toolshelf/runs/<id>.sb`):
   - **write:** project dir, sandbox caches (including a private per-run tmp), `/dev/null` and similar;
   - **read:** everything except credentials and private data: `~/.ssh`, `~/.gnupg`,
     `~/.aws`, `~/.kube`, `~/.docker`, `~/.config/{secrets,gh,docker,npm,gcloud,claude-personal}`,
     `~/.claude*`, `~/.codex` (Codex / ChatGPT app login tokens), `~/.netrc`, `~/.npmrc`, Maven/Gradle/Cargo credential files,
     shell history (`~/.zshcache`), and all of `~/Library` (keychains, app data, cookies);
   - **network:** localhost only. That covers the zero-trust proxy and local test servers.
     There is no DNS, no direct internet, and no unix sockets, so the Docker socket is unreachable too.
7. **Run:** `zsh -f -c <command>` in its own process group. The timeout (default
   600 s, max 3600) kills the whole tree. The response has the exit code, duration
   and the last 8 KB of output (`tail_kb` changes it, up to 64). The full log is at
   `$XDG_STATE_HOME/toolshelf/runs/<id>.log`.

Verified on this Mac:
- **Blocked:** `brew install` and `curl … | bash`;
- **Refused:** writes outside the project, and reads of `~/.ssh`, shell history and `~/Library`;
- **Direct internet fails;**
- **Real dependency builds through the proxy:** Maven 3.9 and 4 with JDK 17 and 25,
  Gradle 8.14 and 9.3, `npm install`, `cargo run` with a crate, and `go mod tidy && go run`.

**Known limit:** Node's built-in `fetch()` ignores proxy variables, so it can't
reach the internet from a run (npm itself works).

### `run` — docker mode (untrusted code) ✅

Use `run(command, cwd, tools: {<one tool>}, mode: "docker", network?: "none" | "proxy")`
(`toolshelf-mcp/src/docker.ts`).

- **Image:** the one requested tool's `docker=` entry from the manifest. It must be
  pinned by digest, otherwise the run is refused. Exactly one tool per run, because a
  run uses one image. Build-tool images include their JDK: Maven 3.9.12 and
  Gradle 8.14.4 use 17, Gradle 9.3.1 uses 25. JDK 26.0.2 and Maven 4 have no
  image, and the error says which versions do. Images are pulled on first use
  (the pinned digest only), quietly.
- **Mounts:** the project at `/work`, read-write; files written there are owned by you.
  Nothing else from the Mac is visible: no `/Users`, no Docker socket, no SSH agent.
- **Container limits:** your uid, `--cap-drop ALL`, `no-new-privileges`, 2 CPUs,
  4 GB memory, 1024 processes. `/tmp` is a fresh 2 GB tmpfs that serves as `HOME`.
  Tool homes point there too (`GRADLE_USER_HOME`, `CARGO_HOME`, `GOPATH`,
  `-Duser.home`), because images keep them in root-owned folders.
- **No caches across runs.** Each run starts empty, so nothing planted by one
  untrusted run survives to the next. Dependencies download again each time.
- **`network: "none"`** is the default: no network at all.
- **`network: "proxy"`** gives enforced proxy-only access. Each run gets its own
  `--internal` Docker network, which has no route out. Its only exit is a forwarder
  container (`@image proxy-forwarder`, `alpine/socat`, pinned) on both that network
  and the bridge, which passes port 3128 to the Mac's proxy at `host.lima.internal`.
  - Proxy settings are passed in for curl, npm, cargo and go; for Java through
    `MAVEN_OPTS`/`GRADLE_OPTS`; and for Maven through a generated `settings.xml`
    mounted at `/opt/toolshelf/`.
  - Verified: npm, Maven, cargo and go builds fetch their dependencies. Direct
    internet fails (no DNS), and a raw connection to the Mac's proxy port fails
    (`ENETUNREACH`).
- **Timeout:** `docker kill` on top of killing the process group. Containers,
  the network and the forwarder are always removed afterwards.
- **No blocklist in docker mode.** Commands can't affect the host's tools,
  so the blocklist, which protects them, applies to sandbox mode only.
- **Colima must already be running.** If it isn't, the error says to run `costart`;
  toolshelf never starts it.

## 5. Agent guardrails

All sources are in `DotFiles/config/agents/`, deployed to `~/.config/agents/`.
`install_copy.sh agents` (which `deploy` offers) merges them into every Claude
Code config on the machine.

### Rules file (all agents) ✅

**Source:** `DotFiles/config/agents/AGENTS.md`. It is six short rules; long rule files get ignored:
1. tools only via toolshelf;
2. never install or upgrade, and use `request_component` instead;
3. builds and tests via `run`;
4. never change build-tool or toolchain versions;
5. ask before adding dependencies;
6. never read secrets.

| Agent | How it gets the rules | Status |
|---|---|---|
| Claude Code (default, `~/.claude`) | `~/.claude/CLAUDE.md` imports `@~/.config/agents/AGENTS.md` | ✅ |
| Claude Code (personal, `myclaude` → `~/.config/claude-personal`) | `CLAUDE.md` in that dir, same import | ✅ |
| Codex | `~/.codex/AGENTS.md` | later |
| Copilot / others | their global instructions file | not planned for now |

### Claude Code ✅

`myclaude` sets `CLAUDE_CONFIG_DIR=~/.config/claude-personal`. Claude Code then
reads settings, hooks, permissions, `CLAUDE.md` **and MCP registrations** from
that dir instead of `~/.claude`. Everything below is therefore applied to both
configs:
- `install_copy.sh agents` covers settings, hooks, permissions and `CLAUDE.md`.
- toolshelf's `install.sh --register` covers the MCP registration.

`DotFiles/config/agents/claude-settings.json` is merged into each `settings.json`:
- permission lists are unioned;
- our hook replaces an older copy of itself;
- everything else in the file is kept, in order;
- the file is backed up to `Backup/<ts>/home/` first, and re-running is a no-op.

| Setting | Value |
|---|---|
| `permissions.allow` | read-only toolshelf tools (`list_components`, `get_component_versions`, `get_defaults`, `get_component_env`, `resolve_toolsrc`, `colima_status`) and `request_component`, which only records a request. Also read-only Bash commands that came up often in a transcript scan (`/fewer-permission-prompts`, 2026-11-11) and that Claude Code doesn't already allow: `docker image inspect/ls`, `docker history`, `docker system df`, `docker compose logs/ps`, `colima status/list`, `git merge-base`, `claude mcp get`, `shasum`, `defaults read`, `sips -g`. Never interpreters, `awk`, task runners or anything that writes |
| `permissions.ask` | `mcp__toolshelf__run` |
| `permissions.deny` | a backstop to the hook for the most common install commands: sudo, Homebrew changes, global npm, pip, rustup, cargo install, sdkman, nvm, softwareupdate. Also `Edit(...)` (every file-editing tool) on the rules themselves: `~/.config/agents/**`, `~/.config/components/**` and both configs' `settings.json`/`settings.local.json`, so an agent can't loosen its guardrails or approve its own version requests. Bash writes to the same paths are caught by a blocklist rule; reads stay allowed. You change these in the dotfiles repo and deploy |
| `hooks.PreToolUse` (matcher `Bash`) | `$HOME/.config/agents/guard.sh` |
| `hooks.Notification` / `hooks.Stop` | `afplay` Sosumi (needs input or approval) / Glass (reply done). Every config gets them, `myclaude` included |

**`guard.sh`** is a Perl script with no dependencies. It reads the hook JSON, matches
`tool_input.command` against `blocklist.txt` (the same list `run` uses), and exits 2
with the reason. Claude sees the reason and is pointed at `request_component`.
- **Logging:** each block appends one JSON line (time, source, reason, match,
  command, cwd, session) to `~/.local/state/toolshelf/blocked.jsonl`, shared with
  `run`. Best effort: a logging failure never changes the decision. Review with
  `toolshelf_report`.
- **Heredocs:** heredoc bodies are file content, so they are not matched. Writing docs
  that mention blocked commands is fine. A heredoc fed to a shell or interpreter
  (`bash <<EOF`, `cat <<EOF | sh`) is matched as code.
- **Fails closed:** a missing blocklist blocks every Bash command.
- **Verified:** 28 cases in total.
  - Blocked: install, upgrade and fetch-and-run patterns, including ones after `cd x &&`,
    in an executed heredoc, or after a data heredoc.
  - Passed: normal builds, `.venv/bin/pip`, `grep "sudo"`, `GOTOOLCHAIN=local`, and doc heredocs.
- **Residual false positives:** blocked words inside quoted arguments, for example a
  commit message that mentions one. Rephrase, or write the text to a file first.

Not used: Claude Code's built-in `/sandbox`. Builds go through toolshelf `run`,
which has its own sandbox. Revisit if Claude's direct Bash calls need confining too.

### Codex (`~/.codex/config.toml`): later

```toml
approval_policy = "on-request"
sandbox_mode    = "workspace-write"
[mcp_servers.toolshelf]
command = "/Users/<you>/Components/Node/<pinned>/bin/node"
args    = ["/Users/<you>/Components/toolshelf-mcp/dist/index.js"]
```
Snippet: `toolshelf-mcp/config/codex.toml`. Rules: link `~/.codex/AGENTS.md` to
`~/.config/agents/AGENTS.md`.

### Copilot / others

Usually rules-only plus whatever approval setting the client offers for
terminal commands (keep auto-approve **off**). Treat them as the least trusted
agents.

## 6. Repo layout

```
DotFiles/config/components/components.conf     # the manifest
DotFiles/config/agents/AGENTS.md               # shared rules
DotFiles/config/agents/blocklist.txt           # shared by guard.sh + MCP run
DotFiles/config/agents/guard.sh                # Claude Code PreToolUse hook
DotFiles/config/agents/claude-settings.json    # merged into each Claude config's settings.json
```

`deploy` copies these to `~/.config/agents/`; `install_copy.sh agents` merges
into Claude configs. The sandbox profile is generated per run by toolshelf-mcp
(no template file). MCP server source stays in its own repo.

## 7. Runbooks

### New machine

1. Install Xcode CLT, Homebrew, git. Clone this repo.
2. `./install_copy.sh deploy` — zsh, configs, manifest, agent rules. It asks for this
   machine's git identity, including any per-folder rules (`install_copy.sh identity`).
3. Restore `~/Components/` (copy from backup or re-download archives listed in
   the manifest). Install **one Node first** — the MCP server needs it.
4. `components_check`: confirms every manifest line resolves on disk.
5. Clone `toolshelf-mcp` anywhere, then `./install.sh --register`. This builds
   into `<components>/toolshelf-mcp` and registers it in Claude Code. For a
   different layout, add `--prefix DIR`, `--components DIR` and/or
   `--manifest FILE`. Registration passes the paths through. See `./install.sh --help`.
6. Register it in other agents with `config/` snippets. Always use the
   **absolute path to the pinned node**, not bare `node`, because agents' PATH differs.
7. Install Colima/Docker; `costart`; `docker pull` each manifest digest once.
8. Verify: ask an agent "list my components" and "run `java -version` with JDK 17".

### Add a new version of an existing component

1. Unpack to `~/Components/<Dir>/<version>/`.
2. Add a line to `DotFiles/config/components/components.conf`
   (+ `docker=` digest if it has a Linux image counterpart).
3. `./install_copy.sh deploy` (or `sync`).
4. `components_check`. No MCP rebuild needed.

### Install Rust (tool already defined, no versions yet)

1. Download the standalone installer tarball for `aarch64-apple-darwin`.
2. `./install.sh --prefix=$HOME/Components/Rust/<ver>` — **not rustup**
   (rustup self-updates toolchains, which bypasses the approved list).
3. Add `rust <ver> default` to the manifest, deploy, check `list_components`.
4. `CARGO_HOME` (registry cache, `cargo install` bins) is `$XDG_DATA_HOME/cargo`;
   it is a cache, not the toolchain.

### Add a brand-new component type

1. Unpack to `~/Components/<Dir>/<version>/`.
2. Add `@tool` line + version lines to the manifest.
3. Only if it needs special behaviour (start/stop like Redis/MySQL): add a zsh
   module `7x-<tool>.zsh`. Plain PATH/HOME tools need no code.
4. Deploy, `components_check`.

### Update / retire a version

1. Add the new version first; switch `default`/`autoload` to it.
2. Grep projects for `.toolsrc` pinning the old one.
3. Remove the manifest line, then the folder. Agents stop seeing it immediately.

### Refresh Docker digests (security updates)

1. `docker buildx imagetools inspect <image:tag>` → copy index digest.
2. Update the manifest line, review the diff, commit.
3. Do this deliberately (e.g. monthly). Pinned digests don't self-update.

### Run a project (sandbox or docker mode)

You ask the agent in plain words. It calls toolshelf `run` with the right
arguments. Cheat sheet: `devhelp toolshelf`.

1. **Pick the mode.**
   - **Sandbox** (default) is for your own projects. It uses your approved
     installs and keeps caches between runs.
   - **Docker** is for untrusted code: freshly cloned repos, scripts from the
     internet, unreviewed generated code, dependencies with install scripts.
     It uses one tool per run, with that tool's pinned image.
2. **Make sure the project qualifies.**
   - The folder (or a parent) has `.git`, `.toolsrc`, `package.json`, `pom.xml`,
     `build.gradle*`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Makefile`, or an
     empty `.toolshelf`.
   - The versions it needs are approved (`components_check`). For docker mode
     they also need a `docker=` image (`components_images`).
3. **Pin versions per project (optional).** Put them in `.toolsrc`, for example
   `JDK=17` and `MAVEN=3.9`. `run` uses it when no tools are given, and
   `toolup` uses it in your shell.
4. **Ask**, for example:
   - "Build and test ~/Projects/Personal/app with JDK 17 and Maven"
   - "This repo is untrusted; run its tests in docker, with network for dependencies"

   Docker mode also needs Colima running (`costart`).
5. **Check results:**
   - The reply has the exit code and the last 8 KB of output.
   - The full log is in `~/.local/state/toolshelf/runs/<id>.log`.
   - Requests for missing versions show up in `components_requests`.
6. **Review now and then:** `toolshelf_report [days]` summarises runs (by
   project, exit code, the most common commands, slowest, failed, ones that hit
   the sandbox or edited files) and every blocked attempt with its reason. Use
   it to tune `blocklist.txt` and Claude's `permissions.allow`.

Typical arguments:

```
run cwd: ~/Projects/Personal/app  tools: {"jdk": "17", "maven": ""}  command: mvn -q test
run cwd: ~/Projects/x  tools: {"python": ""}
    command: python3 -m venv .venv && .venv/bin/pip install -q -r requirements.txt && .venv/bin/pytest -q
run cwd: ~/Projects/untrusted  tools: {"node": "22"}  mode: docker  network: proxy
    command: npm ci --silent && npm test
```

### Try untrusted code yourself (`dockrun`)

For open-source tools and repos you want to try without trusting them, and
which don't ship a Docker image of their own: `dockrun` (zsh,
`70-components-dockrun.zsh`) runs a command, or a shell, in a throwaway
container from the manifest's pinned image for one tool, with the current
folder at `/work`. The container settings are the same as toolshelf docker
mode: no capabilities, no-new-privileges, your uid, cpu/memory/pids caps, a
fresh `/tmp` as `HOME`, nothing else mounted.

| Flag | Network |
|------|---------|
| none | `--network none` |
| `--net` | per-run internal network + the `proxy-forwarder` image → zero-trust proxy only (same as agents' `network: proxy`) |
| `--internet` | normal bridge network; needed for `-p PORT[:C]`, which binds `127.0.0.1` only. For machines without a local proxy |

- **Refused folders:** `$HOME` itself, `/`, private dirs (`~/.ssh`, `~/.config`,
  `~/Library` …), and anything outside `~`. Colima shares only the home folder
  with its VM, so any other folder would mount as an empty, root-owned `/work`.
- **`-n`** prints the docker commands without running them.
- **Image log:** images it uses go into `images.log`, so `components_images`
  sees them.
- **Tests:** `zsh -f tests/components/dockrun-test.zsh [--live]`. The dry-run
  checks need no Docker. `--live` adds real containers: isolation, exit codes,
  capabilities.
- **Agents never use it:** their Bash shells don't load zsh modules. They use
  `run` with `mode: "docker"`.

### Add a new coding agent

1. Register the MCP server (absolute node path + absolute `dist/index.js`).
2. Point its global instructions at `AGENTS.md`.
3. Turn on its approval/sandbox settings; turn auto-approve off.
4. If it supports hooks, wire `guard.sh`.
5. Test: ask it to `brew install jq` — it must refuse or be blocked.
6. Record it in the table in [section 5](#5-agent-guardrails).

## 8. Known issues & risks

| # | Issue | Mitigation |
|---|---|---|
| 1 | **Agent shells don't have your zsh helpers.** Claude Code's shell snapshot drops `_`-prefixed functions (`_jdk_home`, `_mysql_bindir_for`, …), so `use_jdk 17` fails there. State also doesn't persist between commands. | Agents use `get_component_env` / `run`, never `use_*`. |
| 2 | **Build tools download things themselves.** Gradle/Maven wrappers fetch distributions, `npx`/corepack fetch packages, IntelliJ offers JDK downloads. These are the main "unplanned reference" leak. | Hook blocks wrapper-version changes; sandbox network = proxy only; prefer manifest `gradle`/`mvn` over `./gradlew`/`./mvnw` (or point `distributionUrl` at a local file). |
| 3 | **Sandbox vs. real builds.** Maven/Gradle/npm/cargo/go need network for dependencies and write caches. | Profile explicitly allows those caches + proxy. Expect a few iterations of the profile. |
| 4 | **`sandbox-exec` is deprecated by Apple** (still works; Claude Code itself relies on Seatbelt). | Keep the profile in one template; Docker mode is the fallback. |
| 5 | **The MCP `run` tool bypasses the agent's own permission checks.** Commands passed to an MCP tool aren't seen by Claude Code's Bash deny rules or hook. | `run` applies `blocklist.txt` itself; set `run` to "ask" in every client. |
| 6 | **Docker ≠ host.** Linux images match versions, not exact builds; macOS binaries in `~/Components` can't run in containers. "Works in Docker, fails on host" is possible. | Docker only for untrusted code and services; real builds in sandbox mode. |
| 7 | **Digest pinning & arch.** Single-arch digests may pull amd64 → slow emulation on Apple Silicon. | Pin the multi-arch index digest. |
| 8 | **Proxy & certs inside sandbox/containers.** Zero-trust proxy + custom CA must be passed in, or TLS fails. | `run` injects proxy env + mounts `~/.config/zero-trust-certs.pem`; set `KEEP_ZERO=false` paths accordingly. |
| 9 | **Bootstrap dependency.** The MCP server needs a Node from `~/Components`. Removing that version breaks the MCP for every agent. | Mark that Node version in the manifest as `default`; retire it last. |
| 10 | **MCP tool timeouts.** Clients cap tool-call duration; long builds can exceed it. | `run` returns early with a log path; agent tails the log. |
| 11 | **Rules are advisory for agents without hooks/sandbox** (Copilot, desktop apps). | Treat as least trusted; keep auto-approve off; rely on proxy/OS. |
| 12 | **Pattern blocklists are bypassable** (scripts, aliases, encoded commands). | Blocklist is a speed bump; sandbox + network restriction is the real wall. |
| 13 | **Two copies of the manifest logic** (zsh parser + Node parser). | Keep the format trivial; `tests/components/parity.zsh` checks that both parsers agree (24 cases incl. the real manifest). |

## Implementation order

- [x] 1. `components.conf` + Node parser; MCP read tools + `get_component_env` use it; MCP registered from project path with pinned node
- [x] 2. zsh `70-components-core.zsh` reads the manifest (use_*, toolup, completion, `components_check`); `79-defaults.zsh` autoloads from `autoload` flags
- [x] 3. `run` (sandbox mode), `request_component` (+ `components_requests` in zsh), `resolve_toolsrc`; blocklist in `DotFiles/config/agents/`
- [x] 4. `AGENTS.md`, `guard.sh`, Claude Code settings in both configs (`install_copy.sh agents`, offered by deploy); toolshelf registered in both. Codex: later
- [x] 5. `run` docker mode: pinned images in the manifest, per-run container, network none or enforced proxy (internal network + forwarder)
- [x] 6. ~~`components_check`~~ (done in step 2); ~~fix MCP README/config; run MCP from installed copy~~ (done); ~~colima_status single zsh call~~ (done: direct parallel CLI calls, 5.4 s → 1.5 s)
