# Agent rules: developer tools

1. Get tools only from the toolshelf MCP server. Use `list_components` to see
   the approved versions. Use `get_component_env` or `resolve_toolsrc` to get
   their environment. Do not use the user's `use_*` shell functions, Homebrew
   tools or other tools on PATH.
2. Do not install, upgrade or remove tools, runtimes or global packages. This
   includes brew, sudo, rustup, nvm, sdkman, asdf, pyenv, npm -g, pip outside a
   project venv, cargo install, go install …@…, npx -y and curl | sh. If a
   version is missing, call `request_component`. Then tell the user.
3. Use toolshelf `run` for builds, tests and scripts. Set `cwd` to the project
   folder. Code is untrusted if it comes from an unknown repository, a
   download, or generation that the user did not review. For untrusted code,
   set `mode` to "docker" and use one tool. The network is off. If the run
   must download dependencies, set `network` to "proxy".
4. Do not use `run` to edit files. Use your edit tools. Put temporary files in
   `$TMPDIR`. Use quiet flags. Do not pipe output to `tail`; set `tail_kb`.
5. Do not change toolchain versions: Gradle or Maven wrappers, Docker images,
   Gradle JDK download, `GOTOOLCHAIN`.
6. Before you add or upgrade a project dependency, ask the user. Tell the user
   what you want to add and why.
7. Do not read or show secrets: `~/.ssh`, `~/.config/secrets`, tokens, `.env`
   files.
