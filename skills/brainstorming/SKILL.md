---
name: brainstorming
description: "Use before any creative work — creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
---

# Brainstorming Ideas Into Designs

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design and get user approval.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

## Anti-Pattern: "This Is Too Simple To Need A Design"

Every project goes through this process. A todo list, a single-function utility, a config change — all of them. "Simple" projects are where unexamined assumptions cause the most wasted work. The design can be short (a few sentences for truly simple projects), but you MUST present it and get approval.

## Checklist

Complete these in order:

1. **Explore project context** — check files, docs, recent commits
2. **Check architectural significance** — does this involve a new architectural pattern? (see Architectural Decision Gate below)
3. **Ask clarifying questions** — one at a time, understand purpose/constraints/success criteria
4. **Propose 2-3 approaches** — with trade-offs and your recommendation
5. **Present design** — in sections scaled to their complexity, get user approval after each section
6. **Write design doc** — save to `docs/plans/YYYY-MM-DD-<topic>-design.md`
7. **Check repo visibility** before committing: `gh repo view --json isPrivate`
   - Private repo: commit the design doc
   - Public or unknown: keep local-only (unstaged, or add `docs/plans/` to `.gitignore`)
8. **User reviews written spec** — ask user to review before proceeding
9. **Transition to implementation** — invoke the writing-plans skill

## Architectural Decision Gate

Before asking clarifying questions, assess: *Is this designing a new architectural pattern for this codebase?*

Signs it is:
- Introducing a fundamentally different way components interact
- Choosing between build vs. buy for a key capability
- Adopting a new model or service that replaces an existing one
- Establishing a pattern that future work will follow

If yes: flag it during the design phase. After the design is approved and written, use the agentic-dev-journal skill to record the decision.

## Scale Guidance for Personal Projects

This workspace contains personal/small-scale projects. Keep that context in designs:
- **ArguIAno** — personal tool, ~2 users. Don't design for thousands of users.
- **TravelFlow** — MVP, free-tier Vercel, no paying users yet. Don't design for enterprise scale.
- **recetario-cli, MCP Orchestrator** — experimental. Prefer simplicity over robustness.

Ruthlessly apply YAGNI. A feature that works for 2 users doesn't need a queue.

## The Process

**Understanding the idea:**
- Check the current project state first (files, docs, recent commits)
- Assess scope: if the request describes multiple independent subsystems, flag and decompose first
- Ask questions one at a time
- Prefer multiple choice questions when possible
- Focus on: purpose, constraints, success criteria

**Exploring approaches:**
- Propose 2-3 different approaches with trade-offs
- Lead with your recommended option and explain why
- For personal projects: lean toward the simpler option unless there's a compelling reason not to

**Presenting the design:**
- Present the design once you understand what you're building
- Scale each section to its complexity
- Ask after each section if it looks right
- Cover: architecture, components, data flow, error handling, testing

## After the Design

**Write the spec** to `docs/plans/YYYY-MM-DD-<topic>-design.md` (not `docs/superpowers/specs/`).

**Check visibility:**
```bash
gh repo view --json isPrivate
```
Commit only if the repo is private.

**User review gate:**
> "Spec written to `docs/plans/<filename>.md`. Please review it and let me know if you want changes before we start the implementation plan."

Wait for user approval. If they request changes, update and re-check.

**Then:** Invoke the writing-plans skill to create the implementation plan.

## Key Principles

- **One question at a time** — don't overwhelm
- **Multiple choice preferred** — easier than open-ended when possible
- **YAGNI ruthlessly** — personal projects especially
- **Explore alternatives** — always propose 2-3 approaches
- **Incremental validation** — present design, get approval, then proceed
