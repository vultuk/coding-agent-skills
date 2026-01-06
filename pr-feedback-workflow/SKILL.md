---
name: pr-feedback-workflow
description: Process all PR feedback in one pass. Fetches review comments and CI failures together, creates a unified action plan, applies fixes, replies to reviewers, resolves threads, and posts a summary. Use when asked to address PR feedback, fix review comments, handle CI failures, or process PR reviews. Works on the current branch's open PR.
triggers:
  - "address PR feedback"
  - "fix review comments"
  - "handle CI failures"
  - "process PR reviews"
  - "respond to reviewers"
prerequisites:
  - gh (GitHub CLI, authenticated)
  - git
  - jq (for JSON parsing in scripts)
arguments:
  - name: PR_NUMBER
    required: false
    description: The PR number (auto-detected from current branch if not provided)
---

# PR Feedback Workflow

Gather all PR feedback (review comments + CI failures), plan holistically, then execute.

## Phase 1: Gather Context

Run the script to collect all feedback:

```bash
scripts/load-pr-feedback.sh
```

This fetches:
- PR number, title, and current branch
- All conversation comments (general PR discussion)
- All review comments with thread IDs (code-specific feedback)
- All review threads (resolved and unresolved)
- Latest CI/CD run status and failure logs (if any)
- Summary statistics

The script handles:
- Rate limit checking before proceeding
- Pagination for large PRs (>100 threads)
- Graceful error handling for missing permissions

## Phase 2: Analyse

For each piece of feedback, categorise:

| Category | Action |
|----------|--------|
| **Code fix required** | Note the file, change needed, and which comments/CI failures it addresses |
| **No change needed** | Prepare explanation for reviewer |
| **Out of scope** | Prepare to create a new issue and link it |
| **CI-only failure** | Note the fix needed (may overlap with review comments) |
| **General question/discussion** | Prepare appropriate response |

Look for overlaps where one fix addresses multiple items.

Note the comment type (conversation vs review) as they use different reply mechanisms.

### Prioritising Feedback

Handle feedback in this order:
1. **Blocking issues**: Security concerns, correctness bugs, breaking changes
2. **Required changes**: Explicitly requested by reviewers with "Request changes"
3. **CI failures**: Tests, linting, type checking
4. **Suggestions**: Nice-to-haves, style preferences
5. **Questions**: Clarifications that don't block merge

### Handling Conflicting Opinions

When reviewers disagree:
1. Identify the core technical concern from each reviewer
2. If both are valid, choose the approach that:
   - Best fits existing codebase patterns
   - Is more maintainable long-term
   - Has better performance characteristics
3. Reply explaining your reasoning and invite further discussion
4. Tag both reviewers in your response

## Phase 3: Create Unified Plan

Before making changes, output a plan:

1. Code changes to make (grouped by file)
2. Which review comments each change addresses
3. Which CI failures each change fixes
4. Comments that need explanation-only replies
5. Out-of-scope items to convert to issues

Ask: "Ready to execute this plan?"

Wait for confirmation.

## Phase 4: Execute

### 1. Apply code fixes

Make all code changes, then commit:

```bash
git add -A
git commit -m "Address PR feedback

- [summary of changes]
- Fixes review comments from @reviewer
- Resolves CI failure in [workflow]"
git push
```

### 2. Reply to comments

**For code review comments** (attached to specific lines):

```bash
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
  -f body="Fixed: [description of change]"
```

**For PR conversation comments** (general discussion):

```bash
gh pr comment {PR_NUMBER} -b "Replying to @{author}: [response]"
```

Reply templates:
- Fix applied: `Fixed: [what was changed]`
- No change needed: `No change required: [explanation]`
- Out of scope: `Good suggestion, tracked as #[issue_number]`
- Acknowledgement: `Thanks for the feedback, [response]`

### Declining suggestions diplomatically

When you disagree with a suggestion:

```
Thanks for the suggestion. I considered this approach but chose [current approach] because:

1. [Technical reason]
2. [Practical reason]

Happy to discuss further if you see issues with this reasoning.
```

### 3. Create issues for out-of-scope items

```bash
gh issue create \
  -t "Enhancement: [title]" \
  -b "Suggested during PR review of #[PR_NUMBER].

## Context
[Original comment]

## Suggested approach
[Implementation ideas]"
```

### 4. Resolve review threads

Use the helper script:

```bash
scripts/resolve-thread.sh <THREAD_ID>
```

Or manually via GraphQL:

```bash
gh api graphql -f query='
  mutation {
    resolveReviewThread(input: {threadId: "<THREAD_ID>"}) {
      thread { id isResolved }
    }
  }'
```

**Note:** Only resolve threads where the feedback has been addressed. Leave threads open if discussion is ongoing.

### 5. Verify CI passes

Wait for CI to complete after pushing:

```bash
gh run watch
```

If still failing, repeat analysis on new logs.

### 6. Request re-review (if needed)

If reviewers requested changes:

```bash
gh pr edit $PR_NUMBER --add-reviewer @reviewer1,@reviewer2
```

## Phase 5: Summarise

Post a summary comment using [templates/summary.md](templates/summary.md):

```bash
gh pr comment -b "## PR Feedback Summary

### Review Comments
- X comments addressed with code changes
- Y comments resolved with explanations  
- Z suggestions tracked as new issues

### CI/CD
- [Status of workflow runs]

### Changes Made
- [List of commits/changes]

All feedback has been addressed."
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/load-pr-feedback.sh` | Fetches PR comments, threads, and CI status |
| `scripts/resolve-thread.sh` | Resolves a review thread by ID |

## Related Skills

- [fix-github-issue](../fix-github-issue/SKILL.md): The workflow that creates the PR
- [cleanup-issue](../cleanup-issue/SKILL.md): Clean up after PR is merged
