"""Roblox export, flat-material style (round two, 2026-11-14).

The owner found the baked 1024 atlas soft and seamy in Studio ("hand drawn",
"lines don't line up"). The game's own guns are one MeshPart per material
with a flat Color + Roblox Material and no texture, which reads crisp; this
exports skins the same way:

  one MeshPart per (bone, material): SK_<Bone>_<NN> (objects named *Sight*
  get their own parts, SK_<Bone>_Sight_<NN>, so ADS keeps them), flat shaded, with the
  planar side UVs (u = x, v = z, studs) kept for tiled patterns.
  manifest part spec: bone, center, size, color (hex), material (Roblox enum
  name: Neon / Metal / SmoothPlastic), reflectance, pattern (tile name or
  None), triangles.

Exec inside the Blender MCP session after an item's builder (needs `col`,
`ITEM`, `LINE`, `OUT`, `sc`). export_flat() returns (fbx_path, report).
"""
import os, math, bmesh, bpy

FLIPPED = {}

PATTERNS = {                       # material name -> tile (tools/textures/make_skin_tiles.py)
    "GF1 Lacquer Pattern": "Giltfold_Wave",
    "PL2 Carbon Twill": "Payload_Carbon",
    "PL1 Thermal Foil": "Payload_Foil",
    "SW1 Vermilion Seal": "Sealwork_Ruby",
    "MF4 Violet Chamber": "Moltframe_Flow",
    "RF_ObsidianForged": "Riftforge_Forged",
    "RF_GripCarbon": "Payload_Carbon",
    "RF_PlasmaCore": "Riftforge_Plasma",
}

def _hex(rgb):
    def s(c):
        c = max(0.0, min(1.0, c))
        return c * 12.92 if c <= .0031308 else 1.055 * c ** (1 / 2.4) - .055
    return "%02X%02X%02X" % tuple(int(round(s(c) * 255)) for c in rgb[:3])

def _mat_spec(m):
    """Flat Roblox spec from a Blender material: colour from its hex tag, the
    Principled base colour, or the mean of its colour ramp."""
    if m is None:
        return {"color": "808080", "material": "SmoothPlastic", "reflectance": 0.0, "pattern": None}
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF") if nt else None
    color = m.get("mf_hex")
    rough, metal, emis = .5, 0.0, 0.0
    if b:
        bc = b.inputs["Base Color"]
        if not color:
            if bc.is_linked:
                src = bc.links[0].from_node
                if src.type == "VALTORGB":
                    els = src.color_ramp.elements
                    avg = [sum(e.color[i] for e in els) / len(els) for i in range(3)]
                    color = _hex(avg)
                elif src.type == "MIX":
                    color = _hex(src.inputs["A"].default_value)
            if not color:
                color = _hex(bc.default_value)
        rough = b.inputs["Roughness"].default_value if not b.inputs["Roughness"].is_linked else .3
        metal = b.inputs["Metallic"].default_value if not b.inputs["Metallic"].is_linked else .5
        emis = b.inputs["Emission Strength"].default_value if b.inputs["Emission Color"].default_value[:3] != (0, 0, 0) else 0.0
    if emis > .5:
        mat = "Neon"
    elif metal >= .55:
        mat = "Metal"
    else:
        mat = "SmoothPlastic"
    refl = 0.0 if mat != "SmoothPlastic" else (.12 if rough < .2 else (.05 if rough < .3 else 0.0))
    return {"color": color or "808080", "material": mat, "reflectance": refl, "pattern": PATTERNS.get(m.name)}

def fix_outward(obj):
    """Make every closed island of obj face outward (Roblox culls back faces;
    solids built open then mirrored shut could end up inside-out, which read
    as see-through magazines in Studio). Open islands (kept stock pieces) and
    the deliberately inverted ink-outline hulls are left alone. Returns the
    number of islands flipped."""
    if obj.name.endswith("_Ink") or any(m and m.name == "IK2 Ink Outline" for m in obj.data.materials):
        return 0
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    seen, flipped = set(), 0
    for f0 in bm.faces:
        if f0.index in seen:
            continue
        isl, stack = [], [f0]
        seen.add(f0.index)
        while stack:
            f = stack.pop(); isl.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index); stack.append(g)
        closed = all(len(e.link_faces) == 2 for f in isl for e in f.edges)
        if not closed:
            continue
        vol = sum(f.calc_center_median().dot(f.normal) * f.calc_area() for f in isl)
        if vol < 0:
            bmesh.ops.reverse_faces(bm, faces=isl)
            flipped += 1
    if flipped:
        bm.to_mesh(obj.data); obj.data.update()
    bm.free()
    return flipped

CROSSED_FIXED = {}
CROSSED_LEFT = {}

def _seg_cross(a, b, c, d):
    def o(p, q, r):
        v = (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
        return 0 if abs(v) < 1e-12 else (1 if v > 0 else -1)
    return o(a, b, c) * o(a, b, d) < 0 and o(c, d, a) * o(c, d, b) < 0

def _crosses(P):
    k = len(P)
    for i in range(k):
        for j in range(i + 2, k):
            if i == 0 and j == k - 1:
                continue
            if _seg_cross(P[i], P[(i + 1) % k], P[j], P[(j + 1) % k]):
                return True
    return False

def _first_cross(P):
    k = len(P)
    for i in range(k):
        for j in range(i + 2, k):
            if i == 0 and j == k - 1:
                continue
            if _seg_cross(P[i], P[(i + 1) % k], P[j], P[(j + 1) % k]):
                return i, j
    return None

def _split_lobes(poly, depth=0):
    """poly: [(co3, (x, y))]. Splits a self-crossing outline at its crossings
    into simple loops."""
    from mathutils.geometry import intersect_line_line_2d
    from mathutils import Vector
    c = _first_cross([p[1] for p in poly])
    if c is None or depth > 12:
        return [poly]
    i, j = c
    k = len(poly)
    a0, a1 = poly[i], poly[(i + 1) % k]
    b0, b1 = poly[j], poly[(j + 1) % k]
    X2 = intersect_line_line_2d(Vector(a0[1]), Vector(a1[1]), Vector(b0[1]), Vector(b1[1]))
    if X2 is None:
        return [poly]
    L = (Vector(a1[1]) - Vector(a0[1])).length
    t = 0.0 if L < 1e-12 else (X2 - Vector(a0[1])).length / L
    X = (a0[0].lerp(a1[0], t), (X2.x, X2.y))
    A = [X] + poly[i + 1:j + 1]
    B = [X] + poly[j + 1:] + poly[:i + 1]
    out = []
    for lobe in (A, B):
        if len(lobe) >= 3:
            out += _split_lobes(lobe, depth + 1)
    return out

def fix_crossed_faces(obj):
    """Faces whose outline crosses itself (a bow tie) triangulate into lobes
    facing opposite ways; Roblox culls the inward ones: a see-through hole
    plus a black flipped triangle (owner 2026-11-14: the Payload Bulldog,
    Ares and Odin and the Inkshift Odin and Phantom grips). The cause is a
    stray corner left by the chamfer-and-fold step at a sharp outline corner
    (solid_plate). Each such face is split at its crossings into simple
    loops, every loop turned to face outward (inward for ink hulls), and the
    loops replace the face: the whole intended area stays filled (loops
    reaching past the true outline lie inside the next part). Returns
    (faces fixed, faces left)."""
    from mathutils import Vector
    ink = obj.name.endswith("_Ink") or any(m and "Ink Outline" in m.name for m in obj.data.materials)
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bm.normal_update()
    if not bm.verts:
        bm.free(); return 0, 0
    lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
    hi = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
    centre = (lo + hi) / 2
    fixed = left = 0
    for f in list(bm.faces):
        n = len(f.verts)
        if n < 4:
            continue
        nrm = f.normal.copy()
        if nrm.length < 1e-9:
            continue
        a = Vector((1, 0, 0)) if abs(nrm.x) < .9 else Vector((0, 1, 0))
        u = (a - nrm * a.dot(nrm)).normalized(); v = nrm.cross(u)
        poly = [(vv.co.copy(), (vv.co.dot(u), vv.co.dot(v))) for vv in f.verts]
        if _first_cross([p[1] for p in poly]) is None:
            continue
        lobes = _split_lobes(poly)
        if any(_first_cross([p[1] for p in lb]) is not None for lb in lobes):
            left += 1
            continue
        mat, smooth = f.material_index, f.smooth
        made = []
        cache = {}
        for lb in lobes:
            area = sum(lb[q][1][0] * lb[(q + 1) % len(lb)][1][1] - lb[(q + 1) % len(lb)][1][0] * lb[q][1][1]
                       for q in range(len(lb))) / 2
            if abs(area) < 1e-9:
                continue
            cen = sum((p[0] for p in lb), Vector()) / len(lb)
            d = (cen - centre).dot(nrm)
            want = (1 if d >= 0 else -1) if abs(d) > 1e-5 else 1
            if ink:
                want = -want
            if (1 if area > 0 else -1) != want:
                lb = lb[::-1]
            vs = []
            for co, _ in lb:
                key = (round(co.x, 7), round(co.y, 7), round(co.z, 7))
                if key not in cache:
                    hit = next((vv for vv in f.verts if (vv.co - co).length < 1e-7), None)
                    cache[key] = hit or bm.verts.new(co)
                if not vs or vs[-1] is not cache[key]:
                    vs.append(cache[key])
            if len(vs) >= 3 and len(set(vs)) == len(vs):
                try:
                    nf = bm.faces.new(vs)
                    nf.material_index = mat; nf.smooth = smooth
                    made.append(nf)
                except ValueError:
                    pass
        if made:
            bmesh.ops.delete(bm, geom=[f], context="FACES_ONLY")
            fixed += 1
        else:
            left += 1
    if fixed:
        bm.to_mesh(obj.data); obj.data.update()
    bm.free()
    return fixed, left

def _islands(bm):
    bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f0 in bm.faces:
        if f0.index in seen:
            continue
        isl, stack = [], [f0]
        seen.add(f0.index)
        while stack:
            f = stack.pop(); isl.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index); stack.append(g)
        out.append(isl)
    return out


def orient_open_islands(objs, dry=False):
    """Open plates (solid_plate(open_inner=True) shells, trimmed stock) have
    no inside to measure, so fix_outward() leaves them; built mirrored they
    can face into the gun, which Roblox culls (the Giltfold Stinger's receiver
    panels vanished at three-quarter views). Vote per island: each face casts
    a short ray along its normal and against it through the whole item; the
    side that reaches open air is outside. Islands whose area mostly faces
    inward are flipped. Returns {object: islands flipped}."""
    from mathutils.bvhtree import BVHTree
    meshes = [o for o in objs if o.type == "MESH" and o.data.polygons and not o.name.endswith("_Ink")
              and not any(m and m.name == "IK2 Ink Outline" for m in o.data.materials)]
    V, P = [], []
    for o in meshes:
        base = len(V)
        V += [o.matrix_world @ v.co for v in o.data.vertices]
        P += [[base + i for i in p.vertices] for p in o.data.polygons]
    tree = BVHTree.FromPolygons(V, P, epsilon=0.0)
    flipped = {}
    for o in meshes:
        M = o.matrix_world; R = M.to_3x3(); sgn = 1 if R.determinant() >= 0 else -1
        bm = bmesh.new(); bm.from_mesh(o.data)
        todo = []
        for isl in _islands(bm):
            if all(len(e.link_faces) == 2 for f in isl for e in f.edges):
                continue                                   # closed: fix_outward's job
            score = 0.0
            for f in isl:
                a = f.calc_area()
                if a < 1e-7:
                    continue
                c = M @ f.calc_center_median()
                n = (R @ f.normal) * sgn
                if n.length < 1e-9:
                    continue
                n.normalize()
                out_open = tree.ray_cast(c + n * 2e-3, n, 1.5)[0] is None
                in_open = tree.ray_cast(c - n * 2e-3, -n, 1.5)[0] is None
                score += a * ((1 if out_open else 0) - (1 if in_open else 0))
            if score < 0:
                todo.append(isl)
        if todo:
            flipped[o.name] = len(todo)
            if not dry:
                for isl in todo:
                    bmesh.ops.reverse_faces(bm, faces=isl)
                bm.to_mesh(o.data); o.data.update()
        bm.free()
    return flipped


OPEN_FLIPPED = {}

# ------------------------------------------------------------------ coplanar
# Two faces on the same plane, facing the same way and overlapping, z-fight in
# Studio (a dotted or flickering seam: owner 2026-11-14 on the Payload
# Bulldog's bolt slot and pinstripe and the Inkshift Odin's stripe). Skin
# builders lay plates exactly on surfaces (lift 0) or two layers at the same
# lift, and retained stock hardware has flush faces of two materials. Before
# export, one side of every visible pair is lifted COPLANAR_LIFT along its
# normal: an accent (glow, foil, stripe, ink line) over a body colour, a skin
# plate over retained stock hardware (Gun_Part names), else the smaller side.
# 0.004 studs: invisible on a gun, and clear of depth-buffer fighting out to
# about 70 studs (LihFolk Parts Unions and MeshParts: Roblox suggests 0.01
# for world parts; 0.0015 was only safe at viewmodel distance).
COPLANAR_LIFT = 0.004
COPLANAR_TOL_D, COPLANAR_TOL_N = 0.0007, 0.9995
ACCENT_WORDS = ("violet", "chamber", "cyan", "vermilion", "foil", "gold", "glow", "tube", "highlight",
                "ink line", "neon", "indicator", "recess", "mission blue")
COPLANAR_LIFTED = []

def _is_stock_name(name):
    import re
    return re.match(r"^[A-Z][a-z]+_", name) is not None and re.match(r"^[A-Z]{2,4}_", name) is None

def _is_accent(mname):
    m = (mname or "").lower()
    return any(w in m for w in ACCENT_WORDS)

def resolve_coplanar(objs, dry=False):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    COPLANAR_LIFTED.clear()
    objs = [o for o in objs if o.type == "MESH" and o.data.polygons]
    big = bmesh.new()
    for o in objs:
        t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world)
        tmp = bpy.data.meshes.new("_cop_tmp"); t.to_mesh(tmp); t.free()
        big.from_mesh(tmp); bpy.data.meshes.remove(tmp)
    big.normal_update(); big.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(big)
    def visible(c, n):
        h = tree.ray_cast(c + n * 1e-4, n, 0.6)
        return h[0] is None or big.faces[h[2]].normal.dot(n) < 0 or h[3] > 0.004
    def basis(n):
        a = Vector((1, 0, 0)) if abs(n.x) < .9 else Vector((0, 1, 0))
        u = n.cross(a).normalized(); return u, n.cross(u)
    def inside(pt, poly):
        x, y = pt; c = False
        for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
            if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-12) + x1:
                c = not c
        return c
    def samples(poly):
        cx = sum(x for x, _ in poly) / len(poly); cy = sum(y for _, y in poly) / len(poly)
        return [(cx, cy)] + [((x + cx) / 2, (y + cy) / 2) for x, y in poly]
    faces = []
    for o in objs:
        M = o.matrix_world; N = M.to_3x3().inverted().transposed(); mats = o.data.materials
        for p in o.data.polygons:
            n = N @ p.normal
            if n.length < 1e-9:
                continue
            n.normalize()
            pts = [M @ o.data.vertices[i].co for i in p.vertices]
            area = p.area * abs(M.to_3x3().determinant()) ** (2 / 3)
            if area < 2e-6:
                continue
            mname = mats[p.material_index].name if p.material_index < len(mats) and mats[p.material_index] else "_"
            faces.append({"o": o, "pi": p.index, "m": mname, "n": n, "d": n.dot(pts[0]), "pts": pts, "area": area,
                          "c": sum(pts, Vector()) / len(pts)})
    buckets = {}
    for f in faces:
        n = f["n"]; buckets.setdefault((round(n.x * 20), round(n.y * 20), round(n.z * 20)), []).append(f)
    pairs = {}
    for fs in buckets.values():
        fs.sort(key=lambda f: f["d"])
        for i, a in enumerate(fs):
            for b in fs[i + 1:]:
                if b["d"] - a["d"] > COPLANAR_TOL_D:
                    break
                if a["m"] == b["m"] or a["n"].dot(b["n"]) < COPLANAR_TOL_N:
                    continue
                u, v = basis(a["n"])
                pa = [(q.dot(u), q.dot(v)) for q in a["pts"]]; pb = [(q.dot(u), q.dot(v)) for q in b["pts"]]
                if max(x for x, _ in pa) < min(x for x, _ in pb) or max(x for x, _ in pb) < min(x for x, _ in pa):
                    continue
                if max(y for _, y in pa) < min(y for _, y in pb) or max(y for _, y in pb) < min(y for _, y in pa):
                    continue
                if sum(inside(q, pb) for q in samples(pa)) + sum(inside(q, pa) for q in samples(pb)) < 2:
                    continue
                if not (visible(a["c"], a["n"]) or visible(b["c"], b["n"])):
                    continue
                ka, kb = (a["o"].name, a["m"]), (b["o"].name, b["m"])
                e = pairs.setdefault(tuple(sorted([ka, kb])), {ka: {}, kb: {}})
                e[ka][a["pi"]] = a; e[kb][b["pi"]] = b
    for key, sides in pairs.items():
        (sa, fa), (sb, fb) = sides.items()
        def rank(side, fl):
            return (0 if _is_accent(side[1]) else 1, 1 if _is_stock_name(side[0]) else 0,
                    sum(f["area"] for f in fl.values()))
        side, fl = min(((sa, fa), (sb, fb)), key=lambda t: rank(*t))
        other = sb if side == sa else sa
        COPLANAR_LIFTED.append({"lift": f"{side[0]}|{side[1]}", "over": f"{other[0]}|{other[1]}", "faces": len(fl)})
        if dry:
            continue
        o = next(iter(fl.values()))["o"]
        M = o.matrix_world; Mi = M.inverted()
        offs = {}
        for f in fl.values():
            for vi in o.data.polygons[f["pi"]].vertices:
                offs[vi] = offs.get(vi, Vector()) + f["n"]
        for vi, nsum in offs.items():
            o.data.vertices[vi].co = Mi @ (M @ o.data.vertices[vi].co + nsum.normalized() * COPLANAR_LIFT)
        o.data.update()
    big.free()
    return list(COPLANAR_LIFTED)


def export_flat(objs, out_dir, item, line, prefix="SK"):
    FLIPPED.clear()
    CROSSED_FIXED.clear(); CROSSED_LEFT.clear()
    for o in objs:
        if o.type == "MESH" and o.data.polygons:
            fx, lf = fix_crossed_faces(o)
            if fx:
                CROSSED_FIXED[o.name] = fx
            if lf:
                CROSSED_LEFT[o.name] = lf
    for o in objs:
        if o.type == "MESH":
            n = fix_outward(o)
            if n:
                FLIPPED[o.name] = n
    OPEN_FLIPPED.clear()
    OPEN_FLIPPED.update(orient_open_islands(objs))
    resolve_coplanar(objs)
    groups = {}
    for o in objs:
        if o.type != "MESH" or not o.data.polygons:
            continue
        bone = o.parent_bone or "Root"
        # Sights stay their own parts, named "...Sight...": the viewmodel fades
        # whatever sits on the ADS sight line unless its name has "Sight" in it
        # (ViewmodelController findOccluders), so a sight merged into a
        # material group vanished on aim, with the rest of that group (owner
        # 2026-11-14: "sights disappear on ADS").
        sight = "sight" in o.name.lower()
        # Explicit groups let an individually animated mesh keep its stock weld
        # and palette without merging into the rest of that bone's material.
        flat_group = o.get("flat_group", "")
        for p in o.data.polygons:
            m = o.data.materials[p.material_index] if p.material_index < len(o.data.materials) else None
            key = (bone, m.name if m else "_none", sight, flat_group)
            groups.setdefault(key, []).append((o, p.index))
    made, report = [], {}
    counter = {}
    for (bone, mname, sight, flat_group), faces in sorted(groups.items()):
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        cache = {}
        for o, pi in faces:
            me = o.data; p = me.polygons[pi]; M = o.matrix_world
            vs = []
            for vi in p.vertices:
                k = (o.name, vi)
                if k not in cache:
                    cache[k] = bm.verts.new(M @ me.vertices[vi].co)
                vs.append(cache[k])
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            n = (M.to_3x3() @ p.normal).normalized()
            for loop in f.loops:
                co = loop.vert.co
                if abs(n.y) >= max(abs(n.x), abs(n.z)):
                    u, v = co.x, co.z
                elif abs(n.z) >= abs(n.x):
                    u, v = co.x, co.y
                else:
                    u, v = co.y, co.z
                loop[uvl].uv = (u * 4.0, v * 4.0)          # 0.25-stud tile period for patterns
        if not bm.faces:
            bm.free(); continue
        bmesh.ops.dissolve_degenerate(bm, edges=bm.edges[:], dist=1e-6)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_area() < 1e-9], context="FACES")
        if not bm.faces:
            bm.free(); continue
        if flat_group:
            name = f"{prefix}_{bone}_{'Sight_' if sight else ''}{flat_group}"
            assert name not in report, f"Multiple materials share flat group {name}"
        else:
            counter[bone] = counter.get(bone, 0) + 1
            name = f"{prefix}_{bone}_{'Sight_' if sight else ''}{counter[bone]:02d}"
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        for p in me.polygons:
            p.use_smooth = False
        o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
        made.append(o)
        P = [v.co for v in me.vertices]
        lo = [min(p[i] for p in P) for i in range(3)]; hi = [max(p[i] for p in P) for i in range(3)]
        spec = _mat_spec(bpy.data.materials.get(mname))
        spec.update({"bone": bone, "blender_material": mname, "triangles": len(me.polygons),
                     "size": [round(hi[i] - lo[i], 4) for i in range(3)],
                     "center": [round((hi[i] + lo[i]) / 2, 4) for i in range(3)]})
        report[name] = spec
        # re-centre on the bounding-box centre (the installer places parts by center)
        c = [(hi[i] + lo[i]) / 2 for i in range(3)]
        for v in me.vertices:
            v.co.x -= c[0]; v.co.y -= c[1]; v.co.z -= c[2]
        o.location = c
    fbx = os.path.join(out_dir, f"{item}_{line}_RobloxFlat.fbx")
    bpy.ops.object.select_all(action="DESELECT")
    for o in made:
        o.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    # explicit context: after open_mainfile in the same MCP call there is no window context
    win = bpy.context.window_manager.windows[0] if bpy.context.window_manager.windows else None
    with bpy.context.temp_override(window=win, selected_objects=made, active_object=made[0]):
        bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, apply_unit_scale=True, global_scale=1.0,
                                 axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", use_mesh_modifiers=False,
                                 object_types={"MESH"}, bake_space_transform=False)
    for o in made:
        bpy.data.objects.remove(o)
    return fbx, report
