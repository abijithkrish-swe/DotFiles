#!/bin/sh
# -----------------------------------------------------------------------------
# install_copy.sh — bootstrap dotfiles by COPYING from repo into $HOME
#
# Features:
#   • DRY-RUN by default (preview actions)
#   • --apply to actually copy
#   • Backups saved under ./Backup/<timestamp>/home/...
#   • --restore [timestamp] to restore from backups
#   • --list-backups to list available backups
#
# Layout expected:
#   repo/
#     DotFiles/
#       zshrc
#       vimrc
#       zsh.d/
#       config/
#     install_copy.sh
# -----------------------------------------------------------------------------

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_ROOT="$REPO_DIR/Backup"
TS="$(date +%Y%m%d-%H%M%S)"
DRYRUN=1         # default: dry-run ON
APPLY=0
RESTORE=0
RESTORE_TS=""
FORCE=0

say() { printf '%s\n' "$*"; }
die() { say "❌ $*"; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [--apply] [--force] [--restore [timestamp]] [--list-backups]

  (default)        Dry run: preview actions, no changes made
  --apply          Perform the copy (turn off dry-run)
  --force          Overwrite existing files (backed up to ./Backup/<ts>)
  --restore [ts]   Restore from latest (no ts) or specific timestamp dir
  --list-backups   Show available backup timestamps

Examples:
  $0                    # preview what would happen
  $0 --apply            # copy, back up any overwritten items
  $0 --apply --force    # overwrite existing files/dirs (with backups)
  $0 --list-backups
  $0 --restore          # restore from latest backup
  $0 --restore 20250920-101530
EOF
  exit 1
}

# --- parse args ---
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)        APPLY=1; DRYRUN=0 ;;
    --force)        FORCE=1 ;;
    --restore)      RESTORE=1; RESTORE_TS="${2:-}"; shift || true ;;
    --list-backups) ls -1 "$BACKUP_ROOT" 2>/dev/null || echo "(no backups)"; exit 0 ;;
    -h|--help)      usage ;;
    *)              usage ;;
  esac
  shift
done

[ -d "$REPO_DIR/DotFiles" ] || die "Missing DotFiles/ in repo root"

# --- helpers ---
backup_dest_for() {
  # map $HOME path to repo backup path
  # e.g., ~/.zshrc -> $BACKUP_ROOT/<TS>/home/.zshrc
  rel="${1#"$HOME"/}"
  printf "%s/%s/home/%s" "$BACKUP_ROOT" "$TS" "$rel"
}

mkdirp() {
  [ "$DRYRUN" -eq 1 ] && return 0
  mkdir -p "$1"
}

do_copy_file() {
  src="$1"; dest="$2"
  if [ -e "$dest" ]; then
    if [ "$FORCE" -eq 1 ]; then
      bkp="$(backup_dest_for "$dest")"
      say "🔁 Backup file $dest  →  $bkp"
      if [ "$DRYRUN" -eq 0 ]; then
        mkdir -p "$(dirname "$bkp")"
        cp -f "$dest" "$bkp"
      fi
    else
      say "⏭️  Skip (exists) $dest"
      return 0
    fi
  fi
  say "➡️  Copy file $src  →  $dest"
  if [ "$DRYRUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
  end_if=true
  fi
}

do_copy_dir() {
  src="$1"; dest="$2"
  if [ -e "$dest" ]; then
    if [ "$FORCE" -eq 1 ]; then
      bkp="$(backup_dest_for "$dest")"
      say "🔁 Backup dir  $dest  →  $bkp"
      if [ "$DRYRUN" -eq 0 ]; then
        mkdir -p "$(dirname "$bkp")"
        if command -v rsync >/dev/null 2>&1; then
          rsync -a "$dest"/ "$bkp"/
        else
          mkdir -p "$bkp"
          cp -R "$dest"/. "$bkp"/
        fi
      fi
    else
      say "⏭️  Skip dir (exists) $dest"
      return 0
    fi
  fi
  say "➡️  Copy dir  $src  →  $dest"
  if [ "$DRYRUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dest")"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a "$src"/ "$dest"/
    else
      mkdir -p "$dest"
      cp -R "$src"/. "$dest"/
    fi
  fi
}

# --- restore support ---
restore_from() {
  ts="$1"
  src_root="$BACKUP_ROOT/$ts/home"
  [ -d "$src_root" ] || die "Backup timestamp not found: $ts"

  say "🧩 Restoring from backup: $ts"
  find "$src_root" -type d -print | while read -r d; do
    rel="${d#"$src_root"/}"
    [ -z "$rel" ] && continue
    dest="$HOME/$rel"
    say "📂 ensure dir $dest"
    [ "$DRYRUN" -eq 0 ] && mkdir -p "$dest"
  done

  find "$src_root" -type f -print | while read -r f; do
    rel="${f#"$src_root"/}"
    dest="$HOME/$rel"
    say "⬅️  restore $f → $dest"
    if [ "$DRYRUN" -eq 0 ]; then
      mkdir -p "$(dirname "$dest")"
      cp -f "$f" "$dest"
    fi
  done
  say "✅ Restore complete."
}

if [ "$RESTORE" -eq 1 ]; then
  # pick latest if no timestamp supplied
  if [ -z "$RESTORE_TS" ]; then
    RESTORE_TS="$(ls -1 "$BACKUP_ROOT" 2>/dev/null | sort | tail -n1)"
    [ -n "$RESTORE_TS" ] || die "No backups found in $BACKUP_ROOT"
  fi
  say "🧪 (dry-run=$DRYRUN) restore timestamp: $RESTORE_TS"
  restore_from "$RESTORE_TS"
  [ "$DRYRUN" -eq 1 ] && say "ℹ️ Dry run: no files modified. Use --apply to perform restore."
  exit 0
fi

# --- normal install path ---
say "📦 Installing from: $REPO_DIR"
say "🔎 Mode: $( [ "$DRYRUN" -eq 1 ] && echo DRY-RUN || echo APPLY ), force=$FORCE"
[ "$DRYRUN" -eq 0 ] && mkdir -p "$BACKUP_ROOT"

# core files
do_copy_file "$REPO_DIR/DotFiles/zshrc" "$HOME/.zshrc"
do_copy_file "$REPO_DIR/DotFiles/vimrc" "$HOME/.vimrc"

# zsh.d
do_copy_dir  "$REPO_DIR/DotFiles/zsh.d" "$HOME/.zsh.d"

# ~/.config (merge each item under DotFiles/config/)
mkdir -p "$HOME/.config"
if [ -d "$REPO_DIR/DotFiles/config" ]; then
  # iterate over top-level children (files or dirs)
  find "$REPO_DIR/DotFiles/config" -mindepth 1 -maxdepth 1 -print | while read -r item; do
    name="$(basename "$item")"
    if [ -d "$item" ]; then
      do_copy_dir "$item" "$HOME/.config/$name"
    else
      do_copy_file "$item" "$HOME/.config/$name"
    fi
  done
else
  say "ℹ️  No DotFiles/config directory; skipping ~/.config population."
fi

# ensure cache dirs exist
say "📂 Ensure cache dirs: ~/.zshcache/{sessions,zoxide,vim}"
if [ "$DRYRUN" -eq 0 ]; then
  mkdir -p "$HOME/.zshcache/sessions" "$HOME/.zshcache/zoxide" "$HOME/.zshcache/vim"
fi

say "✅ Done."
if [ "$DRYRUN" -eq 1 ]; then
  say "   (dry run: no files were modified) — use --apply to perform actions."
else
  say "   Open a new shell or run: exec zsh"
  [ -d "$BACKUP_ROOT/$TS" ] && say "   Backups saved under: $BACKUP_ROOT/$TS"
fi
