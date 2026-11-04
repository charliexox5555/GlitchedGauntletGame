#!/usr/bin/env python3
"""Greenhouse art placements: the Blender kit laid onto tools/maps/greenhouse_layout.py, from the same numbers.

    python tools/maps/greenhouse_art.py           placements + the coplanar (z-fighting) check
    python tools/maps/greenhouse_layout.py --write   regenerates Greybox.luau and Art.luau (calls write() here)

Every kit placement comes from a layout solid or wall run, so door frames always match their openings and every
prop fills the collision block it dresses. Writes:
  tools/studio/maps/Greenhouse/Art.luau          the art pass (placements, hides, finishes, tints)
  art-source/maps/Greenhouse/plan.json           the same data for the offline Blender preview and its mesh check

The coplanar check mirrors tools/studio/maps/Audit.luau with the boxes Studio will see: every visible greybox Part,
every plain decor Part, and the bounding box of every kit MeshPart (from the export JSON in
art-source/maps/Greenhouse/Exports/, the piece placed and turned the way MapKit's put() does it). Raycasts against a
MeshPart hit its collision box (Box fidelity), so box faces are what the audit compares.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import greenhouse_layout as L  # noqa: E402

ROOT = L.ROOT
ART_OUT = ROOT / "tools/studio/maps/Greenhouse/Art.luau"
PLAN_OUT = ROOT / "art-source/maps/Greenhouse/plan.json"
EXPORTS = ROOT / "art-source/maps/Greenhouse/Exports"
GROUPS = ("Structure", "Garden")

# Finishes for the greybox parts that stay visible: look -> (Roblox material, colour).
LOOKS = {
    "dome_floor": ("Limestone", "D9D2C2"),
    "paving": ("Pavement", "C9C1AF"),
    "flags": ("Limestone", "E3D9C5"),
    "boards": ("WoodPlanks", "9C7A55"),
    "gravel": ("Pebble", "CDBF9C"),
    "shed_floor": ("Brick", "8E5E4A"),
    "plaster_ceiling": ("Plaster", "EFE8D8"),
    "lodge_wall": ("Plaster", "E6DCC6"),
    "lodge_ceiling": ("WoodPlanks", "8C6A48"),
    "shed_ceiling": ("WoodPlanks", "7E6448"),
    "brick": ("Brick", "9C5B44"),
    "lawn": ("Grass", "7EA35A"),
}

# Which kit piece dresses which collision block (by name), and its turn. Sizes are checked against the block.
PROP = {
    "PalmPlanter": "PalmPlanter",
    "Fernery": "Fernery",
    "WingRockery": "Rockery12x6",
    "Statue": "Pedestal4",
    "StatuePlinth": "HedgeBox8x4",
    "Hedge": "HedgeBox8x4",
    "WardianCase": "WardianCase",
    "CitrusTub": "CitrusTub",
    "ColdFrame": "ColdFrame",
    "Urn": "Urn",
    "PottingBench": "PottingBench",
    "ShelfRack": "ShelfRack",
    "Boiler": "Boiler",
    "CrateStack": "CrateStack",
}
# Kit piece footprints (along map X, along map Z at yaw 0) and heights, for the size check.
FOOT = {
    "PalmPlanter": (6, 9, 9),
    "Fernery": (8, 16, 9),
    "Rockery12x6": (12, 6, 10),
    "Pedestal4": (4, 4, 9),
    "HedgeBox8x4": (8, 4, 9),
    "WardianCase": (8, 4, 9),
    "CitrusTub": (4, 4, 3),
    "ColdFrame": (8, 3, 3),
    "Urn": (4, 4, 9),
    "PottingBench": (6, 3, 3),
    "ShelfRack": (6, 2, 9),
    "Boiler": (8, 8, 10),
    "CrateStack": (4, 4, 9),
    "Bed6x6": (6, 6, 3),
    "Bed6x12": (6, 12, 3),
    "Bed6x14": (6, 14, 3),
    "Bed6x18": (6, 18, 3),
    "Bed6x20": (6, 20, 3),
}
BEDS = {"FernBed", "FernBedW", "FernBedE", "WingBed"}


class Art:
    def __init__(self):
        self.place = []  # (section, piece, x, y, z, yaw)
        self.parts = []  # plain decor Parts: (section, name, x0, x1, y0, y1, z0, z1, look)

    def put(self, sec, piece, x, y, z, yaw=0.0):
        self.place.append((sec, piece, float(x), float(y), float(z), float(yaw) % 360))

    def both(self, sec, piece, x, y, z, yaw=0.0):
        self.put(sec, piece, x, y, z, yaw)
        self.put(sec, piece, -x, y, -z, yaw + 180)

    def walls(self):
        """Tile every glass and stucco run with 16 / 8 / 4 / 2 bays and a door piece per opening; a timber frame on
        every brick-wall door. Runs are team B's set: each is also placed turned."""
        for run in L.WALL_RUNS:
            style, axis, a0, a1, at, y1, doors = run["style"], run["axis"], run["a0"], run["a1"], run["at"], run["y1"], run["doors"]
            yaw = 0.0 if axis == "z" else 90.0
            sec = run["name"]

            def xyz(a):
                return (at, a) if axis == "z" else (a, at)

            if style == "brick":
                for d0, d1 in doors:
                    assert d1 - d0 == 8, run
                    x, z = xyz((d0 + d1) / 2)
                    self.both("Doors", "ShedDoor8", x, 0, z, yaw)
                continue
            assert y1 == L.HALL, run
            prefix = {"glass": "Glass", "stucco": "Stucco"}[style]
            cur = a0
            spans = []
            for d0, d1 in sorted(doors):
                spans.append((cur, d0))
                assert d1 - d0 == 8, run
                spans.append(("door", d0))
                cur = d1
            spans.append((cur, a1))
            for s in spans:
                if s[0] == "door":
                    x, z = xyz(s[1] + 4)
                    self.both("Walls", prefix + "Door8", x, 0, z, yaw)
                    continue
                p, end = s
                while end - p > 1e-6:
                    for w in (16, 8, 4, 2):
                        if end - p >= w - 1e-6:
                            break
                    else:
                        raise AssertionError(f"{sec}: a {end - p} gap can't be tiled")
                    x, z = xyz(p + w / 2)
                    self.both("Walls", f"{prefix}Wall{w}", x, 0, z, yaw)
                    p += w

    def build(self):
        self.walls()
        # Roofs: ridge-and-furrow bays over the Fern House and the Wing.
        for z in range(46, 82, 8):
            self.both("Roofs", "RoofSpan48", 0, 0, z, 0)
        for z in range(-36, 40, 8):
            self.both("Roofs", "RoofSpan32", 58, 0, z, 0)
        # Heroes in the middle (self-symmetric: placed once), the gallery and each team's stair.
        self.put("Dome", "Dome", 0, 0, 0, 0)
        self.put("Dome", "Fountain", 0, 0, 0, 0)
        self.put("Dome", "Bridge", 0, 0, 0, 0)
        self.both("Dome", "Gallery", 34, 0, 0, 0)
        self.both("Dome", "IronStair", -10, 0, 36, 180)
        # The Lodge's side doors (timber frames) and the pools.
        self.both("Doors", "ShedDoor8", -17, 0, 110, 0)
        self.both("Doors", "ShedDoor8", 17, 0, 110, 0)
        self.both("Garden", "LilyPool", 61, 0, 0, 0)
        self.both("Garden", "Pond", -57, 0, 58, 0)
        # Props: one per collision block, sized to it.
        for b in L.HALF:
            name = b.name
            piece = PROP.get(name)
            if name in BEDS:
                w, d = round(b.x1 - b.x0), round(b.z1 - b.z0)
                piece = f"Bed{min(w, d)}x{max(w, d)}"
            if piece is None:
                continue
            fx, fz, fh = FOOT[piece]
            w, d = round(b.x1 - b.x0), round(b.z1 - b.z0)
            if (w, d) == (fx, fz):
                yaw = 0.0
            elif (w, d) == (fz, fx):
                yaw = 90.0
            else:
                raise AssertionError(f"{name} {w}x{d} doesn't fit {piece} {fx}x{fz}")
            assert abs((b.y1 - b.y0) - fh) < 1e-6, (name, b.y1 - b.y0, piece, fh)
            self.both("Garden", piece, b.c[0], 0, b.c[2], yaw)
        # Lawn panels on the Terrace (0.2 proud of the gravel), clear of every prop.
        for x0, x1, z0, z1 in ((-72, -66, 44, 66), (-46, -30, 54, 60), (-66, -54, 76, 82), (-72, -62, 84, 94)):
            for s in (1, -1):
                xa, xb = sorted((x0 * s, x1 * s))
                za, zb = sorted((z0 * s, z1 * s))
                self.parts.append(("Garden", "Lawn", xa, xb, 0.0, 0.2, za, zb, "lawn"))
        return self


# ------------------------------------------------------------------ boxes Studio will see

def load_kit():
    parts = {}
    for g in GROUPS:
        f = EXPORTS / f"{g}.json"
        if not f.exists():
            continue
        data = json.loads(f.read_text(encoding="utf-8"))
        for p in data["parts"]:
            parts.setdefault(p["piece"], []).append(p)
    return parts


def part_box(p, x, y, z, yaw):
    """A kit part's box in map space: Blender (x, y, z) -> Roblox (x, z, -y), turned by yaw, moved to (x, y, z)."""
    cx, cy, cz = p["center"]
    sx, sy, sz = p["size"]
    lx, ly, lz = cx, cz, -cy
    ex, ey, ez = sx, sz, sy
    t = math.radians(yaw)
    c, s = round(math.cos(t), 9), round(math.sin(t), 9)
    wx = lx * c + lz * s
    wz = -lx * s + lz * c
    if abs(s) > 0.5:
        ex, ez = ez, ex
    return (x + wx - ex / 2, y + ly - ey / 2, z + wz - ez / 2), (x + wx + ex / 2, y + ly + ey / 2, z + wz + ez / 2)


def studio_boxes(art, kit):
    boxes = L.visible_part_boxes()
    for sec, name, x0, x1, y0, y1, z0, z1, look in art.parts:
        boxes.append(("P:" + name, (x0, y0, z0), (x1, y1, z1), True))
    missing = set()
    for sec, piece, x, y, z, yaw in art.place:
        if piece not in kit:
            missing.add(piece)
            continue
        assert abs(yaw % 90) < 1e-6, (piece, yaw)
        for p in kit[piece]:
            if p.get("look") and p["look"].get("transparency", 0) >= 0.99:
                continue
            lo, hi = part_box(p, x, y, z, yaw)
            boxes.append((f"K:{piece}@{x:.0f},{z:.0f}:{p['name']}", lo, hi, False))
    return boxes, missing


def check(verbose=True):
    art = Art().build()
    kit = load_kit()
    boxes, missing = studio_boxes(art, kit)
    counts = {}
    for _, piece, *_ in art.place:
        counts[piece] = counts.get(piece, 0) + 1
    meshparts = sum(len(kit.get(piece, [])) * n for piece, n in counts.items())
    if verbose:
        print(f"Art: {len(art.place)} kit placements of {len(counts)} pieces, {len(art.parts)} decor Parts, {meshparts} MeshParts")
        if missing:
            print(f"  not in the export yet: {', '.join(sorted(missing))}")
    # Strict: any pair with a Part in it (Parts are boxes, so box faces are their real faces). Kit-only pairs are
    # bounding-box candidates; the Studio audit and tools/blender/preview_map_greenhouse.py test the real triangles.
    allbad = L.coplanar_boxes(boxes)
    bad = [f for f in allbad if not (f[0].startswith("K:") and f[1].startswith("K:"))]
    if verbose:
        print(f"Coplanar check ({len(boxes)} boxes: visible Parts and kit MeshPart boxes): {len(bad)} z-fighting pairs with a Part; "
              f"{len(allbad) - len(bad)} kit-only box candidates (the triangle check in the Blender preview decides those)")
        for a, b, where, hits in bad[:40]:
            ax, pa, u, v = where
            print(f"  {a}  +  {b}   plane {'xyz'[ax]}={pa:.2f} near ({u:.1f}, {v:.1f}), {hits} hits")
    return art, bad, missing, meshparts


# ------------------------------------------------------------------ outputs

def lua(v):
    if isinstance(v, str):
        return json.dumps(v)
    return L.lua_num(v)


ART_TEMPLATE = """--!strict
-- Greenhouse art pass: GENERATED by tools/maps/greenhouse_layout.py --write (placements in tools/maps/greenhouse_art.py).
-- Dresses the greybox with the Blender kit groups Structure and Garden (tools/blender/build_map_kit_greenhouse.py,
-- asset ids in art-source/maps/Greenhouse/Exports/assets.json). Run after the greybox and after installing the kit:
--   python tools/studio/maps/kit_bundle.py Greenhouse Structure -o gh_kit1.luau   (run it)
--   python tools/studio/maps/kit_bundle.py Greenhouse Garden -o gh_kit2.luau      (run it)
--   python tools/studio/maps/bundle.py Greenhouse Greybox Art Lighting -o greenhouse.luau (then this)
-- Re-runnable. The greybox stays the collision: parts without a Look attribute are replaced by the kit and hidden
-- (only when every kit piece is installed, so a missing kit never leaves holes); parts with a Look get that finish.
-- Parts named *_Accent take the end colour of the half they stand in (B blue, A yellow); wall and roof glass casts
-- no shadow, so the sun comes in.

newMap("Greenhouse", CFrame.new(1500, 200, -1500))

local ACCENT_A = Color3.fromHex("%(accent_a)s")
local ACCENT_B = Color3.fromHex("%(accent_b)s")

-- { section, piece, x, y, z, yaw } in map space, both halves written out.
local PLACE: { { any } } = {
%(place)s}

-- Plain decor Parts { section, name, x0, x1, y0, y1, z0, z1, look } (no collision).
local PARTS: { { any } } = {
%(parts)s}

-- Finishes: look -> { material, colour }.
local LOOKS: { [string]: { string } } = {
%(looks)s}

local sections: { [string]: Folder } = {}
local function sec(name: string): Folder
	local f = sections[name]
	if not f then
		f = section("Art", name)
		sections[name] = f
	end
	return f :: Folder
end

local placed = 0
for _, p in PLACE do
	local m = put(sec(p[1] :: string), p[2] :: string, at(p[3] :: number, p[4] :: number, p[5] :: number, p[6] :: number))
	if m then
		placed += 1
		local colour = if (p[5] :: number) < 0 then ACCENT_A else ACCENT_B
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				if string.sub(d.Name, -7) == "_Accent" then
					d.Color = colour
				elseif string.sub(d.Name, -6) == "_Glass" or string.sub(d.Name, -6) == "_Water" then
					d.CastShadow = false
				end
			end
		end
	end
end

for _, p in PARTS do
	local look = LOOKS[p[9] :: string]
	local x0, x1, y0, y1, z0, z1 =
		p[3] :: number, p[4] :: number, p[5] :: number, p[6] :: number, p[7] :: number, p[8] :: number
	local part = box(
		sec(p[1] :: string),
		p[2] :: string,
		Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Color3.fromHex(look[2]),
		{ material = (Enum.Material :: any)[look[1]], castShadow = false }
	)
	decor(part)
end

local missing = missingReport()
local hidden, finished = 0, 0
local grey = root():FindFirstChild("Greybox")
assert(grey, "run the greybox first")
for _, d in grey:GetDescendants() do
	if d:IsA("BasePart") then
		local look = d:GetAttribute("Look")
		if type(look) == "string" and LOOKS[look] then
			d.Material = (Enum.Material :: any)[LOOKS[look][1]]
			d.Color = Color3.fromHex(LOOKS[look][2])
			finished += 1
		elseif missing == "all kit pieces found" then
			hide(d)
			hidden += 1
		end
	end
end

report(
	string.format(
		"Greenhouse art: %%d of %%d pieces placed, %%d decor parts, %%d greybox parts hidden, %%d finished; %%s",
		placed,
		#PLACE,
		#PARTS,
		hidden,
		finished,
		missing
	)
)
"""


def write():
    art, bad, missing, meshparts = check(verbose=True)
    place = "".join(f"\t{{ {lua(s)}, {lua(p)}, {lua(x)}, {lua(y)}, {lua(z)}, {lua(yaw)} }},\n" for s, p, x, y, z, yaw in art.place)
    parts = "".join("\t{ " + ", ".join(lua(v) for v in row) + " },\n" for row in art.parts)
    looks = "".join(f'\t{k} = {{ "{m}", "{c}" }},\n' for k, (m, c) in LOOKS.items())
    ART_OUT.write_text(ART_TEMPLATE % {"accent_a": L.ACCENT["A"][1:], "accent_b": L.ACCENT["B"][1:], "place": place, "parts": parts, "looks": looks}, encoding="utf-8")
    print(f"Wrote {ART_OUT}")
    plan = {
        "about": "Greenhouse plan for the offline Blender preview (tools/blender/preview_map_greenhouse.py). Map space: +X east, +Y up, +Z = team B. Blender = (x, -z, y).",
        "dome_profile": L.DOME_PROFILE,
        "place": [dict(section=s, piece=p, x=x, y=y, z=z, yaw=yaw) for s, p, x, y, z, yaw in art.place],
        "parts": [dict(section=r[0], name=r[1], box=list(r[2:8]), look=LOOKS[r[8]]) for r in art.parts],
        "solids": [
            dict(name=b.name, kind=b.kind, shape=b.shape, c=list(b.c), s=list(b.s), axes=[list(a) for a in b.axes] if b.axes else None,
                 up=b.up, look=LOOKS.get(b.look) if b.look else None)
            for b in L.BLOCKS if b.kind != "barrier"
        ],
        "accent": L.ACCENT,
    }
    PLAN_OUT.parent.mkdir(parents=True, exist_ok=True)
    PLAN_OUT.write_text(json.dumps(plan, indent=0), encoding="utf-8")
    print(f"Wrote {PLAN_OUT}")
    return bad


if __name__ == "__main__":
    if "--write" in sys.argv:
        write()
    else:
        check()
