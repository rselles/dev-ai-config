# dev-ai-config

Personal configuration files for AI coding assistants.

## Structure

```
dev-ai-config/
├── AGENTS.md                        # Canonical cross-CLI instructions
├── CLI-HOOK-SPEC.md                 # Tool-agnostic hook contract
├── README.md
├── skills/                          # Cross-CLI custom skills (source of truth)
│   ├── self-correction/SKILL.md
│   ├── agentic-dev-journal/SKILL.md
│   ├── test-driven-development/SKILL.md
│   ├── writing-plans/SKILL.md
│   ├── subagent-driven-dev/SKILL.md
│   ├── brainstorming/SKILL.md
│   └── systematic-debugging/SKILL.md
├── scripts/
│   └── setup-skills.sh              # Symlink installer for all CLIs
├── hooks/                           # Tool-agnostic hook scripts (bash, jq required)
│   ├── pre-run.sh                   # SessionStart: inject tasks/lessons.md
│   ├── pre-commit.sh                # PreToolUse: validate commit message
│   ├── pre-push.sh                  # PreToolUse: advisory before push
│   └── tests/
│       └── test-hooks.sh            # Automated test suite (20 tests)
├── claude/                          # Claude Code-specific config
│   ├── hooks/
│   │   └── settings-fragment.json   # Merge into ~/.claude/settings.json
│   └── skills/
│       └── sync-agents-md/          # Claude-only skill
└── gemini/                          # Gemini CLI-specific config
    └── hooks/
        └── settings-fragment.json   # Merge into ~/.gemini/settings.json
```

## Canonical Instructions (AGENTS.md)

This repo uses a single canonical `AGENTS.md` so all CLIs follow the same rules.

**Why this approach**
- One source of truth reduces drift between assistants.
- Updates are atomic: change one file, all CLIs get the same behavior.
- Project-local `AGENTS.md` is the primary source; home-level symlinks provide a global fallback.

## Tool-Agnostic Guidance

This repo aims to keep instructions and development rules usable across different assistants and CLIs.

Instruction precedence (highest to lowest):
1. Task/session-specific instructions (if any)
2. Project-level instructions (e.g., `AGENTS.md`, `CLAUDE.md`, or agreed local file)
3. Parent-directory instructions (up to the workspace root)
4. Global instructions (home/user-level)

For details, see [`CLI-HOOK-SPEC.md`](CLI-HOOK-SPEC.md), including canonical filenames and discovery scope.

Plans are local-only for public repos (general CLI rule).

For personal projects, `ROADMAP.md` can be public and serves as a single-developer tracker for progress, ideas, improvements, and pending exploration/research.

## Skills

`skills/` contains cross-CLI custom skills — structured workflow instructions that CLIs load and follow when triggered. Skills are tool-agnostic markdown with YAML frontmatter; the same file works across Claude Code, Gemini CLI, Codex CLI, and Google Antigravity.

### Available Skills

| Skill | Trigger | User-invocable |
|-------|---------|----------------|
| `self-correction` | When the user corrects the assistant mid-task | No — fires automatically |
| `agentic-dev-journal` | Significant events: incidents, architectural decisions, new projects, arc closures | Yes (`/agentic-dev-journal`) |
| `test-driven-development` | Before writing any implementation code | Yes (`/test-driven-development`) |
| `writing-plans` | When you have requirements for a multi-step task, before touching code | Yes (`/writing-plans`) |
| `subagent-driven-dev` | When executing implementation plans with independent tasks | Yes (`/subagent-driven-dev`) |
| `brainstorming` | Before any creative work — features, components, functionality changes | Yes (`/brainstorming`) |
| `systematic-debugging` | When encountering any bug, test failure, or unexpected behavior | Yes (`/systematic-debugging`) |

### Key Customisations vs Stock Superpowers Skills

- **Given/When/Then** acceptance criteria format (TDD skill)
- **≥90% coverage target** explicitly enforced (TDD skill)
- **Bug-fix TDD entry point** — bug report IS the AC, skip asking (TDD skill)
- **`tasks/lessons.md`** check at session start and before debugging/implementing (all applicable skills)
- **`TaskCreate`/`TaskUpdate`** for task tracking (not TodoWrite)
- **`docs/plans/`** for plan and spec storage (not `docs/superpowers/`)
- **Repo visibility check** before committing plans: `gh repo view --json isPrivate`
- **Commit messages** use multiple `-m` flags with `Co-Authored-By` (not heredoc/ANSI-C quoting)
- **Mandatory stop after 3 failed fixes** + involve user (debugging skill)
- **agentic-dev-journal integration** for architectural decisions (brainstorming, writing-plans)

### Installing Skills

Run the setup script to create per-skill symlinks into each installed CLI's skill directory:

```bash
bash scripts/setup-skills.sh
```

The script is idempotent — safe to re-run. It detects which CLIs are installed and skips any that aren't present.

To also install into a Google Antigravity project (project-level `.agents/skills/`):

```bash
bash scripts/setup-skills.sh --project /path/to/project
```

### CLI Support Matrix

| Feature | Claude Code | Gemini CLI (v0.26+) | Codex CLI | Antigravity |
|---------|-------------|---------------------|-----------|-------------|
| SKILL.md format | ✅ Native | ✅ Native | As prompts | ✅ Native |
| Skill auto-discovery | ✅ `~/.claude/skills/` | ✅ `~/.gemini/skills/` | ❌ Manual | ✅ `.agents/skills/` |
| User-invocable (`/skill`) | ✅ `Skill` tool | ✅ `activate_skill` | ❌ | ✅ |
| Install type | Symlink dir | Symlink dir | Symlink SKILL.md as `<name>.md` | Symlink dir (project-level) |

### OS-Specific Symlink Notes

The setup script handles symlink creation on Linux/macOS/WSL2. On **Windows native** (CMD), the script does not run — create symlinks manually with `mklink /D`:

```cmd
mklink /D "%USERPROFILE%\.claude\skills\brainstorming" "C:\path\to\dev-ai-config\skills\brainstorming"
REM Repeat for each skill directory
```

### Claude-Only Skills

`claude/skills/sync-agents-md/` is a Claude-only skill not covered by `setup-skills.sh`. Symlink it manually:

```bash
ln -s ~/claude-projects/dev-ai-config/claude/skills/sync-agents-md ~/.claude/skills/sync-agents-md
```

### Gemini: AGENTS.md Context

Add `contextFileName` to `~/.gemini/settings.json` so Gemini loads AGENTS.md as global context:

```json
{
  "contextFileName": "AGENTS.md"
}
```

Also symlink `~/.gemini/AGENTS.md` to the canonical file (see OS Setup section below).

### Coexistence with Superpowers Plugin

Custom skills use the same names as their Superpowers counterparts (`brainstorming`, `test-driven-development`, etc.). Claude Code loads user/project skills with priority over plugin skills, so the custom versions take precedence. Superpowers skills that have no custom counterpart (e.g., `finishing-a-development-branch`, `verification-before-completion`) continue to work normally.

## Programmatic Hooks

Hook scripts in `hooks/` enforce development rules from `CLI-HOOK-SPEC.md` at
the tool level. Scripts are tool-agnostic — the same script runs on any CLI that
supports hooks with a compatible stdin contract.

**Prerequisites:** `bash`, `jq`

### What each hook does

| Hook | Event | Blocking? | Rule enforced |
|---|---|---|---|
| `pre-run.sh` | Session start | No | Injects `tasks/lessons.md` into context if present |
| `pre-commit.sh` | Before bash tool | **Yes** | Blocks commits to `main`/`master`; validates subject ≤50 chars + imperative mood |
| `pre-commit.sh` | Before bash tool | No (advisory) | Reminds to add Co-Authored-By if missing |
| `pre-push.sh` | Before bash tool | No (advisory) | Reminds to confirm tests passed |

### CLI support

| Hook | Claude Code | Gemini CLI (v0.26+) | Codex CLI |
|---|---|---|---|
| Session start (lessons.md) | ✅ | ✅ | — |
| Commit validation (blocking) | ✅ | ✅ | — |
| Push advisory | ✅ | ✅ | — |

Codex CLI's experimental hooks do not support tool blocking. Rules are enforced
there via `AGENTS.md` instructions only.

### Script contract

Scripts read JSON from stdin (provided natively by Claude Code and Gemini CLI):

```jsonc
// SessionStart payload
{ "cwd": "/path/to/project" }

// PreToolUse / BeforeTool payload
{ "tool_input": { "command": "git commit -m '...'" }, "cwd": "..." }
```

- **Exit 0** — proceed. Stdout JSON `{"hookSpecificOutput":{"additionalContext":"..."}}` injects context.
- **Exit 2** — block. Stderr message becomes feedback to the assistant.

### Known limitations

- Commit message parsing supports `-m 'msg'` and `-m "msg"` forms only.
  Does not handle ANSI-C `$'...'` quoting, `--message=`, or multiple `-m` flags.
  Unparseable messages pass through (conservative).
- `pre-run.sh` checks only `$cwd/tasks/lessons.md` — no parent directory walk.
- Gemini CLI tool name matcher (`run_in_terminal|shell`) may need adjustment
  depending on your Gemini CLI version.

## Setup by CLI

**Claude**
- Claude reads `~/.claude/CLAUDE.md`. Point it to the canonical `AGENTS.md`.

**Hooks (optional):** To enable programmatic rule enforcement, merge
`claude/hooks/settings-fragment.json` into `~/.claude/settings.json`.
The fragment adds `SessionStart` and `PreToolUse` hook entries alongside
any existing hooks. Adjust the absolute script paths to match your checkout.

**Codex**
- Codex reads `AGENTS.md` from the repo and/or home. Ensure a home-level `AGENTS.md` symlink for global defaults.

**Hooks:** Codex CLI's hook system (experimental, v0.111+) supports only
`SessionStart` and `Stop` events with no tool blocking. Rules from
`CLI-HOOK-SPEC.md` are enforced via `AGENTS.md` instructions. See
`CLI-HOOK-SPEC.md` for the full hook contract.

**Gemini**
- Configure `contextFileName` to `AGENTS.md` and symlink `~/.gemini/AGENTS.md` to the canonical file.

**Hooks (optional):** Merge `gemini/hooks/settings-fragment.json` into
`~/.gemini/settings.json`. Verify the `BeforeTool` matcher regex matches
your Gemini CLI version's shell tool name.

## OS Setup

**Windows (native, CMD)**
Symlinks require Developer Mode or admin.
```cmd
:: Canonical AGENTS.md (home-level fallback)
mklink "%USERPROFILE%\\AGENTS.md" "C:\\path\\to\\dev-ai-config\\AGENTS.md"

:: Claude
mklink "%USERPROFILE%\\.claude\\CLAUDE.md" "C:\\path\\to\\dev-ai-config\\AGENTS.md"

:: Gemini
mkdir "%USERPROFILE%\\.gemini"
echo { "contextFileName": "AGENTS.md" } > "%USERPROFILE%\\.gemini\\settings.json"
mklink "%USERPROFILE%\\.gemini\\AGENTS.md" "C:\\path\\to\\dev-ai-config\\AGENTS.md"
```

**Windows + WSL2 (Ubuntu, bash)**
Use the WSL Linux home and keep Windows + WSL in sync by pointing both to the same repo path (WSL path).
```bash
# Canonical AGENTS.md (home-level fallback)
ln -s ~/claude-projects/dev-ai-config/AGENTS.md ~/AGENTS.md

# Claude
mkdir -p ~/.claude
ln -s ~/claude-projects/dev-ai-config/AGENTS.md ~/.claude/CLAUDE.md

# Gemini
mkdir -p ~/.gemini
printf '{ "contextFileName": "AGENTS.md" }\n' > ~/.gemini/settings.json
ln -s ~/claude-projects/dev-ai-config/AGENTS.md ~/.gemini/AGENTS.md
```

**macOS / Linux**
```bash
# Canonical AGENTS.md (home-level fallback)
ln -s ~/claude-projects/dev-ai-config/AGENTS.md ~/AGENTS.md

# Claude
mkdir -p ~/.claude
ln -s ~/claude-projects/dev-ai-config/AGENTS.md ~/.claude/CLAUDE.md

# Gemini
mkdir -p ~/.gemini
printf '{ "contextFileName": "AGENTS.md" }\n' > ~/.gemini/settings.json
ln -s ~/claude-projects/dev-ai-config/AGENTS.md ~/.gemini/AGENTS.md
```

## Canonical Content

The `AGENTS.md` file contains development guidelines covering:

- **Decision Hierarchy** - Prioritization when guidance conflicts
- **Technical Advisory Role** - Proactive challenge of decisions and issue identification
- **TDD Philosophy** - Test-driven development as the default workflow
- **Code Standards** - Before/during writing code, definition of done
- **Planning & Execution** - Workflow, plan mode, subagent usage
- **Communication** - When to ask vs proceed autonomously

## License

MIT
