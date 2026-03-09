#!/usr/bin/env node
// check_sdd_speckit.js
//
// Node.js equivalent of check_sdd_speckit.sh
// Requires only built-in Node.js modules. Works on Windows, macOS, and Linux.
//
// IGNORE TAGS (commit message):
//   [ignore:all_sdd]          — Skip all SDD checks
//   [ignore:spec_complete]    — Skip [NEEDS CLARIFICATION:] marker check
//   [ignore:phase_gates]      — Skip Phase -1 gate check
//   [ignore:task_check]       — Skip task completion check
//   [ignore:spec_doc]         — Skip spec existence check
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

function walkFiles(dir, pattern) {
    const results = [];
    function walk(d) {
        let entries;
        try { entries = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
        for (const e of entries) {
            const full = path.join(d, e.name);
            if (e.isDirectory()) walk(full);
            else if (!pattern || pattern.test(e.name)) results.push(full);
        }
    }
    walk(dir);
    return results;
}

function readSafe(filePath) {
    try { return fs.readFileSync(filePath, 'utf8'); } catch { return ''; }
}

function countMatches(text, re) {
    return (text.match(re) || []).length;
}

const SPECS_DIR    = 'specs';
const CONSTITUTION = path.join('memory', 'constitution.md');

const commitMsg = git('log -1 --pretty=%B').toLowerCase();
function hasIgnore(tag) {
    return commitMsg.includes(`[ignore:${tag}]`) || commitMsg.includes('[ignore:all_sdd]');
}

// ── SpecKit initialized? ─────────────────────────────────────────────────────
if (!fs.existsSync(SPECS_DIR)) {
    warn(`SpecKit specs directory '${SPECS_DIR}/' not found. Skipping SDD checks.`);
    warn('If this project uses SpecKit, run: specify init . --ai claude');
    process.exit(0);
}

// ── Changed source files ─────────────────────────────────────────────────────
const baseRef = process.env.CI_MERGE_REQUEST_DIFF_BASE_SHA || 'HEAD~1';
const excludeRe = /^(specs\/|memory\/|\.gitlab-ci|\.github\/|scripts\/|docs\/|README|AGENTS|CHANGELOG|\.gitignore)/;
const changedSource = git(`diff --name-only ${baseRef} HEAD`)
    .split('\n').filter(f => f && !excludeRe.test(f));

if (changedSource.length === 0) {
    ok('No source code changes detected. Skipping SDD checks.');
    process.exit(0);
}

info('Source files changed in this MR/commit:');
changedSource.forEach(f => console.log(`  ${f}`));

// ── Check 1: Spec directory exists ───────────────────────────────────────────
console.log('');
info('=== Check 1: Spec documentation exists ===');

if (hasIgnore('spec_doc')) {
    ok('Suppressed via [ignore:spec_doc]. Skipping spec existence check.');
} else {
    let specDirEntries = [];
    try { specDirEntries = fs.readdirSync(SPECS_DIR, { withFileTypes: true }).filter(e => e.isDirectory()); } catch {}
    if (specDirEntries.length === 0) {
        error(`No spec directories found in '${SPECS_DIR}/'.`);
        console.log('  -> Source code was changed but there is no spec documentation.');
        console.log('  -> Create a spec with your AI agent using SpecKit.');
        console.log('  -> Suppress with [ignore:spec_doc] for bug fixes or chores.');
    } else {
        ok(`Spec directories found: ${specDirEntries.map(e => e.name).join(', ')}`);
    }
}

// ── Check 2: No unresolved [NEEDS CLARIFICATION:] markers ────────────────────
console.log('');
info('=== Check 2: Unresolved [NEEDS CLARIFICATION:] markers ===');

if (hasIgnore('spec_complete')) {
    ok('Suppressed via [ignore:spec_complete]. Skipping clarification marker check.');
} else {
    let anyFound = false;
    for (const specFile of walkFiles(SPECS_DIR, /^spec\.md$/)) {
        const content = readSafe(specFile);
        const count   = countMatches(content, /\[NEEDS CLARIFICATION:/g);
        if (count > 0) {
            error(`File '${specFile}': ${count} unresolved [NEEDS CLARIFICATION:] marker(s)`);
            console.log('    -> Resolve all ambiguities before merging to release branch');
            console.log('    -> Suppress with [ignore:spec_complete] if deferring is intentional');
            anyFound = true;
        }
    }
    if (!anyFound) ok('No unresolved clarification markers found.');
}

// ── Check 3: Phase -1 Pre-Implementation Gates ───────────────────────────────
console.log('');
info('=== Check 3: Phase -1 Pre-Implementation Gates ===');

if (hasIgnore('phase_gates')) {
    ok('Suppressed via [ignore:phase_gates]. Skipping Phase -1 gate check.');
} else {
    for (const planFile of walkFiles(SPECS_DIR, /^plan\.md$/)) {
        const specName = path.basename(path.dirname(planFile));
        const content  = readSafe(planFile);

        if (!content.includes('Phase -1')) {
            warn(`Spec '${specName}/plan.md': no Phase -1 Pre-Implementation Gates section found.`);
            console.log('    -> Add gate checks as defined in SpecKit\'s plan.md template');
            continue;
        }

        // Extract section between 'Phase -1' and next '## ' heading
        const gateMatch   = content.match(/Phase -1[\s\S]*?(?=^## |\n*$)/m);
        const gateSection = gateMatch ? gateMatch[0] : '';
        const unchecked   = countMatches(gateSection, /^\s*- \[ \]/mg);

        if (unchecked > 0) {
            error(`Spec '${specName}/plan.md': ${unchecked} Phase -1 gate(s) not satisfied.`);
            console.log('    -> Complete all pre-implementation gates before merging');
            console.log("    -> Gates: Simplicity (Article VII), Anti-Abstraction (VIII), Integration-First (IX)");
            console.log("    -> Suppress with [ignore:phase_gates] if gates don't apply");
        } else {
            ok(`Spec '${specName}': Phase -1 gates satisfied`);
        }
    }
}

// ── Check 4: Task completion ──────────────────────────────────────────────────
console.log('');
info('=== Check 4: Task completion ===');

if (hasIgnore('task_check')) {
    ok('Suppressed via [ignore:task_check]. Skipping task completion check.');
} else {
    for (const tasksFile of walkFiles(SPECS_DIR, /^tasks\.md$/)) {
        const specName  = path.basename(path.dirname(tasksFile));
        const unchecked = countMatches(readSafe(tasksFile), /^\s*- \[ \]/mg);
        if (unchecked > 0) {
            warn(`Spec '${specName}/tasks.md': ${unchecked} unchecked task(s).`);
            console.log('    -> Complete tasks or suppress with [ignore:task_check]');
        } else {
            ok(`Spec '${specName}': all tasks complete`);
        }
    }
}

// ── Constitution (informational) ─────────────────────────────────────────────
if (fs.existsSync(CONSTITUTION)) {
    ok(`Constitution found at ${CONSTITUTION}`);
} else {
    warn(`Constitution file not found at '${CONSTITUTION}'.`);
    console.log('    -> SpecKit expects a constitution.md in memory/. Run: specify init . --ai claude');
}

// ── Result ───────────────────────────────────────────────────────────────────
console.log('');
if (failed) {
    console.log(`${RED}==========================================================${NC}`);
    console.log(`${RED} SDD PROCESS CHECK FAILED (SpecKit)${NC}`);
    console.log(`${RED}==========================================================${NC}`);
    console.log('\nFix the issues above, or add an appropriate [ignore:...] tag to your commit message.');
    console.log("See AGENTS.md -> 'SDD Ignore Tags' for the full list.");
    process.exit(1);
} else {
    console.log(`${GREEN}==========================================================${NC}`);
    console.log(`${GREEN} SDD PROCESS CHECK PASSED (SpecKit)${NC}`);
    console.log(`${GREEN}==========================================================${NC}`);
    process.exit(0);
}
