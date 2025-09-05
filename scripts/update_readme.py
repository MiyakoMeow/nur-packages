#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent
PKGS_DIR = REPO_ROOT / "pkgs"
README = REPO_ROOT / "README.md"
GITHUB_REPO = "MiyakoMeow/nur-packages"
DEFAULT_BRANCH = "main"
DEFAULT_SYSTEM = os.environ.get("NIX_SYSTEM", "x86_64-linux")

BEGIN_MARK = "<!-- BEGIN_PACKAGE_LIST -->"
END_MARK = "<!-- END_PACKAGE_LIST -->"


def run(cmd: List[str], cwd: Optional[Path] = None) -> Tuple[int, str, str]:
    proc = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    return proc.returncode, proc.stdout, proc.stderr


def nix_eval_for_pkg(
    package_file: Path, system: str = DEFAULT_SYSTEM
) -> Dict[str, Optional[str]]:
    # Evaluate derivation metadata using flake-pinned nixpkgs
    expr = (
        """
let
  flake = builtins.getFlake "path:{repo}";
  pkgs = import flake.inputs.nixpkgs {{ system = "{system}"; }};
  lib = pkgs.lib;
  drv = pkgs.callPackage {pkg} {{}};
  getName = v: if v ? pname then v.pname else lib.getName v;
  getVersion = v: if v ? version then v.version else lib.getVersion v;
  getDesc = v: if v ? meta && v.meta ? description then v.meta.description else (if v ? description then v.description else "");
 in {{ pname = getName drv; version = getVersion drv; description = getDesc drv; }}
"""
    ).format(repo=str(REPO_ROOT), system=system, pkg=str(package_file))
    code, out, err = run(
        [
            "nix",
            "eval",
            "--json",
            "--extra-experimental-features",
            "nix-command flakes",
            "--expr",
            expr,
        ],
        cwd=REPO_ROOT,
    )
    if code != 0:
        raise RuntimeError(
            f"nix eval failed for {package_file}: {err}\nExpression was:\n{expr}"
        )
    return json.loads(out)


essential_groups_order = [
    # Prefer showing by-name first (flat, common lookup)
    "by-name",
]


def find_packages() -> Dict[str, List[Dict[str, str]]]:
    groups: Dict[str, List[Dict[str, str]]] = {}

    # 1) Nested groups under pkgs/, excluding by-name
    for entry in sorted(PKGS_DIR.iterdir()):
        if not entry.is_dir():
            continue
        if entry.name == "by-name":
            continue
        group = entry.name

        # Direct package at group root
        direct_pkg = None
        if (entry / "package.nix").is_file():
            direct_pkg = entry / "package.nix"
        elif (entry / "default.nix").is_file():
            direct_pkg = entry / "default.nix"
        if direct_pkg:
            groups.setdefault(group, []).append(
                {
                    "usable_path": group,
                    "file": os.path.relpath(direct_pkg, REPO_ROOT),
                }
            )

        # Subdirectory packages
        for sub in sorted(entry.iterdir()):
            if not sub.is_dir():
                continue
            pkg_file = None
            if (sub / "package.nix").is_file():
                pkg_file = sub / "package.nix"
            elif (sub / "default.nix").is_file():
                pkg_file = sub / "default.nix"
            if pkg_file:
                usable_path = f"{group}.{sub.name}"
                groups.setdefault(group, []).append(
                    {
                        "usable_path": usable_path,
                        "file": os.path.relpath(pkg_file, REPO_ROOT),
                    }
                )

    # 2) by-name packages
    by_name_root = PKGS_DIR / "by-name"
    if by_name_root.is_dir():
        for prefix in sorted(by_name_root.iterdir()):
            if not prefix.is_dir():
                continue
            for pkgdir in sorted(prefix.iterdir()):
                if not pkgdir.is_dir():
                    continue
                pkg_file = pkgdir / "package.nix"
                if pkg_file.is_file():
                    groups.setdefault("by-name", []).append(
                        {
                            "usable_path": pkgdir.name,  # flat attr exposed by collectPackages using pname/name
                            "file": os.path.relpath(pkg_file, REPO_ROOT),
                        }
                    )
    return groups


def build_markdown(groups: Dict[str, List[Dict[str, str]]]) -> str:
    lines: List[str] = []
    lines.append("This section is auto-generated. Do not edit manually.")
    lines.append("")
    lines.append(f"Last updated: {datetime.utcnow().isoformat(timespec='seconds')}Z")
    lines.append("")

    # Determine order: by-name first, then other groups alphabetically
    ordered_groups = [g for g in essential_groups_order if g in groups] + [
        g for g in sorted(groups.keys()) if g not in essential_groups_order
    ]

    for group in ordered_groups:
        entries = sorted(groups[group], key=lambda x: x["usable_path"].lower())

        rows: List[Tuple[str, str, str, str]] = []  # usable_path, version, desc, file
        for e in entries:
            file_rel = e["file"]
            meta = nix_eval_for_pkg(REPO_ROOT / file_rel)
            version = meta.get("version") or "-"
            desc = meta.get("description") or ""
            rows.append((e["usable_path"], version, desc, file_rel))

        if not rows:
            continue

        lines.append(f"### {group}")
        lines.append("")
        # Use user's wording: useable-path
        lines.append("| useable-path | version | description |")
        lines.append("| --- | --- | --- |")
        for usable, version, desc, file_rel in rows:
            file_url = (
                f"https://github.com/{GITHUB_REPO}/blob/{DEFAULT_BRANCH}/{file_rel}"
            )
            lines.append(f"| `{usable}` | [{version}]({file_url}) | {desc} |")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def update_readme(content: str) -> None:
    text = README.read_text(encoding="utf-8")

    if BEGIN_MARK in text and END_MARK in text:
        pattern = re.compile(
            re.escape(BEGIN_MARK) + r"[\s\S]*?" + re.escape(END_MARK), re.MULTILINE
        )
        new_block = BEGIN_MARK + "\n\n" + content + "\n" + END_MARK
        text = pattern.sub(new_block, text)
    else:
        heading_regex = re.compile(r"(^## Package List\s*$)", re.MULTILINE)
        if heading_regex.search(text):
            insert_block = BEGIN_MARK + "\n\n" + content + "\n" + END_MARK
            text = heading_regex.sub(r"\1\n\n" + insert_block, text)
        else:
            insert_block = (
                "\n\n## Package List\n\n"
                + BEGIN_MARK
                + "\n\n"
                + content
                + "\n"
                + END_MARK
                + "\n"
            )
            text = text.rstrip() + insert_block

    README.write_text(text, encoding="utf-8")


def main() -> int:
    groups = find_packages()
    md = build_markdown(groups)
    update_readme(md)
    return 0


if __name__ == "__main__":
    sys.exit(main())
