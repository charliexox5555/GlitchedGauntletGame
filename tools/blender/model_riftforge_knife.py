"""Build Riftfang Knife (Riftforge Legendary Hero Melee — XEROFANG-inspired) in live Blender 5.2 MCP.

Starts from Knife_RemasterV2_v05.blend, preserving RightGrip (0,0,0), Root bone (len 0.08),
BladeBase, BladeTip, and compact tactical dagger envelope (~1.84 studs pommel->tip).

Signature features (matching vault/02 Art/Skins/Riftforge/out/Knife_Riftfang_concept_v01.png):
- Faceted octagonal antique-bronze pommel knuckle-ring (clean open finger hole)
- Compound-faceted obsidian/slate ergonomic tactical handle with carbon-twill inlays
- Cut-through hexagonal antique-bronze crossguard reactor cage holding:
  * SK_Root_CoreCrystal (floating faceted violet plasma prism with Riftforge_Plasma tile)
  * SK_Root_CoreRing    (tilted machined-steel hexagonal counter-rotating gimbal ring)
- Broad angular predator-fang drop-point blade with forged-obsidian machined flats
  (Riftforge_Forged tile), razor brushed-steel lower cutting & tip bevels, recessed
  scrolling plasma lower fuller, and recessed upper dorsal plasma core channel
- 3 Articulated overlapping dorsal spine armor scales (Scale1, Scale2, Scale3 — each
  closed-manifold slate wedge + bronze trim collar) that ripple open base->tip!
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
STOCK_BLEND = os.path.join(ROOT, "art-source", "weapons", "RemasterV2", "Knife", "Knife_RemasterV2_v05.blend")
OUT_DIR = os.path.join(ROOT, "art-source", "weapons", "Skins", "Riftforge", "Knife", "v01")
REV_DIR = os.path.join(OUT_DIR, "review")
os.makedirs(REV_DIR, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=STOCK_BLEND)

for o in list(bpy.data.objects):
    if o.name.startswith("Range") or o.name.startswith("Target"):
        bpy.data.objects.remove(o, do_unlink=True)

bpy.context.view_layer.update()
rig = bpy.data.objects["Knife_Rig"]

COL_NAME = "Riftforge Knife v01"
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


def make_mat(name, hexcol, metallic=0.0, roughness=0.40, emit=0.0, tile_png=None):
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
    if tile_png and os.path.exists(tile_png):
        tex_coord = nt.nodes.new("ShaderNodeTexCoord")
        mapping = nt.nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (5.0, 5.0, 5.0)
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
M_SLATE  = make_mat("RF_Slate",          "3F4B62", metallic=0.72, roughness=0.30)
M_DARK   = make_mat("RF_Dark",           "0F1219", metallic=0.14, roughness=0.58)
M_STEEL  = make_mat("RF_Steel",          "92A4BF", metallic=0.92, roughness=0.18)
M_BRONZE = make_mat("RF_Bronze",         "C99A50", metallic=0.92, roughness=0.23)
M_GRIP   = make_mat("RF_GripCarbon",     "1E212B", metallic=0.06, roughness=0.68,
                    tile_png=os.path.join(TILES_DIR, "Payload_Carbon.png"))
M_CORE   = make_mat("RF_PlasmaCore",     "B438FF", metallic=0.0,  roughness=0.16, emit=2.9,
                    tile_png=os.path.join(TILES_DIR, "Riftforge_Plasma.png"))
M_HOT    = make_mat("RF_PlasmaHot",      "F0CCFF", metallic=0.0,  roughness=0.10, emit=3.6)

MATS = [M_OBS, M_SLATE, M_DARK, M_STEEL, M_BRONZE, M_GRIP, M_CORE, M_HOT]
OBS, SLT, DRK, STL, BRZ, GRP, COR, HOT = range(8)


def set_flat(mesh):
    mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))
    mesh.update()


def link(name, bm, bone="Root", flat_group=None):
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


def hull_bm(stations, face_role=None, cap0_mat=DRK, cap1_mat=DRK, ref_z=0.0):
    side = [(0.52, 0.0), (0.82, 0.08), (1.0, 0.28), (0.98, 0.72), (0.82, 0.90), (0.54, 1.0)]
    rings = []
    for x, width, floor, top, rake in stations:
        prof = [(s * width, floor + v * (top - floor)) for s, v in side]
        yz = prof + [(-y, z) for y, z in reversed(prof)]
        rings.append([(x + rake * (z - ref_z), y, z) for y, z in yz])
    return loft_rings_bm(rings, face_role=face_role, cap0_mat=cap0_mat, cap1_mat=cap1_mat)


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
# 1. FACETED ANTIQUE-BRONZE POMMEL KNUCKLE-RING + ERGONOMIC TACTICAL HANDLE
# =============================================================================
def build_handle_and_pommel():
    # Octagonal beveled antique-bronze knuckle-ring (center X=-0.425, Z=0.0, plane XZ)
    cx, cz = -0.428, 0.0
    n = 8
    r_in, r_out, hw = 0.068, 0.104, 0.025
    r_mid = 0.5 * (r_in + r_out)
    prof = [
        (r_in, -hw * 0.65),
        (r_mid, -hw),
        (r_out, -hw * 0.65),
        (r_out, hw * 0.65),
        (r_mid, hw),
        (r_in, hw * 0.65),
    ]
    bm_p = bmesh.new()
    rings = []
    for r, dy in prof:
        ring = []
        for i in range(n):
            ang = math.pi / 8 + 2.0 * math.pi * i / n
            ring.append(bm_p.verts.new((cx + r * math.cos(ang), dy, cz + r * math.sin(ang))))
        rings.append(ring)
    m = len(prof)
    for i in range(n):
        j = (i + 1) % n
        for k in range(m):
            k2 = (k + 1) % m
            f = bm_p.faces.new((rings[k][i], rings[k][j], rings[k2][j], rings[k2][i]))
            f.material_index = BRZ
    link("RFK_PommelRing", bm_p)

    # Sculpted ergonomic tactical handle (palm swell at RightGrip X=0.0, contoured finger arch!)
    def grip_role(edge, row):
        if edge in {4, 6}:
            return STL  # crisp upper machined steel spine bevels
        if edge in {1, 9}:
            return STL  # crisp lower edge bevels
        if edge in {5, 11}:
            return SLT
        return OBS

    handle_st = [
        (-0.345, 0.032, -0.048,  0.048,  0.08),
        (-0.270, 0.038, -0.056,  0.054,  0.04),
        (-0.140, 0.044, -0.064,  0.060,  0.00),
        (0.000,  0.048, -0.068,  0.066,  0.00),  # RightGrip center!
        (0.130,  0.044, -0.062,  0.058, -0.06),
        (0.245,  0.042, -0.066,  0.064, -0.10),
    ]
    link("RFK_Handle", hull_bm(handle_st, face_role=grip_role))

    # Raised sculpted Carbon-Twill tactile grip inlay scales on BOTH flanks!
    for hand, side in ((1.0, "L"), (-1.0, "R")):
        inlay_rings = []
        for x, z0, z1, y_in, y_out in (
            (-0.265, -0.036, 0.034, 0.030, 0.042),
            (-0.140, -0.044, 0.040, 0.036, 0.050),
            (0.000,  -0.048, 0.044, 0.040, 0.054),
            (0.115,  -0.042, 0.038, 0.036, 0.049),
            (0.190,  -0.034, 0.032, 0.032, 0.044),
        ):
            r = [
                (x, hand * y_in, z0),
                (x, hand * y_out, z0 + 0.008),
                (x, hand * y_out, z1 - 0.008),
                (x, hand * y_in, z1),
            ]
            if hand < 0:
                r = list(reversed(r))
            inlay_rings.append(r)
        link(f"RFK_GripInlay_{side}", loft_rings_bm(inlay_rings, face_role=lambda e, r: GRP, cap0_mat=GRP, cap1_mat=GRP))


# =============================================================================
# 2. HEXAGONAL ANTIQUE-BRONZE CROSSGUARD REACTOR CAGE + FLOATING CORE CRYSTAL
# =============================================================================
GUARD_CX, GUARD_CY, GUARD_CZ = 0.330, 0.0, 0.0


def build_crossguard_and_core():
    cx, cy, cz = GUARD_CX, GUARD_CY, GUARD_CZ

    # Sharp diamond-hexagonal sculpted bronze crossguard frame (sleek Y=+-0.046, crisp peaks!)
    guard_st = [
        (0.225, 0.036, -0.068,  0.068,  0.00),
        (0.280, 0.045, -0.122,  0.122,  0.00),
        (0.330, 0.048, -0.152,  0.152,  0.00),
        (0.380, 0.045, -0.122,  0.122,  0.00),
        (0.435, 0.036, -0.072,  0.072,  0.00),
    ]
    guard = link("RFK_Crossguard", hull_bm(
        guard_st,
        face_role=lambda e, r: BRZ if e in {1, 2, 3, 4, 6, 7, 8, 9} else OBS,
        cap0_mat=OBS, cap1_mat=OBS
    ))

    # True open hexagonal cut-through reactor eye right through Y!
    eye_cut = [
        (cx - 0.072, cz),
        (cx - 0.036, cz + 0.066),
        (cx + 0.036, cz + 0.066),
        (cx + 0.072, cz),
        (cx + 0.036, cz - 0.066),
        (cx - 0.036, cz - 0.066),
    ]
    bool_cut(guard, [prism_xz(eye_cut, -0.10, 0.10, DRK)])

    # Floating 16-face octahedral/prismatic plasma crystal (closed manifold, flat_group=CoreCrystal!)
    bm_c = bmesh.new()
    rx, ry, rz = 0.048, 0.036, 0.048
    v_xp = bm_c.verts.new((cx + rx, cy, cz))
    v_xm = bm_c.verts.new((cx - rx, cy, cz))
    v_yp = bm_c.verts.new((cx, cy + ry, cz))
    v_ym = bm_c.verts.new((cx, cy - ry, cz))
    v_zp = bm_c.verts.new((cx, cy, cz + rz))
    v_zm = bm_c.verts.new((cx, cy, cz - rz))
    for tri in (
        (v_zp, v_xp, v_yp), (v_zp, v_yp, v_xm), (v_zp, v_xm, v_ym), (v_zp, v_ym, v_xp),
        (v_zm, v_yp, v_xp), (v_zm, v_xm, v_yp), (v_zm, v_ym, v_xm), (v_zm, v_xp, v_ym),
    ):
        f = bm_c.faces.new(tri)
        f.material_index = COR
    link("RFK_CoreCrystal", bm_c, bone="Root", flat_group="CoreCrystal")

    # Micro tilted machined-steel hexagonal gimbal ring orbiting CoreCrystal (flat_group=CoreRing!)
    bm_r = bmesh.new()
    n = 6
    r_in, r_out, hw = 0.052, 0.061, 0.0065
    r_mid = 0.5 * (r_in + r_out)
    tilt = Matrix.Rotation(math.radians(28), 3, "X") @ Matrix.Rotation(math.radians(-18), 3, "Z")
    prof = [
        (r_in, -hw * 0.6), (r_mid, -hw), (r_out, -hw * 0.6),
        (r_out, hw * 0.6), (r_mid, hw), (r_in, hw * 0.6),
    ]
    rings = []
    for r, dy in prof:
        ring = []
        for i in range(n):
            ang = 2.0 * math.pi * i / n
            p = tilt @ Vector((r * math.cos(ang), dy, r * math.sin(ang)))
            ring.append(bm_r.verts.new((cx + p.x, cy + p.y, cz + p.z)))
        rings.append(ring)
    m = len(prof)
    for i in range(n):
        j = (i + 1) % n
        for k in range(m):
            k2 = (k + 1) % m
            f = bm_r.faces.new((rings[k][i], rings[k][j], rings[k2][j], rings[k2][i]))
            f.material_index = STL
    link("RFK_CoreRing", bm_r, bone="Root", flat_group="CoreRing")


# =============================================================================
# 3. BROAD PREDATOR-FANG TACTICAL BLADE + RECESSED PLASMA CHANNELS
# =============================================================================
def build_blade():
    # Sculpted 10-point compound-faceted blade cross-section:
    # - Razor machined-steel lower cutting bevel (edges 0, 9 -> sharp bottom edge)
    # - Broad forged-obsidian primary flats (edges 1, 2, 7, 8 -> Riftforge_Forged tile!)
    # - Stepped slate upper spine shoulder (edges 3, 6)
    # - Flat recessed dorsal channel bed (edges 4, 5)
    # Stations: (x, z_edge, z_bevel, z_mid, z_spine, y_flat, y_spine)
    stations = [
        (0.415, -0.072, -0.056,  0.000,  0.072, 0.025, 0.018),
        (0.495, -0.104, -0.074, -0.002,  0.080, 0.026, 0.019),  # aggressive choil fang tooth!
        (0.560, -0.086, -0.058,  0.000,  0.082, 0.026, 0.019),
        (0.760, -0.098, -0.066,  0.002,  0.082, 0.025, 0.018),
        (0.980, -0.092, -0.058,  0.006,  0.076, 0.022, 0.016),
        (1.140, -0.068, -0.036,  0.012,  0.058, 0.016, 0.011),
        (1.265, -0.028, -0.008,  0.016,  0.034, 0.009, 0.006),
        (1.345,  0.014,  0.015,  0.016,  0.017, 0.0025, 0.002),  # crisp razor diamond tip!
    ]
    rings = []
    for x, ze, zb, zm, zs, yf, ys in stations:
        rings.append([
            (x,  0.000, ze),         # 0: razor lower cutting edge
            (x,  yf * 0.55, zb),     # 1: +Y cutting bevel shoulder
            (x,  yf,        zm),     # 2: +Y flat crest
            (x,  yf * 0.85, zs - 0.014),  # 3: +Y upper shoulder
            (x,  ys,        zs),     # 4: +Y spine corner
            (x, -ys,        zs),     # 5: -Y spine corner
            (x, -yf * 0.85, zs - 0.014),  # 6: -Y upper shoulder
            (x, -yf,        zm),     # 7: -Y flat crest
            (x, -yf * 0.55, zb),     # 8: -Y cutting bevel shoulder
        ])

    def blade_role(edge, row):
        # Razor steel cutting bevels (edges 0 and 8) + steel tip sweep (row >= 5)
        if edge in {0, 8} or row >= 5:
            return STL
        if edge in {4}:
            return DRK  # dark spine bed under plasma channel
        if edge in {3, 5}:
            return SLT
        return OBS  # forged-obsidian main blade flats!

    link("RFK_Blade", loft_rings_bm(rings, face_role=blade_role, cap0_mat=OBS, cap1_mat=STL))

    # Recessed glowing lower plasma fuller bar running cleanly along both blade flats!
    fuller_rings = []
    for x, z0, z1, yw in (
        (0.460, -0.044, -0.028, 0.0275),
        (0.760, -0.042, -0.025, 0.0268),
        (1.010, -0.030, -0.014, 0.0225),
        (1.135, -0.012, -0.002, 0.0155),
    ):
        zm = 0.5 * (z0 + z1)
        fuller_rings.append([
            (x, -yw * 0.8, z0), (x,  yw * 0.8, z0),
            (x,  yw,       zm), (x,  yw * 0.8, z1),
            (x, -yw * 0.8, z1), (x, -yw,       zm),
        ])
    link("RFK_BladeFullerPlasma", loft_rings_bm(fuller_rings, face_role=lambda e, r: COR, cap0_mat=COR, cap1_mat=COR))

    # Glowing upper dorsal plasma spine core (boldly visible beneath the 3 lifted sawtooth scales!)
    spine_rings = []
    for x, z0, z1, yw in (
        (0.430, 0.056, 0.106, 0.0235),
        (0.650, 0.060, 0.108, 0.0225),
        (0.860, 0.056, 0.102, 0.0205),
        (1.035, 0.044, 0.082, 0.0160),
        (1.095, 0.038, 0.062, 0.0105),
    ):
        zm = 0.5 * (z0 + z1)
        spine_rings.append([
            (x, -yw * 0.78, z0), (x,  yw * 0.78, z0),
            (x,  yw,        zm), (x,  yw * 0.74, z1),
            (x, -yw * 0.74, z1), (x, -yw,        zm),
        ])
    link("RFK_SpinePlasmaCore", loft_rings_bm(spine_rings, face_role=lambda e, r: HOT if e in {2, 3, 4} else COR, cap0_mat=COR, cap1_mat=HOT))


# =============================================================================
# 4. THREE ARTICULATED SEGMENTED DORSAL SPINE SCALES (Scale1, Scale2, Scale3!)
# =============================================================================
def build_spine_scales():
    # Aggressive raked XEROFANG sawtooth scales lifted slightly above the glowing plasma channel
    # with crisp separation notches between Scale1 -> Scale2 -> Scale3!
    scale_specs = [
        ("Scale1", 0.448, 0.628, 0.094, 0.096, 0.156, 0.136, 0.027),
        ("Scale2", 0.645, 0.835, 0.092, 0.090, 0.154, 0.130, 0.026),
        ("Scale3", 0.850, 1.055, 0.084, 0.068, 0.142, 0.102, 0.024),
    ]
    for fg, xr, xf, zlr, zlf, zhr, zhf, w in scale_specs:
        xm = 0.5 * (xr + xf)
        zlm = 0.5 * (zlr + zlf)
        zhm = 0.5 * (zhr + zhf) + 0.010  # sharp predator sawtooth crest!
        s_rings = []
        for x, zl, zh, rw, rake in (
            (xr - 0.014, zlr, zhr, w * 0.72, -0.45),
            (xr + 0.018, zlr, zhr + 0.008, w, -0.45),
            (xm + 0.010, zlm, zhm, w * 0.94, -0.35),
            (xf - 0.012, zlf, zhf, w * 0.78, -0.25),
            (xf + 0.014, zlf, zlf + 0.016, w * 0.42, -0.15),
        ):
            zm = zl + 0.58 * (zh - zl)
            s_rings.append([
                (x + rake * (zl - zlm), -rw * 0.78, zl),
                (x + rake * (zl - zlm),  rw * 0.78, zl),
                (x + rake * (zm - zlm),  rw,        zm),
                (x + rake * (zh - zlm),  rw * 0.42, zh),
                (x + rake * (zh - zlm), -rw * 0.42, zh),
                (x + rake * (zm - zlm), -rw,        zm),
            ])
        link(f"RFK_{fg}_Slt", loft_rings_bm(s_rings, face_role=lambda e, r: SLT, cap0_mat=SLT, cap1_mat=SLT),
             bone="Root", flat_group=fg + "_Slt")

        # Antique-bronze beveled lower collar rim framing the bright plasma slit!
        b_rings = []
        for x, zl, rw, rake in (
            (xr - 0.012, zlr - 0.005, w * 0.84, -0.45),
            (xr + 0.018, zlr - 0.005, w * 1.06, -0.45),
            (xf - 0.010, zlf - 0.005, w * 0.88, -0.25),
            (xf + 0.012, zlf - 0.002, w * 0.50, -0.15),
        ):
            zh = zl + 0.013
            b_rings.append([
                (x + rake * (zl - zlm), -rw * 0.82, zl),
                (x + rake * (zl - zlm),  rw * 0.82, zl),
                (x + rake * (zh - zlm),  rw,        zh),
                (x + rake * (zh - zlm), -rw,        zh),
            ])
        link(f"RFK_{fg}_Brz", loft_rings_bm(b_rings, face_role=lambda e, r: BRZ, cap0_mat=BRZ, cap1_mat=BRZ),
             bone="Root", flat_group=fg + "_Brz")


# =============================================================================
# BUILD ALL ASSEMBLIES + HIDE STOCK KNIFE
# =============================================================================
build_handle_and_pommel()
build_crossguard_and_core()
build_blade()
build_spine_scales()

for n in ("Knife_Blade", "Knife_Hilt", "Knife_Neon"):
    if n in bpy.data.objects:
        bpy.data.objects[n].hide_render = True
        bpy.data.objects[n].hide_set(True)

for o in col.objects:
    if o.type == "MESH":
        me = o.data
        if not me.uv_layers:
            me.uv_layers.new(name="UVMap")
        set_flat(me)

# Centerline assertion on hero parts
bpy.context.view_layer.update()
for check_name in ("RFK_Blade", "RFK_Crossguard", "RFK_CoreCrystal", "RFK_Handle", "RFK_PommelRing"):
    ob = bpy.data.objects[check_name]
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    ys = [p.y for p in pts]
    cy_err = 0.5 * (min(ys) + max(ys))
    assert abs(cy_err) < 0.002, f"{check_name} off-center in Y: {cy_err}"

# Save blend + export flat FBX + manifest
blend_path = os.path.join(OUT_DIR, "Knife_Riftforge_v01.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_path)

sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import importlib
import export_roblox_flat
importlib.reload(export_roblox_flat)

objs = [o for o in col.objects if o.type == "MESH"]
fbx_path, report = export_roblox_flat.export_flat(objs, OUT_DIR, "Knife", "Riftforge")

manifest = {
    "gun": "Knife",
    "item": "Knife",
    "line": "Riftforge",
    "version": "v01",
    "replaced_stock_prefixes": ["Blade", "Hilt", "Neon"],
    "parts": report,
}
with open(os.path.join(OUT_DIR, "manifest_flat.json"), "w", newline="\n") as f:
    json.dump(manifest, f, indent=2)

# Studio lighting & review renders + Locker icon + Shop portrait!
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 28
sc.cycles.use_denoising = True
sc.view_settings.view_transform = "AgX"
sc.render.film_transparent = False
if not sc.world:
    sc.world = bpy.data.worlds.new("RFK_World")
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.045, 0.052, 0.075, 1.0)
    bg.inputs[1].default_value = 0.80

for o in list(bpy.data.objects):
    if o.name.startswith("RFK_Rev"):
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


add_area("RFK_RevKey",  (0.6,  2.2, 2.2), (0.42, 0.0, 0.02), 180, 3.0, 1.6, (1.0, 0.96, 0.92))
add_area("RFK_RevRim",  (0.5, -2.0, 1.8), (0.50, 0.0, 0.02), 190, 2.8, 1.2, (0.78, 0.88, 1.0))
add_area("RFK_RevFill", (0.8,  1.8, -1.0), (0.42, 0.0, 0.0),  65, 2.2, 1.8, (0.88, 0.72, 1.0))


def snap(name, loc, target, lens=50.0, ortho=None, res=(1280, 720), transparent=False):
    sc.render.film_transparent = transparent
    sc.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    cd = bpy.data.cameras.new("RFK_RevCam_" + name)
    if ortho is not None:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.type = "PERSP"
        cd.lens = lens
    co = bpy.data.objects.new("RFK_RevCam_" + name, cd)
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


snap("hero",          (1.65,  1.85, 0.88), (0.42, 0.0, 0.01), ortho=2.15)
snap("side",          (0.42,  2.60, 0.01), (0.42, 0.0, 0.01), ortho=2.15)
snap("closeup_guard", (0.55,  0.65, 0.25), (0.33, 0.0, 0.00), lens=55.0)
snap("closeup_scales",(0.95,  0.72, 0.36), (0.72, 0.0, 0.06), lens=55.0)

# Locker Icon (512x512 transparent, crisp diagonal predator angle!)
snap("Knife_Riftforge_v01_icon",     (1.05, 2.20, 0.42), (0.42, 0.0, 0.01), ortho=2.12, res=(512, 512), transparent=True)
# Shop Portrait (512x512 rich dark obsidian-violet backdrop!)
if bg:
    bg.inputs[0].default_value = (0.042, 0.024, 0.075, 1.0)
    bg.inputs[1].default_value = 0.85
snap("Knife_Riftforge_v01_portrait", (1.42, 1.75, 0.72), (0.44, 0.0, 0.01), ortho=1.98, res=(512, 512), transparent=False)

# Backface ray-cast check on ACTUAL exported FBX!
tmp_sc = bpy.data.scenes.new("RFK_FBX_Check")
win = bpy.context.window or bpy.data.window_managers[0].windows[0]
win.scene = tmp_sc
with bpy.context.temp_override(window=win, scene=tmp_sc):
    bpy.ops.import_scene.fbx(filepath=fbx_path)
deps = bpy.context.evaluated_depsgraph_get()
cam = Vector((1.65, 1.85, 0.88))
backfaces = set()
for xi in range(-6, 15):
    for zi in range(-3, 4):
        tgt = Vector((xi * 0.1, 0.0, zi * 0.05))
        d = (tgt - cam).normalized()
        ok, loc, n, idx, obj, mat = tmp_sc.ray_cast(deps, cam, d)
        if ok and n.dot(d) > 0:
            backfaces.add(obj.name)
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
    "flipped": export_roblox_flat.FLIPPED,
    "open_flipped": export_roblox_flat.OPEN_FLIPPED,
    "ray_backfaces": sorted(backfaces),
}, indent=2))
