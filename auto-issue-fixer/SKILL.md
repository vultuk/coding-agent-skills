---
name: auto-issue-fixer
description: Automate the complete GitHub issue lifecycle. Fetches all issues, prioritizes by importance and execution speed, implements fixes using TDD, creates PRs, monitors for reviews, handles feedback autonomously, and notifies when complete. Uses extensive subagent parallelization for context efficiency.
triggers:
  - "auto fix issues"
  - "process github issues"
  - "fix next issue"
  - "run auto issue fixer"
  - "automate issue fixing"
prerequisites:
  - gh (GitHub CLI, authenticated)
  - git
  - jq (for JSON parsing)
arguments:
  - name: MAX_ISSUES
    required: false
    description: Maximum number of issues to process in one run (default 1)
  - name: LABELS
    required: false
    description: Filter issues by labels (comma-separated)
  - name: EXCLUDE_LABELS
    required: false
    description: Exclude issues with these labels (comma-separated)
  - name: DRY_RUN
    required: false
    description: Analyze and plan without implementing (default false)
  - name: MAX_FEEDBACK_ITERATIONS
    required: false
    description: Maximum rounds of PR feedback to process (default 3)
  - name: REVIEW_TIMEOUT_MINUTES
    required: false
    description: How long to wait for reviews before proceeding (default 30)
---

# Auto Issue Fixer

Fully autonomous GitHub issue lifecycle automation with TDD implementation.

## Overview

This skill runs completely autonomously:
1. Fetches and prioritizes all open issues
2. Selects the highest-priority issue
3. Implements the fix using TDD (Red-Green-Refactor)
4. Creates a PR and requests review
5. Monitors and addresses CI failures and review feedback
6. Notifies the user when ready for final review

**Workflow**: PRs are created immediately to trigger CI and review requests. The skill monitors feedback and addresses it autonomously. When complete, it tags the user for final review and merge.

---

## Status Output

**IMPORTANT**: Output clear status messages at each stage so the user can follow progress. Use this format:

```
================================================================================
AUTO-ISSUE-FIXER: [PHASE] - [ACTION]
================================================================================
```

### Required Status Messages

Output these messages at each stage:

| Phase | Message |
|-------|---------|
| Start | `AUTO-ISSUE-FIXER: STARTING - Fetching issues from repository` |
| Issues found | `AUTO-ISSUE-FIXER: FOUND {N} ISSUES - Analysing priorities...` |
| Issue selected | `AUTO-ISSUE-FIXER: SELECTED ISSUE #{N} - {title}` |
| Sync | `AUTO-ISSUE-FIXER: SYNCING - Pulling latest from origin/main` |
| Planning | `AUTO-ISSUE-FIXER: PLANNING - Creating TDD implementation plan` |
| RED phase | `AUTO-ISSUE-FIXER: TDD RED - Writing failing tests` |
| GREEN phase | `AUTO-ISSUE-FIXER: TDD GREEN - Implementing to pass tests` |
| REFACTOR phase | `AUTO-ISSUE-FIXER: TDD REFACTOR - Cleaning up implementation` |
| PR created | `AUTO-ISSUE-FIXER: PR CREATED - #{N} {url}` |
| Monitoring | `AUTO-ISSUE-FIXER: MONITORING - Waiting for CI and reviews` |
| Feedback | `AUTO-ISSUE-FIXER: FEEDBACK - Processing {N} items` |
| Complete | `AUTO-ISSUE-FIXER: COMPLETE - PR #{N} ready for review` |
| No issues | `AUTO-ISSUE-FIXER: NO ISSUES - No actionable issues found` |
| Error | `AUTO-ISSUE-FIXER: ERROR - {description}` |

---

## Phase 1: Issue Discovery and Prioritization

### 1.1 Fetch All Issues

```bash
scripts/list-all-issues.sh [--labels LABELS] [--exclude LABELS]
```

This fetches all open issues with metadata needed for prioritization.

### 1.2 Parallel Complexity Analysis

Launch Explore subagents in parallel (batches of 5 issues) to analyze implementation complexity:

```
Launch parallel Explore agents (one per batch):

"Analyze these GitHub issues for implementation complexity:

Issues: {batch_of_5_issues}

For each issue, evaluate:
1. Number of files likely affected (search codebase for keywords)
2. Presence of reproduction steps (clear = easier)
3. Clarity of expected outcome
4. Existing test coverage for affected areas
5. Similar past issues/PRs as reference

Return JSON:
{
  "issues": [
    {"number": N, "complexity_score": 0-100, "estimated_files": N, "has_repro": bool, "notes": "..."}
  ]
}"
```

### 1.3 Auto-Exclude Issues

Before scoring, automatically exclude issues that should not be processed:

| Condition | Reason | Detection |
|-----------|--------|-----------|
| **Has open linked PR** | Already being worked on | `has_linked_pr == true` from script |
| Assigned to human | Someone is handling it | `assignees` contains non-bot users |
| Label: `auto-fixing` | Currently being processed | Label check |
| Label: `auto-fixed` | Already completed | Label check |
| Label: `wontfix` | Intentionally not fixing | Label check |
| Label: `duplicate` | Duplicate of another | Label check |
| Label: `blocked` | Blocked by dependency | Label check |
| Label: `on-hold` | Intentionally paused | Label check |

The `list-all-issues.sh` script detects linked PRs via GitHub's timeline API:
- Finds `CROSS_REFERENCED_EVENT` (PR mentions issue)
- Finds `CONNECTED_EVENT` (PR explicitly linked)
- Only counts **OPEN** PRs (closed/merged PRs don't block)

```bash
# Example output showing issue with linked PR
{
  "number": 874,
  "title": "Enforce capacity limit",
  "has_linked_pr": true,
  "linked_pr_count": 1,
  "linked_prs": [879]
}
```

**This issue would be SKIPPED** - PR #879 is already addressing it.

### 1.4 Calculate Priority Scores

**Combined Score Formula**: `(Importance * 0.6) + (Speed * 0.4)`

**Importance Score (0-100)**:
| Factor | Weight | Scoring |
|--------|--------|---------|
| Labels | 30% | `security`: 95, `priority-critical`: 90, `priority-high`: 80, `bug`: 70, `enhancement`: 40 |
| Age | 20% | >30 days: 80, >14 days: 60, >7 days: 40, <7 days: 20 |
| Author | 15% | Maintainer: 80, Contributor: 60, External: 40 |
| Assignees | 10% | Unassigned: 70, Assigned to bot: 80, Assigned to human: 20 |
| Comments | 15% | >5: 70, 3-5: 50, 1-2: 30, 0: 20 |
| Milestone | 10% | Current: 90, Next: 60, None: 30 |

**Speed Score (0-100)** - From subagent analysis:
| Factor | Weight | Scoring |
|--------|--------|---------|
| Description length | 20% | <200 chars: 80, 200-500: 60, 500-1000: 40, >1000: 20 |
| Files affected | 30% | 1 file: 90, 2-3: 70, 4-5: 40, >5: 20 |
| Complexity keywords | 25% | "typo/fix/update": 80, "add/change": 60, "refactor": 30, "rewrite/architecture": 10 |
| Has reproduction | 15% | Yes: 80, Partial: 50, No: 30 |
| Has suggested fix | 10% | Yes: 90, Partial: 60, No: 40 |

See [references/prioritization-criteria.md](references/prioritization-criteria.md) for full scoring details.

### 1.5 Select Top Issue

Automatically select the issue with highest combined score. Output prioritization report:

```markdown
## Issue Prioritization

| Rank | Issue | Title | Importance | Speed | Combined |
|------|-------|-------|------------|-------|----------|
| 1 | #123 | Fix null pointer | 75 | 85 | 79 |
| 2 | #456 | Add validation | 70 | 70 | 70 |

**Selected**: #123 - High importance AND quick to implement
```

---

## Phase 2: Setup and Planning

### 2.1 Sync with Remote

Pull the latest changes before starting any work:

```bash
git fetch origin
git pull --rebase origin main
```

This ensures we're working with the latest codebase and avoids merge conflicts later.

### 2.2 Create Worktree

Use the existing worktree setup script:

```bash
../fix-github-issue/scripts/setup-worktree.sh $ISSUE_NUMBER
```

This creates an isolated worktree at `.worktrees/issue-$ISSUE_NUMBER`.

### 2.3 Mark Issue In Progress

Add a label to indicate work has started:

```bash
gh issue edit $ISSUE_NUMBER --add-label "auto-fixing"
```

This prevents other runs from picking up the same issue and signals to humans that automated work is underway.

### 2.4 Load Issue Context

```bash
../fix-github-issue/scripts/load-issue.sh $ISSUE_NUMBER
```

### 2.5 Create TDD Plan

Launch Explore subagent to create a TDD-specific implementation plan:

```
Launch Explore agent:

"Create a TDD implementation plan for issue #{number}: {title}

Issue details:
{issue_body}

Explore the codebase and return a plan with:

## Phase 1: RED - Failing Tests
List specific test cases to write first:
- Test file path
- Test function name
- What behavior it verifies
- Expected failure reason

## Phase 2: GREEN - Minimal Implementation
List minimal code changes to make tests pass:
- File path
- Function/method to modify
- Specific change description

## Phase 3: REFACTOR - Cleanup
List refactoring opportunities:
- DRY violations to fix
- Naming improvements
- Performance optimizations

## Verification Commands
Detect and list:
- Test command (npm test, pytest, go test, etc.)
- Lint command
- Build command

Return structured markdown using templates/tdd-plan.md format"
```

---

## Phase 3: TDD Implementation

### 3.1 RED Phase - Write Failing Tests

1. Create or update test file based on the TDD plan
2. Write test cases that define expected behavior
3. Run tests to verify they fail:

```bash
{TEST_COMMAND}
# Expected: FAIL (tests should fail before implementation)
```

**Critical**: If tests pass before implementation, the tests may not be testing the right behavior. Review and adjust test cases.

### 3.2 GREEN Phase - Minimal Implementation

1. Write the minimum code to make tests pass
2. Focus on correctness, not elegance
3. Run tests after each change:

```bash
{TEST_COMMAND}
# Expected: PASS
```

### 3.3 REFACTOR Phase

1. Clean up implementation while keeping tests green
2. Apply DRY principles
3. Improve naming and structure
4. Final verification:

```bash
{TEST_COMMAND} && {LINT_COMMAND} && {BUILD_COMMAND}
```

### 3.4 Background Test Monitoring

Launch background subagent for continuous feedback:

```
Launch background agent:

"Monitor test and lint status continuously.

Run every 30 seconds:
- {TEST_COMMAND}
- {LINT_COMMAND}

Report immediately when:
- All tests pass (GREEN achieved)
- New test failures (regression detected)
- Lint errors introduced

Return: Status updates as work progresses"
```

---

## Phase 4: Submit PR

### 4.1 Final Verification

Run all checks before committing:

```bash
{TEST_COMMAND} && {LINT_COMMAND} && {TYPECHECK_COMMAND} && {BUILD_COMMAND}
```

### 4.2 Commit Changes

```bash
git add -A
git commit -m "$(cat <<'EOF'
fix: [Brief description from issue title]

- [Change 1]
- [Change 2]

TDD Approach:
- Added [N] test cases for [scenario]
- Verified [edge case] handling

Closes #ISSUE_NUMBER

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

### 4.3 Create PR

```bash
git push -u origin HEAD
gh pr create --title "fix: [Brief description]" --body-file templates/pr-body.md
```

The PR is created immediately to trigger CI checks and allow reviewers to be notified.

### 4.4 Record PR Number

```bash
PR_NUMBER=$(gh pr view --json number -q '.number')
echo "Created PR #$PR_NUMBER"
```

---

## Phase 5: Feedback Loop

This phase handles ALL PR feedback including CI failures, code reviews, inline comments, and general discussion. The skill must track and address each piece of feedback before marking the PR ready.

### 5.1 Fetch All Current Feedback

Before monitoring for changes, get the current state of all feedback:

```bash
scripts/fetch-pr-comments.sh $PR_NUMBER --json > /tmp/pr-feedback-state.json
```

This returns structured data including:
- **Review threads** (inline code comments with resolution status)
- **Reviews** (approve/request changes/comment with body text)
- **General comments** (discussion on the PR)
- **Actionable items** (items requiring response or code changes)

### 5.2 Launch Parallel Monitors

Start background agents to monitor for new feedback:

```bash
# Monitor for any new PR activity (reviews, threads, comments)
scripts/monitor-pr.sh $PR_NUMBER --timeout $REVIEW_TIMEOUT_MINUTES &
MONITOR_PID=$!

# Separately monitor CI status
scripts/wait-for-ci.sh $PR_NUMBER --timeout 15 &
CI_PID=$!
```

The monitor-pr.sh script detects:
- `THREAD_RECEIVED` - New inline code review comment
- `REVIEW_RECEIVED` - New review (approve/request changes)
- `COMMENT_RECEIVED` - New general PR comment
- `THREAD_UNRESOLVED` - Thread was re-opened
- `MERGED` / `CLOSED` / `TIMEOUT`

### 5.3 Handle CI Failures

When CI fails, diagnose and fix:

```
Launch Explore agent:

"CI has failed for PR #{pr_number}.

Failure logs:
{ci_failure_logs}

Current changes (git diff):
{diff_summary}

Diagnose:
1. Root cause of each failure
2. Specific code changes needed
3. Whether new tests are required

Return: Actionable fix plan with file paths and code changes"
```

Apply fixes, commit, and push:

```bash
git add -A
git commit -m "fix: Address CI failures

- [Fix 1]
- [Fix 2]"
git push
```

### 5.4 Categorize Review Feedback

When feedback arrives, categorize each item:

```bash
# Get all unresolved actionable items
scripts/fetch-pr-comments.sh $PR_NUMBER --unresolved-only --json
```

For each feedback item, classify it:

| Category | Detection | Action Required |
|----------|-----------|-----------------|
| **Code Change Request** | Keywords: "fix", "change", "update", "remove", "add", "please", "should", "must" | Modify code, reply, resolve thread |
| **Question** | Ends with "?", starts with "why", "how", "what", "could you" | Answer question, resolve thread |
| **Suggestion (in scope)** | "Consider", "maybe", "alternatively", "what about" + related to current change | Evaluate, implement or explain, resolve thread |
| **Suggestion (out of scope)** | Suggestion about unrelated code, broad refactoring | Thank, offer to create issue, resolve thread |
| **Nitpick** | "nit:", "minor:", style preferences | Apply if trivial, explain if not, resolve thread |
| **Approval/Praise** | "LGTM", "looks good", "nice", "approved" | Thank briefly, no code change needed |
| **Concern/Blocker** | "Blocking", "must fix", "security", "breaking" | Prioritize fixing, escalate if unclear |

### 5.5 Process Feedback with Subagents

Launch parallel agents to handle different feedback types:

```
Launch parallel Explore agents:

1. Code Changes Agent:
   "Process these review comments that require code changes:

   {code_change_items_json}

   For each comment:
   1. Understand what change is being requested
   2. Locate the relevant code in the codebase
   3. Apply the change (read file first, then edit)
   4. Prepare a confirmation reply: 'Done: [brief description]'

   Return JSON:
   {
     'changes': [{'file': 'path', 'description': 'what changed'}],
     'replies': [{'thread_id': 'id', 'reply': 'text'}]
   }"

2. Response Agent:
   "Process these review comments that need responses only:

   {response_items_json}

   For each comment, draft appropriate reply:
   - If QUESTION: Answer directly with context from codebase
   - If SUGGESTION (out of scope): Thank, explain scope, offer to create issue
   - If CONCERN: Explain the reasoning or acknowledge and fix
   - If APPROVAL: Brief thanks

   Return JSON:
   {
     'replies': [{'thread_id': 'id', 'reply': 'text', 'should_resolve': bool}]
   }"
```

### 5.6 Reply to Threads and Resolve

Use the `reply-to-thread.sh` script to reply and optionally resolve in one step:

**If code change was applied:**
```bash
scripts/reply-to-thread.sh "$THREAD_ID" "Done - [description of fix]" --resolve
```

**If declining the suggestion (with reason):**
```bash
scripts/reply-to-thread.sh "$THREAD_ID" "Thanks for the suggestion. I kept the current approach because:

1. [Technical reason]
2. [Scope reason]

Happy to discuss further." --resolve
```

**If answering a question:**
```bash
scripts/reply-to-thread.sh "$THREAD_ID" "[Answer to the question]" --resolve
```

**If need to discuss further (don't resolve):**
```bash
scripts/reply-to-thread.sh "$THREAD_ID" "Good point. [Response]. What do you think?"
# Don't use --resolve - leave open for continued discussion
```

**Post general PR comment (not a thread reply):**
```bash
gh pr comment $PR_NUMBER -b "$COMMENT_TEXT"
```

### 5.7 Resolution Rules

**ALWAYS reply before resolving** - Never resolve without an explanation.

**When to resolve (use `--resolve` flag):**
- Code change was applied as requested → Reply "Done - [what changed]"
- Question was answered → Reply with answer
- Suggestion declined → Reply with reason why
- Nitpick addressed → Reply "Fixed" or "Left as-is because [reason]"

**When NOT to resolve:**
- Waiting for reviewer to confirm fix is acceptable
- Disagreement needs further discussion
- Reviewer explicitly asks to leave open
- Unsure if change is correct

**Every thread must end with one of:**
1. Reply + Resolve (action taken or declined with reason)
2. Reply only (needs discussion)
3. Escalation to human (can't determine action)

### 5.8 Reply Templates

**For code changes applied:**
```markdown
Done - [brief description of what was changed].
```

**For questions answered:**
```markdown
[Direct answer to the question]

[Optional: Link to relevant code or documentation]
```

**For suggestions declined (in scope):**
```markdown
Thanks for the suggestion! I considered this but kept the current approach because:

- [Technical reason: e.g., "This aligns with the existing pattern in `utils/validation.ts`"]
- [Practical reason: e.g., "The suggested change would require updating 15 call sites"]

Happy to discuss further if you'd like to reconsider.
```

**For suggestions declined (out of scope):**
```markdown
Good point! This change is outside the scope of this PR (which focuses on [issue focus]).

I've created issue #[N] to track this improvement separately. Would you like me to prioritize it next?
```

**For concerns/blockers:**
```markdown
Thanks for flagging this. I've addressed it by:

- [Change 1]
- [Change 2]

Please let me know if this addresses your concern or if you'd like further changes.
```

### 5.9 Handle Conflicting Feedback

When reviewers disagree:

1. **Identify the conflict**: Same code, different suggestions
2. **Check reviewer authority**: Maintainer opinion typically takes precedence
3. **If equal authority**:
   - Summarize both perspectives in a comment
   - Implement the more conservative/safe option
   - Ask for consensus: "I went with [X] but happy to switch if you both prefer [Y]"
4. **If unclear**: Escalate to human

### 5.10 Iteration Loop

```
ITERATION=0
MAX_ITERATIONS=$MAX_FEEDBACK_ITERATIONS

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
    ITERATION=$((ITERATION + 1))

    # 1. Fetch current feedback state
    FEEDBACK=$(scripts/fetch-pr-comments.sh $PR_NUMBER --json)
    UNRESOLVED=$(echo "$FEEDBACK" | jq '.summary.unresolved_threads')
    CHANGES_REQUESTED=$(echo "$FEEDBACK" | jq '.summary.changes_requested')

    # 2. If nothing to address, check if ready
    if [ "$UNRESOLVED" -eq 0 ] && [ "$CHANGES_REQUESTED" -eq 0 ]; then
        # Wait for CI and proceed to Phase 6
        break
    fi

    # 3. Process all actionable items
    # (Use subagents as described above)

    # 4. Commit any changes
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "Address review feedback (iteration $ITERATION)"
        git push
    fi

    # 5. Wait for CI
    scripts/wait-for-ci.sh $PR_NUMBER --timeout 10

    # 6. Wait for potential follow-up feedback
    scripts/monitor-pr.sh $PR_NUMBER --timeout 5 --interval 30
done

if [ $ITERATION -ge $MAX_ITERATIONS ]; then
    # Escalate to human
    gh pr comment $PR_NUMBER -b "## Escalation

After $MAX_ITERATIONS feedback iterations, some items remain unresolved.
Human review requested.

Remaining unresolved threads: $UNRESOLVED"
fi
```

### 5.11 Iteration Limits and Escalation

- **Max iterations**: Default 3 (configurable via MAX_FEEDBACK_ITERATIONS)
- **Per iteration**: Fetch all feedback → process → push → wait for CI → wait for response
- **Escalation triggers**:
  - MAX_FEEDBACK_ITERATIONS exceeded
  - Reviewer explicitly requests human review
  - Feedback requires architectural decisions
  - Conflicting reviewer opinions without resolution

---

## Phase 6: Completion

### 6.1 Verify Completion Criteria

All must be true before marking ready:

```bash
# CI green
CI_STATUS=$(gh pr checks $PR_NUMBER --json bucket -q '[.[] | .bucket] | unique')
[ "$CI_STATUS" = '["pass"]' ] || exit 1

# No unresolved threads
UNRESOLVED=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes { isResolved }
        }
      }
    }
  }' -f owner="$OWNER" -f repo="$REPO" -F pr="$PR_NUMBER" \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)] | length')
[ "$UNRESOLVED" = "0" ] || exit 1
```

### 6.2 Mark PR Ready for Review

```bash
scripts/mark-pr-ready.sh $PR_NUMBER
```

This script:
1. Verifies all CI checks pass
2. Verifies all review threads are resolved
3. If PR is a draft, marks it as ready (`gh pr ready`)
4. **Adds `ready` label** to the PR
5. **Tags the logged-in user** for notification
6. Posts a completion summary comment

The comment tags the user so they receive a GitHub notification:

```markdown
## Ready for Manual Review

@username - This PR is ready for your review.

### Summary
All automated work has been completed:
- All CI checks passing
- All review feedback addressed
- All review threads resolved

### Next Steps
1. Review the changes
2. Approve if satisfied
3. Merge when ready
```

The user tag ensures the human gets notified when the skill completes its work.

### 6.3 Generate Completion Report

Output summary using [templates/completion-report.md](templates/completion-report.md):

```markdown
## Auto Issue Fixer - Complete

### Issue
- **Number**: #123
- **Title**: Fix null pointer in user service

### PR
- **Number**: #456
- **Status**: Ready for review
- **URL**: https://github.com/owner/repo/pull/456

### TDD Summary
| Phase | Result |
|-------|--------|
| RED | 3 test cases written |
| GREEN | 2 files modified |
| REFACTOR | 1 cleanup applied |

### Feedback Handled
- Code changes: 2
- Responses: 1
- Iterations: 2/3

**Next step**: Human review and merge
```

### 6.4 Update Issue Labels

Swap the in-progress label for a completed label:

```bash
gh issue edit $ISSUE_NUMBER --remove-label "auto-fixing" --add-label "auto-fixed"
```

This signals that automated work is complete and the PR is ready for human review.

---

## Escalation Triggers

Stop and escalate to human when:

| Condition | Action |
|-----------|--------|
| CI fails after 3 attempts | Report failures, request help |
| Reviewer requests architectural changes | Flag as out of scope |
| MAX_FEEDBACK_ITERATIONS exceeded | Post summary, request guidance |
| Reviewer explicitly requests human | Stop and notify |
| Merge conflicts | Attempt rebase; if fails, escalate |
| No test framework detected | Warn and proceed without TDD |

Escalation message:
```markdown
## Escalation Required

**Issue**: #{issue_number}
**PR**: #{pr_number}
**Reason**: {escalation_reason}

### Context
{relevant_details}

### Attempted Solutions
{what_was_tried}

### Recommended Action
{suggestion}
```

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/list-all-issues.sh` | Fetch all open issues with metadata |
| `scripts/fetch-pr-comments.sh` | Fetch all PR feedback (threads, reviews, comments) with categorization |
| `scripts/monitor-pr.sh` | Poll for new reviews, threads, and comments |
| `scripts/wait-for-ci.sh` | Wait for CI completion |
| `scripts/reply-to-thread.sh` | Reply to a review thread and optionally resolve it |
| `scripts/mark-pr-ready.sh` | Convert draft to ready for review |

**Reused from other skills**:
| Script | Source |
|--------|--------|
| `setup-worktree.sh` | fix-github-issue |
| `load-issue.sh` | fix-github-issue |
| `create-pr.sh` | fix-github-issue |
| `load-pr-feedback.sh` | pr-feedback-workflow |
| `resolve-thread.sh` | pr-feedback-workflow |

---

## Subagent Usage Summary

| Phase | Type | Purpose | Parallel |
|-------|------|---------|----------|
| 1 | Explore (x N) | Complexity analysis (batches of 5) | YES |
| 2 | Explore | TDD plan creation | NO |
| 3 | Background | Continuous test monitoring | YES |
| 5 | Background (x 2) | CI + Review monitors | YES |
| 5 | Explore (x 2) | Code changes + Responses | YES |

**Token efficiency**: Main context handles orchestration; subagents handle all codebase exploration and monitoring.

---

## Quick Start

```bash
# Fix the highest-priority issue
/auto-issue-fixer

# Fix issues with specific label
/auto-issue-fixer --labels bug

# Dry run - analyze without implementing
/auto-issue-fixer --dry-run

# Process up to 3 issues
/auto-issue-fixer --max-issues 3
```

---

## Related Skills

- [fix-github-issue](../fix-github-issue/SKILL.md): Manual issue fixing with worktrees
- [pr-feedback-workflow](../pr-feedback-workflow/SKILL.md): Dedicated PR feedback handling
- [cleanup-issue](../cleanup-issue/SKILL.md): Post-merge cleanup
