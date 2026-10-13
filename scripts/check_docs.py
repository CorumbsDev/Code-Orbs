#!/usr/bin/env python3
"""Falha se README.md ou BUILD.md ficarem para trás da versão e dos exports.

Não reescreve os arquivos. Só compara fatos que já estão no projeto:

- versão do Godot em project.godot e em .github/workflows/godot-ci.yml
- presets usados em --export-release
- nomes dos binários (EXPORT_NAME)

Uso (na raiz): python3 scripts/check_docs.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project.godot"
WORKFLOW = ROOT / ".github" / "workflows" / "godot-ci.yml"
README = ROOT / "README.md"
BUILD = ROOT / "BUILD.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def godot_version(project_text: str) -> str:
    match = re.search(r'config/features=PackedStringArray\("([^"]+)"', project_text)
    if not match:
        raise SystemExit("project.godot: não achei config/features com a versão do Godot.")
    return match.group(1)


def workflow_env(workflow_text: str, key: str) -> str:
    match = re.search(
        rf'^[ \t]*{re.escape(key)}:\s*"?([^"\n]+?)"?\s*$',
        workflow_text,
        re.M,
    )
    if not match:
        raise SystemExit(f"godot-ci.yml: não achei {key}.")
    return match.group(1)


def export_presets(workflow_text: str) -> list[str]:
    return re.findall(r'--export-release\s+"([^"]+)"', workflow_text)


def main() -> int:
    project_text = read(PROJECT)
    workflow_text = read(WORKFLOW)
    readme = read(README)
    build = read(BUILD)

    version = godot_version(project_text)
    ci_version = workflow_env(workflow_text, "GODOT_VERSION")
    export_name = workflow_env(workflow_text, "EXPORT_NAME")
    presets = export_presets(workflow_text)
    binaries = [f"{export_name}.exe", f"{export_name}.x86_64"]

    errors: list[str] = []
    if version != ci_version:
        errors.append(
            f"Versão divergente: project.godot tem {version}, godot-ci.yml tem {ci_version}."
        )
    if version not in readme:
        errors.append(f"README.md não cita o Godot {version}. Atualize a seção Instalação.")
    if version not in build:
        errors.append(f"BUILD.md não cita o Godot {version}.")
    if not presets:
        errors.append("godot-ci.yml não tem --export-release.")
    for preset in presets:
        if preset not in build:
            errors.append(f"BUILD.md não cita o preset de export \"{preset}\".")
    for binary in binaries:
        if binary not in readme:
            errors.append(f"README.md não cita o binário {binary}. Atualize a Instalação.")
        if binary not in build:
            errors.append(f"BUILD.md não cita o binário {binary}.")

    if errors:
        print("Documentação desatualizada em relação ao projeto:")
        for item in errors:
            print(f"- {item}")
        return 1

    print(
        f"Docs ok: Godot {version}, presets {', '.join(presets)}, binários {', '.join(binaries)}."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
