#!/usr/bin/env node
// check_project_tag.js
//
// Node.js equivalent of check_project_tag.sh
// Requires only built-in Node.js modules. Works on Windows, macOS, and Linux.
//
// IGNORE TAGS (commit message):
//   [ignore:project_tag]   — Skip this check
//   [ignore:all_sdd]       — Skip all SDD/process checks
//
// Exit codes: 0 = passed, 1 = failed

'use strict';

const fs = require('fs');
const { execSync } = require('child_process');

// ── ANSI colours (disabled on Windows unless FORCE_COLOR is set) ─────────────
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

const AGENTS_FILE = 'AGENTS.md';
const commitMsg = git('log -1 --pretty=%B').toLowerCase();

function hasIgnore(tag) {
    return commitMsg.includes(`[ignore:${tag}]`) || commitMsg.includes('[ignore:all_sdd]');
}

info('Checking AGENTS.md for @project-initializer identity tag...');

if (hasIgnore('project_tag')) {
    warn('Suppressed via [ignore:project_tag]. Skipping identity tag check.');
    warn('This is only appropriate when migrating a legacy project.');
    process.exit(0);
}

if (!fs.existsSync(AGENTS_FILE)) {
    error('AGENTS.md not found in project root.');
    console.log('  -> Run the project-initializer skill to create AGENTS.md');
    process.exit(1);
}

const content = fs.readFileSync(AGENTS_FILE, 'utf8');

if (!content.includes('<!-- @project-initializer')) {
    error('AGENTS.md is missing the @project-initializer identity tag.');
    console.log('');
    console.log('  The tag must be the first content in AGENTS.md:');
    console.log('');
    console.log('    <!-- @project-initializer');
    console.log('    version: 1');
    console.log('    initialized_at: YYYY-MM-DD');
    console.log('    sdd_framework: openspec|speckit|gsd');
    console.log('    quality_level: demo|production');
    console.log('    ci_platforms: gitlab|github|gitlab,github');
    console.log('    project_initializer_version: 1.0.0');
    console.log('    -->');
    console.log('');
    console.log('  -> Re-run the project-initializer skill to add this tag.');
    console.log('  -> Suppress with [ignore:project_tag] only for legacy migrations.');
    process.exit(1);
}

const tagBlockMatch = content.match(/<!-- @project-initializer([\s\S]*?)-->/);
const tagBlock = tagBlockMatch ? tagBlockMatch[1] : '';

const requiredFields = [
    { name: 'version',                     pattern: /^\d+$/ },
    { name: 'initialized_at',              pattern: /^\d{4}-\d{2}-\d{2}$/ },
    { name: 'sdd_framework',               pattern: /^(openspec|speckit|gsd)$/ },
    { name: 'quality_level',               pattern: /^(demo|production)$/ },
    { name: 'ci_platforms',                pattern: /^(gitlab|github|gitlab,github|github,gitlab)$/ },
    { name: 'project_initializer_version', pattern: /^[\d.]+$/ },
];

for (const field of requiredFields) {
    const match = tagBlock.match(new RegExp(`^${field.name}: (.+)`, 'm'));
    if (!match) {
        error(`Tag field '${field.name}' is missing from @project-initializer block.`);
        continue;
    }
    const value = match[1].trim();
    if (field.pattern.test(value)) {
        ok(`Tag field '${field.name}': ${value}`);
    } else {
        error(`Tag field '${field.name}' has unexpected value: '${value}'`);
        console.log(`         Expected pattern: ${field.pattern}`);
    }
}

console.log('');
if (failed) {
    console.log(`${RED}==========================================================${NC}`);
    console.log(`${RED} PROJECT TAG CHECK FAILED${NC}`);
    console.log(`${RED}==========================================================${NC}`);
    process.exit(1);
} else {
    console.log(`${GREEN}==========================================================${NC}`);
    console.log(`${GREEN} PROJECT TAG CHECK PASSED${NC}`);
    console.log(`${GREEN}==========================================================${NC}`);
    process.exit(0);
}
