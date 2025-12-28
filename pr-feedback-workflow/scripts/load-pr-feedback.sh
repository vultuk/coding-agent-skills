#!/bin/bash
# Load all PR feedback: review comments, threads, and CI status
#
# Usage: load-pr-feedback.sh [PR_NUMBER]
# If PR_NUMBER not provided, detects from current branch

set -e

# Get repo owner and name
REPO_INFO=$(gh repo view --json owner,name -q '"\(.owner.login)/\(.name)"')
OWNER=$(echo "$REPO_INFO" | cut -d'/' -f1)
REPO=$(echo "$REPO_INFO" | cut -d'/' -f2)

# Get PR number (from argument or current branch)
if [ -n "$1" ]; then
    PR_NUMBER="$1"
else
    PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null || echo "")
    if [ -z "$PR_NUMBER" ]; then
        echo "Error: No PR found for current branch. Specify PR number as argument."
        exit 1
    fi
fi

echo "========================================"
echo "PR FEEDBACK REPORT: #$PR_NUMBER"
echo "Repository: $OWNER/$REPO"
echo "========================================"

echo ""
echo "=== PR DETAILS ==="
gh pr view "$PR_NUMBER" --json title,state,author,headRefName,baseRefName \
    -q '"Title: \(.title)\nState: \(.state)\nAuthor: \(.author.login)\nBranch: \(.headRefName) → \(.baseRefName)"'

echo ""
echo "=== PR CONVERSATION COMMENTS ==="
gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" \
    --jq '.[] | "---\nComment ID: \(.id)\nType: conversation\nAuthor: \(.user.login)\nCreated: \(.created_at)\n\nBody:\n\(.body)\n"'

echo ""
echo "=== CODE REVIEW COMMENTS (with IDs for replies) ==="
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" \
    --jq '.[] | "---\nComment ID: \(.id)\nType: review\nFile: \(.path):\(.line // .original_line)\nAuthor: \(.user.login)\nCreated: \(.created_at)\nIn-Reply-To: \(.in_reply_to_id // "none")\n\nBody:\n\(.body)\n"'

echo ""
echo "=== REVIEW THREADS (with IDs for resolution) ==="
gh api graphql -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first: 10) {
            nodes {
              id
              author { login }
              body
              createdAt
            }
          }
        }
      }
    }
  }
}' -f owner="$OWNER" -f repo="$REPO" -F pr="$PR_NUMBER" \
    --jq '.data.repository.pullRequest.reviewThreads.nodes[] |
        "---\nThread ID: \(.id)\nFile: \(.path):\(.line)\nResolved: \(.isResolved)\nOutdated: \(.isOutdated)\nComments:\n\(.comments.nodes | map("  [\(.author.login)] \(.body)") | join("\n"))\n"'

echo ""
echo "=== CI/CD STATUS ==="
gh pr checks "$PR_NUMBER" --json name,bucket,description \
    --jq '.[] | "\(.name): \(.bucket) - \(.description // "no description")"'

echo ""
echo "=== FAILING CI RUNS ==="
FAILED_RUN=$(gh run list --branch "$(gh pr view "$PR_NUMBER" --json headRefName -q '.headRefName')" \
    --limit 5 --json databaseId,name,conclusion,event \
    --jq '[.[] | select(.conclusion == "failure")] | first | "\(.databaseId) \(.name)"' 2>/dev/null || echo "")

if [ -n "$FAILED_RUN" ] && [ "$FAILED_RUN" != "null null" ] && [ "$FAILED_RUN" != " " ]; then
    RUN_ID=$(echo "$FAILED_RUN" | cut -d' ' -f1)
    RUN_NAME=$(echo "$FAILED_RUN" | cut -d' ' -f2-)
    echo "Latest failure: $RUN_NAME (Run ID: $RUN_ID)"
    echo ""
    echo "=== FAILURE LOGS (truncated) ==="
    gh run view "$RUN_ID" --log 2>/dev/null | grep -A 20 -i "error\|failed\|failure" | head -100
else
    echo "No recent failures found."
fi

echo ""
echo "========================================"
echo "END OF FEEDBACK REPORT"
echo "========================================"
