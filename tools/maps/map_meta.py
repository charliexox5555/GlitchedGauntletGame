"""Looks, lighting and Studio data for tools/maps/map_plans.py (maps overnight run, 2026-11-16).

Per map: origin (maps spaced 1,000 studs apart: owner, 2026-11-16), ceiling, kill depth, looks (colour /
material / tile texture), row looks (name prefix -> look), lighting profile, atmosphere, roof / under / water,
the kit folder in ServerStorage.MapKit, kit pieces per row name, free props. data(plan) builds the table
ServerStorage.MapTools.Build takes; luau() writes it as a Luau literal.
"""

from __future__ import annotations

import json

import arena_layout as L
from arena_layout import Box, Plan

TEX = {
    "grid": {"id": "rbxassetid://99198970022758", "tile": 5, "transparency": 0.78},
    "brick": {"id": "rbxassetid://110149840032586", "tile": 5, "transparency": 0.72},
    "planks": {"id": "rbxassetid://71262750829005", "tile": 5, "transparency": 0.7},
    "concrete": {"id": "rbxassetid://105617476629551", "tile": 10, "transparency": 0.75},
    "pavers": {"id": "rbxassetid://77790486177287", "tile": 5, "transparency": 0.75},
    "cuttingmat": {"id": "rbxassetid://116441595411737", "tile": 10, "transparency": 0.45, "color": "FFFFFF"},
    "tread": {"id": "rbxassetid://132914968334883", "tile": 5, "transparency": 0.72},
}


def lk(color, tex=None, mat="SmoothPlastic", **kw):
    d = {"color": color, "mat": mat}
    if tex:
        d["tex"] = tex
    d.update(kw)
    return d


DAY = {
    "Brightness": 3,
    "ExposureCompensation": 0.1,
    "Ambient": "80848E",
    "OutdoorAmbient": "A8AEBC",
    "EnvironmentDiffuseScale": 0.4,
    "EnvironmentSpecularScale": 0.1,
}


def light(clock, **kw):
    d = dict(DAY)
    d["ClockTime"] = clock
    d.update(kw)
    return d


TOWN_LOOKS = dict(
    deck=lk("CFC6B7", "pavers", topOnly=True), default=lk("D6CCBB", "brick"), cover=lk("D6CCBB", "brick"),
    low=lk("A69885", "brick"), pillar=lk("C9BEAA", "brick"), deck2=lk("BFB4A1", "pavers"), ramp=lk("B0A592", "pavers"),
    tower=lk("CDBFA6", "brick"), stall=lk("B5643F", "planks"), wood=lk("8C6A4A", "planks"), plinth=lk("BDB3A0", "pavers"),
    block=lk("DCCFB8", "brick"),
)

META = {
    "Rooftops": dict(
        origin=(6500, 200, 0), ceiling=70, killDepth=25, id="Rooftops3", kit="Rooftops3",
        under={"y": -30, "look": "street"},
        looks=dict(
            deck=lk("B3B5BA", "concrete", topOnly=True), default=lk("A4A7AD", "concrete"), cover=lk("A4A7AD", "concrete"),
            low=lk("8E9299", "concrete"), pillar=lk("7C8088"), deck2=lk("8C9097", "concrete"), ramp=lk("6E727A", "tread"),
            bridge=lk("6B5A48", "planks"), street=lk("4A4E55"), billboard=lk("D9772E"), tank=lk("6E7C88", "planks"),
        ),
        rowlooks=[("Billboard", "billboard"), ("Water tank", "tank"), ("Bridge mid", "ramp")],
        lighting=light(15.6, ColorShift_Top="FFE7C8"),
        atmosphere={"density": 0.3, "haze": 1.4, "color": "E4D9CC", "decay": "A79C92"},
    ),
    "Courtyard": dict(
        origin=(7500, 200, 0), ceiling=70, killDepth=30, kit="Town", looks=TOWN_LOOKS,
        walls={"h": 18, "look": "block"},  # townhouse backdrop: the square is closed, like the RIVALS town maps
        rowlooks=[("Clock tower", "tower"), ("Tower steps", "plinth"), ("Stall", "stall"), ("Cart", "wood"), ("Crates", "wood")],
        lighting=light(14.2, ColorShift_Top="FFEBD2"),
        atmosphere={"density": 0.26, "haze": 1.0, "color": "E9E0D2", "decay": "B3A28E"},
    ),
    "Bunker": dict(
        origin=(8500, 200, 0), ceiling=40, killDepth=30, id="Bunker3", kit="Bunker3",
        roof={"h": 14, "holes": [[0, 0, 30, 30]]},
        looks=dict(
            deck=lk("8F9297", "concrete", topOnly=True), default=lk("A5A8AD", "concrete"), cover=lk("A5A8AD", "concrete"),
            low=lk("6E7176", "tread"), pillar=lk("7B7E83"), deck2=lk("7F8287", "tread"), ramp=lk("72757A", "tread"),
            roof=lk("7B7E83", "concrete"), locker=lk("5E6E7E", "tread"), generator=lk("C9CDD2", "tread"),
        ),
        rowlooks=[("Locker", "locker"), ("Generator", "generator")],
        lighting=light(12, Brightness=2.4, Ambient="8C9098", OutdoorAmbient="B4BAC6", ExposureCompensation=0.25),
        atmosphere={"density": 0.36, "haze": 0.6, "color": "DDE3EA", "decay": "9AA4B2"},
    ),
    "Foundry": dict(
        origin=(9500, 200, 0), ceiling=70, killDepth=8, kit="Foundry",
        apron={"w": 40, "look": "cover"},  # the hall floor round the play space; the furnace stands on it
        under={"y": -7, "look": "molten"},  # below the deck (bottom -4) so the glow never meets the deck rim
        looks=dict(
            deck=lk("6F7378", "tread", topOnly=True), default=lk("8A8E94", "concrete"), cover=lk("8A8E94", "concrete"),
            low=lk("5D6168", "tread"), pillar=lk("4F535A"), deck2=lk("4F535A", "tread"), ramp=lk("4F535A", "tread"),
            bridge=lk("4F535A", "tread"), molten=lk("FF6A1A", None, "Neon"), machine=lk("5D6168", "tread"),
            ingot=lk("A9AEB5", "tread"),
        ),
        rowlooks=[("Press", "machine"), ("Hopper", "machine"), ("Ingot", "ingot"), ("Mould", "machine"), ("Coil", "ingot")],
        lighting=light(17.6, ColorShift_Top="FFC79A", Ambient="7C7470", OutdoorAmbient="A49488"),
        atmosphere={"density": 0.38, "haze": 2.0, "color": "D9B9A0", "decay": "8A6A58"},
    ),
    "Snowpeak": dict(
        origin=(10500, 200, 0), ceiling=70, killDepth=30, id="Snowpeak3", kit="Snowpeak3",
        apron={"w": 60, "look": "low"},  # a snowfield round the map: the treeline and gondola stand on it
        looks=dict(
            deck=lk("EEF2F6", "pavers", topOnly=True), default=lk("8A5A3C", "planks"), cover=lk("8A5A3C", "planks"),
            low=lk("F4F7FA"), pillar=lk("2F5E45"), deck2=lk("8A5A3C", "planks"), ramp=lk("7A5038", "planks"),
            roof=lk("6B4A36", "planks"), trim=lk("B33A2E", "planks"), stone=lk("8E949B", "brick"), plinth=lk("7A5038", "planks"),
        ),
        rowlooks=[("Lodge roof", "roof"), ("Hearth", "stone"), ("Sled shed", "trim"), ("Ski rack", "trim"), ("Porch", "plinth")],
        lighting=light(13.2, ColorShift_Top="F2F6FF", Ambient="8C96A6", OutdoorAmbient="B6C2D6", ExposureCompensation=0.05),
        atmosphere={"density": 0.34, "haze": 1.6, "color": "E6EEF8", "decay": "A9BCD6"},
    ),
    "ModelKit": dict(
        origin=(11500, 200, 0), ceiling=70, killDepth=30, kit="ModelKit",
        apron={"w": 50, "look": "desk"},  # the cutting mat lies on a wooden desk; the lamp stands on it
        looks=dict(
            deck=lk("3E7B5A", "cuttingmat", topOnly=True), default=lk("D9D4C8"), cover=lk("D9D4C8"),
            low=lk("B9BEC4"), pillar=lk("F0EEE6"), deck2=lk("6B4FA0"), ramp=lk("E3B33A"), plinth=lk("C25B3A"),
            red=lk("C8443B"), blue=lk("3B6FC8"), desk=lk("B58A62", "planks"), book=lk("6B4FA0"), book2=lk("C25B3A"), tape=lk("D8CBA8"), steel=lk("8E949B"),
        ),
        rowlooks=[("Paint pot A", "red"), ("Paint pot B", "blue"), ("Book top", "book"), ("Book step low", "book2"),
                  ("Book step", "book2"), ("Tape", "tape"), ("Craft knife", "steel"), ("Ruler", "low"), ("Pencil ramp", "ramp"),
                  ("Pencil cup", "blue")],
        lighting=light(14, ColorShift_Top="FFF1DC"),
        atmosphere={"density": 0.22, "haze": 0.8, "color": "EDE6DA", "decay": "B8AE9E"},
    ),
    "OldTown": dict(
        origin=(6500, 200, -1500), ceiling=80, killDepth=30, id="OldTown3", kit="Town", looks=TOWN_LOOKS,
        rowlooks=[("Clock tower", "tower"), ("Tower steps", "plinth"), ("Stall", "stall"), ("Cart", "wood"), ("Barrels", "wood"),
                  ("Block", "block")],
        lighting=light(15, ColorShift_Top="FFE6C6"),
        atmosphere={"density": 0.28, "haze": 1.2, "color": "E9DECF", "decay": "B3A08A"},
    ),
    "Metro": dict(
        origin=(7500, 200, -1500), ceiling=40, killDepth=30, id="Metro3", kit="Metro3",
        roof={"h": 22, "holes": [[-40, 60, 20, 30, True], [40, 60, 20, 30, True]]},
        looks=dict(
            deck=lk("B9BBBF", "pavers", topOnly=True), default=lk("C9CBD0", "concrete"), cover=lk("C9CBD0", "concrete"),
            low=lk("8D9197", "tread"), pillar=lk("8D9197", "concrete"), deck2=lk("7A7E85", "tread"), ramp=lk("7A7E85", "tread"),
            bridge=lk("4B4F55", "tread"), roof=lk("6A6E75", "concrete"), train=lk("D3D6DB", "tread"), accent=lk("C2413A"),
        ),
        rowlooks=[("Train", "train"), ("Kiosk", "accent"), ("Map board", "accent"), ("Footbridge", "deck2")],
        lighting=light(12, Brightness=2.6, Ambient="8E929A", OutdoorAmbient="B2B8C4", ExposureCompensation=0.2),
        atmosphere={"density": 0.32, "haze": 0.8, "color": "DDE1E8", "decay": "9CA4B2"},
    ),
    "Greenhouse": dict(
        origin=(8500, 200, -1500), ceiling=80, killDepth=30, id="Greenhouse3", kit="Greenhouse3",
        walls={"h": 16, "look": "glasswall"},
        looks=dict(
            deck=lk("C4BBA9", "pavers", topOnly=True), default=lk("6E4F3A", "planks"), cover=lk("3F7A47"),
            low=lk("B07D5E", "brick"), pillar=lk("4E8A4F"), deck2=lk("E8E8E2", "tread"), ramp=lk("E8E8E2", "tread"),
            bed=lk("6E4F3A", "planks"), glass=lk("BFE3D0", transparency=0.55), glasswall=lk("CFEBDD", transparency=0.6), fountain=lk("C9C3B6", "brick"),
        ),
        rowlooks=[("Bed", "bed"), ("Planter", "bed"), ("Potting", "bed"), ("Seed", "bed"), ("Glass case", "glass"),
                  ("Fountain", "fountain"), ("Cold frame", "glass"), ("Spawn screen", "bed"), ("Water butt", "bed")],
        lighting=light(12.5, ColorShift_Top="F4FFE8", Ambient="88908A", OutdoorAmbient="B4C2B6"),
        atmosphere={"density": 0.3, "haze": 1.4, "color": "E4EEE0", "decay": "A6BCA4"},
    ),
}

KIND_LOOK = {"full": "cover", "baffle": "cover", "low": "low", "pillar": "pillar", "deck": "deck2", "plinth": "low",
             "ramp": "ramp", "bridge": "bridge", "decor": "default"}

# map -> [(row name prefix, kit piece, extra)]; filled as each theme's kit lands. First match wins, so a longer
# prefix that must not take a piece ("Penthouse stair") comes before the shorter one ("Penthouse").
PIECES: dict = {
    "Rooftops": [
        ("Stair hut", "StairHut", {}), ("AC unit", "ACUnit", {}), ("Water tank", "WaterTank", {}), ("Roof shed", "RoofShed", {}),
        ("Vent stack", "VentStack", {}), ("Parapet", "Parapet", {}), ("Penthouse stair", "", {}), ("Penthouse", "Penthouse", {}),
        ("Bridge mid", "SteelBridge", {}), ("Bridge east", "PlankBridge", {}), ("Bridge west", "PlankBridge", {}),
        ("Billboard", "Billboard", {}), ("Skylight", "Skylight", {}), ("Duct run", "DuctRun", {}),
    ],
    "Courtyard": [
        ("Clock tower", "ClockTower", {}), ("Tower steps", "TowerSteps", {}), ("Gate wall", "GateWall20", {}),
        ("Arcade walk", "Arcade40", {}), ("Arcade pier", "ArcadePier", {}), ("Arcade stair", "", {}),
        ("Stall N", "Stall15x5", {}), ("Stall S", "Stall10x15", {}), ("Stall W", "Stall10x5", {}), ("Stall E", "Stall15x5", {}),
        ("Planter", "Planter", {}), ("Well", "Well", {}), ("Cart", "Cart", {}), ("Crates", "Crates", {}),
    ],
    "OldTown": [
        ("Clock tower", "ClockTower", {}), ("Tower steps", "TowerSteps", {}), ("Gate wall", "GateWall30", {}),
        ("Block NW", "Block40", {}), ("Block NE", "Block30", {}), ("Block W", "Block30", {}),
        ("Arcade walk", "Arcade20", {}), ("Arcade stair", "", {}), ("Arcade pier", "ArcadePier", {}),
        ("Stall A", "Stall15x5", {}), ("Stall B", "Stall5x15", {}), ("Planter", "Planter", {}), ("Fountain", "Fountain", {}),
        ("Cart", "Cart", {}), ("Barrels", "Barrels", {}), ("Well", "Well", {}),
    ],
    "Foundry": [
        ("Ingot stack", "IngotStack20x5", {}), ("Catwalk stair", "", {}), ("Catwalk post", "", {}), ("Catwalk", "Catwalk30", {}),
        ("Press", "Press", {}), ("Mould row", "MouldRow", {}), ("Hopper", "Hopper", {}), ("Ladle cart", "LadleCart", {}),
        ("Coil stack", "CoilStack", {}), ("Bridge", "ChannelBridge", {}),
    ],
    "Snowpeak": [
        ("Lodge roof", "LodgeRoof", {}), ("Hearth", "Hearth", {}), ("Lodge wall N", "LodgeWall10x5", {}),
        ("Lodge wall E", "LodgeWall5x10", {}), ("Woodpile", "Woodpile20x5", {}), ("Pine", "Pine", {}), ("Snowbank", "Snowbank", {}),
        ("Ski rack", "SkiRack", {}), ("Sled shed", "SledShed", {}), ("Woodshed", "Woodshed", {}), ("Porch", "Porch", {}),
    ],
    "ModelKit": [
        ("Glue pot", "GluePot", {}), ("Parts box", "PartsBox", {}), ("Paint pot A", "PaintPotRed", {}),
        ("Paint pot B", "PaintPotBlue", {}), ("Ruler", "Ruler", {}), ("Pencil ramp", "PencilRamp", {}),
        ("Pencil cup", "PencilCup", {}), ("Book top", "BookTop", {}), ("Book step low", "BookStepLow", {}),
        ("Book step", "BookStep", {}), ("Sprue frame", "SprueFrame", {}), ("Craft knife", "CraftKnife", {}),
        ("Tape roll", "TapeRoll", {}),
    ],
    "Bunker": [
        ("Generator", "Generator", {}), ("Blast wall", "BlastWall", {}), ("Locker row", "LockerRow", {}),
        ("Crate stack", "CrateStack", {}), ("Console", "Console", {}), ("Overlook step", "", {}),
        ("Overlook", "Overlook", {"pieceYaw": 180}),
    ],
    "Metro": [
        ("Footbridge", "Footbridge", {}), ("Train", "TrainCar", {}), ("Column", "Column", {}), ("Spawn wall", "SpawnWall", {}),
        ("Kiosk", "Kiosk", {}), ("Ticket gates", "TicketGates", {}), ("Vending", "Vending", {"pieceYaw": 180}),
        ("Stairwell", "Stairwell", {}), ("Map board", "MapBoard", {}),
    ],
    "Greenhouse": [
        ("Fountain", "Fountain", {}), ("Dome bridge", "IronBridge", {}), ("Bridge landing", "IronLanding", {}),
        ("Spawn screen", "PottingWall", {}), ("Planter ring NE", "Bed15x5", {}), ("Planter ring NW", "Bed5x15", {}),
        ("Hedge W", "Hedge5x20", {}), ("Hedge E", "Hedge5x15", {}), ("Hall wall E", "HallWall60", {}),
        ("Hall wall W", "HallWall40", {}), ("Bed E1", "Bed10x20", {}), ("Bed W1", "Bed10x25", {}), ("Bed mid", "Bed20x5", {}),
        ("Bed N", "Bed15x5", {}), ("Potting bench", "PottingBench", {}), ("Palm", "Palm", {}), ("Seed crates", "SeedCrates", {}),
        ("Glass case", "GlassCase", {}), ("Cold frame", "ColdFrame", {}), ("Water butt", "WaterButt", {}),
    ],
}
META_PROPS = {
    # piece, x, z, y, yaw, mirrored
    "Rooftops": [["TowerCrane", 62, -20, 0, 0, False]],
    "Foundry": [["Furnace", 60, 0, 0, 0, False]],
    # a pine treeline past the east and north edges (mirrored to west and south), clear of the gondola station
    "Snowpeak": [["GondolaStation", 68, 78, 0, 0, False]]
    + [["Pine", 57 + 5 * (i % 2), -63 + 11 * i, 0, 37 * i, True] for i in range(12)]
    + [["Pine", -44 + 11 * i, 77 + 5 * (i % 2), 0, 53 * i, True] for i in range(8)],
    # the lamp's arm reaches 32 studs toward -X, so the shade hangs over the east third of the bench
    "ModelKit": [["DeskLamp", 72, -20, 0, 0, False]],
    # floodlights under the shaft rim and along the corridors (roof underside at 14)
    "Bunker": [["ShaftLamp", 13.5, 0, 14, 90, True], ["ShaftLamp", 0, 13.5, 14, 0, True], ["ShaftLamp", 0, 40, 14, 0, True],
               ["ShaftLamp", 32, 25, 14, 90, True], ["ShaftLamp", -30, 55, 14, 0, True]],
    # two-faced clocks over the trench, clear of both trains
    "Metro": [["StationClock", 0, 40, 15, 0, True]],
    # yaw 20 puts the four legs at least 6.6 studs from every greybox box (checked against the plan)
    "Greenhouse": [["GlassDome", 0, 0, 0, 20, False]],
}


def _rise(ramp: Box, rows: list) -> str:
    # landings standing on the floor first: a ramp can also touch an elevated deck (a footbridge) at one corner
    for d in sorted(rows, key=lambda r: r.base > 0):
        if d.kind in ("deck", "plinth") and abs(d.h - ramp.h) < 0.1 and L.seg_gap(ramp, d) == 0.0:
            dx, dz = d.x - ramp.x, d.z - ramp.z
            if abs(dz) >= abs(dx):
                return "+z" if dz > 0 else "-z"
            return "+x" if dx > 0 else "-x"
    return "+z"


def data(plan: Plan) -> dict:
    m = META[plan.name]
    xs = [p[0] for p in plan.room]
    zs = [p[1] for p in plan.room]
    rows = []
    group = plan.center + plan.half
    for b in group:
        look = KIND_LOOK.get(b.kind, "cover")
        for sub, lkey in m.get("rowlooks", []):
            if b.name.startswith(sub):
                look = lkey
                break
        extra = {}
        if b.kind == "ramp":
            extra["rise"] = _rise(b, group)
        if b.kind == "bridge" and b.h < 0:
            extra["thick"] = 4
        piece = ""
        for sub, pc, ex in PIECES.get(plan.name, []):
            if b.name.startswith(sub):
                piece = pc
                extra.update(ex)
                break
        rows.append([b.name, b.kind, b.x, b.z, b.sx, b.sz, b.h, b.yaw, b.base, look, piece, extra])
    d = {
        "id": m.get("id", plan.name), "version": "v1 overnight 2026-11-16", "origin": list(m["origin"]),
        "hx": max(xs), "hz": max(zs), "ceiling": m["ceiling"], "killDepth": m["killDepth"], "kit": m.get("kit"),
        "center": len(plan.center), "rows": rows, "spawns": [list(s) for s in plan.spawns_a],
        "looks": m["looks"], "textures": TEX, "lighting": m["lighting"], "atmosphere": m.get("atmosphere", {}),
        "props": m.get("props", META_PROPS.get(plan.name, [])),
    }
    for k in ("roof", "under", "water", "walls", "apron"):
        if k in m:
            d[k] = m[k]
    return d


def luau(v) -> str:
    if isinstance(v, dict):
        return "{" + ", ".join(f"{k} = {luau(x)}" for k, x in v.items()) + "}"
    if isinstance(v, (list, tuple)):
        return "{" + ", ".join(luau(x) for x in v) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return f"{v:g}"
    if v is None:
        return "nil"
    return json.dumps(v)
