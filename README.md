# DotFiles

A modular **zsh + developer environment** setup that keeps `$HOME` clean, portable, and productive.

- 🧩 **Modular design** → config splits in `zsh.d/`.
- 🧹 **Clean home** → artifacts in `~/.zshcache`.
- ⚡ **Rule of 5** → Standardized `use`/`start`/`stop` for all tools.
- 🔐 **Vault** → Built-in encryption for local secrets.

## 📚 Documentation

- [**User Guide**](Docs/UserGuide.md): Core aliases, navigation, shell options.
- [**Components Guide**](Docs/Components.md): Managing JDK, Redis, MySQL, Python versions.
- [**Advanced**](Docs/Advanced.md): Toolup automation. | [**Secrets**](DotFiles/SECRETS.md): Vault System.
- [**Installation**](INSTALL.md): How to deploy.

## Quick Start

1. Clone repo.
2. Run `./install_copy.sh deploy` (copies files to `~/.zsh.d`, `~/.zshrc`, `~/.config`).
3. Restart zsh (`exec zsh`).

Already installed and edited things directly in `$HOME`? Use `./install_copy.sh sync`
to reconcile repo and home in either direction, one change at a time. Run
`./install_copy.sh help` for all verbs.
