"""Shared core for the 2026-11-15 ability rework (props + VFX meshes), run through the LIVE Blender MCP only.

Every MCP call starts with:

    exec(open(r"<repo>/tools/blender/rework/rw_core.py").read())
    S = rw_scene("RW_Molly")          # your own scene; never touch another fork's scene

Rules (several forks share one Blender instance):
  * One MCP call = one self-contained mutation. Never rely on selection, active object, mode or the
    window's scene surviving between calls: call rw_scene() first, pass objects by name.
  * Only create or edit datablocks whose names start with your prefix (e.g. "Molly_"). Shared materials
    come from rw_mat() and are never edited by a fork.
  * No bpy.ops.wm.open_mainfile / read_homefile / revert. Save with rw_save() only.
  * Blender units are studs. The pipeline's axes (export_mods.py, AbilityBuilder): +X FORWARD, +Y left,
    +Z up. Studio maps (x, y, z) -> (-y, z, -x), so Blender +X is the Roblox LookVector.
  * Origin: thrown = centre, handheld = grip, placed = floor centre. Objects are named "<Mod>_<Part>"
    in a collection named "<Mod>"; one material per object; EMPTY = locator (Attachment), MESH = part.
    Lights are separate "<Mod>_<Part>_Energy" objects. Parts that must keep their own colour when the
    game team-tints Neon end in "_Yellow" or "_Violet".
  * Style: gauntlet-build-style. Flat shading, no subdivision, no smooth cylinders or spheres,
    chamfered or carved ends, every joint seated or clearly stepped.
"""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

RW_REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
RW_WORK = os.path.join(RW_REPO, "art-source", "abilities", "Rework", "v03")

# --- palette -----------------------------------------------------------------------------------------
# role -> (hex, roughness, metallic, emission strength, Roblox material). Material names are
# "RW_<Role>" and carry rbx_material / rbx_color custom props, which export_mods.py copies into the
# build data. Forks pick roles, never invent hexes. The neutral roles are the guns' RemasterV2 roles
# (art-source/weapons/RemasterV2/_Library/v2kit.py ROLE_SPEC) so props and guns sit in one family.
RW_PALETTE = {
    "Body": ("#383D48", 0.78, 0.0, 0.0, "SmoothPlastic"),   # matte charcoal shell (largest area)
    "Panel": ("#555C69", 0.72, 0.0, 0.0, "SmoothPlastic"),  # lighter slate panel: the second value
    "Dark": ("#1C1E23", 0.85, 0.0, 0.0, "SmoothPlastic"),   # recesses, vents, seats, shadow gaps
    "Grip": ("#25272D", 0.90, 0.0, 0.0, "SmoothPlastic"),   # rubber / polymer contact points
    "Metal": ("#62676F", 0.45, 0.7, 0.0, "Metal"),          # machined: latches, levers, pins, fixings
    "Accent": ("#AEB4BC", 0.40, 0.7, 0.0, "Metal"),         # small bright metal: pull rings, edges
    "Pale": ("#C4C9CF", 0.72, 0.0, 0.0, "SmoothPlastic"),   # light casing (Frost)
    # one identity colour per prop, as matte paint (never glow)
    "Warm": ("#D56A2C", 0.70, 0.0, 0.0, "SmoothPlastic"),   # Molly heat panel
    "WarmDeep": ("#8A3B1E", 0.75, 0.0, 0.0, "SmoothPlastic"),
    "Cold": ("#8CCBEB", 0.62, 0.0, 0.0, "SmoothPlastic"),   # Frost vents / panels
    "ColdDeep": ("#3F7F9E", 0.70, 0.0, 0.0, "SmoothPlastic"),
    "Scan": ("#3FA9C4", 0.62, 0.0, 0.0, "SmoothPlastic"),   # Recon sensor paint
    "Hazard": ("#D9B13A", 0.70, 0.0, 0.0, "SmoothPlastic"), # Stim casing mark
    # lights. Energy = team-tinted by the game. Yellow / Violet keep their colour: name those parts
    # "..._Yellow" / "..._Violet" (ModProps skips them when tinting).
    "Energy": ("#00E5FF", 0.40, 0.0, 2.5, "Neon"),
    "Yellow": ("#FFD23F", 0.40, 0.0, 2.5, "Neon"),          # Stim coil
    "Violet": ("#9B6BFF", 0.40, 0.0, 2.5, "Neon"),          # Recall core
    # VFX kit meshes (review colours only: the game colours, sizes and fades them in code).
    "FxFireDeep": ("#C2331A", 0.60, 0.0, 1.2, "Neon"),      # flame base band
    "FxFire": ("#FF7A1F", 0.60, 0.0, 1.8, "Neon"),          # flame body
    "FxFireCore": ("#FFE08A", 0.60, 0.0, 2.4, "Neon"),      # pale core
    "FxIce": ("#CFEFFF", 0.35, 0.0, 0.4, "Ice"),            # plates, shards
    "FxIceLight": ("#7FD6FF", 0.40, 0.0, 2.0, "Neon"),      # cold interior light
    "FxHeal": ("#5CFFC8", 0.50, 0.0, 1.6, "Neon"),
    "FxTele": ("#9B6BFF", 0.50, 0.0, 1.8, "Neon"),
    "FxWind": ("#EAF4FF", 0.60, 0.0, 1.0, "Neon"),
    "FxStone": ("#6B6F76", 0.90, 0.0, 0.0, "Concrete"),     # floor fragments (take the floor's colour in game)
}


def _rw_hex(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def rw_mat(role):
    """Shared palette material. Created once, reused by every prop."""
    name = "RW_" + role
    m = bpy.data.materials.get(name)
    if m:
        return m
    hexc, rough, metal, emit, rbx = RW_PALETTE[role]
    m = bpy.data.materials.new(name)
    m["rbx_material"] = rbx
    m["rbx_color"] = hexc.lstrip("#")
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    col = _rw_hex(hexc)
    b.inputs["Base Color"].default_value = col
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = col
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = col
    m["rw_role"] = role
    m.use_fake_user = True
    return m


# --- scenes, collections, objects ----------------------------------------------------------------------
def rw_scene(name):
    """Get or create a fork's scene and make it the window scene for this call."""
    s = bpy.data.scenes.get(name) or bpy.data.scenes.new(name)
    s.unit_settings.system = "NONE"
    bpy.context.window.scene = s
    return s


def rw_col(scene, name):
    c = bpy.data.collections.get(name)
    if not c:
        c = bpy.data.collections.new(name)
    if c.name not in scene.collection.children:
        try:
            scene.collection.children.link(c)
        except RuntimeError:
            pass
    return c


def rw_clear(prefix):
    """Delete every object and mesh whose name starts with prefix (rebuild from scratch)."""
    for o in [o for o in bpy.data.objects if o.name.startswith(prefix)]:
        bpy.data.objects.remove(o, do_unlink=True)
    for me in [m for m in bpy.data.meshes if m.name.startswith(prefix) and m.users == 0]:
        bpy.data.meshes.remove(me)


def rw_obj(col, name, mesh, role=None, loc=(0, 0, 0), rot=(0, 0, 0), parent=None):
    """Wrap a mesh in an object. rot is XYZ euler in degrees. role = palette role for the whole part."""
    o = bpy.data.objects.new(name, mesh)
    col.objects.link(o)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    if parent:
        o.parent = parent
    if role and mesh is not None:
        mesh.materials.clear()
        mesh.materials.append(rw_mat(role))
    return o


def rw_empty(col, name, loc=(0, 0, 0), rot=(0, 0, 0), parent=None, size=0.05, kind="ARROWS"):
    """A locator: pivots, attachments, travel markers. Exported as an Attachment in Studio."""
    o = bpy.data.objects.new(name, None)
    o.empty_display_type = kind
    o.empty_display_size = size
    col.objects.link(o)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    if parent:
        o.parent = parent
    return o


# --- faceted mesh primitives (flat shaded, planar faces) ---------------------------------------------
def _rw_finish(bm, name, planar=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    if planar:  # merge coplanar triangles into planar n-gons so facets read as planes
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), verts=bm.verts, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.update()
    return me


def rw_ngon(r, n, rot_deg=None, sx=1.0, sy=1.0):
    """n-sided ring of (x, y). Default rotation puts a flat facet facing +X (forward)."""
    a0 = math.radians(rot_deg) if rot_deg is not None else math.pi / n
    return [(r * sx * math.cos(a0 + 2 * math.pi * i / n), r * sy * math.sin(a0 + 2 * math.pi * i / n)) for i in range(n)]


def rw_cham_rect(w, d, c):
    """Rectangle w (X) by d (Y) with four flat corner chamfers of size c: an 8-point ring."""
    x, y = w / 2, d / 2
    return [(x - c, -y), (x, -y + c), (x, y - c), (x - c, y), (-x + c, y), (-x, y - c), (-x, -y + c), (-x + c, -y)]


def rw_loft(name, rings, cap=True):
    """Closed faceted solid from stacked rings: [(z, [(x, y), ...]), ...], same point count per ring.
    The workhorse for canisters, collars, caps, tapered and stepped bodies."""
    bm = bmesh.new()
    vr = [[bm.verts.new((x, y, z)) for (x, y) in pts] for z, pts in rings]
    n = len(vr[0])
    for a, b in zip(vr, vr[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap:
        bm.faces.new(list(reversed(vr[0])))
        bm.faces.new(vr[-1])
    return _rw_finish(bm, name)


def rw_hull(name, pts):
    """Convex faceted solid from a point cloud: wedges, chamfered blocks, carved caps."""
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    return _rw_finish(bm, name)


def rw_cham_box(name, sx, sy, sz, c, cz=None):
    """Box with every edge cut by one flat chamfer (c in X/Y, cz in Z). Never a plain box."""
    cz = c if cz is None else cz
    x, y, z = sx / 2, sy / 2, sz / 2
    pts = []
    for a in (-1, 1):
        for b in (-1, 1):
            for d in (-1, 1):
                pts += [(a * (x - c), b * (y - c), d * z), (a * (x - c), b * y, d * (z - cz)), (a * x, b * (y - c), d * (z - cz))]
    return rw_hull(name, pts)


def rw_plane_cut(mesh, point, normal, fill=True):
    """Deliberate planar cut: remove everything on the +normal side of the plane and cap it."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    r = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(point), plane_no=Vector(normal).normalized(), clear_outer=True)
    if fill:
        edges = [e for e in r["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if edges:
            bmesh.ops.contextual_create(bm, geom=edges)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), verts=bm.verts, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = False
    mesh.update()
    return mesh


def rw_bool(target, cutter, op="DIFFERENCE", keep_cutter=False):
    """Apply an exact boolean (recess, inset seat, slot). target/cutter are objects in the same scene."""
    mod = target.modifiers.new("rw_bool", "BOOLEAN")
    mod.operation = op
    mod.solver = "EXACT"
    mod.object = cutter
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(target.evaluated_get(dg))
    target.modifiers.remove(mod)
    old = target.data
    mats = list(old.materials)
    target.data = me
    if not me.materials:
        for m in mats:
            me.materials.append(m)
    me.name = old.name
    if old.users == 0:
        bpy.data.meshes.remove(old)
    for p in me.polygons:
        p.use_smooth = False
    if not keep_cutter:
        cm = cutter.data
        bpy.data.objects.remove(cutter, do_unlink=True)
        if cm and cm.users == 0:
            bpy.data.meshes.remove(cm)
    return target


# --- audit (run before every render you report) --------------------------------------------------------
def _rw_bvh(o, dg):
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    me.transform(o.matrix_world)
    me.calc_loop_triangles()
    verts = [v.co.copy() for v in me.vertices]
    tris = [tuple(t.vertices) for t in me.loop_triangles]
    norms = [t.normal.copy() for t in me.loop_triangles]
    cents = [t.center.copy() for t in me.loop_triangles]
    ev.to_mesh_clear()
    return BVHTree.FromPolygons(verts, tris), verts, norms, cents, len(tris)


def rw_audit(prefix, seats=()):
    """Geometry audit of every mesh object whose name starts with prefix.
    seats: pairs of name fragments allowed to interpenetrate on purpose, e.g. [("Pin", "Latch")].
    Returns a dict: style violations, tri count, overlapping pairs, coplanar same-facing faces
    (z-fight), floating parts (no contact within 0.004), open/non-manifold edges."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    objs = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(prefix)]
    rep = {"objects": len(objs), "tris": 0, "style": [], "overlap": [], "coplanar": [], "floating": [], "open_edges": []}
    data = {}
    for o in objs:
        for m in o.modifiers:
            if m.type in {"SUBSURF", "MULTIRES"} or (m.type == "BEVEL" and m.segments > 1):
                rep["style"].append(f"{o.name}: {m.type} modifier")
        if any(p.use_smooth for p in o.data.polygons):
            rep["style"].append(f"{o.name}: smooth-shaded faces")
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bad = sum(1 for e in bm.edges if not e.is_manifold)
        bm.free()
        if bad:
            rep["open_edges"].append(f"{o.name}: {bad}")
        data[o.name] = _rw_bvh(o, dg)
        rep["tris"] += data[o.name][4]
    names = sorted(data)

    def seated(a, b):
        return any((x in a and y in b) or (x in b and y in a) for x, y in seats)

    touch = {n: False for n in names}
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            ta, va, na, ca, _ = data[a]
            tb, vb, nb, cb, _ = data[b]
            hits = ta.overlap(tb)
            if hits:
                touch[a] = touch[b] = True
                if not seated(a, b):
                    rep["overlap"].append(f"{a} x {b}: {len(hits)} tri pairs")
            zf = 0
            for (n1, c1, other) in ((na, ca, tb), (nb, cb, ta)):
                for nrm, cen in zip(n1, c1):
                    loc, hn, _idx, _d = other.ray_cast(cen + nrm * 0.004, -nrm, 0.008)
                    if loc is not None:
                        touch[a] = touch[b] = True
                        if hn.dot(nrm) > 0.999:
                            zf += 1
            if zf:
                rep["coplanar"].append(f"{a} ~ {b}: {zf} faces")
            if not (touch[a] and touch[b]):
                for (vs, other, who) in ((va, tb, a), (vb, ta, b)):
                    for v in vs[::max(1, len(vs) // 40)]:
                        _l, _n, _i, d = other.find_nearest(v, 0.004)
                        if d is not None:
                            touch[a] = touch[b] = True
                            break
    rep["floating"] = [n for n in names if not touch[n]] if len(names) > 1 else []
    return rep


# --- review renders (same rig for every prop so the set can be compared) ----------------------------
# Camera directions FROM the prop (forward is +X, left is +Y).
RW_VIEWS = {
    "hero": (1.0, -0.85, 0.55), "back": (-1.0, 0.8, 0.5), "side": (0, -1, 0.02), "left": (0, 1, 0.02),
    "front": (1, 0, 0.02), "rear": (-1, 0, 0.02), "top": (-0.25, 0.001, 1),
    "hand": (-1.0, 0.45, 0.5),  # from behind, left and above: roughly the player's eye on a right-hand item
}


def rw_bounds(prefix):
    pts = []
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name.startswith(prefix):
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def rw_render(scene, prefix, out_path, view="hero", res=(1400, 1000), zoom=1.0, target=None, ortho=False):
    """Render every object with this prefix on the shared dark rig. view = key of RW_VIEWS or a
    direction tuple. zoom > 1 crops in (close-ups); target = world point to centre on."""
    bpy.context.window.scene = scene
    lo, hi = rw_bounds(prefix)
    cen = Vector(target) if target is not None else (lo + hi) / 2
    rad = max((hi - lo).length / 2, 0.05) / zoom
    rig = rw_col(scene, "RW_Rig_" + scene.name)
    for o in list(rig.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    d = Vector(RW_VIEWS[view] if isinstance(view, str) else view).normalized()
    cam_d = bpy.data.cameras.new("RW_Cam")
    cam = bpy.data.objects.new("RW_Cam", cam_d)
    rig.objects.link(cam)
    cam_d.lens = 85
    cam_d.clip_start = 0.005
    cam_d.clip_end = 500
    dist = rad / math.tan(cam_d.angle_y / 2) * 1.25
    if ortho:
        cam_d.type = "ORTHO"
        cam_d.ortho_scale = rad * 2.6 * max(1.0, res[0] / res[1])
    cam.location = cen + d * dist
    cam.rotation_euler = (cen - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    right = d.cross(Vector((0, 0, 1))).normalized() if abs(d.z) < 0.95 else Vector((1, 0, 0))
    for nm, off, energy, col, size in (
        ("Key", d * 0.6 + right * 0.9 + Vector((0, 0, 1.1)), 16, (1.0, 0.97, 0.93), 2.2),
        ("Fill", d * 0.8 - right * 1.2 + Vector((0, 0, 0.2)), 4, (0.80, 0.88, 1.0), 3.0),
        ("Rim", -d * 1.0 - right * 0.3 + Vector((0, 0, 0.9)), 14, (0.85, 0.92, 1.0), 1.6),
    ):
        ld = bpy.data.lights.new("RW_" + nm, "AREA")
        ld.energy = energy * (rad * 4.0) ** 2
        ld.color = col
        ld.size = size * rad
        lo_ = bpy.data.objects.new("RW_" + nm, ld)
        rig.objects.link(lo_)
        lo_.location = cen + off.normalized() * rad * 4.0
        lo_.rotation_euler = (cen - lo_.location).to_track_quat("-Z", "Y").to_euler()
    w = bpy.data.worlds.get("RW_World")
    if not w:
        w = bpy.data.worlds.new("RW_World")
        w.use_nodes = True
        bg = w.node_tree.nodes.get("Background")
        bg.inputs[0].default_value = (*_rw_hex("#0B0E14")[:3], 1.0)
        bg.inputs[1].default_value = 1.0
    scene.world = w
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG" if out_path.lower().endswith(".png") else "JPEG"
    scene.render.image_settings.quality = 92
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = out_path
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.render.render(write_still=True, scene=scene.name)
    return out_path


# --- export (live session; same files as tools/blender/export_mods.py writes) ------------------------
def rw_export(scene, mod, kind, extra_props=None):
    """Export collection <mod> to Rework/v03/Exports/<mod>.fbx + .json for the Studio AbilityBuilder.
    kind: "thrown" | "handheld" | "placed". Objects are named "<mod>_<Part>"; the prefix is stripped
    for the export and restored afterwards. One material per mesh object."""
    import json
    bpy.context.window.scene = scene
    col = bpy.data.collections[mod]
    col["kind"] = kind
    for k, v in (extra_props or {}).items():
        col[k] = v
    objs = [o for o in col.all_objects if o.type in {"MESH", "EMPTY"}]
    bpy.context.view_layer.update()
    pre = mod + "_"
    short = lambda n: n[len(pre):] if n.startswith(pre) else n
    data = {"mod": mod, "axes": "blender (+X forward, +Z up, +Y left), 1 unit = 1 stud; same as the gun exports",
            "props": {k: (col[k] if isinstance(col[k], (int, float, str)) else str(col[k])) for k in col.keys()},
            "parts": [], "locators": []}
    lo_all, hi_all = [1e9] * 3, [-1e9] * 3
    for o in objs:
        if o.type == "EMPTY":
            data["locators"].append({"name": short(o.name), "matrix": [list(r) for r in o.matrix_world]})
            continue
        if len({p.material_index for p in o.data.polygons}) > 1 or not o.data.materials:
            raise RuntimeError(o.name + ": needs exactly one material")
        m = o.data.materials[0]
        o.data.calc_loop_triangles()
        pts = [o.matrix_world @ v.co for v in o.data.vertices]
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        lo_all = [min(a, b) for a, b in zip(lo_all, lo)]
        hi_all = [max(a, b) for a, b in zip(hi_all, hi)]
        data["parts"].append({
            "name": short(o.name), "material": m.name.split(".")[0],
            "look": {"material": m["rbx_material"], "color": m["rbx_color"]},
            "energy": short(o.name).endswith("_Energy"), "tris": len(o.data.loop_triangles),
            "center": [round((lo[i] + hi[i]) / 2, 5) for i in range(3)],
            "size": [round(hi[i] - lo[i], 5) for i in range(3)],
        })
    data["tris"] = sum(p["tris"] for p in data["parts"])
    data["bounds"] = {"min": [round(v, 5) for v in lo_all], "max": [round(v, 5) for v in hi_all]}
    out_dir = os.path.join(RW_WORK, "Exports")
    os.makedirs(out_dir, exist_ok=True)
    names = {o: o.name for o in objs}
    try:
        for o in objs:
            o.name = short(o.name)
        for o in scene.objects:
            o.select_set(False)
        for o in objs:
            o.hide_set(False)
            o.select_set(True)
        bpy.context.view_layer.objects.active = next(o for o in objs if o.type == "MESH")
        fbx = os.path.join(out_dir, mod + ".fbx")
        bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH", "EMPTY"},
                                 apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=True, bake_anim=False)
    finally:
        for o, n in names.items():
            o.name = n
    with open(os.path.join(out_dir, mod + ".json"), "w") as f:
        json.dump(data, f, indent=1)
    return {"mod": mod, "fbx": fbx, "parts": len(data["parts"]), "tris": data["tris"], "bounds": data["bounds"]}


# --- saving ----------------------------------------------------------------------------------------------
def rw_save():
    """Save the shared work file (all forks' scenes)."""
    bpy.ops.wm.save_mainfile()
    return bpy.data.filepath


def rw_write_source(mod, path=None):
    """Write collection <mod> (its objects, meshes, materials) to its own editable .blend:
    Rework/v03/<mod>/<mod>.blend by default. The shared work file stays open and untouched."""
    path = path or os.path.join(RW_WORK, mod, mod + ".blend")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.data.libraries.write(path, {bpy.data.collections[mod]}, fake_user=True)
    return path
