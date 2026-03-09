# GSD (Get Shit Done) Reference

**Repo:** [github.com/gsd-build/get-shit-done](https://github.com/gsd-build/get-shit-done)  
**Install:** `npx get-shit-done-cc@latest`  
**Philosophy:** Phase-based roadmap, context-engineering, multi-agent orchestration. Solves context rot.

---

## Directory Structure

```
<project>/
└── .planning/
    ├── PROJECT.md              ← Project vision (always loaded)
    ├── REQUIREMENTS.md         ← Scoped v1/v2 requirements with phase traceability
    ├── ROADMAP.md              ← Phases and status
    ├── STATE.md                ← Decisions, blockers, session memory
    ├── config.json             ← GSD configuration
    ├── <N>-CONTEXT.md          ← Phase N: implementation decisions (from /gsd:discuss-phase)
    ├── <N>-RESEARCH.md         ← Phase N: domain research (from /gsd:plan-phase)
    ├── <N>-<M>-PLAN.md         ← Phase N, plan M: atomic task with XML structure
    ├── <N>-<M>-SUMMARY.md      ← Phase N, plan M: what happened, what changed
    ├── <N>-VERIFICATION.md     ← Phase N: goals verification (from /gsd:verify-work)
    ├── <N>-UAT.md              ← Phase N: user acceptance testing results
    └── quick/
        └── NNN-<task-slug>/
            ├── PLAN.md
            └── SUMMARY.md
```

**SDD docs path for AGENTS.md:** `.planning/`

---

## Core Workflow

```
/gsd:new-project          ← Interview → research → requirements → roadmap
/gsd:discuss-phase N      ← Capture implementation decisions
/gsd:plan-phase N         ← Research + create atomic plans + verify plans
/gsd:execute-phase N      ← Execute plans in parallel waves + auto-commit
/gsd:verify-work N        ← User acceptance testing
/gsd:complete-milestone   ← Archive milestone, tag release
```

### Quick mode (ad-hoc tasks, bug fixes)

```
/gsd:quick                ← Ad-hoc task with GSD guarantees (atomic commits, state tracking)
```

---

## Plan Format (XML)

Plans (`<N>-<M>-PLAN.md`) use XML structure for precision:

```xml
<task type="auto">
  <name>Create login endpoint</name>
  <files>src/app/api/auth/login/route.ts</files>
  <action>
    Use jose for JWT (not jsonwebtoken - CommonJS issues).
    Validate credentials against users table.
    Return httpOnly cookie on success.
  </action>
  <verify>curl -X POST localhost:3000/api/auth/login returns 200 + Set-Cookie</verify>
  <done>Valid credentials return cookie, invalid return 401</done>
</task>
```

---

## STATE.md Format

STATE.md tracks session memory. Use `[BLOCKER]` for blocking issues (CI checks for these):

```markdown
## Current Position
Phase 2, Plan 3 — Auth API

## Key Decisions
- Using Prisma over raw SQL for type safety
- JWT stored in httpOnly cookies (not localStorage)

## Blockers
- [BLOCKER] Need DB schema approval from team before Phase 3

## Notes
- Discovered: pagination is needed for /users endpoint (added to Phase 3 scope)
```

---

## Commit Convention

GSD uses automatic commits per task:

```
feat(08-02): implement user registration endpoint
docs(08-02): complete user registration plan
```

Pattern: `type(phase-plan): description`

---

## Configuration (`.planning/config.json`)

```json
{
  "mode": "interactive",
  "depth": "standard",
  "workflow": {
    "research": true,
    "plan_check": true,
    "verifier": true,
    "auto_advance": false
  },
  "parallelization": { "enabled": true },
  "git": {
    "branching_strategy": "none"
  }
}
```

---

## SDD Workflow Summary (for AGENTS.md)

Use this block for AGENTS.md's `{{SDD_WORKFLOW_SUMMARY}}`:

```
- Initialize with `/gsd:new-project` to generate PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md
- For each phase: discuss → plan → execute → verify (/gsd:discuss-phase → /gsd:plan-phase → /gsd:execute-phase → /gsd:verify-work)
- Plans are atomic XML tasks; each gets its own commit automatically
- STATE.md is your memory across sessions — update it with decisions and blockers
- Use `/gsd:quick` for ad-hoc tasks and bug fixes (no full planning cycle)
- Complete milestones with `/gsd:complete-milestone`; tag releases automatically
```

---

## Ignore Tags (for AGENTS.md)

Use this block for AGENTS.md's `{{IGNORE_TAG_DOCS}}`:

```markdown
| Tag | What it suppresses |
|-----|-------------------|
| `[ignore:all_sdd]` | All GSD SDD checks |
| `[ignore:plan_doc]` | Core planning documents existence check (PROJECT.md etc.) |
| `[ignore:phase_summary]` | Missing SUMMARY.md for executed plans |
| `[ignore:state_blockers]` | Active [BLOCKER] entries in STATE.md |
| `[ignore:phase_verify]` | Missing VERIFICATION.md for completed phases |
```

---

## Navigation Commands

```bash
/gsd:progress    # where am I? what's next?
/gsd:help        # all commands
/gsd:update      # update GSD to latest
/gsd:resume-work # restore from last session
/gsd:pause-work  # create handoff when stopping mid-phase
```

---

## Useful Settings

```bash
/gsd:set-profile quality   # use Opus for all agents
/gsd:set-profile balanced  # Opus orchestrator, Sonnet workers (default)
/gsd:set-profile budget    # Sonnet throughout
/gsd:settings              # configure all options interactively
```
