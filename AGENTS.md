# Agent instructions for this repository

This repository is a **skills catalog** for the [open agent skills ecosystem](https://github.com/vercel-labs/skills). Users install skills with:

```bash
npx skills add keyeforge/skills
```

(Replace `keyeforge/skills` with the actual GitHub repo if different.)

## Repository goals

- Publish **reusable agent skills** that users can install via `npx skills add`.
- Keep the **README** in sync with the list of skills so the catalog is accurate.

## Where skills live

- **Path:** `skills/<skill-name>/SKILL.md`
- Each skill is a **directory** under `skills/` with a `SKILL.md` file.
- `SKILL.md` must have YAML frontmatter with at least:
  - `name`: unique identifier (lowercase, hyphens)
  - `description`: short description (used in README and by agents)

Example:

```markdown
---
name: my-skill
description: What this skill does and when to use it
---

# My Skill
...
```

## When you add or remove a skill

1. **Add/remove** the skill under `skills/<skill-name>/` (add or delete the directory and its `SKILL.md`).
2. **Update the README** by running:
   ```bash
   node scripts/update-readme.js
   ```
   This script scans `skills/`, reads each `SKILL.md` frontmatter, and rewrites the "Available Skills" section in `README.md`. **Always run it after adding or removing a skill.**

## GitHub and tooling

- **GitHub user:** `keyeforge`
- **Management:** Use the [vercel-labs/skills](https://github.com/vercel-labs/skills) CLI:
  - Install: `npx skills add <source>`
  - List: `npx skills list`
  - Remove: `npx skills remove <skill-name>`
- After changing skills locally, commit and push to GitHub so users can install with `npx skills add keyeforge/skills` (or the repo’s full path).

## Skill authoring

- Follow the [Agent Skills](https://agentskills.io/) format.
- Keep each skill focused; put "When to use" and clear steps in the body.
- Optional frontmatter: `metadata.internal: true` to hide from normal discovery (e.g. WIP skills).

## Summary

| Action              | Do this |
|---------------------|--------|
| Add a new skill     | Create `skills/<skill-name>/SKILL.md`, then run `node scripts/update-readme.js` |
| Remove a skill      | Delete `skills/<skill-name>/`, then run `node scripts/update-readme.js` |
| Change skill text   | Edit `SKILL.md`; run `node scripts/update-readme.js` if name/description changed |
| Publish for users   | Commit and push to GitHub (e.g. keyeforge/skills) |
