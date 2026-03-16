---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code
---

# Test-Driven Development (TDD)

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

## Before Starting: Check Known Patterns

If `tasks/lessons.md` exists in the current project, read it before writing the first test. Known failure patterns often predict where edge cases live.

## When to Use

**Always:**
- New features
- Bug fixes
- Refactoring
- Behavior changes

**Exceptions (ask your human partner):**
- Throwaway prototypes
- Generated code
- Configuration files

Thinking "skip TDD just this once"? Stop. That's rationalization.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

Implement fresh from tests. Period.

## Acceptance Criteria First

Every task needs acceptance criteria before writing tests. If missing:

- **For features:** Ask: "What are the acceptance criteria?" or propose them. Format as:
  ```
  Given [precondition]
  When [action]
  Then [expected outcome]
  ```
- **For bug fixes:** The bug report IS the acceptance criterion. Skip asking — the breakage defines expected behavior.
  - Exception: if the bug is ambiguous, ask for clarification
  - If non-deterministic (race condition, flaky network): fix first, then write a test guarding the fixed state

Each acceptance criterion becomes one or more failing tests.

## Coverage Target

**≥90% coverage is the minimum.** Below 90% is a red flag — untested code is unfinished code.

Follow the test conventions for the language/framework in use:
- Python → pytest
- JavaScript/TypeScript → Jest (or Vitest)
- Go → built-in `go test`
- Ruby → RSpec
- Java/Kotlin → JUnit

When in doubt, check what test runner is already used in the project before introducing a new one.

## Red-Green-Refactor

### RED — Write Failing Test

Write one minimal test showing what should happen.

Requirements:
- One behavior per test
- Clear name describing the behavior
- Real code (no mocks unless genuinely unavoidable)

### Verify RED — Watch It Fail

**MANDATORY. Never skip.**

Run the test. Confirm:
- Test fails (not errors)
- Failure message matches the expected missing behavior
- Fails because feature is missing, not because of a typo

**Test passes?** You're testing existing behavior. Fix the test.

**Test errors?** Fix the error, re-run until it fails correctly.

### GREEN — Minimal Code

Write the simplest code that makes the test pass. No features beyond what the test requires. No speculative abstractions.

### Verify GREEN — Watch It Pass

**MANDATORY.**

Run the test. Confirm:
- Test passes
- All other tests still pass
- No errors or warnings in output

### REFACTOR — Clean Up

After green only:
- Remove duplication
- Improve names
- Extract helpers

Keep tests green. Don't add behavior.

### Repeat

Next failing test for the next acceptance criterion.

## Bug Fix Entry Point

Bug reports have a different TDD flow:

1. **Investigate first:** Read the code, reproduce the bug, find the root cause
2. **Write a failing test** that reproduces the bug at the right abstraction level
3. **Fix** — make the test pass
4. Regression test now exists permanently

Do NOT ask for acceptance criteria for bugs. The bug report IS the spec.

## Good Tests

| Quality | Good | Bad |
|---------|------|-----|
| **Minimal** | One thing. "and" in name? Split it. | `test('validates email and domain and whitespace')` |
| **Clear** | Name describes behavior | `test('test1')` |
| **Shows intent** | Demonstrates desired API | Obscures what code should do |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "TDD will slow me down" | TDD is faster than debugging. |

## Red Flags — STOP and Start Over

- Code before test
- Test passes immediately without implementation
- Can't explain why test failed
- Tests added "later"
- Rationalizing "just this once"
- Coverage below 90% at completion

**All of these mean: Delete code. Start over with TDD.**

## When Stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test | Write the wished-for API. Write assertion first. Ask your human partner. |
| Test too complicated | Design too complicated. Simplify the interface. |
| Must mock everything | Code too coupled. Use dependency injection. |
| Test setup huge | Extract helpers. Still complex? Simplify the design. |

## Verification Checklist

Before marking work complete:

- [ ] Every new function/method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for the expected reason (feature missing, not a typo)
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass
- [ ] Output pristine (no errors, warnings)
- [ ] Tests use real code (mocks only if unavoidable)
- [ ] Edge cases and errors covered
- [ ] Coverage ≥90%
- [ ] Acceptance criteria each have corresponding tests

Can't check all boxes? You skipped TDD. Start over.
