# Advanced Configuration

## Secrets Vault
Protect your sensitive environment variables (API keys) on disk.
1. Create `~/.config/secrets/secrets.env` with your export statements.
2. Run `vault_lock` to encrypt it with a password.
3. Delete the plaintext file.
4. In a new session, run `vault_unlock` and enter password to load variables.

## Project Automation ("Toolup")
Toolup allows per-directory version switching.
1. Create a `.toolsrc` file in your project root:
   ```
   JDK=17
   REDIS=7.2
   ```
2. Run `toolup` to load these versions into the current shell.

## Customization
- **Local Overrides**: Create `~/.zshrc.local` for machine-specific settings.
- **Extra Aliases**: Create `~/.zsh.d/99-my-aliases.zsh`.
