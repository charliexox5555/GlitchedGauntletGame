"""Old Town art placement: turns the checked layout (oldtown_layout.py) into kit placements.

Called by `python tools/maps/oldtown_layout.py --write`, which writes tools/studio/maps/OldTown/Art.luau.
Run alone to print the placement summary:  python tools/maps/oldtown_art.py

The kit pieces and their origins are documented in tools/blender/build_map_kit_oldtown.py. Roblox yaw here is
MapKit's: at(x, y, z, yaw) turns a piece's local +X toward (cos yaw, -sin yaw) in (x, z), so a piece facing
+X / -Z / -X / +Z has yaw 0 / 90 / 180 / 270.

What gets placed:
- every exposed face of every house: facade modules per storey (doors where the layout has door voids),
  cornices or parapets at the eave, the attic band on the four-storey perimeter, quoins on exposed corners;
- roofs (slope modules along the eaves, gable ends) and flat roof tops;
- arcade bays, the terrace balustrade, the west arcade's tiled roof, passage arches, the Cafe stair;
- the heroes (fountain, city gates, pavilions, clock tower) and a prop on every cover block;
- dressing: banners, wall lanterns, laundry lines, paving inlays;
- interiors: plaster linings on room walls and door reveals, plank floors, ceiling beams.

No z-fighting (vault/01 Design/Maps/00 Maps.md): pieces butt edge to edge, and where a W/E facade meets an S/N one
at a corner their trims would share planes (string courses, copings), so everything on a W/E face sits X_DROP lower.
Windows never sit under an arch, a porch or a shrine: those spans get plain modules. Every face a player can't see
from the map (the perimeter's outer sides) gets plain walls, so the town is closed from every side.
tools/blender/preview_map_oldtown.py --check proves it on the assembled triangles.
"""

from __future__ import annotations

import hashlib
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import oldtown_layout as L  # noqa: E402

TONES = {"cream": "#E9DCC0", "ochre": "#E0BE8A", "rose": "#DDAA8F"}
INTERIOR = "#EFE4CC"
FLOORING = "#8A6A4A"
ROOFTOP = "#CDBE9F"
X_DROP = 0.06  # facade pieces on W/E faces sit this much lower than on S/N faces (corner trims never share a plane)

FACE = {  # outward normal (x, z) -> yaw
    (1, 0): 0.0,
    (0, -1): 90.0,
    (-1, 0): 180.0,
    (0, 1): 270.0,
}

# Cover solids -> kit prop (piece, yaw relative to the solid, y offset).
PROPS = {
    "StallW": ("MarketStall", 270.0),
    "StallE": ("MarketStall", 180.0),
    "StallMid": ("MarketStall", 0.0),
    "Kiosk": ("Kiosk", 270.0),
    "PlanterS": ("PlanterLow", 90.0),
    "PlanterF": ("PlanterLow", 90.0),
    "CypressesW": ("CypressPlanter", 0.0),
    "CafeTable1": ("CafeSet", 15.0),
    "CafeTable2": ("CafeSet", -25.0),
    "CafeTable3": ("CafeSet", 40.0),
    "Well": ("Well", 0.0),
    "Cart": ("Cart", 0.0),
    "ShrineE": ("Shrine", 90.0),
    "ShrineW": ("Shrine", 90.0),
    "LanePorchW": ("StairPorch", 90.0),
    "LaneTrough": ("StairPorch", 270.0),
    "LaneCart": ("StairPorch", 270.0),
    "LanePorchE": ("StairPorch", 90.0),
    "Crates": ("Crates", 0.0),
    "AlleyCratesE": ("Crates", 30.0),
    "Barrels": ("Barrels", 90.0),
    "AlleyBarrelsW": ("Barrels", 90.0),
}


def h01(*key) -> float:
    d = hashlib.md5(repr(key).encode()).digest()
    return d[0] / 255.0


class Art:
    def __init__(self):
        self.solids = L.all_solids()
        self.buildings = L.all_buildings()
        blockers = [s for s in self.solids if s.kind in ("bldg", "perim", "arcade", "floor", "roof", "lintel")]
        self.grid = L.Grid(blockers + [s for s in self.solids if s.kind == "ground"])
        self.place = []  # (section, piece, x, y, z, yaw, side, tone)
        self.parts = []  # (section, name, x0, x1, y0, y1, z0, z1, color, material)

    # ---------------------------------------------------------- queries
    def solid_at(self, x, y, z) -> bool:
        if abs(x) > L.OUT_X or abs(z) > L.OUT_Z:
            return True
        i, j = int(math.floor(x + L.OUT_X)), int(math.floor(z + L.OUT_Z))
        i, j = min(max(i, 0), L.NX - 1), min(max(j, 0), L.NZ - 1)
        return bool(((self.grid.lo[:, i, j] < y) & (self.grid.hi[:, i, j] > y)).any())

    def open_air(self, x, y, z) -> bool:
        # Visible from the playable map: inside the playable rectangle, not inside a building (its rooms and
        # doorways included: an inner door gets linings, not a facade) and not the clock tower's base.
        if abs(x) > L.PLAY_X or abs(z) > L.PLAY_Z:
            return False
        tx0, tx1, tz0, tz1, _ = L.TOWER
        if tx0 - 1.5 <= x <= tx1 and tz0 - 1.0 <= z <= tz1 + 1.0:
            return False
        for b in self.buildings:
            if b.x0 < x < b.x1 and b.z0 < z < b.z1 and y < b.eave:
                return False
        return not self.solid_at(x, y, z)

    def void_air(self, x, z) -> bool:
        # Outside the playable map and not inside any building: a perimeter house's outer side.
        if abs(x) <= L.PLAY_X and abs(z) <= L.PLAY_Z:
            return False
        return not any(b.x0 < x < b.x1 and b.z0 < z < b.z1 for b in self.buildings)

    def attachments(self, b, n, plane, axis, a, c):
        # Spans of this face that must stay plain: (s0, s1, storeys). Arches (lane mouths, cloister gates) cover
        # the ground and first storeys where they meet the wall; porches, shrines and crates stacked against the
        # wall cover the ground storey.
        out = []
        for s in self.solids:
            if s.kind == "lintel":
                along_x = s.sx > s.sz
                depth = 4.0 if min(s.sx, s.sz) > 3 else 2.0
                if along_x:
                    ends, mid = (s.cx - s.sx / 2, s.cx + s.sx / 2), s.cz
                    if axis != "z":
                        continue
                else:
                    ends, mid = (s.cz - s.sz / 2, s.cz + s.sz / 2), s.cx
                    if axis != "x":
                        continue
                if not any(abs(e - plane) < 1e-6 for e in ends):
                    continue
                s0, s1 = max(mid - depth / 2, a), min(mid + depth / 2, c)
                if s1 > s0:
                    out.append((s0, s1, {0, 1}))
            elif s.kind in ("cover",) and s.shape == "box" and abs(s.yaw) < 1e-6:
                x0, x1, z0, z1 = s.cx - s.sx / 2, s.cx + s.sx / 2, s.cz - s.sz / 2, s.cz + s.sz / 2
                if axis == "z":
                    touch = (x0 - 0.5 <= plane <= x1 + 0.5) and (z0 < c and z1 > a)
                    s0, s1 = max(z0, a), min(z1, c)
                else:
                    touch = (z0 - 0.5 <= plane <= z1 + 0.5) and (x0 < c and x1 > a)
                    s0, s1 = max(x0, a), min(x1, c)
                if axis == "z":
                    near = (x0 <= plane + 0.6 and x1 > plane) if n[0] > 0 else (x1 >= plane - 0.6 and x0 < plane)
                else:
                    near = (z0 <= plane + 0.6 and z1 > plane) if n[1] > 0 else (z1 >= plane - 0.6 and z0 < plane)
                if touch and near and s1 > s0:
                    out.append((s0, s1, {0}))
        # Where another house (or the clock tower) stands against this face: break the module rhythm at its edges, so
        # no module straddles the inside corner (its trims would run into the other house's facade).
        others = [(o.x0, o.x1, o.z0, o.z1) for o in self.buildings if o is not b]
        tx0, tx1, tz0, tz1, _ = L.TOWER
        others.append((tx0 - 0.5, tx1, tz0 - 1.0, tz1 + 1.0))
        for x0, x1, z0, z1 in others:
            if axis == "z":
                adjacent = (x1 >= plane - 0.6 and x0 < plane) if n[0] < 0 else (x0 <= plane + 0.6 and x1 > plane)
                s0, s1 = max(z0, a), min(z1, c)
            else:
                adjacent = (z1 >= plane - 0.6 and z0 < plane) if n[1] < 0 else (z0 <= plane + 0.6 and z1 > plane)
                s0, s1 = max(x0, a), min(x1, c)
            if adjacent and s1 > s0 + 1e-6 and (s0 > a + 1e-6 or s1 < c - 1e-6):
                out.append((s0, s1, set()))
        # Snap to the 2-stud grid from the face start, merge overlaps.
        snapped = []
        for s0, s1, st in out:
            s0 = a + math.floor((s0 - a) / 2 + 1e-6) * 2
            s1 = a + math.ceil((s1 - a) / 2 - 1e-6) * 2
            snapped.append((s0, s1, st))
        snapped.sort()
        merged = []
        for s0, s1, st in snapped:
            if merged and s0 <= merged[-1][1] + 1e-6:
                m0, m1, mst = merged[-1]
                merged[-1] = (m0, max(m1, s1), mst | st)
            else:
                merged.append((s0, s1, set(st)))
        return merged

    def put(self, section, piece, x, y, z, yaw, side="A", tone=None):
        self.place.append((section, piece, round(x, 3), round(y, 3), round(z, 3), round(yaw % 360.0, 3), side, tone))

    def part(self, section, name, x0, x1, y0, y1, z0, z1, color, material):
        self.parts.append((section, name, x0, x1, y0, y1, z0, z1, color, material))

    # ---------------------------------------------------------- faces
    @staticmethod
    def faces(b):
        # (normal, plane coordinate, along-axis, a, b): along-axis "z" for the W/E faces, "x" for S/N.
        return [
            ((-1, 0), b.x0, "z", b.z0, b.z1),
            ((1, 0), b.x1, "z", b.z0, b.z1),
            ((0, -1), b.z0, "x", b.x0, b.x1),
            ((0, 1), b.z1, "x", b.x0, b.x1),
        ]

    @staticmethod
    def point(n, plane, axis, t, off=0.0):
        if axis == "z":
            return plane + n[0] * off, t
        return t, plane + n[1] * off

    def doors(self, b, n, plane, axis):
        # Door voids cut through this face: (centre along the face, storey index).
        out = []
        for v in b.voids:
            x0, x1, z0, z1, y0, y1 = v
            if axis == "z":
                touches = abs((x0 if n[0] < 0 else x1) - plane) < 1e-6 and (x1 - x0) <= 2.01
                a, c = z0, z1
            else:
                touches = abs((z0 if n[1] < 0 else z1) - plane) < 1e-6 and (z1 - z0) <= 2.01
                a, c = x0, x1
            if touches and abs((c - a) - L.DOOR_W) < 0.01:
                out.append(((a + c) / 2, int(round(y0 / L.STOREY))))
        return out

    @staticmethod
    def segments(a, b, fixed, plain=()):
        # Split a..b into module spans: the fixed 8-wide door modules, the plain spans (attachments), then 8s, 4s
        # and 2s in between. Returns (centre, width, kind, plain-storeys).
        spans = sorted([(c - 4, c + 4, "door", set()) for c in fixed] + [(p0, p1, "plain", st) for p0, p1, st in plain])
        out, cur = [], a
        for s0, s1, kind, st in spans + [(b, b, "end", set())]:
            s0 = max(s0, cur)
            gap = s0 - cur
            while gap > 1e-6:
                w = 8 if gap >= 8 - 1e-6 else 4 if gap >= 4 - 1e-6 else 2
                assert gap >= 2 - 1e-6, f"span {a}..{b} leaves {gap:.2f} (not a multiple of 2)"
                out.append((cur + w / 2, w, None, set()))
                cur += w
                gap -= w
            if kind == "door":
                out.append(((s0 + s1) / 2, 8, "door", set()))
                cur = s1
            elif kind == "plain" and s1 > cur + 1e-6:
                # (an empty storey set: a break where another house stands against the face; normal modules)
                g = s1 - cur
                while g > 1e-6:
                    w = 8 if g >= 8 - 1e-6 else 4 if g >= 4 - 1e-6 else 2
                    out.append((cur + w / 2, w, "plain", st))
                    cur += w
                    g -= w
        return out

    def classify(self, x, z):
        if abs(x) >= L.PLAY_X - 12 - 1e-6:
            return "alley"
        if abs(x) <= 20 and abs(z) >= 108:
            return "cloister"
        if abs(x) <= 44 and abs(z) <= 36:
            return "plaza"
        return "street"

    def facade(self, b):
        storeys = 4 if b.klass == "perim" else int(round(b.eave / L.STOREY))
        if b.roof[0] == "hero":
            return
        tone = b.tone
        for n, plane, axis, a, c in self.faces(b):
            yaw = FACE[n]
            drop = -X_DROP if n[1] == 0 else 0.0
            dmap = {}
            for centre, storey in self.doors(b, n, plane, axis):
                dmap.setdefault(round(centre, 3), set()).add(storey)
            segs = self.segments(a, c, sorted(dmap), self.attachments(b, n, plane, axis, a, c))
            full = [k for k, sg in enumerate(segs) if sg[1] == 8 and sg[2] != "plain"]
            for k, (t, w, kind, plain_st) in enumerate(segs):
                px, pz = self.point(n, plane, axis, t)
                ox, oz = self.point(n, plane, axis, t, 1.0)
                outer = self.void_air(ox, oz)
                cls = self.classify(ox, oz)
                idx = full.index(k) if k in full else -1
                # Next to a corner, a break (another house) or a plain span: no awning or balcony (they stand proud).
                edge = k in (0, len(segs) - 1) or any(0 <= k + d < len(segs) and segs[k + d][2] == "plain" for d in (-1, 1))
                for st in range(storeys):
                    y = st * L.STOREY
                    if outer:
                        piece = f"F_Upper{w}"  # plain wall, one part per storey (nobody sees it up close)
                    elif not self.open_air(ox, y + 6, oz):
                        continue
                    elif kind == "plain" and st in plain_st:
                        piece = f"F_Ground{w}" if st == 0 else f"F_Upper{w}"
                    else:
                        piece = self.module(b, st, w, kind, dmap.get(round(t, 3), set()), cls, idx, len(full), edge)
                    self.put("Facades", piece, px, y + drop, pz, yaw, b.side, tone)
                    if st == 0 and not outer and piece == "F_Ground8" and cls in ("street", "alley") and h01(b.name, px, pz, "lamp") < 0.5:
                        self.put("Dressing", "WallLantern", px, 8.6 + drop, pz, yaw, b.side)
                # Eave trim.
                top = 4 * L.STOREY if b.klass == "perim" else b.eave
                if outer or self.open_air(ox, top - 1, oz):
                    if b.klass == "perim":
                        self.put("Facades", f"Attic{w}", px, top + drop, pz, yaw, b.side, tone)
                    elif b.roof[0] == "flat":
                        self.put("Facades", f"Parapet{w}", px, b.eave + drop, pz, yaw, b.side, tone)
                    else:
                        self.put("Facades", f"Cornice{w}", px, b.eave + drop, pz, yaw, b.side, tone)
                # A shed roof's high side over the outer wall: a band of wall up to the roof edge.
                if outer and b.roof[0] == "shed" and w in (8, 4):
                    high = {"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}[b.roof[1]]
                    if high == n:
                        self.put("Facades", f"OuterBand{w}", px, b.eave + drop, pz, yaw, b.side, tone)
        self.quoins(b, storeys)

    def module(self, b, st, w, kind, door_storeys, cls, idx, nfull, edge):
        # A regular rhythm per face: openings stack storey over storey, alternate along the face, and the same
        # building always gets the same pattern.
        if kind == "door" and st in door_storeys:
            return "F_GroundDoor" if st == 0 else "F_UpperDoor"
        if w < 8:
            return f"F_Ground{w}" if st == 0 else f"F_Upper{w}"
        middle = nfull >= 3 and nfull % 2 == 1 and idx == nfull // 2
        if st == 0:
            if kind == "door":
                return "F_GroundClosed"
            if cls == "cloister":
                return "F_GroundWindow"
            if middle:
                return "F_GroundClosed"
            if cls == "plaza":
                return "F_GroundShop" if idx % 2 == 0 and not edge else "F_GroundWindow"
            if cls == "street":
                shops = h01(b.name, "shops") < 0.5
                return ("F_GroundShop" if shops and not edge else "F_GroundWindow") if idx % 2 == 0 else "F_GroundWindow"
            return "F_GroundWindow" if idx % 2 == 0 else "F_Ground8"
        if cls == "alley" and b.klass != "perim" and idx % 2 == 1:
            return "F_Upper8"
        balcony = st == 1 and not edge and (idx % 2 == 0 if b.klass != "perim" else idx % 3 == 1)
        if balcony and cls in ("plaza", "street", "alley"):
            return "F_UpperBalcony"
        return "F_UpperWindow"

    def quoins(self, b, storeys):
        corners = [
            ((b.x0, b.z0), (-1, 0), (0, -1), 180.0),
            ((b.x1, b.z0), (1, 0), (0, -1), 90.0),
            ((b.x1, b.z1), (1, 0), (0, 1), 0.0),
            ((b.x0, b.z1), (-1, 0), (0, 1), 270.0),
        ]
        for (cx, cz), n1, n2, yaw in corners:
            for s in range(storeys):
                y = s * L.STOREY + 6
                # Both faces exposed next to the corner, and the diagonal open (a real outside corner).
                p1 = (cx + n1[0] * 1.0 - n2[0] * 1.5, cz + n1[1] * 1.0 - n2[1] * 1.5)
                p2 = (cx + n2[0] * 1.0 - n1[0] * 1.5, cz + n2[1] * 1.0 - n1[1] * 1.5)
                pd = (cx + (n1[0] + n2[0]) * 1.0, cz + (n1[1] + n2[1]) * 1.0)
                arch = s < 2 and any(
                    s2.kind == "lintel" and abs(s2.cx - cx) < s2.sx / 2 + 1.5 and abs(s2.cz - cz) < s2.sz / 2 + 1.5 for s2 in self.solids
                )
                if not arch and all(self.open_air(px, y, pz) for px, pz in (p1, p2, pd)):
                    self.put("Facades", "Quoin12", cx, s * L.STOREY, cz, yaw, b.side, b.tone)

    # ---------------------------------------------------------- roofs
    def roofs(self, b):
        kind = b.roof[0]
        if kind == "hero":
            return
        e = b.eave
        if kind == "flat":
            # Inset from the walls and below every coping: no face of it shares a plane with a facade piece.
            self.part("Roofs", f"{b.name}_Top", b.x0 + 0.1, b.x1 - 0.1, e - 0.35, e - 0.15, b.z0 + 0.1, b.z1 - 0.1, ROOFTOP, "Limestone")
            return
        if kind == "gable":
            if b.roof[1] == "x":
                run = (b.z1 - b.z0) / 2
                eaves = [((0, -1), b.z0, "x", b.x0, b.x1), ((0, 1), b.z1, "x", b.x0, b.x1)]
                ends = [((-1, 0), b.x0, (b.z0 + b.z1) / 2), ((1, 0), b.x1, (b.z0 + b.z1) / 2)]
                depth = b.z1 - b.z0
            else:
                run = (b.x1 - b.x0) / 2
                eaves = [((-1, 0), b.x0, "z", b.z0, b.z1), ((1, 0), b.x1, "z", b.z0, b.z1)]
                ends = [((0, -1), b.z0, (b.x0 + b.x1) / 2), ((0, 1), b.z1, (b.x0 + b.x1) / 2)]
                depth = b.x1 - b.x0
            for n, plane, axis, a, c in eaves:
                self.slope_row(b, n, plane, axis, a, c, run, e)
            # One ridge cap on the line where the two slopes meet.
            ridge_y = e + run * L.PITCH + 0.45 - 0.1
            if b.roof[1] == "x":
                zm = (b.z0 + b.z1) / 2
                for t, w, _, _ in self.segments(b.x0, b.x1, []):
                    if w in (8, 4):
                        self.put("Roofs", f"RidgeCap{w}", t, ridge_y, zm, 90, b.side)
            else:
                xm = (b.x0 + b.x1) / 2
                for t, w, _, _ in self.segments(b.z0, b.z1, []):
                    if w in (8, 4):
                        self.put("Roofs", f"RidgeCap{w}", xm, ridge_y - X_DROP, t, 0, b.side)
            for n, plane, t in ends:
                if depth not in (24, 32):
                    continue
                px, pz = (plane, t) if n[1] == 0 else (t, plane)
                ox, oz = px + n[0] * 1.0, pz + n[1] * 1.0
                if self.open_air(ox, e + 2, oz):
                    self.put("Roofs", f"Gable{int(depth)}", px, e, pz, FACE[n], b.side, b.tone)
        elif kind == "shed":
            up = b.roof[1]
            n = {"+x": (-1, 0), "-x": (1, 0), "+z": (0, -1), "-z": (0, 1)}[up]
            if n[1] == 0:
                plane, axis, a, c = (b.x0 if n[0] < 0 else b.x1), "z", b.z0, b.z1
                run = b.x1 - b.x0
            else:
                plane, axis, a, c = (b.z0 if n[1] < 0 else b.z1), "x", b.x0, b.x1
                run = b.z1 - b.z0
            self.slope_row(b, n, plane, axis, a, c, run, e)

    def slope_row(self, b, n, plane, axis, a, c, run, e):
        run = int(round(run))
        assert run in (12, 16), f"{b.name}: no roof module for a {run} run"
        for t, w, _, _ in self.segments(a, c, []):
            if w == 2:
                continue
            px, pz = self.point(n, plane, axis, t)
            ox, oz = self.point(n, plane, axis, t, 1.0)
            if any(o is not b and o.x0 < ox < o.x1 and o.z0 < oz < o.z1 and o.eave >= e - 0.5 for o in self.buildings):
                continue  # the eave runs against a house as tall: its own roof covers the joint
            drop = -X_DROP if n[1] == 0 else 0.0
            self.put("Roofs", f"Roof{run}_{w}", px, e + drop, pz, FACE[n], b.side)

    # ---------------------------------------------------------- arcades, arches, stair, heroes, props
    def structures(self):
        for s in self.solids:
            base = s.name.rstrip("'").replace("_B", "_A")
            if s.name.startswith("Spandrel") or s.name.startswith("BalustradeE") or s.name.startswith("ArcadeRoof"):
                sign = 1 if s.cx > 0 else -1
                face_x = s.cx - sign * s.sx / 2 if s.shape != "wedge" else (s.cx - sign * 5.0)
                if s.shape == "wedge":
                    face_x = sign * 34.0
                yaw = 180.0 if sign > 0 else 0.0
                z0 = s.cz - (s.sz if s.shape != "wedge" else s.sx) / 2
                length = s.sz if s.shape != "wedge" else s.sx
                piece = "ArcadeBay" if s.name.startswith("Spandrel") else "Balustrade8" if s.name.startswith("Balustrade") else "ArcadeRoof8"
                y = 0.0 if piece == "ArcadeBay" else L.UPPER
                for k in range(int(round(length / 8))):
                    self.put("Arcades", piece, face_x, y, z0 + 4 + 8 * k, yaw, s.side)
                if piece == "ArcadeBay":
                    for k in range(1, int(round(length / 8))):
                        self.put("Dressing", "Banner", face_x, 10.9, z0 + 8 * k, yaw, s.side)
            elif s.kind == "lintel":
                yaw = 90.0 if s.sx > s.sz else 0.0
                deep = min(s.sx, s.sz) > 3
                self.put("Arches", "Arch8D4" if deep else "Arch8", s.cx, s.y0, s.cz, yaw, s.side)
            elif s.kind == "stair":
                r = math.radians(s.yaw)
                ux, uz = math.sin(r), math.cos(r)
                self.put("Arcades", "Stair12", s.cx - ux * s.sz / 2, s.y0, s.cz - uz * s.sz / 2, s.yaw - 90.0, s.side)
            elif base in PROPS:
                piece, dyaw = PROPS[base]
                self.put("Props", piece, s.cx, 0.0, s.cz, s.yaw + dyaw, s.side)
        self.put("Heroes", "Fountain", 0, 0, 0, 0, "A")
        self.put("Paving", "PlazaRing", 0, 0.05, 0, 0, "A")
        tx0, tx1, tz0, tz1, _ = L.TOWER
        self.put("Heroes", "ClockTower", (tx0 + tx1) / 2, 0, (tz0 + tz1) / 2, 0, "A")
        for b in self.buildings:
            if b.roof[0] == "hero":
                yaw = 0.0 if (b.x0 + b.x1) / 2 >= 0 and b.roof[1] == "Pavilion" else 0.0
                cx, cz = (b.x0 + b.x1) / 2, (b.z0 + b.z1) / 2
                if b.roof[1] == "Pavilion":
                    yaw = 0.0 if cx > 0 else 180.0
                else:
                    yaw = 0.0 if cz < 0 else 180.0
                self.put("Heroes", b.roof[1], cx, 0, cz, yaw, b.side)

    def dressing(self):
        for half in (1, -1):
            side = "A" if half == 1 else "B"
            # Forecourt leading line toward the gate arch (x -5 on the Blue side), plaza border bands.
            for zc in (-84, -68, -52):
                self.put("Paving", "PavingBand16", -5 * half, 0.05, zc * half, 0, side)
            for zc in (-28, -12):
                self.put("Paving", "PavingBand16", 33 * half, 0.05, zc * half, 0, side)
                self.put("Paving", "PavingBand16", -33 * half, 0.05, zc * half, 0, side)
            for xc in (-24, -8, 8, 24):
                self.put("Paving", "PavingBand16", xc * half, 0.05, -35 * half, 90, side)
            # Laundry over the alleys.
            for x, z in ((74, -30), (74, -56), (-74, -40), (-74, -70)):
                self.put("Dressing", "LaundryLine", x * half, 17.0 + 2 * h01(x, z), z * half, 90, side)
            # Spawn banners on the cloister walls (the corner houses' inner faces), facing into the cloister.
            for z in (-128, -120):
                self.put("Dressing", "Banner", 20 * half, 22.0, z * half, 180 if half == 1 else 0, side)
                self.put("Dressing", "Banner", -20 * half, 22.0, z * half, 0 if half == 1 else 180, side)

    # ---------------------------------------------------------- interiors
    def interiors(self):
        for b in self.buildings:
            if not b.voids or b.roof[0] == "hero":
                continue
            rooms = [v for v in b.voids if (v[1] - v[0]) > 2.01 and (v[3] - v[2]) > 2.01 and abs(v[4] - L.SLAB) > 1e-6]
            for vi, v in enumerate(b.voids):
                x0, x1, z0, z1, y0, y1 = v
                door = (x1 - x0) <= 2.01 or (z1 - z0) <= 2.01
                if door and self.exterior_door(b, v):
                    continue  # the facade module frames it
                for axis, sign in (("x", -1), ("x", 1), ("z", -1), ("z", 1)):
                    self.line_face(b, vi, v, axis, sign)
                if door:
                    # The soffit fits between the jamb linings.
                    if (x1 - x0) <= 2.01:
                        self.part("Interiors", f"{b.name}_Soffit{vi}", x0, x1, y1 - 0.16, y1 - 0.06, z0 + 0.16, z1 - 0.16, INTERIOR, "Plaster")
                    else:
                        self.part("Interiors", f"{b.name}_Soffit{vi}", x0 + 0.16, x1 - 0.16, y1 - 0.16, y1 - 0.06, z0, z1, INTERIOR, "Plaster")
                if v in rooms:
                    fy = y0 + 0.01
                    self.part("Interiors", f"{b.name}_Floor{vi}", x0, x1, fy, fy + 0.1, z0, z1, FLOORING, "WoodPlanks")
                    if y0 == 0 and abs(y1 - L.SLAB) < 1e-6:
                        self.beams(b, v)

    def exterior_door(self, b, v):
        x0, x1, z0, z1, y0, y1 = v
        ym = (y0 + y1) / 2
        if (x1 - x0) <= 2.01:
            x = b.x0 - 1.0 if abs(x0 - b.x0) < 1e-6 else b.x1 + 1.0
            return self.open_air(x, ym, (z0 + z1) / 2)
        z = b.z0 - 1.0 if abs(z0 - b.z0) < 1e-6 else b.z1 + 1.0
        return self.open_air((x0 + x1) / 2, ym, z)

    def line_face(self, b, vi, v, axis, sign):
        x0, x1, z0, z1, y0, y1 = v
        plane = (x1 if sign > 0 else x0) if axis == "x" else (z1 if sign > 0 else z0)
        # Rectangle on the plane: (a0, a1) along the other horizontal axis, (y0, y1).
        a0, a1 = (z0, z1) if axis == "x" else (x0, x1)
        rects = [(a0, a1, y0, y1)]
        for wi, w in enumerate(b.voids):
            if wi == vi:
                continue
            wx0, wx1, wz0, wz1, wy0, wy1 = w
            lo, hi = (wx0, wx1) if axis == "x" else (wz0, wz1)
            if not (lo - 1e-6 <= plane <= hi + 1e-6):
                continue
            # The other void continues beyond this face: cut its projection out of the lining.
            if sign > 0 and hi <= plane + 1e-6:
                continue
            if sign < 0 and lo >= plane - 1e-6:
                continue
            ca0, ca1 = (wz0, wz1) if axis == "x" else (wx0, wx1)
            nxt = []
            for r in rects:
                nxt += cut2(r, (ca0, ca1, wy0, wy1))
            rects = nxt
        for k, (ra0, ra1, ry0, ry1) in enumerate(rects):
            if ra1 - ra0 < 0.05 or ry1 - ry0 < 1.5:
                continue  # a slab edge (the visible greybox shows it), not a wall
            am, ym = (ra0 + ra1) / 2, (ry0 + ry1) / 2
            beyond = (plane + sign * 0.5, am) if axis == "x" else (am, plane + sign * 0.5)
            if not self.solid_at(beyond[0], ym, beyond[1]):
                continue  # open to the outside (a doorway's mouth)
            t0, t1 = (plane - sign * 0.16, plane - sign * 0.06)
            t0, t1 = min(t0, t1), max(t0, t1)
            ry1 = ry1 - 0.02 if abs(ry1 - y1) < 1e-6 else ry1  # just under the ceiling, not in its plane
            if axis == "x":
                self.part("Interiors", f"{b.name}_Lining{vi}{axis}{sign}{k}", t0, t1, ry0, ry1, ra0, ra1, INTERIOR, "Plaster")
            else:
                # Linings on the S/N walls stop at the W/E linings (they butt, never overlap).
                a0 = ra0 + 0.16 if abs(ra0 - x0) < 1e-6 else ra0
                a1 = ra1 - 0.16 if abs(ra1 - x1) < 1e-6 else ra1
                self.part("Interiors", f"{b.name}_Lining{vi}{axis}{sign}{k}", a0, a1, ry0, ry1, t0, t1, INTERIOR, "Plaster")

    def beams(self, b, v):
        x0, x1, z0, z1, y0, y1 = v
        wx, wz = x1 - x0, z1 - z0
        above = [w for w in b.voids if w[4] >= y1 - 1e-6]
        if abs(wx - 20) < 0.01:
            for zc in frange(z0 + 3, z1 - 2, 4):
                if any(w[0] < x1 and w[1] > x0 and w[2] < zc + 0.5 and w[3] > zc - 0.5 for w in above):
                    continue
                self.put("Interiors", "CeilingBeam", (x0 + x1) / 2, y1 - 0.03, zc, 90, b.side)
        elif abs(wz - 20) < 0.01:
            for xc in frange(x0 + 3, x1 - 2, 4):
                if any(w[2] < z1 and w[3] > z0 and w[0] < xc + 0.5 and w[1] > xc - 0.5 for w in above):
                    continue
                self.put("Interiors", "CeilingBeam", xc, y1 - 0.03, (z0 + z1) / 2, 0, b.side)

    def build(self):
        for b in self.buildings:
            self.facade(b)
            self.roofs(b)
        self.structures()
        self.dressing()
        self.interiors()
        return self


def frange(a, b, step):
    out = []
    v = a
    while v <= b + 1e-6:
        out.append(v)
        v += step
    return out


def cut2(r, h):
    # 2D rectangle minus rectangle -> list (a0, a1, y0, y1).
    a0, a1, y0, y1 = r
    h0, h1, hy0, hy1 = h
    if h0 >= a1 or h1 <= a0 or hy0 >= y1 or hy1 <= y0:
        return [r]
    out = []
    if a0 < h0:
        out.append((a0, h0, y0, y1))
        a0 = h0
    if a1 > h1:
        out.append((h1, a1, y0, y1))
        a1 = h1
    if y0 < hy0:
        out.append((a0, a1, y0, hy0))
    if y1 > hy1:
        out.append((a0, a1, hy1, y1))
    return out


def num(v):
    v = round(float(v), 3)
    return str(int(v)) if v == int(v) else repr(v)


def art_luau() -> str:
    art = Art().build()
    rows = []
    for sec, piece, x, y, z, yaw, side, tone in art.place:
        t = f'"{tone}"' if tone else "nil"
        rows.append(f'\t{{ "{sec}", "{piece}", {num(x)}, {num(y)}, {num(z)}, {num(yaw)}, "{side}", {t} }},')
    parts = []
    for sec, name, x0, x1, y0, y1, z0, z1, color, material in art.parts:
        parts.append(
            f'\t{{ "{sec}", "{name}", {num(x0)}, {num(x1)}, {num(y0)}, {num(y1)}, {num(z0)}, {num(z1)}, "{color}", "{material}" }},'
        )
    counts = {}
    for p in art.place:
        counts[p[1]] = counts.get(p[1], 0) + 1
    summary = ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    return ART_TEMPLATE % {
        "rows": "\n".join(rows),
        "parts": "\n".join(parts),
        "n": len(rows),
        "np": len(parts),
        "summary": summary,
        "tones": ", ".join(f'{k} = hex("{v}")' for k, v in TONES.items()),
        "accent_a": L.ACCENT["A"],
        "accent_b": L.ACCENT["B"],
    }


ART_TEMPLATE = """--!strict
-- Old Town art pass (vault/01 Design/Maps/Old Town.md). GENERATED by
-- tools/maps/oldtown_layout.py --write (placement rules: tools/maps/oldtown_art.py), so it
-- always matches the greybox. Needs the kit installed first (ServerStorage.MapKit.OldTown):
--   python tools/studio/maps/kit_bundle.py OldTown Structure -o kit1.luau   (run in the match place)
--   python tools/studio/maps/kit_bundle.py OldTown Props -o kit2.luau
-- then bundle and run:  python tools/studio/maps/bundle.py OldTown Greybox Art Lighting -o oldtown.luau
--
-- It rebuilds Workspace.OldTown.Art (%(n)s kit pieces, %(np)s plain parts for roof tops and
-- interiors), tints each house's stucco to its tone and the side accent (blue) to green on
-- the Green half, and hides the greybox parts the meshes replace (Transparency 1; they stay
-- the collision). Interior greybox (ceilings, stairwell, landing) stays visible as plaster.
-- Pieces: %(summary)s.

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

-- section, piece, x, y, z (map space), yaw, side, tone
local PLACE: { { any } } = {
%(rows)s
}

-- section, name, x0, x1, y0, y1, z0, z1, colour, material (decor: no collision)
local PARTS: { { any } } = {
%(parts)s
}

local STUCCO = hex("#E9DCC0")
local ACCENT_A = hex("%(accent_a)s")
local ACCENT_B = hex("%(accent_b)s")
local TONE: { [string]: Color3 } = { %(tones)s }
local INTERIOR = hex("#EFE4CC")
local SLAB = hex("#D9CBAE")

local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.006 and math.abs(a.G - b.G) < 0.006 and math.abs(a.B - b.B) < 0.006
end

local function tint(m: Instance, side: string, tone: string?)
	local toneColor = if tone then TONE[tone] else nil
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if toneColor and near(d.Color, STUCCO) then
				d.Color = toneColor
			elseif side == "B" and near(d.Color, ACCENT_A) then
				d.Color = ACCENT_B
			end
		end
	end
end

-- Greybox: hide what the meshes replace, keep interiors and slabs as plaster.
local REPLACED: { [string]: boolean } = {
	arcade = true,
	rail = true,
	roof = true,
	stair = true,
	lintel = true,
	cover = true,
	low = true,
}
local grey = root():FindFirstChild("Greybox")
local hidden, kept = 0, 0
if grey then
	for _, p in grey:GetDescendants() do
		if not p:IsA("BasePart") then
			continue
		end
		local kind = p:GetAttribute("Kind")
		local sectionName = p.Parent and p.Parent.Name or ""
		if p:GetAttribute("Shell") or REPLACED[kind :: string] or sectionName == "Fountain" then
			hide(p)
			hidden += 1
		elseif kind == "bldg" or kind == "perim" then
			p.Color = INTERIOR
			p.Material = Enum.Material.Plaster
			p.CastShadow = false
			kept += 1
		elseif kind == "floor" then
			p.Color = SLAB
			p.Material = Enum.Material.Limestone
			kept += 1
		end
	end
end

local sections: { [string]: Folder } = {}
local function sec(name: string): Folder
	local f = sections[name]
	if f then
		return f
	end
	local made = section("Art", name)
	sections[name] = made
	return made
end

local placed = 0
for _, r in PLACE do
	local m = put(
		sec(r[1] :: string),
		r[2] :: string,
		at(r[3] :: number, r[4] :: number, r[5] :: number, r[6] :: number)
	)
	if m then
		tint(m, r[7] :: string, r[8] :: string?)
		placed += 1
	end
end

for _, r in PARTS do
	local x0, x1, y0, y1 = r[3] :: number, r[4] :: number, r[5] :: number, r[6] :: number
	local z0, z1 = r[7] :: number, r[8] :: number
	local p = box(
		sec(r[1] :: string),
		r[2] :: string,
		Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		hex(r[9] :: string),
		{ material = (Enum.Material :: any)[r[10] :: string], castShadow = false }
	)
	decor(p)
end

report(
	string.format(
		"OldTown art: %%d / %%d pieces placed, %%d parts, greybox %%d hidden, %%d kept; %%s",
		placed,
		#PLACE,
		#PARTS,
		hidden,
		kept,
		missingReport()
	)
)
"""


if __name__ == "__main__":
    art = Art().build()
    counts = {}
    for p in art.place:
        counts[p[1]] = counts.get(p[1], 0) + 1
    print(f"{len(art.place)} placements, {len(art.parts)} parts")
    for k, v in sorted(counts.items()):
        print(f"  {k:16s} {v}")
