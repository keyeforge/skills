#!/usr/bin/env pwsh
# check_sdd_speckit.ps1
#
# PowerShell equivalent of check_sdd_speckit.sh
# Works on Windows, macOS, and Linux with PowerShell 7+.
#
# IGNORE TAGS (commit message):
#   [ignore:all_sdd]          — Skip all SDD checks
#   [ignore:spec_complete]    — Skip [NEEDS CLARIFICATION:] marker check
#   [ignore:phase_gates]      — Skip Phase -1 gate check
#   [ignore:task_check]       — Skip task completion check
#   [ignore:spec_doc]         — Skip spec existence check
#
# Exit codes: 0 = passed, 1 = failed

param()
$ErrorActionPreference = 'Continue'

$SPECS_DIR       = "specs"
$MEMORY_DIR      = "memory"
$CONSTITUTION    = Join-Path $MEMORY_DIR "constitution.md"
$script:Failed   = $false

function Write-Ok($msg)   { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:Failed = $true }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }

function Invoke-Git([string]$Arguments) {
    try {
        $parts = $Arguments -split '\s+'
        return (& git @parts 2>$null | Out-String).Trim()
    } catch { return "" }
}

function Test-Ignore([string]$Tag) {
    $lower = $commitMsg.ToLower()
    return ($lower -match "\[ignore:$Tag\]") -or ($lower -match "\[ignore:all_sdd\]")
}

$commitMsg = Invoke-Git "log -1 --pretty=%B"

# ── SpecKit initialized? ─────────────────────────────────────────────────────
if (-not (Test-Path $SPECS_DIR)) {
    Write-Warn "SpecKit specs directory '$SPECS_DIR/' not found. Skipping SDD checks."
    Write-Warn "If this project uses SpecKit, run: specify init . --ai claude"
    exit 0
}

# ── Changed source files ─────────────────────────────────────────────────────
$baseRef = if ($env:CI_MERGE_REQUEST_DIFF_BASE_SHA) { $env:CI_MERGE_REQUEST_DIFF_BASE_SHA } else { "HEAD~1" }
$excludePattern = '^(specs/|memory/|\.gitlab-ci|\.github/|scripts/|docs/|README|AGENTS|CHANGELOG|\.gitignore)'
$changedSource = (Invoke-Git "diff --name-only $baseRef HEAD") -split "`n" |
    Where-Object { $_ -and $_ -notmatch $excludePattern }

if (-not $changedSource) {
    Write-Ok "No source code changes detected. Skipping SDD checks."
    exit 0
}

Write-Info "Source files changed in this MR/commit:"
$changedSource | ForEach-Object { Write-Host "  $_" }

# ── Check 1: Spec directory exists ───────────────────────────────────────────
Write-Host ""
Write-Info "=== Check 1: Spec documentation exists ==="

if (Test-Ignore "spec_doc") {
    Write-Ok "Suppressed via [ignore:spec_doc]. Skipping spec existence check."
} else {
    $specDirs = Get-ChildItem -Path $SPECS_DIR -Directory -ErrorAction SilentlyContinue

    if (-not $specDirs) {
        Write-Fail "No spec directories found in '$SPECS_DIR/'."
        Write-Host "  -> Source code was changed but there is no spec documentation."
        Write-Host "  -> Create a spec with your AI agent using SpecKit."
        Write-Host "  -> Suppress with [ignore:spec_doc] for bug fixes or chores."
    } else {
        Write-Ok "Spec directories found: $(($specDirs.Name) -join ', ')"
    }
}

# ── Check 2: No unresolved [NEEDS CLARIFICATION:] markers ────────────────────
Write-Host ""
Write-Info "=== Check 2: Unresolved [NEEDS CLARIFICATION:] markers ==="

if (Test-Ignore "spec_complete") {
    Write-Ok "Suppressed via [ignore:spec_complete]. Skipping clarification marker check."
} else {
    Get-ChildItem -Path $SPECS_DIR -Recurse -Filter "spec.md" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $specFile = $_.FullName
            $count = (Select-String -Path $specFile -Pattern '\[NEEDS CLARIFICATION:' | Measure-Object).Count
            if ($count -gt 0) {
                Write-Fail "File '$($_.FullName)': $count unresolved [NEEDS CLARIFICATION:] marker(s)"
                Write-Host "    -> Resolve all ambiguities before merging to release branch"
                Write-Host "    -> Suppress with [ignore:spec_complete] if deferring is intentional"
            }
        }

    if (-not $script:Failed) {
        Write-Ok "No unresolved clarification markers found."
    }
}

# ── Check 3: Phase -1 Pre-Implementation Gates ───────────────────────────────
Write-Host ""
Write-Info "=== Check 3: Phase -1 Pre-Implementation Gates ==="

if (Test-Ignore "phase_gates") {
    Write-Ok "Suppressed via [ignore:phase_gates]. Skipping Phase -1 gate check."
} else {
    Get-ChildItem -Path $SPECS_DIR -Recurse -Filter "plan.md" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $planFile   = $_.FullName
            $specName   = Split-Path (Split-Path $planFile) -Leaf
            $planContent = Get-Content $planFile -Raw -ErrorAction SilentlyContinue

            if (-not ($planContent -match 'Phase -1')) {
                Write-Warn "Spec '$specName/plan.md': no Phase -1 Pre-Implementation Gates section found."
                Write-Host "    -> Add gate checks as defined in SpecKit's plan.md template"
                return
            }

            # Count unchecked gate items between 'Phase -1' and the next '## ' heading
            $gateSection = [regex]::Match($planContent, 'Phase -1[\s\S]*?(?=^## |\z)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            $unchecked   = ([regex]::Matches($gateSection.Value, '^\s*- \[ \]', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count

            if ($unchecked -gt 0) {
                Write-Fail "Spec '$specName/plan.md': $unchecked Phase -1 gate(s) not satisfied."
                Write-Host "    -> Complete all pre-implementation gates before merging"
                Write-Host "    -> Suppress with [ignore:phase_gates] if gates don't apply"
            } else {
                Write-Ok "Spec '$specName': Phase -1 gates satisfied"
            }
        }
}

# ── Check 4: Task completion ──────────────────────────────────────────────────
Write-Host ""
Write-Info "=== Check 4: Task completion ==="

if (Test-Ignore "task_check") {
    Write-Ok "Suppressed via [ignore:task_check]. Skipping task completion check."
} else {
    Get-ChildItem -Path $SPECS_DIR -Recurse -Filter "tasks.md" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $tasksFile = $_.FullName
            $specName  = Split-Path (Split-Path $tasksFile) -Leaf
            $unchecked = (Select-String -Path $tasksFile -Pattern '^\s*- \[ \]' | Measure-Object).Count

            if ($unchecked -gt 0) {
                Write-Warn "Spec '$specName/tasks.md': $unchecked unchecked task(s)."
                Write-Host "    -> Complete tasks or suppress with [ignore:task_check]"
            } else {
                Write-Ok "Spec '$specName': all tasks complete"
            }
        }
}

# ── Constitution (informational) ─────────────────────────────────────────────
if (Test-Path $CONSTITUTION) {
    Write-Ok "Constitution found at $CONSTITUTION"
} else {
    Write-Warn "Constitution file not found at '$CONSTITUTION'."
    Write-Host "    -> SpecKit expects a constitution.md in memory/. Run: specify init . --ai claude"
}

# ── Result ───────────────────────────────────────────────────────────────────
Write-Host ""
if ($script:Failed) {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host " SDD PROCESS CHECK FAILED (SpecKit)" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fix the issues above, or add an appropriate [ignore:...] tag to your commit message."
    Write-Host "See AGENTS.md -> 'SDD Ignore Tags' for the full list."
    exit 1
} else {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " SDD PROCESS CHECK PASSED (SpecKit)" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    exit 0
}
