#!/bin/bash
# Set up a git worktree for working on an issue
#
# Usage: setup-worktree.sh <issue-number>
#
# This script:
# 1. Ensures you're in a git repository
# 2. Checks out main and pulls latest changes
# 3. Creates a worktree at .worktrees/issue-$ISSUE_NUMBER
# 4. Creates a new branch issue-$ISSUE_NUMBER
# 5. Outputs the path to cd into

set -e

ISSUE_NUMBER="$1"

if [ -z "$ISSUE_NUMBER" ]; then
    echo "Usage: setup-worktree.sh <issue-number>"
    exit 1
fi

# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
WORKTREE_BASE="$REPO_ROOT/.worktrees"
WORKTREE_PATH="$WORKTREE_BASE/issue-$ISSUE_NUMBER"
BRANCH_NAME="issue-$ISSUE_NUMBER"

echo "=== Setting up worktree for issue #$ISSUE_NUMBER ==="
echo "Repository: $REPO_NAME"
echo "Worktree path: $WORKTREE_PATH"
echo "Branch: $BRANCH_NAME"
echo ""

# Ensure .worktrees is in .gitignore
if [ -f "$REPO_ROOT/.gitignore" ]; then
    if ! grep -q "^\.worktrees/?$" "$REPO_ROOT/.gitignore"; then
        echo ".worktrees/" >> "$REPO_ROOT/.gitignore"
        echo "Added .worktrees/ to .gitignore"
    fi
else
    echo ".worktrees/" > "$REPO_ROOT/.gitignore"
    echo "Created .gitignore with .worktrees/"
fi

# Check if worktree already exists
if [ -d "$WORKTREE_PATH" ]; then
    echo "Worktree already exists at $WORKTREE_PATH"
    echo ""
    echo "To use it:"
    echo "  cd $WORKTREE_PATH"
    echo ""
    echo "To remove and recreate:"
    echo "  git worktree remove $WORKTREE_PATH"
    exit 0
fi

# Check if branch already exists
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo "Warning: Branch $BRANCH_NAME already exists."
    echo "Creating worktree with existing branch..."
    
    # Ensure we're on main and up to date first
    echo ""
    echo "=== Updating main ==="
    git checkout main
    git pull --ff-only origin main
    
    # Create worktree directory
    mkdir -p "$WORKTREE_BASE"
    
    # Create worktree with existing branch
    git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
else
    # Checkout main and pull latest
    echo "=== Updating main ==="
    git checkout main
    git pull --ff-only origin main
    
    # Create worktree directory
    mkdir -p "$WORKTREE_BASE"
    
    # Create worktree with new branch
    echo ""
    echo "=== Creating worktree ==="
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" main
fi

echo ""
echo "=== Worktree ready ==="
echo ""
echo "To start working:"
echo "  cd $WORKTREE_PATH"
echo ""
echo "Current worktrees:"
git worktree list
