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

Project requirements
--------------------
  • cwd must be a project: it (or a parent ≥ 2 levels under $HOME) contains
    .git, .toolsrc, package.json, pom.xml, build.gradle*, Cargo.toml, go.mod,
    pyproject.toml, Makefile … or an empty .toolshelf file.
  • Only approved versions (components_check). Missing one? The agent records a
    request; you review with components_requests.
  • Docker mode: Colima must be running (costart); the tool's version needs a
    docker= image in the manifest (components_images shows which).

Where things go
---------------
  logs            ~/.local/state/toolshelf/runs/<id>.log   (full output)
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
EOF2
}

_devhelp_register "toolshelf" _devhelp_toolshelf
