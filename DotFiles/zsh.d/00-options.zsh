# 0 ) SHELL SAFETY & BASIC OPTIONS
set -o noclobber
set -o notify
setopt prompt_subst
setopt autocd
setopt correct
setopt hist_ignore_dups
setopt hist_reduce_blanks
setopt share_history
setopt inc_append_history

# Deduplicate PATH — keeps only the first occurrence of each entry
typeset -U path

# ---------------------------------------------------------------------
# 1) ENVIRONMENT & PATH
# ---------------------------------------------------------------------
