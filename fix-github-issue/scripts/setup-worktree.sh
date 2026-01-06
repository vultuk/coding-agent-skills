#!/bin/bash
# Set up a git worktree for working on an issue
#
# Usage: setup-worktree.sh <issue-number> [--no-worktree]
#
# Options:
#   --no-worktree    Work directly on a branch instead of creating a worktree
#
# This script:
# 1. Validates prerequisites (git repo, gh auth, origin remote)
# 2. Checks out main and pulls latest changes
# 3. Creates a worktree at .worktrees/issue-$ISSUE_NUMBER (or just a branch with --no-worktree)
# 4. Creates a new branch issue-$ISSUE_NUMBER
# 5. Outputs the path to cd into

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}Warning: $1${NC}" >&2
}

success() {
    echo -e "${GREEN}$1${NC}"
}

# Parse arguments
ISSUE_NUMBER=""
NO_WORKTREE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-worktree)
            NO_WORKTREE=true
            shift
            ;;
        -*)
            error "Unknown option: $1"
            ;;
        *)
            if [ -z "$ISSUE_NUMBER" ]; then
                ISSUE_NUMBER="$1"
            else
                error "Unexpected argument: $1"
            fi
            shift
            ;;
    esac
done

if [ -z "$ISSUE_NUMBER" ]; then
    echo "Usage: setup-worktree.sh <issue-number> [--no-worktree]"
    echo ""
    echo "Options:"
    echo "  --no-worktree    Work directly on a branch instead of creating a worktree"
    exit 1
fi

# Validate issue number is numeric
if ! [[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
    error "Issue number must be numeric, got: $ISSUE_NUMBER"
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "Not in a git repository. Please run this from within a git repo."
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) is not installed. Install it from https://cli.github.com/"
fi

# Check if gh CLI is authenticated
if ! gh auth status &> /dev/null; then
    error "GitHub CLI is not authenticated. Run 'gh auth login' first."
fi

# Check if origin remote exists
if ! git remote get-url origin &> /dev/null; then
    error "No 'origin' remote found. Add one with 'git remote add origin <url>'."
fi

# Check if origin is a GitHub remote
ORIGIN_URL=$(git remote get-url origin)
if [[ ! "$ORIGIN_URL" =~ github\.com ]]; then
    warn "Origin remote doesn't appear to be GitHub: $ORIGIN_URL"
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    error "You have uncommitted changes. Please commit or stash them first."
fi

# Check for detached HEAD
if [ "$(git rev-parse --abbrev-ref HEAD)" = "HEAD" ]; then
    error "You are in detached HEAD state. Please checkout a branch first."
fi

# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
WORKTREE_BASE="$REPO_ROOT/.worktrees"
WORKTREE_PATH="$WORKTREE_BASE/issue-$ISSUE_NUMBER"
BRANCH_NAME="issue-$ISSUE_NUMBER"

echo "=== Setting up workspace for issue #$ISSUE_NUMBER ==="
echo "Repository: $REPO_NAME"
if [ "$NO_WORKTREE" = false ]; then
    echo "Worktree path: $WORKTREE_PATH"
fi
echo "Branch: $BRANCH_NAME"
echo ""

# Ensure .worktrees is in .gitignore (only if using worktrees)
if [ "$NO_WORKTREE" = false ]; then
    if [ -f "$REPO_ROOT/.gitignore" ]; then
        if ! grep -q "^\.worktrees/?$" "$REPO_ROOT/.gitignore"; then
            echo ".worktrees/" >> "$REPO_ROOT/.gitignore"
            echo "Added .worktrees/ to .gitignore"
        fi
    else
        echo ".worktrees/" > "$REPO_ROOT/.gitignore"
        echo "Created .gitignore with .worktrees/"
    fi
fi

# Check if worktree already exists
if [ "$NO_WORKTREE" = false ] && [ -d "$WORKTREE_PATH" ]; then
    echo "Worktree already exists at $WORKTREE_PATH"
    echo ""
    echo "To use it:"
    echo "  cd $WORKTREE_PATH"
    echo ""
    echo "To remove and recreate:"
    echo "  git worktree remove $WORKTREE_PATH"
    exit 0
fi

# Determine the default branch (main or master)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
if ! git show-ref --verify --quiet "refs/heads/$DEFAULT_BRANCH"; then
    if git show-ref --verify --quiet "refs/heads/master"; then
        DEFAULT_BRANCH="master"
    else
        error "Could not determine default branch. Neither 'main' nor 'master' exists."
    fi
fi

# Check if branch already exists
BRANCH_EXISTS=false
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    BRANCH_EXISTS=true
    warn "Branch $BRANCH_NAME already exists."
fi

# Update default branch
echo "=== Updating $DEFAULT_BRANCH ==="
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
    git checkout "$DEFAULT_BRANCH" || error "Failed to checkout $DEFAULT_BRANCH"
fi

# Try to pull, handle failures gracefully
if ! git pull --ff-only origin "$DEFAULT_BRANCH" 2>/dev/null; then
    warn "Could not fast-forward $DEFAULT_BRANCH. Trying fetch + reset..."
    git fetch origin "$DEFAULT_BRANCH" || error "Failed to fetch from origin"
    
    # Check if local is behind
    LOCAL=$(git rev-parse "$DEFAULT_BRANCH")
    REMOTE=$(git rev-parse "origin/$DEFAULT_BRANCH")
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "Local $DEFAULT_BRANCH is diverged from origin. Options:"
        echo "  1. Reset to origin: git reset --hard origin/$DEFAULT_BRANCH"
        echo "  2. Merge: git merge origin/$DEFAULT_BRANCH"
        error "Please resolve $DEFAULT_BRANCH state manually and re-run."
    fi
fi

success "$DEFAULT_BRANCH is up to date."

if [ "$NO_WORKTREE" = true ]; then
    # Direct branch mode
    echo ""
    echo "=== Creating branch (no worktree) ==="
    
    if [ "$BRANCH_EXISTS" = true ]; then
        git checkout "$BRANCH_NAME" || error "Failed to checkout existing branch $BRANCH_NAME"
        echo "Switched to existing branch $BRANCH_NAME"
    else
        git checkout -b "$BRANCH_NAME" || error "Failed to create branch $BRANCH_NAME"
        echo "Created and switched to branch $BRANCH_NAME"
    fi
    
    echo ""
    success "=== Workspace ready ==="
    echo ""
    echo "You are now on branch: $BRANCH_NAME"
    echo "Start making your changes!"
else
    # Worktree mode
    mkdir -p "$WORKTREE_BASE"
    
    echo ""
    echo "=== Creating worktree ==="
    
    if [ "$BRANCH_EXISTS" = true ]; then
        git worktree add "$WORKTREE_PATH" "$BRANCH_NAME" || error "Failed to create worktree with existing branch"
    else
        git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" "$DEFAULT_BRANCH" || error "Failed to create worktree with new branch"
    fi
    
    echo ""
    success "=== Worktree ready ==="
    echo ""
    echo "To start working:"
    echo "  cd $WORKTREE_PATH"
    echo ""
    echo "Current worktrees:"
    git worktree list
fi
