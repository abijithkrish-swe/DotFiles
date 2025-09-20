# --- git help module (basic) -------------------------------------------------
_devhelp_git() {
cat <<'EOF'
Git — Quick Reference (Basic)
=============================

Your aliases
------------
  lg                 # pretty graph log
  tags               # list tags
  branches           # list branches (all)
  remotes            # list remotes (verbose)
  unpushed           # commits not on remotes
  undo               # reset --hard HEAD~1 (⚠️ destructive)
  prune-branches     # prune local branches tracking gone
  gsync              # stash; checkout master; fetch; pull --rebase

Everyday flow
-------------
  git status
  git add -p
  git commit -m "message"
  git push
  git switch -c feature/xyz      # new branch from current
  git switch -                   # toggle previous branch

Sync (safe defaults)
--------------------
  git fetch --all --prune
  git pull --rebase
  git rebase origin/master
  git push --force-with-lease    # safer than --force

Diff & staging
--------------
  git diff                       # unstaged
  git diff --staged              # staged
  git restore --staged <file>    # unstage
  git restore <file>             # discard working changes

Need more?  →  devhelp git-advanced
EOF
}

_devhelp_register "git" _devhelp_git