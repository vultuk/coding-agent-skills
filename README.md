# Claude Code Skills

A collection of custom skills for Claude Code that automate common development workflows.

## Skills

### fix-github-issue

Load a GitHub issue, create an isolated worktree, plan the implementation, and submit a PR.

**Example prompts:**
- "Fix issue #123"
- "Implement GitHub issue 456"
- "Work on issue #78"

**Workflow:**
1. Creates isolated git worktree for the issue
2. Fetches issue context (description, comments, labels)
3. Explores codebase and creates implementation plan
4. Implements changes after confirmation
5. Commits and opens PR with proper issue linking

### pr-feedback-workflow

Process all PR feedback in one pass - review comments and CI failures together.

**Example prompts:**
- "Address the PR feedback"
- "Fix the review comments"
- "Handle the CI failures on this PR"
- "Process the PR reviews"

**Workflow:**
1. Gathers all review comments and CI failure logs
2. Categorizes feedback (code fix, explanation needed, out of scope)
3. Creates unified action plan
4. Applies fixes, replies to reviewers, resolves threads
5. Posts summary comment

### cleanup-issue

Clean up after an issue PR is merged.

**Example prompts:**
- "Clean up issue #123"
- "Finish up the issue"
- "The PR was approved, clean up"

**Workflow:**
1. Merges PR if approved but not yet merged
2. Removes the worktree
3. Deletes the local branch
4. Updates main branch
5. Starts fresh session

### code-audit

Perform comprehensive code audits and generate structured reports.

**Example prompts:**
- "Audit this codebase"
- "Review the code quality"
- "Check for security issues"
- "Generate a code audit report"

**Analysis categories:**
- Architecture and component structure
- Bugs and race conditions
- SOLID/DRY violations
- Security vulnerabilities
- Performance issues

**Output:** Markdown report with severity-prioritized recommendations (P0-P3) and optional GitHub issue creation.

### race-condition-audit

Systematic identification of race conditions and concurrency bugs.

**Example prompts:**
- "Find race conditions in this code"
- "Audit the concurrent code"
- "Check for thread safety issues"
- "Look for data races"

**Supports:** TypeScript, JavaScript, Python, Go, Rust, C++

**Detects:**
- Check-then-act races
- Read-modify-write without atomics
- Lazy initialization races
- Deadlocks and lock ordering issues
- Collection mutation during iteration
- Async/await races

## Requirements

- Claude Code CLI
- GitHub CLI (`gh`) authenticated for GitHub-related skills
- Git

## Installation

These skills are automatically available when placed in `~/.claude/skills/`.
