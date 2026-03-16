---
name: subagent-driven-dev
description: Use when executing implementation plans with independent tasks in the current session
---

# Subagent-Driven Development

Execute a plan by dispatching a fresh subagent per task, with two-stage review after each: spec compliance first, then code quality.

**Core principle:** Fresh subagent per task + two-stage review (spec then quality) = high quality, fast iteration.

## Before Starting

1. **Never start on main/master** without explicit user consent. Create a feature branch first.
2. **Check `tasks/lessons.md`** in the current project. Read it before dispatching the first implementer — known failure patterns predict where edge cases live.
3. **Create tasks** with `TaskCreate` — one per plan task. Use `TaskUpdate` to mark `in_progress` before dispatching and `completed` after review passes. Do not use TodoWrite.

## The Process

### For Each Task

1. Mark task `in_progress` with `TaskUpdate`
2. Read `tasks/lessons.md` (if it exists) and include any relevant lessons in the implementer's context
3. Dispatch implementer subagent with:
   - Full task text (extracted from plan — do NOT make subagent read the plan file)
   - Project context (what this task is part of, how it fits in)
   - Relevant lessons from `tasks/lessons.md`
   - Feature branch name to work on
4. Handle implementer status:
   - **DONE:** Proceed to spec compliance review
   - **DONE_WITH_CONCERNS:** Read concerns before proceeding. If they affect correctness, address first. If observations only, note and proceed.
   - **NEEDS_CONTEXT:** Provide missing context, re-dispatch
   - **BLOCKED:** Assess — provide context, upgrade model, break task smaller, or escalate to user
5. Dispatch spec compliance reviewer
   - If issues found: implementer fixes, re-review. Repeat until ✅
6. Dispatch code quality reviewer (only after spec compliance ✅)
   - If issues found: implementer fixes, re-review. Repeat until ✅
7. Mark task `completed` with `TaskUpdate`

### Lessons Capture in Review Loops

If a reviewer finds a pattern-level issue (not just a typo), after the fix:
- Check if this would be useful to remember in future sessions
- If yes: append to `tasks/lessons.md` in this format:
  ```markdown
  ## <Short Rule Title>
  **Rule:** <One sentence — what to do or avoid>
  **Why:** <The issue the reviewer found>
  ```

### After All Tasks

Dispatch a final code reviewer for the entire implementation, then use the finishing-a-development-branch skill.

## Model Selection

- **Mechanical tasks** (isolated functions, complete spec, 1-2 files): use a fast/cheap model
- **Integration tasks** (multi-file coordination, pattern matching): use a standard model
- **Architecture, design, review tasks**: use the most capable available model

## Commit Messages

All commits from implementer subagents must use multiple `-m` flags:

```bash
git commit -m "Add feature" -m "Why it was needed" -m "Co-Authored-By: <MODEL> <noreply@PROVIDER>"
```

Never use heredoc or ANSI-C `$'...'` quoting for commit messages.

## Red Flags

**Never:**
- Start on main/master branch without explicit user consent
- Skip reviews (spec compliance OR code quality)
- Proceed with unfixed issues
- Dispatch multiple implementers in parallel (causes conflicts)
- Make subagent read the plan file (provide the full task text instead)
- Accept "close enough" on spec compliance
- Skip re-review after fixes

**If subagent asks questions:** Answer clearly and completely before letting them proceed.

**If subagent is BLOCKED:** Something must change. Don't re-dispatch the same model with no changes.
