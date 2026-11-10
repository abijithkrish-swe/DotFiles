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

## Git Identity (per machine)
Your git name/email is **not** stored in this repo. The tracked
`~/.config/git/config` only includes a machine-local file:

```
~/.config/git/identity        default [user] + per-folder rules
~/.config/git/identity.d/*    one [user] per folder rule
```

- **New machine:** `install_copy.sh deploy` asks for it when it's missing
  (`--force` just prints a reminder). Run `install_copy.sh identity` any time to
  change it.
- **Per-folder identities:** answer "y" to *Add a folder-specific identity* and
  give the folder, e.g. `~/Projects/Personal` → personal name/email. Repos under
  that folder use it automatically (`includeIf "gitdir/i:..."`, case-insensitive).
  Each machine has its own rules, so folders can differ between devices.
- **Leak guard:** if a `sync`/drift fold copies a `[user]` section from home into
  the repo's git config, the installer strips it. Don't use
  `git config --global user.*`; use `install_copy.sh identity`.
- Check which identity a repo gets: `git config user.email` (inside the repo).

## Machine-specific git settings
Settings that only make sense on one machine go in `~/.config/git/local`. It's
never in the repo, and the tracked config includes it **last**, so it wins.
Example from the work Mac, where the default keychain helper misbehaves:

```
[credential]
	helper =      # empty value clears the inherited `osxkeychain`
	helper = /Library/Developer/CommandLineTools/usr/libexec/git-core/git-credential-osxkeychain
```

Check the effective value with `git config --show-origin --get-all credential.helper`.

## Build-tool caches (XDG)
`10-env-path.zsh` moves build-tool caches out of `$HOME`. They are shared
safely across tool versions:

| Tool | Variable | Location |
|------|----------|----------|
| Gradle | `GRADLE_USER_HOME` | `~/.local/share/gradle` |
| npm | `npm_config_cache`, `NPM_CONFIG_USERCONFIG` | `~/.cache/npm`, `~/.config/npm/npmrc` |
| Cargo | `CARGO_HOME` | `~/.local/share/cargo` (`bin/` on PATH) |
| Go | `GOPATH` | `~/.local/share/go` (`bin/` on PATH; build cache in `~/Library/Caches/go-build`) |
| Maven | (unchanged) | `~/.m2`: VS Code's LemMinX writes there anyway |

GUI apps don't read zsh. In IntelliJ / Android Studio, set
*Settings → Build Tools → Gradle → Gradle user home* to `~/.local/share/gradle`,
or they will recreate `~/.gradle`. AI-agent sandbox runs use separate caches under
`~/.cache/toolshelf/`.

### Gradle toolchains: approved JDKs only
Without limits, Gradle downloads a JDK whenever a build asks for a Java version
it can't find. `jdk_gradle_sync` (in `71-jdk.zsh`, run at login) keeps this
block in `$GRADLE_USER_HOME/gradle.properties`, generated from the manifest.
The rest of the file is left alone:

```
org.gradle.java.installations.auto-download=false
org.gradle.java.installations.auto-detect=false
org.gradle.java.installations.paths=<every approved JDK home>
```

A build asking for an unapproved version now fails with *"Cannot find a Java
installation … Toolchain auto-provisioning is not enabled"*. Approve that JDK in
the manifest, then run `jdk_gradle_sync` or open a new shell.
