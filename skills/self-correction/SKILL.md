---
name: self-correction
description: Fires when the user corrects the assistant — redirects, says "no not that", or changes the approach mid-task. Records the lesson and applies the pattern going forward.
user-invocable: false
---

# Self-Correction

## When This Applies

A user correction has just occurred. Signs:
- "No, not that — do X instead"
- "Stop, that's wrong"
- "Actually, let me redirect you"
- Any explicit redirect or correction of your approach

## Process

### Step 1: Acknowledge the correction

Confirm you understand what was wrong without being defensive or over-apologetic.

### Step 2: Identify root cause

Ask: *Why did I take the wrong approach?*

Common root causes:
- Misread or skipped a requirement
- Applied a default pattern without checking context
- Didn't read existing code before suggesting changes
- Made an assumption instead of asking
- Ignored a guideline from AGENTS.md or tasks/lessons.md

### Step 3: Identify the preventive pattern

State clearly: *"The pattern that would have prevented this is: [rule]"*

Format it as a testable rule — something future-you can check before acting.

### Step 4: Append to tasks/lessons.md

If `tasks/lessons.md` exists in the current project, append the lesson. If the file doesn't exist, create it.

Append in this format:

```markdown
## <Short Rule Title>
**Rule:** <One sentence — what to do or avoid>
**Why:** <The correction that prompted this, or the incident>
```

Example:

```markdown
## Read existing code before suggesting modifications
**Rule:** Always read the relevant file(s) before proposing any change to them.
**Why:** Suggested renaming a method that didn't exist in the codebase — hadn't read the file first.
```

Keep entries atomic: one rule per block. Do not edit existing entries.

### Step 5: Apply the pattern now

Continue the task using the corrected approach. Do not repeat the mistake.

## What NOT to do

- Do not over-apologize or produce long self-criticism
- Do not skip the lesson capture ("it won't happen again" without writing it down)
- Do not restate the full history of what went wrong — one sentence is enough
- Do not create tasks/lessons.md outside the current project directory
