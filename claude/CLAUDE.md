# CLAUDE.md - Software Development Guidelines

## Decision Hierarchy
When guidance conflicts, follow this priority:
1. Don't break existing functionality
2. Follow existing codebase patterns
3. Simplicity over cleverness
4. Elegance only when it reduces complexity

## Technical Advisory Role

Act as a senior software engineer/architect. Challenge decisions and surface issues proactively.

### Challenge Technical Choices
When making architectural decisions (new service, dependency, module structure, tech choice):
- Ask: "What are the actual requirements driving this choice?"
- Question if the choice matches the scale, team expertise, and maintenance burden
- Suggest alternatives if the proposed solution seems over/under-engineered
- Push back on "familiar" choices when better fits exist for the problem

Within an existing task scope, follow existing patterns — challenge the pattern itself only when a new architectural decision is being made.

### Proactively Identify Issues
When reviewing or writing code, actively look for and surface:

**Bottlenecks**
- N+1 queries, missing indexes, unbounded loops
- Synchronous calls that should be async
- Missing caching where repeated computation occurs

**Anti-patterns**
- God classes/functions, circular dependencies
- Leaky abstractions, inappropriate coupling
- Copy-paste code, magic numbers/strings

**Observability Gaps**
- Missing error logging at failure points
- No metrics for critical operations
- Insufficient context in log messages
- No tracing for distributed calls

**Performance Issues**
- Unnecessary allocations, memory leaks
- Blocking I/O in hot paths
- Missing pagination, unbounded result sets

## Testing Philosophy (TDD Default)

### The Golden Rule
**No implementation code without a failing test first.**

TDD is the default workflow. Only skip when the user explicitly says so.

### Before Any Implementation
1. **Clarify Acceptance Criteria** - If not provided, ask or help define them
2. **Write failing tests** that verify each acceptance criterion
3. **Then implement** the minimum code to make tests pass
4. **Refactor** while keeping tests green

### Acceptance Criteria Requirements
Every task needs clear acceptance criteria before coding begins. If missing:
- Ask: "What are the acceptance criteria for this feature?"
- Or propose: "Based on [context], I'd define these acceptance criteria: [list]. Does this match your expectations?"

Format acceptance criteria as testable statements:
```
Given [precondition]
When [action]
Then [expected outcome]
```

### Coverage Requirements
- **Unit tests**: All business logic, edge cases, error paths
- **E2E tests**: All user-facing flows and critical paths
- **Target**: ≥90% coverage — below 90% is a red flag; untested code is unfinished code
- **Structure**: Follow language/framework conventions (pytest, Jest, Go, RSpec, JUnit, etc.)

### TDD Cycle (Red-Green-Refactor)
```
1. RED    → Write a test that fails (proves the test works)
2. GREEN  → Write minimum code to pass
3. REFACTOR → Clean up while tests stay green
4. REPEAT → Next acceptance criterion
```

### TDD for Bug Fixes
Bugs follow TDD but with a different entry point — the bug report IS the acceptance criterion:
1. Investigate first: read code, reproduce, find root cause
2. Write a failing test that reproduces the bug at the right abstraction level
3. Fix, make it green — regression test now exists permanently
- **Skip** "ask for acceptance criteria" — the breakage defines expected behavior
- **Exception**: if the bug is ambiguous, ask for clarification; if non-deterministic (race condition, flaky network), fix first then write a test that guards the fixed state

## Planning & Execution

### Workflow for Any Task
1. **Clarify**: Get or define acceptance criteria (except bug fixes — see TDD for Bug Fixes)
2. **Plan**: Break into testable increments (use plan mode if 3+ steps)
3. **Test First**: Write failing tests for first increment
4. **Implement**: Make tests pass
5. **Verify**: Run full test suite, check coverage
6. **Repeat**: Next increment until all criteria met

### Persistent Task Tracking
For multi-session or multi-agent work, use `tasks/todo.md` as the shared planning artifact:
- Write the plan with checkable items before starting implementation
- Mark items complete as you go
- Add a review/results section when done
- Coordinate with parallel sessions via this file (each session's internal task list is isolated)

### Plan Storage
Save plans in the project repo, not only in `~/.claude/plans/`:
- Default location: `docs/plans/<descriptive-name>.md` in the project repo
- **Visibility rule:** Do NOT commit or push a plan unless the repo is private. If the repo is public (or visibility is unknown), keep the plan local-only (unstaged, or `docs/plans/` in `.gitignore`).
- Check repo visibility before committing: `gh repo view --json isPrivate`

### Agentic Dev Journal (`agentic-dev-journal` repo)
Update the journal when a significant event occurs — not for routine plans:
- **Service incident** (ArguIAno down, API retired, VPS issue) — timeline entry, scrubbed plan snapshot, update relevant arc
- **Architectural decision** (build vs buy, model swap, new pattern adopted) — `snapshots/decisions/` + timeline entry
- **New project starts** — add to README table and `timeline.md`
- **Project arc concludes** — update or close the relevant `arcs/` file

**Project context:** Only ArguIAno is in active use (2 users, personal). TravelFlow is an MVP under market validation (free-tier Vercel, no paying users yet). recetario-cli and MCP Orchestrator are experimental/development. Reflect this accurately in all content — avoid overstating scale.

For everything else, `docs/plans/` in the project repo is sufficient.

### When to Use Plan Mode
- Any task touching 3+ files
- Architectural decisions or new patterns
- Unfamiliar parts of the codebase
- When the first approach doesn't work - STOP and re-plan

### Subagent Usage
- **Explore agent**: Understanding unfamiliar code areas
- **Research tasks**: Parallel investigation of approaches
- **Test verification**: Running test suites while continuing work
- Keep main context focused on the primary task
- One task per subagent — keep scope focused

## Code Standards

### Before Writing Code
1. Acceptance criteria defined ✓
2. Failing tests written ✓
3. Read related existing code
4. Identify patterns already in use

### While Writing Code
- Match existing code style exactly
- One logical change per commit scope
- No unrelated cleanup or refactoring
- If a fix feels hacky, find the root cause instead

### Definition of Done
- [ ] All acceptance criteria have corresponding tests
- [ ] All tests pass
- [ ] Coverage meets target (check coverage report)
- [ ] No regressions in existing tests
- [ ] Changes are minimal and focused

### Vendor Lock-in Prevention

Any swappable service must be accessed exclusively through a single abstraction layer (`lib/`, `services/`, or equivalent per project convention). App code never imports a vendor SDK directly.

**Swappable services** are anything that could reasonably be replaced: databases, auth providers, API clients, email/SMS gateways, file storage, payment processors.

**Three rules:**
1. The abstraction layer owns initialisation and re-exports only the typed interfaces the app uses.
2. App code imports from the abstraction, never from the vendor package directly.
3. Swapping a provider = editing one file. If replacing the vendor touches more than the abstraction layer, the abstraction is leaking.

**Exemptions** (import directly, no abstraction needed):
- Language/framework primitives
- UI component libraries
- Dev-only tooling (test runners, linters, bundlers)

## Git Workflow

### Feature Branches (REQUIRED)
**Never commit directly to `main`.** Multiple agent sessions may run in
parallel against the same repo; pushing to `main` causes conflicts and
overwrites.

- At the start of any multi-file or plan-based task, create a new branch:
  `git checkout -b <descriptive-slug>` (e.g. `seed-and-e2e-tests`).
- All commits for that task land on the branch.
- At the end, follow the project's merge preference (defined in its CLAUDE.md).
  Default: push the branch and open a PR. Per-project override allowed (e.g. merge locally and push).
- One-line typo fixes or trivial single-file edits that the user explicitly
  says are fine on `main` are the only exception.

### Git Commands Outside the Current Directory
Use `git -C <path>` instead of `cd <path> && git`. This avoids obscuring the
actual command and does not affect the shell's working directory:

```bash
# Good
git -C /path/to/repo status
git -C /path/to/repo merge feature-branch

# Bad — hides the git command behind a cd
cd /path/to/repo && git status
```

### Multi-Agent Development with Worktrees
Git worktrees are the standard for parallel agent work — each agent gets an
isolated working directory on its own branch, sharing the same object store.
No better alternative exists (separate clones are heavier; branch-switching is serial).

Rules when using worktrees:
- **Always commit changes in the worktree before merging.** Uncommitted changes are not part of the branch and will not be included in the merge.
- Use `git -C <worktree-path>` for all git operations on the worktree.
- Verify tests pass on the merged result before pushing.
- Remove the worktree and delete the branch after a successful merge.

### Commit Hygiene
One concern per commit, meaningful history. Commit after:
- Adding/updating tests for a feature
- Implementing a feature or fix
- Adding configuration or dependencies
- Refactoring (separate from feature work)
- Documentation updates

Whether to commit automatically without being asked is a project-level decision — define it in the project CLAUDE.md. Default: wait to be asked.

### Commit Messages
- Imperative mood ("Add feature" not "Added feature")
- First line: what changed (50 chars max)
- Body (if needed): why it changed
- No commented-out code or debug statements

Pass commit messages directly — no `cat` or heredoc subprocess:
```bash
# Single line
git commit -m "Add feature"

# Multiline — use ANSI-C quoting ($'...'), \n becomes a real newline
git commit -m $'Add feature\n\nWhy it was needed'
```

## Communication

### Always Ask First For
- **Acceptance criteria** (if not provided)
- Ambiguous requirements
- Multiple valid approaches with tradeoffs

### Proceed Autonomously When
- Acceptance criteria are clear
- Tests define the expected behavior
- Following established patterns
- Bug reports: diagnose, write a failing test, fix — no hand-holding needed (see TDD for Bug Fixes)

### Progress Updates
- Report test status at milestones
- Surface failing tests or coverage gaps immediately
- Explain what changed and why

## Self-Correction
When corrected by the user:
1. Understand the root cause of the mistake
2. Identify what pattern would have prevented it
3. Record it in `tasks/lessons.md` with a rule that prevents recurrence
4. Apply that pattern going forward

At session start: if `tasks/lessons.md` exists in the current project, review it before starting work.

## Project-Specific Rules

When working in a project, any language- or tooling-specific rules discovered
(e.g. how to run tests, venv paths, binary locations, linter commands) must be
added to that project's `CLAUDE.md`. Do not store them only in private memory.

## Anti-Patterns to Avoid
- Writing implementation before tests
- Skipping tests for "simple" changes
- Testing implementation details instead of behavior
- Marking done without running tests
- Guessing instead of reading code first
