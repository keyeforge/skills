#!/usr/bin/env node
// check_sdd_openspec.js
//
// Node.js equivalent of check_sdd_openspec.sh
// Requires only built-in Node.js modules. Works on Windows, macOS, and Linux.
//
// IGNORE TAGS (commit message):
//   [ignore:all_sdd]       — Skip all SDD checks
//   [ignore:spec_sync]     — Skip delta spec sync check
//   [ignore:task_check]    — Skip task completion check
//   [ignore:change_doc]    — Skip active change requirement
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

const OPENSPEC_DIR = 'openspec';
const CHANGES_DIR  = path.join(OPENSPEC_DIR, 'changes');
const SPECS_DIR    = path.join(OPENSPEC_DIR, 'specs');

const commitMsg = git('log -1 --pretty=%B').toLowerCase();
function hasIgnore(tag) {
    return commitMsg.includes(`[ignore:${tag}]`) || commitMsg.includes('[ignore:all_sdd]');
}

// ── OpenSpec initialized? ────────────────────────────────────────────────────
if (!fs.existsSync(OPENSPEC_DIR)) {
    warn(`OpenSpec directory '${OPENSPEC_DIR}/' not found. Skipping SDD checks.`);
    warn('If this project uses OpenSpec, run: openspec init');
    process.exit(0);
}

// ── Changed source files ─────────────────────────────────────────────────────
const baseRef = process.env.CI_MERGE_REQUEST_DIFF_BASE_SHA || 'HEAD~1';
const excludeRe = /^(openspec\/|\.gitlab-ci|\.github\/|scripts\/|docs\/|README|AGENTS|CHANGELOG|\.gitignore)/;
const changedSource = git(`diff --name-only ${baseRef} HEAD`)
    .split('\n').filter(f => f && !excludeRe.test(f));

if (changedSource.length === 0) {
    ok('No source code changes detected. Skipping SDD checks.');
    process.exit(0);
}

info('Source files changed in this MR/commit:');
changedSource.forEach(f => console.log(`  ${f}`));

// ── Helpers ──────────────────────────────────────────────────────────────────
function readdirSafe(dir) {
    try { return fs.readdirSync(dir, { withFileTypes: true }); } catch { return []; }
}

function walkFiles(dir, pattern) {
    const results = [];
    function walk(d) {
        for (const entry of readdirSafe(d)) {
            const full = path.join(d, entry.name);
            if (entry.isDirectory()) walk(full);
            else if (!pattern || pattern.test(entry.name)) results.push(full);
        }
    }
    walk(dir);
    return results;
}

function countPattern(filePath, re) {
    try {
        return (fs.readFileSync(filePath, 'utf8').match(re) || []).length;
    } catch { return 0; }
}

// ── Check 1: Active change exists ────────────────────────────────────────────
console.log('');
info('=== Check 1: Active change documentation ===');

if (hasIgnore('change_doc')) {
    ok('Suppressed via [ignore:change_doc]. Skipping active-change check.');
} else {
    const activeChanges = fs.existsSync(CHANGES_DIR)
        ? readdirSafe(CHANGES_DIR)
              .filter(e => e.isDirectory() && e.name !== 'archive')
              .map(e => e.name)
        : [];

    if (activeChanges.length === 0) {
        error(`No active OpenSpec changes found in '${CHANGES_DIR}/'.`);
        console.log('  -> Source code was changed but there is no accompanying change documentation.');
        console.log('  -> Create a change with: /opsx:propose <description>');
        console.log('  -> Or suppress with: [ignore:change_doc] (e.g., for pure bug fixes)');
    } else {
        ok(`Active change(s) found: ${activeChanges.join(', ')}`);
    }
}

// ── Check 2: Task completion ──────────────────────────────────────────────────
console.log('');
info('=== Check 2: Task completion in active changes ===');

if (hasIgnore('task_check')) {
    ok('Suppressed via [ignore:task_check]. Skipping task completion check.');
} else if (fs.existsSync(CHANGES_DIR)) {
    const taskFiles = walkFiles(CHANGES_DIR, /^tasks\.md$/)
        .filter(f => !f.includes(path.sep + 'archive' + path.sep));

    for (const taskFile of taskFiles) {
        const changeName = path.basename(path.dirname(taskFile));
        const unchecked = countPattern(taskFile, /^\s*- \[ \]/mg);
        if (unchecked > 0) {
            warn(`Change '${changeName}': ${unchecked} incomplete task(s) in tasks.md`);
            console.log('    -> Complete tasks or suppress with [ignore:task_check]');
        } else {
            ok(`Change '${changeName}': all tasks complete`);
        }
    }
}

// ── Check 3: Delta spec sync status ─────────────────────────────────────────
console.log('');
info('=== Check 3: Delta spec synchronization ===');

if (hasIgnore('spec_sync')) {
    ok('Suppressed via [ignore:spec_sync]. Skipping delta spec sync check.');
} else if (fs.existsSync(CHANGES_DIR)) {
    for (const entry of readdirSafe(CHANGES_DIR)) {
        if (!entry.isDirectory() || entry.name === 'archive') continue;
        const changeName    = entry.name;
        const changeSpecsDir = path.join(CHANGES_DIR, changeName, 'specs');
        if (!fs.existsSync(changeSpecsDir)) continue;

        const deltaFiles = walkFiles(changeSpecsDir, /\.md$/);
        for (const deltaSpec of deltaFiles) {
            const relPath  = path.relative(changeSpecsDir, deltaSpec);
            const mainSpec = path.join(SPECS_DIR, relPath);

            if (!fs.existsSync(mainSpec)) {
                warn(`Change '${changeName}': delta spec '${relPath}' has no corresponding main spec.`);
                console.log(`    -> Run /opsx:sync ${changeName} to merge delta into main specs`);
                console.log('    -> Suppress with [ignore:spec_sync] if creation is planned later');
            } else {
                const deltaMtime = fs.statSync(deltaSpec).mtimeMs;
                const mainMtime  = fs.statSync(mainSpec).mtimeMs;
                if (deltaMtime > mainMtime) {
                    warn(`Change '${changeName}': delta spec '${relPath}' is newer than main spec.`);
                    console.log(`    -> Delta spec changed since last sync. Run: /opsx:sync ${changeName}`);
                    console.log('    -> Suppress with [ignore:spec_sync] if intentional');
                } else {
                    ok(`Change '${changeName}' / '${relPath}': in sync`);
                }
            }
        }
    }
}

// ── Result ───────────────────────────────────────────────────────────────────
console.log('');
if (failed) {
    console.log(`${RED}==========================================================${NC}`);
    console.log(`${RED} SDD PROCESS CHECK FAILED (OpenSpec)${NC}`);
    console.log(`${RED}==========================================================${NC}`);
    console.log('\nFix the issues above, or add an appropriate [ignore:...] tag to your commit message.');
    console.log("See AGENTS.md -> 'SDD Ignore Tags' for the full list.");
    process.exit(1);
} else {
    console.log(`${GREEN}==========================================================${NC}`);
    console.log(`${GREEN} SDD PROCESS CHECK PASSED (OpenSpec)${NC}`);
    console.log(`${GREEN}==========================================================${NC}`);
    process.exit(0);
}
