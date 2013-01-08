#!/bin/sh
# git-task - issue tracker for git.
#
# This script is Free Software under the non-terms of
# the Anti-License. Do whatever the fuck you want.

_TASKBRANCH="git-task"

error () {
	echo $* >&2
	exit 1
}

branch_exists () {
	if [[ -n "$(git branch --list $1)" ]]; then
		return 0
	else
		return 1
	fi
}

# TODO: Create an empty branch, not a fork of the current one.
make_branch () {
	git branch git-task || exit 1
}

current_branch () {
	git symbolic-ref HEAD --short 2>/dev/null
}

# stash the current branch and remember its name
prepare () {
	# if this fails, something is horribly wrong.
	git stash save --include-untracked \
		"git-task stash. You should never see this." &>/dev/null
	if [[ $? -ne 0 ]]; then
		error "Stashing failed, bailing out. Your working directory might be dirty."
	fi
	_CURRENT=$(current_branch)
	git checkout ${_TASKBRANCH} || rollback
}

rollback () {
	# Since we stashed, there should™ be nothing that could go wrong here.
	git checkout ${_CURRENT} &>/dev/null
	if [[ $? -ne 0 ]]; then
		error "[FATAL] Couldn't rollback to previous state: checkout to " \
		"$(_CURRENT) failed. There should be a stash with your uncommited" \
		"changes."
	fi
	git stash apply
}

# BEGIN SCRIPT

# TODO: currently only works in the git root directory.
if [[ ! -d .git ]]; then
	error "Git dir not found. Is this the root directory of the repository?"
fi

echo "Checking branch..."
if [[ $(branch_exists $_TASKBRANCH) -ne 0 ]]; then
	echo "Creating task branch..."
	make_branch || exit 1
fi
echo "Task branch exists."

prepare

TASKDATA=.task task $* || rollback

# add and commit the changes 
git add .task || rollback
git commit -m "$*" || rollback

# switch back
rollback

exit 0
