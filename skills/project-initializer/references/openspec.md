# OpenSpec Reference

**Repo:** [github.com/Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec)  
**Install:** `npm install -g @fission-ai/openspec@latest && openspec init`  
**Philosophy:** Fluid, brownfield-first, no phase gates, iterative.

---

## Directory Structure

```
openspec/
├── specs/                              ← Source of truth (main specs)
│   └── <domain>/
│       └── spec.md
└── changes/                            ← Active work in progress
    ├── <change-name>/
    │   ├── proposal.md
    │   ├── design.md
    │   ├── tasks.md                    ← Numbered checklist: - [ ] item
    │   ├── .openspec.yaml
    │   └── specs/                      ← Delta specs only (ADDED/MODIFIED/REMOVED)
    │       └── <domain>/
    │           └── spec.md
    └── archive/
        └── YYYY-MM-DD-<change-name>/
```

**SDD docs path for AGENTS.md:** `openspec/`

---

## Spec Format

`spec.md` uses RFC-2119 keywords:

```markdown
## Requirements
### Requirement: User Authentication
The system SHALL issue a JWT token upon successful login.
#### Scenario: Valid credentials
- GIVEN a user with valid credentials
- WHEN the user submits the login form
- THEN a JWT token is returned
```

Delta specs (in `changes/<name>/specs/`) only contain:

```markdown
## ADDED Requirements
### Requirement: Two-Factor Authentication
...

## MODIFIED Requirements
### Requirement: Session Expiration
...previously 30 minutes, now 15 minutes

## REMOVED Requirements
### Requirement: Remember Me
(Deprecated in favor of 2FA.)
```

---

## Slash Commands

| Command | What it does |
|---------|-------------|
| `/opsx:propose <description>` | Creates change folder + all artifacts in one step |
| `/opsx:explore <topic>` | Investigates codebase; no artifacts created |
| `/opsx:apply <change-name>` | Implements tasks.md items one by one |
| `/opsx:sync <change-name>` | Merges delta specs into main specs (keeps change active) |
| `/opsx:verify <change-name>` | 3-dimensional alignment check (completeness, correctness, coherence) |
| `/opsx:archive <change-name>` | Runs sync if needed, then moves to archive/ |

---

## Sync Workflow

The key command: `/opsx:sync <change-name>`

- Reads `changes/<name>/specs/<domain>/spec.md` (delta)
- Merges ADDED / MODIFIED / REMOVED sections into `specs/<domain>/spec.md`
- Does NOT archive the change — it stays active for further work
- Use when: parallel changes need the updated base; long-running change; want to preview merge

Use `/opsx:archive <change-name>` when done — it calls sync automatically.

---

## SDD Workflow Summary (for AGENTS.md)

Use this block for AGENTS.md's `{{SDD_WORKFLOW_SUMMARY}}`:

```
- Create a change with `/opsx:propose <description>` to scaffold proposal, design, tasks, delta specs
- Implement tasks in `changes/<name>/tasks.md` using `/opsx:apply <change-name>`
- When delta specs are finalized, sync to main: `/opsx:sync <change-name>`  
- Verify alignment with code using `/opsx:verify <change-name>`
- Complete and archive when done: `/opsx:archive <change-name>`
- Main specs live in `openspec/specs/`; active work lives in `openspec/changes/`
```

---

## Ignore Tags (for AGENTS.md)

Use this block for AGENTS.md's `{{IGNORE_TAG_DOCS}}`:

```markdown
| Tag | What it suppresses |
|-----|-------------------|
| `[ignore:all_sdd]` | All OpenSpec SDD checks |
| `[ignore:change_doc]` | Requirement for an active change to exist (use for pure bug fixes) |
| `[ignore:task_check]` | Incomplete tasks.md items check |
| `[ignore:spec_sync]` | Delta spec sync check (use when spec delta intentionally not yet synced) |
```

---

## CLI Commands

```bash
npm install -g @fission-ai/openspec@latest
openspec init                    # initialize project
openspec update                  # regenerate agent instructions
openspec config profile          # switch between core / expanded workflow
openspec list                    # list active changes
openspec status --change <name>  # show artifact + task status
openspec schemas                 # list schemas
```

---

## CI Integration

- CodeRabbit integration available (`.coderabbit.yaml`)
- GitHub Action: `openspec-badge-action` for README badges
- Conventional Commits for all commit messages
