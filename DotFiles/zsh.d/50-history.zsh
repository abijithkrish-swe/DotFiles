# 50) history settings

# --- CORE OPTIONS ---
# These apply to all sessions (normal, VS Code, IntelliJ)
setopt EXTENDED_HISTORY          # Store timestamps
setopt APPEND_HISTORY            # Append history (don't overwrite)
setopt HIST_EXPIRE_DUPS_FIRST    # Remove older duplicates when full
setopt HIST_IGNORE_DUPS          # Don't store duplicates
setopt HIST_IGNORE_ALL_DUPS      # Remove old duplicates
setopt HIST_IGNORE_SPACE         # Ignore commands starting with space
setopt HIST_REDUCE_BLANKS        # Remove blank lines
setopt HIST_VERIFY               # Show command with history expansion before running

# --- SHARING STRATEGY ---
# Default: Share history between active terminals
setopt SHARE_HISTORY             # Share history across sessions

# --- IDE ISOLATION ---
# IDEs (VS Code, IntelliJ) use their own history file (set in 10-env-path.zsh).
# We also want to disable "live sharing" to prevent noise/clutter in IDE terminals.

if [[ "$TERM_PROGRAM" == "vscode" || \
      "$TERMINAL_EMULATOR" == "JetBrains"* || \
      -n "$INTELLIJ_IDEA_CONSOLE" || \
      -n "$ECLIPSE_CONSOLE" ]]; then

  # 1. Disable sharing (don't read other tabs' history immediately)
  unsetopt SHARE_HISTORY

  # 2. Enable incremental append (save immediately, but don't read immediately)
  # This ensures history is saved even if the IDE crashes
  setopt INC_APPEND_HISTORY

  # 3. Disable verify (just run the command in IDE)
  unsetopt HIST_VERIFY
  
  # Note: The HISTFILE is already set to a unique file in 10-env-path.zsh
  # so 'normal' terminal commands will never appear here.
fi
# ---------------------------------------------------------------------
# 60) aliases
# ---------------------------------------------------------------------