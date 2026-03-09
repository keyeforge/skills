#!/usr/bin/env bash
# check_sdd_speckit.sh
#
# CI check script for SpecKit spec-driven development.
#
# Verifies that code changes have corresponding SpecKit documentation:
#   1. If changed files touch source code, there must be at least one spec directory.
#   2. Any spec.md files must not contain unresolved [NEEDS CLARIFICATION:] markers.
#   3. Any plan.md files must have Phase -1 Pre-Implementation Gates completed.
#   4. tasks.md files must not have unchecked items for a release.
#
# IGNORE TAGS (place in commit message):
#   [ignore:all_sdd]          — Skip all SDD checks
#   [ignore:spec_complete]    — Skip check 2: clarification markers check
#   [ignore:phase_gates]      — Skip check 3: Phase -1 gates check
#   [ignore:task_check]       — Skip check 4: task completion check
#   [ignore:spec_doc]         — Skip check 1: spec existence check
#
# Exit codes:
#   0 — all checks passed (or suppressed)
#   1 — one or more checks failed

set -euo pipefail

SPECS_DIR="specs"
MEMORY_DIR="memory"
CONSTITUTION_FILE="${MEMORY_DIR}/constitution.md"

# ─── helpers ────────────────────────────────────────────────────────────────

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

FAILED=0

error()   { echo -e "${RED}[FAIL]${NC} $*"; FAILED=1; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
ok()      { echo -e "${GREEN}[ OK ]${NC} $*"; }
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }

# ─── read commit message ────────────────────────────────────────────────────

COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")

has_ignore() {
  local tag="$1"
  echo "$COMMIT_MSG" | grep -qi "\[ignore:${tag}\]" || \
  echo "$COMMIT_MSG" | grep -qi "\[ignore:all_sdd\]"
}

# ─── check if speckit is initialized ────────────────────────────────────────

if [ ! -d "$SPECS_DIR" ]; then
  warn "SpecKit specs directory '${SPECS_DIR}/' not found. Skipping SDD checks."
  warn "If this project uses SpecKit, run: specify init . --ai claude"
  exit 0
fi

# ─── collect changed source files ───────────────────────────────────────────

BASE_REF="${CI_MERGE_REQUEST_DIFF_BASE_SHA:-HEAD~1}"
CHANGED_SOURCE=$(git diff --name-only "$BASE_REF" HEAD 2>/dev/null | \
  grep -vE '^(specs/|memory/|\.gitlab-ci|scripts/|\.github/|docs/|README|AGENTS|CHANGELOG|\.gitignore)' || true)

if [ -z "$CHANGED_SOURCE" ]; then
  ok "No source code changes detected. Skipping SDD checks."
  exit 0
fi

info "Source files changed in this MR/commit:"
echo "$CHANGED_SOURCE" | sed 's/^/  /'

# ─── 1. CHECK: Spec directory exists ────────────────────────────────────────

echo ""
info "=== Check 1: Spec documentation exists ==="

if has_ignore "spec_doc"; then
  ok "Suppressed via [ignore:spec_doc]. Skipping spec existence check."
else
  SPEC_DIRS=()
  while IFS= read -r -d '' spec_dir; do
    SPEC_DIRS+=("$(basename "$spec_dir")")
  done < <(find "$SPECS_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

  if [ ${#SPEC_DIRS[@]} -eq 0 ]; then
    error "No spec directories found in '${SPECS_DIR}/'."
    echo  "  → Source code was changed but there is no spec documentation."
    echo  "  → Create a spec with your AI agent: describe the feature, let SpecKit scaffold it."
    echo  "  → Suppress with [ignore:spec_doc] for bug fixes or chores."
  else
    ok "Spec directories found: ${SPEC_DIRS[*]}"
  fi
fi

# ─── 2. CHECK: No unresolved clarification markers ──────────────────────────

echo ""
info "=== Check 2: Unresolved [NEEDS CLARIFICATION:] markers ==="

if has_ignore "spec_complete"; then
  ok "Suppressed via [ignore:spec_complete]. Skipping clarification marker check."
else
  UNRESOLVED=0
  while IFS= read -r spec_file; do
    COUNT=$(grep -c '\[NEEDS CLARIFICATION:' "$spec_file" 2>/dev/null || echo 0)
    if [ "$COUNT" -gt 0 ]; then
      error "File '${spec_file}': ${COUNT} unresolved [NEEDS CLARIFICATION:] marker(s)"
      echo  "    → Resolve all ambiguities before merging to release branch"
      echo  "    → Suppress with [ignore:spec_complete] if deferring is intentional"
      UNRESOLVED=1
    fi
  done < <(find "$SPECS_DIR" -name "spec.md" 2>/dev/null)

  if [ "$UNRESOLVED" -eq 0 ]; then
    ok "No unresolved clarification markers found."
  fi
fi

# ─── 3. CHECK: Phase -1 Pre-Implementation Gates ────────────────────────────

echo ""
info "=== Check 3: Phase -1 Pre-Implementation Gates ==="

if has_ignore "phase_gates"; then
  ok "Suppressed via [ignore:phase_gates]. Skipping Phase -1 gate check."
else
  GATES_FAILED=0
  while IFS= read -r plan_file; do
    spec_name=$(basename "$(dirname "$plan_file")")

    # Check if plan.md contains Phase -1 gate checkboxes
    if ! grep -q 'Phase -1' "$plan_file" 2>/dev/null; then
      warn "Spec '${spec_name}/plan.md': no Phase -1 Pre-Implementation Gates section found."
      echo  "    → Add gate checks as defined in SpecKit's plan.md template"
      continue
    fi

    # Count unchecked gate items (lines with "- [ ]" under Phase -1)
    UNCHECKED_GATES=$(awk '/Phase -1/,/^## /' "$plan_file" | grep -c '^\s*- \[ \]' 2>/dev/null || echo 0)
    if [ "$UNCHECKED_GATES" -gt 0 ]; then
      error "Spec '${spec_name}/plan.md': ${UNCHECKED_GATES} Phase -1 gate(s) not satisfied."
      echo  "    → Complete all pre-implementation gates before merging"
      echo  "    → Gates are: Simplicity (Article VII), Anti-Abstraction (VIII), Integration-First (IX)"
      echo  "    → Suppress with [ignore:phase_gates] if gates don't apply to this change"
      GATES_FAILED=1
    else
      ok "Spec '${spec_name}': Phase -1 gates satisfied"
    fi
  done < <(find "$SPECS_DIR" -name "plan.md" 2>/dev/null)
fi

# ─── 4. CHECK: Task completion ───────────────────────────────────────────────

echo ""
info "=== Check 4: Task completion ==="

if has_ignore "task_check"; then
  ok "Suppressed via [ignore:task_check]. Skipping task completion check."
else
  while IFS= read -r tasks_file; do
    spec_name=$(basename "$(dirname "$tasks_file")")
    UNCHECKED=$(grep -c '^\s*- \[ \]' "$tasks_file" 2>/dev/null || echo 0)

    if [ "$UNCHECKED" -gt 0 ]; then
      warn "Spec '${spec_name}/tasks.md': ${UNCHECKED} unchecked task(s)."
      echo  "    → Complete tasks or use [P] markers to identify parallel tasks"
      echo  "    → Suppress with [ignore:task_check] if tasks are intentionally deferred"
    else
      ok "Spec '${spec_name}': all tasks complete"
    fi
  done < <(find "$SPECS_DIR" -name "tasks.md" 2>/dev/null)
fi

# ─── constitution check (informational) ─────────────────────────────────────

if [ -f "$CONSTITUTION_FILE" ]; then
  ok "Constitution found at ${CONSTITUTION_FILE}"
else
  warn "Constitution file not found at '${CONSTITUTION_FILE}'."
  echo  "    → SpecKit expects a constitution.md in memory/. Run: specify init . --ai claude"
fi

# ─── result ─────────────────────────────────────────────────────────────────

echo ""
if [ "$FAILED" -ne 0 ]; then
  echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${RED} SDD PROCESS CHECK FAILED (SpecKit)${NC}"
  echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "Fix the issues above, or add an appropriate [ignore:...] tag to your"
  echo "commit message if the check is not applicable."
  echo ""
  echo "See AGENTS.md → 'SDD Ignore Tags' for the full list of suppression options."
  exit 1
else
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN} SDD PROCESS CHECK PASSED (SpecKit)${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  exit 0
fi
