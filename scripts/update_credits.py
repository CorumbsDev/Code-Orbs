#!/usr/bin/env python3
"""Atualiza CREDITS com autores do Git, sem apagar descrições já escritas.

Uso (na raiz do repositório):
    python3 scripts/update_credits.py
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CREDITS = ROOT / "CREDITS"

HEADER = """\
	This is a credits file of people who have contributed to the
	Code Orbs project. It is sorted by name and formatted to allow
	easy grepping. The fields are: name (N), email (E) and
	description (D).
	Thanks,

			Code Orbs
----------
"""

DEFAULT_DESCRIPTION = (
    "Contribuições no repositório. Atualize esta descrição no CREDITS."
)

SKIP_EMAIL_SUFFIXES = (
    "[bot]@users.noreply.github.com",
)
SKIP_NAME_MARKERS = ("[bot]",)


def git_authors() -> list[tuple[str, str]]:
    log = subprocess.run(
        ["git", "log", "--use-mailmap", "--format=%aN\t%aE"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    seen: dict[str, str] = {}
    for line in log.stdout.splitlines():
        if "\t" not in line:
            continue
        name, email = line.split("\t", 1)
        name = name.strip()
        email = email.strip()
        if not name or not email:
            continue
        if any(marker in name for marker in SKIP_NAME_MARKERS):
            continue
        if email.lower().endswith(SKIP_EMAIL_SUFFIXES):
            continue
        seen.setdefault(email.lower(), name)
    return [(seen[email], email) for email in seen]


def parse_entries(text: str) -> dict[str, dict]:
    if "----------" in text:
        body = text.split("----------", 1)[1]
    else:
        body = text
    entries: dict[str, dict] = {}
    current: dict | None = None
    for raw in body.splitlines():
        line = raw.rstrip()
        if line.startswith("N:"):
            if current and current.get("email"):
                entries[current["email"].lower()] = current
            current = {"name": line[2:].strip(), "email": "", "descriptions": []}
        elif line.startswith("E:") and current is not None:
            current["email"] = line[2:].strip()
        elif line.startswith("D:") and current is not None:
            current["descriptions"].append(line[2:].strip())
        elif line.strip() == "" and current and current.get("email"):
            entries[current["email"].lower()] = current
            current = None
    if current and current.get("email"):
        entries[current["email"].lower()] = current
    return entries


def render(entries: list[dict]) -> str:
    blocks: list[str] = []
    for entry in entries:
        lines = [f"N: {entry['name']}", f"E: {entry['email']}"]
        descriptions = entry["descriptions"] or [DEFAULT_DESCRIPTION]
        lines.extend(f"D: {desc}" for desc in descriptions)
        blocks.append("\n".join(lines))
    return HEADER + "\n" + "\n\n".join(blocks) + "\n"


def main() -> int:
    existing = parse_entries(CREDITS.read_text(encoding="utf-8") if CREDITS.exists() else "")
    merged: dict[str, dict] = dict(existing)
    for name, email in git_authors():
        key = email.lower()
        if key in merged:
            merged[key]["name"] = name
            merged[key]["email"] = email
            continue
        merged[key] = {
            "name": name,
            "email": email,
            "descriptions": [DEFAULT_DESCRIPTION],
        }
    ordered = sorted(merged.values(), key=lambda item: item["name"].casefold())
    new_text = render(ordered)
    old_text = CREDITS.read_text(encoding="utf-8") if CREDITS.exists() else ""
    if new_text == old_text:
        print("CREDITS já está em dia.")
        return 0
    CREDITS.write_text(new_text, encoding="utf-8")
    print("CREDITS atualizado.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
