---
name: agentic-dev-journal
description: Record significant events — architectural decisions, service incidents, new project starts, or arc closures — to the agentic-dev-journal repo. Use when a notable event occurs that future-you needs to know about.
user-invocable: true
---

# Agentic Dev Journal

Record significant events to the `agentic-dev-journal` repo. Routine plans go in `docs/plans/`. This journal is for events that matter at the arc level.

## When to Use

Update the journal for:
- **Service incident** — ArguIAno down, API retired, VPS issue, data loss
- **Architectural decision** — build vs buy, model swap, new pattern adopted, major dependency choice
- **New project starts** — when a new project gets its first real investment of effort
- **Arc closure** — a project phase, major feature, or initiative concludes

Do NOT update for:
- Routine feature work
- Bug fixes
- Plan documents for features (those go in `docs/plans/`)
- Daily/session summaries

## Project Context (accuracy check)

Before writing, verify you're describing projects accurately:
- **ArguIAno** — in active use, ~2 users, personal/hobby project
- **TravelFlow** — MVP under market validation, free-tier Vercel, no paying users yet
- **recetario-cli** — experimental/development, not in regular use
- **MCP Orchestrator** — experimental/development

Do not overstate scale or users. "Production" is a high bar — ArguIAno barely qualifies.

## Event-Type Guidance

### Incident
Timeline entry documenting what happened, when, and the resolution.

Files to update:
- `timeline.md` — add a dated entry
- Relevant `arcs/<project>.md` — add incident section
- Optional: `snapshots/incidents/YYYY-MM-DD-<description>.md` for detailed post-mortems

Entry format for `timeline.md`:
```markdown
### YYYY-MM-DD — <Incident Title>
**What:** <One sentence describing the failure>
**Impact:** <Who/what was affected and for how long>
**Resolution:** <What fixed it>
**Lesson:** <What to do differently>
```

### Architectural Decision
Record a decision that shapes how the project is built.

Files to update:
- `snapshots/decisions/YYYY-MM-DD-<decision-slug>.md` — full decision record
- `timeline.md` — brief entry linking to the decision file

Decision file format:
```markdown
# Decision: <Title>
**Date:** YYYY-MM-DD
**Project:** <project name>
**Status:** accepted

## Context
<What situation led to this decision>

## Decision
<What was decided>

## Alternatives considered
<What else was evaluated and why it was rejected>

## Consequences
<Expected trade-offs and outcomes>
```

### New Project
Record that a project exists and what it's for.

Files to update:
- `README.md` — add row to the projects table
- `timeline.md` — add dated entry: "Started <project>"
- Optional: create `arcs/<project>.md` if the project has multiple planned phases

### Arc Closure
Mark a project phase or initiative as complete.

Files to update:
- `arcs/<project>.md` — update status, add conclusion section
- `timeline.md` — add dated entry marking the closure

## Commit and Push

After writing:
1. Stage only the files you changed
2. Commit with a clear message describing the event type and subject:
   ```
   git -C <journal-repo-path> add <files>
   git -C <journal-repo-path> commit -m "record: <event type> — <subject>" -m "<one sentence summary>" -m "Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
   git -C <journal-repo-path> push
   ```
3. Report the commit SHA and what was recorded

## Article Drafting

When writing a blog post or article:

**Always produce both versions in the same session:**
1. `drafts/NN-<slug>-medium.md` — full article (3,000–5,000 words)
2. `drafts/NN-<slug>-linkedin.md` — condensed LinkedIn version (~700–800 words)

The LinkedIn version is not a summary — it's a standalone post. It hooks the reader, hits the 3–4 most important points, and ends with a link to the full article. Same conversational, first-person tone. Use `---` dividers and bold section labels.

Naming convention: `NN` is the next sequential number in `drafts/`. Check existing files before numbering.

After both drafts exist, commit both in one commit:
```
git -C <journal-repo-path> add drafts/
git -C <journal-repo-path> commit -m "draft: article NN — <slug>" -m "<one-line description>" -m "Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

## Finding the Journal Repo

The journal lives in a separate git repo called `agentic-dev-journal`. Locate it relative to known project directories (e.g., `~/claude-projects/agentic-dev-journal/`) or ask the user for the path if unknown.
