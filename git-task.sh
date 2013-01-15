#!/bin/sh
# git-task - issue tracker for git.
#
# This script is Free Software under the non-terms of
# the Anti-License. Do whatever the fuck you want.

# FIXME: git-stash changes the ctime of files. This causes vim to think that 
# files have changes. Find a way to avoid this, if possible.

_TASKBRANCH="git-task"

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
    echo "Preparing transaction..."
    echo "Checking for .git directory..."
    # TODO: currently only works in the git root directory.
    if [[ ! -d .git ]]; then
        error "Git dir not found. Is this the root directory of the repository?"
    fi

    # if this fails, something is horribly wrong.
    echo "Stashing current branch..."
    git stash save --include-untracked \
        "git-task stash. You should never see this." &>/dev/null
    if [[ $? -ne 0 ]]; then
        error "[FATAL] Stashing failed, bailing out. Your working directory might be dirty."
    fi

	echo "Checking out task-branch..."
	git checkout ${_TASKBRANCH}
	if [[ $? -ne 0 ]]; then
		echo "No task branch. Creating new orphan branch..."
        git checkout --orphan "${_TASKBRANCH}" HEAD || rollback 1
        echo "Unstaging everything..."
        git rm --cached -r "*" || rollback 1
	fi

    echo "Done preparing."
}

task_commit () {
    echo "Starting task transaction..."
    echo "Recording task..."
    TASKDATA=.task task $* || rollback 1

    # add and commit the changes
    echo "Adding task to git..."
    git add .task || rollback 1
    echo "Committing task..."
    git commit -m "$*" || rollback 1
    echo "Transaction done."
}

rollback () {
    echo "Rolling back..."
    # Since we stashed, there should™ be nothing that could go wrong here.
    echo "Checking out working branch..."
	git checkout -f ${_CURRENT} &>/dev/null
    if [[ $? -ne 0 ]]; then
        error "[FATAL] Couldn't rollback to previous state: checkout to ${_CURRENT} failed. There should be a stash with your uncommited changes."
    fi
    echo "Applying the stash..."
	git stash pop
	echo "Done rolling back."

    exit $1
}

# BEGIN SCRIPT

# TODO: Figure out a better way to save this than a global.
_CURRENT=$(current_branch)
prepare
task_commit $*
rollback

exit 0
