# Agent Skills

A collection of agent skills you can install with the [skills CLI](https://github.com/vercel-labs/skills). Compatible with **Cursor**, **Claude Code**, **Codex**, **OpenCode**, and other agents that support the [Agent Skills](https://agentskills.io/) format.

## Installation

```bash
npx skills add keyeforge/skills
```

To install only certain skills or to a specific agent, see the [skills CLI options](https://github.com/vercel-labs/skills#options).

## Available Skills

<!-- SKILLS_LIST_START -->

### init-react-frontend

Use when scaffolding a new React frontend with React, Ant Design, Ant Design X, react-router, TypeScript, Zustand, Vitest, Tailwind CSS, Axios, and Vite plus Rolldown — or when the user asks to initialize a frontend project with this stack.

### initialize-node-admin-system

Initialize a new Node.js admin system from the keyeforge/directus-template GitHub template. Use when the user asks to create, scaffold, clone, bootstrap, or initialize a Node.js backend/admin system, Directus CRM/admin project, React admin console, or a new project based on https://github.com/keyeforge/directus-template.

### project-initializer

"Helps users scaffold new projects with production-ready files: README.md, AGENTS.md (agent memory), and CI/CD pipelines (GitLab CI, GitHub Actions, or both). Handles tech stack selection, coding standards ingestion, quality level configuration (demo vs. production), and SDD framework integration (OpenSpec, SpecKit, or GSD). Documentation is generated in Chinese (中文) by default, with support for other languages upon request. Use this skill whenever a user wants to create a new project, initialize a repository, set up CI/CD, choose a spec-driven development workflow, scaffold project files, or asks about project structure and agent memory files. Even if the user only asks about one part (e.g., \"set up CI/CD\" or \"create AGENTS.md\"), use this skill — it ensures all files stay consistent with each other."


<!-- SKILLS_LIST_END -->

## Usage

After installation, your agent will use these skills when they match the task. No extra configuration needed.

## Skill structure

Each skill is a directory under `skills/` with:

- `SKILL.md` – instructions and when to use (required; includes `name` and `description` in frontmatter)
- Optional: `scripts/`, `references/`, or other supporting files

## License

MIT
