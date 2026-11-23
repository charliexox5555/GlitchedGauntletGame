"""Sundial Epic Knife v02: Solar Astrolabe Blade with open octagonal gold bezel,
large rotating 8-tooth brass/gold Sun-Dial wheel (with glowing solar core and
gnomon pointer), swept winged champagne-ivory crossguard, plum-obsidian blade
with burnished gold bevels and glowing solar fuller slit, and faceted compass-
rose star pommel.

Run in live Blender 5.2 MCP with Knife_RemasterV2_v05.blend open.
Layout (stock Knife_Rig): +X blade tip, +Z spine up, -Z edge, +Y left.
"""
import bpy, bmesh, math, os
from collections import defaultdict
from mathutils import Vector

sc = bpy.context.scene
rig = bpy.data.objects["Knife_Rig"]
COL_NAME = "Sundial Knife v02"

# --------------------------------------------------------------- materials
def _lin(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in c]

def pbsdf(name, hexc, metal, rough, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = (*_lin(hexc), 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit > 0.0:
        b.inputs["Emission Color"].default_value = (*_lin(hexc), 1)
        b.inputs["Emission Strength"].default_value = emit
    nt.links.new(b.outputs[0], out.inputs[0])
    m.diffuse_color = (*_lin(hexc), 1)
    m["mf_hex"] = hexc
    return m

MATS = [
    pbsdf("SD2 Plum Obsidian", "33213B", 0.0, 0.36),        # 0 OBSIDIAN
    pbsdf("SD2 Champagne Ivory", "DFD5BD", 0.0, 0.34),      # 1 IVORY
    pbsdf("SD2 Solar Gold", "D9A84E", 1.0, 0.18),           # 2 GOLD
    pbsdf("SD2 Antique Brass", "A8803B", 1.0, 0.28),        # 3 BRASS
    pbsdf("SD2 Grip Dark", "1D1A23", 0.0, 0.72),            # 4 GRIP
    pbsdf("SD2 Solar Glow", "FFB84D", 0.0, 0.20, emit=2.2), # 5 SOLAR
    pbsdf("SD2 Sun Noon", "FFF0C4", 0.0, 0.20, emit=2.0),   # 6 NOON
]
OBSIDIAN, IVORY, GOLD, BRASS, GRIP, SOLAR, NOON = range(7)

col = bpy.data.collections.get(COL_NAME)
if col is None:
    col = bpy.data.collections.new(COL_NAME)
    sc.collection.children.link(col)
for o in list(col.objects):
    me = o.data
    bpy.data.objects.remove(o, do_unlink=True)
    if me and me.users == 0 and isinstance(me, bpy.types.Mesh):
        bpy.data.meshes.remove(me)

if rig.animation_data:
    rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.matrix_basis.identity()
sc.frame_set(1)
bpy.context.view_layer.update()


def link(name, bm, bone="Root", flat_group=""):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for m in MATS:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    o.parent = rig
    o.parent_type = "BONE"
    o.parent_bone = bone
    bpy.context.view_layer.update()
    o.matrix_world.identity()
    bpy.context.view_layer.update()
    if flat_group:
        o["flat_group"] = flat_group
    return o


def ring(half):
    return list(half) + [(-y, z) for y, z in reversed(half)]


def ring_mats(half_mats, bottom=GOLD, top=GOLD):
    return list(half_mats) + [top] + list(reversed(half_mats)) + [bottom]


def loft(stations, mats, caps=(True, True), cap_mat=GOLD):
    bm = bmesh.new()
    rings = [[bm.verts.new((x, y, z)) for y, z in pts] for x, pts in stations]
    n = len(rings[0])
    for i in range(len(rings) - 1):
        for j in range(n):
            f = bm.faces.new((rings[i][j], rings[i][(j + 1) % n],
                              rings[i + 1][(j + 1) % n], rings[i + 1][j]))
            f.material_index = mats[j]
    for k, on in zip((0, -1), caps):
        if on:
            f = bm.faces.new(rings[k])
            f.material_index = cap_mat
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def loft3(stations, mats, caps=(True, True), cap_mat=GOLD):
    bm = bmesh.new()
    rings = [[bm.verts.new(tuple(p)) for p in r] for r in stations]
    n = len(rings[0])
    for i in range(len(rings) - 1):
        for j in range(n):
            f = bm.faces.new((rings[i][j], rings[i][(j + 1) % n],
                              rings[i + 1][(j + 1) % n], rings[i + 1][j]))
            f.material_index = mats[j % len(mats)]
    for k, on in zip((0, -1), caps):
        if on:
            f = bm.faces.new(rings[k])
            f.material_index = cap_mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def solid_plate(outline, y0, y1, ch=0.004, mat=IVORY, bevel_mat=GOLD, open_inner=False):
    bm = bmesh.new()
    lo = [bm.verts.new((x, y0, z)) for x, z in outline]
    hi = [bm.verts.new((x, y1, z)) for x, z in outline]
    n = len(outline)
    bm.faces.new(lo)
    top = bm.faces.new(hi)
    for i in range(n):
        bm.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
    for f in bm.faces:
        f.material_index = mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if ch > 0:
        res = bmesh.ops.bevel(bm, geom=list(top.edges), offset=ch, offset_type="OFFSET",
                              segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
        for f in res["faces"]:
            f.material_index = bevel_mat
    if open_inner:
        inner = [f for f in bm.faces if all(abs(v.co.y - y0) < 1e-7 for v in f.verts)]
        bmesh.ops.delete(bm, geom=inner, context="FACES_ONLY")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prism(outline, y0, y1, side=OBSIDIAN, floor=OBSIDIAN):
    bm = bmesh.new()
    lo = [bm.verts.new((x, y0, z)) for x, z in outline]
    hi = [bm.verts.new((x, y1, z)) for x, z in outline]
    n = len(outline)
    a = bm.faces.new(lo); a.material_index = floor
    b = bm.faces.new(hi); b.material_index = side
    for i in range(n):
        f = bm.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
        f.material_index = side
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def mirror_apply(obj, merge=False):
    md = obj.modifiers.new("mir", "MIRROR")
    md.use_axis = (False, True, False)
    md.use_mirror_merge = merge
    md.merge_threshold = 1e-5
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_apply(modifier=md.name)


def cut(obj, cutters_bm, rim=0.002, rim_mat=GOLD):
    tmp = []
    for cbm in cutters_bm:
        me = bpy.data.meshes.new("_cut")
        cbm.to_mesh(me); cbm.free()
        for m in MATS:
            me.materials.append(m)
        co = bpy.data.objects.new("_cut", me)
        col.objects.link(co)
        co.matrix_world = obj.matrix_world.copy()
        tmp.append(co)
    for co in tmp:
        md = obj.modifiers.new("cut", "BOOLEAN")
        md.operation = "DIFFERENCE"; md.solver = "EXACT"; md.object = co
        md.material_mode = "TRANSFER"
        bpy.context.view_layer.objects.active = obj
        with bpy.context.temp_override(object=obj, active_object=obj):
            bpy.ops.object.modifier_apply(modifier=md.name)
    for co in tmp:
        me = co.data
        bpy.data.objects.remove(co, do_unlink=True)
        bpy.data.meshes.remove(me)
    me = obj.data
    names = [m.name for m in MATS]
    remap = {i: (names.index(m.name) if m and m.name in names else 0) for i, m in enumerate(me.materials)}
    for p in me.polygons:
        p.material_index = remap[p.material_index]
    while len(me.materials) > len(MATS):
        me.materials.pop(index=len(me.materials) - 1)
    if rim > 0:
        bm = bmesh.new(); bm.from_mesh(me)
        edges = []
        for e in bm.edges:
            ms = {f.material_index for f in e.link_faces}
            if len(e.link_faces) == 2 and len(ms) == 2:
                edges.append(e)
        if edges:
            res = bmesh.ops.bevel(bm, geom=edges, offset=rim, offset_type="OFFSET",
                                  segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
            for f in res["faces"]:
                f.material_index = rim_mat
        bm.to_mesh(me); bm.free()
    me.update()


def retain_grip():
    src = bpy.data.objects["Knife_Hilt"]
    me = src.data
    adj = defaultdict(set)
    for p in me.polygons:
        for i in p.vertices:
            adj[i].update(p.vertices)
    keepv, seen = set(), set()
    for i in adj:
        if i in seen: continue
        g, st = {i}, [i]
        while st:
            f = adj[st.pop()] - g; g |= f; st += list(f)
        seen |= g
        pts = [src.matrix_world @ me.vertices[j].co for j in g]
        if min(p.x for p in pts) > -0.35 and max(p.x for p in pts) < 0.34:
            keepv |= g
    bm = bmesh.new(); bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keepv], context="VERTS")
    for v in bm.verts:
        v.co = src.matrix_world @ v.co
    for f in bm.faces:
        f.material_index = GRIP
    return link("SDK_GripCore", bm)


# ------------------------------------------------------------------ blade
DIAL_X, DIAL_Z = 0.565, 0.002


def blade_profile(x):
    """Double-edged swept leaf-spear solar ritual blade flaring cleanly around
    the octagonal astrolabe aperture and tapering to a razor diamond tip."""
    sp = [
        (0.35, 0.088), (0.45, 0.114), (0.565, 0.122), (0.70, 0.114),
        (0.84, 0.090), (1.06, 0.082), (1.28, 0.056), (1.46, 0.006),
    ]
    ed = [
        (0.35, -0.088), (0.45, -0.110), (0.565, -0.118), (0.70, -0.110),
        (0.84, -0.088), (1.06, -0.080), (1.28, -0.052), (1.46, -0.004),
    ]
    def lp(pts):
        if x <= pts[0][0]: return pts[0][1]
        for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
            if x0 <= x <= x1:
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
        return pts[-1][1]
    return lp(sp), lp(ed)


def build_blade():
    xs = [0.345, 0.40, 0.45, 0.565, 0.70, 0.78, 0.86, 0.98, 1.12, 1.26, 1.38, 1.46]
    st = []
    for x in xs:
        s, e = blade_profile(x)
        h = s - e
        t = 0.022 * (1.0 - max(0.0, (x - 1.08) / 0.40) * 0.80)
        half = [
            (0.0008, e),
            (0.0085, e + 0.18 * h),
            (t, e + 0.34 * h),
            (t, s - 0.34 * h),
            (0.0085, s - 0.18 * h),
            (0.0008, s),
        ]
        st.append((x, ring(half)))
    x_tip, r_tip = st[-1]
    st[-1] = (x_tip, [(y * 0.16, z) for y, z in r_tip])
    # Both bevel edges = GOLD, broad central fuller flats = OBSIDIAN!
    mats = [GOLD, GOLD, OBSIDIAN, GOLD, GOLD]
    o = link("SDK_Blade", loft(st, ring_mats(mats, bottom=GOLD, top=GOLD), cap_mat=GOLD))

    # Open octagonal astrolabe aperture cut right through the blade (r = 0.086)
    ap_pts = [(DIAL_X + 0.086 * math.cos(math.radians(22.5 + 45 * i)),
               DIAL_Z + 0.086 * math.sin(math.radians(22.5 + 45 * i))) for i in range(8)]
    cut(o, [prism(ap_pts, -0.08, 0.08, side=BRASS, floor=BRASS)], rim=0.0025, rim_mat=GOLD)

    # Raised octagonal champagne-ivory + gold astrolabe bezel collar framing the dial
    bez_out = [(DIAL_X + 0.106 * math.cos(math.radians(22.5 + 45 * i)),
                DIAL_Z + 0.106 * math.sin(math.radians(22.5 + 45 * i))) for i in range(8)]
    bez = link("SDK_AstrolabeBezel", solid_plate(bez_out, 0.0, 0.028, ch=0.004, mat=IVORY, bevel_mat=GOLD, open_inner=True))
    mirror_apply(bez, merge=True)
    bez_in = [(DIAL_X + 0.083 * math.cos(math.radians(22.5 + 45 * i)),
               DIAL_Z + 0.083 * math.sin(math.radians(22.5 + 45 * i))) for i in range(8)]
    cut(bez, [prism(bez_in, -0.08, 0.08, side=GOLD, floor=GOLD)], rim=0.002, rim_mat=GOLD)

    # Forward champagne-ivory mid-rib ridge + glowing solar fuller channel toward the tip
    rib_out = [(0.68, 0.030), (0.76, 0.036), (1.28, 0.018), (1.36, 0.001), (1.28, -0.016), (0.76, -0.034), (0.68, -0.028)]
    rib = link("SDK_SolarRib", solid_plate(rib_out, 0.014, 0.026, ch=0.003, mat=IVORY, bevel_mat=GOLD))
    mirror_apply(rib)

    # Glowing solar-gold fuller inlay bar seated cleanly along the ivory mid-rib
    slit = [(0.76, 0.009), (1.22, 0.005), (1.26, 0.001), (1.22, -0.005), (0.76, -0.009)]
    slit_o = link("SDK_SolarFuller", solid_plate(slit, 0.021, 0.0285, ch=0.001, mat=SOLAR, bevel_mat=SOLAR))
    mirror_apply(slit_o)
    return o, bez, rib, slit_o


def build_dial():
    """Large rotating faceted 8-tooth brass & gold Sun-Dial wheel centered in
    the astrolabe aperture, split into 3 single-material flat_groups (DialGear,
    DialCore, DialHand) so the entire wheel turns cleanly as one assembly!"""
    y_half = 0.020
    # 1. 8-tooth faceted brass sun-star gear (16 alternating outer/inner radius points)
    gear_pts = []
    for i in range(16):
        ang = math.radians(i * 22.5)
        r = 0.078 if i % 2 == 0 else 0.056
        gear_pts.append((DIAL_X + r * math.cos(ang), DIAL_Z + r * math.sin(ang)))
    gear = link("SDK_DialGear", solid_plate(gear_pts, 0.0, y_half, ch=0.0025, mat=BRASS, bevel_mat=BRASS, open_inner=True),
                bone="Root", flat_group="DialGear")
    mirror_apply(gear, merge=True)
    # Cut a clean 8-sided center recess for the glowing solar core
    hole_pts = [(DIAL_X + 0.036 * math.cos(math.radians(22.5 + 45 * i)),
                 DIAL_Z + 0.036 * math.sin(math.radians(22.5 + 45 * i))) for i in range(8)]
    cut(gear, [prism(hole_pts, -0.06, 0.06, side=BRASS, floor=BRASS)], rim=0.0)

    # 2. Glowing solar-amber crystal core inside the gear (visible both sides!)
    core_pts = [(DIAL_X + 0.037 * math.cos(math.radians(22.5 + 45 * i)),
                 DIAL_Z + 0.037 * math.sin(math.radians(22.5 + 45 * i))) for i in range(8)]
    core = link("SDK_DialCore", solid_plate(core_pts, 0.0, y_half - 0.003, ch=0.002, mat=SOLAR, bevel_mat=SOLAR, open_inner=True),
                bone="Root", flat_group="DialCore")
    mirror_apply(core, merge=True)

    # 3. Bright noon-sun gnomon pointer hand crossing the dial (makes rotation unmistakable!)
    hand_pts = [
        (DIAL_X - 0.022, DIAL_Z - 0.007),
        (DIAL_X + 0.066, DIAL_Z - 0.002),
        (DIAL_X + 0.072, DIAL_Z + 0.000),
        (DIAL_X + 0.066, DIAL_Z + 0.002),
        (DIAL_X - 0.022, DIAL_Z + 0.007),
        (DIAL_X - 0.034, DIAL_Z + 0.000),
    ]
    hand = link("SDK_DialHand", solid_plate(hand_pts, y_half - 0.002, y_half + 0.006, ch=0.001, mat=NOON, bevel_mat=NOON),
                bone="Root", flat_group="DialHand")
    mirror_apply(hand)
    return gear, core, hand


def build_guard():
    """Swept winged champagne-ivory & burnished-gold solar crossguard framing
    the astrolabe bezel."""
    out = [
        (0.285, 0.090), (0.335, 0.165), (0.455, 0.185), (0.425, 0.122),
        (0.390, 0.088), (0.390, -0.088), (0.425, -0.122), (0.455, -0.185),
        (0.335, -0.165), (0.285, -0.090), (0.265, 0.000),
    ]
    g = link("SDK_Guard", solid_plate(out, 0.0, 0.046, ch=0.006, mat=IVORY, bevel_mat=GOLD, open_inner=True))
    mirror_apply(g, merge=True)

    # Deep plum-obsidian central collar medallion on guard flank
    med = [(0.295, 0.068), (0.375, 0.080), (0.375, -0.080), (0.295, -0.068)]
    m_o = link("SDK_GuardCore", solid_plate(med, 0.042, 0.054, ch=0.003, mat=OBSIDIAN, bevel_mat=GOLD))
    mirror_apply(m_o)
    return g, m_o


def build_grip_and_pommel():
    """Obsidian & ivory grip plates with three burnished gold inlay bands +
    faceted octagonal solar compass-rose star pommel."""
    out = [
        (-0.305, 0.064), (-0.180, 0.076), (0.120, 0.076), (0.265, 0.066),
        (0.292, 0.034), (0.265, 0.002), (0.100, 0.010), (-0.140, 0.008),
        (-0.285, 0.014), (-0.312, 0.038),
    ]
    sc_o = link("SDK_GripPlates", solid_plate(out, 0.045, 0.059, ch=0.0035, mat=OBSIDIAN, bevel_mat=IVORY))
    mirror_apply(sc_o)

    # Three crisp angled burnished-gold inlay chevrons along grip scale
    bands = []
    for xc in (-0.15, 0.0, 0.15):
        bq = [(xc - 0.016, 0.018), (xc + 0.008, 0.066), (xc + 0.030, 0.066), (xc + 0.006, 0.018)]
        bands.append(solid_plate(bq, 0.055, 0.064, ch=0.0015, mat=GOLD, bevel_mat=GOLD))
    bm_acc = bmesh.new()
    for b in bands:
        tmp = bpy.data.meshes.new("_g"); b.to_mesh(tmp); b.free()
        bm_acc.from_mesh(tmp); bpy.data.meshes.remove(tmp)
    bo = link("SDK_GripBands", bm_acc)
    mirror_apply(bo)

    # Faceted solar compass-rose star pommel (buried into rear hilt x=-0.30..-0.54)
    cx, cz = -0.425, 0.0
    star_pts = []
    for i in range(12):
        ang = math.radians(i * 30.0)
        r = 0.118 if i % 2 == 0 else 0.084
        star_pts.append((cx + r * math.cos(ang), cz + r * math.sin(ang)))
    pom = link("SDK_CompassPommel", solid_plate(star_pts, 0.0, 0.054, ch=0.0065, mat=OBSIDIAN, bevel_mat=GOLD, open_inner=True))
    mirror_apply(pom, merge=True)

    # Glowing solar jewel inset in pommel center
    jewel = [(cx + 0.038 * math.cos(math.radians(45 * i)), cz + 0.038 * math.sin(math.radians(45 * i))) for i in range(8)]
    jw = link("SDK_PommelJewel", solid_plate(jewel, 0.048, 0.060, ch=0.002, mat=SOLAR, bevel_mat=GOLD))
    mirror_apply(jw)

    # Ivory collar lug seating pommel solidly into hilt (x = -0.37..-0.28)
    lug = [(-0.375, -0.070), (-0.275, -0.074), (-0.275, 0.074), (-0.375, 0.070)]
    lug_o = link("SDK_PommelCollar", solid_plate(lug, 0.0, 0.058, ch=0.005, mat=IVORY, bevel_mat=GOLD, open_inner=True))
    mirror_apply(lug_o, merge=True)
    return sc_o, bo, pom, jw, lug_o


# ------------------------------------------------------------------- build
grip_core = retain_grip()
blade_parts = build_blade()
dial_parts = build_dial()
guard_parts = build_guard()
grip_parts = build_grip_and_pommel()

for n in ("Knife_Blade", "Knife_Hilt", "Knife_Neon"):
    o = bpy.data.objects.get(n)
    if o:
        o.hide_render = True
        o.hide_set(True)

result = {
    "objects": [(o.name, len(o.data.polygons), o.get("flat_group", "")) for o in col.objects],
    "pivots": {
        "Dial": [DIAL_X, 0.0, DIAL_Z],
    },
}
