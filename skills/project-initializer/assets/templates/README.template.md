# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

---

## Tech Stack

{{TECH_STACK_LIST}}

---

## Spec-Driven Development

This project uses **{{SDD_FRAMEWORK}}** for spec-driven development.

All planning documents live in `{{SDD_DOCS_PATH}}`.

See `AGENTS.md` for the development workflow and quality standards that agents must follow.

---

## Getting Started

{{GETTING_STARTED_STEPS}}

---

## CI/CD

This project uses GitLab CI. The pipeline has two main stages:

- **commit-check** — runs on every push: linting, unit tests, commit format validation
- **release-check** — runs on merge to `{{MAIN_BRANCH}}`: full test suite, coverage, security scan, and SDD process documentation checks

See `.gitlab-ci.yml` for details.

### SDD Process Checks

On release, the pipeline verifies that code changes are backed by the appropriate SDD process documents (specs, plans, tasks). Developers can suppress individual checks using structured tags in their commit message when the check is not applicable (e.g., a pure bug fix). See `AGENTS.md` → "SDD Ignore Tags" for details.

---

## Contributing

1. Pick a task from the SDD backlog (`{{SDD_DOCS_PATH}}`)
2. Follow the `{{SDD_FRAMEWORK}}` workflow described in `AGENTS.md`
3. Open a merge request targeting `{{MAIN_BRANCH}}`
4. Ensure all CI checks pass

---

## License

<!-- TODO: Add license -->
