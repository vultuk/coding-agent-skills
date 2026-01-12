#!/bin/bash
# Load GitHub issue details and related PRs
#
# Usage: load-issue.sh <issue-number>

set -e

ISSUE_NUMBER="$1"

if [ -z "$ISSUE_NUMBER" ]; then
    echo "Usage: load-issue.sh <issue-number>"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "Error: gh (GitHub CLI) is not installed" >&2
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "Error: gh is not authenticated. Run: gh auth login" >&2
    exit 1
fi

if ! gh repo view &> /dev/null; then
    echo "Error: Not in a GitHub repository. Run from a repo or set a default with 'gh repo set-default'." >&2
    exit 1
fi

echo "=== ISSUE #$ISSUE_NUMBER ==="
gh issue view "$ISSUE_NUMBER" --comments --json title,body,comments,author,url,labels,milestone,assignees,state

echo ""
echo "=== RELATED PULL REQUESTS ==="
gh pr list --search "issue:$ISSUE_NUMBER" --state all --json number,title,state,author,url
