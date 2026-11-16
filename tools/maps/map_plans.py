#!/usr/bin/env python3
"""Layouts for the rest of the release lineup (maps overnight run, 2026-11-16).

    python tools/maps/map_plans.py <id> [...]        checks (arena_layout.report) + plan PNG/SVG
    python tools/maps/map_plans.py --luau <id>       the Studio data for ServerStorage.MapTools.Build
                                                     (art-source/maps/<id>/build.luau)

Each map: a Plan (the checker's view: X across, Z along, +Z = team A, 180-degree rotational symmetry) and a
META dict: origin, deck half-size, ceiling, kill depth, looks (colour / material / tile), lighting, the kit
folder, and per-row extras (look, kit piece, rise for ramps, thickness for bridges). Rows are on a 2.5 grid,
sizes in 5s where it matters; gaps between solids are 0 or 6.5+ (the checker's pinch rule).
Kinds: full, baffle, low, pillar, deck, plinth, ramp, bridge (walkable over a void), void (alley gap /
molten channel: no deck, deadly by KillDepth), decor (no collision).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arena_layout as L  # noqa: E402
from arena_layout import Box, Plan  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
GRID_TILE = "rbxassetid://99198970022758"


def rect(hx, hz):
    return [(-hx, hz), (hx, hz), (hx, -hz), (-hx, -hz)]


# ------------------------------------------------------------------------------------------------ ROOFTOPS
# Two team roofs (concrete, parapets, rooftop units) across a 15-wide alley you can't jump; three bridges
# (planks / a steel walkway) carry the lanes. A +10 penthouse deck a side (stair + crate step). Landmark: a
# tower crane standing beside the block (decor), orange: the accent.
ROOFTOPS = Plan(
    name="Rooftops", title="Rooftops", room=rect(45, 75), duel=True,
    center=[
        Box("Alley", 0, 0, 90, 15, 0, 0, "void"),
        Box("Bridge mid", 0, 0, 10, 15, 0, 0, "bridge"),
        Box("Bridge east", 35, 0, 10, 15, 0, 0, "bridge"),
        Box("Bridge west", -35, 0, 10, 15, 0, 0, "bridge"),
    ],
    half=[
        Box("Billboard", -17.5, 0, 15, 2.5, 18, 0, "full", 3.0),
        Box("Stair hut", 0, 55, 20, 10, 10, 0, "baffle"),
        Box("Parapet W", -17.5, 10, 15, 5, 3, 0, "low"),
        Box("Parapet E", 17.5, 10, 15, 5, 3, 0, "low"),
        Box("Roof shed", -32.5, 25, 10, 10, 10),
        Box("AC unit", -25, 45, 10, 10, 10),
        Box("Vent stack", 10, 32.5, 5, 5, 10, 0, "pillar"),
        Box("Skylight", -5, 30, 10, 10, 3, 0, "plinth"),
        Box("Penthouse", 35, 60, 20, 30, 10, 0, "deck"),
        Box("Penthouse stair", 35, 37.5, 10, 15, 10, 0, "ramp"),
        Box("Step crate", 22.5, 50, 5, 5, 7, 0, "deck"),
        Box("Water tank", -40, 60, 10, 10, 10),
        Box("Duct run", 25, 25, 10, 5, 3, 0, "low"),
    ],
    spawns_a=[(-5, 70), (5, 70), (-5, 65), (5, 65)],
)

# ------------------------------------------------------------------------------------------------ COURTYARD
# A stone plaza ringed by house fronts (outside the deck). The clock tower in the middle; arcades along the
# long sides carry a +10 walkway (stair + crate step); market stalls and planters as cover.
COURTYARD = Plan(
    name="Courtyard", title="Courtyard", room=rect(50, 70), duel=True,
    center=[
        Box("Clock tower", 0, 0, 10, 10, 40, 0, "pillar"),
        Box("Tower steps", 0, 0, 20, 20, 3, 0, "plinth"),
    ],
    half=[
        Box("Gate wall", 0, 52.5, 20, 5, 10, 0, "baffle"),
        Box("Arcade walk", -45, 25, 10, 40, 10, 0, "deck", 7.0),
        Box("Arcade pier N", -37.5, 42.5, 5, 5, 7, 0, "pillar"),
        Box("Arcade pier M", -37.5, 25, 5, 5, 7, 0, "pillar"),
        Box("Arcade pier S", -37.5, 7.5, 5, 5, 7, 0, "pillar"),
        Box("Arcade stair", -45, 55, 10, 20, 10, 0, "ramp"),
        Box("Stall N", 20, 40, 15, 5, 10),
        Box("Stall S", -12.5, 25, 10, 15, 10),
        Box("Stall W", -27.5, 60, 10, 5, 10),
        Box("Stall E", 35, 25, 15, 5, 10),
        Box("Planter", 15, 15, 10, 5, 3, 0, "low"),
        Box("Well", 30, 57.5, 10, 10, 3, 0, "low"),
        Box("Cart", -25, 45, 5, 10, 7, 0, "deck"),
        Box("Crates", 5, 30, 5, 5, 10),
    ],
    spawns_a=[(-5, 62), (5, 62), (-5, 66), (5, 66)],
)

# ------------------------------------------------------------------------------------------------ BUNKER
# Indoors (roof at +14): a 40 x 40 room round a light shaft open to the sky in the middle, doorways 10
# wide on every side; corridors round it split by partition walls; spawns at the ends behind blast walls.
BUNKER = Plan(
    name="Bunker", title="Bunker", room=rect(45, 75), duel=True,
    center=[
        Box("Generator", 0, 0, 10, 10, 10),
    ],
    half=[
        Box("Ring wall E", 22.5, 12.5, 5, 15, 14),
        Box("Ring wall W", -22.5, 12.5, 5, 15, 14),
        Box("Ring wall N1", 12.5, 22.5, 15, 5, 14),
        Box("Ring wall N2", -12.5, 22.5, 15, 5, 14),
        Box("Blast wall", 0, 52.5, 20, 5, 14, 0, "baffle"),
        Box("Partition E", 40, 37.5, 10, 5, 14),
        Box("Partition W", -40, 30, 10, 5, 14),
        Box("Locker row", -12.5, 40, 15, 5, 10),
        Box("Crate stack", 15, 37.5, 5, 5, 10),
        Box("Console", 40, 10, 10, 5, 3, 0, "low"),
        Box("Overlook", 15, 15, 10, 10, 7, 0, "deck"),
        Box("Overlook step", 7.5, 15, 5, 5, 3.5, 0, "plinth"),
    ],
    spawns_a=[(-5, 67), (5, 67), (-5, 62), (5, 62)],
)

# ------------------------------------------------------------------------------------------------ FOUNDRY
# Steel works: a molten channel across the middle (deadly) with three steel bridges; catwalks at +10 along
# the long walls (stairs up from each half); ingot stacks and machines as cover; the furnace and its ladle
# stand off the east wall (decor landmark).
FOUNDRY = Plan(
    name="Foundry", title="Foundry", room=rect(45, 75), duel=True,
    center=[
        Box("Channel", 0, 0, 90, 10, 0, 0, "void"),
        Box("Bridge mid", 0, 0, 10, 10, 0, 0, "bridge"),
        Box("Bridge east", 27.5, 0, 10, 10, 0, 0, "bridge"),
        Box("Bridge west", -27.5, 0, 10, 10, 0, 0, "bridge"),
    ],
    half=[
        Box("Ingot stack", 0, 52.5, 20, 5, 10, 0, "baffle"),
        Box("Catwalk", 42.5, 20, 5, 30, 10, 0, "deck", 7.0),
        Box("Catwalk stair", 42.5, 45, 5, 20, 10, 0, "ramp"),
        Box("Catwalk post", 42.5, 10, 5, 5, 7, 0, "pillar"),
        Box("Press", -27.5, 25, 10, 15, 10),
        Box("Mould row", 15, 22.5, 5, 15, 10),
        Box("Billet low", -10, 15, 10, 5, 3, 0, "low"),
        Box("Hopper", -30, 55, 10, 10, 10),
        Box("Pallet step", 25, 55, 5, 5, 3.5, 0, "plinth"),
        Box("Ladle cart", -10, 35, 10, 5, 10),
        Box("Coil stack", 27.5, 35, 5, 5, 10),
        Box("Rail cart", 0, 20, 10, 5, 3, 0, "low"),
    ],
    spawns_a=[(-5, 67), (5, 67), (-5, 62), (5, 62)],
)

# ------------------------------------------------------------------------------------------------ SNOWPEAK
# A ski lodge in a snowy yard: the lodge (30 x 20, walls with doors, roof overhead) is the middle you fight
# through; pines, woodpiles and snowbanks in the yard; the gondola station stands off the north-east corner.
SNOWPEAK = Plan(
    name="Snowpeak", title="Snowpeak", room=rect(50, 70), duel=True,
    center=[
        Box("Lodge roof", 0, 0, 40, 30, 20, 0, "full", 12.0),
        Box("Hearth", 0, 0, 5, 5, 12, 0, "pillar"),
    ],
    half=[
        Box("Lodge wall N1", -10, 12.5, 10, 5, 12),
        Box("Lodge wall N2", 10, 12.5, 10, 5, 12),
        Box("Lodge wall E", 17.5, 5, 5, 10, 12),
        Box("Woodpile", 0, 52.5, 20, 5, 10, 0, "baffle"),
        Box("Pine A", -32.5, 35, 5, 5, 16, 0, "pillar"),
        Box("Pine B", 30, 20, 5, 5, 16, 0, "pillar"),
        Box("Pine C", -15, 40, 5, 5, 16, 0, "pillar"),
        Box("Snowbank", 22.5, 40, 15, 5, 3, 0, "low"),
        Box("Ski rack", -35, 15, 5, 10, 3, 0, "low"),
        Box("Sled shed", 42.5, 55, 15, 10, 10),
        Box("Pine D", 40, 35, 5, 5, 16, 0, "pillar"),
        Box("Woodshed", -35, 55, 10, 10, 10),
        Box("Porch", -5, 25, 10, 5, 3, 0, "plinth"),
    ],
    spawns_a=[(-5, 64), (5, 64), (-5, 60), (5, 60)],
)

# ------------------------------------------------------------------------------------------------ MODEL KIT
# Giant scale: a hobby workbench. A cutting mat floor; the glue pot (landmark) in the middle; paint pots and
# a parts box as full cover; a steel ruler as long low cover; a stack of books as steps up to a +10 book top.
MODELKIT = Plan(
    name="ModelKit", title="Model Kit", room=rect(50, 70), duel=True,
    center=[
        Box("Glue pot", 0, 0, 15, 15, 25, 0, "pillar"),
    ],
    half=[
        Box("Parts box", 0, 52.5, 25, 5, 10, 0, "baffle"),
        Box("Paint pot A", -27.5, 32.5, 10, 10, 12),
        Box("Paint pot B", 17.5, 20, 10, 10, 12),
        Box("Ruler", -7.5, 17.5, 25, 5, 3, 0, "low"),
        Box("Pencil ramp", 20, 50, 15, 10, 10, 0, "ramp"),
        Box("Pencil cup", -12.5, 40, 5, 5, 10),
        Box("Book top", 35, 50, 15, 20, 10, 0, "deck"),
        Box("Book step", 35, 35, 15, 10, 7, 0, "deck"),
        Box("Book step low", 35, 27.5, 10, 5, 3.5, 0, "plinth"),
        Box("Sprue frame", -35, 55, 15, 5, 10),
        Box("Craft knife", 5, 37.5, 15, 5, 3, 0, "low"),
        Box("Tape roll", -32.5, 10, 10, 10, 7, 0, "deck"),
    ],
    spawns_a=[(-5, 64), (5, 64), (-5, 60), (5, 60)],
)

# ------------------------------------------------------------------------------------------------ OLD TOWN
# The full plaza and its streets (3v3): building blocks make three streets along Z; the clock tower in the
# plaza; arcade walkways (+10) on two blocks; one long marked sightline down the main street.
OLDTOWN = Plan(
    name="OldTown", title="Old Town", room=rect(100, 120), duel=False,
    center=[
        Box("Clock tower", 0, 0, 10, 10, 40, 0, "pillar"),
        Box("Tower steps", 0, 0, 20, 20, 3, 0, "plinth"),
    ],
    half=[
        Box("Gate wall", 0, 97.5, 30, 5, 10, 0, "baffle"),
        Box("Block NW", -55, 70, 40, 40, 18),
        Box("Block NE", 55, 55, 30, 30, 18),
        Box("Block W", -70, 15, 30, 30, 18),
        Box("Arcade walk", -40, 40, 10, 20, 10, 0, "deck", 7.0),
        Box("Arcade stair", -40, 20, 10, 20, 10, 0, "ramp"),
        Box("Arcade pier", -37.5, 32.5, 5, 5, 7, 0, "pillar"),
        Box("Stall A", 20, 45, 15, 5, 10),
        Box("Stall B", -20, 60, 5, 15, 10),
        Box("Planter A", 30, 15, 10, 5, 3, 0, "low"),
        Box("Fountain", 0, 30, 10, 10, 3, 0, "low"),
        Box("Cart", 75, 20, 5, 10, 7, 0, "deck"),
        Box("Barrels", 42.5, 72.5, 5, 5, 10),
        Box("Well", -22.5, 25, 10, 10, 3, 0, "low"),
    ],
    spawns_a=[(-12, 108), (0, 110), (12, 108), (-6, 104), (6, 104)],
)

# ------------------------------------------------------------------------------------------------ METRO
# A station (indoors, roof +22 with skylights): two platforms along Z, the track trench between (floor -5,
# you can drop in and climb out), two parked trains as cover, a footbridge at +12 over the middle with stairs
# on both platforms, columns and kiosks.
METRO = Plan(
    name="Metro", title="Metro", room=rect(100, 105), duel=False,
    center=[
        Box("Track trench", 0, 0, 50, 210, 0, 0, "void"),
        Box("Trench floor", 0, 0, 50, 210, -5, 0, "bridge"),
        Box("Footbridge", 0, 0, 70, 10, 12, 0, "deck", 9.0),
    ],
    half=[
        Box("Train A", -12.5, 45, 10, 50, 8, 0, "full", -5.0),
        Box("Train B", 12.5, 35, 10, 50, 8, 0, "full", -5.0),
        Box("Bridge landing", -40, 0, 10, 10, 12, 0, "deck"),
        Box("Bridge stair N", -40, 15, 10, 20, 12, 0, "ramp"),
        Box("Bridge stair S", -40, -15, 10, 20, 12, 0, "ramp"),
        Box("Concourse wall 1", -57.5, 77.5, 5, 35, 12),
        Box("Concourse wall 2", -57.5, 25, 5, 30, 12),
        Box("Concourse wall 3", -57.5, -40, 5, 30, 12),
        Box("Spawn wall", -40, 80, 30, 5, 12, 0, "baffle"),
        Box("Column 1", -40, 55, 5, 5, 22, 0, "pillar"),
        Box("Column 2", -40, 35, 5, 5, 22, 0, "pillar"),
        Box("Column 3", -40, -35, 5, 5, 22, 0, "pillar"),
        Box("Column 4", -40, -60, 5, 5, 22, 0, "pillar"),
        Box("Kiosk", -80, 60, 10, 10, 10),
        Box("Ticket gates", -80, 25, 15, 5, 3, 0, "low"),
        Box("Vending", -77.5, -10, 5, 10, 10),
        Box("Stairwell", -82.5, -60, 15, 20, 10),
        Box("Map board", -80, 85, 10, 5, 10),
    ],
    spawns_a=[(-45, 95), (-35, 95), (-40, 99), (-48, 90), (-32, 90)],
)

# ------------------------------------------------------------------------------------------------ GREENHOUSE
# Glass halls: the dome hall in the middle (a ring of planters round the fountain), a bridge at +10 across
# it with stairs at both ends, side halls with planting beds; hall walls are low brick with glass above
# (the glass is decor: you see and shoot through it).
GREENHOUSE = Plan(
    name="Greenhouse", title="Greenhouse", room=rect(100, 120), duel=False,
    center=[
        Box("Fountain", 0, 0, 15, 15, 3, 0, "low"),
        Box("Dome bridge", 0, 0, 60, 10, 10, 0, "deck", 7.0),
    ],
    half=[
        Box("Bridge landing", 35, 0, 10, 10, 10, 0, "deck"),
        Box("Bridge stair", 35, 15, 10, 20, 10, 0, "ramp"),
        Box("Landing step", 42.5, 0, 5, 5, 7, 0, "deck"),
        Box("Landing step low", 47.5, 0, 5, 5, 3.5, 0, "plinth"),
        Box("Spawn screen", 0, 97.5, 40, 5, 10, 0, "baffle"),
        Box("Planter ring NE", 17.5, 22.5, 15, 5, 10),
        Box("Planter ring NW", -22.5, 17.5, 5, 15, 10),
        Box("Hedge W", -60, 0, 5, 20, 10),
        Box("Hall wall E", 60, 50, 5, 60, 3, 0, "low"),
        Box("Hall wall W", -60, 40, 5, 40, 3, 0, "low"),
        Box("Bed E1", 80, 60, 10, 20, 10),
        Box("Bed W1", -80, 45, 10, 25, 10),
        Box("Bed mid", 25, 65, 20, 5, 10),
        Box("Bed N", -20, 50, 15, 5, 10),
        Box("Hedge E", 40, 45, 5, 15, 10),
        Box("Potting bench", -30, 75, 15, 5, 3, 0, "low"),
        Box("Palm", -40, 25, 5, 5, 16, 0, "pillar"),
        Box("Seed crates", 85, 20, 5, 10, 7, 0, "deck"),
        Box("Glass case", -70, 95, 10, 10, 10),
        Box("Cold frame", 70, 100, 10, 5, 10),
        Box("Water butt", 50, 90, 5, 5, 10, 0, "pillar"),
    ],
    spawns_a=[(-12, 108), (0, 110), (12, 108), (-6, 104), (6, 104)],
)

PLANS = {p.name: p for p in (ROOFTOPS, COURTYARD, BUNKER, FOUNDRY, SNOWPEAK, MODELKIT, OLDTOWN, METRO, GREENHOUSE)}

if __name__ == "__main__" and "--luau" in sys.argv:
    import map_meta as M  # noqa: E402

    for nm in [a for a in sys.argv[1:] if a != "--luau"]:
        out = ROOT / "art-source/maps" / M.data(PLANS[nm])["id"]
        out.mkdir(parents=True, exist_ok=True)
        code = "return require(game.ServerStorage.MapTools.Run)(" + M.luau(M.data(PLANS[nm])) + ")\n"
        (out / "build.luau").write_text(code, encoding="utf-8")
        print(nm, len(code), "bytes ->", out / "build.luau")

if __name__ == "__main__" and "--luau" not in sys.argv:
    for nm in sys.argv[1:] or list(PLANS):
        p = PLANS[nm]
        longest = L.report(p)
        out = ROOT / "vault/02 Art/References/maps" / nm.lower()
        out.mkdir(parents=True, exist_ok=True)
        (out / f"{nm.lower()}-layout.svg").write_text(L.svg(p, longest), encoding="utf-8")
        L.png(p, longest, out / f"{nm.lower()}-layout.png")
