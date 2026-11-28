"""Collector Charm Blind Box (Strike Box + Overdrive Box) for Draft Duels.

Built headless via Blender 5.2 CLI:
    blender --background --factory-startup --python tools/blender/crates/build_charm_box.py

Units: 1 Blender unit = 1 stud. X = width, -Y = front, Z = up, origin = box centre.
Style (gauntlet-build-style / gauntlet-model-joins): flat faceted only, chamfered
edges, zero smooth faces, zero subdiv modifiers, seated details, 0 non-manifold.

Parts (Group_Role naming for Studio CrateLook / BlindBoxOpening recoloring):
    Body_Box       main vertical faceted blind box body
    Body_Trim      seated corner bumpers, waist band, and side ribs
    Body_Glow      horizontal rarity seam collar + side light pips
    Body_Label     flush front label plate (receives SurfaceGui in Studio)
    Body_Interior  hollow dark cavity tray + inner pedestal
    Lid_Box        hinged top lid cap + faceted collector hang-tab header
    Lid_Trim       lid corner lugs + front pull tab
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
BLEND = os.path.join(ROOT, "art-source", "lobby", "crates", "CharmBox.blend")
OUT_JSON = os.path.join(ROOT, "art-source", "lobby", "crates", "CharmBox.json")
FBX = os.path.join(ROOT, "art-source", "lobby", "Exports", "CharmBox.fbx")
REVIEW_PNG = os.path.join(ROOT, "art-source", "lobby", "crates", "charm_box_review.png")
SHOP_BOXES_DIR = os.path.join(ROOT, "art-source", "ui", "shop", "boxes")
STRIKE_CARD_PNG = os.path.join(SHOP_BOXES_DIR, "box_strike.png")
OVERDRIVE_CARD_PNG = os.path.join(SHOP_BOXES_DIR, "box_overdrive.png")

COLL = "CHARMBOX"

# Box geometry (1 unit = 1 stud)
HX = 0.62
HY = 0.62
CORNER = 0.09
Z_BOT = -0.82
Z_SEAM = 0.32
Z_LID0 = 0.345
Z_LID1 = 0.56
Z_TAB1 = 0.88
WALL = 0.085

# Rear top hinge pivot in Blender coords (X=0, Y=+0.59, Z=+0.345) -> Roblox (0, 0.345, 0.59)
LID_PIVOT = Vector((0.0, HY - 0.03, Z_LID0))
PIVOTS = {"Body": (0.0, 0.0, 0.0), "Lid": tuple(LID_PIVOT)}

THEMES = {
    "Strike": {
        "Box": (0.145, 0.155, 0.180),       # tactical charcoal gunmetal
        "Trim": (0.068, 0.072, 0.086),      # deep matte slate trim
        "Glow": (0.961, 0.761, 0.220),      # #F5C238 tactical gold
        "Label": (0.055, 0.058, 0.070),
        "Interior": (0.032, 0.034, 0.042),
    },
    "Overdrive": {
        "Box": (0.095, 0.110, 0.145),       # matte obsidian navy
        "Trim": (0.048, 0.055, 0.078),      # dark slate trim
        "Glow": (0.247, 0.878, 0.949),      # #3FE0F2 overdrive cyan
        "Label": (0.042, 0.048, 0.064),
        "Interior": (0.024, 0.028, 0.038),
    },
}


def srgb_to_linear(rgb):
    return tuple(((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92 for c in rgb) + (1.0,)


def make_mat(role, theme="Strike"):
    name = f"CharmBox_{role}"
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    apply_theme_to_mat(m, role, theme)
    return m


def apply_theme_to_mat(m, role, theme="Strike"):
    lin = srgb_to_linear(THEMES[theme][role])
    m.diffuse_color = lin
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = lin
        bsdf.inputs["Roughness"].default_value = 0.28 if role == "Glow" else 0.52
        bsdf.inputs["Metallic"].default_value = 0.22 if role == "Trim" else 0.05
        if role == "Glow":
            bsdf.inputs["Emission Color"].default_value = lin
            bsdf.inputs["Emission Strength"].default_value = 2.4
        else:
            bsdf.inputs["Emission Strength"].default_value = 0.0


def cham_rect(x0, x1, y0, y1, c):
    return [
        (x0 + c, y0),
        (x1 - c, y0),
        (x1, y0 + c),
        (x1, y1 - c),
        (x1 - c, y1),
        (x0 + c, y1),
        (x0, y1 - c),
        (x0, y0 + c),
    ]


def scale_pts(pts, s):
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    return [(cx + (x - cx) * s, cy + (y - cy) * s) for x, y in pts]


def add_bm(dst, src):
    me = bpy.data.meshes.new("_tmp_join")
    src.to_mesh(me)
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)
    src.free()


def to3(plane, u, v, w):
    if plane == "XY":
        return Vector((u, v, w))
    if plane == "YZ":
        return Vector((w, u, v))
    return Vector((u, w, v))


def prism(pts, plane, a0, a1, cham=0.0, taper=None):
    bm = bmesh.new()
    cu = sum(p[0] for p in pts) / len(pts)
    cv = sum(p[1] for p in pts) / len(pts)
    rings = []
    for a, s in ((a0, taper[0] if taper else 1.0), (a1, taper[1] if taper else 1.0)):
        rings.append([bm.verts.new(to3(plane, cu + (u - cu) * s, cv + (v - cv) * s, a)) for u, v in pts])
    n = len(pts)
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[1])))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if cham > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=cham, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    return bm


def loft_z(rings, cham=0.0):
    bm = bmesh.new()
    vs = [[bm.verts.new((u, v, z)) for u, v in pts] for pts, z in rings]
    bm.faces.new(vs[0])
    bm.faces.new(list(reversed(vs[-1])))
    n = len(vs[0])
    for a, b in zip(vs, vs[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if cham > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=cham, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    return bm


def hollow_box(outer_pts, inner_pts, z_bot, z_floor, z_top):
    """Watertight hollow tray extruded Z: outer floor -> outer top -> inner rim -> inner floor."""
    bm = bmesh.new()
    n = len(outer_pts)
    ob = [bm.verts.new((u, v, z_bot)) for u, v in outer_pts]
    ot = [bm.verts.new((u, v, z_top)) for u, v in outer_pts]
    it = [bm.verts.new((u, v, z_top)) for u, v in inner_pts]
    ib = [bm.verts.new((u, v, z_floor)) for u, v in inner_pts]

    bm.faces.new(list(reversed(ob)))
    bm.faces.new(ib)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
        bm.faces.new((ot[i], ot[j], it[j], it[i]))
        bm.faces.new((it[i], it[j], ib[j], ib[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def ring_frame_xz(outer_pts, inner_pts, y0, y1):
    """Watertight rectangular/chamfered window frame in XZ extruded Y (no floating coplanar holes)."""
    bm = bmesh.new()
    n = len(outer_pts)
    of = [bm.verts.new((x, y0, z)) for x, z in outer_pts]
    ob = [bm.verts.new((x, y1, z)) for x, z in outer_pts]
    if_ = [bm.verts.new((x, y0, z)) for x, z in inner_pts]
    ib = [bm.verts.new((x, y1, z)) for x, z in inner_pts]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((of[i], of[j], if_[j], if_[i]))
        bm.faces.new((ib[i], ib[j], ob[j], ob[i]))
        bm.faces.new((of[i], ob[i], ob[j], of[j]))
        bm.faces.new((if_[j], ib[j], ib[i], if_[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def build_body_box():
    outer = cham_rect(-HX, HX, -HY, HY, CORNER)
    inner = cham_rect(-HX + WALL, HX - WALL, -HY + WALL, HY - WALL, CORNER * 0.6)
    plinth = scale_pts(outer, 1.035)
    # Stepped plinth + hollow box shell up to shoulder so opening the lid reveals a deep interior cavity
    bm = loft_z([
        (scale_pts(plinth, 0.96), Z_BOT),
        (plinth, Z_BOT + 0.04),
        (plinth, Z_BOT + 0.14),
        (outer, Z_BOT + 0.22),
    ])
    shell = hollow_box(outer, inner, Z_BOT + 0.21, Z_BOT + 0.24, Z_SEAM)
    add_bm(bm, shell)
    return bm


def build_body_trim():
    bm = bmesh.new()
    # Seated lower waist belt wrapping the plinth step
    belt_pts = cham_rect(-HX - 0.025, HX + 0.025, -HY - 0.025, HY + 0.025, CORNER + 0.015)
    add_bm(bm, prism(belt_pts, "XY", Z_BOT + 0.05, Z_BOT + 0.16, cham=0.012))

    # Four angled corner bumper pillars along the box sides, seated cleanly into body corners
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (HX - 0.04), sy * (HY - 0.04)
            col_pts = cham_rect(cx - 0.095, cx + 0.095, cy - 0.095, cy + 0.095, 0.035)
            add_bm(bm, prism(col_pts, "XY", Z_BOT + 0.14, Z_SEAM - 0.05, cham=0.014))

    # Seated side vent ribs (+X and -X walls)
    for sx in (-1, 1):
        x0 = (HX - 0.01) if sx > 0 else (-HX - 0.032)
        x1 = (HX + 0.032) if sx > 0 else (-HX + 0.01)
        for i in range(4):
            z0 = -0.52 + i * 0.18
            rib = cham_rect(-0.34, 0.34, z0, z0 + 0.075, 0.02)
            add_bm(bm, prism(rib, "YZ", x0, x1, cham=0.008))

    # Back spine reinforcement plate (+Y back wall)
    back_rib = cham_rect(-0.28, 0.28, Z_BOT + 0.22, Z_SEAM - 0.08, 0.05)
    add_bm(bm, prism(back_rib, "XZ", HY - 0.015, HY + 0.035, cham=0.012))
    return bm


def build_body_glow():
    bm = bmesh.new()
    # Hollow glowing seam collar ring around the top rim (leaves the cavity completely open)
    outer = cham_rect(-HX - 0.016, HX + 0.016, -HY - 0.016, HY + 0.016, CORNER + 0.006)
    inner = cham_rect(-HX + WALL - 0.004, HX - WALL + 0.004, -HY + WALL - 0.004, HY - WALL + 0.004, CORNER * 0.58)
    n = len(outer)
    z0, z1 = Z_SEAM - 0.048, Z_SEAM - 0.004
    ob = [bm.verts.new((u, v, z0)) for u, v in outer]
    ot = [bm.verts.new((u, v, z1)) for u, v in outer]
    it = [bm.verts.new((u, v, z1)) for u, v in inner]
    ib = [bm.verts.new((u, v, z0)) for u, v in inner]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
        bm.faces.new((ot[i], ot[j], it[j], it[i]))
        bm.faces.new((it[i], it[j], ib[j], ib[i]))
        bm.faces.new((ib[i], ib[j], ob[j], ob[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    # Front header neon bar above the label plate + side glow strips
    bar = cham_rect(-0.36, 0.36, Z_SEAM - 0.125, Z_SEAM - 0.075, 0.015)
    add_bm(bm, prism(bar, "XZ", -HY - 0.025, -HY + 0.005, cham=0.004))
    for sx in (-1, 1):
        x0 = (HX - 0.008) if sx > 0 else (-HX - 0.020)
        x1 = (HX + 0.020) if sx > 0 else (-HX + 0.008)
        pip = cham_rect(-0.18, 0.18, -0.50, 0.06, 0.015)
        add_bm(bm, prism(pip, "YZ", x0, x1, cham=0.004))
    return bm


def build_body_label():
    # Flush front display plate on -Y face for Studio SurfaceGui (`Enum.NormalId.Front`)
    pts = cham_rect(-0.44, 0.44, -0.62, 0.14, 0.055)
    return prism(pts, "XZ", -HY - 0.014, -HY + 0.008, cham=0.004)


def build_body_interior():
    outer = cham_rect(-HX + WALL + 0.005, HX - WALL - 0.005, -HY + WALL + 0.005, HY - WALL - 0.005, CORNER * 0.55)
    inner = cham_rect(-HX + WALL + 0.045, HX - WALL - 0.045, -HY + WALL + 0.045, HY - WALL - 0.045, CORNER * 0.4)
    bm = hollow_box(outer, inner, Z_BOT + 0.25, Z_BOT + 0.29, Z_SEAM + 0.008)
    # Raised octagonal charm pedestal inside the floor of the blind box
    ped = cham_rect(-0.24, 0.24, -0.24, 0.24, 0.07)
    add_bm(bm, prism(ped, "XY", Z_BOT + 0.28, Z_BOT + 0.40, cham=0.015))
    return bm


def build_lid_box():
    # Overhanging chamfered cap from Z_LID0 to Z_LID1
    base = cham_rect(-HX - 0.03, HX + 0.03, -HY - 0.03, HY + 0.03, CORNER + 0.015)
    top = scale_pts(base, 0.90)
    bm = loft_z([
        (base, Z_LID0),
        (base, Z_LID1 - 0.075),
        (top, Z_LID1),
    ])

    # Top central riser block supporting the faceted collector hang-tab
    riser = cham_rect(-0.46, 0.46, -0.16, 0.16, 0.05)
    add_bm(bm, prism(riser, "XY", Z_LID1 - 0.02, Z_LID1 + 0.055, cham=0.012))

    # Faceted retail hang-tab header with punched collector slot (cleanly watertight via ring_frame_xz)
    tab_outer = cham_rect(-0.38, 0.38, Z_LID1 + 0.03, Z_TAB1, 0.085)
    tab_inner = cham_rect(-0.18, 0.18, Z_LID1 + 0.145, Z_TAB1 - 0.07, 0.025)
    add_bm(bm, ring_frame_xz(tab_outer, tab_inner, -0.055, 0.055))
    return bm


def build_lid_trim():
    bm = bmesh.new()
    # Lid corner cap armor
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (HX - 0.03), sy * (HY - 0.03)
            cap = cham_rect(cx - 0.11, cx + 0.11, cy - 0.11, cy + 0.11, 0.04)
            add_bm(bm, prism(cap, "XY", Z_LID0 - 0.008, Z_LID1 - 0.045, cham=0.014))

    # Front tear-notch pull clasp on -Y front rim of the lid
    clasp = cham_rect(-0.24, 0.24, Z_LID0 - 0.02, Z_LID0 + 0.11, 0.035)
    add_bm(bm, prism(clasp, "XZ", -HY - 0.068, -HY - 0.01, cham=0.010))

    # Rear hinge knuckle block
    hinge = cham_rect(-0.34, 0.34, Z_SEAM - 0.02, Z_LID0 + 0.08, 0.025)
    add_bm(bm, prism(hinge, "XZ", HY - 0.02, HY + 0.058, cham=0.010))
    return bm


def check_mesh(obj):
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    non_manifold = sum(1 for e in bm.edges if not e.is_manifold)
    bm.free()
    smooth = sum(1 for p in me.polygons if p.use_smooth)
    subdiv = sum(1 for m in obj.modifiers if m.type == "SUBSURF")
    return {
        "tris": len(me.polygons),
        "non_manifold": non_manifold,
        "smooth_faces": smooth,
        "subdiv": subdiv,
    }


def build_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    coll = bpy.data.collections.new(COLL)
    bpy.context.scene.collection.children.link(coll)

    parts = {
        ("Body", "Box"): build_body_box(),
        ("Body", "Trim"): build_body_trim(),
        ("Body", "Glow"): build_body_glow(),
        ("Body", "Label"): build_body_label(),
        ("Body", "Interior"): build_body_interior(),
        ("Lid", "Box"): build_lid_box(),
        ("Lid", "Trim"): build_lid_trim(),
    }

    info = {
        "parts": {},
        "pivots_blender": PIVOTS,
        "lid_pivot_roblox": [0.0, round(Z_LID0, 4), round(HY - 0.03, 4)],
        "tris": 0,
    }
    objs = {}
    for (group, role), bm in parts.items():
        name = f"{group}_{role}"
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        px, py, pz = PIVOTS[group]
        bmesh.ops.translate(bm, vec=(-px, -py, -pz), verts=bm.verts)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        me.materials.append(make_mat(role, "Strike"))
        ob = bpy.data.objects.new(name, me)
        ob.location = (px, py, pz)
        ob["group"], ob["role"] = group, role
        coll.objects.link(ob)
        stats = check_mesh(ob)
        assert stats["non_manifold"] == 0, f"{name} non_manifold={stats['non_manifold']}"
        assert stats["smooth_faces"] == 0, f"{name} smooth={stats['smooth_faces']}"
        info["parts"][name] = stats
        info["tris"] += stats["tris"]
        objs[name] = ob

    return coll, objs, info


def apply_theme(theme):
    for role in THEMES[theme]:
        mat = bpy.data.materials.get(f"CharmBox_{role}")
        if mat:
            apply_theme_to_mat(mat, role, theme)


def setup_studio(sc, target=(0, 0, 0.04)):
    tgt = Vector(target)
    for name, loc, energy, size in (
        ("Key", (-3.4, -4.4, 3.6), 340, 3.2),
        ("Fill", (3.8, -2.6, 1.4), 130, 3.8),
        ("Rim", (1.6, 3.8, 3.2), 260, 2.6),
    ):
        lt = bpy.data.objects.get("BoxLight_" + name) or bpy.data.objects.new(
            "BoxLight_" + name, bpy.data.lights.new("BoxLight_" + name, "AREA")
        )
        if lt.name not in sc.collection.objects:
            sc.collection.objects.link(lt)
        lt.location = Vector(loc)
        lt.data.energy, lt.data.size = energy, size
        lt.rotation_euler = (tgt - lt.location).to_track_quat("-Z", "Y").to_euler()
    cam = bpy.data.objects.get("BoxCam") or bpy.data.objects.new("BoxCam", bpy.data.cameras.new("BoxCam"))
    if cam.name not in sc.collection.objects:
        sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def add_render_label(theme):
    """Add crisp temporary graphic plane on front Body_Label for UI card renders only."""
    tex_path = os.path.join(SHOP_BOXES_DIR, f"_label_{theme.lower()}.png")
    if not os.path.exists(tex_path):
        return None

    me = bpy.data.meshes.new("_LabelArtMesh")
    x, z0, z1, y = 0.40, -0.58, 0.10, -HY - 0.0155
    me.from_pydata([(-x, y, z0), (x, y, z0), (x, y, z1), (-x, y, z1)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new()
    for i, c in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
        uv.data[i].uv = c
    mat = bpy.data.materials.get("_CardLabelMat") or bpy.data.materials.new("_CardLabelMat")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.get("LabelTex") or nt.nodes.new("ShaderNodeTexImage")
    tex.name = "LabelTex"
    tex.image = bpy.data.images.load(tex_path, check_existing=True)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.45
    bsdf.inputs["Roughness"].default_value = 0.45
    me.materials.append(mat)
    plane = bpy.data.objects.new("_CardLabelPlane", me)
    bpy.data.collections[COLL].objects.link(plane)
    return plane, tex_path


def crop_rgba(path, pad=16):
    from PIL import Image
    im = Image.open(path).convert("RGBA")
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    side = max(im.size) + pad * 2
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    sq.resize((512, 512), Image.LANCZOS).save(path)


def render_assets(objs):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("BoxWorld")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.045, 0.048, 0.060, 1.0)
    sc.world = w
    cam = setup_studio(sc, (0, 0, 0.04))

    # 1. Shop & Backpack transparent card renders (512x512 RGBA)
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.resolution_x, sc.render.resolution_y = 640, 640
    cam.location = Vector((-1.95, -3.55, 1.15))
    q = (Vector((0, 0, 0.04)) - cam.location).to_track_quat("-Z", "Y")
    cam.rotation_euler = (q @ Quaternion((0, 0, 1), math.radians(-5))).to_euler()
    cam.data.lens = 50

    for theme, out_path in (("Strike", STRIKE_CARD_PNG), ("Overdrive", OVERDRIVE_CARD_PNG)):
        apply_theme(theme)
        lbl = add_render_label(theme)
        sc.render.filepath = out_path
        bpy.ops.render.render(write_still=True)
        if lbl:
            bpy.data.objects.remove(lbl[0])

    # 2. 4 review renders (composed into 2x2 sheet in post-step)
    sc.render.film_transparent = False
    sc.render.resolution_x, sc.render.resolution_y = 640, 640
    tmp_dir = os.path.dirname(REVIEW_PNG)

    # Q1: Strike Box 3/4
    apply_theme("Strike")
    lbl1 = add_render_label("Strike")
    cam.location = Vector((-2.1, -3.6, 1.25))
    cam.rotation_euler = (Vector((0, 0, 0.04)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(tmp_dir, "_q1.png")
    bpy.ops.render.render(write_still=True)
    if lbl1:
        bpy.data.objects.remove(lbl1[0])

    # Q2: Overdrive Box 3/4
    apply_theme("Overdrive")
    lbl2 = add_render_label("Overdrive")
    sc.render.filepath = os.path.join(tmp_dir, "_q2.png")
    bpy.ops.render.render(write_still=True)
    if lbl2:
        bpy.data.objects.remove(lbl2[0])

    # Q3: Open Lid View (Strike) - rotate lid backward around rear hinge (-X tilts up & back in Blender)
    apply_theme("Strike")
    for k in ("Lid_Box", "Lid_Trim"):
        objs[k].rotation_euler = Euler((math.radians(-108), 0, 0), "XYZ")
    cam.location = Vector((-1.95, -3.55, 2.25))
    cam.rotation_euler = (Vector((0, 0.1, 0.15)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(tmp_dir, "_q3.png")
    bpy.ops.render.render(write_still=True)

    # Q4: Close-up seam collar + hang-tab join (closed)
    for k in ("Lid_Box", "Lid_Trim"):
        objs[k].rotation_euler = Euler((0, 0, 0), "XYZ")
    cam.location = Vector((-1.35, -2.05, 0.95))
    cam.rotation_euler = (Vector((0, 0, 0.45)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(tmp_dir, "_q4.png")
    bpy.ops.render.render(write_still=True)


def export_fbx(coll):
    os.makedirs(os.path.dirname(FBX), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=FBX,
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_UNITS",
        use_mesh_modifiers=True,
        bake_anim=False,
    )


def main():
    coll, objs, info = build_scene()
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    export_fbx(coll)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)
    render_assets(objs)
    apply_theme("Strike")
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print(json.dumps(info, indent=2))


if __name__ == "__main__":
    main()
