# CLI Hook Spec (Draft)

## Goal
Provide a common, cross-CLI hook contract so any assistant can enforce the same development rules consistently.

## Instruction Discovery

### Canonical Instruction Files
Assistants must discover instructions in this order of proximity (nearest wins), using the following filenames:
- `AGENTS.md`
- `CLAUDE.md`
- `INSTRUCTIONS.md`
- `.claude/CLAUDE.md`

If multiple instruction files exist at the same directory depth, apply the most conservative rule when they conflict.

### Workspace and Project Roots (Tool-Agnostic)
- **Workspace root**: The nearest ancestor directory that contains a VCS marker (e.g., `.git/`) or an explicit tool-defined root.
- **Project root**: The specific root that contains the file(s) being acted on.
- **Multi-root workspaces**: If multiple roots apply, select the closest project root to the active file. If ambiguity remains, ask the user to choose.

### Instruction Precedence
Order of precedence (highest → lowest):
1. Task/session-specific instructions (if any)
2. Project-level instructions (e.g., `AGENTS.md`, `CLAUDE.md`, or agreed local file)
3. Parent-directory instructions (up to the workspace root)
4. Global instructions (home/user-level)

When instructions conflict, the more specific (closest) file overrides broader rules. If two rules conflict at the same level, follow the safer / more conservative option.

## Hook Events

### pre_run
Fires at the start of a session or before processing a task.

Required actions:
- Discover instruction files in the workspace and load them in precedence order.
- If `tasks/lessons.md` exists in the project root, load it before proceeding.
- If project visibility is unknown and a plan is required, default to keeping the plan local.

### pre_plan
Fires when a task is large or architectural.

Required actions:
- If task touches 3+ files or introduces a new pattern, require a plan before code changes.
- If a plan is created, store it in the repo unless the repo is public or visibility is unknown. If public/unknown, keep it local-only.

### pre_write
Fires before any code change is applied.

Required actions:
- Require acceptance criteria unless the user explicitly waives this requirement.
- Enforce TDD default: require a failing test before implementation unless the user explicitly waives TDD.
- If new vendor SDK usage is introduced, require an abstraction layer unless explicitly exempted.

### pre_commit
Fires before `git commit`.

Required actions:
- Enforce commit message rules (imperative mood, <= 50 chars subject).
- Warn or block if changes appear to mix unrelated concerns.
- Warn or block if code changes lack matching tests unless TDD is explicitly waived.

### pre_push
Fires before `git push`.

Required actions:
- Require test suite run and pass status if the project defines tests.
- Require coverage threshold (if defined) or warn if not checked.

### post_run
Fires after task completion.

Required actions:
- If the user corrected the assistant, append a prevention rule to `tasks/lessons.md`.

## Standard Waiver Flags
To proceed when policy should not apply, user must explicitly confirm:
- `skip_tdd`
- `skip_acceptance_criteria`
- `skip_tests`
- `skip_coverage`

Waivers are scoped to the current task and should be recorded in the session log.

## Non-Hook Guidance (Advisory Only)
The following are policy suggestions and should not be enforced as hard hooks:
- Challenging architectural choices
- Identifying anti-patterns and observability gaps
- Subagent usage guidance
