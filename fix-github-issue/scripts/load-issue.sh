#!/bin/bash
# Load GitHub issue details and related PRs
#
# Usage: load-issue.sh <issue-number>

ISSUE_NUMBER="$1"

if [ -z "$ISSUE_NUMBER" ]; then
    echo "Usage: load-issue.sh <issue-number>"
    exit 1
fi

echo "=== ISSUE #$ISSUE_NUMBER ==="
gh issue view "$ISSUE_NUMBER" --comments --json title,body,comments,author,url,labels,milestone,assignees,state

echo ""
echo "=== RELATED PULL REQUESTS ==="
gh pr list --search "issue:$ISSUE_NUMBER" --state all --json number,title,state,author,url
