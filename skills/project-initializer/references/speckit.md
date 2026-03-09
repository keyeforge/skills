# SpecKit Reference

**Repo:** [github.com/github/spec-kit](https://github.com/github/spec-kit)  
**Install:** `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git`  
**Philosophy:** Constitution-enforced, phase-gated, TDD-first. Specs are primary artifacts — code is their expression.

---

## Directory Structure

```
<project>/
├── memory/
│   └── constitution.md        ← Immutable architectural DNA (Nine Articles)
└── specs/
    └── NNN-feature-name/      ← Auto-numbered (001, 002, ...)
        ├── spec.md            ← WHAT: requirements & user stories
        ├── plan.md            ← HOW: technical plan, ADRs, Phase -1 gates
        ├── data-model.md      ← Entity schemas
        ├── contracts/         ← API/interface contracts
        ├── research.md        ← Library comparisons, benchmarks
        ├── quickstart.md      ← Key validation scenarios
        └── tasks.md           ← Executable task list ([P] = parallelizable)
```

**SDD docs path for AGENTS.md:** `specs/` and `memory/`

---

## Constitution: The Nine Articles

The `memory/constitution.md` encodes the project's architectural DNA. Key articles:

| Article | Principle |
|---------|-----------|
| I | Library-First — every feature starts as a standalone library |
| II | CLI Interface Mandate — all interfaces must be text-in/text-out |
| III | Test-First Imperative — TDD, non-negotiable, Red → Green → Refactor |
| VII | Simplicity Gate — max 3 projects, no future-proofing |
| VIII | Anti-Abstraction — use framework directly, no superfluous wrapping |
| IX | Integration-First Test — real DBs over mocks, contract tests mandatory |

---

## Phase -1 Pre-Implementation Gates

Every `plan.md` must pass these gates before implementation:

```markdown
### Phase -1: Pre-Implementation Gates
#### Simplicity Gate (Article VII)
- [ ] Using ≤3 projects?
- [ ] No future-proofing?
#### Anti-Abstraction Gate (Article VIII)
- [ ] Using framework directly?
- [ ] Single model representation?
#### Integration-First Gate (Article IX)
- [ ] Contracts defined?
- [ ] Contract tests written?
```

The CI check (`check_sdd_speckit.sh`) validates these checkboxes are all checked `[x]` before releasing.

---

## `spec.md` Format

Focus on WHAT users need and WHY. No implementation details.

```markdown
## User Story
As a [user type], I want to [goal] so that [reason].

## Requirements
- REQ-001: The system shall [requirement]
- REQ-002: ...

## Acceptance Criteria
- [ ] [testable criterion]

## Out of Scope
- [explicitly excluded features]
```

Mark any ambiguities for resolution:
```markdown
[NEEDS CLARIFICATION: Which auth provider should this integrate with?]
```

The CI check flags any unresolved `[NEEDS CLARIFICATION:]` markers.

---

## `tasks.md` Format

```markdown
## Tasks

### Group 1: Database setup (sequential)
- [ ] Create migrations for user table
- [ ] Add indexes for email lookup
- [ ] Write contract tests for user repository

### Group 2: API layer [P] (parallelizable)
- [ ] [P] Implement POST /users endpoint
- [ ] [P] Implement GET /users/:id endpoint

### Group 3: Integration
- [ ] Wire endpoint to repository
- [ ] Integration tests pass against real DB
```

---

## CLI Commands

```bash
# Install
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# Initialize project with Claude Code as the AI agent
specify init <PROJECT_NAME> --ai claude
specify init . --ai claude   # current directory

# Check installed tools
specify check

# Upgrade
uv tool install specify-cli --force --from git+https://github.com/github/spec-kit.git
```

**`--ai` options:** claude, gemini, copilot, cursor-agent, windsurf, opencode, codex, qwen, amp, shai, agy, bob, qodercli, roo, codebuddy, jules, kilocode, generic

---

## SDD Workflow Summary (for AGENTS.md)

Use this block for AGENTS.md's `{{SDD_WORKFLOW_SUMMARY}}`:

```
- All new features start with a spec in `specs/NNN-feature-name/`
- Write spec.md first (WHAT/WHY, no implementation); resolve all [NEEDS CLARIFICATION:] markers
- Write plan.md with Phase -1 gates; complete all gate checkboxes before coding
- Follow TDD: write failing tests → implement → green (Article III is non-negotiable)
- Mark tasks with [P] in tasks.md where parallel execution is safe
- Constitution in `memory/constitution.md` governs all architectural decisions
```

---

## Ignore Tags (for AGENTS.md)

Use this block for AGENTS.md's `{{IGNORE_TAG_DOCS}}`:

```markdown
| Tag | What it suppresses |
|-----|-------------------|
| `[ignore:all_sdd]` | All SpecKit SDD checks |
| `[ignore:spec_doc]` | Requirement for a spec directory to exist |
| `[ignore:spec_complete]` | Unresolved [NEEDS CLARIFICATION:] marker check |
| `[ignore:phase_gates]` | Phase -1 Pre-Implementation Gates check |
| `[ignore:task_check]` | Unchecked tasks.md items check |
```
