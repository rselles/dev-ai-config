# CLI Hook Spec

## Goal
Provide a common, cross-CLI hook contract so any assistant can enforce the same development rules consistently.

## Instruction Discovery

### Canonical Instruction Files
Assistants must discover instructions by walking up from the project root to the workspace root (inclusive), stopping there. At each directory level, check for these filenames in order:
- `AGENTS.md`
- `CLAUDE.md`
- `INSTRUCTIONS.md`

If multiple instruction files exist at the same directory depth, apply the most conservative rule when they conflict.

Global (home/user-level) instruction files follow the same filename list and are loaded last (lowest precedence).

### Workspace and Project Roots (Tool-Agnostic)
- **Workspace root**: The nearest ancestor directory that contains a VCS marker (e.g., `.git/`) or an explicit tool-defined root. Traversal stops here.
- **Project root**: The specific root that contains the file(s) being acted on.
- **Multi-root workspaces**: If multiple roots apply, select the closest project root to the active file. If ambiguity remains, ask the user to choose.

### Instruction Precedence
The discovery (proximity) rule and the precedence list operate on different axes — proximity governs file location; the list governs instruction type. Both apply:

Order of precedence (highest → lowest):
1. Task/session-specific instructions (injected by the user mid-session)
2. Project-level instructions (nearest `AGENTS.md` / `CLAUDE.md` / `INSTRUCTIONS.md`)
3. Parent-directory instructions (up to the workspace root)
4. Global instructions (home/user-level)

When instructions conflict at the same level, the more specific (closest) file wins. If two rules conflict at the same level and depth, follow the safer / more conservative option.

## Hook Event Ordering

Hooks fire in this sequence when applicable:

```
pre_run → pre_plan → pre_write → pre_commit → pre_push → post_run
```

Not every hook fires for every task. Each hook fires only when its trigger condition is met.

## Hook Events

### pre_run
Fires at the start of a session or before processing a task.

Required actions:
- Discover instruction files from project root to workspace root and load them in precedence order.
- If `tasks/lessons.md` exists at the project root or any parent up to the workspace root, load it before proceeding.
- If project visibility is unknown and a plan is required, default to keeping the plan local.

### pre_plan
Fires when a task touches 3+ files or introduces a new architectural pattern.

Required actions:
- Require a plan before any code changes.
- Store the plan in the repo unless the repo is public or visibility is unknown; if public/unknown, keep it local-only.

### pre_write
Fires before any **code** change is applied. Does not apply to documentation-only or configuration-only changes.

Required actions:
- Require acceptance criteria unless the user explicitly waives (`skip_acceptance_criteria`).
- Enforce TDD default: require a failing test before implementation unless the user explicitly waives (`skip_tdd`).
- If a **new external service or vendor SDK** is introduced (i.e., a dependency not already present in the project that could reasonably be swapped), require an abstraction layer unless explicitly exempted.

### pre_commit
Fires before `git commit`.

Required actions:
- Enforce commit message rules (imperative mood, ≤ 50 chars subject).
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
- If the user corrected the assistant, append an entry to `tasks/lessons.md` in this format:
  ```
  ## <short rule title>
  **Rule:** <one sentence stating what to do or avoid>
  **Why:** <the reason the user gave or the incident that surfaced it>
  ```

## Standard Waiver Flags
To proceed when a policy should not apply, the user must explicitly confirm one of:
- `skip_tdd`
- `skip_acceptance_criteria`
- `skip_tests`
- `skip_coverage`
- `skip_plan`

Waivers are scoped to the current task and should be recorded in the session log.

## Non-Hook Guidance (Advisory Only)
The following are policy suggestions and should not be enforced as hard hooks:
- Challenging architectural choices
- Identifying anti-patterns and observability gaps
- Subagent usage guidance
