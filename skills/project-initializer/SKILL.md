---
name: project-initializer
description: "Helps users scaffold new projects with production-ready files: README.md, AGENTS.md (agent memory), and CI/CD pipelines (GitLab CI, GitHub Actions, or both). Handles tech stack selection, coding standards ingestion, quality level configuration (demo vs. production), and SDD framework integration (OpenSpec, SpecKit, or GSD). Documentation is generated in Chinese (中文) by default, with support for other languages upon request. Use this skill whenever a user wants to create a new project, initialize a repository, set up CI/CD, choose a spec-driven development workflow, scaffold project files, or asks about project structure and agent memory files. Even if the user only asks about one part (e.g., \"set up CI/CD\" or \"create AGENTS.md\"), use this skill — it ensures all files stay consistent with each other."
---

# Project Initializer

A skill for scaffolding new projects with consistent README.md, AGENTS.md, and CI/CD pipelines — all wired together with an SDD (Spec-Driven Development) framework.

## Overview

The skill does five things:

1. **Interview** — Understand the project's goals, tech stack, coding standards, quality requirements, CI platform(s), and preferred SDD workflow.
2. **Generate** — Create README.md, AGENTS.md, and CI pipeline file(s) from templates.
3. **Integrate** — Install SDD framework tools and initialize project structure; wire coding standards and quality checks into the CI pipeline.
4. **Tag** — Embed a machine-readable project identity tag in AGENTS.md so server-side CI can verify the project was properly initialized.
5. **Verify consistency** — Make sure all generated files agree with each other (same tech stack, same quality gates, same SDD expectations).

---

## Phase 1: Interview

使用 `AskUserQuestion` 与用户进行访谈，了解项目情况。逐个问题与用户交互 — 不要跳过问题或代表用户做出决定。在进入第2阶段（文件生成）前，总结他们的答案并确认理解。

根据已有的上下文信息，可以一次性提出所有问题，也可以在自然对话中分散提问 — 根据情况自行判断。

**必需信息：**

对于以下每个问题，使用 `AskUserQuestion` 与用户交互式提问。不要跳过问题，不要代替用户做决定。当提供建议或默认值时，请通过 `AskUserQuestion` 确认用户同意后再继续。

1. **项目名称和一句话描述** — 使用 `AskUserQuestion`。这个项目是什么？它解决了什么问题？

2. **技术栈** — 编程语言、框架、包管理工具、数据库、部署目标等。使用 `AskUserQuestion` 提示用户。用户表示不确定或要求建议时，根据问题领域提供合理的默认值 — 但通过 `AskUserQuestion` 获得用户确认后再继续。

3. **质量等级** — 使用 `AskUserQuestion` 提问：这是演示/原型项目还是生产项目？
   - *演示*：最小化CI、无覆盖率门槛、无安全扫描、轻量级SDD
   - *生产*：完整CI、覆盖率门槛、安全扫描、严格的SDD对齐检查

4. **SDD框架** — 使用 `AskUserQuestion` 展示所有三个选项，询问团队将使用哪一个。包括下面的描述以帮助他们做出决定。

   | 框架 | 风格 | 适用于 |
   |------|------|--------|
   | **OpenSpec** | 流畅、棕地优先、增量规范 | 现有代码库、个人开发者、迭代工作 |
   | **SpecKit** | 宪法强制、分阶段 | 团队、企业、严格的质量标准 |
   | **GSD** | 基于阶段的路线图、上下文工程 | 想让AI做主力工作的个人开发者 |

   > 选择后，阅读相应的参考文件了解更多细节：
   > - OpenSpec → `references/openspec.md`
   > - SpecKit → `references/speckit.md`
   > - GSD → `references/gsd.md`

5. **CI平台** — 使用 `AskUserQuestion` 提问：应该配置哪些CI系统？
   - *GitLab CI* — 生成 `.gitlab-ci.yml`
   - *GitHub Actions* — 生成 `.github/workflows/ci.yml`
   - *两者* — 生成两个文件，保持一致

6. **主分支名称** — 使用 `AskUserQuestion` 提问哪个分支会触发发布流程。建议用 `main` 作为默认值，但要向用户确认。

7. **编码规范** — 使用 `AskUserQuestion` 提问：团队是否有现有的编码规范、风格指南或代码检查配置？
   - *直接粘贴内容* — 用户将规范粘贴到对话中
   - *文件路径* — 用户提供现有文件的路径（如 `docs/coding-standards.md`、`.eslintrc.json`）
   - *无* — 如果没有，使用技术栈的合理默认值
   
   如果提供了规范，请阅读并总结。规范将被注入到AGENTS.md中，并用于配置CI代码检查命令。

8. **额外质量要求**（生产项目）— 使用 `AskUserQuestion` 提问：
   - 最小测试覆盖率百分比（如 80%）
   - 静态分析工具（如 ESLint、Pylint、SonarQube）— 可能已被编码规范涵盖
   - 安全扫描（Trivy、Semgrep、Bandit等）

9. **文档语言** — 使用 `AskUserQuestion` 提问：README.md和AGENTS.md应该用什么语言编写？默认为中文（中文），除非用户指定其他语言。

---

## Phase 2: File Generation

> **CRITICAL — Template Fidelity:** Reproduce every CI pipeline template verbatim. Substitute only the `{{PLACEHOLDER}}` tokens. Do **not** remove, merge, rename, or omit any stages, jobs, or comment blocks. The complete job set in each template is the minimum viable pipeline; dropping any job will break SDD checks, project-tag validation, or coverage gates. For demo projects, dial down strictness through placeholder values (e.g., set `{{COVERAGE_THRESHOLD}}` to `0`, `{{SECURITY_SCAN_CMD}}` to `echo "skipped"`) — never by removing jobs.

After gathering information, generate files. Use the templates in `assets/templates/` as starting points and fill in the placeholders.

> **Path resolution — read this before running any script:**
> - `<skill_dir>` = the directory that contains this SKILL.md file (e.g. `.agents/skills/project-initializer`). All script paths below are relative to `<skill_dir>`.
> - `<project_root>` = the root of the project being initialized — pass `.` if you are already inside it, or the absolute path if not. **Never pass a path outside the project the user is working on.**

**File locations:**
- `README.md` — project root
- `AGENTS.md` — project root
- `.gitlab-ci.yml` — project root (if GitLab CI selected)
- `.github/workflows/ci.yml` — project root (if GitHub Actions selected)

**Placeholder convention** used in templates: `{{VARIABLE_NAME}}`

After creating all files, do a consistency pass:
- The tech stack in README.md must match AGENTS.md and the CI environment images
- Quality gates in CI files must reflect what's specified in AGENTS.md
- The SDD check script path must match the framework chosen
- Both CI files (if both selected) must use the same quality thresholds, check scripts, and branch names

### README.md

Read `assets/templates/README.template.md`. Fill in:
- `{{PROJECT_NAME}}` — project name
- `{{PROJECT_DESCRIPTION}}` — one-paragraph description
- `{{TECH_STACK_LIST}}` — bulleted list of stack components
- `{{SDD_FRAMEWORK}}` — name of chosen SDD framework
- `{{SDD_DOCS_PATH}}` — where SDD documents live (see framework reference)
- `{{GETTING_STARTED_STEPS}}` — installation and run steps appropriate for the tech stack

**Language**: Generate this file in the language chosen in Phase 1 (default: Chinese/中文).

### AGENTS.md

Read `assets/templates/AGENTS.template.md`. Fill in:
- `{{PROJECT_NAME}}` — project name
- `{{PROJECT_DESCRIPTION}}` — concise single-sentence summary
- `{{TECH_STACK_DETAILS}}` — structured tech stack list with versions if known
- `{{SDD_FRAMEWORK}}` — framework display name (e.g., "OpenSpec")
- `{{SDD_FRAMEWORK_ID}}` — framework lowercase id: `openspec`, `speckit`, or `gsd`
- `{{SDD_WORKFLOW_SUMMARY}}` — 3-5 bullet points describing the team's SDD workflow from the reference doc
- `{{QUALITY_LEVEL}}` — "demo" or "production" (display)
- `{{QUALITY_LEVEL_ID}}` — "demo" or "production" (machine-readable, same as display)
- `{{CI_PLATFORMS_ID}}` — `gitlab`, `github`, or `gitlab,github` (no spaces)
- `{{COVERAGE_THRESHOLD}}` — number (e.g., "80") or "N/A" for demo
- `{{LINT_TOOL}}` — linter/formatter names (from coding standards or tech stack defaults)
- `{{SECURITY_TOOLS}}` — security scan tools or "N/A"
- `{{IGNORE_TAG_DOCS}}` — the git commit ignore tag reference for the chosen framework (see reference docs)
- `{{CODING_STANDARDS_SUMMARY}}` — see Coding Standards Composition section above
- `{{INITIALIZED_DATE}}` — today's date in `YYYY-MM-DD` format
- `{{MAIN_BRANCH}}` — release branch name

**Language**: Generate this file in the language chosen in Phase 1 (default: Chinese/中文).

**Important**: AGENTS.md is a living document. Keep it minimal at creation time. Agents should append to it during development but never remove existing entries. The initial version is just the skeleton — it will grow.

### Coding Standards Composition

If the user provided coding standards:

1. Read the content (from the pasted text or the file path).
2. Extract the key rules relevant to: naming conventions, file structure, formatting, forbidden patterns, and required patterns.
3. Summarize them into the `## Coding Standards` section of AGENTS.md (concise bullet-point form — the full doc lives separately).
4. If the standards specify a linter/formatter config, reference it in the `{{LINT_CMD}}` for CI (e.g., `eslint --config .eslintrc.json`, `ruff check --config pyproject.toml`).
5. If the user provided a file path, also add a reference to that file in AGENTS.md so agents know where the canonical source is.

If no standards were provided, write a minimal placeholder in the Coding Standards section appropriate for the tech stack (e.g., "Follow PEP 8" for Python, "Follow Airbnb JavaScript Style Guide" for JS).

### .gitlab-ci.yml

Read `assets/templates/gitlab-ci.template.yml`. Fill in:
- `{{DOCKER_IMAGE}}` — appropriate base image for the tech stack
- `{{INSTALL_CMD}}` — dependency install command (e.g., `npm ci`, `pip install -r requirements.txt`)
- `{{LINT_CMD}}` — lint/format check command
- `{{TEST_CMD}}` — test run command
- `{{COVERAGE_CMD}}` — coverage report command
- `{{COVERAGE_THRESHOLD}}` — minimum coverage (skip/set to 0 for demo)
- `{{SECURITY_SCAN_CMD}}` — security scan command or `echo "skipped"` for demo
- `{{SDD_CHECK_SCRIPT}}` — path to framework check script: one of:
  - `scripts/check_sdd_openspec.sh`
  - `scripts/check_sdd_speckit.sh`
  - `scripts/check_sdd_gsd.sh`
- `{{MAIN_BRANCH}}` — release branch name (default: `main`)

Run the install script to copy all required check scripts into the project:

    python <skill_dir>/scripts/install_scripts.py <project_root> --framework <fw>

This installs the appropriate runtime variant (`.sh` on Linux/macOS, `.js` as fallback, `.ps1` on Windows) of `check_project_tag` and `check_sdd_<framework>` into `<project_root>/scripts/`. **Do not manually recreate or copy-paste script files** — the install script guarantees the exact asset versions are used without modification. Pass `--dry-run` first to verify what will be copied.

### .github/workflows/ci.yml (if GitHub Actions selected)

Read `assets/templates/github-actions.template.yml`. Fill in the same placeholders as the GitLab template — the values must be identical to ensure both pipelines enforce the same standards.

---

## Phase 3: SDD Framework Installation

> **MANDATORY — do not skip or substitute manually.**
> You MUST run the script below. Do NOT create SDD framework directories or documents by hand. Manually created files will be incomplete, wrongly structured, and will fail CI checks. If the script encounters an error, report it to the user — do not work around it by creating files yourself.

Resolve `<skill_dir>` (the directory containing this SKILL.md) and run:

    python <skill_dir>/scripts/initialize_sdd.py <project_root> --framework <fw> --ai-provider <agent> [--script-shell sh|ps]

If you are already inside the project directory, `<project_root>` is `.`.

**Determining the `--ai-provider` value:** Use the name of the AI agent currently running this skill (e.g. `claude`, `copilot`, `gemini`, `opencode`, `codex`). You know this from your own identity — pass it as-is.

**For SpecKit only — `--script-shell` parameter:** Choose the shell for generated scripts:
- `sh` (default): Unix/shell scripts — use for Linux/macOS CI runners
- `ps`: PowerShell scripts — use for Windows CI runners

This script runs all frameworks **non-interactively**:
- **OpenSpec**: `openspec init --tools <tool_id>` — `--ai-provider` mapped to OpenSpec's tool ID: `claude`, `opencode`, `codex`, `gemini`, `windsurf`, `qwen`, `codebuddy`, `kilocode` use the same name; `copilot`→`github-copilot`; `cursor-agent`→`cursor`; `roo`→`roocode`; all others→`all`
- **SpecKit**: `specify init . --ai <provider> --here --force --script <shell>` — passes the provider name and shell choice directly
- **GSD**: `npx -y get-shit-done-cc@latest --<runtime> --local` — `--ai-provider` is mapped to a runtime flag: `claude`→`--claude`, `opencode`→`--opencode`, `codex`→`--codex`, all others→`--claude`

The script also:
- Installs the framework CLI tool (`npm`, `uv`, or `npx` as appropriate) if not found
- Initializes framework-specific directories
- For **OpenSpec**: initializes `openspec/specs/` and `openspec/changes/`
- For **SpecKit**: initializes `specs/` (auto-numbered) and `memory/constitution.md`
- For **GSD**: initializes `.planning/` with PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, config.json

SpecKit `--ai-provider` supported values: claude, gemini, copilot, cursor-agent, windsurf, opencode, codex, qwen, amp, shai, agy, bob, qodercli, roo, codebuddy, jules, kilocode, generic.

Pass `--dry-run` to preview without installing.

### Prerequisites

| Framework | Requires |
|-----------|----------|
| OpenSpec | `npm` (Node.js) |
| SpecKit | `uv` (Python tool installer) + `git` |
| GSD | `npx` + Node.js ≥18 |

If a required tool is not installed, the script will exit with an error message indicating what needs to be installed.

---

## Phase 4: SDD Check Script

The check script reads the latest git commit message and the project's SDD documents. It enforces documentation consistency.

### Ignore Tag System

Agents and developers can place structured tags in commit messages to suppress specific checks:

```
feat: implement user login [ignore:spec_sync]
fix: typo in variable name [ignore:all_sdd]
```

**Universal tags (all frameworks):**

| Tag | What it suppresses |
|-----|-------------------|
| `[ignore:all_sdd]` | All SDD process checks |

**Framework-specific tags** — see the relevant reference file for the complete list. They follow the pattern `[ignore:<check_name>]`.

### When checks fail

The script exits non-zero and prints a message explaining:
1. What was found (e.g., "3 tasks incomplete in openspec/changes/add-auth/tasks.md")
2. What the developer should do (e.g., `Run /opsx:sync add-auth to sync delta specs`)
3. How to suppress the check if appropriate (e.g., `Add [ignore:spec_sync] to commit message if this is a bug fix not tied to a feature`)

---

## Phase 5: Project Identity Tag

Every project initialized by this skill must have a machine-readable identity tag embedded at the top of `AGENTS.md`. This tag allows server-side CI to:
- Confirm the project was properly initialized (not just a hand-crafted AGENTS.md)
- Know which SDD framework and CI platforms are in use
- Enforce version-specific checks appropriate for the project's configuration

The tag takes the form of a structured HTML comment block (the first thing in the file, before any Markdown):

```
<!-- @project-initializer
version: 1
initialized_at: YYYY-MM-DD
sdd_framework: openspec|speckit|gsd
quality_level: demo|production
ci_platforms: gitlab|github|gitlab,github
project_initializer_version: 1.0.0
-->
```

Rules:
- Always place it as the very first content in `AGENTS.md` (before the `#` heading)
- Use the actual initialization date (today)
- `sdd_framework` — lowercase identifier: `openspec`, `speckit`, or `gsd`
- `ci_platforms` — comma-separated, no spaces: `gitlab`, `github`, or `gitlab,github`
- Do not modify this block after creation except through a deliberate re-initialization

The CI check script (`assets/scripts/check_project_tag.sh`) reads this tag and exits non-zero if it is missing or malformed. It is installed automatically by the `install_scripts.py` step described in Phase 2 — `check_project_tag` is always included regardless of the chosen SDD framework. The framework's initialize script (Phase 3) must complete successfully before this tag is validated.

---

## Phase 6: Consistency Verification

After generating all files, perform this checklist:

- [ ] `AGENTS.md` starts with a valid `<!-- @project-initializer` tag
- [ ] `sdd_framework` in tag matches chosen framework
- [ ] `ci_platforms` in tag matches files actually generated
- [ ] Docker/runner image in CI file(s) matches tech stack
- [ ] `AGENTS.md` tech stack section matches `README.md`
- [ ] Coverage threshold in CI file(s) matches `AGENTS.md` → Quality Standards
- [ ] SDD framework name consistent across all generated files
- [ ] The correct SDD check script is referenced (OpenSpec/SpecKit/GSD)
- [ ] Both CI platform files (if both generated) use identical quality thresholds
- [ ] Branch name in CI rules matches the stated main branch
- [ ] SDD framework initialized successfully (Phase 3)
  - OpenSpec: `openspec/specs/` and `openspec/changes/` exist
  - SpecKit: `specs/` and `memory/constitution.md` exist
  - GSD: `.planning/` contains PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, config.json
- [ ] `scripts/` directory was populated by running `install_scripts.py` (not manually recreated or copy-pasted)
- [ ] The correct single variant (`.sh` on Linux/macOS, `.ps1` on Windows, `.js` as fallback) is present in `scripts/`
- [ ] `.gitlab-ci.yml` (if generated) contains **all** required jobs: `lint`, `unit-tests`, `commit-format`, `full-test-suite`, `coverage-gate`, `security-scan`, `project-tag-check`, `sdd-process-check`, `deploy`
- [ ] `.github/workflows/ci.yml` (if generated) contains **all** required jobs: `lint`, `unit-tests`, `commit-format`, `full-test-suite`, `security-scan`, `project-tag-check`, `sdd-process-check`
- [ ] No jobs were removed or merged compared to the template; only `{{PLACEHOLDER}}` tokens were substituted
- [ ] `AGENTS.md` starts with a valid `<!-- @project-initializer` tag
- [ ] First commit includes: README.md, AGENTS.md, CI files, scripts/, and framework directories

Report any inconsistencies to the user before finishing.

---

## Reference files

- `references/openspec.md` — OpenSpec document structure, sync workflow, ignore tags
- `references/speckit.md` — SpecKit spec lifecycle, constitution, phase gates, ignore tags
- `references/gsd.md` — GSD phase workflow, document set, planning structure, ignore tags

## Installation scripts

All script paths are relative to `<skill_dir>` (the directory containing this SKILL.md). `<project_root>` is the project's root — use `.` if already inside it.

- `scripts/install_scripts.py` — copies check scripts into `<project_root>/scripts/`

  Usage: `python <skill_dir>/scripts/install_scripts.py <project_root> --framework <openspec|speckit|gsd>`

  Always run this instead of manually copying scripts. Add `--dry-run` to preview.

- `scripts/initialize_sdd.py` — installs SDD framework tools and initializes project structure

  Usage: `python <skill_dir>/scripts/initialize_sdd.py <project_root> --framework <openspec|speckit|gsd> --ai-provider <agent>`

  **Must be run — do not manually create SDD directories.** Installs the framework CLI non-interactively, sets up directories. Add `--dry-run` to preview.

## Template files

- `assets/templates/README.template.md`
- `assets/templates/AGENTS.template.md`
- `assets/templates/gitlab-ci.template.yml`
- `assets/templates/github-actions.template.yml`

## Check scripts

Each check is available in three runtime variants, stored in the skill's `assets/scripts/` directory. The install_scripts.py command copies these into the target project's `scripts/` directory — which variant gets invoked in CI depends on the runner OS and what's available.

| Script | Shell (Linux/macOS) | PowerShell (Windows/cross-platform) | Node.js (any platform) |
|--------|--------------------|------------------------------------|------------------------|
| Project tag | `check_project_tag.sh` | `check_project_tag.ps1` | `check_project_tag.js` |
| OpenSpec | `check_sdd_openspec.sh` | `check_sdd_openspec.ps1` | `check_sdd_openspec.js` |
| SpecKit | `check_sdd_speckit.sh` | `check_sdd_speckit.ps1` | `check_sdd_speckit.js` |
| GSD | `check_sdd_gsd.sh` | `check_sdd_gsd.ps1` | `check_sdd_gsd.js` |

### Selecting which variant to use in CI

When generating CI pipeline files, choose the invocation command based on the project's runner environment:

| Runner environment | CI invocation |
|--------------------|--------------|
| Linux / macOS (bash available) | `bash scripts/check_sdd_<fw>.sh` |
| Windows (PowerShell 7+ available) | `pwsh scripts/check_sdd_<fw>.ps1` |
| Any (Node.js ≥ 18 available) | `node scripts/check_sdd_<fw>.js` |
| Unknown / mixed | Use Node.js — it works everywhere Node.js is installed |

The Node.js variants are the most portable choice if the runner environment is uncertain. They require no npm dependencies — only the Node.js built-in modules (`fs`, `path`, `child_process`).

The GitLab CI and GitHub Actions templates default to the shell variant. If the user's CI runners are Windows-based or they prefer Node.js, update the `script:` / `run:` lines accordingly. All three variants implement identical logic and exit codes.
````
