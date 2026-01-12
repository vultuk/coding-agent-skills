---
name: ralph-prompt-generator
description: Generate optimized Ralph Wiggum prompts for Claude Code iterative loops. Use when the user wants to create a Ralph prompt, needs help structuring an iterative task for Claude Code, mentions Ralph Wiggum plugin, or asks for help with /ralph-loop commands. This skill guides through discovery questions AND explores the codebase to generate highly targeted prompts.
---

# Ralph Prompt Generator (Claude Code Edition)

Generate effective prompts for the Ralph Wiggum iterative loop technique, enhanced with actual codebase analysis.

**Codex note:** Codex does not run `/ralph-loop`. In Codex, generate the command text only and do not execute it. Use tool calls (for example `functions.shell_command`) for codebase exploration. See [`../../COMPATIBILITY.md`](../../COMPATIBILITY.md).

## About Ralph

Ralph is a development methodology using a stop hook that intercepts Claude Code exit attempts, feeding the same prompt back repeatedly until a completion promise is detected or max iterations reached.

Command: `/ralph-loop:ralph-loop "<prompt>" --completion-promise "<text>" --max-iterations <n>`

## When Ralph Is Appropriate

**Good fit:**
- Well-defined tasks with clear success criteria
- Tasks with automatic verification (tests, linters, builds)
- Greenfield projects
- Bug fixes with reproducible symptoms
- Refactoring with existing test coverage

**Poor fit:**
- Tasks requiring human judgment or design decisions
- One-shot operations
- Unclear success criteria
- Production debugging without reproduction steps

## Workflow

### Step 1: Discovery Questions

Ask these questions (adapt based on context already provided):

1. **Task Type**: Is this a new feature, bug fix, refactoring, or investigation?
2. **Success Criteria**: How will we know it's done? (tests, build, observable behavior)
3. **Scope Boundaries**: What should NOT be touched?

For **bug fixes** also ask:
- What is the error message or symptom?
- Is it reproducible? How?

For **new features** also ask:
- What are the acceptance criteria?
- Are there similar existing features to reference?

### Step 2: Codebase Exploration

Before generating the prompt, explore the codebase to gather context:

**Always do:**
- List the project structure: `find . -type f -name "*.ts" -o -name "*.rs" -o -name "*.py" | head -50`
- Check for existing tests: `find . -type f -name "*.test.*" -o -name "*.spec.*" | head -20`
- Look at package.json, Cargo.toml, or equivalent for project type
- Check for CI/CD: `.github/workflows/`, `Dockerfile`, etc.

**For bug fixes:**
- Find files likely related to the bug using grep/ripgrep
- Check recent git commits: `git log --oneline -20`
- Look for existing error handling patterns

**For new features:**
- Find similar existing features to use as reference
- Check the schema/types for relevant data structures
- Look at existing API patterns if adding endpoints
- Find where new code should be added

**For refactoring:**
- Check test coverage of affected code
- Identify all files that would need changes
- Look for dependent code

### Step 3: Assess Fit

Based on discovery and codebase exploration, determine:
- Is Ralph appropriate? If not, explain why and suggest alternatives.
- What iteration count is reasonable given scope?
- What are the actual file paths to reference in the prompt?

### Step 4: Generate Prompt

Use the gathered context to create a highly specific prompt with:
- Actual file paths from the codebase
- Real function/class names discovered
- Existing patterns to follow
- Specific test files to run

## Prompt Structure

```
/ralph-loop:ralph-loop "
## Task: [Clear one-line description]

### The Problem
[2-3 sentences with specific context from codebase exploration]

### Key Files
[Actual paths discovered during exploration]
- [path/to/relevant/file.ts] - [why it's relevant]
- [path/to/test/file.test.ts] - [test file to verify]

### [Context Section - varies by task type]
[Investigation steps for bugs, Requirements for features, etc.]
[Reference actual patterns found in the codebase]

### Success Criteria
- [Specific, verifiable criterion using actual test/build commands]
- [Reference actual files that should pass/work]

### If Stuck
After [N] iterations:
- Document what was attempted
- List blocking issues
- Suggest what human input is needed

Output <promise>[COMPLETION_WORD]</promise> when [specific condition].
" --completion-promise "[COMPLETION_WORD]" --max-iterations [N]
```

## Parameter Guidelines

**--max-iterations**:
- Simple bug fixes: 10-15
- Feature implementation: 20-30
- Complex multi-phase work: 30-50
- Investigation/debugging: 15-20

**--completion-promise**:
- Use clear, unique words matching the task
- Examples: FIXED, COMPLETE, IMPLEMENTED, RESOLVED
- Note: Exact string match only

## Output Format

Always output the complete, ready-to-paste command. The user should be able to copy the entire output directly into Claude Code.

Important:
- The completion promise word must exactly match --completion-promise parameter
- Avoid backticks and nested quotes that break the shell
- Put --completion-promise and --max-iterations AFTER the closing quote
- Include ACTUAL file paths discovered during codebase exploration

## Quality Checklist

Before outputting, verify:

- [ ] Explored codebase and found relevant files
- [ ] Prompt references actual file paths (not placeholders)
- [ ] Success criteria uses real test/build commands from the project
- [ ] Iteration limit matches task complexity
- [ ] No shell-breaking characters
- [ ] Fallback instructions included

## Subagent Usage

Use an Explore agent to gather codebase context without bloating main conversation.

### Step 2: Explore Agent for Codebase Analysis

Replace manual exploration commands with a single Explore agent:

```
Launch Explore agent:
"Explore the codebase to gather context for generating a Ralph prompt.

Task description from user: {task_description}

Gather this information:

1. **Project Structure**
   - Main entry points
   - Directory organization
   - Primary language(s)

2. **Testing Infrastructure**
   - Test framework (jest, pytest, go test, etc.)
   - Test file naming pattern (*.test.*, *.spec.*, *_test.*)
   - Test run command (from package.json scripts, Makefile, etc.)
   - Example test file path

3. **Build/CI Configuration**
   - Build command
   - Lint command
   - CI workflow files (.github/workflows/)
   - Dockerfile if present

4. **Task-Relevant Files**
   - Files matching keywords from task description
   - Similar existing implementations
   - Related type definitions
   - Test files for affected areas

5. **Code Patterns**
   - Error handling patterns
   - Logging patterns
   - Common abstractions used

Return structured summary with actual file paths and commands."
```

**Benefits:**
- Single agent replaces 5-10 manual searches
- Exploration output summarized, not dumped into main context
- Agent can be thorough without token pressure
- Main context receives only what's needed for prompt generation

### Using Exploration Results

After agent returns, use the structured data to fill prompt template:

```markdown
### Key Files (from exploration)
- {actual_path_1} - {why_relevant}
- {actual_path_2} - {why_relevant}
- {actual_test_path} - verification

### Success Criteria (from exploration)
- {actual_test_command} passes
- {actual_build_command} succeeds
```

**When to use Explore agent:**
- Unfamiliar codebase
- Task spans multiple areas
- User hasn't provided file paths

**When to skip:**
- User provided specific file paths already
- Small, familiar codebase
- Follow-up prompt in same session (reuse previous exploration)

## Example Codebase-Aware Output

After exploring a TypeScript monorepo with NX:

```
/ralph-loop:ralph-loop "
## Task: Fix depth pricing not applying to aggregated pools

### The Problem
XAUUSD.10lots and XAUUSD.30lots show identical prices to XAUUSD.all.
The depth-walking logic in aggregator-publisher is not being applied.

### Key Files
- apps/aggregator-publisher/src/services/price-calculator.ts - main price logic
- apps/aggregator-publisher/src/services/depth-walker.ts - depth calculation
- apps/portal/src/features/pools/api.ts - pool config API
- libs/shared/types/src/pool.ts - pool type definitions
- apps/aggregator-publisher/src/services/__tests__/price-calculator.test.ts - tests

### Investigation Steps
1. Add logging in price-calculator.ts to trace which code path runs
2. Check if pool.depthConfig is defined when calculatePrice is called
3. Verify depth-walker.ts walkBook function receives correct parameters
4. Check if depth data is available in the price update handler

### Success Criteria
- bun nx test aggregator-publisher passes
- XAUUSD.10lots shows different price than XAUUSD.all when depth varies
- No TypeScript errors: bun nx typecheck aggregator-publisher

### If Stuck
After 15 iterations:
- Document the code path taken during price calculation
- List where depthConfig IS and IS NOT defined
- Identify exact line where fallback to top-of-book occurs

Output <promise>DEPTH_FIXED</promise> when prices correctly differ based on lot size.
" --completion-promise "DEPTH_FIXED" --max-iterations 20
```
