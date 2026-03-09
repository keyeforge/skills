#!/usr/bin/env pwsh
# check_sdd_gsd.ps1
#
# PowerShell equivalent of check_sdd_gsd.sh
# Works on Windows, macOS, and Linux with PowerShell 7+.
#
# IGNORE TAGS (commit message):
#   [ignore:all_sdd]        — Skip all SDD checks
#   [ignore:plan_doc]       — Skip core planning document existence check
#   [ignore:phase_summary]  — Skip plan SUMMARY.md check
#   [ignore:state_blockers] — Skip STATE.md blocker check
#   [ignore:phase_verify]   — Skip VERIFICATION.md check
#
# Exit codes: 0 = passed, 1 = failed

param()
$ErrorActionPreference = 'Continue'

$PLANNING_DIR  = ".planning"
$script:Failed = $false

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

# ── GSD initialized? ─────────────────────────────────────────────────────────
if (-not (Test-Path $PLANNING_DIR)) {
    Write-Warn "GSD planning directory '$PLANNING_DIR/' not found. Skipping SDD checks."
    Write-Warn "If this project uses GSD, run: /gsd:new-project"
    exit 0
}

# ── Changed source files ─────────────────────────────────────────────────────
$baseRef = if ($env:CI_MERGE_REQUEST_DIFF_BASE_SHA) { $env:CI_MERGE_REQUEST_DIFF_BASE_SHA } else { "HEAD~1" }
$excludePattern = '^(\.planning/|\.gitlab-ci|\.github/|scripts/|docs/|README|AGENTS|CHANGELOG|\.gitignore)'
$changedSource = (Invoke-Git "diff --name-only $baseRef HEAD") -split "`n" |
    Where-Object { $_ -and $_ -notmatch $excludePattern }

if (-not $changedSource) {
    Write-Ok "No source code changes detected. Skipping SDD checks."
    exit 0
}

Write-Info "Source files changed in this MR/commit:"
$changedSource | ForEach-Object { Write-Host "  $_" }

# ── Check 1: Core planning documents ─────────────────────────────────────────
Write-Host ""
Write-Info "=== Check 1: Core GSD planning documents ==="

if (Test-Ignore "plan_doc") {
    Write-Ok "Suppressed via [ignore:plan_doc]. Skipping core document check."
} else {
    @("PROJECT.md", "REQUIREMENTS.md", "ROADMAP.md", "STATE.md") | ForEach-Object {
        $docPath = Join-Path $PLANNING_DIR $_
        if (-not (Test-Path $docPath)) {
            Write-Fail "Missing core GSD document: $docPath"
            Write-Host "    -> Create it with /gsd:new-project or restore from your planning/ directory"
        } else {
            Write-Ok "$docPath exists"
        }
    }
}

# ── Check 2: Plan SUMMARY.md files ───────────────────────────────────────────
Write-Host ""
Write-Info "=== Check 2: Plan SUMMARY.md documentation ==="

if (Test-Ignore "phase_summary") {
    Write-Ok "Suppressed via [ignore:phase_summary]. Skipping plan summary check."
} else {
    # Main phase plans
    Get-ChildItem -Path $PLANNING_DIR -Filter "*-PLAN.md" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[/\\]quick[/\\]' } |
        ForEach-Object {
            $planFile    = $_.FullName
            $summaryFile = $planFile -replace '-PLAN\.md$', '-SUMMARY.md'
            if (-not (Test-Path $summaryFile)) {
                Write-Warn "Plan '$($_.Name)': no corresponding SUMMARY.md found."
                Write-Host "    -> Execute the plan with /gsd:execute-phase to auto-generate SUMMARY.md"
                Write-Host "    -> Suppress with [ignore:phase_summary] if plan is not yet executed"
            } else {
                Write-Ok "Plan '$($_.Name)': SUMMARY.md exists"
            }
        }

    # Quick tasks
    $quickDir = Join-Path $PLANNING_DIR "quick"
    if (Test-Path $quickDir) {
        Get-ChildItem -Path $quickDir -Recurse -Filter "PLAN.md" -ErrorAction SilentlyContinue |
            ForEach-Object {
                $taskSlug    = Split-Path (Split-Path $_.FullName) -Leaf
                $summaryFile = Join-Path (Split-Path $_.FullName) "SUMMARY.md"
                if (-not (Test-Path $summaryFile)) {
                    Write-Warn "Quick task '$taskSlug': no SUMMARY.md yet."
                    Write-Host "    -> Suppress with [ignore:phase_summary] if still in progress"
                } else {
                    Write-Ok "Quick task '$taskSlug': documented"
                }
            }
    }
}

# ── Check 3: STATE.md blockers ────────────────────────────────────────────────
Write-Host ""
Write-Info "=== Check 3: STATE.md active blockers ==="

$stateFile = Join-Path $PLANNING_DIR "STATE.md"
if (Test-Ignore "state_blockers") {
    Write-Ok "Suppressed via [ignore:state_blockers]. Skipping STATE.md blocker check."
} elseif (Test-Path $stateFile) {
    $blockerLines = Select-String -Path $stateFile -Pattern '\[BLOCKER\]' -CaseSensitive:$false
    $count = ($blockerLines | Measure-Object).Count
    if ($count -gt 0) {
        Write-Warn "STATE.md contains $count active BLOCKER(s)."
        $blockerLines | ForEach-Object { Write-Host "    $($_.LineNumber): $($_.Line.Trim())" }
        Write-Host "    -> Resolve blockers or suppress with [ignore:state_blockers]"
    } else {
        Write-Ok "No active blockers in STATE.md"
    }
}

# ── Check 4: VERIFICATION.md for completed phases ────────────────────────────
Write-Host ""
Write-Info "=== Check 4: Phase verification documentation ==="

if (Test-Ignore "phase_verify") {
    Write-Ok "Suppressed via [ignore:phase_verify]. Skipping VERIFICATION.md check."
} else {
    $planFiles = Get-ChildItem -Path $PLANNING_DIR -Filter "*-PLAN.md" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[/\\]quick[/\\]' }

    $phaseCount   = @{}
    $phaseSummary = @{}

    foreach ($planFile in $planFiles) {
        if ($planFile.Name -match '^(\d+)-\d+') {
            $phaseNum = $Matches[1]
            $phaseCount[$phaseNum] = ($phaseCount[$phaseNum] ?? 0) + 1
            $summaryFile = $planFile.FullName -replace '-PLAN\.md$', '-SUMMARY.md'
            if (Test-Path $summaryFile) {
                $phaseSummary[$phaseNum] = ($phaseSummary[$phaseNum] ?? 0) + 1
            }
        }
    }

    foreach ($phaseNum in $phaseCount.Keys) {
        $total      = $phaseCount[$phaseNum]
        $summarized = $phaseSummary[$phaseNum] ?? 0
        if ($total -eq $summarized -and $total -gt 0) {
            $verifyFile = Join-Path $PLANNING_DIR "${phaseNum}-VERIFICATION.md"
            if (-not (Test-Path $verifyFile)) {
                Write-Warn "Phase $phaseNum: all plans documented but $verifyFile is missing."
                Write-Host "    -> Run /gsd:verify-work $phaseNum to generate VERIFICATION.md"
                Write-Host "    -> Suppress with [ignore:phase_verify] if verification was done externally"
            } else {
                Write-Ok "Phase $phaseNum: VERIFICATION.md present"
            }
        }
    }
}

# ── Result ───────────────────────────────────────────────────────────────────
Write-Host ""
if ($script:Failed) {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host " SDD PROCESS CHECK FAILED (GSD)" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fix the issues above, or add an appropriate [ignore:...] tag to your commit message."
    Write-Host "See AGENTS.md -> 'SDD Ignore Tags' for the full list."
    exit 1
} else {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " SDD PROCESS CHECK PASSED (GSD)" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    exit 0
}
