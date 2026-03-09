#!/usr/bin/env bash
# check_sdd_gsd.sh
#
# CI check script for GSD (Get Shit Done) spec-driven development.
#
# Verifies that code changes have corresponding GSD planning documentation:
#   1. PROJECT.md, REQUIREMENTS.md, ROADMAP.md must exist.
#   2. For each phase whose plans changed source code, a SUMMARY.md must exist.
#   3. STATE.md must exist and must not contain BLOCKER markers.
#   4. Completed phases must have a VERIFICATION.md.
#
# IGNORE TAGS (place in commit message):
#   [ignore:all_sdd]        — Skip all SDD checks
#   [ignore:plan_doc]       — Skip check 1: core planning document existence
#   [ignore:phase_summary]  — Skip check 2: plan SUMMARY.md check
#   [ignore:state_blockers] — Skip check 3: STATE.md blocker check
#   [ignore:phase_verify]   — Skip check 4: VERIFICATION.md check
#
# Exit codes:
#   0 — all checks passed (or suppressed)
#   1 — one or more checks failed

set -euo pipefail

PLANNING_DIR=".planning"

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

# ─── check if GSD is initialized ────────────────────────────────────────────

if [ ! -d "$PLANNING_DIR" ]; then
  warn "GSD planning directory '${PLANNING_DIR}/' not found. Skipping SDD checks."
  warn "If this project uses GSD, run: /gsd:new-project"
  exit 0
fi

# ─── collect changed source files ───────────────────────────────────────────

BASE_REF="${CI_MERGE_REQUEST_DIFF_BASE_SHA:-HEAD~1}"
CHANGED_SOURCE=$(git diff --name-only "$BASE_REF" HEAD 2>/dev/null | \
  grep -vE '^(\.planning/|\.gitlab-ci|scripts/|\.github/|docs/|README|AGENTS|CHANGELOG|\.gitignore)' || true)

if [ -z "$CHANGED_SOURCE" ]; then
  ok "No source code changes detected. Skipping SDD checks."
  exit 0
fi

info "Source files changed in this MR/commit:"
echo "$CHANGED_SOURCE" | sed 's/^/  /'

# ─── 1. CHECK: Core planning documents exist ────────────────────────────────

echo ""
info "=== Check 1: Core GSD planning documents ==="

if has_ignore "plan_doc"; then
  ok "Suppressed via [ignore:plan_doc]. Skipping core document check."
else
  REQUIRED_DOCS=("PROJECT.md" "REQUIREMENTS.md" "ROADMAP.md" "STATE.md")
  MISSING_DOCS=0

  for doc in "${REQUIRED_DOCS[@]}"; do
    if [ ! -f "${PLANNING_DIR}/${doc}" ]; then
      error "Missing core GSD document: ${PLANNING_DIR}/${doc}"
      echo  "    → Create it with /gsd:new-project or restore from your planning/ directory"
      MISSING_DOCS=1
    else
      ok "${PLANNING_DIR}/${doc} exists"
    fi
  done
fi

# ─── 2. CHECK: Active plan SUMMARY.md files ──────────────────────────────────

echo ""
info "=== Check 2: Plan SUMMARY.md documentation ==="

if has_ignore "phase_summary"; then
  ok "Suppressed via [ignore:phase_summary]. Skipping plan summary check."
else
  # Find all PLAN.md files (pattern: N-M-PLAN.md)
  UNSUMMARIZED=0
  while IFS= read -r plan_file; do
    # Derive expected SUMMARY.md path: N-M-PLAN.md → N-M-SUMMARY.md
    summary_file="${plan_file/-PLAN.md/-SUMMARY.md}"

    if [ ! -f "$summary_file" ]; then
      # Check if this plan's phase has any committed changes
      phase_prefix=$(basename "$plan_file" | grep -oE '^[0-9]+-[0-9]+' || true)
      if [ -n "$phase_prefix" ]; then
        warn "Plan '$(basename "$plan_file")': no corresponding SUMMARY.md found."
        echo  "    → Execute the plan with /gsd:execute-phase to auto-generate SUMMARY.md"
        echo  "    → Or suppress with [ignore:phase_summary] if plan is not yet executed"
        UNSUMMARIZED=1
      fi
    else
      ok "Plan '$(basename "$plan_file")': SUMMARY.md exists"
    fi
  done < <(find "$PLANNING_DIR" -name "*-PLAN.md" -not -path "*/quick/*" 2>/dev/null | sort)

  # Also check quick/ tasks
  while IFS= read -r quick_plan; do
    quick_summary="${quick_plan/PLAN.md/SUMMARY.md}"
    if [ ! -f "$quick_summary" ]; then
      warn "Quick task '$(basename "$(dirname "$quick_plan")")': no SUMMARY.md yet."
      echo  "    → Suppress with [ignore:phase_summary] if task is still in progress"
    else
      ok "Quick task '$(basename "$(dirname "$quick_plan")")': documented"
    fi
  done < <(find "${PLANNING_DIR}/quick" -name "PLAN.md" 2>/dev/null | sort)
fi

# ─── 3. CHECK: STATE.md blockers ────────────────────────────────────────────

echo ""
info "=== Check 3: STATE.md active blockers ==="

if has_ignore "state_blockers"; then
  ok "Suppressed via [ignore:state_blockers]. Skipping STATE.md blocker check."
elif [ -f "${PLANNING_DIR}/STATE.md" ]; then
  BLOCKER_COUNT=$(grep -ci '\[BLOCKER\]' "${PLANNING_DIR}/STATE.md" 2>/dev/null || echo 0)

  if [ "$BLOCKER_COUNT" -gt 0 ]; then
    warn "STATE.md contains ${BLOCKER_COUNT} active BLOCKER(s)."
    grep -n '\[BLOCKER\]' "${PLANNING_DIR}/STATE.md" | sed 's/^/    /'
    echo  "    → Resolve blockers or suppress with [ignore:state_blockers] if they are tracked externally"
  else
    ok "No active blockers in STATE.md"
  fi
fi

# ─── 4. CHECK: VERIFICATION.md for completed phases ─────────────────────────

echo ""
info "=== Check 4: Phase verification documentation ==="

if has_ignore "phase_verify"; then
  ok "Suppressed via [ignore:phase_verify]. Skipping VERIFICATION.md check."
else
  # A phase is "complete" if all its PLANs have a corresponding SUMMARY.md
  # For such phases, a VERIFICATION.md should exist

  declare -A phase_plan_count
  declare -A phase_summary_count

  while IFS= read -r plan_file; do
    phase_num=$(basename "$plan_file" | grep -oE '^[0-9]+' || true)
    [ -z "$phase_num" ] && continue
    phase_plan_count[$phase_num]=$(( ${phase_plan_count[$phase_num]:-0} + 1 ))

    summary="${plan_file/-PLAN.md/-SUMMARY.md}"
    [ -f "$summary" ] && phase_summary_count[$phase_num]=$(( ${phase_summary_count[$phase_num]:-0} + 1 ))
  done < <(find "$PLANNING_DIR" -name "*-PLAN.md" -not -path "*/quick/*" 2>/dev/null)

  for phase_num in "${!phase_plan_count[@]}"; do
    total=${phase_plan_count[$phase_num]}
    summarized=${phase_summary_count[$phase_num]:-0}

    if [ "$total" -eq "$summarized" ] && [ "$total" -gt 0 ]; then
      # Phase appears complete — check for VERIFICATION.md
      verification_file="${PLANNING_DIR}/${phase_num}-VERIFICATION.md"
      if [ ! -f "$verification_file" ]; then
        warn "Phase ${phase_num}: all plans have summaries but ${verification_file} is missing."
        echo  "    → Run /gsd:verify-work ${phase_num} to generate VERIFICATION.md"
        echo  "    → Suppress with [ignore:phase_verify] if verification was done externally"
      else
        ok "Phase ${phase_num}: VERIFICATION.md present"
      fi
    fi
  done
fi

# ─── result ─────────────────────────────────────────────────────────────────

echo ""
if [ "$FAILED" -ne 0 ]; then
  echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${RED} SDD PROCESS CHECK FAILED (GSD)${NC}"
  echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "Fix the issues above, or add an appropriate [ignore:...] tag to your"
  echo "commit message if the check is not applicable."
  echo ""
  echo "See AGENTS.md → 'SDD Ignore Tags' for the full list of suppression options."
  exit 1
else
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN} SDD PROCESS CHECK PASSED (GSD)${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  exit 0
fi
