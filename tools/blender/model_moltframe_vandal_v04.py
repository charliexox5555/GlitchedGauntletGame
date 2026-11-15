"""Moltframe Vandal v04: faceted layered armour over the stock Vandal.

Run inside the Blender MCP session that has Vandal_Moltframe_v03.blend open
(stock rig `Vandal_Rig.001`, review cameras and retained hardware).
Everything is rebuilt each run into the collection "Moltframe Shell v04".

Layout (stock coordinates, studs): +X muzzle, +Z up, +Y = left side
(player-facing; charging handle and selector), -Y = right (bolt).
Rules: gauntlet-build-style (no round forms, flat chamfers, carved ends),
weapon-art-bar (nothing floating, stock fit). Cosmetic forms mirror on Y.
"""

import bpy, bmesh, math
from mathutils import Vector

sc = bpy.context.scene
# Shared by every Moltframe item: set RIG_NAME / COL_NAME / ITEM_KEY before
# exec to build another gun (defaults are the Vandal).
RIG_NAME = globals().get("RIG_NAME", "Vandal_Rig.001")
COL_NAME = globals().get("COL_NAME", "Moltframe Shell v04")
ITEM_KEY = globals().get("ITEM_KEY", "Vandal")
rig = bpy.data.objects[RIG_NAME]

# --------------------------------------------------------------- materials
def _lin(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in c]

def pbsdf(name, hexc, metal, rough, coat=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = (*_lin(hexc), 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    nt.links.new(b.outputs[0], out.inputs[0])
    m.diffuse_color = (*_lin(hexc), 1)
    m["mf_hex"] = hexc
    return m, nt, b

def armour_material():
    # Satin graphite alloy: clean, broad, with a very soft low-frequency value
    # drift (about +-4%) so big faces never read as flat CG grey.
    m, nt, b = pbsdf("MF4 Graphite Armour", "5A6170", 1.0, .29, .0)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 1.6
    nz.inputs["Detail"].default_value = 1.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*[v * .93 for v in _lin("5A6170")], 1)
    ramp.color_ramp.elements[1].color = (*[v * 1.07 for v in _lin("5A6170")], 1)
    nt.links.new(nz.outputs["Fac"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], b.inputs["Base Color"])
    rr = nt.nodes.new("ShaderNodeMapRange")
    rr.inputs["To Min"].default_value = .24
    rr.inputs["To Max"].default_value = .31
    nt.links.new(nz.outputs["Fac"], rr.inputs["Value"])
    nt.links.new(rr.outputs[0], b.inputs["Roughness"])
    return m

def violet_material():
    """Glossy aubergine fluid with two marbling layers and fine lilac veins.

    The motion is a seamless loop: the warp noise samples a circle in two
    spare noise dimensions, theta = 2*pi*frame/LOOP, so the last frame meets
    the first with no cross-fade. Chamber edges and metal stay static because
    only this material's internal coordinates move.
    """
    m, nt, b = pbsdf("MF4 Violet Chamber", "2A0E3A", 0.0, .16, .35)
    b.inputs["Coat Roughness"].default_value = .03
    b.inputs["Coat IOR"].default_value = 1.6
    b.inputs["Specular IOR Level"].default_value = .32
    N = nt.nodes; L = nt.links.new
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ"); L(tc.outputs["Object"], sep.inputs[0])
    t = N.new("ShaderNodeValue"); t.label = t.name = "loop_theta"
    fc = t.outputs[0].driver_add("default_value")
    fc.driver.expression = "2*pi*((frame-1) % 144)/144"
    cosn = N.new("ShaderNodeMath"); cosn.operation = "COSINE"; L(t.outputs[0], cosn.inputs[0])
    sinn = N.new("ShaderNodeMath"); sinn.operation = "SINE"; L(t.outputs[0], sinn.inputs[0])
    R = .55
    cr = N.new("ShaderNodeMath"); cr.operation = "MULTIPLY"; cr.inputs[1].default_value = R; L(cosn.outputs[0], cr.inputs[0])
    sr = N.new("ShaderNodeMath"); sr.operation = "MULTIPLY"; sr.inputs[1].default_value = R; L(sinn.outputs[0], sr.inputs[0])
    # surface coords: along the gun (x) and up (z); y is the chamber normal
    comb = N.new("ShaderNodeCombineXYZ")
    L(sep.outputs["X"], comb.inputs[0]); L(sep.outputs["Z"], comb.inputs[1]); L(cr.outputs[0], comb.inputs[2])
    # layer A: broad slow warp (the "deep" layer)
    wa = N.new("ShaderNodeTexNoise"); wa.noise_dimensions = "4D"
    wa.inputs["Scale"].default_value = 5.0; wa.inputs["Detail"].default_value = 2.0
    wa.inputs["Roughness"].default_value = .45
    L(comb.outputs[0], wa.inputs["Vector"]); L(sr.outputs[0], wa.inputs["W"])
    # warped coords
    wsub = N.new("ShaderNodeVectorMath"); wsub.operation = "SUBTRACT"
    L(wa.outputs["Color"], wsub.inputs[0]); wsub.inputs[1].default_value = (.5, .5, .5)
    wsc = N.new("ShaderNodeVectorMath"); wsc.operation = "SCALE"; wsc.inputs["Scale"].default_value = .16
    L(wsub.outputs[0], wsc.inputs[0])
    flat = N.new("ShaderNodeCombineXYZ"); L(sep.outputs["X"], flat.inputs[0]); L(sep.outputs["Z"], flat.inputs[1])
    pw = N.new("ShaderNodeVectorMath"); pw.operation = "ADD"; L(flat.outputs[0], pw.inputs[0]); L(wsc.outputs[0], pw.inputs[1])
    # marbling bands along the channel (bands run lengthwise like poured fluid)
    w1 = N.new("ShaderNodeTexWave"); w1.wave_type = "BANDS"; w1.bands_direction = "Y"
    w1.inputs["Scale"].default_value = 4.5; w1.inputs["Distortion"].default_value = 11.0
    w1.inputs["Detail"].default_value = 3.0; w1.inputs["Detail Scale"].default_value = 1.4
    w1.inputs["Detail Roughness"].default_value = .62
    L(pw.outputs[0], w1.inputs["Vector"])
    # finer second layer, rotated, for the thin veins
    w2 = N.new("ShaderNodeTexWave"); w2.wave_type = "BANDS"; w2.bands_direction = "DIAGONAL"
    w2.inputs["Scale"].default_value = 10.0; w2.inputs["Distortion"].default_value = 9.0
    w2.inputs["Detail"].default_value = 2.0; w2.inputs["Detail Scale"].default_value = 1.2
    L(pw.outputs[0], w2.inputs["Vector"])
    ra = N.new("ShaderNodeValToRGB"); cr_ = ra.color_ramp
    cr_.elements[0].position = .0; cr_.elements[0].color = (*_lin("18051F"), 1)
    cr_.elements[1].position = 1.0; cr_.elements[1].color = (*_lin("8A35B4"), 1)
    e = cr_.elements.new(.45); e.color = (*_lin("360C4A"), 1)
    e = cr_.elements.new(.80); e.color = (*_lin("5E1E86"), 1)
    L(w1.outputs["Fac"], ra.inputs[0])
    # vein mask: narrow peak of layer 2
    vr = N.new("ShaderNodeValToRGB"); vc = vr.color_ramp
    vc.interpolation = "B_SPLINE"
    vc.elements[0].position = .0; vc.elements[0].color = (0, 0, 0, 1)
    vc.elements[1].position = 1.0; vc.elements[1].color = (0, 0, 0, 1)
    e = vc.elements.new(.42); e.color = (0, 0, 0, 1)
    e = vc.elements.new(.5); e.color = (1, 1, 1, 1)
    e = vc.elements.new(.58); e.color = (0, 0, 0, 1)
    L(w2.outputs["Fac"], vr.inputs[0])
    vm = N.new("ShaderNodeMix"); vm.data_type = "RGBA"; vm.blend_type = "SCREEN"
    vmf = N.new("ShaderNodeMath"); vmf.operation = "MULTIPLY"; vmf.inputs[1].default_value = .26
    L(vr.outputs[0], vmf.inputs[0]); L(vmf.outputs[0], vm.inputs["Factor"])
    L(ra.outputs[0], vm.inputs["A"]); vm.inputs["B"].default_value = (*_lin("D29AF5"), 1)
    # depth: darken towards the gasket walls (AO) so the fluid sits low
    ao = N.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = .03; ao.samples = 16
    L(vm.outputs["Result"], ao.inputs["Color"])
    aom = N.new("ShaderNodeMix"); aom.data_type = "RGBA"; aom.blend_type = "MULTIPLY"
    aom.inputs["Factor"].default_value = .85
    L(vm.outputs["Result"], aom.inputs["A"])
    aoc = N.new("ShaderNodeMapRange"); aoc.inputs["To Min"].default_value = .25
    L(ao.outputs["AO"], aoc.inputs["Value"])
    L(aoc.outputs[0], aom.inputs["B"])
    L(aom.outputs["Result"], b.inputs["Base Color"])
    # faint self-light so the chamber still reads in a dark corner
    L(aom.outputs["Result"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = .35
    m["mf_hex"] = "3A1458"
    return m

MATS = [
    armour_material(),                                     # 0 ARM
    pbsdf("MF4 Polished Fold", "C3CAD6", 1.0, .14)[0],      # 1 EDGE
    pbsdf("MF4 Core Graphite", "171A22", .55, .42)[0],      # 2 CORE
    pbsdf("MF4 Gasket", "100A16", 0.0, .5)[0],              # 3 GASKET
    violet_material(),                                     # 4 VIOLET
    pbsdf("MF4 Grip", "23252F", 0.0, .72)[0],               # 5 GRIP
    pbsdf("MF4 Steel", "4E5462", 1.0, .34)[0],              # 6 STEEL
    pbsdf("MF4 Lilac Alloy", "7C7290", 1.0, .28)[0],        # 7 LILAC
]
ARM, EDGE, CORE, GASKET, VIOLET, GRIP, STEEL, LILAC = range(8)

# ------------------------------------------------------------ collections
col = bpy.data.collections.get(COL_NAME)
if col is None:
    col = bpy.data.collections.new(COL_NAME)
    sc.collection.children.link(col)
for o in list(col.objects):
    me = o.data
    bpy.data.objects.remove(o, do_unlink=True)
    if me and me.users == 0:
        if isinstance(me, bpy.types.Mesh):
            bpy.data.meshes.remove(me)
        elif isinstance(me, bpy.types.Armature):
            bpy.data.armatures.remove(me)

# rest pose for building
if rig.animation_data:
    rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.matrix_basis.identity()
sc.frame_set(1)
bpy.context.view_layer.update()

def link(name, bm, bone="Root", smooth=False):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for m in MATS:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = smooth
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    o.parent = rig
    o.parent_type = "BONE"
    o.parent_bone = bone
    bpy.context.view_layer.update()
    o.matrix_world.identity()
    bpy.context.view_layer.update()
    return o

# --------------------------------------------------------------- builders
def loft(stations, mats, caps=(True, True), cap_mat=ARM):
    """stations: [(x, [(y, z), ...])] closed rings with equal counts.
    mats[j] is the material of the strip between ring points j and j+1."""
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

def ring(half):
    """Mirror a +Y half profile (bottom -> top) into a closed ring."""
    return list(half) + [(-y, z) for y, z in reversed(half)]

def ring_mats(half_mats, bottom=CORE, top=ARM):
    # half has k points -> k-1 strips; then top strip, mirrored strips, bottom
    return list(half_mats) + [top] + list(reversed(half_mats)) + [bottom]

def solid_plate(outline, y0, y1, ch=.0055, fold=None, mat=ARM, open_inner=False):
    """Extrude a side-view outline [(x, z)] between y0 (inner) and y1 (outer),
    chamfer the outer rim, then fold the outer face along a crease line.
    fold = ((x0, z0), (x1, z1), amp, reach): outer verts move +y by
    amp*(1-|d|/reach), d = distance from the crease (planar each side)."""
    bm = bmesh.new()
    lo = [bm.verts.new((x, y0, z)) for x, z in outline]
    hi = [bm.verts.new((x, y1, z)) for x, z in outline]
    n = len(outline)
    bm.faces.new(lo)
    top = bm.faces.new(hi)
    for i in range(n):
        f = bm.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
        f.material_index = mat
    for f in bm.faces:
        f.material_index = mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if ch > 0:
        res = bmesh.ops.bevel(bm, geom=list(top.edges), offset=ch, offset_type="OFFSET",
                              segments=1, profile=.5, affect="EDGES", clamp_overlap=True)
        for f in res["faces"]:
            f.material_index = EDGE
    if fold:
        (fx0, fz0), (fx1, fz1), amp, reach = fold
        d = Vector((fx1 - fx0, fz1 - fz0)).normalized()
        nrm = Vector((-d.y, d.x))
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                               plane_co=(fx0, 0, fz0), plane_no=(nrm.x, 0, nrm.y))
        mid = (y0 + y1) / 2
        for v in bm.verts:
            if v.co.y > mid:
                dist = abs((v.co.x - fx0) * nrm.x + (v.co.z - fz0) * nrm.y)
                v.co.y += amp * (1 - dist / reach)
    if open_inner:
        inner = [f for f in bm.faces if all(abs(v.co.y - y0) < 1e-7 for v in f.verts)]
        bmesh.ops.delete(bm, geom=inner, context="FACES_ONLY")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def prism(outline, y0, y1, side=GASKET, floor=VIOLET, outer=GASKET):
    """Window cutter: outline [(x, z)], floor face at y0 (gets the fluid)."""
    bm = bmesh.new()
    lo = [bm.verts.new((x, y0, z)) for x, z in outline]
    hi = [bm.verts.new((x, y1, z)) for x, z in outline]
    n = len(outline)
    a = bm.faces.new(lo); a.material_index = floor
    b = bm.faces.new(hi); b.material_index = outer
    for i in range(n):
        f = bm.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
        f.material_index = side
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

CUT_FAILURES = []

def cut(obj, cutters_bm, rim=.0035):
    """Boolean the cutters out of obj, transferring cutter materials (fluid
    floor + gasket walls), then chamfer the window lip so it catches light."""
    tmp = []
    for i, cbm in enumerate(cutters_bm):
        me = bpy.data.meshes.new("_cut")
        cbm.to_mesh(me); cbm.free()
        for m in MATS:
            me.materials.append(m)
        co = bpy.data.objects.new("_cut", me)
        col.objects.link(co)
        co.matrix_world = obj.matrix_world.copy()
        tmp.append(co)
    def _ext(me_):
        return max((abs(v.co.y) for v in me_.vertices), default=0), max((abs(v.co.z) for v in me_.vertices), default=0)
    for co in tmp:
        before = obj.data.copy()
        ext0 = _ext(obj.data)
        md = obj.modifiers.new("cut", "BOOLEAN")
        md.operation = "DIFFERENCE"; md.solver = "EXACT"; md.object = co
        md.material_mode = "TRANSFER"
        bpy.context.view_layer.objects.active = obj
        with bpy.context.temp_override(object=obj, active_object=obj):
            bpy.ops.object.modifier_apply(modifier=md.name)
        ext1 = _ext(obj.data)
        if ext1[0] > ext0[0] + .02 or ext1[1] > ext0[1] + .02 or len(obj.data.polygons) < 4 or ext1[1] < ext0[1] * .5:
            # a failed difference keeps cutter geometry: roll this cutter back
            bad = obj.data
            obj.data = before
            bpy.data.meshes.remove(bad)
            CUT_FAILURES.append(obj.name)
        else:
            bpy.data.meshes.remove(before)
    for co in tmp:
        me = co.data
        bpy.data.objects.remove(co, do_unlink=True)
        bpy.data.meshes.remove(me)
    # tidy: boolean may have appended duplicate material slots
    me = obj.data
    names = [m.name for m in MATS]
    remap = {}
    for i, m in enumerate(me.materials):
        remap[i] = names.index(m.name) if m and m.name in names else 0
    for p in me.polygons:
        p.material_index = remap[p.material_index]
    while len(me.materials) > len(MATS):
        me.materials.pop(index=len(me.materials) - 1)
    if rim > 0:
        bm = bmesh.new(); bm.from_mesh(me)
        edges = []
        for e in bm.edges:
            mats = {f.material_index for f in e.link_faces}
            if len(e.link_faces) == 2 and GASKET in mats and (ARM in mats or EDGE in mats):
                edges.append(e)
        if edges:
            res = bmesh.ops.bevel(bm, geom=edges, offset=rim, offset_type="OFFSET", segments=1,
                                  profile=.5, affect="EDGES", clamp_overlap=True)
            for f in res["faces"]:
                f.material_index = EDGE
        bm.to_mesh(me); bm.free()
    me.update()

def mirror_apply(obj, merge=False):
    md = obj.modifiers.new("mir", "MIRROR")
    md.use_axis = (False, True, False)
    md.use_mirror_merge = merge
    md.merge_threshold = 1e-5
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_apply(modifier=md.name)

def flat_uv(obj, scale=1.0):
    """Planar side projection (u = x, v = z): matches a face-aligned Roblox
    Texture on the chamber floors and keeps the armour maps simple."""
    me = obj.data
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        n = p.normal
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if abs(n.y) >= max(abs(n.x), abs(n.z)):
                u, v = co.x, co.z
            elif abs(n.z) >= abs(n.x):
                u, v = co.x, co.y
            else:
                u, v = co.y, co.z
            uv.data[li].uv = (u * scale, v * scale)


if ITEM_KEY == "Vandal":
    # ------------------------------------------------- retained stock hardware
    EXTRA = {
        "Neon": pbsdf("MF4 Indicator", "BA63F2", 0.0, .3)[0],
        "Brass": pbsdf("MF4 Smoke Nickel", "63637A", 1.0, .30)[0],
    }
    _ind = EXTRA["Neon"].node_tree.nodes["Principled BSDF"]
    _ind.inputs["Emission Color"].default_value = (*_lin("BA63F2"), 1)
    _ind.inputs["Emission Strength"].default_value = 2.0
    SLOT_SKIN = [MATS[ARM], MATS[ARM], MATS[CORE], MATS[STEEL], MATS[GRIP], MATS[LILAC], EXTRA["Neon"], EXTRA["Brass"]]
    STOCK_SET = ["Body.001", "Panel.001", "Dark.001", "Metal.001", "Grip.001", "Accent.001", "Neon.001", "Brass.001"]
    HARDWARE = ["Vandal_RearSight.001", "Vandal_FrontSight.001", "Vandal_ChargingHandle.001", "Vandal_Bolt.001",
                "Vandal_Trigger.001", "Vandal_FireSelector.001", "Vandal_CharmLoop.001",
                "Moltframe_ReceiverHardware", "Moltframe_PinsHardware", "Moltframe_MagHardware", "Moltframe_GripHardware"]
    STOCK_PARTS = ["Vandal_Neon.001", "Vandal_Receiver.001", "Vandal_Handguard.001", "Vandal_Rail.001",
                   "Vandal_Barrel.001", "Vandal_Grip.001", "Vandal_Stock.001", "Vandal_Pins.001", "Vandal_Mag.001"]
    OLD_SHELL = [o.name for o in sc.objects if o.name.startswith("Moltframe_")
                 and o.name not in ("Moltframe_ReceiverHardware", "Moltframe_PinsHardware",
                                    "Moltframe_MagHardware", "Moltframe_GripHardware")]

    def set_skin(enabled):
        """True: Moltframe v04 (shell + hardware in skin finishes). False: stock."""
        for n in HARDWARE:
            o = bpy.data.objects[n]
            for i, slot in enumerate(o.material_slots):
                if i < 8:
                    slot.material = SLOT_SKIN[i] if enabled else bpy.data.materials[STOCK_SET[i]]
            if n.startswith("Moltframe_"):
                o.hide_render = not enabled; o.hide_set(not enabled)
        for n in STOCK_PARTS:
            o = bpy.data.objects[n]
            for i, slot in enumerate(o.material_slots):
                if i < 8:
                    slot.material = bpy.data.materials[STOCK_SET[i]]
            o.hide_render = enabled; o.hide_set(enabled)
        for n in OLD_SHELL:
            o = bpy.data.objects.get(n)
            if o:
                o.hide_render = True; o.hide_set(True)
        col.hide_render = not enabled
        col.hide_viewport = not enabled
