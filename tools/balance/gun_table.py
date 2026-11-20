#!/usr/bin/env python3
"""Gun balance sheet: reads src/shared/Config/Weapons.luau and works out shots and
time to kill against every health total a player can have.

Run: python tools/balance/gun_table.py
Rewrites the tables in vault/01 Design/Gun Balance.md (between the table markers)
and prints warnings for anything outside the targets written there. TTK starts at
the first shot and accounts for spin-up and empty reloads. Shotguns assume every
pellet hits.
"""

from __future__ import annotations

import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "src/shared/Config/Weapons.luau"
NOTE = ROOT / "vault/01 Design/Gun Balance.md"
TOTALS = (100, 125, 150)
PHASES = {1: "Sidearm", 2: "Light", 3: "Heavy", 4: "Elite"}
FLAT_SHIELD = {3: 50, 4: 50}

# Targets (Gun Balance.md). Body kill against 150, on guns that aren't snipers or shotguns.
TTK_MIN, TTK_MAX = 0.7, 1.4  # 2026-11-12: slower kills (was 0.5, 1.1)
NO_ONE_SHOT_HEAD = {"Rifle", "SMG", "MachineGun", "Sidearm"}


def read_guns() -> list[dict]:
    text = CONFIG.read_text(encoding="utf-8")
    guns = []
    for m in re.finditer(r'\n\t(\w+) = \{\n\t\tid = "\1",(.*?)\n\t\},', text, re.S):
        body = m.group(2)
        field = lambda name: re.search(rf"\n\t\t{name} = ([^,\n]+),", body)
        damage = re.search(r"damage = \{ body = (\d+), head = (\d+), legs = (\d+) \}", body)
        klass = field("class").group(1).strip('"')
        if klass == "Melee":
            continue
        shield = field("shield")
        spin = re.search(
            r"spinUp = \{ startInterval = ([\d.]+), endInterval = ([\d.]+), time = ([\d.]+) \}",
            body,
        )
        guns.append(
            {
                "id": m.group(1),
                "class": klass,
                "tier": int(field("tier").group(1)),
                "body": int(damage.group(1)),
                "head": int(damage.group(2)),
                "pellets": int(field("pellets").group(1)),
                "interval": float(field("fireInterval").group(1)),
                "spin": tuple(map(float, spin.groups())) if spin else None,
                "mag": int(field("magSize").group(1)),
                "empty_reload": float(field("emptyReloadTime").group(1)),
                "shield": int(shield.group(1)) if shield else None,
            }
        )
    guns.sort(key=lambda g: (g["tier"], g["class"], g["id"]))
    return guns


def shots(hp: int, per_shot: int) -> int:
    return math.ceil(hp / per_shot)


def time_to_kill(gun: dict, count: int) -> float:
    elapsed = 0.0
    spin_started = 0.0
    for fired in range(1, count):
        if fired % gun["mag"] == 0:
            elapsed += max(gun["empty_reload"], gun["interval"])
            spin_started = elapsed
        elif gun["spin"]:
            start, end, duration = gun["spin"]
            ramp = (start - end) / duration
            # FireRate evaluates the interval at the next shot's time.
            gap = (start - ramp * (elapsed - spin_started)) / (1 + ramp)
            elapsed += max(end, gap)
        else:
            elapsed += gun["interval"]
    return elapsed


def cell(hp: int, per_shot: int, gun: dict) -> str:
    n = shots(hp, per_shot)
    return f"{n} ({time_to_kill(gun, n):.2f}s)"


def table(guns: list[dict], tier: int) -> str:
    rows = [
        f"| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at {TOTALS[0]} / {TOTALS[1]} / {TOTALS[2]} | Head shots at {TOTALS[0]} / {TOTALS[1]} / {TOTALS[2]} |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for g in guns:
        if g["tier"] != tier:
            continue
        body = g["body"] * g["pellets"]
        head = g["head"] * g["pellets"]
        shield = FLAT_SHIELD.get(tier, g["shield"] or 0)
        damage = (
            f"{g['body']} / {g['head']} × {g['pellets']} pellets"
            if g["pellets"] > 1
            else f"{g['body']} / {g['head']}"
        )
        rate = (
            f"{1 / g['spin'][0]:.1f}–{1 / g['spin'][1]:.1f}/s"
            if g["spin"]
            else f"{1 / g['interval']:.1f}/s"
        )
        rows.append(
            f"| **{g['id']}** | {g['class']} | {shield} | {damage} | {rate} | {g['mag']} | "
            + " · ".join(cell(hp, body, g) for hp in TOTALS)
            + " | "
            + " · ".join(cell(hp, head, g) for hp in TOTALS)
            + " |"
        )
    return "\n".join(rows)


def warnings(guns: list[dict]) -> list[str]:
    out = []
    for g in guns:
        body = g["body"] * g["pellets"]
        head = g["head"] * g["pellets"]
        ttk = time_to_kill(g, shots(150, body))
        if g["class"] not in ("Sniper", "Shotgun") and g["pellets"] == 1 and not TTK_MIN <= ttk <= TTK_MAX:
            out.append(f"{g['id']}: body kill at 150 is {ttk:.2f} s, target {TTK_MIN}-{TTK_MAX}")
        if g["class"] in NO_ONE_SHOT_HEAD and g["pellets"] == 1 and head >= 100:
            out.append(f"{g['id']}: one-shots a head at 100")
        if body >= 100:
            out.append(f"{g['id']}: one-shots the body at 100")
        if g["pellets"] == 1 and head / g["body"] > (2.2 if g["class"] == "Sniper" else 1.75):
            out.append(f"{g['id']}: head multiplier {head / g['body']:.2f}")
        if shots(150, body) > g["mag"]:
            out.append(f"{g['id']}: a full mag can't kill 150")
    return out


def main():
    guns = read_guns()
    parts = []
    for tier, name in PHASES.items():
        parts.append(f"### {name} phase\n{table(guns, tier)}")
    block = "\n\n".join(parts)
    note = NOTE.read_text(encoding="utf-8")
    start, end = "<!-- table:start -->", "<!-- table:end -->"
    note = note[: note.index(start) + len(start)] + "\n" + block + "\n" + note[note.index(end) :]
    NOTE.write_text(note, encoding="utf-8")
    print(f"{len(guns)} guns written to {NOTE.name}")
    problems = warnings(guns)
    print("\n".join(problems) if problems else "All inside the targets.")


if __name__ == "__main__":
    main()
