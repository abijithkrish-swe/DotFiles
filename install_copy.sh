#!/bin/sh
# -----------------------------------------------------------------------------
# install_copy.sh — manage dotfiles between repo and $HOME
#
# Verbs:
#   deploy [--force]         repo → $HOME, fresh install (mirror ~/.zsh.d).
#                            First reviews any local drift so you can fold edits
#                            back to repo before they're overwritten.
#   sync   [--force]         Bidirectional reconcile (per-file direction choice).
#                            No side is authoritative; pick repo→home or home→repo
#                            for each change.
#   backup list              List backup timestamps under Backup/.
#   backup show [ts]         Summarize what's in a backup.
#   backup create            Manual full snapshot of $HOME paths the repo manages
#                            (excluding ~/.config/secrets).
#   backup restore [ts]      Restore $HOME from a backup.
#   identity                 Set this machine's git identity (prompts).
#   agents                   Merge agent guardrails into Claude Code config
#                            (~/.claude and ~/.config/claude-personal).
#   help                     Show usage.
#
# ~/.config/secrets/ is always excluded from deploy, sync, and backup.
# Git identity is machine-local (~/.config/git/identity + identity.d/), never in
# the repo: deploy offers to create it, and a [user] section folded back into
# the repo's git config is stripped automatically.
# -----------------------------------------------------------------------------

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_ROOT="$REPO_DIR/Backup"
TS="$(date +%Y%m%d-%H%M%S)"
TAB="$(printf '\t')"
SECRETS_REL=".config/secrets"
GIT_CFG_DIR="$HOME/.config/git"
IDENTITY_FILE="$GIT_CFG_DIR/identity"
IDENTITY_DIR="$GIT_CFG_DIR/identity.d"
REPO_GIT_CONFIG="$REPO_DIR/DotFiles/config/git/config"

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "❌ $*" >&2; exit 1; }

# ask <prompt> — read one line into REPLY from the terminal (stdin if no tty).
ask() {
  if { : < /dev/tty; } 2>/dev/null; then
    printf '%s' "$1" > /dev/tty
    IFS= read -r REPLY < /dev/tty || REPLY=""
  else
    printf '%s' "$1" >&2
    IFS= read -r REPLY || REPLY=""
  fi
}

usage() {
  cat <<'EOF'
Usage: install_copy.sh <verb> [options]

Verbs:
  deploy [--force]         Fresh install repo → $HOME.
                           Step 1: review local drift (home edits vs repo).
                                   Per file: fold to repo or discard.
                           Step 2: full backup of touched home paths.
                           Step 3: apply.
                              ~/.zshrc, ~/.vimrc → copy
                              ~/.zsh.d/         → mirror (--delete)
                              ~/.config/<x>/    → merge (untracked files kept)
                              ~/.config/secrets/→ skipped
                           --force skips step 1 (drift discarded).

  sync   [--force]         Bidirectional reconcile, no fresh install.
                           Per change, pick a direction:
                              [>] repo → home    [<] home → repo
                              [x] delete (only when one side is missing)
                              [s] skip           [q] quit
                           --force is not very meaningful here; it auto-skips
                           every change instead of prompting.

  backup list              List backup timestamps.
  backup show [ts]         Summarize what's in a backup (latest if no ts).
  backup create            Full snapshot of $HOME paths the repo manages
                           (excluding ~/.config/secrets) → Backup/<ts>/manual/.
  backup restore [ts]      Restore $HOME from Backup/<ts>/home (or manual/).

  identity                 Set this machine's git identity (prompts):
                              default name/email, plus optional per-folder
                              identities (e.g. ~/Projects/Personal → personal).
                           Stored in ~/.config/git/identity (+ identity.d/),
                           never in the repo. deploy offers it when missing.

  agents                   Agent guardrails for Claude Code, in every config dir
                           found (~/.claude, ~/.config/claude-personal):
                              settings.json: + toolshelf permissions (read tools
                                allowed, run asks), install denies, and a
                                PreToolUse hook (~/.config/agents/guard.sh)
                                that enforces blocklist.txt
                              CLAUDE.md: + @~/.config/agents/AGENTS.md
                           Merge only (your settings kept), backed up, re-runnable.
                           deploy offers it.

  help                     Show this message.

Examples:
  install_copy.sh deploy
  install_copy.sh deploy --force
  install_copy.sh sync
  install_copy.sh backup list
  install_copy.sh backup show
  install_copy.sh backup create
  install_copy.sh identity
  install_copy.sh agents
EOF
}

# -----------------------------------------------------------------------------
# Generic helpers
# -----------------------------------------------------------------------------

copy_path() {
  src="$1"; dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -d "$src" ]; then
    mkdir -p "$dest"
    if command -v rsync >/dev/null 2>&1; then rsync -a "$src"/ "$dest"/
    else cp -R "$src"/. "$dest"/
    fi
  else
    cp -f "$src" "$dest"
  fi
}

mirror_dir() {
  src="$1"; dest="$2"
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$src"/ "$dest"/
  else
    rm -rf "$dest"
    cp -R "$src" "$dest"
  fi
}

backup_path_into() {
  src="$1"; bkp="$2"
  [ -e "$src" ] || return 0
  mkdir -p "$(dirname "$bkp")"
  if [ -d "$src" ]; then
    if command -v rsync >/dev/null 2>&1; then rsync -a "$src"/ "$bkp"/
    else cp -R "$src" "$bkp"
    fi
  else
    cp -f "$src" "$bkp"
  fi
}

# Write a SKIPPED.md note at the backup root explaining what merge-mode dirs
# left untouched (Docker contexts, Colima VM images, etc. — runtime state that
# apps regenerate, deliberately not backed up because deploy never touches it).
write_skip_summary() {
  bkroot_kind="$1"   # "home" or "manual" — used only for the heading
  ts_root="$BACKUP_ROOT/$TS"
  outfile="$ts_root/SKIPPED.md"
  body="$(mktemp "${TMPDIR:-/tmp}/skip.XXXXXX")"

  deploy_pairs | while IFS="$TAB" read -r src dest mode; do
    [ "$mode" = "merge" ] || continue
    [ -d "$dest" ] || continue
    rel="${dest#"$HOME"/}"
    home_files="$(find "$dest" -type f 2>/dev/null | wc -l | tr -d ' ')"
    home_size="$(du -sh "$dest" 2>/dev/null | cut -f1)"
    repo_files="$(find "$src" -type f 2>/dev/null | wc -l | tr -d ' ')"
    printf -- '- ~/%s/  — home: %s files (%s)  • repo-tracked: %s files\n' \
      "$rel" "$home_files" "$home_size" "$repo_files" >> "$body"
  done

  if [ -s "$body" ]; then
    {
      printf '# Skip notes — backup %s (%s)\n\n' "$TS" "$bkroot_kind"
      printf 'These paths use **merge-mode** deploy. Only files present in the repo\n'
      printf 'source were backed up. Anything else in the home directory (runtime state,\n'
      printf 'VM images, caches, plugin binaries, secrets) was deliberately skipped to\n'
      printf 'keep backups small and fast — deploy never touches those files anyway.\n\n'
      cat "$body"
      printf '\nRestore from this backup will only restore the repo-tracked files;\n'
      printf 'the apps that own these dirs will regenerate any missing runtime state.\n'
    } > "$outfile"
    say "📝 skip summary: $outfile"
  fi
  rm -f "$body"
}

# Back up a deploy-pair's home side, scoped to what deploy would actually touch.
#   file/mirror → back up the whole home path
#   merge       → back up only files that ALSO exist in the repo source
#                 (untracked files like Docker buildx cache, plugin binaries,
#                 token seeds are preserved by deploy and don't need backup)
backup_pair_into() {
  bkroot="$1"; src_repo="$2"; dest_home="$3"; mode="$4"
  [ -e "$dest_home" ] || return 0
  rel="${dest_home#"$HOME"/}"
  case "$mode" in
    file|mirror)
      backup_path_into "$dest_home" "$bkroot/$rel"
      say "  📦 $dest_home"
      ;;
    merge)
      [ -d "$src_repo" ] || return 0
      ( cd "$src_repo" && find . -type f ) | sed 's|^\./||' | while IFS= read -r r; do
        h="$dest_home/$r"
        [ -e "$h" ] || continue
        backup_path_into "$h" "$bkroot/$rel/$r"
      done
      [ -d "$bkroot/$rel" ] && say "  📦 $dest_home (tracked files only)"
      ;;
  esac
}

diff_two_files() {
  left="$1"; right="$2"
  if command -v icdiff >/dev/null 2>&1; then
    icdiff -L "$left (current)" -L "$right (incoming)" "$left" "$right" || true
  else
    width="$(tput cols 2>/dev/null || echo 160)"
    say "─── LEFT: $left  │  RIGHT: $right ───"
    diff -y -W "$width" "$left" "$right" || true
  fi
}

# -----------------------------------------------------------------------------
# Deploy plan: list of (repo_src, home_dest, mode)
# mode ∈ { file, mirror, merge }
# -----------------------------------------------------------------------------

deploy_pairs() {
  printf "%s${TAB}%s${TAB}file\n"   "$REPO_DIR/DotFiles/zshrc" "$HOME/.zshrc"
  printf "%s${TAB}%s${TAB}file\n"   "$REPO_DIR/DotFiles/vimrc" "$HOME/.vimrc"
  printf "%s${TAB}%s${TAB}mirror\n" "$REPO_DIR/DotFiles/zsh.d" "$HOME/.zsh.d"
  if [ -d "$REPO_DIR/DotFiles/config" ]; then
    find "$REPO_DIR/DotFiles/config" -mindepth 1 -maxdepth 1 -print | while read -r item; do
      name="$(basename "$item")"
      [ "$name" = "secrets" ] && continue
      printf "%s${TAB}%s${TAB}merge\n" "$item" "$HOME/.config/$name"
    done
  fi
}

# -----------------------------------------------------------------------------
# Change classification
# -----------------------------------------------------------------------------

# classify_into <out_file> <home_path> <repo_path> <pair_mode>
# Emits per-file records: <home_path>\t<repo_path>\t<status>\t<pair_mode>
# status ∈ { DIFFERS, ONLY_HOME, ONLY_REPO }
classify_into() {
  out="$1"; hp="$2"; rp="$3"; mode="$4"

  if [ -d "$rp" ] || [ -d "$hp" ]; then
    classify_dir_into "$out" "$hp" "$rp" "$mode"
    return
  fi

  if [ -e "$rp" ] && [ ! -e "$hp" ]; then
    printf '%s%s%s%s%s%s%s\n' "$hp" "$TAB" "$rp" "$TAB" "ONLY_REPO" "$TAB" "$mode" >> "$out"
  elif [ ! -e "$rp" ] && [ -e "$hp" ]; then
    printf '%s%s%s%s%s%s%s\n' "$hp" "$TAB" "$rp" "$TAB" "ONLY_HOME" "$TAB" "$mode" >> "$out"
  elif [ -e "$rp" ] && ! cmp -s "$rp" "$hp"; then
    printf '%s%s%s%s%s%s%s\n' "$hp" "$TAB" "$rp" "$TAB" "DIFFERS" "$TAB" "$mode" >> "$out"
  fi
}

# Walk a dir-pair using a recursive enumeration so we can see per-file changes,
# including files only in one side (which `diff -qr` would emit as "Only in …"
# at directory granularity without recursing into added subdirs).
classify_dir_into() {
  out="$1"; hd="$2"; rd="$3"; mode="$4"

  # Build a unique sorted list of relative file paths under either side.
  # For merge pairs (e.g. ~/.config/docker), home-only files are preserved by
  # deploy, so we don't need to enumerate the home side (which can be huge:
  # buildx cache, contexts, plugin binaries, etc.). Only mirror pairs need
  # the home walk so ONLY_HOME files (which mirror would --delete) are caught.
  rels="$(mktemp "${TMPDIR:-/tmp}/cls-rels.XXXXXX")"
  if [ -d "$rd" ]; then
    ( cd "$rd" && find . -type f ) | sed 's|^\./||' >> "$rels" || true
  fi
  if [ "$mode" = "mirror" ] && [ -d "$hd" ]; then
    ( cd "$hd" && find . -type f ) | sed 's|^\./||' >> "$rels" || true
  fi

  sort -u "$rels" | while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    h="$hd/$rel"; r="$rd/$rel"
    if [ -e "$r" ] && [ ! -e "$h" ]; then
      printf '%s%s%s%s%s%s%s\n' "$h" "$TAB" "$r" "$TAB" "ONLY_REPO" "$TAB" "$mode" >> "$out"
    elif [ ! -e "$r" ] && [ -e "$h" ]; then
      printf '%s%s%s%s%s%s%s\n' "$h" "$TAB" "$r" "$TAB" "ONLY_HOME" "$TAB" "$mode" >> "$out"
    elif [ -e "$r" ] && ! cmp -s "$r" "$h"; then
      printf '%s%s%s%s%s%s%s\n' "$h" "$TAB" "$r" "$TAB" "DIFFERS" "$TAB" "$mode" >> "$out"
    fi
  done
  rm -f "$rels"
}

detect_changes() {
  out="$1"
  : > "$out"
  deploy_pairs | while IFS="$TAB" read -r src dest mode; do
    classify_into "$out" "$dest" "$src" "$mode"
  done
}

show_change_diff() {
  hp="$1"; rp="$2"; status="$3"
  case "$status" in
    DIFFERS)   diff_two_files "$hp" "$rp" ;;
    ONLY_REPO) say "(only in repo — does not exist in home yet)" ;;
    ONLY_HOME) say "(only in home — not present in repo)" ;;
  esac
}

# -----------------------------------------------------------------------------
# Deploy
# -----------------------------------------------------------------------------

cmd_deploy() {
  force=0
  for a in "$@"; do
    case "$a" in
      --force) force=1 ;;
      *) die "Unknown option for deploy: $a" ;;
    esac
  done
  [ -d "$REPO_DIR/DotFiles" ] || die "Missing DotFiles/ in repo root"

  changes="$(mktemp "${TMPDIR:-/tmp}/deploy-changes.XXXXXX")"
  drift_sel="$(mktemp "${TMPDIR:-/tmp}/deploy-drift.XXXXXX")"
  trap 'rm -f "$changes" "$drift_sel"' EXIT

  detect_changes "$changes"

  # Drift = changes deploy would clobber/lose:
  #   DIFFERS (any pair): home edit will be overwritten
  #   ONLY_HOME on mirror pair (.zsh.d): file will be deleted by --delete
  # ONLY_HOME on merge pair (.config/<x>) is preserved by deploy → not drift.
  drift="$(mktemp "${TMPDIR:-/tmp}/deploy-drift-pending.XXXXXX")"
  while IFS="$TAB" read -r hp rp status mode; do
    case "$status" in
      DIFFERS)
        printf '%s%s%s%s%s%s%s\n' "$hp" "$TAB" "$rp" "$TAB" "$status" "$TAB" "$mode" >> "$drift"
        ;;
      ONLY_HOME)
        [ "$mode" = "mirror" ] && \
          printf '%s%s%s%s%s%s%s\n' "$hp" "$TAB" "$rp" "$TAB" "$status" "$TAB" "$mode" >> "$drift"
        ;;
    esac
  done < "$changes"

  say "📋 Deploy plan: repo → \$HOME (~/.config/secrets is skipped)"
  if [ -s "$drift" ]; then
    n_drift="$(wc -l < "$drift" | tr -d ' ')"
    say "⚠️  $n_drift local change(s) detected in \$HOME that deploy would overwrite/delete."
  else
    say "✅ no local drift detected."
  fi
  say ""

  # Drift review (skip if --force).
  if [ -s "$drift" ] && [ "$force" -eq 0 ]; then
    say "🔎 Drift review — fold local edits back to repo before deploy clobbers them."
    say "   Keys: [y] fold to repo  [n] discard (deploy will overwrite)  [a] fold-all  [q] quit deploy"
    apply_all=0
    quit=0
    while IFS="$TAB" read -r hp rp status mode; do
      say ""
      say "----- $hp [$status] -----"
      show_change_diff "$hp" "$rp" "$status"

      if [ "$apply_all" -eq 1 ]; then
        printf '%s%s%s%s%s%s%s\n' "$hp" "$TAB" "$rp" "$TAB" "$status" "$TAB" "$mode" >> "$drift_sel"
        say "✅ folded (all)"
        continue
      fi

      printf "Fold to repo? [y/n/a/q]: " > /dev/tty
      IFS= read -r ans < /dev/tty
      case "$ans" in
        y|Y) printf '%s%s%s%s%s%s%s\n' "$hp" "$TAB" "$rp" "$TAB" "$status" "$TAB" "$mode" >> "$drift_sel"
             say "✅ folded" ;;
        a|A) printf '%s%s%s%s%s%s%s\n' "$hp" "$TAB" "$rp" "$TAB" "$status" "$TAB" "$mode" >> "$drift_sel"
             apply_all=1
             say "✅ folded (apply-all)" ;;
        q|Q) quit=1; break ;;
        *)   say "⏭️  discarded" ;;
      esac
    done < "$drift"
    rm -f "$drift"

    if [ "$quit" -eq 1 ]; then
      say "⏹️  deploy aborted. Nothing was written."
      exit 0
    fi

    if [ -s "$drift_sel" ]; then
      bkroot_repo="$BACKUP_ROOT/$TS/repo"
      say ""
      say "⬅️  Folding selected drift to repo (with backup of repo target):"
      while IFS="$TAB" read -r hp rp status mode; do
        repo_rel="${rp#"$REPO_DIR"/}"
        backup_path_into "$rp" "$bkroot_repo/$repo_rel"
        copy_path "$hp" "$rp"
        say "  ⬅️  $hp → $rp"
      done < "$drift_sel"
      strip_repo_identity
    fi
  else
    rm -f "$drift"
  fi

  # Confirm before destructive deploy step (unless --force).
  say ""
  if [ "$force" -eq 0 ]; then
    printf "Proceed with full deploy? [y/N]: " > /dev/tty
    IFS= read -r ans < /dev/tty
    case "$ans" in y|Y) ;; *) say "⏹️  deploy cancelled."; exit 0 ;; esac
  fi

  # Full backup of home paths the repo manages (skip secrets).
  say ""
  say "📦 Full backup of home paths (excluding ~/.config/secrets)…"
  bkroot_home="$BACKUP_ROOT/$TS/home"
  deploy_pairs | while IFS="$TAB" read -r src dest mode; do
    backup_pair_into "$bkroot_home" "$src" "$dest" "$mode"
  done
  write_skip_summary "home"

  # Apply.
  say ""
  say "➡️  Applying deploy…"
  deploy_pairs | while IFS="$TAB" read -r src dest mode; do
    case "$mode" in
      mirror) mirror_dir "$src" "$dest" ;;
      *)      copy_path  "$src" "$dest" ;;
    esac
    say "  ➡️  $dest  ($mode)"
  done
  mkdir -p "$HOME/.zshcache/sessions" "$HOME/.zshcache/zoxide" "$HOME/.zshcache/vim"

  # First deploy on a machine: no git identity yet.
  if [ ! -f "$IDENTITY_FILE" ]; then
    say ""
    if [ "$force" -eq 1 ]; then
      say "🪪 No git identity on this machine yet. Run: install_copy.sh identity"
    else
      ask "🪪 No git identity on this machine yet. Set it up now? [Y/n]: "
      case "$REPLY" in
        n|N) say "ℹ️  Later: install_copy.sh identity" ;;
        *)   cmd_identity ;;
      esac
    fi
  fi

  # Agent guardrails for Claude Code (merge into existing settings, backed up)
  if [ -n "$(claude_config_dirs)" ]; then
    say ""
    if [ "$force" -eq 1 ]; then
      cmd_agents || true
    else
      ask "🛡️  Apply agent guardrails to Claude Code config (merge, backed up)? [Y/n]: "
      case "$REPLY" in
        n|N) say "ℹ️  Later: install_copy.sh agents" ;;
        *)   cmd_agents || true ;;
      esac
    fi
  fi

  say ""
  say "✅ deploy complete. Backup root: $BACKUP_ROOT/$TS"
  say "   Open a new shell or run: exec zsh"
}

# -----------------------------------------------------------------------------
# Sync (bidirectional)
# -----------------------------------------------------------------------------

cmd_sync() {
  force=0
  for a in "$@"; do
    case "$a" in
      --force) force=1 ;;
      *) die "Unknown option for sync: $a" ;;
    esac
  done

  changes="$(mktemp "${TMPDIR:-/tmp}/sync-changes.XXXXXX")"
  actions="$(mktemp "${TMPDIR:-/tmp}/sync-actions.XXXXXX")"
  trap 'rm -f "$changes" "$actions"' EXIT

  detect_changes "$changes"

  if [ ! -s "$changes" ]; then
    say "✅ repo and \$HOME are already in sync (excluding ~/.config/secrets)."
    exit 0
  fi

  n="$(wc -l < "$changes" | tr -d ' ')"
  say "📋 Sync review: $n change(s) between repo and \$HOME"
  say "   Keys per item:"
  say "     [>] repo → home    [<] home → repo    [x] delete (when only-side)"
  say "     [s] skip           [q] quit"
  say ""

  if [ "$force" -eq 1 ]; then
    say "ℹ️  --force: every change skipped. Nothing to do."
    exit 0
  fi

  quit=0
  while IFS="$TAB" read -r hp rp status mode; do
    say ""
    say "----- $hp [$status] -----"
    show_change_diff "$hp" "$rp" "$status"

    case "$status" in
      DIFFERS)
        printf "Action? [>/</s/q]: " > /dev/tty
        ;;
      ONLY_HOME)
        printf "Action? [< add to repo / x delete from home / s skip / q quit]: " > /dev/tty
        ;;
      ONLY_REPO)
        printf "Action? [> add to home / s skip / q quit]: " > /dev/tty
        ;;
    esac
    IFS= read -r ans < /dev/tty

    case "$ans" in
      ">") [ "$status" != "ONLY_HOME" ] || { say "⚠️  > not valid here, skipping"; continue; }
           printf '%s%s%s%s%s\n' "$rp" "$TAB" "$hp" "$TAB" "R2H" >> "$actions"
           say "✅ queued: repo → home" ;;
      "<") [ "$status" != "ONLY_REPO" ] || { say "⚠️  < not valid here, skipping"; continue; }
           printf '%s%s%s%s%s\n' "$hp" "$TAB" "$rp" "$TAB" "H2R" >> "$actions"
           say "✅ queued: home → repo" ;;
      "x"|"X")
           if [ "$status" = "ONLY_HOME" ]; then
             printf '%s%s%s%s%s\n' "$hp" "$TAB" "" "$TAB" "DELHOME" >> "$actions"
             say "✅ queued: delete $hp"
           else
             say "⚠️  x not valid here, skipping"
           fi ;;
      "q"|"Q") quit=1; break ;;
      *) say "⏭️  skipped" ;;
    esac
  done < "$changes"

  if [ "$quit" -eq 1 ]; then
    if [ -s "$actions" ]; then
      printf "Apply queued actions before quitting? [y/N]: " > /dev/tty
      IFS= read -r ans < /dev/tty
      case "$ans" in y|Y) ;; *) say "⏹️  aborted, nothing applied."; exit 0 ;; esac
    else
      say "⏹️  aborted, nothing queued."
      exit 0
    fi
  fi

  if [ ! -s "$actions" ]; then
    say ""
    say "ℹ️  no actions queued. Done."
    exit 0
  fi

  bkroot_home="$BACKUP_ROOT/$TS/home"
  bkroot_repo="$BACKUP_ROOT/$TS/repo"

  say ""
  say "🔁 Backups + applying queued actions…"
  while IFS="$TAB" read -r src dest action; do
    case "$action" in
      R2H)
        rel="${dest#"$HOME"/}"
        backup_path_into "$dest" "$bkroot_home/$rel"
        copy_path "$src" "$dest"
        say "  ➡️  $src → $dest"
        ;;
      H2R)
        repo_rel="${dest#"$REPO_DIR"/}"
        backup_path_into "$dest" "$bkroot_repo/$repo_rel"
        copy_path "$src" "$dest"
        say "  ⬅️  $src → $dest"
        ;;
      DELHOME)
        rel="${src#"$HOME"/}"
        backup_path_into "$src" "$bkroot_home/$rel"
        rm -rf "$src"
        say "  ❌ deleted $src"
        ;;
    esac
  done < "$actions"
  strip_repo_identity

  say ""
  say "✅ sync complete. Backup root: $BACKUP_ROOT/$TS"
}

# -----------------------------------------------------------------------------
# Git identity (machine-local, never in the repo)
# -----------------------------------------------------------------------------

# The repo's git config must not carry a [user] section. Called after anything
# copies home → repo (deploy fold, sync <), so an identity set with
# `git config --global` can't leak back into the repo.
strip_repo_identity() {
  [ -f "$REPO_GIT_CONFIG" ] || return 0
  git config -f "$REPO_GIT_CONFIG" --get-regexp '^user\.' >/dev/null 2>&1 || return 0
  awk '/^[[:space:]]*\[/ { skip = ($0 ~ /^[[:space:]]*\[user\][[:space:]]*$/) } !skip' \
    "$REPO_GIT_CONFIG" > "$REPO_GIT_CONFIG.tmp" && mv "$REPO_GIT_CONFIG.tmp" "$REPO_GIT_CONFIG"
  say "🪪 stripped [user] from DotFiles/config/git/config (identity stays machine-local:"
  say "   install_copy.sh identity)"
}

identity_show() {
  if [ ! -f "$IDENTITY_FILE" ]; then
    say "   (none yet)"
    return 0
  fi
  say "   default: $(git config -f "$IDENTITY_FILE" user.name) <$(git config -f "$IDENTITY_FILE" user.email)>"
  git config -f "$IDENTITY_FILE" --get-regexp '^includeif\..*\.path$' 2>/dev/null |
  while read -r key path; do
    dir="${key#includeif.gitdir/i:}"; dir="${dir%.path}"
    case "$path" in "~/"*) path="$HOME/${path#"~/"}" ;; esac
    say "   $dir → $(git config -f "$path" user.name) <$(git config -f "$path" user.email)>"
  done
}

# ask_value <prompt> <default> — non-empty answer into REPLY.
ask_value() {
  while :; do
    if [ -n "$2" ]; then ask "$1 [$2]: "; else ask "$1: "; fi
    [ -n "$REPLY" ] || REPLY="$2"
    [ -n "$REPLY" ] && return 0
    say "   a value is required"
  done
}

# ask_email <prompt> <default> — answer containing @ into REPLY.
ask_email() {
  while :; do
    ask_value "$1" "$2"
    case "$REPLY" in *?@?*) return 0 ;; esac
    say "   that doesn't look like an email"
  done
}

cmd_identity() {
  [ $# -eq 0 ] || die "identity takes no options"
  command -v git >/dev/null 2>&1 || die "git not found"

  say "🪪 Git identity for this machine"
  say "   Stored in $IDENTITY_FILE (+ identity.d/), never in the repo."
  identity_show
  if [ -f "$IDENTITY_FILE" ]; then
    ask "Replace it? [y/N]: "
    case "$REPLY" in y|Y) ;; *) say "⏹️  identity unchanged."; return 0 ;; esac
  fi

  cur_name="$(git config -f "$IDENTITY_FILE" user.name 2>/dev/null || true)"
  cur_email="$(git config -f "$IDENTITY_FILE" user.email 2>/dev/null || true)"
  ask_value "Default name" "$cur_name";   name="$REPLY"
  ask_email "Default email" "$cur_email"; email="$REPLY"

  stage="$(mktemp -d "${TMPDIR:-/tmp}/git-identity.XXXXXX")"
  mkdir -p "$stage/identity.d"
  {
    printf '# Machine-local git identity — written by install_copy.sh identity.\n'
    printf '# Not part of the dotfiles repo; included from ~/.config/git/config.\n'
  } > "$stage/identity"
  git config -f "$stage/identity" user.name "$name"
  git config -f "$stage/identity" user.email "$email"

  while :; do
    ask "Add a folder-specific identity (e.g. personal projects)? [y/N]: "
    case "$REPLY" in y|Y) ;; *) break ;; esac
    ask_value "  Folder (repos under it use this identity)" ""; dir="$REPLY"
    case "$dir" in
      /*|"~/"*) ;;
      *) say "   use an absolute path or ~/..."; continue ;;
    esac
    dir="${dir%/}/"
    ask_value "  Name" "$name";  d_name="$REPLY"
    ask_email "  Email" "";       d_email="$REPLY"

    label="$(basename "${dir%/}" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-')"
    n=1; base="$label"
    while [ -e "$stage/identity.d/$label" ]; do n=$((n + 1)); label="$base-$n"; done

    git config -f "$stage/identity.d/$label" user.name "$d_name"
    git config -f "$stage/identity.d/$label" user.email "$d_email"
    git config -f "$stage/identity" "includeIf.gitdir/i:$dir.path" "~/.config/git/identity.d/$label"
    say "   ✅ $dir → $d_name <$d_email>"
  done

  # Back up and replace.
  bkroot_home="$BACKUP_ROOT/$TS/home"
  backup_path_into "$IDENTITY_FILE" "$bkroot_home/.config/git/identity"
  backup_path_into "$IDENTITY_DIR"  "$bkroot_home/.config/git/identity.d"
  mkdir -p "$GIT_CFG_DIR"
  rm -rf "$IDENTITY_DIR"
  mv "$stage/identity.d" "$IDENTITY_DIR"
  mv "$stage/identity" "$IDENTITY_FILE"
  rmdir "$stage"

  say ""
  say "✅ identity saved:"
  identity_show
  if ! git config --global --get-all include.path 2>/dev/null | grep -qx '~/.config/git/identity'; then
    say "ℹ️  ~/.config/git/config doesn't include it yet — run: install_copy.sh deploy"
  fi
}

# -----------------------------------------------------------------------------
# Agent guardrails (Claude Code)
# -----------------------------------------------------------------------------

AGENTS_SRC="$REPO_DIR/DotFiles/config/agents"
AGENTS_HOME="$HOME/.config/agents"

# Claude Code config dirs on this machine: the default and the personal one
# (myclaude → CLAUDE_CONFIG_DIR=~/.config/claude-personal). Only existing dirs.
claude_config_dirs() {
  for d in "$HOME/.claude" "$HOME/.config/claude-personal"; do
    [ -d "$d" ] && printf '%s\n' "$d"
  done
}

# Merge DotFiles/config/agents/claude-settings.json into <dir>/settings.json:
# permission lists are unioned, our PreToolUse hook replaces an older copy of
# itself; everything else in the file is kept as is (order preserved).
merge_claude_settings() {
  target="$1"; frag="$2"
  /usr/bin/python3 - "$target" "$frag" <<'PY'
import json, os, sys
target, frag = sys.argv[1], sys.argv[2]
cur = json.load(open(target)) if os.path.exists(target) and os.path.getsize(target) else {}
before = json.dumps(cur, sort_keys=True)
f = json.load(open(frag))
changes = []
perm = cur.setdefault("permissions", {})
for k, items in f.get("permissions", {}).items():
    lst = perm.setdefault(k, [])
    for item in items:
        if item not in lst:
            lst.append(item)
            changes.append(f"permissions.{k} + {item}")
hooks = cur.setdefault("hooks", {})
for event, entries in f.get("hooks", {}).items():
    lst = hooks.setdefault(event, [])
    for e in entries:
        ours = {h["command"] for h in e.get("hooks", [])}
        kept = [x for x in lst if not ({h.get("command") for h in x.get("hooks", [])} & ours)]
        if len(kept) == len(lst):
            changes.append(f"hooks.{event} + {e.get('matcher', '*')}: {', '.join(sorted(ours))}")
        lst[:] = kept + [e]
if json.dumps(cur, sort_keys=True) != before:
    with open(target, "w") as fh:
        json.dump(cur, fh, indent=2)
        fh.write("\n")
for c in changes:
    print(f"      {c}")
if not changes:
    print("      (already up to date)")
PY
}

cmd_agents() {
  [ $# -eq 0 ] || die "agents takes no options"
  [ -x /usr/bin/python3 ] || die "agents needs /usr/bin/python3 (Xcode Command Line Tools)"
  [ -f "$AGENTS_SRC/claude-settings.json" ] || die "missing $AGENTS_SRC/claude-settings.json"
  if [ ! -x "$AGENTS_HOME/guard.sh" ] || [ ! -f "$AGENTS_HOME/blocklist.txt" ]; then
    say "⚠️  $AGENTS_HOME/guard.sh or blocklist.txt not deployed yet; run: install_copy.sh deploy"
    say "   (the hook fails closed and would block every Bash command until then)"
    return 1
  fi

  dirs="$(claude_config_dirs)"
  [ -n "$dirs" ] || { say "ℹ️  no Claude Code config dirs found (~/.claude, ~/.config/claude-personal)"; return 0; }

  say "🛡️  Agent guardrails → Claude Code"
  bkroot_home="$BACKUP_ROOT/$TS/home"
  printf '%s\n' "$dirs" | while IFS= read -r d; do
    rel="${d#"$HOME"/}"
    say "   $d"
    backup_path_into "$d/settings.json" "$bkroot_home/$rel/settings.json"
    backup_path_into "$d/CLAUDE.md" "$bkroot_home/$rel/CLAUDE.md"

    say "    settings.json:"
    merge_claude_settings "$d/settings.json" "$AGENTS_SRC/claude-settings.json"

    import_line='@~/.config/agents/AGENTS.md'
    if [ -f "$d/CLAUDE.md" ] && grep -qxF "$import_line" "$d/CLAUDE.md"; then
      say "    CLAUDE.md: imports AGENTS.md (already)"
    else
      {
        [ -s "$d/CLAUDE.md" ] && printf '\n'
        printf '# Agent rules (dotfiles: DotFiles/config/agents/AGENTS.md)\n%s\n' "$import_line"
      } >> "$d/CLAUDE.md"
      say "    CLAUDE.md: + $import_line"
    fi
  done
  say "✅ done. Backups (if anything existed): $bkroot_home"
  say "   Restart Claude Code sessions to pick up hooks/permissions."
}

# -----------------------------------------------------------------------------
# Backup
# -----------------------------------------------------------------------------

backup_list() {
  ls -1 "$BACKUP_ROOT" 2>/dev/null || say "(no backups)"
}

backup_show() {
  ts="${1:-}"
  if [ -z "$ts" ]; then
    ts="$(ls -1 "$BACKUP_ROOT" 2>/dev/null | sort | tail -n1)"
    [ -n "$ts" ] || die "No backups found in $BACKUP_ROOT"
  fi
  root="$BACKUP_ROOT/$ts"
  [ -d "$root" ] || die "Backup not found: $ts"

  say "📦 Backup $ts  ($root)"
  for sect in home repo manual; do
    sect_dir="$root/$sect"
    [ -d "$sect_dir" ] || continue
    say "   $sect/"
    find "$sect_dir" -mindepth 1 -maxdepth 1 -print | sort | while read -r child; do
      cname="$(basename "$child")"
      if [ -d "$child" ] && [ "$cname" = ".config" ]; then
        find "$child" -mindepth 1 -maxdepth 1 -print | sort | while read -r sub; do
          sname="$(basename "$sub")"
          if [ -d "$sub" ]; then
            count="$(find "$sub" -type f | wc -l | tr -d ' ')"
            say "     .config/$sname/    ($count files)"
          else
            say "     .config/$sname"
          fi
        done
      elif [ -d "$child" ]; then
        count="$(find "$child" -type f | wc -l | tr -d ' ')"
        say "     $cname/    ($count files)"
      else
        say "     $cname"
      fi
    done
  done
}

backup_create() {
  bkroot="$BACKUP_ROOT/$TS/manual"
  deploy_pairs | while IFS="$TAB" read -r src dest mode; do
    backup_pair_into "$bkroot" "$src" "$dest" "$mode"
  done
  if [ -d "$bkroot" ]; then
    write_skip_summary "manual"
    say "✅ backup saved: $bkroot"
  else
    say "ℹ️  nothing to back up — none of the managed home paths exist yet."
  fi
}

backup_restore() {
  ts="${1:-}"
  if [ -z "$ts" ]; then
    ts="$(ls -1 "$BACKUP_ROOT" 2>/dev/null | sort | tail -n1)"
    [ -n "$ts" ] || die "No backups found in $BACKUP_ROOT"
  fi
  if   [ -d "$BACKUP_ROOT/$ts/home" ];   then src_root="$BACKUP_ROOT/$ts/home"
  elif [ -d "$BACKUP_ROOT/$ts/manual" ]; then src_root="$BACKUP_ROOT/$ts/manual"
  else die "No restorable contents under Backup/$ts (need home/ or manual/)"
  fi

  say "🧩 Restoring \$HOME from $ts ($src_root)"
  find "$src_root" -type f -print | while read -r f; do
    rel="${f#"$src_root"/}"
    dest="$HOME/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -f "$f" "$dest"
    say "  ⬅️  $dest"
  done
  say "✅ restore complete."
}

cmd_backup() {
  sub="${1:-}"
  shift 2>/dev/null || true
  case "$sub" in
    list)    backup_list ;;
    show)    backup_show "$@" ;;
    create)  backup_create ;;
    restore) backup_restore "$@" ;;
    *) die "Usage: install_copy.sh backup {list|show [ts]|create|restore [ts]}" ;;
  esac
}

# -----------------------------------------------------------------------------
# Dispatch
# -----------------------------------------------------------------------------

verb="${1:-}"
shift 2>/dev/null || true
case "$verb" in
  deploy) cmd_deploy "$@" ;;
  sync)   cmd_sync "$@" ;;
  backup) cmd_backup "$@" ;;
  identity) cmd_identity "$@" ;;
  agents)   cmd_agents "$@" ;;
  ''|help|-h|--help) usage ;;
  *) printf '%s\n' "Unknown verb: $verb" >&2; usage; exit 1 ;;
esac
