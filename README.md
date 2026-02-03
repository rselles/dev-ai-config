# dev-ai-config

Personal configuration files for AI coding assistants.

## Structure

```
dev-ai-config/
├── claude/
│   └── CLAUDE.md    # Claude Code configuration
└── README.md
```

## Claude Code

The `claude/CLAUDE.md` file contains development guidelines for [Claude Code](https://claude.ai/claude-code), covering:

- **Decision Hierarchy** - Prioritization when guidance conflicts
- **Technical Advisory Role** - Proactive challenge of decisions and issue identification
- **TDD Philosophy** - Test-driven development as the default workflow
- **Code Standards** - Before/during writing code, definition of done
- **Planning & Execution** - Workflow, plan mode, subagent usage
- **Communication** - When to ask vs proceed autonomously

### Usage

Copy `claude/CLAUDE.md` to `~/.claude/CLAUDE.md` for global configuration, or to `.claude/CLAUDE.md` in a project root for project-specific settings.

## License

MIT
