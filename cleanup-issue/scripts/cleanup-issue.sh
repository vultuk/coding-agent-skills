#!/bin/bash
# Clean up after an issue is complete
#
# Usage: cleanup-issue.sh <issue-number>
#
# This script:
# 1. Finds the PR for the issue branch
# 2. Merges it if approved but not yet merged
# 3. Removes the worktree
# 4. Deletes the local branch
# 5. Updates main
# 6. Prunes stale worktree references

set -e

ISSUE_NUMBER="$1"

if [ -z "$ISSUE_NUMBER" ]; then
    echo "Usage: cleanup-issue.sh <issue-number>"
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
BRANCH_NAME="issue-$ISSUE_NUMBER"
WORKTREE_PATH="$REPO_ROOT/.worktrees/issue-$ISSUE_NUMBER"

echo "=== Cleaning up issue #$ISSUE_NUMBER ==="
echo "Branch: $BRANCH_NAME"
echo "Worktree: $WORKTREE_PATH"
echo ""

# Step 1: Check if we're in the worktree (need to leave first)
CURRENT_DIR=$(pwd)
if [[ "$CURRENT_DIR" == "$WORKTREE_PATH"* ]]; then
    echo "Currently in worktree, moving to repo root..."
    cd "$REPO_ROOT"
fi

# Step 2: Find and check PR status
echo "=== Checking PR status ==="
PR_INFO=$(gh pr list --head "$BRANCH_NAME" --json number,state,mergeStateStatus --jq '.[0]' 2>/dev/null || echo "")

if [ -z "$PR_INFO" ] || [ "$PR_INFO" == "null" ]; then
    echo "No open PR found for branch $BRANCH_NAME"
    echo "Checking for merged PR..."
    
    MERGED_PR=$(gh pr list --head "$BRANCH_NAME" --state merged --json number --jq '.[0].number' 2>/dev/null || echo "")
    
    if [ -n "$MERGED_PR" ] && [ "$MERGED_PR" != "null" ]; then
        echo "PR #$MERGED_PR was already merged."
    else
        echo "No PR found. Proceeding with local cleanup only."
    fi
else
    PR_NUMBER=$(echo "$PR_INFO" | jq -r '.number')
    PR_STATE=$(echo "$PR_INFO" | jq -r '.state')
    MERGE_STATUS=$(echo "$PR_INFO" | jq -r '.mergeStateStatus')
    
    echo "Found PR #$PR_NUMBER"
    echo "State: $PR_STATE"
    echo "Merge status: $MERGE_STATUS"
    
    if [ "$PR_STATE" == "OPEN" ]; then
        if [ "$MERGE_STATUS" == "CLEAN" ]; then
            echo ""
            echo "=== Merging PR #$PR_NUMBER ==="
            gh pr merge "$PR_NUMBER" --merge --delete-branch
            echo "PR merged successfully!"
        else
            echo ""
            echo "Warning: PR is not ready to merge (status: $MERGE_STATUS)"
            echo "Please resolve any issues and try again."
            exit 1
        fi
    fi
fi

# Step 3: Remove worktree
echo ""
echo "=== Removing worktree ==="
if [ -d "$WORKTREE_PATH" ]; then
    git worktree remove "$WORKTREE_PATH" --force
    echo "Worktree removed."
else
    echo "Worktree not found at $WORKTREE_PATH (already removed?)"
fi

# Step 4: Delete local branch
echo ""
echo "=== Cleaning up local branch ==="
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    git branch -D "$BRANCH_NAME" 2>/dev/null || echo "Branch already deleted or is current branch"
else
    echo "Local branch $BRANCH_NAME not found (already deleted?)"
fi

# Step 5: Update main
echo ""
echo "=== Updating main ==="
git checkout main
git pull --ff-only origin main
echo "Main is up to date."

# Step 6: Prune worktree references
echo ""
echo "=== Pruning stale worktree references ==="
git worktree prune
echo "Done."

echo ""
echo "=== Cleanup complete ==="
echo ""
echo "Current worktrees:"
git worktree list
echo ""
echo "Ready for next task. Run /new to start fresh."
