# --- toolshelf help module ---------------------------------------------------
_devhelp_toolshelf() {
cat <<'EOF2'
toolshelf — running projects through AI agents
==============================================

Agents build and test through the toolshelf MCP server's `run` tool. You ask
in plain words; the agent picks the arguments. Two modes:

               sandbox (default)                   docker (untrusted code)
  tools        your approved ~/Components installs pinned Linux images (manifest docker=)
  reads        almost everything, except secrets,  only the project (/work)
               shell history and ~/Library
  writes       project + ~/.cache/toolshelf        project only
  network      only via the zero-trust proxy       none, or network:"proxy" (enforced)
  caches       kept between runs (sandbox-only)    none: every run starts empty
  speed        fast                                slower (fresh, image pull on first use)

Use docker for: freshly cloned repos, scripts from the internet, generated code
you haven't reviewed, dependencies with install scripts (npm postinstall …).
Your own projects: sandbox.

What to ask (examples)
----------------------
  "Build and test ~/Projects/Personal/app with JDK 17 and Maven"
  "Run the tests in this repo"                      (uses its .toolsrc if present)
  "Run pytest in ~/Projects/x with Python"          (venv in the project)
  "This repo is untrusted — run its tests in docker, with network for deps"

What the agent sends
--------------------
  run  cwd: ~/Projects/Personal/app
       tools: {"jdk": "17", "maven": ""}            ("" = manifest default)
       command: mvn -q test

  run  cwd: ~/Projects/x   tools: {"python": ""}
       command: python3 -m venv .venv && .venv/bin/pip install -q -r requirements.txt && .venv/bin/pytest -q

  run  cwd: ~/Projects/untrusted   tools: {"node": "22"}
       mode: docker   network: proxy                (one tool per docker run)
       command: npm ci --silent && npm test

  Optional: timeout_seconds (default 600, max 3600), tail_kb (output returned,
  default 8). Omit `tools` to use the project's .toolsrc.

  Keeping it cheap (the rules ask agents for this):
  • quiet flags (mvn -q, gradle -q, npm --silent, cargo -q) unless debugging
  • several steps in one run, not one run per command
  • the reply is the last 8 KB; agents read the log only when that's not enough,
    and use tail_kb rather than piping through tail/head
  • edits go through the agent's edit tools, not sed -i / cat > inside run

Agent rules
-----------
  One file: ~/.config/agents/AGENTS.md (repo: DotFiles/config/agents/AGENTS.md).
  Claude Code imports it; toolshelf sends it to every other app (Claude app,
  Codex / ChatGPT …) when they connect. Edit in the repo, deploy, reconnect.
  codex                     # Codex CLI = the ChatGPT app's own copy (alias when no
                            # codex is on PATH); same ~/.codex/config.toml as the app
  Written in ASD-STE100 style, kept under 1600 bytes:
  perl tests/agents/agents-md-test.pl

Project requirements
--------------------
  • cwd must be a project: it (or a parent ≥ 2 levels under $HOME) contains
    .git, .toolsrc, package.json, pom.xml, build.gradle*, Cargo.toml, go.mod,
    pyproject.toml, Makefile … or an empty .toolshelf file.
  • Only approved versions (components_check). Missing one? The agent records a
    request; you review with components_requests.
  • Docker mode: Colima must be running (costart); the tool's version needs a
    docker= image in the manifest, shown as "(docker)" in jdk_list, node_list …
    Versions without one work in sandbox mode only. components_images shows
    which images are pulled (each downloads on its first docker run).

Doing it yourself: dockrun
--------------------------
Same idea as docker mode, from your shell: for open-source tools and repos
you don't trust. The current folder is mounted at /work; nothing else from
your Mac (home, keys, caches, Docker socket). The container is gone afterwards.

  dockrun [--net|--internet] [-p PORT[:C]] [-n] <tool>[=version] ['command']

  dockrun node=22 'npm ci && npm test'        no network (default)
  dockrun --net python 'pip install x && x'   only via the zero-trust proxy
  dockrun --internet -p 8080 node 'npx serve -l 8080'
                                              normal network; port on 127.0.0.1
  dockrun python                              no command: a shell inside
  dockrun -n jdk=17 'mvn -q test'             print the docker commands only

  • Images: the version's docker= pin (tab-complete shows which tools have one).
  • Quote compound commands; unquoted, "&& npm test" would run on your Mac.
  • The folder must be under ~ (Colima shares only your home with Docker).
  • Nothing persists between runs: dependencies download again each time.
  • Files the tool writes in /work are yours (it runs as your uid).

Where things go
---------------
  logs            ~/.local/state/toolshelf/runs/<id>.log   (full output)
  blocked         ~/.local/state/toolshelf/blocked.jsonl   (guard hook + run)
  review          toolshelf_report [days]   runs, common commands, failures,
                  sandbox walls, file edits via run, blocked attempts
  sandbox caches  ~/.cache/toolshelf/{m2,gradle,npm,cargo,go,pip}  (safe to delete)
  docker images   components_images   /   components_images prune

Troubleshooting
---------------
  "unknown directive @image" / old behaviour → that Claude session runs an old
      toolshelf: /mcp → reconnect toolshelf (or restart the session)
  "doesn't look like a project"  → add an empty .toolshelf, or use the repo root
  "is not approved"              → install + add to the manifest (devhelp components)
  "Blocked: …"                   → the command installs/upgrades tools; run it yourself if wanted
  "Docker isn't running"         → costart
  "note: the sandbox blocked a file operation" → something wrote outside the
      project, e.g. /tmp or ~. Temp files belong in $TMPDIR (private per run).
      Shown even when the command exited 0 (errors hidden by 2>/dev/null).
EOF2
}

_devhelp_register "toolshelf" _devhelp_toolshelf
