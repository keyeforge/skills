#!/usr/bin/env python3
"""install_scripts.py

Copy project-initializer check scripts from the skill's assets/scripts/ directory
into the target project's scripts/ directory.

Only the single most appropriate runtime variant of each script is installed,
based on the current operating system and available shells:

  Priority: .sh  (Linux/macOS with bash)
         → .js  (any OS with Node.js — cross-platform fallback)
         → .ps1 (Windows without bash)

Usage:
    python scripts/install_scripts.py <project_root> --framework <openspec|speckit|gsd>

Arguments:
    project_root        Absolute or relative path to the target project root.

Options:
    --framework         SDD framework: openspec, speckit, or gsd  [required]
    --scripts-dir       Subdirectory inside project_root for scripts
                        (default: scripts)
    --dry-run           Print what would be copied without creating any files.

Installed scripts (one variant each):
    check_project_tag.{sh|js|ps1}       — AGENTS.md identity tag validation
    check_sdd_<framework>.{sh|js|ps1}   — SDD process documentation checks

Example:
    python .agents/skills/project-initializer/scripts/install_scripts.py . --framework gsd
    python .agents/skills/project-initializer/scripts/install_scripts.py /path/to/project --framework openspec --dry-run
"""

import argparse
import shutil
import stat
import sys
from pathlib import Path

FRAMEWORKS = ("openspec", "speckit", "gsd")

# Variant priority: sh (Unix with bash) > js (cross-platform Node) > ps1 (Windows)
_VARIANT_PRIORITY = (".sh", ".js", ".ps1")

# Required scripts: always-installed base names
ALWAYS_INSTALL = ["check_project_tag"]


def _pick_variant(src_dir: Path, base: str) -> str | None:
    """Return the best available script extension for *base* given the current OS.

    Selection order on Linux/macOS: .sh → .js → .ps1
    Selection order on Windows:     .ps1 → .js → .sh
    Returns None if no variant exists.
    """
    if sys.platform == "win32":
        priority = (".ps1", ".js", ".sh")
    elif shutil.which("bash"):
        priority = (".sh", ".js", ".ps1")
    else:
        priority = (".js", ".sh", ".ps1")

    for ext in priority:
        if (src_dir / (base + ext)).exists():
            return ext
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Copy project-initializer check scripts into a target project.",
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
        help=f"SDD framework to install check scripts for: {', '.join(FRAMEWORKS)}  [required]",
    )
    parser.add_argument(
        "--scripts-dir",
        default="scripts",
        metavar="DIR",
        help="Subdirectory inside project_root where scripts will be placed (default: scripts).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be copied without creating any files.",
    )
    return parser.parse_args()


def collect_files(src_dir: Path, framework: str) -> list[Path]:
    """Return the list of source script files to install (one per base name)."""
    bases = ALWAYS_INSTALL + [f"check_sdd_{framework}"]
    files: list[Path] = []

    for base in bases:
        ext = _pick_variant(src_dir, base)
        if ext is None:
            print(
                f"ERROR: No variants found for '{base}' in {src_dir} — aborting.",
                file=sys.stderr,
            )
            sys.exit(1)
        files.append(src_dir / (base + ext))

    return files


def make_executable(path: Path) -> None:
    """Add user/group/other execute permission to a file (no-op on non-Unix)."""
    try:
        current_mode = path.stat().st_mode
        path.chmod(current_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    except NotImplementedError:
        pass  # Windows: chmod is a no-op, skip silently


def install(files: list[Path], dest_dir: Path, dry_run: bool) -> None:
    if dry_run:
        print(f"[dry-run] Would create: {dest_dir}/")
        for src in files:
            print(f"[dry-run]   {src.name}  →  {dest_dir / src.name}")
        print(f"\n[dry-run] {len(files)} file(s) would be installed.")
        return

    dest_dir.mkdir(parents=True, exist_ok=True)
    installed: list[Path] = []

    for src in files:
        dest = dest_dir / src.name
        shutil.copy2(src, dest)
        if src.suffix == ".sh":
            make_executable(dest)
        installed.append(dest)
        print(f"  + {dest}")

    print(f"\nDone. {len(installed)} script file(s) installed to {dest_dir}/")
    print(
        "\nNext step: commit the scripts/ directory to your repository so CI runners can access it."
    )


def main() -> None:
    args = parse_args()

    # Resolve paths
    # This script lives in skills/project-initializer/scripts/
    # The check scripts live in skills/project-initializer/assets/scripts/
    skill_root = Path(__file__).parent.parent   # project-initializer/
    src_dir = skill_root / "assets" / "scripts"
    project_root = Path(args.project_root).resolve()
    dest_dir = project_root / args.scripts_dir

    # Validate source
    if not src_dir.is_dir():
        print(
            f"ERROR: Source scripts directory not found: {src_dir}\n"
            "Make sure you are running this script from within the project-initializer skill directory.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Validate project root exists
    if not project_root.is_dir():
        print(
            f"ERROR: Project root does not exist: {project_root}",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"Project root : {project_root}")
    print(f"Framework    : {args.framework}")
    print(f"Scripts dir  : {dest_dir}")
    if args.dry_run:
        print("Mode         : dry-run\n")
    else:
        print()

    files = collect_files(src_dir, args.framework)
    install(files, dest_dir, args.dry_run)


if __name__ == "__main__":
    main()
