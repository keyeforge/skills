#!/usr/bin/env node
/**
 * Updates README.md "Available Skills" section from skills in skills/ subdirs (SKILL.md frontmatter).
 * Run after adding, removing, or renaming skills.
 *
 * Usage: node scripts/update-readme.js
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SKILLS_DIR = path.join(ROOT, 'skills');
const README_PATH = path.join(ROOT, 'README.md');

const START_MARKER = '<!-- SKILLS_LIST_START -->';
const END_MARKER = '<!-- SKILLS_LIST_END -->';

function getFrontmatter(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const match = content.match(/^---\s*\n([\s\S]*?)\n---/);
  if (!match) return null;
  const yaml = match[1];
  const name = yaml.match(/^name:\s*(.+)$/m)?.[1]?.trim();
  const description = yaml.match(/^description:\s*(.+)$/m)?.[1]?.trim();
  return name && description ? { name, description } : null;
}

function getSkillBodyPreview(filePath, maxLines = 25) {
  const content = fs.readFileSync(filePath, 'utf8');
  const afterFrontmatter = content.replace(/^---\s*\n[\s\S]*?\n---\s*\n?/, '');
  const lines = afterFrontmatter.split('\n').filter(Boolean);
  return lines.slice(0, maxLines).join('\n');
}

function collectSkills() {
  if (!fs.existsSync(SKILLS_DIR)) return [];
  const entries = fs.readdirSync(SKILLS_DIR, { withFileTypes: true });
  const skills = [];
  for (const ent of entries) {
    if (!ent.isDirectory()) continue;
    const skillPath = path.join(SKILLS_DIR, ent.name);
    const skillMd = path.join(skillPath, 'SKILL.md');
    if (!fs.existsSync(skillMd)) continue;
    const meta = getFrontmatter(skillMd);
    if (!meta) continue;
    const bodyPreview = getSkillBodyPreview(skillMd);
    skills.push({
      dir: ent.name,
      name: meta.name,
      description: meta.description,
      bodyPreview,
    });
  }
  skills.sort((a, b) => a.name.localeCompare(b.name));
  return skills;
}

function buildSkillsSection(skills) {
  if (skills.length === 0) {
    return '*No skills in this repo yet. Add skills under `skills/<name>/SKILL.md` and run `node scripts/update-readme.js` to update this list.*';
  }
  const blocks = skills.map((s) => {
    return `### ${s.name}\n\n${s.description}\n`;
  });
  return blocks.join('\n');
}

function main() {
  const readme = fs.readFileSync(README_PATH, 'utf8');
  const startIdx = readme.indexOf(START_MARKER);
  const endIdx = readme.indexOf(END_MARKER);

  if (startIdx === -1 || endIdx === -1 || endIdx <= startIdx) {
    console.error('README.md must contain both SKILLS_LIST_START and SKILLS_LIST_END markers.');
    process.exit(1);
  }

  const skills = collectSkills();
  const newContent =
    readme.slice(0, startIdx + START_MARKER.length) +
    '\n\n' +
    buildSkillsSection(skills) +
    '\n\n' +
    readme.slice(endIdx);

  fs.writeFileSync(README_PATH, newContent, 'utf8');
  console.log(`Updated README.md with ${skills.length} skill(s).`);
}

main();
