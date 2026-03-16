---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for the codebase and questionable taste. Document everything they need: which files to touch, complete code snippets, exact test commands with expected output. Bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

## Plan Location

**Save plans to:** `docs/plans/<descriptive-name>.md` in the project repo.

**Visibility rule — check before committing:**
```bash
gh repo view --json isPrivate
```
- If repo is **private**: commit and push the plan normally
- If repo is **public** or visibility is unknown: keep plan local-only (unstaged, or add `docs/plans/` to `.gitignore`)

Do NOT save plans to `docs/superpowers/plans/` or `~/.claude/plans/`.

## Scope Check

If the spec covers multiple independent subsystems, suggest breaking into sub-project specs — one per subsystem. Each plan should produce working, testable software on its own.

## Architectural Decision Gate

Before writing the plan, ask: *Does this involve a significant architectural decision?*

Signs it does:
- Choosing between fundamentally different implementation approaches
- Adding or removing a major dependency
- Introducing a new pattern the codebase hasn't used before
- Changing the structure of how components communicate

If yes: flag it. After the plan is written, update the `agentic-dev-journal` using the agentic-dev-journal skill.

## File Structure

Before defining tasks, map out which files will be created or modified. Each file should have one clear responsibility. This informs the task decomposition.

## Bite-Sized Task Granularity

Each step is one action (2-5 minutes):
- "Write the failing test" — step
- "Run it to verify it fails" — step
- "Implement the minimal code to make it pass" — step
- "Run the tests and verify they pass" — step
- "Commit" — step

## Plan Document Header

Every plan MUST start with this header:

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** Use the executing-plans or subagent-driven-dev skill to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "Add specific feature" -m "Why it was needed" -m "Co-Authored-By: <MODEL> <noreply@PROVIDER>"
```
````

## Commit Message Format in Plan Steps

All commit commands in plan steps MUST:
- Use multiple `-m` flags (not heredoc, not ANSI-C `$'...'` quoting)
- Include a `Co-Authored-By` line as the last `-m` flag with the current model and provider
- Use imperative mood for the subject line

```bash
# Correct
git commit -m "Add retry logic" -m "Handles transient failures in the upload path" -m "Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

# Wrong
git commit -m $'Add retry logic\n\nWhy...\n\nCo-Authored-By: ...'
```

## Task Tracking

After writing the plan, create tasks using `TaskCreate` — one task per plan task. Mark tasks `in_progress` before starting each one and `completed` after.

Do not use TodoWrite. Use `TaskCreate`/`TaskUpdate` for all task tracking.

## Remember

- Exact file paths always
- Complete code in the plan (not "add validation here")
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits
- Acceptance criteria in Given/When/Then format

## Execution Handoff

After saving the plan:

**"Plan complete and saved to `docs/plans/<filename>.md`. Ready to execute?"**

If the harness has subagents (Claude Code, etc.): use the subagent-driven-dev skill.
If it does not: use the executing-plans skill.
