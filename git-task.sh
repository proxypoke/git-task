#!/bin/sh
# git-task - issue tracker for git.
#
# This script is Free Software under the non-terms of
# the Anti-License. Do whatever the fuck you want.

# FIXME: git-stash changes the ctime of files. This causes vim to think that 
# files have changes. Find a way to avoid this, if possible.

_TASKBRANCH="${TASKBRANCH:-tasks}"
_DEBUG="false"
TASK="/usr/local/bin/task"

log () {
  echo $* >&1
}

error () {
  echo $* >&2
  exit 1
}

branch_exists () {
    if [[ -z "$(git branch --list $1)" ]]; then
        return 0
    else
        return 1
    fi
}

current_branch () {
    git symbolic-ref HEAD --short 2>/dev/null
}

# stash the current branch and remember its name
prepare () {
  $_DEBUG && log "Preparing transaction..."
  $_DEBUG && log "Checking for .git directory..."
  # TODO: currently only works in the git root directory.
  _OLDDIR="$PWD"
  cd $( git rev-parse --show-toplevel )
  if [[ ! -d .git ]]; then
    error "Git dir not found. Is this the root directory of the repository?"
    exit 1
  fi

  # source env file if exists
  [ -f ${_TASKBRANCH}.config ] && source ./${_TASKBRANCH}.config
  # if this fails, something is horribly wrong.
  $_DEBUG && log "Stashing current branch..."
  git stash save --include-untracked \
    "git-task stash. You should never see this." &>/dev/null
  if [[ $? -ne 0 ]]; then
    error "[FATAL] Stashing failed, bailing out. Your working directory might be dirty."
  fi

  $_DEBUG && log "Checking out task-branch..."
  git checkout  -q ${_TASKBRANCH}
  if [[ $? -ne 0 ]]; then
    $_DEBUG && log "No task branch. Creating new orphan branch..."
    git checkout -q --orphan "${_TASKBRANCH}" HEAD || rollback 1
    $_DEBUG && log "Unstaging everything..."
    git rm -q --cached -r "*" || rollback 1
  fi

  cd $_OLDDIR
  $_DEBUG && log "Done preparing."
}

task_commit () {
  $_DEBUG && log "Starting task transaction..."
  $_DEBUG && log "Recording task..."
  TASKDATA=.task $TASK $* || rollback 1
  # add and commit the changes
  $_DEBUG && log "Adding task to git..."
  git add .task || rollback 1
  $_DEBUG && log "Committing task..."
  git commit -q -m "$*" || rollback 1
  $_DEBUG && log "Transaction done."
}

rollback () {
  $_DEBUG && log "Rolling back..."
  # Since we stashed, there should™ be nothing that could go wrong here.
  $_DEBUG && log "Checking out working branch..."
  git checkout -f ${_CURRENT} &>/dev/null
  if [[ $? -ne 0 ]]; then
    error "[FATAL] Couldn't rollback to previous state: checkout to ${_CURRENT} failed. There should be a stash with your uncommited changes."
  fi
  $_DEBUG && log "Applying the stash..."
  git stash pop -q
  $_DEBUG && log "Done rolling back."

  exit $1
}

# BEGIN SCRIPT

# TODO: Figure out a better way to save this than a global.
_CURRENT=$(current_branch)
prepare
task_commit $*
rollback

exit 0

# vim: ts=2 sw=2 sts=2 et :
