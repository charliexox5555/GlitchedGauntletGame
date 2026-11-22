"""Refresh (KB) size labels in vault/INDEX.md to match actual file sizes on disk.

Run from repo root:
    python tools/vault_index_sizes.py
"""
from __future__ import annotations

import math
import pathlib
import re
import urllib.parse

VAULT = pathlib.Path("vault")
INDEX = VAULT / "INDEX.md"


def kb_of(rel_path: str) -> int | None:
    fp = VAULT / rel_path
    if not fp.is_file():
        return None
    return max(1, int(math.ceil(fp.stat().st_size / 1024)))


def refresh_line(line: str) -> tuple[str, int]:
    changes = 0

    def repl_backtick(m: re.Match[str]) -> str:
        nonlocal changes
        path = m.group(1)
        old_kb = m.group(2)
        if "<" in path or "{" in path:
            return m.group(0)
        real = kb_of(path)
        if real is None:
            return m.group(0)
        if old_kb is not None:
            if int(old_kb) != real:
                changes += 1
                return f"`{path}` ({real})"
            return m.group(0)
        if real >= 15:
            changes += 1
            return f"`{path}` ({real})"
        return m.group(0)

    def repl_mdlink(m: re.Match[str]) -> str:
        nonlocal changes
        label, target, old_kb = m.group(1), m.group(2), m.group(3)
        rel = urllib.parse.unquote(target.split("#", 1)[0])
        real = kb_of(rel)
        if real is None:
            return m.group(0)
        if old_kb is not None:
            if int(old_kb) != real:
                changes += 1
                return f"[{label}]({target}) ({real})"
            return m.group(0)
        if real >= 15:
            changes += 1
            return f"[{label}]({target}) ({real})"
        return m.group(0)

    line = re.sub(r"`([^`]+\.md)`(?:\s*\((\d+)\))?", repl_backtick, line)
    line = re.sub(r"\[([^\]]+)\]\(([^)]+\.md(?:#[^)]+)?)\)(?:\s*\((\d+)\))?", repl_mdlink, line)
    return line, changes


def main() -> None:
    lines = INDEX.read_text(encoding="utf-8").splitlines()
    out = []
    total = 0
    for line in lines:
        new_line, n = refresh_line(line)
        out.append(new_line)
        total += n
    INDEX.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"Updated {total} size labels in {INDEX.as_posix()}")


if __name__ == "__main__":
    main()
