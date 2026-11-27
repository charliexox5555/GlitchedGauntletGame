#!/usr/bin/env python3
"""Gun balance sheet for the loadout (vault/01 Design/Gun Balance.md).

Reads the active set from src/shared/Config/Loadout.luau and the stats from
src/shared/Config/Weapons.luau, then works out shots and time to kill at five range
bands, body and head. Primaries fight at 150 (100 health + the flat 50 shield of
rounds 2+); secondaries are listed at their round-1 totals (their own shield) and
at 150 (as a backup in later rounds).

Run: python tools/balance/gun_table.py
Rewrites the tables between the table markers in the note and prints warnings for
anything outside the targets written there. TTK starts at the first shot and counts
spin-up, burst gaps and empty reloads. Shotguns assume every pellet hits. Damage is
not rounded per hit (the server applies the float; only the numbers on screen round).
"""

from __future__ import annotations

import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEAPONS = ROOT / "src/shared/Config/Weapons.luau"
LOADOUT = ROOT / "src/shared/Config/Loadout.luau"
NOTE = ROOT / "vault/01 Design/Gun Balance.md"

BANDS = (10, 35, 60, 90, 150)  # studs
PRIMARY_HP = 150
SIDEARM_HEALTH = 100

# Targets (Gun Balance.md → Targets): body kill at 150, close range, perfect accuracy.
PRIMARY_TTK = (0.65, 1.2)  # automatics and bursts
NO_ONE_SHOT_HEAD = {"Rifle", "SMG", "MachineGun", "Sidearm"}


def list_ids(text: str, name: str) -> list[str]:
    block = re.search(rf"{name} = table\.freeze\(\{{(.*?)\}}\)", text, re.S).group(1)
    return re.findall(r'"(\w+)"', block)


def read_guns() -> dict[str, dict]:
    text = WEAPONS.read_text(encoding="utf-8")
    guns = {}
    for m in re.finditer(r'\n\t(\w+) = \{\n\t\tid = "\1",(.*?)\n\t\},', text, re.S):
        body = m.group(2)

        def field(name: str):
            f = re.search(rf"\n\t\t{name} = ([^,\n]+),", body)
            return f.group(1).strip().strip('"') if f else None

        damage = re.search(r"damage = \{ body = ([\d.]+), head = ([\d.]+), legs = ([\d.]+) \}", body)
        if field("class") == "Melee":
            continue
        spin = re.search(
            r"spinUp = \{ startInterval = ([\d.]+), endInterval = ([\d.]+), time = ([\d.]+) \}", body
        )
        burst = re.search(r"burst = \{ count = (\d+), interval = ([\d.]+)", body)
        falloff = [
            (float(a), float(b))
            for a, b in re.findall(r"\{ from = ([\d.]+), multiplier = ([\d.]+) \}", body)
        ]
        guns[m.group(1)] = {
            "id": m.group(1),
            "name": field("displayName"),
            "class": field("class"),
            "body": float(damage.group(1)),
            "head": float(damage.group(2)),
            "pellets": int(field("pellets")),
            "interval": float(field("fireInterval")),
            "spin": tuple(map(float, spin.groups())) if spin else None,
            "burst": (int(burst.group(1)), float(burst.group(2))) if burst else None,
            "falloff": falloff,
            "mag": int(field("magSize")),
            "empty_reload": float(field("emptyReloadTime")),
            "shield": int(field("shield") or 0),
            "move": float(field("moveMultiplier")),
        }
    return guns


def falloff(gun: dict, distance: float) -> float:
    mult = 1.0
    for start, m in gun["falloff"]:
        if distance >= start:
            mult = m
    return mult


def gap(gun: dict, fired: int, elapsed: float, spin_started: float) -> float:
    """Seconds from shot `fired` (1-based) to the next one."""
    if gun["burst"]:
        count, inner = gun["burst"]
        return inner if fired % count else gun["interval"]
    if gun["spin"]:
        start, end, duration = gun["spin"]
        ramp = (start - end) / duration
        # FireRate evaluates the interval at the next shot's time.
        return max(end, (start - ramp * (elapsed - spin_started)) / (1 + ramp))
    return gun["interval"]


def time_to_kill(gun: dict, count: int) -> float:
    elapsed = 0.0
    spin_started = 0.0
    for fired in range(1, count):
        if fired % gun["mag"] == 0:
            elapsed += max(gun["empty_reload"], gun["interval"])
            spin_started = elapsed
        else:
            elapsed += gap(gun, fired, elapsed, spin_started)
    return elapsed


def kill(gun: dict, hp: float, zone: str, distance: float) -> tuple[int, float]:
    per = gun[zone] * gun["pellets"] * falloff(gun, distance)
    n = math.ceil(hp / per - 1e-9)
    return n, time_to_kill(gun, n)


def rate(gun: dict) -> str:
    if gun["spin"]:
        return f"{1 / gun['spin'][0]:.1f}–{1 / gun['spin'][1]:.1f}/s"
    if gun["burst"]:
        count, inner = gun["burst"]
        return f"{count}-burst, {count / (gun['interval'] + (count - 1) * inner):.1f}/s"
    return f"{1 / gun['interval']:.1f}/s"


def damage(gun: dict) -> str:
    b, h = f"{gun['body']:g}", f"{gun['head']:g}"
    return f"{b} / {h} × {gun['pellets']}" if gun["pellets"] > 1 else f"{b} / {h}"


def cell(gun: dict, hp: float, distance: float) -> str:
    bn, bt = kill(gun, hp, "body", distance)
    hn, ht = kill(gun, hp, "head", distance)
    return f"{bn} · {bt:.2f}s / {hn} · {ht:.2f}s"


def primaries_table(guns: dict, ids: list[str]) -> str:
    bands = " | ".join(f"{d} studs" for d in BANDS)
    rows = [
        f"| Gun | Class | Damage body / head | Rate | Mag | Move | {bands} |",
        "|---|---|---|---|---|---|" + "---|" * len(BANDS),
    ]
    for gid in ids:
        g = guns[gid]
        rows.append(
            f"| **{g['name']}** ({gid}) | {g['class']} | {damage(g)} | {rate(g)} | {g['mag']} | {g['move']:.2f} | "
            + " | ".join(cell(g, PRIMARY_HP, d) for d in BANDS)
            + " |"
        )
    return "\n".join(rows)


def secondaries_table(guns: dict, ids: list[str]) -> str:
    rows = [
        "| Gun | Own shield | Damage body / head | Rate | Mag | vs 100 at 10 | vs 125 at 10 | vs 150 at 10 | vs 150 at 35 | vs 150 at 90 |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for gid in ids:
        g = guns[gid]
        rows.append(
            f"| **{g['name']}** ({gid}) | {g['shield']} ({SIDEARM_HEALTH + g['shield']} total) | {damage(g)} | {rate(g)} | {g['mag']} | "
            + " | ".join(
                cell(g, hp, d) for hp, d in ((100, 10), (125, 10), (150, 10), (150, 35), (150, 90))
            )
            + " |"
        )
    return "\n".join(rows)


def round_one(guns: dict, ids: list[str]) -> str:
    rows = ["| Round 1 | Body kill, each way (10 studs) | Reading |", "|---|---|---|"]
    for i, a in enumerate(ids):
        for b in ids[i + 1 :]:
            ga, gb = guns[a], guns[b]
            ta = kill(ga, SIDEARM_HEALTH + gb["shield"], "body", 10)[1]
            tb = kill(gb, SIDEARM_HEALTH + ga["shield"], "body", 10)[1]
            lead = ga["name"] if ta < tb - 0.02 else gb["name"] if tb < ta - 0.02 else "even"
            rows.append(f"| {ga['name']} vs {gb['name']} | {ta:.2f}s vs {tb:.2f}s | {lead} |")
    return "\n".join(rows)


def warnings(guns: dict, primaries: list[str], secondaries: list[str]) -> list[str]:
    out = []
    for gid in primaries + secondaries:
        g = guns[gid]
        body = g["body"] * g["pellets"]
        head = g["head"] * g["pellets"]
        if gid in primaries and g["class"] not in ("Sniper", "Shotgun"):
            t = kill(g, PRIMARY_HP, "body", 10)[1]
            lo, hi = PRIMARY_TTK
            if not lo <= t <= hi:
                out.append(f"{gid}: close body kill at 150 is {t:.2f} s, target {lo}-{hi}")
        if g["class"] in NO_ONE_SHOT_HEAD and g["pellets"] == 1 and head >= 100:
            out.append(f"{gid}: one-shots a head at 100")
        # A full-health fighter survives any one body hit: 150 for primaries, 100 for sidearms (round 1).
        if body >= (PRIMARY_HP if gid in primaries else SIDEARM_HEALTH):
            out.append(f"{gid}: one-shots a full-health body")
        if g["pellets"] == 1 and head / g["body"] > (2.2 if g["class"] == "Sniper" else 1.75):
            out.append(f"{gid}: head multiplier {head / g['body']:.2f}")
        if kill(g, PRIMARY_HP, "body", 10)[0] > g["mag"]:
            out.append(f"{gid}: a full mag can't kill 150")
    return out


def main():
    loadout = LOADOUT.read_text(encoding="utf-8")
    primaries, secondaries = list_ids(loadout, "PRIMARIES"), list_ids(loadout, "SECONDARIES")
    guns = read_guns()
    block = "\n\n".join(
        [
            f"### Primaries at {PRIMARY_HP} (rounds 2+)\nEach cell: body shots · time / head shots · time.\n\n"
            + primaries_table(guns, primaries),
            "### Secondaries\nRound 1 is sidearms only, each with its own shield. Same cell format.\n\n"
            + secondaries_table(guns, secondaries),
            round_one(guns, secondaries),
        ]
    )
    note = NOTE.read_text(encoding="utf-8")
    start, end = "<!-- table:start -->", "<!-- table:end -->"
    note = note[: note.index(start) + len(start)] + "\n" + block + "\n" + note[note.index(end) :]
    NOTE.write_bytes(note.encode("utf-8"))
    print(f"{len(primaries)} primaries + {len(secondaries)} secondaries written to {NOTE.name}")
    problems = warnings(guns, primaries, secondaries)
    print("\n".join(problems) if problems else "All inside the targets.")


if __name__ == "__main__":
    main()
