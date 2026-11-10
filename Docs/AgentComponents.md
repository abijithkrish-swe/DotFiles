# Agent Components — Design & Runbook

How AI coding agents (Claude Code, Codex, Copilot, any MCP client) consume the
tools under `~/Components/` — and only those — without installing or updating
anything on their own.

Read this when you: set up a new machine, add/update a component, or wire up a
new coding agent.

> Status: **steps 1–2 done**: the manifest drives the MCP read tools, `get_component_env` and the zsh `use_*` / `toolup` / login defaults. See [Implementation order](#implementation-order).

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

Rules for the manifest:

- **A version not listed does not exist** to agents, even if its folder is on
  disk. A listed version whose folder is missing is reported as broken.
- `default` = what `toolup`/agents pick when no version is given.
  `autoload` = activated on interactive login (replaces `79-defaults.zsh`).
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
  It smoke-tests the result, then swaps it in. `INSTALLED` records the revision.
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
| `resolve_toolsrc(dir)` | read | Parse a project's `.toolsrc` → resolved versions (errors on unknown) |
| `run(tools, command, cwd, mode)` | exec | Runs a command with those versions. `mode`: `sandbox` (default) or `docker`. Applies the same command blocklist as the hook. |
| `request_component(tool, version, reason)` | write-request | Appends to `~/.config/components/requests.log`. **Never installs.** |
| `colima_status` | read | One zsh invocation, not five (currently still five) |

Registered in Claude Code (user scope) with the pinned node, via `./install.sh --register`:
`claude mcp add toolshelf -s user -- ~/Components/Node/20.19.5/bin/node ~/Components/toolshelf-mcp/dist/index.js`.
Snippets for VS Code / Codex: `toolshelf-mcp/config/`.

Removed/changed from today's server:

- `activate_component` / `deactivate_component` → replaced by `get_component_env`
  (shell-function commands fail in agent shells — see [Known issues](#8-known-issues--risks)).
- `get_active_versions` → removed; a fresh `zsh -i` only ever shows login defaults.
- Colima start/stop/delete → stay as "returns command for you to run"; not executed.
- No `install`, `upgrade`, `remove`, `download` tool. Ever.

### `run` — sandbox mode (default)

- macOS `sandbox-exec` with a generated profile:
  - **read:** broad (system, `~/Components`, project)
  - **write:** project dir + declared caches only (`~/.m2`, `~/.gradle`,
    `~/.npm`, `~/.cache/go-build`, `$TMPDIR`)
  - **network:** only `127.0.0.1:3128` (the zero-trust proxy) and localhost —
    so every outbound request goes through the proxy or fails
- Minimal env: manifest-computed PATH/homes + proxy vars + `NODE_EXTRA_CA_CERTS`.
  **No inherited secrets** (anything from `use_secret` is dropped).
- Timeout + output cap; long builds return a tail and a log file path.

### `run` — docker mode (untrusted code)

- Image = manifest `docker=` digest for the requested versions. No digest → refuse.
- `docker run --rm --network none -v <project>:/work -w /work …` by default;
  `network: "proxy"` opt-in adds proxy env + mounted CA cert.
- No host home, no SSH agent, no Docker socket mounted.
- Requires Colima running; if not, return "run `costart`" — don't start it.

## 5. Agent guardrails

### Rules file (all agents)

**Source:** `DotFiles/config/agents/AGENTS.md`
Deployed/symlinked to every agent's global instructions location:

| Agent | Location |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md` (import or symlink) |
| Codex | `~/.codex/AGENTS.md` |
| Copilot (VS Code) | user-level instructions file / per-repo `.github/copilot-instructions.md` |
| Others | Whatever "global instructions" path they support |

Core rules (keep short — long rule files get ignored):

```markdown
- Tools come ONLY from the `toolshelf` MCP. Use `get_component_env` or `run`.
- Never install, upgrade, or remove tools, runtimes, or global packages
  (brew, sdkman, nvm, asdf, pyenv, npm -g, pip outside a venv, curl|sh).
  Need something missing? Call `request_component` and tell the user.
- Run builds/tests via `run` (sandbox). Run untrusted code via `run` mode=docker.
- Do not change Gradle/Maven wrapper versions or Docker image tags/digests.
- Project dependencies (npm/maven/pip into a project venv) need user approval.
```

### Claude Code (`~/.claude/settings.json`)

- `permissions.deny`: `brew install`, `brew upgrade`, `npm install -g`,
  `pip install` (outside venv), `curl … | sh`, `sdk install`, `nvm install`,
  `asdf install`, `softwareupdate`
- `permissions.ask`: `npm install`, `mvn`/`gradle` wrapper upgrades,
  `mcp__toolshelf__run`, `mcp__toolshelf__request_component`
- `permissions.allow`: the read-only `mcp__toolshelf__*` tools
- **PreToolUse hook** (`matcher: Bash`) → `DotFiles/config/agents/guard.sh`.
  Same blocklist as the MCP `run` tool (single file: `blocklist.txt`). Exit
  code 2 blocks with a reason. Catches `cd x && brew install`, `python -m pip`,
  `npx -y <pkg>`, etc.
- **Sandbox** (`/sandbox`): enable; restrict writes to the project, network
  to the proxy. Check exact settings keys against current Claude Code docs
  when implementing.

### Codex (`~/.codex/config.toml`)

```toml
approval_policy = "on-request"
sandbox_mode    = "workspace-write"
[mcp_servers.toolshelf]
command = "/Users/<you>/Components/Node/<pinned>/bin/node"
args    = ["/Users/<you>/Components/toolshelf-mcp/dist/index.js"]
```

### Copilot / others

Usually rules-only plus whatever approval setting the client offers for
terminal commands (keep auto-approve **off**). Treat them as the least trusted
agents.

## 6. Repo layout (planned)

```
DotFiles/config/components/components.conf     # the manifest
DotFiles/config/agents/AGENTS.md               # shared rules
DotFiles/config/agents/blocklist.txt           # shared by hook + MCP run
DotFiles/config/agents/guard.sh                # Claude Code PreToolUse hook
DotFiles/config/agents/claude-settings.json    # merged into ~/.claude/settings.json
DotFiles/config/agents/codex-config.toml       # merged into ~/.codex/config.toml
DotFiles/config/agents/sandbox.sb.tmpl         # sandbox-exec profile template
```

`install_copy.sh deploy` places/merges these. MCP server source stays in its
own repo.

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
4. Set `CARGO_HOME` (registry cache) per project or leave at `~/.cargo`;
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
| 3 | **Sandbox vs. real builds.** Maven/Gradle/npm need network for dependencies and write to `~/.m2`, `~/.gradle`, `~/.npm`. | Profile explicitly allows those caches + proxy. Expect a few iterations of the profile. |
| 4 | **`sandbox-exec` is deprecated by Apple** (still works; Claude Code itself relies on Seatbelt). | Keep the profile in one template; Docker mode is the fallback. |
| 5 | **The MCP `run` tool bypasses the agent's own permission checks.** Commands passed to an MCP tool aren't seen by Claude Code's Bash deny rules or hook. | `run` applies `blocklist.txt` itself; set `run` to "ask" in every client. |
| 6 | **Docker ≠ host.** Linux images match versions, not exact builds; macOS binaries in `~/Components` can't run in containers. "Works in Docker, fails on host" is possible. | Docker only for untrusted code and services; real builds in sandbox mode. |
| 7 | **Digest pinning & arch.** Single-arch digests may pull amd64 → slow emulation on Apple Silicon. | Pin the multi-arch index digest. |
| 8 | **Proxy & certs inside sandbox/containers.** Zero-trust proxy + custom CA must be passed in, or TLS fails. | `run` injects proxy env + mounts `~/.config/zero-trust-certs.pem`; set `KEEP_ZERO=false` paths accordingly. |
| 9 | **Bootstrap dependency.** The MCP server needs a Node from `~/Components`. Removing that version breaks the MCP for every agent. | Mark that Node version in the manifest as `default`; retire it last. |
| 10 | **MCP tool timeouts.** Clients cap tool-call duration; long builds can exceed it. | `run` returns early with a log path; agent tails the log. |
| 11 | **Rules are advisory for agents without hooks/sandbox** (Copilot, desktop apps). | Treat as least trusted; keep auto-approve off; rely on proxy/OS. |
| 12 | **Pattern blocklists are bypassable** (scripts, aliases, encoded commands). | Blocklist is a speed bump; sandbox + network restriction is the real wall. |
| 13 | **Two copies of the manifest logic** (zsh parser + Node parser). | Keep the format trivial; add a `components_check` that both sides agree on. |

## Implementation order

- [x] 1. `components.conf` + Node parser; MCP read tools + `get_component_env` use it; MCP registered from project path with pinned node
- [x] 2. zsh `70-components-core.zsh` reads the manifest (use_*, toolup, completion, `components_check`); `79-defaults.zsh` autoloads from `autoload` flags
- [ ] 3. ~~`get_component_env`~~ (done in step 1); `run` (sandbox mode), `request_component`, `resolve_toolsrc`
- [ ] 4. `AGENTS.md`, `blocklist.txt`, `guard.sh`, Claude Code + Codex settings; deploy via installer
- [ ] 5. `run` docker mode with pinned digests
- [ ] 6. ~~`components_check`~~ (done in step 2); ~~fix MCP README/config; run MCP from installed copy~~ (done); colima_status single zsh call
