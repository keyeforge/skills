#!/usr/bin/env pwsh
# check_project_tag.ps1
#
# PowerShell equivalent of check_project_tag.sh
# Works on Windows, macOS, and Linux with PowerShell 7+.
#
# IGNORE TAGS (commit message):
#   [ignore:project_tag]   — Skip this check
#   [ignore:all_sdd]       — Skip all SDD/process checks
#
# Exit codes: 0 = passed, 1 = failed

param()
$ErrorActionPreference = 'Continue'

$AGENTS_FILE = "AGENTS.md"
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

Write-Info "Checking AGENTS.md for @project-initializer identity tag..."

if (Test-Ignore "project_tag") {
    Write-Warn "Suppressed via [ignore:project_tag]. Skipping identity tag check."
    Write-Warn "This is only appropriate when migrating a legacy project."
    exit 0
}

if (-not (Test-Path $AGENTS_FILE)) {
    Write-Fail "AGENTS.md not found in project root."
    Write-Host "  -> Run the project-initializer skill to create AGENTS.md"
    exit 1
}

$content = Get-Content $AGENTS_FILE -Raw -Encoding UTF8

if (-not ($content -match '<!-- @project-initializer')) {
    Write-Fail "AGENTS.md is missing the @project-initializer identity tag."
    Write-Host ""
    Write-Host "  The tag must be the first content in AGENTS.md:"
    Write-Host ""
    Write-Host "    <!-- @project-initializer"
    Write-Host "    version: 1"
    Write-Host "    initialized_at: YYYY-MM-DD"
    Write-Host "    sdd_framework: openspec|speckit|gsd"
    Write-Host "    quality_level: demo|production"
    Write-Host "    ci_platforms: gitlab|github|gitlab,github"
    Write-Host "    project_initializer_version: 1.0.0"
    Write-Host "    -->"
    Write-Host ""
    Write-Host "  -> Re-run the project-initializer skill to add this tag."
    Write-Host "  -> Suppress with [ignore:project_tag] only for legacy migrations."
    exit 1
}

# Extract the tag block
$tagBlockMatch = [regex]::Match($content, '<!-- @project-initializer([\s\S]*?)-->')
$tagBlock = if ($tagBlockMatch.Success) { $tagBlockMatch.Groups[1].Value } else { "" }

$requiredFields = @(
    @{ Name = 'version';                    Pattern = '^\d+$' },
    @{ Name = 'initialized_at';             Pattern = '^\d{4}-\d{2}-\d{2}$' },
    @{ Name = 'sdd_framework';              Pattern = '^(openspec|speckit|gsd)$' },
    @{ Name = 'quality_level';              Pattern = '^(demo|production)$' },
    @{ Name = 'ci_platforms';               Pattern = '^(gitlab|github|gitlab,github|github,gitlab)$' },
    @{ Name = 'project_initializer_version'; Pattern = '^[\d.]+$' }
)

foreach ($field in $requiredFields) {
    if ($tagBlock -match "(?m)^$($field.Name): (.+)") {
        $value = $Matches[1].Trim()
        if ($value -match $field.Pattern) {
            Write-Ok "Tag field '$($field.Name)': $value"
        } else {
            Write-Fail "Tag field '$($field.Name)' has unexpected value: '$value'"
            Write-Host "         Expected pattern: $($field.Pattern)"
        }
    } else {
        Write-Fail "Tag field '$($field.Name)' is missing from @project-initializer block."
    }
}

Write-Host ""
if ($script:Failed) {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host " PROJECT TAG CHECK FAILED" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    exit 1
} else {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " PROJECT TAG CHECK PASSED" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    exit 0
}
