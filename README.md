# dev-ai-config

Personal configuration files for AI coding assistants.

## Structure

```
dev-ai-config/
├── AGENTS.md            # Canonical cross-CLI instructions
├── claude/
│   └── CLAUDE.md          # Compatibility symlink to AGENTS.md
├── CLI-HOOK-SPEC.md       # Tool-agnostic hook contract
└── README.md
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

## Setup by CLI

**Claude**
- Claude reads `~/.claude/CLAUDE.md`. Point it to the canonical `AGENTS.md`.

**Codex**
- Codex reads `AGENTS.md` from the repo and/or home. Ensure a home-level `AGENTS.md` symlink for global defaults.

**Gemini**
- Configure `contextFileName` to `AGENTS.md` and symlink `~/.gemini/AGENTS.md` to the canonical file.

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
