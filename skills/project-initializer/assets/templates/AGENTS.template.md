<!-- @project-initializer
version: 1
initialized_at: {{INITIALIZED_DATE}}
sdd_framework: {{SDD_FRAMEWORK_ID}}
quality_level: {{QUALITY_LEVEL_ID}}
ci_platforms: {{CI_PLATFORMS_ID}}
project_initializer_version: 1.0.0
-->

# AGENTS.md — {{PROJECT_NAME}}

> This file is the shared memory for AI agents working on this repository.
> Keep it accurate and up to date. Add entries; do not delete them without team agreement.
> Start minimal and grow it as the project evolves.

---

## Project Overview

**Name:** {{PROJECT_NAME}}
**Description:** {{PROJECT_DESCRIPTION}}
**Quality Level:** {{QUALITY_LEVEL}}

---

## Tech Stack

{{TECH_STACK_DETAILS}}

<!--
Add runtime versions, key libraries, and their roles as the project evolves.
Example format:
- **Runtime:** Node.js 20 LTS
- **Framework:** Fastify 4.x
- **Database:** PostgreSQL 15 (via Prisma ORM)
- **Testing:** Vitest + Supertest
- **Linting:** ESLint (Airbnb config) + Prettier
- **Container:** Docker + docker-compose
-->

---

## Quality Standards

| Standard | Requirement |
|----------|-------------|
| Unit test coverage | {{COVERAGE_THRESHOLD}}% minimum |
| Linting | {{LINT_TOOL}} — zero warnings on release |
| Security scanning | {{SECURITY_TOOLS}} |
| Commit messages | Conventional Commits (`type(scope): description`) |
| Branch strategy | Feature branches → MR → `{{MAIN_BRANCH}}` |

---

## Coding Standards

{{CODING_STANDARDS_SUMMARY}}

<!--
Summarize the key rules agents must follow when writing code for this project.
If a canonical standards file exists, reference it:
  Source: docs/coding-standards.md  (or .eslintrc.json, pyproject.toml, etc.)

Keep this section brief — bullet points preferred. Full detail lives in the source file.
-->

---

## Spec-Driven Development: {{SDD_FRAMEWORK}}

**Workflow summary:**

{{SDD_WORKFLOW_SUMMARY}}

### SDD Ignore Tags

When a code change is NOT tied to a spec/plan/task (e.g., pure bug fixes, typo corrections, dependency bumps), add one or more ignore tags to the commit message to suppress specific CI checks:

{{IGNORE_TAG_DOCS}}

**Usage example:**
```
fix: correct off-by-one error in pagination [ignore:spec_sync]
chore: bump lodash to 4.17.21 [ignore:all_sdd]
```

---

## Development Conventions

<!-- Add project-specific conventions here as they emerge during development -->
<!-- Examples: naming patterns, file structure decisions, API design rules -->

---

## Architecture Notes

<!-- Add key architectural decisions (ADRs) here as they are made -->
<!-- Format: ## Decision: <title> -->
<!-- Include: context, decision, consequences -->

---

## Known Issues / Tech Debt

<!-- Track items that need future attention but aren't blocking -->

---

## Agent Memory Log

<!-- Agents: append timestamped notes about significant decisions or discoveries here -->
<!-- Format: - [YYYY-MM-DD] <note> -->
