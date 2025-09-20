# 62) Git sync helpers — short names

# syncm — stash, checkout master, fetch, pull --rebase
syncm() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repo"; return 1; }
  git stash || return $?
  git checkout master || return $?
  git fetch || return $?
  git pull --rebase || return $?
  echo "✅ master synced with remote (stash saved)"
}

# syncc — stash, pull --rebase on current branch, stash pop
syncc() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repo"; return 1; }
  local cur_branch
  cur_branch="$(git rev-parse --abbrev-ref HEAD)"
  git stash || return $?
  git pull --rebase origin "$cur_branch" || return $?
  git stash pop || echo "ℹ️ No stash to pop"
  echo "✅ $cur_branch rebased onto origin/$cur_branch (stash reapplied)"
}

# syncs — stash, update master, rebase current branch on master, stash pop
syncs() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repo"; return 1; }
  local cur_branch
  cur_branch="$(git rev-parse --abbrev-ref HEAD)"
  git stash || return $?
  git checkout master || return $?
  git fetch || return $?
  git pull --rebase || return $?
  if [[ "$cur_branch" != "master" ]]; then
    git checkout "$cur_branch" || return $?
    git rebase master || return $?
  fi
  git stash pop || echo "ℹ️ No stash to pop"
  echo "✅ $cur_branch rebased on updated master (stash reapplied)"
}

# ---------------------------------------------------------------------
# 65) secrets helper
# ---------------------------------------------------------------------