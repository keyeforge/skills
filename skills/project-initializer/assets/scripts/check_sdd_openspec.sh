#!/usr/bin/env bash
# check_sdd_openspec.sh
#
# CI check script for OpenSpec spec-driven development.
#
# Verifies that code changes have corresponding OpenSpec documentation:
#   1. If changed files touch source code, there must be at least one active change.
#   2. If there is an active change, its tasks.md should not have unfinished tasks
#      (unless suppressed).
#   3. If a change's delta specs haven't been synced to main specs, flag it
#      (unless suppressed).
#
# IGNORE TAGS (place in commit message):
#   [ignore:all_sdd]       — Skip all SDD checks
#   [ignore:spec_sync]     — Skip check 3: delta spec sync check
#   [ignore:task_check]    — Skip check 2: task completion check
#   [ignore:change_doc]    — Skip check 1: active change requirement
#
# Exit codes:
#   0 — all checks passed (or suppressed)
#   1 — one or more checks failed

set -euo pipefail

OPENSPEC_DIR="openspec"
CHANGES_DIR="${OPENSPEC_DIR}/changes"
SPECS_DIR="${OPENSPEC_DIR}/specs"

# ─── helpers ────────────────────────────────────────────────────────────────

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# ─── check if openspec is initialized ───────────────────────────────────────

if [ ! -d "$OPENSPEC_DIR" ]; then
  warn "OpenSpec directory '${OPENSPEC_DIR}/' not found. Skipping SDD checks."
  warn "If this project uses OpenSpec, run: openspec init"
  exit 0
fi

# ─── collect changed source files ───────────────────────────────────────────

# Compare HEAD to the merge base with the target branch (or previous commit)
BASE_REF="${CI_MERGE_REQUEST_DIFF_BASE_SHA:-HEAD~1}"
CHANGED_SOURCE=$(git diff --name-only "$BASE_REF" HEAD 2>/dev/null | \
  grep -vE '^(openspec/|\.gitlab-ci|scripts/|\.github/|docs/|README|AGENTS|CHANGELOG|\.gitignore)' || true)

if [ -z "$CHANGED_SOURCE" ]; then
  ok "No source code changes detected. Skipping SDD checks."
  exit 0
fi

info "Source files changed in this MR/commit:"
echo "$CHANGED_SOURCE" | sed 's/^/  /'

# ─── 1. CHECK: Active change exists ─────────────────────────────────────────

echo ""
info "=== Check 1: Active change documentation ==="

if has_ignore "change_doc"; then
  ok "Suppressed via [ignore:change_doc]. Skipping active-change check."
else
  ACTIVE_CHANGES=()
  if [ -d "$CHANGES_DIR" ]; then
    while IFS= read -r -d '' change_dir; do
      # Skip archive directory
      [[ "$change_dir" == *"/archive/"* ]] && continue
      ACTIVE_CHANGES+=("$(basename "$change_dir")")
    done < <(find "$CHANGES_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
  fi

  if [ ${#ACTIVE_CHANGES[@]} -eq 0 ]; then
    error "No active OpenSpec changes found in '${CHANGES_DIR}/'."
    echo  "  → Source code was changed but there is no accompanying change documentation."
    echo  "  → Create a change with: /opsx:propose <description>"
    echo  "  → Or suppress with: [ignore:change_doc] in commit message (e.g., for pure bug fixes)"
  else
    ok "Active change(s) found: ${ACTIVE_CHANGES[*]}"
  fi
fi

# ─── 2. CHECK: Task completion ───────────────────────────────────────────────

echo ""
info "=== Check 2: Task completion in active changes ==="

if has_ignore "task_check"; then
  ok "Suppressed via [ignore:task_check]. Skipping task completion check."
elif [ -d "$CHANGES_DIR" ]; then
  INCOMPLETE_TASKS_FOUND=0

  while IFS= read -r -d '' tasks_file; do
    change_name=$(basename "$(dirname "$tasks_file")")
    [[ "$tasks_file" == *"/archive/"* ]] && continue

    # Count unchecked tasks: lines starting with "- [ ]"
    UNCHECKED=$(grep -c '^\s*- \[ \]' "$tasks_file" 2>/dev/null || echo 0)

    if [ "$UNCHECKED" -gt 0 ]; then
      warn "Change '${change_name}': ${UNCHECKED} incomplete task(s) in tasks.md"
      echo  "    → Complete tasks or suppress with [ignore:task_check]"
      echo  "    → If tasks are intentionally deferred, add a comment explaining why"
      INCOMPLETE_TASKS_FOUND=1
    else
      ok "Change '${change_name}': all tasks complete"
    fi
  done < <(find "$CHANGES_DIR" -name "tasks.md" -not -path "*/archive/*" -print0 2>/dev/null)

  if [ "$INCOMPLETE_TASKS_FOUND" -eq 0 ] && [ -d "$CHANGES_DIR" ]; then
    # No tasks.md found at all in active changes - might be OK depending on schema
    true
  fi
fi

# ─── 3. CHECK: Delta spec sync status ───────────────────────────────────────

echo ""
info "=== Check 3: Delta spec synchronization ==="

if has_ignore "spec_sync"; then
  ok "Suppressed via [ignore:spec_sync]. Skipping delta spec sync check."
elif [ -d "$CHANGES_DIR" ]; then
  while IFS= read -r -d '' change_spec_dir; do
    change_name=$(basename "$(dirname "$(dirname "$change_spec_dir")")")
    [[ "$change_spec_dir" == *"/archive/"* ]] && continue

    # For each domain in the change's delta specs, check if main spec is missing
    # or if main spec is older than the delta (rough heuristic: delta file was modified after main)
    while IFS= read -r -d '' delta_spec; do
      # Derive relative path from changes/<name>/specs/
      rel_path="${delta_spec#${CHANGES_DIR}/${change_name}/specs/}"
      main_spec="${SPECS_DIR}/${rel_path}"

      if [ ! -f "$main_spec" ]; then
        warn "Change '${change_name}': delta spec '${rel_path}' has no corresponding main spec."
        echo  "    → Run /opsx:sync ${change_name} to merge delta into main specs"
        echo  "    → Suppress with [ignore:spec_sync] if main spec creation is planned later"
      else
        # Compare modification times
        if [ "$delta_spec" -nt "$main_spec" ]; then
          warn "Change '${change_name}': delta spec '${rel_path}' is newer than main spec."
          echo  "    → Delta spec has changed since last sync. Run: /opsx:sync ${change_name}"
          echo  "    → Suppress with [ignore:spec_sync] if this is intentional"
        else
          ok "Change '${change_name}' / '${rel_path}': in sync"
        fi
      fi
    done < <(find "${CHANGES_DIR}/${change_name}/specs" -name "*.md" -print0 2>/dev/null)

  done < <(find "$CHANGES_DIR" -mindepth 2 -maxdepth 2 -type d -name "specs" -not -path "*/archive/*" -print0 2>/dev/null)
fi

# ─── result ─────────────────────────────────────────────────────────────────

echo ""
if [ "$FAILED" -ne 0 ]; then
  echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${RED} SDD PROCESS CHECK FAILED (OpenSpec)${NC}"
  echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "Fix the issues above, or add an appropriate [ignore:...] tag to your"
  echo "commit message if the check is not applicable."
  echo ""
  echo "See AGENTS.md → 'SDD Ignore Tags' for the full list of suppression options."
  exit 1
else
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN} SDD PROCESS CHECK PASSED (OpenSpec)${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  exit 0
fi
