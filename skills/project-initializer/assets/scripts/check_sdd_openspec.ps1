#!/usr/bin/env pwsh
# check_sdd_openspec.ps1
#
# PowerShell equivalent of check_sdd_openspec.sh
# Works on Windows, macOS, and Linux with PowerShell 7+.
#
# IGNORE TAGS (commit message):
#   [ignore:all_sdd]       — Skip all SDD checks
#   [ignore:spec_sync]     — Skip delta spec sync check
#   [ignore:task_check]    — Skip task completion check
#   [ignore:change_doc]    — Skip active change requirement
#
# Exit codes: 0 = passed, 1 = failed

param()
$ErrorActionPreference = 'Continue'

$OPENSPEC_DIR = "openspec"
$CHANGES_DIR  = Join-Path $OPENSPEC_DIR "changes"
$SPECS_DIR    = Join-Path $OPENSPEC_DIR "specs"
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

# ── OpenSpec initialized? ────────────────────────────────────────────────────
if (-not (Test-Path $OPENSPEC_DIR)) {
    Write-Warn "OpenSpec directory '$OPENSPEC_DIR/' not found. Skipping SDD checks."
    Write-Warn "If this project uses OpenSpec, run: openspec init"
    exit 0
}

# ── Changed source files ─────────────────────────────────────────────────────
$baseRef = if ($env:CI_MERGE_REQUEST_DIFF_BASE_SHA) { $env:CI_MERGE_REQUEST_DIFF_BASE_SHA } else { "HEAD~1" }
$excludePattern = '^(openspec/|\.gitlab-ci|\.github/|scripts/|docs/|README|AGENTS|CHANGELOG|\.gitignore)'
$changedSource = (Invoke-Git "diff --name-only $baseRef HEAD") -split "`n" |
    Where-Object { $_ -and $_ -notmatch $excludePattern }

if (-not $changedSource) {
    Write-Ok "No source code changes detected. Skipping SDD checks."
    exit 0
}

Write-Info "Source files changed in this MR/commit:"
$changedSource | ForEach-Object { Write-Host "  $_" }

# ── Check 1: Active change exists ────────────────────────────────────────────
Write-Host ""
Write-Info "=== Check 1: Active change documentation ==="

if (Test-Ignore "change_doc") {
    Write-Ok "Suppressed via [ignore:change_doc]. Skipping active-change check."
} else {
    $activeChanges = @()
    if (Test-Path $CHANGES_DIR) {
        $activeChanges = Get-ChildItem -Path $CHANGES_DIR -Directory |
            Where-Object { $_.FullName -notmatch '[/\\]archive[/\\]' } |
            Select-Object -ExpandProperty Name
    }

    if ($activeChanges.Count -eq 0) {
        Write-Fail "No active OpenSpec changes found in '$CHANGES_DIR/'."
        Write-Host "  -> Source code was changed but there is no accompanying change documentation."
        Write-Host "  -> Create a change with: /opsx:propose <description>"
        Write-Host "  -> Or suppress with: [ignore:change_doc] (e.g., for pure bug fixes)"
    } else {
        Write-Ok "Active change(s) found: $($activeChanges -join ', ')"
    }
}

# ── Check 2: Task completion ──────────────────────────────────────────────────
Write-Host ""
Write-Info "=== Check 2: Task completion in active changes ==="

if (Test-Ignore "task_check") {
    Write-Ok "Suppressed via [ignore:task_check]. Skipping task completion check."
} elseif (Test-Path $CHANGES_DIR) {
    Get-ChildItem -Path $CHANGES_DIR -Recurse -Filter "tasks.md" |
        Where-Object { $_.FullName -notmatch '[/\\]archive[/\\]' } |
        ForEach-Object {
            $taskFile   = $_.FullName
            $changeName = Split-Path (Split-Path $taskFile) -Leaf
            $unchecked  = (Select-String -Path $taskFile -Pattern '^\s*- \[ \]' | Measure-Object).Count

            if ($unchecked -gt 0) {
                Write-Warn "Change '$changeName': $unchecked incomplete task(s) in tasks.md"
                Write-Host "    -> Complete tasks or suppress with [ignore:task_check]"
            } else {
                Write-Ok "Change '$changeName': all tasks complete"
            }
        }
}

# ── Check 3: Delta spec sync status ─────────────────────────────────────────
Write-Host ""
Write-Info "=== Check 3: Delta spec synchronization ==="

if (Test-Ignore "spec_sync") {
    Write-Ok "Suppressed via [ignore:spec_sync]. Skipping delta spec sync check."
} elseif (Test-Path $CHANGES_DIR) {
    Get-ChildItem -Path $CHANGES_DIR -Directory |
        Where-Object { $_.FullName -notmatch '[/\\]archive[/\\]' } |
        ForEach-Object {
            $changeName   = $_.Name
            $changeSpecsDir = Join-Path $_.FullName "specs"
            if (-not (Test-Path $changeSpecsDir)) { return }

            Get-ChildItem -Path $changeSpecsDir -Recurse -Filter "*.md" | ForEach-Object {
                $deltaSpec = $_.FullName
                $relPath   = $deltaSpec.Substring($changeSpecsDir.Length).TrimStart('/\')
                $mainSpec  = Join-Path $SPECS_DIR $relPath

                if (-not (Test-Path $mainSpec)) {
                    Write-Warn "Change '$changeName': delta spec '$relPath' has no corresponding main spec."
                    Write-Host "    -> Run /opsx:sync $changeName to merge delta into main specs"
                    Write-Host "    -> Suppress with [ignore:spec_sync] if creation is planned later"
                } elseif ((Get-Item $deltaSpec).LastWriteTime -gt (Get-Item $mainSpec).LastWriteTime) {
                    Write-Warn "Change '$changeName': delta spec '$relPath' is newer than main spec."
                    Write-Host "    -> Delta spec changed since last sync. Run: /opsx:sync $changeName"
                    Write-Host "    -> Suppress with [ignore:spec_sync] if intentional"
                } else {
                    Write-Ok "Change '$changeName' / '$relPath': in sync"
                }
            }
        }
}

# ── Result ───────────────────────────────────────────────────────────────────
Write-Host ""
if ($script:Failed) {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host " SDD PROCESS CHECK FAILED (OpenSpec)" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fix the issues above, or add an appropriate [ignore:...] tag to your commit message."
    Write-Host "See AGENTS.md -> 'SDD Ignore Tags' for the full list."
    exit 1
} else {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " SDD PROCESS CHECK PASSED (OpenSpec)" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    exit 0
}
