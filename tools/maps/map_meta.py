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
        origin=(6500, 200, 0), ceiling=70, killDepth=25, kit="Rooftops",
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
        rowlooks=[("Clock tower", "tower"), ("Tower steps", "plinth"), ("Stall", "stall"), ("Cart", "wood"), ("Crates", "wood")],
        lighting=light(14.2, ColorShift_Top="FFEBD2"),
        atmosphere={"density": 0.26, "haze": 1.0, "color": "E9E0D2", "decay": "B3A28E"},
    ),
    "Bunker": dict(
        origin=(8500, 200, 0), ceiling=40, killDepth=30, kit="Bunker",
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
        under={"y": -3, "look": "molten"},
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
        origin=(10500, 200, 0), ceiling=70, killDepth=30, kit="Snowpeak",
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
        looks=dict(
            deck=lk("3E7B5A", "cuttingmat", topOnly=True), default=lk("D9D4C8"), cover=lk("D9D4C8"),
            low=lk("B9BEC4"), pillar=lk("F0EEE6"), deck2=lk("6B4FA0"), ramp=lk("E3B33A"), plinth=lk("C25B3A"),
            red=lk("C8443B"), blue=lk("3B6FC8"), book=lk("6B4FA0"), book2=lk("C25B3A"), tape=lk("D8CBA8"), steel=lk("8E949B"),
        ),
        rowlooks=[("Paint pot A", "red"), ("Paint pot B", "blue"), ("Book top", "book"), ("Book step low", "book2"),
                  ("Book step", "book2"), ("Tape", "tape"), ("Craft knife", "steel"), ("Ruler", "low"), ("Pencil ramp", "ramp"),
                  ("Pencil cup", "blue")],
        lighting=light(14, ColorShift_Top="FFF1DC"),
        atmosphere={"density": 0.22, "haze": 0.8, "color": "EDE6DA", "decay": "B8AE9E"},
    ),
    "OldTown": dict(
        origin=(6500, 200, -1500), ceiling=80, killDepth=30, kit="Town", looks=TOWN_LOOKS,
        rowlooks=[("Clock tower", "tower"), ("Tower steps", "plinth"), ("Stall", "stall"), ("Cart", "wood"), ("Barrels", "wood"),
                  ("Block", "block")],
        lighting=light(15, ColorShift_Top="FFE6C6"),
        atmosphere={"density": 0.28, "haze": 1.2, "color": "E9DECF", "decay": "B3A08A"},
    ),
    "Metro": dict(
        origin=(7500, 200, -1500), ceiling=40, killDepth=30, kit="Metro",
        roof={"h": 22, "holes": [[-40, 60, 20, 30, True], [40, 60, 20, 30, True]]},
        looks=dict(
            deck=lk("B9BBBF", "pavers", topOnly=True), default=lk("C9CBD0", "concrete"), cover=lk("C9CBD0", "concrete"),
            low=lk("8D9197", "tread"), pillar=lk("8D9197", "concrete"), deck2=lk("7A7E85", "tread"), ramp=lk("7A7E85", "tread"),
            bridge=lk("4B4F55", "tread"), roof=lk("6A6E75", "concrete"), train=lk("D3D6DB", "tread"), accent=lk("E3B12C"),
        ),
        rowlooks=[("Train", "train"), ("Kiosk", "accent"), ("Map board", "accent"), ("Footbridge", "deck2")],
        lighting=light(12, Brightness=2.6, Ambient="8E929A", OutdoorAmbient="B2B8C4", ExposureCompensation=0.2),
        atmosphere={"density": 0.32, "haze": 0.8, "color": "DDE1E8", "decay": "9CA4B2"},
    ),
    "Greenhouse": dict(
        origin=(8500, 200, -1500), ceiling=80, killDepth=30, kit="Greenhouse",
        looks=dict(
            deck=lk("C4BBA9", "pavers", topOnly=True), default=lk("6E4F3A", "planks"), cover=lk("3F7A47"),
            low=lk("B07D5E", "brick"), pillar=lk("4E8A4F"), deck2=lk("E8E8E2", "tread"), ramp=lk("E8E8E2", "tread"),
            bed=lk("6E4F3A", "planks"), glass=lk("BFE3D0", transparency=0.55), fountain=lk("C9C3B6", "brick"),
        ),
        rowlooks=[("Bed", "bed"), ("Planter", "bed"), ("Potting", "bed"), ("Seed", "bed"), ("Glass case", "glass"),
                  ("Fountain", "fountain"), ("Cold frame", "glass"), ("Spawn screen", "bed"), ("Water butt", "bed")],
        lighting=light(12.5, ColorShift_Top="F4FFE8", Ambient="88908A", OutdoorAmbient="B4C2B6"),
        atmosphere={"density": 0.3, "haze": 1.4, "color": "E4EEE0", "decay": "A6BCA4"},
    ),
}

KIND_LOOK = {"full": "cover", "baffle": "cover", "low": "low", "pillar": "pillar", "deck": "deck2", "plinth": "low",
             "ramp": "ramp", "bridge": "bridge", "decor": "default"}

# map -> [(row name prefix, kit piece, extra)]; filled as each theme's kit lands
PIECES: dict = {}


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
        "id": plan.name, "version": "v1 overnight 2026-11-16", "origin": list(m["origin"]),
        "hx": max(xs), "hz": max(zs), "ceiling": m["ceiling"], "killDepth": m["killDepth"], "kit": m.get("kit"),
        "center": len(plan.center), "rows": rows, "spawns": [list(s) for s in plan.spawns_a],
        "looks": m["looks"], "textures": TEX, "lighting": m["lighting"], "atmosphere": m.get("atmosphere", {}),
        "props": m.get("props", []),
    }
    for k in ("roof", "under", "water"):
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
