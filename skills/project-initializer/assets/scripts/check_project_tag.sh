#!/usr/bin/env bash
# check_project_tag.sh
#
# Verifies that AGENTS.md contains a valid @project-initializer identity tag.
#
# This tag is written by the project-initializer skill when the project is
# first scaffolded. Its presence confirms:
#   - The project was properly initialized (not just a hand-crafted AGENTS.md)
#   - The CI system knows which SDD framework and quality level apply
#   - The metadata is available for framework-specific checks
#
# IGNORE TAGS (commit message):
#   [ignore:project_tag]  — Skip this check (use only when intentionally
#                           migrating a legacy project to project-initializer)
#   [ignore:all_sdd]      — Skips all SDD and process checks including this one
#
# Exit codes:
#   0 — tag found and valid (or suppressed)
#   1 — tag missing or malformed

set -euo pipefail

AGENTS_FILE="AGENTS.md"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── read commit message ────────────────────────────────────────────────────

COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")

has_ignore() {
  local tag="$1"
  echo "$COMMIT_MSG" | grep -qi "\[ignore:${tag}\]" || \
  echo "$COMMIT_MSG" | grep -qi "\[ignore:all_sdd\]"
}

echo -e "${BLUE}[INFO]${NC} Checking AGENTS.md for @project-initializer identity tag..."

# ─── suppress check ─────────────────────────────────────────────────────────

if has_ignore "project_tag"; then
  echo -e "${YELLOW}[WARN]${NC} Suppressed via [ignore:project_tag]. Skipping identity tag check."
  echo "       This is only appropriate when migrating a legacy project."
  exit 0
fi

# ─── file existence ──────────────────────────────────────────────────────────

if [ ! -f "$AGENTS_FILE" ]; then
  echo -e "${RED}[FAIL]${NC} AGENTS.md not found in project root."
  echo "  → Run the project-initializer skill to create AGENTS.md"
  exit 1
fi

# ─── tag presence ───────────────────────────────────────────────────────────

if ! grep -q '<!-- @project-initializer' "$AGENTS_FILE"; then
  echo -e "${RED}[FAIL]${NC} AGENTS.md is missing the @project-initializer identity tag."
  echo ""
  echo "  The tag must be the first content in AGENTS.md and look like:"
  echo ""
  echo "    <!-- @project-initializer"
  echo "    version: 1"
  echo "    initialized_at: YYYY-MM-DD"
  echo "    sdd_framework: openspec|speckit|gsd"
  echo "    quality_level: demo|production"
  echo "    ci_platforms: gitlab|github|gitlab,github"
  echo "    project_initializer_version: 1.0.0"
  echo "    -->"
  echo ""
  echo "  → Re-run the project-initializer skill to add this tag, or add it manually."
  echo "  → Suppress with [ignore:project_tag] only when intentionally migrating a legacy project."
  exit 1
fi

# ─── required fields ─────────────────────────────────────────────────────────

# Extract the comment block
TAG_BLOCK=$(awk '/<!-- @project-initializer/,/-->/' "$AGENTS_FILE" | head -20)

check_field() {
  local field="$1"
  local pattern="$2"
  local value
  value=$(echo "$TAG_BLOCK" | grep -oP "(?<=^${field}: ).+" 2>/dev/null | head -1 || true)

  if [ -z "$value" ]; then
    echo -e "${RED}[FAIL]${NC} Tag field '${field}' is missing from AGENTS.md @project-initializer block."
    return 1
  fi

  if [ -n "$pattern" ] && ! echo "$value" | grep -qE "$pattern"; then
    echo -e "${RED}[FAIL]${NC} Tag field '${field}' has unexpected value: '${value}'"
    echo "         Expected pattern: ${pattern}"
    return 1
  fi

  echo -e "${GREEN}[ OK ]${NC} Tag field '${field}': ${value}"
  return 0
}

FIELD_ERRORS=0

check_field "version"    "^[0-9]+$"                          || FIELD_ERRORS=1
check_field "initialized_at" "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" || FIELD_ERRORS=1
check_field "sdd_framework"  "^(openspec|speckit|gsd)$"      || FIELD_ERRORS=1
check_field "quality_level"  "^(demo|production)$"           || FIELD_ERRORS=1
check_field "ci_platforms"   "^(gitlab|github|gitlab,github|github,gitlab)$" || FIELD_ERRORS=1

# ─── result ──────────────────────────────────────────────────────────────────

echo ""
if [ "$FIELD_ERRORS" -ne 0 ]; then
  echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
  echo -e "${RED} PROJECT TAG CHECK FAILED${NC}"
  echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "Fix the missing or invalid fields in the @project-initializer block"
  echo "at the top of AGENTS.md, then push again."
  exit 1
else
  echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN} PROJECT TAG CHECK PASSED${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
  exit 0
fi
