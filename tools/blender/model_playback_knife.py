"""Playback Epic Knife v02: Angular Retro-Deck Tanto with dual spinning cassette
reels, sliding phosphor-lime VU meter bar, transport-key guard, and faceted
tape-spool ring pommel.

Run in live Blender 5.2 MCP with Knife_RemasterV2_v05.blend open.
Layout (stock Knife_Rig): +X blade tip, +Z spine up, -Z cutting edge, +Y left
(player-facing), RightGrip at origin (0, 0, 0).
"""
import bpy, bmesh, math, os
from collections import defaultdict
from mathutils import Vector

sc = bpy.context.scene
rig = bpy.data.objects["Knife_Rig"]
COL_NAME = "Playback Knife v02"

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
    pbsdf("PB2 Putty Deck", "C4BCB0", 0.0, 0.34),         # 0 PUTTY
    pbsdf("PB2 Plum Casing", "5E4866", 0.0, 0.36),        # 1 PLUM
    pbsdf("PB2 Deck Core", "1A1D24", 0.0, 0.44),          # 2 DECK
    pbsdf("PB2 Grip Charcoal", "22242C", 0.0, 0.72),      # 3 GRIP
    pbsdf("PB2 Machined Silver", "D5DAE2", 1.0, 0.16),    # 4 STEEL
    pbsdf("PB2 Gunmetal", "4A505E", 1.0, 0.30),           # 5 GUNMETAL
    pbsdf("PB2 VU Lime", "8FE34E", 0.0, 0.25, emit=2.0),  # 6 VU_LIME
    pbsdf("PB2 Rec Coral", "E64B3C", 0.0, 0.25, emit=1.8),# 7 REC_RED
    pbsdf("PB2 Tape Amber", "E0943E", 0.65, 0.28),        # 8 AMBER
]
PUTTY, PLUM, DECK, GRIP, STEEL, GUNMETAL, VU_LIME, REC_RED, AMBER = range(9)

# Clean collection
col = bpy.data.collections.get(COL_NAME)
if col is None:
    col = bpy.data.collections.new(COL_NAME)
    sc.collection.children.link(col)
for o in list(col.objects):
    me = o.data
    bpy.data.objects.remove(o, do_unlink=True)
    if me and me.users == 0 and isinstance(me, bpy.types.Mesh):
        bpy.data.meshes.remove(me)

# Rest pose
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


def ring_mats(half_mats, bottom=STEEL, top=PUTTY):
    return list(half_mats) + [top] + list(reversed(half_mats)) + [bottom]


def loft(stations, mats, caps=(True, True), cap_mat=STEEL):
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


def loft3(stations, mats, caps=(True, True), cap_mat=STEEL):
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


def solid_plate(outline, y0, y1, ch=0.004, mat=PUTTY, bevel_mat=STEEL, open_inner=False):
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


def prism(outline, y0, y1, side=DECK, floor=DECK):
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


def cut(obj, cutters_bm, rim=0.002, rim_mat=STEEL):
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
            if len(e.link_faces) == 2 and DECK in ms and len(ms) == 2:
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
    return link("PBK_GripCore", bm)


# ------------------------------------------------------------------ blade
# Broad angular retro-tanto blade with stepped putty spine & open cassette bay
def blade_profile(x):
    sp = [(0.34, 0.088), (0.98, 0.092), (1.16, 0.084), (1.38, 0.054), (1.44, 0.039)]
    ed = [(0.34, -0.088), (0.42, -0.098), (1.02, -0.092), (1.14, -0.070), (1.32, -0.015), (1.44, 0.031)]
    def lp(pts):
        if x <= pts[0][0]: return pts[0][1]
        for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
            if x0 <= x <= x1:
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
        return pts[-1][1]
    return lp(sp), lp(ed)


def build_blade():
    xs = [0.335, 0.38, 0.44, 0.56, 0.72, 0.88, 0.98, 1.06, 1.14, 1.24, 1.34, 1.40, 1.44]
    st = []
    for x in xs:
        s, e = blade_profile(x)
        h = s - e
        t = 0.022 * (1.0 - max(0.0, (x - 1.12) / 0.34) * 0.82)
        half = [
            (0.0008, e),
            (0.0075, e + 0.24 * h),
            (t, e + 0.34 * h),
            (t, s - 0.028),
            (t * 0.88, s - 0.012),
            (t * 0.52, s),
        ]
        st.append((x, ring(half)))
    x_tip, r_tip = st[-1]
    st[-1] = (x_tip, [(y * 0.14, z) for y, z in r_tip])
    # Edge grind = STEEL, lower bevel = STEEL, flat body = PLUM, upper bevel = PUTTY, spine = PUTTY
    mats = [STEEL, STEEL, PLUM, PUTTY, PUTTY]
    o = link("PBK_Blade", loft(st, ring_mats(mats, bottom=STEEL, top=PUTTY), cap_mat=STEEL))

    # Cut open-through framed cassette bay right through the flat of the blade (x = 0.44..0.98)
    bay_out = [
        (0.455, -0.024), (0.485, 0.056), (0.945, 0.058),
        (0.975, 0.028), (0.955, -0.044), (0.485, -0.046),
    ]
    # Cut all the way through Y (-0.06..+0.06) so the spinning reels read from BOTH sides!
    cut(o, [prism(bay_out, -0.08, 0.08, side=DECK, floor=DECK)], rim=0.0025, rim_mat=PUTTY)

    # Add a thin dark cassette bridge bar behind the reels (connecting front & rear walls of the bay)
    bridge = [
        (0.450, -0.012), (0.978, -0.010), (0.978, 0.024), (0.450, 0.022),
    ]
    br = link("PBK_CassetteBridge", solid_plate(bridge, -0.005, 0.005, ch=0.0, mat=DECK, bevel_mat=DECK))

    # Putty-cream armored deck spine rail along top of blade (seats VU meter track!)
    spine_out = [
        (0.320, 0.066), (1.030, 0.070), (1.110, 0.092), (1.020, 0.112),
        (0.355, 0.110), (0.315, 0.088),
    ]
    sp_o = link("PBK_SpineDeck", solid_plate(spine_out, 0.0, 0.024, ch=0.0038, mat=PUTTY, bevel_mat=STEEL, open_inner=True))
    mirror_apply(sp_o, merge=True)
    # Recessed dark VU meter trough on BOTH sides of spine rail
    trough = [(0.42, 0.078), (0.96, 0.080), (0.96, 0.098), (0.42, 0.096)]
    cut(sp_o, [prism(trough, 0.018, 0.06), prism(trough, -0.018, -0.06)], rim=0.0015, rim_mat=PLUM)

    # Amber tape-stripe accent inlaid along lower blade fuller (x = 1.00..1.30)
    stripe = [(1.01, -0.028), (1.28, 0.018), (1.25, 0.032), (1.00, -0.010)]
    st_o = link("PBK_TapeAccent", solid_plate(stripe, 0.014, 0.0225, ch=0.0015, mat=AMBER, bevel_mat=STEEL))
    mirror_apply(st_o)
    return o, br, sp_o, st_o


def build_reel(name, cx, cz, flat_group):
    """8-sided faceted spinning cassette reel split into single-material parts
    (rim, spokes, hub) with distinct flat_groups so all 3 spin together cleanly."""
    n = 8
    r_outer = 0.044
    y_half = 0.0245

    def oct_r(y, r):
        return [(cx + r * math.cos(2 * math.pi * (i + 0.5) / n), y, cz + r * math.sin(2 * math.pi * (i + 0.5) / n))
                for i in range(n)]

    bm_rim = loft3([oct_r(-y_half, r_outer - 0.005), oct_r(-y_half + 0.004, r_outer),
                    oct_r(y_half - 0.004, r_outer), oct_r(y_half, r_outer - 0.005)],
                   [GUNMETAL] * n, caps=(True, True), cap_mat=GUNMETAL)
    o_rim = link(name + "_Rim", bm_rim, bone="Root", flat_group=flat_group + "Rim")

    bm_sp = bmesh.new()
    for sgn in (1.0, -1.0):
        for k in range(4):
            ang = math.radians(45 * k)
            ca, sa = math.cos(ang), math.sin(ang)
            tx, tz = -sa * 0.0055, ca * 0.0055
            p0 = (cx - ca * 0.036, sgn * y_half, cz - sa * 0.036)
            p1 = (cx + ca * 0.036, sgn * y_half, cz + sa * 0.036)
            y_in = sgn * (y_half - 0.002)
            y_out = sgn * (y_half + 0.004)
            quad = [
                (p0[0] - tx, p0[2] - tz), (p1[0] - tx, p1[2] - tz),
                (p1[0] + tx, p1[2] + tz), (p0[0] + tx, p0[2] + tz),
            ]
            lo = [bm_sp.verts.new((px, y_in, pz)) for px, pz in quad]
            hi = [bm_sp.verts.new((px, y_out, pz)) for px, pz in quad]
            bm_sp.faces.new(lo); bm_sp.faces.new(hi)
            for i in range(4):
                bm_sp.faces.new((lo[i], lo[(i + 1) % 4], hi[(i + 1) % 4], hi[i]))
    for f in bm_sp.faces:
        f.material_index = STEEL
    bmesh.ops.recalc_face_normals(bm_sp, faces=bm_sp.faces)
    o_sp = link(name + "_Spokes", bm_sp, bone="Root", flat_group=flat_group + "Spokes")

    bm_hub = bmesh.new()
    for sgn in (1.0, -1.0):
        hub_r = [
            [(cx + r * math.cos(math.radians(30 + 60 * i)), sgn * yv, cz + r * math.sin(math.radians(30 + 60 * i)))
             for i in range(6)]
            for yv, r in ((y_half - 0.002, 0.015), (y_half + 0.006, 0.011))
        ]
        rings_h = [[bm_hub.verts.new(p) for p in hr] for hr in hub_r]
        bm_hub.faces.new(rings_h[0])
        bm_hub.faces.new(rings_h[1])
        for j in range(6):
            bm_hub.faces.new((rings_h[0][j], rings_h[0][(j + 1) % 6], rings_h[1][(j + 1) % 6], rings_h[1][j]))
    for f in bm_hub.faces:
        f.material_index = AMBER
    bmesh.ops.recalc_face_normals(bm_hub, faces=bm_hub.faces)
    o_hub = link(name + "_Hub", bm_hub, bone="Root", flat_group=flat_group + "Hub")
    return o_rim, o_sp, o_hub


def build_meter():
    """Glowing phosphor-lime VU meter slider riding inside the upper spine trough."""
    quad = [(0.445, 0.081), (0.615, 0.082), (0.615, 0.095), (0.445, 0.094)]
    o = link("PBK_MeterSweep", solid_plate(quad, 0.016, 0.025, ch=0.0015, mat=VU_LIME, bevel_mat=VU_LIME),
             bone="Root", flat_group="MeterSweep")
    mirror_apply(o)
    return o


def build_guard():
    """Stepped cassette-deck crossguard with iconic red REC & lime PLAY keys."""
    out = [
        (0.280, 0.118), (0.345, 0.145), (0.425, 0.135), (0.435, 0.080),
        (0.400, 0.068), (0.398, -0.075), (0.425, -0.112), (0.390, -0.148),
        (0.320, -0.142), (0.278, -0.102),
    ]
    g = link("PBK_Guard", solid_plate(out, 0.0, 0.048, ch=0.006, mat=PUTTY, bevel_mat=STEEL, open_inner=True))
    mirror_apply(g, merge=True)

    # Plum-slate side bolster frame seating into guard
    bol_out = [
        (0.295, 0.098), (0.385, 0.115), (0.388, -0.115), (0.295, -0.095),
    ]
    bol = link("PBK_GuardBolster", solid_plate(bol_out, 0.044, 0.056, ch=0.003, mat=PLUM, bevel_mat=STEEL))
    mirror_apply(bol)

    # Glowing REC (coral-red) and PLAY (phosphor-lime) transport keys proud on the guard flank!
    rec_q = [(0.312, 0.036), (0.366, 0.036), (0.366, 0.072), (0.312, 0.072)]
    rec = link("PBK_RecKey", solid_plate(rec_q, 0.052, 0.063, ch=0.002, mat=REC_RED, bevel_mat=REC_RED))
    mirror_apply(rec)

    play_q = [(0.312, -0.072), (0.366, -0.072), (0.366, -0.036), (0.312, -0.036)]
    play = link("PBK_PlayKey", solid_plate(play_q, 0.052, 0.063, ch=0.002, mat=VU_LIME, bevel_mat=VU_LIME))
    mirror_apply(play)
    return g, bol, rec, play


def build_grip_and_pommel():
    """Putty & plum armored grip scales with glowing lime status bar + iconic
    octagonal cassette-spool ring pommel."""
    out = [
        (-0.305, 0.064), (-0.180, 0.076), (0.120, 0.076), (0.265, 0.066),
        (0.292, 0.034), (0.265, 0.002), (0.100, 0.010), (-0.140, 0.008),
        (-0.285, 0.014), (-0.312, 0.038),
    ]
    sc_o = link("PBK_GripScales", solid_plate(out, 0.045, 0.060, ch=0.0035, mat=PLUM, bevel_mat=PUTTY))
    mirror_apply(sc_o)

    # Glowing lime LED status strip inlaid in grip scale
    led = [(-0.220, 0.036), (-0.060, 0.038), (-0.060, 0.052), (-0.220, 0.050)]
    led_o = link("PBK_GripLed", solid_plate(led, 0.056, 0.064, ch=0.001, mat=VU_LIME, bevel_mat=VU_LIME))
    mirror_apply(led_o)

    # Faceted octagonal tape-spool ring pommel at butt (x = -0.31..-0.54, open ring!)
    cx, cz = -0.435, -0.005
    n = 8
    r_out, r_in = 0.118, 0.062
    out_ring = [(cx + r_out * math.cos(math.radians(22.5 + 45 * i)),
                 cz + r_out * math.sin(math.radians(22.5 + 45 * i))) for i in range(n)]
    pom = link("PBK_RingPommel", solid_plate(out_ring, 0.0, 0.046, ch=0.006, mat=PLUM, bevel_mat=STEEL, open_inner=True))
    mirror_apply(pom, merge=True)
    in_ring = [(cx + r_in * math.cos(math.radians(22.5 + 45 * i)),
                cz + r_in * math.sin(math.radians(22.5 + 45 * i))) for i in range(n)]
    cut(pom, [prism(in_ring, -0.08, 0.08, side=GUNMETAL, floor=GUNMETAL)], rim=0.003, rim_mat=PUTTY)

    # Collar lug firmly burying the ring pommel into the rear hilt (x = -0.36..-0.28)
    lug = [(-0.375, -0.068), (-0.275, -0.072), (-0.275, 0.070), (-0.375, 0.068)]
    lug_o = link("PBK_PommelLug", solid_plate(lug, 0.0, 0.058, ch=0.005, mat=PUTTY, bevel_mat=STEEL, open_inner=True))
    mirror_apply(lug_o, merge=True)
    return sc_o, led_o, pom, lug_o


# ------------------------------------------------------------------- build
grip_core = retain_grip()
blade_parts = build_blade()
reel_rear = build_reel("PBK_ReelRear", 0.595, 0.008, "ReelRear")
reel_front = build_reel("PBK_ReelFront", 0.845, 0.012, "ReelFront")
meter_o = build_meter()
guard_parts = build_guard()
grip_parts = build_grip_and_pommel()

# Hide stock parts
for n in ("Knife_Blade", "Knife_Hilt", "Knife_Neon"):
    o = bpy.data.objects.get(n)
    if o:
        o.hide_render = True
        o.hide_set(True)

result = {
    "objects": [(o.name, len(o.data.polygons), o.get("flat_group", "")) for o in col.objects],
    "pivots": {
        "ReelRear": [0.595, 0.0, 0.008],
        "ReelFront": [0.845, 0.0, 0.012],
        "MeterSweep": [0.530, 0.0, 0.088],
    },
}
