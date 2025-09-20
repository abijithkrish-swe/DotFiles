# --- git help module (advanced) ----------------------------------------------
_devhelp_git_advanced() {
cat <<'EOF'
Git — Advanced
==============

Fixup / autosquash
------------------
  git commit --fixup=<SHA>
  git rebase -i --autosquash <base>   # fixups auto-placed

History surgery
---------------
  git rebase -i HEAD~N                # reorder/squash/fixup
  git cherry-pick <SHA>
  git revert <SHA>                    # create inverse commit

Recovery
--------
  git reflog                          # find lost commits/branch tips
  git reset --hard <SHA>              # reset to a point (⚠️)
  git checkout -- <file>              # discard file changes

Stash
-----
  git stash push -m "wip"
  git stash list
  git stash pop
  git stash apply stash@{n}

Bisect (find bad commit)
------------------------
  git bisect start
  git bisect bad
  git bisect good <good-sha-or-tag>
  git bisect reset

Tags & releases
---------------
  git tag -a v1.2.3 -m "release"
  git push origin v1.2.3
  tags

Cleanup / maintenance
---------------------
  git branch -vv
  git remote prune origin
  prune-branches                     # your alias

Remote tracking
---------------
  git branch -u origin/master        # set upstream for current branch
  git branch -r                      # list remote branches

Safety tips
-----------
  • Prefer 'git push --force-with-lease'
  • Rebase only your own branches (don’t rewrite shared history)
  • Use 'reflog' to recover mistakes
EOF
}

_devhelp_register "git-advanced" _devhelp_git_advanced