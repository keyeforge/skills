#!/usr/bin/env python3
"""initialize_sdd.py

Initialize the SDD framework directories and install required tools for an existing project.

This script:
1. Installs the framework CLI tool globally (npm, uv, or npx as appropriate)
2. Initializes the framework-specific directory structures in a non-interactive way
3. Validates the result

Usage:
    python initialize_sdd.py <project_root> --framework openspec [--ai-provider claude]
    python initialize_sdd.py <project_root> --framework speckit --ai-provider <provider> [--script-shell sh|ps]

Arguments:
    project_root        Absolute or relative path to the target project root.

Options:
    --framework         SDD framework: openspec, speckit, or gsd  [required]
    --ai-provider       AI agent/provider running this script (default: claude).
                        Used to select non-interactive initialization flags.
                        OpenSpec maps to --tools <id>: claude, opencode, codex, gemini,
                            copilot→github-copilot, cursor-agent→cursor, windsurf, qwen,
                            roo→roocode, codebuddy, kilocode; all others→all
                        SpecKit accepts: claude, gemini, copilot, cursor-agent, windsurf,
                            opencode, codex, qwen, amp, shai, agy, bob, qodercli, roo,
                            codebuddy, jules, kilocode, generic
                        GSD maps: claude→--claude, opencode→--opencode, codex→--codex,
                            all others→--claude (default)
    --script-shell      For SpecKit: shell for generated scripts (default: sh).
                        Valid values: sh, ps (PowerShell)
    --dry-run           Print commands without executing them.

Requirements:
    OpenSpec:  npm (Node.js package manager)
    SpecKit:   uv (Python tool installer) and git
    GSD:       npx and Node.js ≥18

Example:
    python initialize_sdd.py . --framework gsd --ai-provider claude
    python initialize_sdd.py /path/to/project --framework speckit --ai-provider gemini --dry-run
    python initialize_sdd.py /path/to/project --framework gsd --ai-provider opencode
"""

import argparse
import subprocess
import sys
from pathlib import Path

FRAMEWORKS = ("openspec", "speckit", "gsd")
# Map framework to valid AI provider choices
AI_PROVIDERS = {
    "speckit": (
        "claude", "gemini", "copilot", "cursor-agent", "windsurf", "opencode",
        "codex", "qwen", "amp", "shai", "agy", "bob", "qodercli", "roo", "codebuddy",
        "jules", "kilocode", "generic"
    ),
}

# OpenSpec --tools flag: map provider name to OpenSpec tool ID.
# Providers not listed here fall back to "all" (installs integrations for every tool).
OPENSPEC_TOOL_MAP: dict[str, str] = {
    "claude": "claude",
    "opencode": "opencode",
    "codex": "codex",
    "gemini": "gemini",
    "copilot": "github-copilot",
    "cursor-agent": "cursor",
    "windsurf": "windsurf",
    "qwen": "qwen",
    "roo": "roocode",
    "codebuddy": "codebuddy",
    "kilocode": "kilocode",
}

# GSD only supports three named runtimes; all other agents fall back to claude.
GSD_RUNTIME_MAP: dict[str, str] = {
    "claude": "claude",
    "opencode": "opencode",
    "codex": "codex",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Initialize SDD framework tools and directories.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "project_root",
        help="Path to the target project root directory.",
    )
    parser.add_argument(
        "--framework",
        required=True,
        choices=FRAMEWORKS,
        metavar="FRAMEWORK",
        help=f"SDD framework to initialize: {', '.join(FRAMEWORKS)}  [required]",
    )
    parser.add_argument(
        "--ai-provider",
        default="claude",
        metavar="PROVIDER",
        help="AI provider for SpecKit initialization (default: claude). "
             "See script docstring for full list.",
    )
    parser.add_argument(
        "--script-shell",
        default="sh",
        choices=["sh", "ps"],
        metavar="SHELL",
        help="For SpecKit: shell for generated scripts (default: sh). "
             "Valid values: sh, ps (PowerShell).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands without executing them.",
    )
    return parser.parse_args()


def run_command(cmd: list[str], description: str, dry_run: bool) -> bool:
    """
    Run a shell command, printing output in real-time.
    Return True on success, False on failure.
    """
    if dry_run:
        print(f"[dry-run] {description}")
        print(f"[dry-run]   {' '.join(cmd)}\n")
        return True

    print(f"{description}...")
    try:
        result = subprocess.run(
            cmd,
            check=True,
            text=True,
            capture_output=False,
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Command failed with exit code {e.returncode}", file=sys.stderr)
        return False
    except FileNotFoundError:
        print(f"ERROR: Command not found. Make sure {cmd[0]} is installed.", file=sys.stderr)
        return False


def run_command_capture(cmd: list[str], description: str, dry_run: bool) -> tuple[bool, str]:
    """
    Run a shell command and capture output.
    Return (success, output).
    """
    if dry_run:
        print(f"[dry-run] {description}")
        print(f"[dry-run]   {' '.join(cmd)}\n")
        return True, ""

    try:
        result = subprocess.run(
            cmd,
            check=True,
            text=True,
            capture_output=True,
        )
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        print(f"ERROR: {description} failed\n{e.stderr}", file=sys.stderr)
        return False, ""
    except FileNotFoundError:
        return False, ""


def init_openspec(project_root: Path, ai_provider: str, dry_run: bool) -> bool:
    """Initialize OpenSpec non-interactively via openspec init --tools <tool_id>.

    `openspec init` without flags is interactive (Human-Only per docs).
    Passing --tools <id> skips all prompts.

    Provider → tool ID mapping:
      claude, opencode, codex, gemini, windsurf, qwen, codebuddy, kilocode → same name
      copilot       → github-copilot
      cursor-agent  → cursor
      roo           → roocode
      others        → all  (installs integrations for every supported tool)
    """
    print("\n=== OpenSpec Initialization ===\n")

    tool_id = OPENSPEC_TOOL_MAP.get(ai_provider, "all")
    print(f"OpenSpec tool flag: --tools {tool_id} (ai_provider={ai_provider!r})")

    # Check if openspec CLI is available
    success, _ = run_command_capture(["openspec", "--version"], "Check OpenSpec CLI", dry_run)

    if not success:
        print("Installing @fission-ai/openspec globally...")
        if not run_command(
            ["npm", "install", "-g", "@fission-ai/openspec@latest"],
            "Install @fission-ai/openspec globally",
            dry_run,
        ):
            print("ERROR: Failed to install OpenSpec.", file=sys.stderr)
            return False

    # Run openspec init non-interactively in project root
    orig_cwd = Path.cwd()
    try:
        import os
        os.chdir(project_root)
        if not run_command(
            ["openspec", "init", "--tools", tool_id],
            f"Initialize OpenSpec (tools: {tool_id}, non-interactive)",
            dry_run,
        ):
            print("ERROR: OpenSpec initialization failed.", file=sys.stderr)
            return False
    finally:
        import os
        os.chdir(orig_cwd)

    if not dry_run:
        # Verify structure
        if (project_root / "openspec").exists():
            print(f"✓ OpenSpec initialized in {project_root / 'openspec'}")
        else:
            print(f"WARNING: OpenSpec directory not found after initialization", file=sys.stderr)

    return True


def init_speckit(project_root: Path, ai_provider: str, script_shell: str, dry_run: bool) -> bool:
    """Initialize SpecKit: install specify CLI and run specify init.
    
    Args:
        project_root: Path to project root
        ai_provider: AI provider name (e.g., 'claude', 'gemini')
        script_shell: Shell for generated scripts ('sh' or 'ps')
        dry_run: Whether to run in dry-run mode
    """
    print("\n=== SpecKit Initialization ===\n")

    # Check if specify CLI is available
    success, _ = run_command_capture(["specify", "--version"], "Check SpecKit CLI", dry_run)

    if not success:
        print("Installing specify-cli globally via uv...")
        if not run_command(
            ["uv", "tool", "install", "specify-cli", "--from",
             "git+https://github.com/github/spec-kit.git"],
            "Install specify-cli globally",
            dry_run,
        ):
            print("ERROR: Failed to install SpecKit.", file=sys.stderr)
            print("Make sure 'uv' is installed: https://github.com/astral-sh/uv", file=sys.stderr)
            return False

    # Run specify init in project root
    orig_cwd = Path.cwd()
    try:
        import os
        os.chdir(project_root)
        if not run_command(
            ["specify", "init", ".", "--ai", ai_provider, "--here", "--force", "--script", script_shell],
            f"Initialize SpecKit with {ai_provider} (script shell: {script_shell})",
            dry_run,
        ):
            print("ERROR: SpecKit initialization failed.", file=sys.stderr)
            return False
    finally:
        import os
        os.chdir(orig_cwd)

    if not dry_run:
        # Verify structure
        if (project_root / "specs").exists():
            print(f"✓ SpecKit initialized in {project_root / 'specs'} and {project_root / 'memory'}")
        else:
            print(f"WARNING: SpecKit spec directory not found after initialization", file=sys.stderr)

    return True


def init_gsd(project_root: Path, ai_provider: str, dry_run: bool) -> bool:
    """Initialize GSD non-interactively via npx get-shit-done-cc@latest.

    Passes the appropriate runtime flag so the tool never prompts interactively:
      claude   → --claude
      opencode → --opencode
      codex    → --codex
      others   → --claude  (safe default)
    """
    print("\n=== GSD Initialization ===\n")

    runtime = GSD_RUNTIME_MAP.get(ai_provider, "claude")
    print(f"GSD runtime flag: --{runtime} (ai_provider={ai_provider!r})")

    # Run non-interactively: --<runtime> selects the agent, --local installs into
    # the current project directory rather than globally.
    orig_cwd = Path.cwd()
    try:
        import os
        os.chdir(project_root)

        success = run_command(
            ["npx", "-y", "get-shit-done-cc@latest", f"--{runtime}", "--local"],
            f"Initialize GSD (runtime: {runtime}, non-interactive, local)",
            dry_run,
        )

        if not success:
            print("\nnpx initialization failed. Creating base .planning/ structure...\n")
            if not dry_run:
                create_gsd_structure(project_root)
    finally:
        import os
        os.chdir(orig_cwd)

    if not dry_run:
        if (project_root / ".planning").exists():
            print(f"✓ GSD initialized in {project_root / '.planning'}")
        else:
            print(f"WARNING: .planning directory not found after initialization", file=sys.stderr)

    return True


def create_gsd_structure(project_root: Path) -> None:
    """Create minimal GSD .planning/ structure."""
    planning_dir = project_root / ".planning"
    planning_dir.mkdir(exist_ok=True)

    # Create minimal core files
    files = {
        "PROJECT.md": """# Project
        
[Project vision and goals go here]
""",
        "REQUIREMENTS.md": """# Requirements

## Phase 1
[Phase 1 requirements here]
""",
        "ROADMAP.md": """# Roadmap

## Phases
- Phase 1: [Phase 1 goals]
""",
        "STATE.md": """# State

## Current Position
Project initialized. Ready to begin.

## Key Decisions

## Blockers

## Notes
""",
        "config.json": """{
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
""",
    }

    for filename, content in files.items():
        filepath = planning_dir / filename
        if not filepath.exists():
            filepath.write_text(content)
            print(f"  + {filepath}")


def main() -> None:
    args = parse_args()

    project_root = Path(args.project_root).resolve()

    # Validate project root
    if not project_root.is_dir():
        print(
            f"ERROR: Project root does not exist: {project_root}",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"Project root : {project_root}")
    print(f"Framework    : {args.framework}")
    print(f"AI provider  : {args.ai_provider}")
    if args.dry_run:
        print("Mode         : dry-run\n")
    else:
        print()

    # Dispatch to framework-specific initializer
    success = False
    if args.framework == "openspec":
        success = init_openspec(project_root, args.ai_provider, args.dry_run)
    elif args.framework == "speckit":
        success = init_speckit(project_root, args.ai_provider, args.script_shell, args.dry_run)
    elif args.framework == "gsd":
        success = init_gsd(project_root, args.ai_provider, args.dry_run)

    if not success:
        print("\n❌ Initialization failed.", file=sys.stderr)
        sys.exit(1)

    if not args.dry_run:
        print("\n✓ SDD framework initialized successfully!")
        print(f"   Next: commit .gitignore, {args.framework}/ directories, and scripts/ to your repository.")


if __name__ == "__main__":
    main()
