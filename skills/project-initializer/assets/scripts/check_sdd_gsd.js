#!/usr/bin/env node
// check_sdd_gsd.js
//
// Node.js equivalent of check_sdd_gsd.sh
// Requires only built-in Node.js modules. Works on Windows, macOS, and Linux.
//
// IGNORE TAGS (commit message):
//   [ignore:all_sdd]        — Skip all SDD checks
//   [ignore:plan_doc]       — Skip core planning document existence check
//   [ignore:phase_summary]  — Skip plan SUMMARY.md check
//   [ignore:state_blockers] — Skip STATE.md blocker check
//   [ignore:phase_verify]   — Skip VERIFICATION.md check
//
// Exit codes: 0 = passed, 1 = failed

'use strict';

const fs   = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const isColour = process.platform !== 'win32' || process.env.FORCE_COLOR;
const RED    = isColour ? '\x1b[31m' : '';
const YELLOW = isColour ? '\x1b[33m' : '';
const GREEN  = isColour ? '\x1b[32m' : '';
const BLUE   = isColour ? '\x1b[34m' : '';
const NC     = isColour ? '\x1b[0m'  : '';

let failed = false;
function error(msg) { console.log(`${RED}[FAIL]${NC} ${msg}`); failed = true; }
function warn(msg)  { console.log(`${YELLOW}[WARN]${NC} ${msg}`); }
function ok(msg)    { console.log(`${GREEN}[ OK ]${NC} ${msg}`); }
function info(msg)  { console.log(`${BLUE}[INFO]${NC} ${msg}`); }

function git(cmd) {
    try {
        return execSync(`git ${cmd}`, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
    } catch { return ''; }
}

function existsSafe(p) { try { return fs.existsSync(p); } catch { return false; } }
function readSafe(p)   { try { return fs.readFileSync(p, 'utf8'); } catch { return ''; } }

function readdirSafe(dir, opts) {
    try { return fs.readdirSync(dir, opts || {}); } catch { return []; }
}

function globFiles(dir, pattern) {
    const results = [];
    function walk(d) {
        for (const e of readdirSafe(d, { withFileTypes: true })) {
            const full = path.join(d, e.name);
            if (e.isDirectory()) walk(full);
            else if (!pattern || pattern.test(e.name)) results.push(full);
        }
    }
    if (existsSafe(dir)) walk(dir);
    return results;
}

const PLANNING_DIR = '.planning';

const commitMsg = git('log -1 --pretty=%B').toLowerCase();
function hasIgnore(tag) {
    return commitMsg.includes(`[ignore:${tag}]`) || commitMsg.includes('[ignore:all_sdd]');
}

// ── GSD initialized? ─────────────────────────────────────────────────────────
if (!existsSafe(PLANNING_DIR)) {
    warn(`GSD planning directory '${PLANNING_DIR}/' not found. Skipping SDD checks.`);
    warn('If this project uses GSD, run: /gsd:new-project');
    process.exit(0);
}

// ── Changed source files ─────────────────────────────────────────────────────
const baseRef = process.env.CI_MERGE_REQUEST_DIFF_BASE_SHA || 'HEAD~1';
const excludeRe = /^(\.planning\/|\.planning\\|\.gitlab-ci|\.github[/\\]|scripts[/\\]|docs[/\\]|README|AGENTS|CHANGELOG|\.gitignore)/;
const changedSource = git(`diff --name-only ${baseRef} HEAD`)
    .split('\n').filter(f => f && !excludeRe.test(f));

if (changedSource.length === 0) {
    ok('No source code changes detected. Skipping SDD checks.');
    process.exit(0);
}

info('Source files changed in this MR/commit:');
changedSource.forEach(f => console.log(`  ${f}`));

// ── Check 1: Core planning documents ─────────────────────────────────────────
console.log('');
info('=== Check 1: Core GSD planning documents ===');

if (hasIgnore('plan_doc')) {
    ok('Suppressed via [ignore:plan_doc]. Skipping core document check.');
} else {
    for (const doc of ['PROJECT.md', 'REQUIREMENTS.md', 'ROADMAP.md', 'STATE.md']) {
        const docPath = path.join(PLANNING_DIR, doc);
        if (!existsSafe(docPath)) {
            error(`Missing core GSD document: ${docPath}`);
            console.log('    -> Create it with /gsd:new-project or restore from your planning/ directory');
        } else {
            ok(`${docPath} exists`);
        }
    }
}

// ── Check 2: Plan SUMMARY.md files ───────────────────────────────────────────
console.log('');
info('=== Check 2: Plan SUMMARY.md documentation ===');

if (hasIgnore('phase_summary')) {
    ok('Suppressed via [ignore:phase_summary]. Skipping plan summary check.');
} else {
    // Main phase plans (not in quick/)
    const planFiles = readdirSafe(PLANNING_DIR, { withFileTypes: true })
        .filter(e => e.isFile() && e.name.endsWith('-PLAN.md'));

    for (const planEntry of planFiles) {
        const planPath    = path.join(PLANNING_DIR, planEntry.name);
        const summaryPath = planPath.replace(/-PLAN\.md$/, '-SUMMARY.md');
        if (!existsSafe(summaryPath)) {
            warn(`Plan '${planEntry.name}': no corresponding SUMMARY.md found.`);
            console.log('    -> Execute the plan with /gsd:execute-phase to auto-generate SUMMARY.md');
            console.log('    -> Suppress with [ignore:phase_summary] if plan is not yet executed');
        } else {
            ok(`Plan '${planEntry.name}': SUMMARY.md exists`);
        }
    }

    // Quick tasks
    const quickDir = path.join(PLANNING_DIR, 'quick');
    for (const quickPlan of globFiles(quickDir, /^PLAN\.md$/)) {
        const taskSlug   = path.basename(path.dirname(quickPlan));
        const quickSummary = path.join(path.dirname(quickPlan), 'SUMMARY.md');
        if (!existsSafe(quickSummary)) {
            warn(`Quick task '${taskSlug}': no SUMMARY.md yet.`);
            console.log('    -> Suppress with [ignore:phase_summary] if still in progress');
        } else {
            ok(`Quick task '${taskSlug}': documented`);
        }
    }
}

// ── Check 3: STATE.md blockers ────────────────────────────────────────────────
console.log('');
info('=== Check 3: STATE.md active blockers ===');

const stateFile = path.join(PLANNING_DIR, 'STATE.md');
if (hasIgnore('state_blockers')) {
    ok('Suppressed via [ignore:state_blockers]. Skipping STATE.md blocker check.');
} else if (existsSafe(stateFile)) {
    const stateContent = readSafe(stateFile);
    const blockerLines = stateContent.split('\n')
        .map((line, i) => ({ line, num: i + 1 }))
        .filter(({ line }) => /\[BLOCKER\]/i.test(line));

    if (blockerLines.length > 0) {
        warn(`STATE.md contains ${blockerLines.length} active BLOCKER(s).`);
        blockerLines.forEach(({ line, num }) => console.log(`    ${num}: ${line.trim()}`));
        console.log('    -> Resolve blockers or suppress with [ignore:state_blockers]');
    } else {
        ok('No active blockers in STATE.md');
    }
}

// ── Check 4: VERIFICATION.md for completed phases ────────────────────────────
console.log('');
info('=== Check 4: Phase verification documentation ===');

if (hasIgnore('phase_verify')) {
    ok('Suppressed via [ignore:phase_verify]. Skipping VERIFICATION.md check.');
} else {
    const phaseCount   = {};
    const phaseSummary = {};

    for (const entry of readdirSafe(PLANNING_DIR, { withFileTypes: true })) {
        if (!entry.isFile()) continue;
        const matchPlan = entry.name.match(/^(\d+)-(\d+)-PLAN\.md$/);
        if (!matchPlan) continue;
        const phaseNum = matchPlan[1];
        phaseCount[phaseNum]   = (phaseCount[phaseNum]   || 0) + 1;

        const summaryPath = path.join(PLANNING_DIR, entry.name.replace('-PLAN.md', '-SUMMARY.md'));
        if (existsSafe(summaryPath)) {
            phaseSummary[phaseNum] = (phaseSummary[phaseNum] || 0) + 1;
        }
    }

    for (const phaseNum of Object.keys(phaseCount)) {
        const total      = phaseCount[phaseNum];
        const summarized = phaseSummary[phaseNum] || 0;
        if (total === summarized && total > 0) {
            const verifyFile = path.join(PLANNING_DIR, `${phaseNum}-VERIFICATION.md`);
            if (!existsSafe(verifyFile)) {
                warn(`Phase ${phaseNum}: all plans documented but ${verifyFile} is missing.`);
                console.log(`    -> Run /gsd:verify-work ${phaseNum} to generate VERIFICATION.md`);
                console.log('    -> Suppress with [ignore:phase_verify] if verification was done externally');
            } else {
                ok(`Phase ${phaseNum}: VERIFICATION.md present`);
            }
        }
    }
}

// ── Result ───────────────────────────────────────────────────────────────────
console.log('');
if (failed) {
    console.log(`${RED}==========================================================${NC}`);
    console.log(`${RED} SDD PROCESS CHECK FAILED (GSD)${NC}`);
    console.log(`${RED}==========================================================${NC}`);
    console.log('\nFix the issues above, or add an appropriate [ignore:...] tag to your commit message.');
    console.log("See AGENTS.md -> 'SDD Ignore Tags' for the full list.");
    process.exit(1);
} else {
    console.log(`${GREEN}==========================================================${NC}`);
    console.log(`${GREEN} SDD PROCESS CHECK PASSED (GSD)${NC}`);
    console.log(`${GREEN}==========================================================${NC}`);
    process.exit(0);
}
