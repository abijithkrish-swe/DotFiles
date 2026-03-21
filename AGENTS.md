# Developer Environment Context

## Shell Setup

Modular Zsh config: numbered files in `~/.zsh.d/` loaded in order. Source repo: `~/Important/zshrc/configured/`.

## Tool Versions

Tools live in `~/Components/<Tool>/<Version>/`. Activate with `use_<tool> <version>`.

Available: JDK (11/17/21/25), Maven, Gradle, Ant, Python, Node, Go, Redis, MySQL, Protobuf.

Defaults on login: JDK 11, MySQL 8.0.43, Redis 7.4.5, Node 20.19.5.

## Project Setup Convention

Pin versions in `.toolsrc` at project root, then run `toolup`:

```ini
JDK=17
MAVEN=3.9.6
NODE=20.0
```

## Key Paths

- `~/Components/` — Tool installations
- `~/.config/` — App configs (git, starship, tmux, fzf, docker)
- `~/.zshcache/` — Runtime state (history, completions, zoxide)
- `~/.zshrc.local` — Machine-specific overrides (not in repo)

## Environment Notes

- Corporate proxy active: `http://127.0.0.1:3128` (zero-trust)
- Python: PATH-only switching, no PYTHONHOME (venv safe)
- Secrets: encrypted vault at `~/.config/secrets/vault.store` — use `use_secret KEY` to export
- History: isolated per IDE (VS Code, IntelliJ get separate history files)
