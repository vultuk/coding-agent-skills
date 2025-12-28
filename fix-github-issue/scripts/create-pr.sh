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

CURRENT_BRANCH=$(git branch --show-current)

echo "=== Current branch: $CURRENT_BRANCH ==="

echo ""
echo "=== Staging changes ==="
git add -A
git status --short

echo ""
echo "=== Committing ==="
git commit -m "$DESCRIPTION

Closes #$ISSUE_NUMBER"

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
gh pr view --web
