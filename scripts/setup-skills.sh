#!/usr/bin/env bash
# setup-skills.sh — Install cross-CLI skill symlinks
#
# Usage:
#   bash scripts/setup-skills.sh
#   bash scripts/setup-skills.sh --project /path/to/antigravity-project
#
# Creates per-skill symlinks from dev-ai-config/skills/ into each installed CLI's
# skill directory. Idempotent — safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd "$SCRIPT_DIR/../skills" && pwd)"
PROJECT_DIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--project /path/to/antigravity-project]" >&2
      exit 1
      ;;
  esac
done

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
SKIP='\033[0;90m'
NC='\033[0m'

created=0
skipped=0
errors=0

make_symlink() {
  local src="$1"
  local dest="$2"
  local dest_dir
  dest_dir="$(dirname "$dest")"

  if [[ ! -d "$dest_dir" ]]; then
    mkdir -p "$dest_dir"
  fi

  if [[ -L "$dest" ]]; then
    # Already a symlink — check if it points to the right place
    if [[ "$(readlink "$dest")" == "$src" ]]; then
      echo -e "  ${SKIP}skip${NC}  $dest (already linked)"
      ((skipped++)) || true
      return
    else
      echo -e "  ${YELLOW}update${NC} $dest (was pointing elsewhere)"
      rm "$dest"
    fi
  elif [[ -e "$dest" ]]; then
    echo -e "  ${YELLOW}skip${NC}  $dest (exists as real file — remove manually to replace)" >&2
    ((errors++)) || true
    return
  fi

  ln -s "$src" "$dest"
  echo -e "  ${GREEN}link${NC}   $dest -> $src"
  ((created++)) || true
}

install_for_cli() {
  local cli_name="$1"
  local skills_target_dir="$2"
  local mode="$3"   # "dir" or "file"

  echo ""
  echo "[$cli_name] -> $skills_target_dir"

  for skill_dir in "$SKILLS_DIR"/*/; do
    local skill_name
    skill_name="$(basename "$skill_dir")"
    local skill_file="${skill_dir%/}/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
      echo -e "  ${YELLOW}warn${NC}  $skill_name: no SKILL.md found, skipping"
      continue
    fi

    if [[ "$mode" == "dir" ]]; then
      # Symlink the entire skill directory (Claude Code, Gemini CLI, Antigravity)
      make_symlink "$skill_dir" "$skills_target_dir/$skill_name"
    else
      # Symlink just the SKILL.md as <name>.md (Codex CLI)
      make_symlink "$skill_file" "$skills_target_dir/${skill_name}.md"
    fi
  done
}

# ── Claude Code ──────────────────────────────────────────────────────────────
if [[ -d "$HOME/.claude" ]]; then
  install_for_cli "Claude Code" "$HOME/.claude/skills" "dir"
else
  echo ""
  echo "[Claude Code] ~/.claude/ not found — skipping"
fi

# ── Gemini CLI ───────────────────────────────────────────────────────────────
if [[ -d "$HOME/.gemini" ]]; then
  install_for_cli "Gemini CLI" "$HOME/.gemini/skills" "dir"
else
  echo ""
  echo "[Gemini CLI] ~/.gemini/ not found — skipping"
fi

# ── Codex CLI ────────────────────────────────────────────────────────────────
if [[ -d "$HOME/.codex" ]]; then
  install_for_cli "Codex CLI" "$HOME/.codex/prompts" "file"
else
  echo ""
  echo "[Codex CLI] ~/.codex/ not found — skipping"
fi

# ── Google Antigravity (project-level) ───────────────────────────────────────
if [[ -n "$PROJECT_DIR" ]]; then
  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo ""
    echo "[Antigravity] ERROR: --project path does not exist: $PROJECT_DIR" >&2
    ((errors++)) || true
  else
    install_for_cli "Antigravity" "$PROJECT_DIR/.agents/skills" "dir"
  fi
fi

# ── Validate all symlinks ────────────────────────────────────────────────────
echo ""
echo "Validating symlinks..."
broken=0
for link in \
  "$HOME/.claude/skills"/*/ \
  "$HOME/.gemini/skills"/*/ \
  "$HOME/.codex/prompts"/*.md \
  ; do
  [[ -e "$link" ]] || continue
  if [[ -L "$link" ]] && [[ ! -e "$link" ]]; then
    echo -e "  ${YELLOW}BROKEN${NC} $link -> $(readlink "$link")"
    ((broken++)) || true
  fi
done

if [[ $broken -eq 0 ]]; then
  echo -e "  ${GREEN}All symlinks valid${NC}"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "Done. Created: $created  Skipped: $skipped  Errors: $errors  Broken: $broken"
if [[ $errors -gt 0 ]] || [[ $broken -gt 0 ]]; then
  exit 1
fi
