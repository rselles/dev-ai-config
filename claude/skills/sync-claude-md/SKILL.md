---
name: sync-claude-md
description: Commit and push any uncommitted changes to the global CLAUDE.md. Use after modifying ~/.claude/CLAUDE.md to keep the remote dev-ai-config repo in sync.
user-invocable: true
---

Sync the global CLAUDE.md to its remote repository.

`~/.claude/CLAUDE.md` is a symlink to `/home/sirrasel/claude-projects/dev-ai-config/claude/CLAUDE.md`.

Steps:
1. Run `git -C /home/sirrasel/claude-projects/dev-ai-config status -- claude/CLAUDE.md` to check for uncommitted changes
2. If there are changes:
   - Run `git -C /home/sirrasel/claude-projects/dev-ai-config diff claude/CLAUDE.md` to review what changed
   - Write a commit message that accurately summarises the changes based on the diff
   - Commit: `git -C /home/sirrasel/claude-projects/dev-ai-config commit claude/CLAUDE.md -m "<message>\n\nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"`
   - Push: `git -C /home/sirrasel/claude-projects/dev-ai-config push`
   - Report what was committed and pushed
3. If no changes: report "CLAUDE.md is already in sync — nothing to commit."
