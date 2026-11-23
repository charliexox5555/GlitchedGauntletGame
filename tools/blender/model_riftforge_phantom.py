"""Build Riftforge Phantom (First Legendary Bundle Hero) in live Blender 5.2 MCP.

Starts from stock Phantom_RemasterV2_v05.blend, preserving exact rig bones,
grips, muzzle, eject, charm point, AimPoint (0.154, 0, 0.578) and animated
stock controls (ChargingHandle, Bolt, Trigger, FireSelector, CharmLoop).

Signature features:
- Cut-through mid-receiver Reactor Core Bay framed by bronze collars
- Floating faceted violet octahedral crystal (flat_group=CoreCrystal)
- Counter-rotating faceted hexagonal containment ring (flat_group=CoreRing)
- Articulated upper & lower containment claws + bronze tips (flat_group=ProngUpper/Lower*)
- Forged slate-titanium faceted handguard with angled bronze armor clamp bands
- Sleek tapered octagonal plasma suppressor with recessed lateral violet
  accelerator rails, bronze root & muzzle bore collars, slate baffle bridges,
  and flush-seated animated top/bottom heat-vent louvers (flat_group=VentTop/VentBottom)
- Sculpted open hexagonal-arch iron sight (*Sight* naming, AimPoint Z=0.578)
- Ribbed energy-cell magazine with recessed violet charge core & bronze base (bone: Mag)
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

assert os.getpid() == 54904, f"Expected live Blender PID 54904, got {os.getpid()}"

ROOT = r"c:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
STOCK_BLEND = os.path.join(ROOT, "art-source", "weapons", "RemasterV2", "Phantom", "Phantom_RemasterV2_v05.blend")
OUT_DIR = os.path.join(ROOT, "art-source", "weapons", "Skins", "Riftforge", "Phantom", "v01")
REV_DIR = os.path.join(OUT_DIR, "review")
os.makedirs(REV_DIR, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=STOCK_BLEND)

# Remove range props if present
for o in list(bpy.data.objects):
    if o.name.startswith("Range") or o.name.startswith("Target"):
        bpy.data.objects.remove(o, do_unlink=True)

bpy.context.view_layer.update()
rig = bpy.data.objects["Phantom_Rig"]

# Copy exact bone parent inverse matrices from stock meshes so every new part
# has world transform == Identity (0.000000 drift on Root and Mag!).
BONE_INV = {
    "Root": bpy.data.objects["Phantom_Receiver"].matrix_parent_inverse.copy(),
    "Mag": bpy.data.objects["Phantom_Mag"].matrix_parent_inverse.copy(),
}

COL_NAME = "Riftforge Phantom"
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


def make_mat(name, hexcol, metallic=0.0, roughness=0.45, emit=0.0):
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
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    m["mf_hex"] = hexcol.lstrip("#").upper()
    return m


# Material Palette (Riftforge Legendary)
M_OBSIDIAN = make_mat("RF_Obsidian", "191C24", metallic=0.18, roughness=0.44)
M_SLATE    = make_mat("RF_Slate",    "414A5C", metallic=0.75, roughness=0.34)
M_DARK     = make_mat("RF_Dark",     "101218", metallic=0.10, roughness=0.62)
M_STEEL    = make_mat("RF_Steel",    "646F85", metallic=0.88, roughness=0.26)
M_BRONZE   = make_mat("RF_Bronze",   "C29852", metallic=0.92, roughness=0.25)
M_GRIP     = make_mat("RF_Grip",     "1E2129", metallic=0.05, roughness=0.72)
M_CORE     = make_mat("RF_Core",     "B438FF", metallic=0.0,  roughness=0.18, emit=2.6)
M_HOT      = make_mat("RF_Hot",      "E8B2FF", metallic=0.0,  roughness=0.12, emit=3.0)

MATS = [M_OBSIDIAN, M_SLATE, M_DARK, M_STEEL, M_BRONZE, M_GRIP, M_CORE, M_HOT]
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


def solid_plate(outline, y0, y1, ch=0.005, mat=OBS, bevel_mat=STL, open_inner=False):
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
        res = bmesh.ops.bevel(
            bm, geom=list(top.edges), offset=ch, offset_type="OFFSET",
            segments=1, profile=0.5, affect="EDGES", clamp_overlap=True
        )
        for f in res["faces"]:
            f.material_index = bevel_mat
    if open_inner:
        inner = [f for f in bm.faces if all(abs(v.co.y - y0) < 1e-6 for v in f.verts)]
        bmesh.ops.delete(bm, geom=inner, context="FACES_ONLY")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def solid_plate_x(outline_yz, x0, x1, ch=0.004, mat=OBS, bevel_mat=STL):
    """Extrude a (y, z) polygon along X from x0 to x1 with beveled ends."""
    bm = bmesh.new()
    lo = [bm.verts.new((x0, y, z)) for y, z in outline_yz]
    hi = [bm.verts.new((x1, y, z)) for y, z in outline_yz]
    n = len(outline_yz)
    f0 = bm.faces.new(lo)
    f1 = bm.faces.new(hi)
    for i in range(n):
        bm.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
    for f in bm.faces:
        f.material_index = mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if ch > 0:
        edges = list(set(list(f0.edges) + list(f1.edges)))
        res = bmesh.ops.bevel(
            bm, geom=edges, offset=ch, offset_type="OFFSET",
            segments=1, profile=0.5, affect="EDGES", clamp_overlap=True
        )
        for f in res["faces"]:
            f.material_index = bevel_mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box_bm(x0, x1, y0, y1, z0, z1, ch=0.003, mat=OBS, bevel_mat=None):
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


def loft_rings(rings, mat=OBS, cap0=True, cap1=True, cap_mat=None):
    if cap_mat is None:
        cap_mat = mat
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(vr[0])
    for k in range(len(vr) - 1):
        for i in range(n):
            f = bm.faces.new((vr[k][i], vr[k][(i + 1) % n], vr[k + 1][(i + 1) % n], vr[k + 1][i]))
            f.material_index = mat
    if cap0:
        f = bm.faces.new(vr[0])
        f.material_index = cap_mat
    if cap1:
        f = bm.faces.new(list(reversed(vr[-1])))
        f.material_index = cap_mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def merge_bms(bm_list):
    out = bmesh.new()
    for b in bm_list:
        me = bpy.data.meshes.new("_tmp_m")
        b.to_mesh(me); b.free()
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
    bmesh.ops.recalc_face_normals(out, faces=out.faces)
    return out


def mirror_y(obj, merge=False):
    md = obj.modifiers.new("mir", "MIRROR")
    md.use_axis = (False, True, False)
    md.use_mirror_merge = merge
    md.merge_threshold = 1e-5
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_apply(modifier=md.name)


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
    set_flat(obj.data)


def oct_ring_x(x, r, cy=0.0, cz=0.352, n=8, phase=math.pi / 8):
    return [(x, cy + r * math.cos(phase + 2 * math.pi * i / n), cz + r * math.sin(phase + 2 * math.pi * i / n)) for i in range(n)]


# =============================================================================
# 1. RECEIVER & OPEN CUT-THROUGH REACTOR CORE BAY
# =============================================================================
CORE_CX, CORE_CY, CORE_CZ = 0.455, 0.0, 0.296


def build_receiver():
    outline = [
        (-0.180, 0.395), (-0.140, 0.428), (0.930, 0.428), (0.938, 0.408),
        (0.938, 0.215), (0.850, 0.195), (0.842, 0.028), (0.535, 0.028),
        (0.525, 0.165), (0.430, 0.175), (0.400, 0.095), (0.215, 0.095),
        (0.185, 0.175), (0.045, 0.175), (-0.178, 0.195),
    ]
    rec = link("RF_Receiver", solid_plate(outline, 0.0, 0.082, ch=0.008, mat=OBS, bevel_mat=SLT, open_inner=True))
    mirror_y(rec, merge=True)

    # Trigger guard opening + true open cut-through Reactor Core Bay + magwell slot + right ejection recess
    trig_cut = [(0.232, 0.112), (0.392, 0.112), (0.405, 0.176), (0.218, 0.176)]
    bay_cut = [
        (0.265, 0.208), (0.645, 0.208), (0.688, 0.250), (0.688, 0.340),
        (0.645, 0.382), (0.265, 0.382), (0.222, 0.340), (0.222, 0.250),
    ]
    mag_cut = box_bm(0.556, 0.818, -0.056, 0.056, 0.010, 0.195, ch=0.0, mat=DRK)
    eject_cut = box_bm(0.285, 0.585, -0.100, -0.055, 0.354, 0.406, ch=0.0, mat=DRK)
    bool_cut(rec, [prism_xz(trig_cut, -0.12, 0.12, DRK), prism_xz(bay_cut, -0.12, 0.12, DRK), mag_cut, eject_cut])

    # Stepped chamfered slate-titanium upper rear shoulder shrouds (relieved cleanly above FireSelector z=0.305!)
    rear_shroud = [
        (-0.145, 0.378), (-0.115, 0.422), (0.195, 0.422), (0.218, 0.365),
        (0.195, 0.308), (0.068, 0.308), (0.048, 0.258), (-0.145, 0.258),
    ]
    rs = link("RF_RearShroud", solid_plate(rear_shroud, 0.068, 0.088, ch=0.005, mat=SLT, bevel_mat=STL))
    mirror_y(rs)

    # Antique-bronze stepped collar framing the front & rear pillars of the core bay
    f_col = [(0.682, 0.204), (0.740, 0.204), (0.750, 0.246), (0.750, 0.362), (0.735, 0.420), (0.678, 0.420), (0.688, 0.346), (0.688, 0.248)]
    fc = link("RF_BayCollarFront", solid_plate(f_col, 0.0, 0.091, ch=0.004, mat=BRZ, bevel_mat=BRZ, open_inner=True))
    mirror_y(fc, merge=True)

    r_col = [(0.174, 0.222), (0.226, 0.222), (0.222, 0.252), (0.222, 0.338), (0.232, 0.414), (0.178, 0.414)]
    rc = link("RF_BayCollarRear", solid_plate(r_col, 0.0, 0.090, ch=0.004, mat=BRZ, bevel_mat=BRZ, open_inner=True))
    mirror_y(rc, merge=True)

    # Rear stock-receiver bronze adapter collar
    link("RF_StockCollar", box_bm(-0.205, -0.135, -0.088, 0.088, 0.195, 0.418, ch=0.006, mat=BRZ))

    # Upper dorsal spine rail + bronze cross-lugs + rear charge status pad
    link("RF_SpineRail", box_bm(0.015, 1.595, -0.044, 0.044, 0.424, 0.464, ch=0.004, mat=OBS, bevel_mat=SLT))
    lugs = [box_bm(lx - 0.016, lx + 0.016, -0.046, 0.046, 0.455, 0.474, ch=0.0025, mat=BRZ)
            for lx in (0.32, 0.40, 0.48, 0.56, 0.64, 0.72, 0.80, 0.88)]
    link("RF_SpineLugs", merge_bms(lugs))

    link("RF_RearPadFrame", box_bm(-0.085, 0.020, -0.042, 0.042, 0.424, 0.450, ch=0.003, mat=BRZ))
    link("RF_RearPadGlow", box_bm(-0.072, 0.006, -0.024, 0.024, 0.445, 0.454, ch=0.001, mat=COR))


# =============================================================================
# 2. ANIMATED REACTOR CORE ASSEMBLY (CRYSTAL + RING + ARTICULATED PRONGS)
# =============================================================================
def build_reactor_core():
    # A) Floating 8-face faceted violet plasma octahedron (flat_group = CoreCrystal)
    bm_c = bmesh.new()
    cx, cy, cz = CORE_CX, CORE_CY, CORE_CZ
    rx, ry, rz = 0.080, 0.056, 0.062
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
    link("RF_CoreCrystal", bm_c, bone="Root", flat_group="CoreCrystal")

    # B) Faceted hexagonal tilted containment ring (flat_group = CoreRing)
    bm_r = bmesh.new()
    n = 6
    r_in, r_out, half_w = 0.086, 0.102, 0.011
    tilt = Matrix.Rotation(math.radians(24), 3, "X") @ Matrix.Rotation(math.radians(-16), 3, "Z")

    def pt(ang, r, dy):
        p = tilt @ Vector((r * math.cos(ang), dy, r * math.sin(ang)))
        return (cx + p.x, cy + p.y, cz + p.z)

    rings = [
        [bm_r.verts.new(pt(2 * math.pi * i / n, r_in, -half_w)) for i in range(n)],
        [bm_r.verts.new(pt(2 * math.pi * i / n, r_out, -half_w)) for i in range(n)],
        [bm_r.verts.new(pt(2 * math.pi * i / n, r_out, half_w)) for i in range(n)],
        [bm_r.verts.new(pt(2 * math.pi * i / n, r_in, half_w)) for i in range(n)],
    ]
    for i in range(n):
        j = (i + 1) % n
        for k in range(4):
            k2 = (k + 1) % 4
            f = bm_r.faces.new((rings[k][i], rings[k][j], rings[k2][j], rings[k2][i]))
            f.material_index = STL
    link("RF_CoreRing", bm_r, bone="Root", flat_group="CoreRing")

    # C) Four articulated containment prongs (Upper pair + Lower pair)
    def build_prong_pair(is_upper):
        sgn = 1.0 if is_upper else -1.0
        z_root = CORE_CZ + sgn * 0.082
        z_mid = CORE_CZ + sgn * 0.066
        z_tip = CORE_CZ + sgn * 0.043
        fg = "ProngUpper" if is_upper else "ProngLower"
        arms, tips = [], []
        for xsgn in (-1.0, 1.0):
            x_base = CORE_CX + xsgn * 0.200
            x_elbow = CORE_CX + xsgn * 0.145
            x_tip = CORE_CX + xsgn * 0.094
            arm_out = [
                (x_base, z_root), (x_elbow, z_mid + sgn * 0.012),
                (x_tip, z_tip + sgn * 0.010), (x_tip + xsgn * 0.008, z_tip - sgn * 0.006),
                (x_elbow + xsgn * 0.006, z_mid - sgn * 0.008), (x_base, z_root - sgn * 0.018),
            ]
            if not is_upper:
                arm_out = list(reversed(arm_out))
            for ysgn in (-1.0, 1.0):
                y0, y1 = (0.044, 0.068) if ysgn > 0 else (-0.068, -0.044)
                arms.append(solid_plate(arm_out, y0, y1, ch=0.002, mat=STL, bevel_mat=STL))
                tips.append(box_bm(
                    min(x_tip - xsgn * 0.022, x_tip + xsgn * 0.012),
                    max(x_tip - xsgn * 0.022, x_tip + xsgn * 0.012),
                    y0 - 0.002, y1 + 0.002,
                    min(z_tip - 0.009, z_tip + 0.011),
                    max(z_tip - 0.009, z_tip + 0.011),
                    ch=0.002, mat=BRZ
                ))
        link(f"RF_{fg}Arms", merge_bms(arms), bone="Root", flat_group=fg + "Arms")
        link(f"RF_{fg}Tips", merge_bms(tips), bone="Root", flat_group=fg + "Tips")

    build_prong_pair(True)
    build_prong_pair(False)


# =============================================================================
# 3. FORGED SLATE-TITANIUM HANDGUARD + BRONZE CLAMP BANDS
# =============================================================================
def build_handguard():
    # Tapered faceted slate-titanium handguard (x=0.915..1.652, LeftGrip flush at z=0.198!)
    hg_out = [
        (0.915, 0.428), (1.648, 0.420), (1.664, 0.392), (1.664, 0.258),
        (1.622, 0.212), (1.560, 0.198), (0.955, 0.198), (0.915, 0.220),
    ]
    hg = link("RF_Handguard", solid_plate(hg_out, 0.0, 0.086, ch=0.014, mat=SLT, bevel_mat=STL, open_inner=True))
    mirror_y(hg, merge=True)

    # Relieve left side around CharmPoint (0.985, 0.090, 0.225) + crisp side cooling louvers
    charm_rel = box_bm(0.945, 1.032, 0.066, 0.125, 0.194, 0.275, ch=0.0, mat=DRK)
    slot1_l = box_bm(1.085, 1.240, 0.064, 0.115, 0.298, 0.334, ch=0.0, mat=DRK)
    slot1_r = box_bm(1.085, 1.240, -0.115, -0.064, 0.298, 0.334, ch=0.0, mat=DRK)
    slot2_l = box_bm(1.375, 1.545, 0.064, 0.115, 0.300, 0.336, ch=0.0, mat=DRK)
    slot2_r = box_bm(1.375, 1.545, -0.115, -0.064, 0.300, 0.336, ch=0.0, mat=DRK)
    bool_cut(hg, [charm_rel, slot1_l, slot1_r, slot2_l, slot2_r])

    # Dark obsidian lower keel + recessed plasma sliver visible inside the handguard louvers
    link("RF_HandguardCore", box_bm(0.935, 1.625, -0.066, 0.066, 0.198, 0.340, ch=0.004, mat=OBS))
    link("RF_HgGlow", box_bm(1.100, 1.535, -0.068, 0.068, 0.309, 0.324, ch=0.0, mat=COR))

    # Two raked antique-bronze armor clamp bands wrapping the handguard
    for idx, bx in enumerate((1.285, 1.445)):
        band_out = [
            (bx - 0.028, 0.422), (bx + 0.032, 0.422),
            (bx + 0.022, 0.214), (bx - 0.038, 0.214),
        ]
        b = link(f"RF_HgBand_{idx}", solid_plate(band_out, 0.0, 0.091, ch=0.004, mat=BRZ, bevel_mat=BRZ, open_inner=True))
        mirror_y(b, merge=True)


# =============================================================================
# 4. SLEEK TAPERED OCTAGONAL PLASMA SUPPRESSOR (CLEAN, AGGRESSIVE, ZERO BLOAT!)
# =============================================================================
def build_suppressor():
    cz = 0.352

    # Stepped antique-bronze root locking collar transitioning handguard -> suppressor
    col_rings = [
        oct_ring_x(1.630, 0.088, cz=cz),
        oct_ring_x(1.655, 0.092, cz=cz),
        oct_ring_x(1.730, 0.090, cz=cz),
        oct_ring_x(1.752, 0.080, cz=cz),
    ]
    link("RF_SuppCollar", loft_rings(col_rings, mat=BRZ, cap0=True, cap1=True))

    # Sleek octagonal dark-obsidian suppressor body tapering sharply to a carved crown
    supp_rings = [
        oct_ring_x(1.735, 0.079, cz=cz),
        oct_ring_x(2.380, 0.076, cz=cz),
        oct_ring_x(2.482, 0.066, cz=cz),
        oct_ring_x(2.505, 0.055, cz=cz),
    ]
    supp = link("RF_Suppressor", loft_rings(supp_rings, mat=OBS, cap0=True, cap1=True, cap_mat=DRK))

    # Razor-crisp lateral plasma accelerator channels on BOTH flanks + hollow dark bore!
    flank_l = box_bm(1.800, 2.370, 0.050, 0.120, cz - 0.016, cz + 0.016, ch=0.0, mat=DRK)
    flank_r = box_bm(1.800, 2.370, -0.120, -0.050, cz - 0.016, cz + 0.016, ch=0.0, mat=DRK)
    bore = loft_rings([oct_ring_x(2.385, 0.028, cz=cz), oct_ring_x(2.525, 0.028, cz=cz)], mat=DRK)
    bool_cut(supp, [flank_l, flank_r, bore])

    # Recessed glowing violet plasma accelerator rails seated cleanly inside the channels
    link("RF_SuppPlasmaL", box_bm(1.812, 2.358, 0.048, 0.065, cz - 0.0085, cz + 0.0085, ch=0.001, mat=COR))
    link("RF_SuppPlasmaR", box_bm(1.812, 2.358, -0.065, -0.048, cz - 0.0085, cz + 0.0085, ch=0.001, mat=COR))

    # Three crisp beveled slate-titanium baffle ribs bridging across the plasma channel
    ribs = [
        loft_rings([
            oct_ring_x(rx - 0.016, 0.079, cz=cz),
            oct_ring_x(rx - 0.011, 0.083, cz=cz),
            oct_ring_x(rx + 0.011, 0.083, cz=cz),
            oct_ring_x(rx + 0.016, 0.079, cz=cz),
        ], mat=SLT)
        for rx in (1.94, 2.11, 2.28)
    ]
    link("RF_SuppBaffles", merge_bms(ribs))

    # Beveled antique-bronze internal muzzle crown collar
    crown_obj = link("RF_SuppCrown", loft_rings([
        oct_ring_x(2.452, 0.044, cz=cz),
        oct_ring_x(2.502, 0.040, cz=cz),
    ], mat=BRZ))
    bool_cut(crown_obj, [loft_rings([oct_ring_x(2.440, 0.028, cz=cz), oct_ring_x(2.520, 0.028, cz=cz)], mat=DRK)])

    # Flush-seated animated Top & Bottom Heat-Vent Louvers (hinge at x=1.78, flare outward on spray & reload!)
    vt_out = [(1.780, cz + 0.068), (2.335, cz + 0.066), (2.375, cz + 0.078), (1.805, cz + 0.083)]
    vt = link("RF_VentTop", solid_plate(vt_out, 0.0, 0.025, ch=0.003, mat=SLT, bevel_mat=SLT, open_inner=True),
              bone="Root", flat_group="VentTop")
    mirror_y(vt, merge=True)

    vb_out = [(1.805, cz - 0.083), (2.375, cz - 0.078), (2.335, cz - 0.066), (1.780, cz - 0.068)]
    vb = link("RF_VentBottom", solid_plate(vb_out, 0.0, 0.025, ch=0.003, mat=SLT, bevel_mat=SLT, open_inner=True),
              bone="Root", flat_group="VentBottom")
    mirror_y(vb, merge=True)

    # Recessed glowing core strip revealed underneath when top/bottom heat vents flare open
    link("RF_VentCore", box_bm(1.830, 2.310, -0.015, 0.015, cz - 0.071, cz + 0.071, ch=0.0, mat=COR))


# =============================================================================
# 5. SCULPTED OPEN HEXAGONAL-ARCH IRON SIGHTS (*Sight* NAMING, AIMPOINT Z=0.578)
# =============================================================================
def build_sights():
    # AimPoint = (0.154, 0.000, 0.578). Center |y| < 0.038 is 100% open & unobstructed!
    # Rear sight: sleek chamfered open hexagonal-arch silhouette (single material OBS)
    rear_l = [
        (0.056, 0.462), (0.064, 0.505), (0.058, 0.600), (0.036, 0.628),
        (0.024, 0.620), (0.040, 0.592), (0.040, 0.512), (0.000, 0.504), (0.000, 0.462),
    ]
    rear_r = [(-y, z) for y, z in reversed(rear_l)]
    sr_l = solid_plate_x(rear_l, 0.130, 0.215, ch=0.004, mat=OBS, bevel_mat=OBS)
    sr_r = solid_plate_x(rear_r, 0.130, 0.215, ch=0.004, mat=OBS, bevel_mat=OBS)
    link("RF_SightRear", merge_bms([sr_l, sr_r]), bone="Root", flat_group="SightRear")

    # Subtle antique-bronze sight base trim
    link("RF_SightBase", box_bm(0.118, 0.228, -0.058, 0.058, 0.460, 0.484, ch=0.003, mat=BRZ),
         bone="Root", flat_group="SightBase")

    # Crisp restrained violet side pips seated on rear faces at exact Z = 0.578, Y = +/- 0.049
    pips = [
        box_bm(0.124, 0.138, ysgn * 0.048 - 0.0045, ysgn * 0.048 + 0.0045, 0.5735, 0.5825, ch=0.001, mat=HOT)
        for ysgn in (-1.0, 1.0)
    ]
    link("RF_SightPips", merge_bms(pips), bone="Root", flat_group="SightPips")

    # Front sight: tapered angled protective wings + razor center post tip at EXACT Z = 0.578!
    fr_l = [
        (0.042, 0.456), (0.046, 0.498), (0.038, 0.586), (0.028, 0.590),
        (0.028, 0.500), (0.000, 0.494), (0.000, 0.456),
    ]
    fr_r = [(-y, z) for y, z in reversed(fr_l)]
    f_l = solid_plate_x(fr_l, 1.552, 1.612, ch=0.003, mat=OBS, bevel_mat=OBS)
    f_r = solid_plate_x(fr_r, 1.552, 1.612, ch=0.003, mat=OBS, bevel_mat=OBS)
    f_post = box_bm(1.572, 1.592, -0.0055, 0.0055, 0.490, 0.578, ch=0.001, mat=OBS)
    link("RF_SightFront", merge_bms([f_l, f_r, f_post]), bone="Root", flat_group="SightFront")


# =============================================================================
# 6. SKELETONIZED ANGULAR STOCK, GRIP & ENERGY-CELL MAGAZINE
# =============================================================================
def build_stock():
    top_out = [(-0.155, 0.398), (-1.040, 0.408), (-1.055, 0.345), (-0.155, 0.325)]
    top = link("RF_StockTop", solid_plate(top_out, 0.0, 0.042, ch=0.006, mat=OBS, bevel_mat=SLT, open_inner=True))
    mirror_y(top, merge=True)

    low_out = [(-0.155, 0.275), (-1.025, -0.002), (-1.025, -0.058), (-0.155, 0.212)]
    low = link("RF_StockLow", solid_plate(low_out, 0.0, 0.036, ch=0.005, mat=OBS, bevel_mat=SLT, open_inner=True))
    mirror_y(low, merge=True)

    butt_out = [
        (-1.005, 0.412), (-1.072, 0.408), (-1.102, 0.355), (-1.098, -0.015),
        (-1.070, -0.064), (-1.005, -0.062), (-0.995, -0.010), (-0.995, 0.365),
    ]
    butt = link("RF_StockButt", solid_plate(butt_out, 0.0, 0.056, ch=0.007, mat=OBS, bevel_mat=SLT, open_inner=True))
    mirror_y(butt, merge=True)

    link("RF_StockHeel", box_bm(-1.095, -1.015, -0.048, 0.048, 0.345, 0.405, ch=0.003, mat=BRZ))


def build_grip():
    grip_out = [
        (-0.025, 0.190), (0.195, 0.190), (0.145, 0.040), (0.048, -0.295),
        (-0.165, -0.310), (-0.190, -0.275), (-0.092, 0.045),
    ]
    g = link("RF_Grip", solid_plate(grip_out, 0.0, 0.056, ch=0.007, mat=GRP, bevel_mat=OBS, open_inner=True))
    mirror_y(g, merge=True)

    gbase = [(-0.172, -0.272), (0.052, -0.262), (0.044, -0.312), (-0.166, -0.314)]
    gb = link("RF_GripBase", solid_plate(gbase, 0.0, 0.060, ch=0.003, mat=BRZ, bevel_mat=BRZ, open_inner=True))
    mirror_y(gb, merge=True)


def build_mag():
    mag_out = [(0.562, 0.215), (0.812, 0.215), (0.816, -0.248), (0.554, -0.248)]
    m = link("RF_MagBody", solid_plate(mag_out, 0.0, 0.054, ch=0.006, mat=OBS, bevel_mat=SLT, open_inner=True), bone="Mag")
    mirror_y(m, merge=True)

    slot_l = box_bm(0.662, 0.712, 0.036, 0.080, -0.220, 0.035, ch=0.0, mat=DRK)
    slot_r = box_bm(0.662, 0.712, -0.080, -0.036, -0.220, 0.035, ch=0.0, mat=DRK)
    bool_cut(m, [slot_l, slot_r])

    link("RF_MagCore", box_bm(0.668, 0.706, -0.044, 0.044, -0.212, 0.028, ch=0.001, mat=COR), bone="Mag")

    base_out = [(0.542, -0.242), (0.828, -0.242), (0.822, -0.302), (0.548, -0.302)]
    mb = link("RF_MagBase", solid_plate(base_out, 0.0, 0.060, ch=0.005, mat=BRZ, bevel_mat=BRZ, open_inner=True), bone="Mag")
    mirror_y(mb, merge=True)


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

# Reskin kept stock controls; hide replaced stock parts
STOCK_SET = ["Body", "Panel", "Dark", "Metal", "Grip", "Accent", "Neon", "Brass"]
SLOT_SKIN = [M_OBSIDIAN, M_SLATE, M_DARK, M_STEEL, M_GRIP, M_BRONZE, M_CORE, M_BRONZE]
HARDWARE = ["Phantom_ChargingHandle", "Phantom_Bolt", "Phantom_Trigger", "Phantom_FireSelector", "Phantom_CharmLoop"]
REPLACED = [
    "Phantom_Neon", "Phantom_Receiver", "Phantom_Handguard", "Phantom_Rail",
    "Phantom_Suppressor", "Phantom_Grip", "Phantom_Stock", "Phantom_Pins",
    "Phantom_Mag", "Phantom_Sights",
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

# Assert exact world origin alignment on critical parts!
bpy.context.view_layer.update()
for check_name in ("RF_SightRear", "RF_SightFront", "RF_Suppressor", "RF_CoreCrystal"):
    o = bpy.data.objects[check_name]
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    ys = [p.y for p in pts]
    assert abs(0.5 * (min(ys) + max(ys))) < 0.002, f"{check_name} off-center in Y: {min(ys):.4f}..{max(ys):.4f}"

BLEND_OUT = os.path.join(OUT_DIR, "Phantom_Riftforge_v01.blend")
bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)

# =============================================================================
# RENDER FULL-FRAME & CLOSE-UP REVIEW SHEETS
# =============================================================================
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.film_transparent = False
if not scene.world:
    scene.world = bpy.data.worlds.new("World")
scene.world.use_nodes = True
bg = scene.world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.14, 0.16, 0.21, 1.0)
    bg.inputs[1].default_value = 0.9

for o in list(bpy.data.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o, do_unlink=True)

def add_light(name, loc, energy, size=2.5, color=(1, 1, 1)):
    ld = bpy.data.lights.new(name, type="AREA")
    ld.energy = energy
    ld.size = size
    ld.color = color
    lo = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(lo)
    lo.location = loc
    d = Vector((0.68, 0.0, 0.28)) - Vector(loc)
    lo.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

add_light("Key", (1.6, 2.6, 2.2), 185, 2.4, (1.0, 0.98, 0.96))
add_light("Fill", (-1.5, 2.4, 1.0), 85, 3.0, (0.85, 0.90, 1.0))
add_light("Rim", (0.8, -2.5, 1.8), 145, 2.0, (0.95, 0.86, 1.0))

cam_data = bpy.data.cameras.new("ReviewCam")
cam = bpy.data.objects.new("ReviewCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

def render_shot(name, loc, target, lens=50):
    cam_data.lens = lens
    cam.location = Vector(loc)
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(REV_DIR, name)
    bpy.ops.render.render(write_still=True)

render_shot("hero.png", (2.15, 3.35, 1.08), (0.72, 0.0, 0.22), lens=44)
render_shot("side.png", (0.70, 4.35, 0.22), (0.70, 0.0, 0.22), lens=48)
render_shot("fp.png", (-0.84, 0.56, 0.64), (0.86, -0.01, 0.30), lens=36)
render_shot("ads.png", (-0.42, 0.0, 0.578), (1.60, 0.0, 0.578), lens=65)
render_shot("closeup_core.png", (0.48, 0.72, 0.36), (0.455, 0.0, 0.296), lens=55)
render_shot("closeup_supp.png", (2.28, 0.88, 0.48), (2.06, 0.0, 0.352), lens=52)

# =============================================================================
# FLAT EXPORT (export_roblox_flat.py) + MAGENTA BACKFACE-CULLED CHECK
# =============================================================================
exec(open(os.path.join(ROOT, "tools", "blender", "export_roblox_flat.py"), encoding="utf-8").read())
fbx_path, report = export_flat([o for o in col.objects if o.type == "MESH"], OUT_DIR, "Phantom", "Riftforge")
print("EXPORT REPORT:", report)

# Re-import FBX into clean empty scene with magenta world + backface culling to verify zero holes/flips!
bpy.ops.wm.read_homefile(use_empty=True, use_factory_startup=True)
bpy.ops.import_scene.fbx(filepath=fbx_path)
s2 = bpy.context.scene
s2.render.engine = "BLENDER_EEVEE"
s2.render.resolution_x = 1280
s2.render.resolution_y = 720
s2.world = bpy.data.worlds.new("MagWorld")
s2.world.use_nodes = True
s2.world.node_tree.nodes["Background"].inputs[0].default_value = (1.0, 0.0, 1.0, 1.0)
s2.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0

for m in bpy.data.materials:
    m.use_backface_culling = True
for o in bpy.data.objects:
    if o.type == "MESH":
        o.data.polygons.foreach_set("use_smooth", [False] * len(o.data.polygons))
        for sl in o.material_slots:
            if sl.material:
                sl.material.use_backface_culling = True

ld = bpy.data.lights.new("Sun", type="SUN")
ld.energy = 3.0
lo = bpy.data.objects.new("Sun", ld)
s2.collection.objects.link(lo)
lo.rotation_euler = (math.radians(40), math.radians(20), math.radians(30))

cd = bpy.data.cameras.new("MagCam")
cd.lens = 44
co = bpy.data.objects.new("MagCam", cd)
s2.collection.objects.link(co)
s2.camera = co
# FBX is exported at 100x scale (cm)
co.location = Vector((215, 335, 108))
co.rotation_euler = (Vector((72, 0, 22)) - co.location).to_track_quat("-Z", "Y").to_euler()
s2.render.filepath = os.path.join(REV_DIR, "fbx_magenta.png")
bpy.ops.render.render(write_still=True)

# Re-open master .blend so Blender stays on the editable master
bpy.ops.wm.open_mainfile(filepath=BLEND_OUT)
print("DONE Riftforge Phantom v01 master + flat FBX + magenta check")
