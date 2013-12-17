#!/bin/bash

logMessage ()
{
	local thisMessage=$*
	local tabCount=0
	if [[ $TAB_INDENT -gt 0 ]]; then
		while [[ $tabCount -lt $TAB_INDENT ]]; do
			thisMessage="\t${thisMessage}"
			let tabCount++
		done
	fi
	echo -e "[`date --utc +"${LOG_DATE_FORMAT}"`] ${thisMessage}"
}

fatalMessage ()
{
    local exitCode=$1
    shift
    local thisMessage=$*
    logMessage "${thisMessage}"
    exit $exitCode
}

indentMore ()
{
	let TAB_INDENT++
}

indentLess ()
{
	let TAB_INDENT--
	TAB_INDENT=$((${TAB_INDENT}<0?0:${TAB_INDENT}))
}

indentReset ()
{
	TAB_INDENT=0
}

gitBranchExists ()
{
	local branchName=$1
	git show-branch $branchName >>/dev/null 2>&1 && return 0 || return 1
}

gitGetCurrentBranch ()
{
	git status | head -1 | sed 's/^# On branch\s\+//'
}
