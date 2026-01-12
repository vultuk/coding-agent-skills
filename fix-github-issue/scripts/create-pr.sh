#!/bin/bash
# Commit, push, and open PR linked to an issue
# Assumes you're already in a worktree with the correct branch
#
# Usage: create-pr.sh <issue-number> "Description of changes"

set -e

ISSUE_NUMBER="$1"
DESCRIPTION="$2"

if [ -z "$ISSUE_NUMBER" ] || [ -z "$DESCRIPTION" ]; then
    echo "Usage: create-pr.sh <issue-number> \"Description of changes\""
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "Error: git is not installed" >&2
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

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 1
fi

if ! git remote get-url origin &> /dev/null; then
    echo "Error: No 'origin' remote found" >&2
    exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)

echo "=== Current branch: $CURRENT_BRANCH ==="

echo ""
echo "=== Staging changes ==="
git add -A
git status --short

echo ""
echo "=== Committing ==="
if git diff --cached --quiet; then
    if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
        AHEAD_COUNT=$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null | awk '{print $1}')
    else
        AHEAD_COUNT=1
    fi

    if [ "${AHEAD_COUNT:-0}" -eq 0 ]; then
        echo "No changes to commit and no commits to push."
        exit 1
    fi

    echo "No staged changes to commit; continuing with existing commits."
else
    git commit -m "$DESCRIPTION

Closes #$ISSUE_NUMBER"
fi

echo ""
echo "=== Pushing to origin ==="
git push -u origin HEAD

echo ""
echo "=== Creating pull request ==="
gh pr create \
    --title "$DESCRIPTION" \
    --body "## Summary

$DESCRIPTION

## Issue

Closes #$ISSUE_NUMBER

## Changes

<!-- Describe what changed and why -->

## Testing

<!-- How was this tested? -->"

echo ""
echo "=== Done ==="
gh pr view --json url -q '.url'
