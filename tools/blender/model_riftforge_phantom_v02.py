"""Build Riftforge Phantom v02 (Sculpted, Textured Legendary Hero) in live Blender 5.2 MCP.

Upgrades over v01:
- Compound-faceted 12-sided multi-station lofts (hull/facet) across every major form:
  receiver, keel, dorsal brow, cheek cowls, handguard, suppressor, stock, grip, mag.
- Zero boxy cubes or flat 2D side-wall slabs; bright machined steel edge bevels for
  crisp silhouette readability in Roblox lighting.
- Real seamless surface patterns mapped via export_roblox_flat.py:
  * RF_ObsidianForged -> Riftforge_Forged (machined octagonal forged-metal plating)
  * RF_GripCarbon     -> Payload_Carbon (tactical twill on grip & cheek pad)
  * RF_PlasmaCore     -> Riftforge_Plasma (scrolling dark-matter plasma veins)
- Removes stock ChargingHandle & Bolt completely so the skin's custom reload/inspect
  choreography uses articulated Reactor Armor Cowls + Magnetic Energy Cell + Dual Gimbal!
- 7 articulated moving parts (flat_group):
  * CowlLeft, CowlRight (swept receiver armor shrouds that flare open & SLAM shut)
  * CoreCrystal (16-face compound-faceted plasma prism that levitates on inspect)
  * CoreRingA, CoreRingB (dual counter-rotating gyroscopic containment rings)
  * VentTop, VentBottom (aerodynamic suppressor accelerator shrouds)
"""
import json
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

assert os.getpid() == 54904, f"Expected live Blender PID 54904, got {os.getpid()}"

ROOT = r"c:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
STOCK_BLEND = os.path.join(ROOT, "art-source", "weapons", "RemasterV2", "Phantom", "Phantom_RemasterV2_v05.blend")
OUT_DIR = os.path.join(ROOT, "art-source", "weapons", "Skins", "Riftforge", "Phantom", "v02")
REV_DIR = os.path.join(OUT_DIR, "review")
os.makedirs(REV_DIR, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=STOCK_BLEND)

for o in list(bpy.data.objects):
    if o.name.startswith("Range") or o.name.startswith("Target"):
        bpy.data.objects.remove(o, do_unlink=True)

bpy.context.view_layer.update()
rig = bpy.data.objects["Phantom_Rig"]

COL_NAME = "Riftforge Phantom v02"
if COL_NAME in bpy.data.collections:
    old_c = bpy.data.collections[COL_NAME]
    for o in list(old_c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(old_c)
col = bpy.data.collections.new(COL_NAME)
bpy.context.scene.collection.children.link(col)


def _lin(h):
    h = h.lstrip("#")
    return tuple(((int(h[i:i + 2], 16) / 255.0) ** 2.2) for i in (0, 2, 4))


def make_mat(name, hexcol, metallic=0.0, roughness=0.42, emit=0.0, tile_png=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    c = _lin(hexcol)
    bsdf.inputs["Base Color"].default_value = (*c, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = (*c, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    # Preview surface texture in Cycles renders too!
    if tile_png and os.path.exists(tile_png):
        tex_coord = nt.nodes.new("ShaderNodeTexCoord")
        mapping = nt.nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (4.0, 4.0, 4.0)
        img_node = nt.nodes.new("ShaderNodeTexImage")
        img_node.image = bpy.data.images.load(tile_png, check_existing=True)
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["Factor"].default_value = 0.42 if emit == 0 else 0.55
        mix.inputs[6].default_value = (*c, 1.0)
        nt.links.new(tex_coord.outputs["Object"], mapping.inputs["Vector"])
        nt.links.new(mapping.outputs["Vector"], img_node.inputs["Vector"])
        nt.links.new(img_node.outputs["Color"], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        if emit > 0:
            nt.links.new(mix.outputs[2], bsdf.inputs["Emission Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    m["mf_hex"] = hexcol.lstrip("#").upper()
    return m


TILES_DIR = os.path.join(ROOT, "art-source", "weapons", "Skins", "_tiles")
M_OBS    = make_mat("RF_ObsidianForged", "1B1F2B", metallic=0.22, roughness=0.38,
                    tile_png=os.path.join(TILES_DIR, "Riftforge_Forged.png"))
M_SLATE  = make_mat("RF_Slate",          "3D485E", metallic=0.72, roughness=0.32)
M_DARK   = make_mat("RF_Dark",           "0F1219", metallic=0.14, roughness=0.58)
M_STEEL  = make_mat("RF_Steel",          "8A9AB5", metallic=0.88, roughness=0.22)
M_BRONZE = make_mat("RF_Bronze",         "C99A50", metallic=0.92, roughness=0.24)
M_GRIP   = make_mat("RF_GripCarbon",     "1E212B", metallic=0.06, roughness=0.68,
                    tile_png=os.path.join(TILES_DIR, "Payload_Carbon.png"))
M_CORE   = make_mat("RF_PlasmaCore",     "B438FF", metallic=0.0,  roughness=0.16, emit=2.8,
                    tile_png=os.path.join(TILES_DIR, "Riftforge_Plasma.png"))
M_HOT    = make_mat("RF_PlasmaHot",      "EDC4FF", metallic=0.0,  roughness=0.10, emit=3.4)

MATS = [M_OBS, M_SLATE, M_DARK, M_STEEL, M_BRONZE, M_GRIP, M_CORE, M_HOT]
MAT_TAG = ["Obs", "Slt", "Drk", "Stl", "Brz", "Grp", "Cor", "Hot"]
OBS, SLT, DRK, STL, BRZ, GRP, COR, HOT = range(8)


def set_flat(mesh):
    mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))
    mesh.update()


def _attach_mesh(name, bm, bone="Root", flat_group=None):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in MATS:
        me.materials.append(m)
    set_flat(me)
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    o.parent = rig
    o.parent_type = "BONE"
    o.parent_bone = bone
    pb = rig.pose.bones[bone]
    tail_mat = rig.matrix_world @ pb.matrix @ Matrix.Translation((0.0, pb.length, 0.0))
    o.matrix_parent_inverse = tail_mat.inverted()
    o.matrix_basis = Matrix.Identity(4)
    if flat_group:
        o["flat_group"] = flat_group
    bpy.context.view_layer.update()
    return o


def link(name, bm, bone="Root", flat_group=None):
    used_mats = sorted({f.material_index for f in bm.faces})
    if not flat_group or len(used_mats) <= 1:
        return _attach_mesh(name, bm, bone=bone, flat_group=flat_group)
    # Multi-material animated/sight group: split cleanly into 1 mesh per material
    # so export_roblox_flat produces crisp multi-material subparts sharing the same prefix!
    first_obj = None
    src_me = bpy.data.meshes.new("_split_src")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(src_me)
    bm.free()
    for mi in used_mats:
        sub = bmesh.new()
        sub.from_mesh(src_me)
        drop = [f for f in sub.faces if f.material_index != mi]
        if drop:
            bmesh.ops.delete(sub, geom=drop, context="FACES")
        tag = MAT_TAG[mi]
        sub_name = f"{name}_{tag}"
        sub_fg = f"{flat_group}_{tag}"
        obj = _attach_mesh(sub_name, sub, bone=bone, flat_group=sub_fg)
        if first_obj is None:
            first_obj = obj
    bpy.data.meshes.remove(src_me)
    return first_obj


# =============================================================================
# SCULPTURAL LOFT PRIMITIVES (TEMPEST-STRIKE GRADE COMPOUND FACETING)
# =============================================================================
def loft_rings_bm(rings, face_role=None, cap0=True, cap1=True, cap0_mat=0, cap1_mat=0, loop=False):
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(vr[0])
    rows = len(vr) if loop else len(vr) - 1
    for row in range(rows):
        a = vr[row]
        b = vr[(row + 1) % len(vr)]
        for j in range(n):
            k = (j + 1) % n
            f = bm.faces.new((a[j], a[k], b[k], b[j]))
            f.material_index = face_role(j, row) if face_role else 0
    if not loop:
        if cap0:
            f = bm.faces.new(list(reversed(vr[0])))
            f.material_index = cap0_mat
        if cap1:
            f = bm.faces.new(vr[-1])
            f.material_index = cap1_mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def hull_bm(stations, face_role=None, cap0_mat=DRK, cap1_mat=DRK, ref_z=0.30):
    """12-sided sculpted armor hull: 6 distinct faceted planes per flank with
    crisp shoulder chamfers, recessed underbelly, and raked station cuts."""
    side = [(0.54, 0.0), (0.82, 0.06), (1.0, 0.25), (0.98, 0.68), (0.82, 0.87), (0.56, 1.0)]
    rings = []
    for x, width, floor, top, rake in stations:
        prof = [(s * width, floor + v * (top - floor)) for s, v in side]
        yz = prof + [(-y, z) for y, z in reversed(prof)]
        rings.append([(x + rake * (z - ref_z), y, z) for y, z in yz])
    return loft_rings_bm(rings, face_role=face_role, cap0_mat=cap0_mat, cap1_mat=cap1_mat)


def facet_blade_bm(hand, stations, face_role=None, cap_mat=SLT, ref_z=0.30):
    """Sculpted 3D cheek-armor blade that sweeps outward to a sharp faceted ridge
    and tapers to narrow machined steel/bronze bevel edges (5-point profile)."""
    rings = []
    for x, inset, crest, low, ridge, top, rake in stations:
        edge = min(0.011, (top - low) * 0.17)
        section = [
            (inset, low),
            (crest - edge, low + edge * 0.55),
            (crest, ridge),
            (crest - edge * 0.72, top - edge * 0.42),
            (inset, top),
        ]
        if hand < 0:
            section = list(reversed(section))
        rings.append([(x + rake * (z - ref_z), hand * y, z) for y, z in section])
    return loft_rings_bm(rings, face_role=face_role, cap0_mat=cap_mat, cap1_mat=cap_mat)


def prism_xz(outline, y0, y1, mat=DRK):
    bm = bmesh.new()
    lo = [bm.verts.new((x, y0, z)) for x, z in outline]
    hi = [bm.verts.new((x, y1, z)) for x, z in outline]
    n = len(outline)
    bm.faces.new(lo)
    bm.faces.new(hi)
    for i in range(n):
        bm.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
    for f in bm.faces:
        f.material_index = mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box_bm(x0, x1, y0, y1, z0, z1, ch=0.0, mat=DRK, bevel_mat=None):
    if bevel_mat is None:
        bevel_mat = mat
    bm = bmesh.new()
    cx, cy, cz = 0.5 * (x0 + x1), 0.5 * (y0 + y1), 0.5 * (z0 + z1)
    sx, sy, sz = (x1 - x0), (y1 - y0), (z1 - z0)
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((cx, cy, cz)) @ Matrix.Diagonal((sx, sy, sz, 1.0)))
    for f in bm.faces:
        f.material_index = mat
    if ch > 0:
        res = bmesh.ops.bevel(
            bm, geom=list(bm.edges), offset=ch, offset_type="OFFSET",
            segments=1, profile=0.5, affect="EDGES", clamp_overlap=True
        )
        for f in res["faces"]:
            f.material_index = bevel_mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def oct_ring_x(x, ry, rz=None, cy=0.0, cz=0.352, n=8, phase=math.pi / 8, rake=0.0):
    if rz is None:
        rz = ry
    pts = []
    for i in range(n):
        ang = phase + 2.0 * math.pi * i / n
        y = cy + ry * math.cos(ang)
        z = cz + rz * math.sin(ang)
        pts.append((x + rake * (z - cz), y, z))
    return pts


def merge_bms(bm_list):
    out = bmesh.new()
    for b in bm_list:
        me = bpy.data.meshes.new("_tmp_m")
        b.to_mesh(me)
        b.free()
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
    bmesh.ops.recalc_face_normals(out, faces=out.faces)
    return out


def bool_cut(obj, cutter_bms):
    bpy.context.view_layer.update()
    for idx, cbm in enumerate(cutter_bms):
        me = bpy.data.meshes.new(f"_cut_{idx}")
        cbm.to_mesh(me)
        cbm.free()
        for m in MATS:
            me.materials.append(m)
        co = bpy.data.objects.new(f"_cut_{idx}", me)
        col.objects.link(co)
        co.matrix_world = Matrix.Identity(4)
        md = obj.modifiers.new(f"cut_{idx}", "BOOLEAN")
        md.operation = "DIFFERENCE"
        md.solver = "EXACT"
        md.object = co
        with bpy.context.temp_override(object=obj, active_object=obj):
            bpy.ops.object.modifier_apply(modifier=md.name)
        bpy.data.objects.remove(co, do_unlink=True)
        bpy.data.meshes.remove(me)
    bm_fix = bmesh.new()
    bm_fix.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm_fix, faces=bm_fix.faces)
    bm_fix.to_mesh(obj.data)
    bm_fix.free()
    set_flat(obj.data)


# =============================================================================
# 1. SCULPTED EXOSKELETON RECEIVER & OPEN REACTOR CORE BAY
# =============================================================================
CORE_CX, CORE_CY, CORE_CZ = 0.455, 0.0, 0.296


def build_receiver():
    # Main sculpted forged-obsidian chassis hull (12-sided tapered armor profile)
    # Edges on 12-gon: 0..4 right (+Y), 5 top, 6..10 left (-Y), 11 bottom
    def rec_role(edge, row):
        if edge in {11, 0, 10}:
            return DRK
        if edge in {4, 6}:
            return STL  # crisp upper machined steel shoulder bevel!
        if edge in {1, 9}:
            return SLT  # sculpted lower chamfer
        return OBS

    rec_stations = [
        (-0.188, 0.058, 0.205, 0.372, -0.16),
        (-0.145, 0.084, 0.178, 0.422, -0.08),
        (0.020,  0.088, 0.172, 0.426,  0.00),
        (0.240,  0.088, 0.172, 0.428,  0.00),
        (0.680,  0.088, 0.172, 0.428,  0.00),
        (0.840,  0.088, 0.182, 0.426,  0.08),
        (0.955,  0.084, 0.205, 0.422,  0.22),
    ]
    rec = link("RF_Receiver", hull_bm(rec_stations, face_role=rec_role))

    # Sculpted lower magwell & trigger guard keel
    def keel_role(edge, row):
        if edge in {11, 0, 10}:
            return DRK
        if edge in {1, 9}:
            return BRZ  # bronze lower keel trim!
        return OBS

    keel_stations = [
        (0.160, 0.044, 0.115, 0.185, -0.10),
        (0.220, 0.048, 0.094, 0.185, -0.06),
        (0.415, 0.052, 0.094, 0.185,  0.08),
        (0.515, 0.072, 0.042, 0.195, -0.14),
        (0.560, 0.082, 0.026, 0.198,  0.00),
        (0.818, 0.080, 0.026, 0.198,  0.04),
        (0.875, 0.068, 0.095, 0.210,  0.22),
        (0.955, 0.055, 0.170, 0.228,  0.24),
    ]
    keel = link("RF_ReceiverKeel", hull_bm(keel_stations, face_role=keel_role, ref_z=0.14))

    # True open cut-through octagonal Reactor Core Bay + magwell slot + trigger relief
    bay_cut = [
        (0.268, 0.205), (0.642, 0.205), (0.692, 0.252), (0.692, 0.340),
        (0.642, 0.386), (0.268, 0.386), (0.218, 0.340), (0.218, 0.252),
    ]
    trig_cut = [(0.236, 0.110), (0.394, 0.110), (0.408, 0.178), (0.220, 0.178)]
    mag_slot = loft_rings_bm([
        [(0.687 + a * 0.132, b * 0.056, z) for a, b in
         [(0.82, -1), (-0.82, -1), (-1, -0.75), (-1, 0.75), (-0.82, 1), (0.82, 1), (1, 0.75), (1, -0.75)]]
        for z in (0.005, 0.120, 0.220)
    ], face_role=lambda e, r: DRK, cap0_mat=DRK, cap1_mat=DRK)

    bool_cut(rec, [prism_xz(bay_cut, -0.14, 0.14, DRK)])
    bool_cut(keel, [prism_xz(trig_cut, -0.12, 0.12, DRK), mag_slot])

    # Swept sculpted Dorsal Spine / Upper Brow (Tempest-Strike style tapered spine!)
    def spine_role(edge, row):
        if edge in {4, 6}:
            return STL
        if edge in {5}:
            return SLT
        if edge in {2, 8}:
            return OBS
        return DRK

    spine_stations = [
        (-0.165, 0.036, 0.390, 0.426, -0.18),
        (-0.100, 0.052, 0.412, 0.456,  0.00),
        (0.110,  0.054, 0.418, 0.464,  0.00),
        (0.245,  0.056, 0.420, 0.468,  0.16),
        (0.715,  0.054, 0.420, 0.468,  0.16),
        (0.920,  0.060, 0.414, 0.460,  0.22),
        (1.120,  0.054, 0.408, 0.454,  0.12),
        (1.480,  0.046, 0.402, 0.448,  0.00),
        (1.625,  0.036, 0.392, 0.436, -0.18),
    ]
    link("RF_DorsalSpine", hull_bm(spine_stations, face_role=spine_role, ref_z=0.43))

    # Sculpted rear shoulder cheek-armor blades (relieved cleanly above FireSelector z=0.305)
    for hand, side in ((1.0, "L"), (-1.0, "R")):
        sh_st = [
            (-0.150, 0.064, 0.088, 0.258, 0.340, 0.402, -0.14),
            (-0.080, 0.070, 0.097, 0.258, 0.352, 0.418, -0.06),
            (0.055,  0.072, 0.097, 0.308, 0.360, 0.418,  0.00),
            (0.175,  0.072, 0.094, 0.312, 0.362, 0.416,  0.14),
            (0.212,  0.068, 0.084, 0.320, 0.362, 0.406,  0.22),
        ]
        def sh_role(edge, row):
            return STL if edge in {2, 3} else (BRZ if edge == 1 else SLT)
        link(f"RF_RearShoulder_{side}", facet_blade_bm(hand, sh_st, face_role=sh_role, ref_z=0.35))

    # Sculpted antique-bronze raked reactor framing collars (front & rear of core bay)
    def brz_role(edge, row):
        return DRK if edge in {11, 0, 10} else BRZ

    front_collar_st = [
        (0.676, 0.089, 0.205, 0.422,  0.12),
        (0.706, 0.096, 0.200, 0.434,  0.14),
        (0.742, 0.096, 0.202, 0.434,  0.16),
        (0.772, 0.088, 0.208, 0.424,  0.18),
    ]
    fc = link("RF_BayCollarFront", hull_bm(front_collar_st, face_role=brz_role))
    bool_cut(fc, [prism_xz(bay_cut, -0.14, 0.14, DRK)])

    rear_collar_st = [
        (0.164, 0.088, 0.220, 0.420, -0.14),
        (0.194, 0.095, 0.214, 0.432, -0.12),
        (0.224, 0.095, 0.214, 0.432, -0.10),
        (0.246, 0.088, 0.220, 0.422, -0.08),
    ]
    rc = link("RF_BayCollarRear", hull_bm(rear_collar_st, face_role=brz_role))
    bool_cut(rc, [prism_xz(bay_cut, -0.14, 0.14, DRK)])

    # Swept bronze stock-receiver coupling collar
    stock_col_st = [
        (-0.208, 0.068, 0.202, 0.402, -0.18),
        (-0.175, 0.088, 0.194, 0.424, -0.14),
        (-0.135, 0.089, 0.192, 0.426, -0.10),
    ]
    link("RF_StockCollar", hull_bm(stock_col_st, face_role=brz_role))

    # Sculpted dorsal reactor status vent & glowing energy bar (visible in hip/ADS peripheral!)
    pad_st = [
        (-0.088, 0.032, 0.448, 0.464, -0.16),
        (-0.064, 0.042, 0.450, 0.474,  0.00),
        (0.012,  0.042, 0.450, 0.474,  0.00),
        (0.032,  0.030, 0.448, 0.464,  0.16),
    ]
    link("RF_RearStatusFrame", hull_bm(pad_st, face_role=lambda e, r: BRZ if e in {3, 4, 5, 6, 7} else OBS, ref_z=0.46))
    glow_st = [
        (-0.068, 0.018, 0.468, 0.476, 0.0),
        (0.010,  0.018, 0.468, 0.476, 0.0),
    ]
    link("RF_RearStatusGlow", hull_bm(glow_st, face_role=lambda e, r: COR, cap0_mat=COR, cap1_mat=COR, ref_z=0.47))

    # Sculpted bronze spine cross-ribs along dorsal spine (raked trapezoidal wedges)
    ribs = []
    for lx in (0.31, 0.41, 0.51, 0.61, 0.71, 0.81):
        ribs.append(hull_bm([
            (lx - 0.022, 0.044, 0.456, 0.472, 0.20),
            (lx - 0.010, 0.048, 0.460, 0.479, 0.20),
            (lx + 0.010, 0.048, 0.460, 0.479, 0.20),
            (lx + 0.022, 0.044, 0.456, 0.472, 0.20),
        ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.47))
    link("RF_SpineRibs", merge_bms(ribs))

    # Recessed glowing upper & lower reactor bay busbars (illuminate cavity when cowls flare!)
    bus_top = hull_bm([
        (0.285, 0.026, 0.376, 0.390, 0.0),
        (0.625, 0.026, 0.376, 0.390, 0.0),
    ], face_role=lambda e, r: COR, cap0_mat=COR, cap1_mat=COR, ref_z=0.383)
    bus_bot = hull_bm([
        (0.285, 0.024, 0.200, 0.214, 0.0),
        (0.625, 0.024, 0.200, 0.214, 0.0),
    ], face_role=lambda e, r: COR, cap0_mat=COR, cap1_mat=COR, ref_z=0.207)
    link("RF_BayBusbars", merge_bms([bus_top, bus_bot]))


# =============================================================================
# 2. ARTICULATED REACTOR CORE + MOVING ARMOR COWLS (5 MOVING ASSEMBLIES!)
# =============================================================================
def build_reactor_core():
    cx, cy, cz = CORE_CX, CORE_CY, CORE_CZ

    # A) CoreCrystal: 16-face closed manifold plasma prism (COR with Riftforge_Plasma scrolling tile!)
    bm_c = bmesh.new()
    n = 6
    rx_tip = 0.088
    rx_mid = 0.042
    ry_mid, rz_mid = 0.048, 0.056
    ry_w, rz_w = 0.056, 0.066

    def ring_x(x, ry, rz, phase=0.0):
        return [bm_c.verts.new((x, cy + ry * math.cos(phase + 2 * math.pi * i / n),
                                cz + rz * math.sin(phase + 2 * math.pi * i / n))) for i in range(n)]

    tip_f = bm_c.verts.new((cx + rx_tip, cy, cz))
    tip_r = bm_c.verts.new((cx - rx_tip, cy, cz))
    rf = ring_x(cx + rx_mid, ry_mid, rz_mid, phase=math.pi / 6)
    rw = ring_x(cx,          ry_w,   rz_w,   phase=0.0)
    rr = ring_x(cx - rx_mid, ry_mid, rz_mid, phase=math.pi / 6)

    for i in range(n):
        j = (i + 1) % n
        for tri in (
            (tip_f, rf[i], rf[j]),
            (rf[i], rw[i], rf[j]), (rf[j], rw[i], rw[j]),
            (rw[i], rr[i], rw[j]), (rw[j], rr[i], rr[j]),
            (tip_r, rr[j], rr[i]),
        ):
            f = bm_c.faces.new(tri)
            f.material_index = COR

    link("RF_CoreCrystal", bm_c, bone="Root", flat_group="CoreCrystal")

    # B) Dual counter-rotating gyroscopic containment rings (closed manifold single-mat solids!)
    def make_gimbal_ring(name, fg, n_sides, r_in, r_out, half_w, tilt_x, tilt_z, mat_idx):
        bm_r = bmesh.new()
        tilt = Matrix.Rotation(math.radians(tilt_x), 3, "X") @ Matrix.Rotation(math.radians(tilt_z), 3, "Z")

        def pt(ang, r, dy):
            p = tilt @ Vector((r * math.cos(ang), dy, r * math.sin(ang)))
            return (cx + p.x, cy + p.y, cz + p.z)

        r_mid = 0.5 * (r_in + r_out)
        prof = [
            (r_in, -half_w * 0.65),
            (r_mid, -half_w),
            (r_out, -half_w * 0.65),
            (r_out, half_w * 0.65),
            (r_mid, half_w),
            (r_in, half_w * 0.65),
        ]
        rings = [[bm_r.verts.new(pt(2 * math.pi * i / n_sides, r, dy)) for i in range(n_sides)] for r, dy in prof]
        m = len(prof)
        for i in range(n_sides):
            j = (i + 1) % n_sides
            for k in range(m):
                k2 = (k + 1) % m
                f = bm_r.faces.new((rings[k][i], rings[k][j], rings[k2][j], rings[k2][i]))
                f.material_index = mat_idx
        link(name, bm_r, bone="Root", flat_group=fg)

    # Outer octagonal bright machined-steel gimbal ring + inner hexagonal antique-bronze ring
    make_gimbal_ring("RF_CoreRingA", "CoreRingA", 8, 0.088, 0.104, 0.011, 28, -18, STL)
    make_gimbal_ring("RF_CoreRingB", "CoreRingB", 6, 0.070, 0.082, 0.009, -32, 22, BRZ)

    # C) Sculpted Articulated Reactor Armor Cowls (closed manifold solids per material!)
    for hand, fg in ((1.0, "CowlLeft"), (-1.0, "CowlRight")):
        upper_st = [
            (0.228, 0.072, 0.095, 0.326, 0.362, 0.398,  0.22),
            (0.320, 0.076, 0.106, 0.320, 0.360, 0.402,  0.14),
            (0.455, 0.076, 0.108, 0.328, 0.364, 0.404,  0.00),
            (0.590, 0.076, 0.105, 0.320, 0.360, 0.402, -0.14),
            (0.682, 0.072, 0.094, 0.326, 0.362, 0.398, -0.22),
        ]
        lower_st = [
            (0.242, 0.072, 0.094, 0.194, 0.226, 0.262, -0.20),
            (0.350, 0.076, 0.104, 0.192, 0.224, 0.268, -0.10),
            (0.455, 0.076, 0.106, 0.192, 0.222, 0.260,  0.00),
            (0.560, 0.076, 0.104, 0.192, 0.224, 0.268,  0.10),
            (0.668, 0.072, 0.094, 0.194, 0.226, 0.262,  0.20),
        ]
        fin_st = [
            (0.355, 0.098, 0.114, 0.344, 0.356, 0.368,  0.12),
            (0.455, 0.102, 0.118, 0.348, 0.360, 0.372,  0.00),
            (0.555, 0.098, 0.114, 0.344, 0.356, 0.368, -0.12),
        ]

        u_bm = facet_blade_bm(hand, upper_st, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.36)
        l_bm = facet_blade_bm(hand, lower_st, face_role=lambda e, r: SLT, cap_mat=SLT, ref_z=0.23)
        f_bm = facet_blade_bm(hand, fin_st,   face_role=lambda e, r: BRZ, cap_mat=BRZ, ref_z=0.36)
        link(f"RF_{fg}_Slt", merge_bms([u_bm, l_bm]), bone="Root", flat_group=fg + "_Slt")
        link(f"RF_{fg}_Brz", f_bm, bone="Root", flat_group=fg + "_Brz")


# =============================================================================
# 3. COMPOUND-TAPERED SCULPTED HANDGUARD & ARMOR SHROUDS
# =============================================================================
def build_handguard():
    # Primary sculpted handguard hull (sweeps smoothly from receiver into tapered nose!)
    # LeftGrip sits flush on underside at z=0.198!
    def hg_role(edge, row):
        if edge in {11, 0, 10}:
            return DRK
        if edge in {4, 6}:
            return STL
        if edge in {2, 8}:
            return OBS
        return SLT

    hg_stations = [
        (0.918, 0.084, 0.206, 0.422,  0.22),
        (0.990, 0.090, 0.198, 0.424,  0.14),
        (1.220, 0.088, 0.198, 0.420,  0.04),
        (1.460, 0.084, 0.198, 0.412, -0.06),
        (1.605, 0.078, 0.214, 0.400, -0.16),
        (1.675, 0.064, 0.252, 0.382, -0.24),
    ]
    hg = link("RF_Handguard", hull_bm(hg_stations, face_role=hg_role, ref_z=0.31))

    # Relieve left side around CharmPoint (0.985, 0.090, 0.225) + angled side plasma slots!
    charm_rel = box_bm(0.942, 1.036, 0.062, 0.130, 0.190, 0.278, ch=0.0, mat=DRK)
    # Raked parallelogram cooling slots along both flanks
    cut_s1 = [(1.075, 0.296), (1.255, 0.304), (1.275, 0.338), (1.095, 0.330)]
    cut_s2 = [(1.360, 0.304), (1.535, 0.312), (1.552, 0.344), (1.377, 0.336)]
    bool_cut(hg, [
        charm_rel,
        prism_xz(cut_s1, 0.056, 0.125, DRK), prism_xz(cut_s1, -0.125, -0.056, DRK),
        prism_xz(cut_s2, 0.056, 0.125, DRK), prism_xz(cut_s2, -0.125, -0.056, DRK),
    ])

    # Recessed glowing scrolling-plasma conduit bars visible through the raked slots
    conduit_st = [
        (1.065, 0.066, 0.292, 0.346, 0.0),
        (1.565, 0.062, 0.302, 0.352, 0.0),
    ]
    link("RF_HgPlasmaConduit", hull_bm(conduit_st, face_role=lambda e, r: COR, cap0_mat=COR, cap1_mat=COR, ref_z=0.32))

    # Sculpted swept cheek-armor blades flanking the lower handguard (keeps charm clear!)
    for hand, side in ((1.0, "L"), (-1.0, "R")):
        blade_st = [
            (1.060, 0.076, 0.096, 0.214, 0.256, 0.292,  0.18),
            (1.240, 0.078, 0.098, 0.212, 0.258, 0.296,  0.08),
            (1.460, 0.074, 0.094, 0.218, 0.264, 0.300, -0.06),
            (1.615, 0.064, 0.080, 0.244, 0.282, 0.306, -0.18),
        ]
        link(f"RF_HgBlade_{side}", facet_blade_bm(
            hand, blade_st, face_role=lambda e, r: STL if e in {1, 3} else SLT, ref_z=0.26
        ))

    # Two raked sculpted antique-bronze locking bands wrapping the handguard
    for idx, bx in enumerate((1.298, 1.465)):
        band_st = [
            (bx - 0.026, 0.086, 0.204, 0.418, 0.26),
            (bx - 0.012, 0.095, 0.198, 0.424, 0.26),
            (bx + 0.012, 0.095, 0.198, 0.424, 0.26),
            (bx + 0.026, 0.086, 0.204, 0.418, 0.26),
        ]
        link(f"RF_HgBand_{idx}", hull_bm(band_st, face_role=lambda e, r: DRK if e in {11, 0, 10} else BRZ, ref_z=0.31))


# =============================================================================
# 4. SCULPTED FLUTED PLASMA SUPPRESSOR & CROWN (SLEEK, COMPOUND-TAPERED!)
# =============================================================================
def build_suppressor():
    cz = 0.352

    # Stepped beveled antique-bronze transition collar
    col_rings = [
        oct_ring_x(1.622, 0.082, 0.086, cz=cz, rake=-0.12),
        oct_ring_x(1.658, 0.092, 0.094, cz=cz, rake=-0.08),
        oct_ring_x(1.728, 0.090, 0.092, cz=cz, rake=0.00),
        oct_ring_x(1.758, 0.078, 0.080, cz=cz, rake=0.08),
    ]
    link("RF_SuppCollar", loft_rings_bm(col_rings, face_role=lambda e, r: BRZ, cap0_mat=DRK, cap1_mat=DRK))

    # Sleek compound-faceted forged-obsidian suppressor shroud tapering to an angled prow
    def supp_role(edge, row):
        if row >= 3:
            return STL if edge in {1, 3, 5, 7} else SLT
        return STL if edge in {1, 3, 5, 7} else OBS

    supp_rings = [
        oct_ring_x(1.738, 0.078, 0.080, cz=cz, rake=0.08),
        oct_ring_x(2.060, 0.077, 0.079, cz=cz, rake=0.04),
        oct_ring_x(2.345, 0.073, 0.076, cz=cz, rake=-0.06),
        oct_ring_x(2.448, 0.066, 0.070, cz=cz, rake=-0.16),
        oct_ring_x(2.502, 0.052, 0.056, cz=cz, rake=-0.22),
    ]
    supp = link("RF_Suppressor", loft_rings_bm(supp_rings, face_role=supp_role, cap0_mat=DRK, cap1_mat=DRK))

    # Deep sculpted lateral plasma-accelerator channels + hollow dark bore + dorsal/ventral vent channels
    flank_l = box_bm(1.790, 2.385, 0.046, 0.125, cz - 0.017, cz + 0.017, ch=0.0, mat=DRK)
    flank_r = box_bm(1.790, 2.385, -0.125, -0.046, cz - 0.017, cz + 0.017, ch=0.0, mat=DRK)
    bore = loft_rings_bm([oct_ring_x(2.360, 0.030, cz=cz), oct_ring_x(2.540, 0.030, cz=cz)],
                         face_role=lambda e, r: DRK, cap0_mat=DRK, cap1_mat=DRK)
    bool_cut(supp, [flank_l, flank_r, bore])

    # Twin deeply recessed scrolling-plasma accelerator rails + inner bright filament
    for side, y0, y1 in (("L", 0.046, 0.063), ("R", -0.063, -0.046)):
        link(f"RF_SuppPlasma_{side}", box_bm(1.805, 2.368, y0, y1, cz - 0.010, cz + 0.010, ch=0.002, mat=COR))

    # Three raked compound-beveled titanium baffle collars bridging the plasma channels
    ribs = []
    for rx in (1.925, 2.095, 2.265):
        ribs.append(loft_rings_bm([
            oct_ring_x(rx - 0.020, 0.078, 0.080, cz=cz, rake=0.22),
            oct_ring_x(rx - 0.010, 0.084, 0.085, cz=cz, rake=0.22),
            oct_ring_x(rx + 0.010, 0.084, 0.085, cz=cz, rake=0.22),
            oct_ring_x(rx + 0.020, 0.078, 0.080, cz=cz, rake=0.22),
        ], face_role=lambda e, r: STL if e in {1, 3, 5, 7} else SLT, cap0_mat=SLT, cap1_mat=SLT))
    link("RF_SuppBaffles", merge_bms(ribs))

    # Sculpted antique-bronze 4-fin muzzle crown ring (sleek, flush with bore!)
    crown_obj = link("RF_SuppCrown", loft_rings_bm([
        oct_ring_x(2.438, 0.048, 0.050, cz=cz, rake=-0.16),
        oct_ring_x(2.495, 0.044, 0.046, cz=cz, rake=-0.20),
        oct_ring_x(2.518, 0.039, 0.041, cz=cz, rake=-0.20),
    ], face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=DRK))
    bool_cut(crown_obj, [loft_rings_bm([oct_ring_x(2.425, 0.030, cz=cz), oct_ring_x(2.535, 0.030, cz=cz)],
                                       face_role=lambda e, r: DRK, cap0_mat=DRK, cap1_mat=DRK)])

    # Flush aerodynamic animated Dorsal & Ventral Accelerator Shrouds (closed single-mat solids!)
    vt_st = [
        (1.770, 0.020, cz + 0.070, cz + 0.082,  0.22),
        (1.835, 0.032, cz + 0.072, cz + 0.090,  0.14),
        (2.260, 0.030, cz + 0.070, cz + 0.086,  0.00),
        (2.365, 0.022, cz + 0.068, cz + 0.080, -0.22),
    ]
    link("RF_VentTop_Slt", hull_bm(vt_st, face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=cz + 0.078),
         bone="Root", flat_group="VentTop_Slt")
    vt_fin = [
        (1.860, 0.014, cz + 0.086, cz + 0.094,  0.12),
        (2.240, 0.014, cz + 0.084, cz + 0.091, -0.12),
    ]
    link("RF_VentTop_Brz", hull_bm(vt_fin, face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=cz + 0.090),
         bone="Root", flat_group="VentTop_Brz")

    vb_st = [
        (1.770, 0.020, cz - 0.082, cz - 0.070, -0.22),
        (1.835, 0.032, cz - 0.090, cz - 0.072, -0.14),
        (2.260, 0.030, cz - 0.086, cz - 0.070,  0.00),
        (2.365, 0.022, cz - 0.080, cz - 0.068,  0.22),
    ]
    link("RF_VentBottom_Slt", hull_bm(vb_st, face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT, ref_z=cz - 0.078),
         bone="Root", flat_group="VentBottom_Slt")
    vb_fin = [
        (1.860, 0.014, cz - 0.094, cz - 0.086, -0.12),
        (2.240, 0.014, cz - 0.091, cz - 0.084,  0.12),
    ]
    link("RF_VentBottom_Brz", hull_bm(vb_fin, face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=cz - 0.090),
         bone="Root", flat_group="VentBottom_Brz")

    # Recessed incandescent plasma core strip revealed underneath when VentTop/VentBottom flare!
    link("RF_VentCore", box_bm(1.825, 2.325, -0.014, 0.014, cz - 0.072, cz + 0.072, ch=0.0, mat=HOT))


# =============================================================================
# 5. SCULPTED SWEPT OPEN-HORNED IRON SIGHTS (*Sight* NAMING, AIMPOINT Z=0.578)
# =============================================================================
def build_sights():
    # AimPoint = (0.154, 0.000, 0.578). Center |y| < 0.038 is 100% open!
    # Swept bronze mounting bridge
    base_st = [
        (0.105, 0.046, 0.456, 0.478,  0.20),
        (0.132, 0.056, 0.460, 0.486,  0.10),
        (0.212, 0.056, 0.460, 0.486, -0.10),
        (0.238, 0.044, 0.456, 0.478, -0.20),
    ]
    link("RF_SightBase", hull_bm(base_st, face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ, ref_z=0.47),
         bone="Root", flat_group="SightBase")

    # Swept sculpted open-horn rear sight blades (raked back into sleek angular horns!)
    rear_bms = []
    for hand in (1.0, -1.0):
        horn_rings = []
        stations = [
            # (z, x_back, x_front, y_in, y_out)
            (0.476, 0.130, 0.214, 0.022, 0.058),
            (0.514, 0.130, 0.206, 0.039, 0.064),
            (0.572, 0.126, 0.194, 0.042, 0.062),
            (0.614, 0.118, 0.176, 0.036, 0.052),
            (0.630, 0.112, 0.156, 0.024, 0.036),
        ]
        for z, xb, xf, yi, yo in stations:
            xm = 0.5 * (xb + xf)
            ring = [
                (xb, hand * yi, z),
                (xb + 0.006, hand * yo, z),
                (xf - 0.006, hand * yo, z),
                (xf, hand * yi, z),
            ]
            if hand < 0:
                ring = list(reversed(ring))
            horn_rings.append(ring)
        rear_bms.append(loft_rings_bm(
            horn_rings,
            face_role=lambda e, r: OBS,
            cap0_mat=OBS, cap1_mat=OBS
        ))
    # Rear bridge floor bar
    rear_bms.append(hull_bm([
        (0.130, 0.044, 0.476, 0.502, 0.0),
        (0.212, 0.044, 0.476, 0.502, 0.0),
    ], face_role=lambda e, r: OBS, cap0_mat=OBS, cap1_mat=OBS, ref_z=0.49))
    link("RF_SightRear", merge_bms(rear_bms), bone="Root", flat_group="SightRear")

    # Crisp micro-lilac sight pips seated cleanly at Z = 0.578
    pips = [
        box_bm(0.120, 0.134, ysgn * 0.050 - 0.004, ysgn * 0.050 + 0.004, 0.574, 0.582, ch=0.001, mat=HOT)
        for ysgn in (-1.0, 1.0)
    ]
    link("RF_SightPips", merge_bms(pips), bone="Root", flat_group="SightPips")

    # Sculpted swept front sight protective wings + crisp center needle post (tip EXACT Z = 0.578!)
    fr_bms = []
    for hand in (1.0, -1.0):
        f_rings = []
        for z, xb, xf, yi, yo in (
            (0.440, 1.546, 1.616, 0.012, 0.042),
            (0.495, 1.552, 1.612, 0.028, 0.046),
            (0.562, 1.560, 1.604, 0.030, 0.042),
            (0.592, 1.568, 1.598, 0.025, 0.034),
        ):
            ring = [
                (xb, hand * yi, z),
                (xb + 0.005, hand * yo, z),
                (xf - 0.005, hand * yo, z),
                (xf, hand * yi, z),
            ]
            if hand < 0:
                ring = list(reversed(ring))
            f_rings.append(ring)
        fr_bms.append(loft_rings_bm(f_rings, face_role=lambda e, r: OBS, cap0_mat=OBS, cap1_mat=OBS))
    fr_bms.append(hull_bm([
        (1.548, 0.032, 0.440, 0.494, 0.0),
        (1.614, 0.032, 0.440, 0.494, 0.0),
    ], face_role=lambda e, r: OBS, cap0_mat=OBS, cap1_mat=OBS, ref_z=0.47))
    # Tapered front post needle (tip EXACT Z = 0.578)
    post_rings = [
        [(1.570, -0.006, 0.490), (1.594, -0.006, 0.490), (1.594, 0.006, 0.490), (1.570, 0.006, 0.490)],
        [(1.575, -0.0045, 0.578), (1.589, -0.0045, 0.578), (1.589, 0.0045, 0.578), (1.575, 0.0045, 0.578)],
    ]
    fr_bms.append(loft_rings_bm(post_rings, face_role=lambda e, r: OBS, cap0_mat=OBS, cap1_mat=OBS))
    link("RF_SightFront", merge_bms(fr_bms), bone="Root", flat_group="SightFront")


# =============================================================================
# 6. COMPOUND-FACETED SKELETONIZED STOCK, ERGONOMIC GRIP & ENERGY-CELL MAG
# =============================================================================
def build_stock():
    # Tapered upper boom (sweeps cleanly from receiver into cheek rest)
    def st_role(edge, row):
        if edge in {4, 6}:
            return STL
        if edge in {5}:
            return GRP  # carbon cheek rest on top!
        if edge in {11, 0, 10}:
            return DRK
        return OBS

    top_st = [
        (-1.052, 0.044, 0.348, 0.412, -0.10),
        (-0.820, 0.050, 0.340, 0.416,  0.00),
        (-0.420, 0.048, 0.332, 0.410,  0.00),
        (-0.150, 0.052, 0.324, 0.402,  0.08),
    ]
    link("RF_StockTop", hull_bm(top_st, face_role=st_role, ref_z=0.37))

    # Sculpted diagonal lower tension strut with bronze collar accent
    low_st = [
        (-1.032, 0.036, -0.056,  0.002,  0.14),
        (-0.620, 0.038,  0.068,  0.132,  0.06),
        (-0.150, 0.046,  0.205,  0.278,  0.00),
    ]
    link("RF_StockStrut", hull_bm(low_st, face_role=lambda e, r: STL if e in {4, 6} else (DRK if e in {11, 0, 10} else SLT), ref_z=0.10))

    # Sculpted diagonal cross-brace connecting upper boom to lower strut (classic Prelude sci-fi skeleton!)
    brace_rings = [
        [(-0.785, -0.024, 0.045), (-0.725, -0.024, 0.065), (-0.725, 0.024, 0.065), (-0.785, 0.024, 0.045)],
        [(-0.675, -0.028, 0.345), (-0.615, -0.028, 0.345), (-0.615, 0.028, 0.345), (-0.675, 0.028, 0.345)],
    ]
    link("RF_StockBrace", loft_rings_bm(brace_rings, face_role=lambda e, r: BRZ if e in {1, 3} else SLT, cap0_mat=BRZ, cap1_mat=BRZ))

    # Ergonomic compound-faceted buttplate with bronze top heel & rubberized toe
    butt_rings = []
    butt_profile = [
        (-0.066, -1.072, -1.000, 0.042),
        (-0.010, -1.102, -0.996, 0.056),
        (0.180,  -1.096, -0.994, 0.058),
        (0.355,  -1.104, -0.998, 0.056),
        (0.414,  -1.070, -1.002, 0.044),
    ]
    for z, xb, xf, w in butt_profile:
        wb = w * 0.72
        butt_rings.append([
            (xb, -wb, z), (xb + 0.018, -w, z), (xf - 0.014, -w, z), (xf, -wb, z),
            (xf,  wb, z), (xf - 0.014,  w, z), (xb + 0.018,  w, z), (xb,  wb, z),
        ])
    link("RF_StockButt", loft_rings_bm(
        butt_rings,
        face_role=lambda e, r: GRP if e == 7 else (BRZ if r == 3 and e in {0, 1, 5, 6} else (STL if e in {1, 5} else OBS)),
        cap0_mat=DRK, cap1_mat=BRZ
    ))


def build_grip():
    # Sculpted multi-station ergonomic pistol grip (carbon-twill palm swell + obsidian spine + bronze heel!)
    grip_stations = [
        # (z, x_back, x_front, width)
        (0.192, -0.024, 0.194, 0.054),
        (0.105, -0.062, 0.162, 0.058),
        (0.015, -0.098, 0.132, 0.060),
        (-0.110, -0.136, 0.096, 0.062),
        (-0.220, -0.168, 0.064, 0.058),
        (-0.278, -0.184, 0.048, 0.056),
    ]
    g_rings = []
    for z, xb, xf, w in grip_stations:
        wb = w * 0.68
        g_rings.append([
            (xb, -wb, z), (xb + 0.024, -w, z), (xf - 0.024, -w, z), (xf, -wb, z),
            (xf,  wb, z), (xf - 0.024,  w, z), (xb + 0.024,  w, z), (xb,  wb, z),
        ])
    link("RF_Grip", loft_rings_bm(
        g_rings,
        face_role=lambda e, r: GRP if e in {1, 5} else (STL if e in {0, 6} else OBS),
        cap0_mat=OBS, cap1_mat=DRK
    ))

    # Sculpted bronze magwell-style grip heel flare
    heel_rings = []
    for z, xb, xf, w in (
        (-0.264, -0.184, 0.050, 0.058),
        (-0.288, -0.194, 0.056, 0.064),
        (-0.312, -0.174, 0.048, 0.056),
    ):
        wb = w * 0.72
        heel_rings.append([
            (xb, -wb, z), (xb + 0.022, -w, z), (xf - 0.022, -w, z), (xf, -wb, z),
            (xf,  wb, z), (xf - 0.022,  w, z), (xb + 0.022,  w, z), (xb,  wb, z),
        ])
    link("RF_GripHeel", loft_rings_bm(heel_rings, face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=DRK))


def build_mag():
    # Sculpted faceted sci-fi Plasma Energy-Cell Magazine (bone = "Mag")
    mag_stations = [
        (0.215, 0.566, 0.808, 0.050),
        (0.065, 0.562, 0.812, 0.053),
        (-0.080, 0.558, 0.816, 0.055),
        (-0.238, 0.554, 0.818, 0.055),
    ]
    m_rings = []
    for z, xb, xf, w in mag_stations:
        wb = w * 0.72
        m_rings.append([
            (xb, -wb, z), (xb + 0.022, -w, z), (xf - 0.022, -w, z), (xf, -wb, z),
            (xf,  wb, z), (xf - 0.022,  w, z), (xb + 0.022,  w, z), (xb,  wb, z),
        ])
    m = link("RF_MagBody", loft_rings_bm(
        m_rings,
        face_role=lambda e, r: STL if e in {0, 2, 4, 6} else OBS,
        cap0_mat=DRK, cap1_mat=DRK
    ), bone="Mag")

    # Recessed energy-cell charge core window on BOTH flanks
    slot_l = box_bm(0.654, 0.720, 0.036, 0.085, -0.210, 0.035, ch=0.0, mat=DRK)
    slot_r = box_bm(0.654, 0.720, -0.085, -0.036, -0.210, 0.035, ch=0.0, mat=DRK)
    bool_cut(m, [slot_l, slot_r])

    # Glowing scrolling-plasma core cylinder seated cleanly inside the window
    link("RF_MagCore", box_bm(0.660, 0.714, -0.045, 0.045, -0.204, 0.028, ch=0.002, mat=COR), bone="Mag")

    # Three crisp sculpted titanium containment ribs bridging across the plasma cell
    mribs = [
        box_bm(0.648, 0.726, -0.056, 0.056, rz - 0.007, rz + 0.007, ch=0.002, mat=SLT, bevel_mat=STL)
        for rz in (-0.155, -0.085, -0.015)
    ]
    link("RF_MagRibs", merge_bms(mribs), bone="Mag")

    # Heavy beveled antique-bronze energy-cell locking baseplate
    base_rings = []
    for z, xb, xf, w in (
        (-0.232, 0.548, 0.824, 0.058),
        (-0.264, 0.538, 0.834, 0.063),
        (-0.302, 0.550, 0.822, 0.056),
    ):
        wb = w * 0.72
        base_rings.append([
            (xb, -wb, z), (xb + 0.024, -w, z), (xf - 0.024, -w, z), (xf, -wb, z),
            (xf,  wb, z), (xf - 0.024,  w, z), (xb + 0.024,  w, z), (xb,  wb, z),
        ])
    link("RF_MagBase", loft_rings_bm(base_rings, face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=DRK), bone="Mag")


# =============================================================================
# BUILD ALL ASSEMBLIES
# =============================================================================
build_receiver()
build_reactor_core()
build_handguard()
build_suppressor()
build_sights()
build_stock()
build_grip()
build_mag()

# Reskin ONLY kept stock micro-hardware (Trigger, FireSelector, CharmLoop).
# ChargingHandle and Bolt are REMOVED completely in v02!
SLOT_SKIN = [M_OBS, M_SLATE, M_DARK, M_STEEL, M_GRIP, M_BRONZE, M_CORE, M_BRONZE]
HARDWARE = ["Phantom_Trigger", "Phantom_FireSelector", "Phantom_CharmLoop"]
REPLACED = [
    "Phantom_Neon", "Phantom_Receiver", "Phantom_Handguard", "Phantom_Rail",
    "Phantom_Suppressor", "Phantom_Grip", "Phantom_Stock", "Phantom_Pins",
    "Phantom_Mag", "Phantom_Sights", "Phantom_ChargingHandle", "Phantom_Bolt",
]
for n in HARDWARE:
    o = bpy.data.objects[n]
    for i, sl in enumerate(o.material_slots):
        if i < len(SLOT_SKIN):
            sl.material = SLOT_SKIN[i]
for n in REPLACED:
    o = bpy.data.objects[n]
    o.hide_render = True
    o.hide_set(True)

for o in col.objects:
    if o.type == "MESH":
        me = o.data
        if not me.uv_layers:
            me.uv_layers.new(name="UVMap")
        set_flat(me)

# Assert exact world centerline alignment on hero parts!
bpy.context.view_layer.update()
for check_prefix in ("RF_SightRear", "RF_SightFront", "RF_Suppressor", "RF_CoreCrystal", "RF_Receiver"):
    ob = next(o for o in col.objects if o.name.startswith(check_prefix))
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    ys = [p.y for p in pts]
    cy_err = 0.5 * (min(ys) + max(ys))
    assert abs(cy_err) < 0.002, f"{ob.name} off-center in Y: {cy_err}"

# =============================================================================
# SAVE BLEND, EXPORT ROBLOX FLAT FBX + MANIFEST, AND RENDER REVIEW SUITE
# =============================================================================
blend_path = os.path.join(OUT_DIR, "Phantom_Riftforge_v02.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_path)

sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import importlib
import export_roblox_flat
importlib.reload(export_roblox_flat)

objs = [o for o in col.objects if o.type == "MESH"]
fbx_path, report = export_roblox_flat.export_flat(objs, OUT_DIR, "Phantom", "Riftforge")

manifest = {
    "gun": "Phantom",
    "item": "Phantom",
    "line": "Riftforge",
    "version": "v02",
    "replaced_stock_prefixes": [
        "Neon", "Receiver", "Handguard", "Rail", "Suppressor",
        "Grip", "Stock", "Pins", "Mag", "Sights", "ChargingHandle", "Bolt",
    ],
    "parts": report,
}
with open(os.path.join(OUT_DIR, "manifest_flat.json"), "w", newline="\n") as f:
    json.dump(manifest, f, indent=2)

# Clean studio render stage for visual review
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 28
sc.cycles.use_denoising = True
sc.view_settings.view_transform = "AgX"
sc.render.resolution_x = 1280
sc.render.resolution_y = 720
sc.render.film_transparent = False
if not sc.world:
    sc.world = bpy.data.worlds.new("RF_World")
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.045, 0.052, 0.075, 1.0)
    bg.inputs[1].default_value = 0.75

# Clean old review lights/cams
for o in list(bpy.data.objects):
    if o.name.startswith("RF_Rev"):
        bpy.data.objects.remove(o, do_unlink=True)


def add_area(name, loc, target, energy, sx, sy, color=(1, 1, 1)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.shape = "RECTANGLE"
    ld.energy = energy
    ld.size = sx
    ld.size_y = sy
    ld.color = color
    lo = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(lo)
    lo.location = loc
    lo.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


add_area("RF_RevKey",  (1.2,  3.2, 3.6), (0.65, 0.0, 0.25), 340, 4.5, 2.2, (1.0, 0.96, 0.92))
add_area("RF_RevRim",  (0.9, -2.6, 2.6), (0.85, 0.0, 0.28), 320, 4.0, 1.6, (0.78, 0.86, 1.0))
add_area("RF_RevFill", (1.6,  2.5, -1.2), (0.75, 0.0, 0.22), 90, 3.0, 2.5, (0.88, 0.72, 1.0))


def snap(name, loc, target, lens=50.0, ortho=None, res=(1280, 720)):
    cd = bpy.data.cameras.new("RF_RevCam_" + name)
    if ortho is not None:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.type = "PERSP"
        cd.lens = lens
    co = bpy.data.objects.new("RF_RevCam_" + name, cd)
    sc.collection.objects.link(co)
    co.location = loc
    co.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    sc.render.resolution_x, sc.render.resolution_y = res
    out = os.path.join(REV_DIR, f"{name}.png")
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(co, do_unlink=True)
    bpy.data.cameras.remove(cd)
    return out


snap("hero",         (3.35,  3.25, 1.55), (0.68, 0.0, 0.24), ortho=3.95)
snap("side",         (0.70,  4.50, 0.24), (0.70, 0.0, 0.24), ortho=4.05)
snap("fp",           (-1.35, 0.58, 0.80), (0.85, 0.0, 0.30), lens=38.0)
snap("ads",          (-0.78, 0.00, 0.578), (1.58, 0.0, 0.578), lens=65.0)
snap("closeup_core", (0.76,  0.88, 0.54), (0.46, 0.0, 0.30), lens=55.0)
snap("closeup_supp", (2.68,  0.98, 0.62), (2.06, 0.0, 0.35), lens=55.0)

# Backface-culled magenta re-import verification of the ACTUAL exported FBX!
tmp_sc = bpy.data.scenes.new("RF_FBX_Check")
win = bpy.context.window or bpy.data.window_managers[0].windows[0]
win.scene = tmp_sc
with bpy.context.temp_override(window=win, scene=tmp_sc):
    bpy.ops.import_scene.fbx(filepath=fbx_path)
imported = [o for o in tmp_sc.objects if o.type == "MESH"]
m_check = bpy.data.materials.new("RF_MagentaBackface")
m_check.use_nodes = True
m_check.use_backface_culling = False
nt = m_check.node_tree
nt.nodes.clear()
out_n = nt.nodes.new("ShaderNodeOutputMaterial")
mix_s = nt.nodes.new("ShaderNodeMixShader")
geo_n = nt.nodes.new("ShaderNodeNewGeometry")
front_s = nt.nodes.new("ShaderNodeBsdfPrincipled")
front_s.inputs["Base Color"].default_value = (0.35, 0.42, 0.55, 1.0)
back_s = nt.nodes.new("ShaderNodeEmission")
back_s.inputs["Color"].default_value = (1.0, 0.0, 0.8, 1.0)
back_s.inputs["Strength"].default_value = 3.0
nt.links.new(geo_n.outputs["Backfacing"], mix_s.inputs["Fac"])
nt.links.new(front_s.outputs["BSDF"], mix_s.inputs[1])
nt.links.new(back_s.outputs["Emission"], mix_s.inputs[2])
nt.links.new(mix_s.outputs["Shader"], out_n.inputs["Surface"])

lo_v = Vector((1e9, 1e9, 1e9))
hi_v = Vector((-1e9, -1e9, -1e9))
for ob in imported:
    ob.data.materials.clear()
    ob.data.materials.append(m_check)
    for c in ob.bound_box:
        p = ob.matrix_world @ Vector(c)
        lo_v = Vector((min(lo_v.x, p.x), min(lo_v.y, p.y), min(lo_v.z, p.z)))
        hi_v = Vector((max(hi_v.x, p.x), max(hi_v.y, p.y), max(hi_v.z, p.z)))

ctr = 0.5 * (lo_v + hi_v)
span = max((hi_v - lo_v).length, 0.1)
tmp_sc.render.engine = "CYCLES"
tmp_sc.cycles.samples = 16
tmp_sc.render.resolution_x, tmp_sc.render.resolution_y = 1024, 576
ld = bpy.data.lights.new("CheckSun", "SUN")
ld.energy = 3.0
lo_o = bpy.data.objects.new("CheckSun", ld)
tmp_sc.collection.objects.link(lo_o)
lo_o.rotation_euler = (math.radians(45), 0, math.radians(35))
cd = bpy.data.cameras.new("CheckCam")
cd.type = "ORTHO"
cd.ortho_scale = span * 1.15
co = bpy.data.objects.new("CheckCam", cd)
tmp_sc.collection.objects.link(co)
co.location = ctr + Vector((span * 0.65, span * 0.9, span * 0.42))
co.rotation_euler = (ctr - co.location).to_track_quat("-Z", "Y").to_euler()
tmp_sc.camera = co
tmp_sc.render.filepath = os.path.join(REV_DIR, "fbx_magenta.png")
with bpy.context.temp_override(window=win, scene=tmp_sc):
    bpy.ops.render.render(write_still=True)

win.scene = sc
bpy.data.scenes.remove(tmp_sc)

total_tris = sum(p["triangles"] for p in report.values())
print(json.dumps({
    "blend": blend_path,
    "fbx": fbx_path,
    "parts_count": len(report),
    "total_tris": total_tris,
    "part_names": sorted(report.keys()),
    "patterns": {k: v["pattern"] for k, v in report.items() if v.get("pattern")},
}, indent=2))
