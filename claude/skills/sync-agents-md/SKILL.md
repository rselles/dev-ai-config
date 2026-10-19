---
name: sync-agents-md
description: Commit and push any uncommitted changes to the canonical AGENTS.md. Use after modifying ~/.claude/CLAUDE.md (symlinked to AGENTS.md) to keep the remote dev-ai-config repo in sync.
user-invocable: true
---

Sync the canonical AGENTS.md to its remote repository.

`~/.claude/CLAUDE.md` is a symlink to `/home/sirrasel/claude-projects/dev-ai-config/AGENTS.md`.

Steps:
1. Run `git -C /home/sirrasel/claude-projects/dev-ai-config status -- AGENTS.md` to check for uncommitted changes
2. If there are changes:
   - Run `git -C /home/sirrasel/claude-projects/dev-ai-config diff AGENTS.md` to review what changed
   - Write a commit message that accurately summarises the changes based on the diff
   - Commit: `git -C /home/sirrasel/claude-projects/dev-ai-config commit AGENTS.md -m "<subject>" -m "<why>" -m "Co-Authored-By: <MODEL> <noreply@PROVIDER>"`
   - Push: `git -C /home/sirrasel/claude-projects/dev-ai-config push`
   - Report what was committed and pushed
3. If no changes: report "AGENTS.md is already in sync — nothing to commit."
