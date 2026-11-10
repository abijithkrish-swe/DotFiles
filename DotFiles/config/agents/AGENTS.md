# Agent rules: developer tools on this machine

These rules apply to every coding agent. They are short on purpose.

1. **Tools come only from the `toolshelf` MCP server.** Use `list_components`
   to see the approved versions. Use `get_component_env` (prefix every shell
   command with its exports) or `resolve_toolsrc` (a project's pinned versions).
   Don't use the user's `use_*` shell functions, Homebrew tools, or anything
   else on PATH as a substitute.
2. **Never install, upgrade or remove tools, runtimes or global packages.**
   This includes brew, sudo, rustup, nvm, sdkman, asdf, pyenv, `npm -g`, `pip`
   outside a project venv, `cargo install`, `go install …@…`, `npx -y`, and
   `curl … | sh`. If a version is missing, call `request_component` and tell the user.
3. **Run builds and tests with toolshelf `run`** (macOS sandbox: project-only
   writes, proxy-only network, no secrets). Pass the project folder as `cwd`.
   Untrusted code goes in Docker mode once it exists. Until then, ask first.
   Keep output small:
   - use quiet flags (`mvn -q`, `gradle -q`, `npm --silent`, `cargo -q`) unless
     you're debugging;
   - do multi-step work in one `run` rather than repeating `get_component_env`
     exports on every command;
   - read the run's log file only when the last 8 KB isn't enough.
4. **Don't change build-tool or toolchain versions.** That covers Gradle/Maven
   wrapper versions, Docker image tags or digests, Gradle JDK auto-download,
   and `GOTOOLCHAIN`.
5. **Ask before adding or upgrading project dependencies** (npm, Maven, Gradle,
   cargo, go, pip into a venv). Say what and why.
6. **Never read or print secrets:** `~/.ssh`, `~/.config/secrets`, tokens, `.env` files.
