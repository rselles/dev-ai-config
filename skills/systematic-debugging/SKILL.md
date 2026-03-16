---
name: systematic-debugging
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
---

# Systematic Debugging

## Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## Before Starting: Check Known Patterns

If `tasks/lessons.md` exists in the current project, read it before investigating. A known pattern may describe this exact failure mode and save significant investigation time.

## When to Use

Use for ANY technical issue:
- Test failures
- Bugs in production
- Unexpected behavior
- Performance problems
- Build failures
- Integration issues

**Use this ESPECIALLY when:**
- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes
- Previous fix didn't work
- You don't fully understand the issue

## The Four Phases

You MUST complete each phase before proceeding to the next.

### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

1. **Read Error Messages Carefully**
   - Don't skip past errors or warnings
   - Read stack traces completely
   - Note line numbers, file paths, error codes

2. **Reproduce Consistently**
   - Can you trigger it reliably?
   - What are the exact steps?
   - If not reproducible → gather more data, don't guess

3. **Check Recent Changes**
   - What changed that could cause this?
   - Git diff, recent commits
   - New dependencies, config changes, environmental differences

4. **Gather Evidence in Multi-Component Systems**

   When the system has multiple components, add diagnostic instrumentation at each boundary before proposing fixes:
   ```
   For EACH component boundary:
     - Log what data enters
     - Log what data exits
     - Verify environment/config propagation
     - Check state at each layer

   Run once to gather evidence showing WHERE it breaks.
   THEN analyze evidence to identify the failing component.
   THEN investigate that specific component.
   ```

5. **Trace Data Flow**
   - Where does the bad value originate?
   - What called this with the bad value?
   - Keep tracing up until you find the source
   - Fix at source, not at symptom

### Phase 2: Pattern Analysis

**Find the pattern before fixing:**

1. Find similar working code in the same codebase
2. Compare against references — read completely, not skimming
3. List every difference between working and broken, however small
4. Understand what other components, config, or assumptions this depends on

### Phase 3: Hypothesis and Testing

**Scientific method:**

1. Form a single hypothesis: "I think X is the root cause because Y"
2. Make the smallest possible change to test it — one variable at a time
3. Verify: Did it work?
   - Yes → Phase 4
   - No → Form a NEW hypothesis (don't stack fixes)

When you don't know: say so. Ask for help. Don't pretend.

### Phase 4: Implementation

**Fix the root cause, not the symptom:**

1. **Create failing test case first** — use the test-driven-development skill for writing proper failing tests
2. **Implement single fix** — one change at a time, no bundled refactoring
3. **Verify fix** — test passes, no regressions, issue actually resolved

4. **If fix doesn't work:**
   - STOP
   - Count: How many fixes have you tried?
   - If < 3: Return to Phase 1 with new information
   - **If ≥ 3: MANDATORY STOP — question the architecture (see below)**
   - Do NOT attempt fix #4 without architectural discussion

5. **If 3+ fixes failed — question the architecture:**

   Signs of an architectural problem:
   - Each fix reveals new shared state/coupling/problem in a different place
   - Fixes require "massive refactoring" to implement
   - Each fix creates new symptoms elsewhere

   **STOP. Do not attempt another fix autonomously.** Present the situation to the user:
   - What you've tried (3 attempts)
   - The pattern you're seeing
   - Your hypothesis about what's architecturally wrong
   - Options for how to proceed

   Wait for guidance. This is not a failure — it's the right response to a structural problem.

## After a Successful Fix: Capture the Lesson

Once the fix is confirmed working, ask: *Is this a novel pattern worth remembering?*

Signs it is:
- The bug was subtle or non-obvious
- The root cause was a general class of mistake (not a one-off typo)
- Future-you would benefit from knowing this pattern

If yes: append to `tasks/lessons.md`:
```markdown
## <Short Rule Title>
**Rule:** <One sentence — what to do or avoid>
**Why:** <The bug or incident that surfaced this>
```

## Red Flags — STOP and Follow Process

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "One more fix attempt" (when you've already tried 2+)
- Each fix reveals a new problem in a different place

**ALL of these mean: STOP. Return to Phase 1.**

**If 3+ fixes failed:** Stop and question the architecture. Involve the user. Do not attempt fix #4.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
| "I'll write test after confirming fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question pattern, don't fix again. |

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Root Cause** | Read errors, reproduce, check changes, gather evidence | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare | Identify differences |
| **3. Hypothesis** | Form theory, test minimally | Confirmed or new hypothesis |
| **4. Implementation** | Create test, fix, verify | Bug resolved, tests pass, lesson captured |
