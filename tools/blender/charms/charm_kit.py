"""Shared faceted charm modelling, validation, and studio rendering helpers.

Used by build_charms.py, build_strike_pack.py, and build_overdrive_pack.py
inside Blender 5.2 (port 9100, PID 18288).
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
OUT_ROOT = os.path.join(REPO, "art-source", "charms")


def clear_scene():
    bpy.ops.wm.read_homefile(use_empty=True, use_factory_startup=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    return scene


def make_material(
    name: str,
    hex_color: str,
    rbx_material: str = "SmoothPlastic",
    roughness: float = 0.40,
    metallic: float = 0.0,
    emission_strength: float = 0.0,
    alpha: float = 1.0,
    rbx_transparency: float = 0.0,
):
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0

    def srgb_to_lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    lr, lg, lb = srgb_to_lin(r), srgb_to_lin(g), srgb_to_lin(b)

    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (lr, lg, lb, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if "Alpha" in bsdf.inputs:
            bsdf.inputs["Alpha"].default_value = alpha
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (lr, lg, lb, 1.0)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength
        if "IOR" in bsdf.inputs and alpha < 1.0:
            bsdf.inputs["IOR"].default_value = 1.31
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.55 if metallic > 0 else 0.38

    if alpha < 1.0 and hasattr(mat, "blend_method"):
        mat.blend_method = "BLEND"

    mat["rbx_material"] = rbx_material
    mat["rbx_color"] = [int(round(r * 255)), int(round(g * 255)), int(round(b * 255))]
    if rbx_transparency > 0.0:
        mat["rbx_transparency"] = float(rbx_transparency)
    return mat


def get_empty_union_coll():
    col = bpy.data.collections.get("_EmptyUnion")
    if not col:
        col = bpy.data.collections.new("_EmptyUnion")
    return col


def apply_modifiers_clean(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    new_mesh = bpy.data.meshes.new_from_object(
        eval_obj, preserve_all_data_layers=True, depsgraph=depsgraph
    )
    new_mesh.name = obj.name + "_Mesh"
    old_mesh = obj.data
    obj.modifiers.clear()
    obj.data = new_mesh
    if old_mesh.users == 0:
        bpy.data.meshes.remove(old_mesh)


def bm_to_object(
    name: str,
    bm: bmesh.types.BMesh,
    materials: list,
    coll: bpy.types.Collection,
    union: bool = False,
    bevel_width: float = 0.0,
    bevel_angle_deg: float = 38.0,
    origin: Vector = Vector((0.0, 0.0, 0.0)),
    dissolve_coplanar: bool = True,
):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = False
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(name, mesh)
    coll.objects.link(obj)
    for m in materials:
        obj.data.materials.append(m)

    if origin != Vector((0.0, 0.0, 0.0)):
        for v in obj.data.vertices:
            v.co -= origin
        obj.location = origin

    bpy.context.view_layer.update()

    if union:
        md = obj.modifiers.new("Union", "BOOLEAN")
        md.operation = "UNION"
        md.solver = "EXACT"
        md.use_self = True
        md.operand_type = "COLLECTION"
        md.collection = get_empty_union_coll()
        apply_modifiers_clean(obj)

        if dissolve_coplanar:
            bm2 = bmesh.new()
            bm2.from_mesh(obj.data)
            bmesh.ops.dissolve_limit(
                bm2,
                angle_limit=math.radians(1.5),
                use_dissolve_boundaries=False,
                verts=bm2.verts[:],
                edges=bm2.edges[:],
                delimit={"MATERIAL"},
            )
            bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
            bm2.to_mesh(obj.data)
            bm2.free()
            obj.data.update()

    if bevel_width > 0.0:
        bv = obj.modifiers.new("Bevel", "BEVEL")
        bv.width = bevel_width
        bv.segments = 1
        bv.limit_method = "ANGLE"
        bv.angle_limit = math.radians(bevel_angle_deg)
        bv.use_clamp_overlap = True
        bv.harden_normals = False
        apply_modifiers_clean(obj)

        bm3 = bmesh.new()
        bm3.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm3, verts=bm3.verts[:], dist=0.0002)
        bmesh.ops.recalc_face_normals(bm3, faces=bm3.faces)
        bm3.to_mesh(obj.data)
        bm3.free()

    for p in obj.data.polygons:
        p.use_smooth = False
    obj.data.update()
    return obj


# ---------------------------------------------------------------------------
# BMesh Faceted Primitives
# ---------------------------------------------------------------------------

def add_box(bm, x0, x1, y0, y1, z0, z1, mat_idx=0, xform=None):
    cx, cy, cz = (x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5
    sx, sy, sz = (x1 - x0), (y1 - y0), (z1 - z0)
    m = Matrix.Translation((cx, cy, cz)) @ Matrix.Diagonal((sx, sy, sz, 1.0))
    if xform is not None:
        m = xform @ m
    ret = bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    verts = ret["verts"]
    vset = set(verts)
    for f in bm.faces:
        if all(v in vset for v in f.verts):
            f.material_index = mat_idx
            f.smooth = False
    return verts


def add_prism_y(bm, pts_xz, y0, y1, mat_idx=0, xform=None):
    v_front, v_back = [], []
    for x, z in pts_xz:
        p0 = Vector((x, y0, z))
        p1 = Vector((x, y1, z))
        if xform is not None:
            p0 = xform @ p0
            p1 = xform @ p1
        v_front.append(bm.verts.new(p0))
        v_back.append(bm.verts.new(p1))
    n = len(pts_xz)
    faces = [bm.faces.new(list(reversed(v_front))), bm.faces.new(v_back)]
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new([v_front[i], v_front[j], v_back[j], v_back[i]]))
    for f in faces:
        f.material_index = mat_idx
        f.smooth = False
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return v_front + v_back


def add_prism_z(bm, pts_xy, z0, z1, mat_idx=0, xform=None):
    v_bot, v_top = [], []
    for x, y in pts_xy:
        p0 = Vector((x, y, z0))
        p1 = Vector((x, y, z1))
        if xform is not None:
            p0 = xform @ p0
            p1 = xform @ p1
        v_bot.append(bm.verts.new(p0))
        v_top.append(bm.verts.new(p1))
    n = len(pts_xy)
    faces = [bm.faces.new(list(reversed(v_bot))), bm.faces.new(v_top)]
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new([v_bot[i], v_bot[j], v_top[j], v_top[i]]))
    for f in faces:
        f.material_index = mat_idx
        f.smooth = False
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return v_bot + v_top


def add_frustum_z(bm, pts_xy_bot, z0, pts_xy_top, z1, mat_idx=0, xform=None):
    assert len(pts_xy_bot) == len(pts_xy_top)
    v_bot = [bm.verts.new(xform @ Vector((x, y, z0)) if xform else Vector((x, y, z0))) for x, y in pts_xy_bot]
    v_top = [bm.verts.new(xform @ Vector((x, y, z1)) if xform else Vector((x, y, z1))) for x, y in pts_xy_top]
    n = len(pts_xy_bot)
    faces = [bm.faces.new(list(reversed(v_bot))), bm.faces.new(v_top)]
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new([v_bot[i], v_bot[j], v_top[j], v_top[i]]))
    for f in faces:
        f.material_index = mat_idx
        f.smooth = False
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return v_bot + v_top


def add_frustum_y(bm, pts_xz_front, y0, pts_xz_back, y1, mat_idx=0, xform=None):
    assert len(pts_xz_front) == len(pts_xz_back)
    v_f = [bm.verts.new(xform @ Vector((x, y0, z)) if xform else Vector((x, y0, z))) for x, z in pts_xz_front]
    v_b = [bm.verts.new(xform @ Vector((x, y1, z)) if xform else Vector((x, y1, z))) for x, z in pts_xz_back]
    n = len(pts_xz_front)
    faces = [bm.faces.new(list(reversed(v_f))), bm.faces.new(v_b)]
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new([v_f[i], v_f[j], v_b[j], v_b[i]]))
    for f in faces:
        f.material_index = mat_idx
        f.smooth = False
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return v_f + v_b


def add_layered_prism_y(bm, pts_xz, y_half, cham_y, cham_in, mat_idx=0, center_xz=None):
    if center_xz is None:
        cx = sum(p[0] for p in pts_xz) / len(pts_xz)
        cz = sum(p[1] for p in pts_xz) / len(pts_xz)
    else:
        cx, cz = center_xz
    inner_pts = [(cx + (x - cx) * (1.0 - cham_in), cz + (z - cz) * (1.0 - cham_in)) for x, z in pts_xz]
    y_mid = y_half - cham_y
    v_fi = [bm.verts.new((x, -y_half, z)) for x, z in inner_pts]
    v_fm = [bm.verts.new((x, -y_mid, z)) for x, z in pts_xz]
    v_bm = [bm.verts.new((x, y_mid, z)) for x, z in pts_xz]
    v_bi = [bm.verts.new((x, y_half, z)) for x, z in inner_pts]
    n = len(pts_xz)
    faces = [bm.faces.new(list(reversed(v_fi))), bm.faces.new(v_bi)]
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new([v_fi[i], v_fi[j], v_fm[j], v_fm[i]]))
        faces.append(bm.faces.new([v_fm[i], v_fm[j], v_bm[j], v_bm[i]]))
        faces.append(bm.faces.new([v_bm[i], v_bm[j], v_bi[j], v_bi[i]]))
    for f in faces:
        f.material_index = mat_idx
        f.smooth = False
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def add_ring_y(bm, cx, cz, r_in, r_out, n, y_half, cham=0.004, rot=0.0, mat_idx=0):
    """Continuous closed N-sided chamfered ring around Y axis (0 internal seams)."""
    prof = [
        (r_in, -(y_half - cham)),
        (r_in + cham, -y_half),
        (r_out - cham, -y_half),
        (r_out, -(y_half - cham)),
        (r_out, (y_half - cham)),
        (r_out - cham, y_half),
        (r_in + cham, y_half),
        (r_in, (y_half - cham)),
    ]
    rings = []
    for i in range(n):
        a = rot + 2 * math.pi * i / n
        ca, sa = math.cos(a), math.sin(a)
        rings.append([bm.verts.new((cx + rad * ca, yy, cz + rad * sa)) for rad, yy in prof])
    faces = []
    for i in range(n):
        j = (i + 1) % n
        for k in range(len(prof)):
            kn = (k + 1) % len(prof)
            f = bm.faces.new([rings[i][k], rings[j][k], rings[j][kn], rings[i][kn]])
            f.material_index = mat_idx
            f.smooth = False
            faces.append(f)
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def ngon_pts(cx, cy, r, n, rot=0.0):
    return [(cx + r * math.cos(rot + 2 * math.pi * i / n), cy + r * math.sin(rot + 2 * math.pi * i / n)) for i in range(n)]


def cham_rect_pts(cx, cy, hx, hy, c):
    return [
        (cx - hx + c, cy - hy),
        (cx + hx - c, cy - hy),
        (cx + hx, cy - hy + c),
        (cx + hx, cy + hy - c),
        (cx + hx - c, cy + hy),
        (cx - hx + c, cy + hy),
        (cx - hx, cy + hy - c),
        (cx - hx, cy - hy + c),
    ]


def add_sweep_loop(bm, spine_pts, tube_r, mat_idx=0):
    n = len(spine_pts)
    rings = []
    for i in range(n):
        prev_p = Vector(spine_pts[(i - 1) % n])
        cur_p = Vector(spine_pts[i])
        next_p = Vector(spine_pts[(i + 1) % n])
        t1 = (cur_p - prev_p).normalized()
        t2 = (next_p - cur_p).normalized()
        tangent = t1 + t2
        if tangent.length < 1e-6:
            tangent = t2
        else:
            tangent.normalize()
        ref = Vector((0, 1, 0)) if abs(tangent.y) < 0.9 else Vector((1, 0, 0))
        binorm = tangent.cross(ref).normalized()
        norm = binorm.cross(tangent).normalized()
        cos_half = max(0.55, math.sqrt(max(0.3, (1.0 + t1.dot(t2)) * 0.5)))
        r = tube_r / cos_half
        offsets = [norm * r, binorm * r, -norm * r, -binorm * r]
        rings.append([bm.verts.new(cur_p + off) for off in offsets])

    faces = []
    for i in range(n):
        j = (i + 1) % n
        for k in range(4):
            kn = (k + 1) % 4
            f = bm.faces.new([rings[i][k], rings[j][k], rings[j][kn], rings[i][kn]])
            f.material_index = mat_idx
            f.smooth = False
            faces.append(f)
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def stadium_spine(center_z, half_w, half_h, plane="XZ", segs=6):
    if segs == 6:
        pts2d = [
            (0.0, half_h),
            (half_w, half_h * 0.52),
            (half_w, -half_h * 0.52),
            (0.0, -half_h),
            (-half_w, -half_h * 0.52),
            (-half_w, half_h * 0.52),
        ]
    else:
        pts2d = [
            (-half_w * 0.45, half_h),
            (half_w * 0.45, half_h),
            (half_w, half_h * 0.45),
            (half_w, -half_h * 0.45),
            (half_w * 0.45, -half_h),
            (-half_w * 0.45, -half_h),
            (-half_w, -half_h * 0.45),
            (-half_w, half_h * 0.45),
        ]
    return [(u, 0.0, center_z + v) if plane == "XZ" else (0.0, u, center_z + v) for u, v in pts2d]


def add_chain(coll, charm_id: str, chain_mat, bottom_z: float = -0.106):
    bm = bmesh.new()
    l0 = []
    cz0, r0 = -0.020, 0.020
    for i in range(6):
        a = 2 * math.pi * i / 6 + math.pi / 6
        l0.append((0.0, r0 * math.cos(a), cz0 + r0 * math.sin(a)))
    add_sweep_loop(bm, l0, tube_r=0.006, mat_idx=0)

    l1 = stadium_spine(center_z=-0.050, half_w=0.015, half_h=0.023, plane="XZ", segs=6)
    add_sweep_loop(bm, l1, tube_r=0.0055, mat_idx=0)

    mid2 = (-0.060 + bottom_z) * 0.5
    hh2 = abs(bottom_z - (-0.060)) * 0.5
    l2 = stadium_spine(center_z=mid2, half_w=0.015, half_h=hh2, plane="YZ", segs=6)
    add_sweep_loop(bm, l2, tube_r=0.0055, mat_idx=0)

    return bm_to_object(f"{charm_id}_Chain", bm, [chain_mat], coll, union=False, bevel_width=0.0)


def add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=0):
    cz = (z_top + z_bot) * 0.5
    hh = (z_top - z_bot) * 0.5
    spine = stadium_spine(center_z=cz, half_w=half_w, half_h=hh, plane="XZ", segs=6)
    add_sweep_loop(bm, spine, tube_r=tube_r, mat_idx=mat_idx)


def add_faceted_gem(bm, center: Vector, rx: float, ry: float, rz: float, n_sides: int = 6, mat_idx: int = 0):
    v_top = bm.verts.new(center + Vector((0, 0, rz)))
    v_bot = bm.verts.new(center + Vector((0, 0, -rz)))
    ring_hi, ring_lo = [], []
    for i in range(n_sides):
        a = 2 * math.pi * i / n_sides
        ring_hi.append(bm.verts.new(center + Vector((rx * math.cos(a), ry * math.sin(a), rz * 0.34))))
        a2 = a + math.pi / n_sides
        ring_lo.append(bm.verts.new(center + Vector((rx * math.cos(a2), ry * math.sin(a2), -rz * 0.34))))
    faces = []
    for i in range(n_sides):
        j = (i + 1) % n_sides
        faces.append(bm.faces.new([v_top, ring_hi[i], ring_hi[j]]))
        faces.append(bm.faces.new([ring_hi[i], ring_lo[i], ring_hi[j]]))
        faces.append(bm.faces.new([ring_lo[i], ring_lo[j], ring_hi[j]]))
        faces.append(bm.faces.new([v_bot, ring_lo[j], ring_lo[i]]))
    for f in faces:
        f.material_index = mat_idx
        f.smooth = False
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def build_flush_corner_clasp(bm_cube_aligned, cut_z: float, mat_chain, coll, name: str):
    """Build a custom flush metallic corner cap directly from the upper facets of a cube mesh."""
    bm_cap = bm_cube_aligned.copy()
    bmesh.ops.recalc_face_normals(bm_cap, faces=bm_cap.faces)
    bm_cap.normal_update()
    for v in bm_cap.verts:
        v.co += v.normal * 0.0045
    geom = bm_cap.verts[:] + bm_cap.edges[:] + bm_cap.faces[:]
    bmesh.ops.bisect_plane(bm_cap, geom=geom, plane_co=(0.0, 0.0, cut_z), plane_no=(0.0, 0.0, 1.0), clear_inner=True)
    bmesh.ops.holes_fill(bm_cap, edges=[e for e in bm_cap.edges if e.is_boundary])
    for f in bm_cap.faces:
        f.material_index = 0
        f.smooth = False
    add_frustum_z(bm_cap, cham_rect_pts(0, 0, 0.020, 0.016, 0.005), cut_z + 0.016, cham_rect_pts(0, 0, 0.016, 0.013, 0.004), -0.125, mat_idx=0)
    add_eyelet(bm_cap, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=0)
    return bm_to_object(name, bm_cap, [mat_chain], coll, union=True, bevel_width=0.0)


# ---------------------------------------------------------------------------
# Studio Lighting, Camera, Validation & Rendering
# ---------------------------------------------------------------------------

def setup_render_rig(scene):
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False

    world = bpy.data.worlds.new("CharmStudioWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.028, 0.034, 0.048, 1.0)
        bg.inputs["Strength"].default_value = 1.15

    rig_coll = bpy.data.collections.new("RenderRig")
    scene.collection.children.link(rig_coll)

    def add_area(name, loc, target, energy, size, color):
        ldata = bpy.data.lights.new(name, type="AREA")
        ldata.energy = energy
        ldata.size = size
        ldata.color = color
        lobj = bpy.data.objects.new(name, ldata)
        rig_coll.objects.link(lobj)
        lobj.location = Vector(loc)
        lobj.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        return lobj

    t = (0.0, 0.0, -0.20)
    add_area("KeyLight", (-0.75, -1.10, 0.35), t, 6.4, 0.85, (1.0, 0.98, 0.95))
    add_area("FillLight", (0.85, -0.85, -0.10), t, 3.0, 1.1, (0.82, 0.90, 1.0))
    add_area("RimLight", (0.45, 0.95, 0.30), t, 5.5, 0.75, (0.92, 0.96, 1.0))
    add_area("UnderBounce", (0.0, -0.45, -0.85), t, 1.5, 0.9, (0.88, 0.91, 1.0))

    cdata = bpy.data.cameras.new("ReviewCam")
    cdata.lens = 50.0
    cdata.clip_start = 0.01
    cdata.clip_end = 50.0
    cam = bpy.data.objects.new("ReviewCam", cdata)
    rig_coll.objects.link(cam)
    scene.camera = cam
    return cam, rig_coll


def validate_charm(coll: bpy.types.Collection):
    total_tris = 0
    non_manifold_total = 0
    smooth_faces = 0
    subdiv_mods = 0
    mats = set()

    z_min, z_max = 1e9, -1e9
    bx_min, bx_max = 1e9, -1e9
    by_min, by_max = 1e9, -1e9
    bz_min, bz_max = 1e9, -1e9
    parts = []

    for obj in coll.objects:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        mesh.calc_loop_triangles()
        tris = len(mesh.loop_triangles)
        total_tris += tris

        for mod in obj.modifiers:
            if mod.type == "SUBSURF":
                subdiv_mods += 1
        for p in mesh.polygons:
            if p.use_smooth:
                smooth_faces += 1
        for m in mesh.materials:
            if m:
                mats.add(m.name)

        bm = bmesh.new()
        bm.from_mesh(mesh)
        nm = sum(1 for e in bm.edges if not e.is_manifold)
        non_manifold_total += nm
        bm.free()

        mw = obj.matrix_world
        pts = [mw @ v.co for v in mesh.vertices]
        if pts:
            z_min = min(z_min, min(p.z for p in pts))
            z_max = max(z_max, max(p.z for p in pts))
            if not obj.name.endswith("_Chain"):
                bx_min = min(bx_min, min(p.x for p in pts))
                bx_max = max(bx_max, max(p.x for p in pts))
                by_min = min(by_min, min(p.y for p in pts))
                by_max = max(by_max, max(p.y for p in pts))
                bz_min = min(bz_min, min(p.z for p in pts))
                bz_max = max(bz_max, max(p.z for p in pts))

        parts.append({"name": obj.name, "tris": tris, "non_manifold": nm})

    return {
        "tris": total_tris,
        "materials": sorted(mats),
        "material_count": len(mats),
        "non_manifold": non_manifold_total,
        "smooth_faces": smooth_faces,
        "subdiv_modifiers": subdiv_mods,
        "z_max": round(z_max, 4),
        "z_min": round(z_min, 4),
        "total_height": round(z_max - z_min, 4),
        "body_width_x": round(bx_max - bx_min, 4),
        "body_depth_y": round(by_max - by_min, 4),
        "body_height_z": round(bz_max - bz_min, 4),
        "parts": parts,
    }


def render_charm(scene, cam, charm_id: str, out_dir: str):
    rev_dir = os.path.join(out_dir, "review")
    os.makedirs(rev_dir, exist_ok=True)
    shots = [
        ("front_34", (0.42, -0.62, -0.08), (0.0, 0.0, -0.20), 50.0),
        ("side", (0.74, -0.05, -0.20), (0.0, 0.0, -0.20), 50.0),
        ("closeup_join", (0.16, -0.28, -0.02), (0.0, 0.0, -0.10), 35.0),
    ]
    paths = {}
    for name, pos, target, lens in shots:
        cam.location = Vector(pos)
        cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        fpath = os.path.join(rev_dir, f"{name}.png")
        scene.render.filepath = fpath
        bpy.ops.render.render(write_still=True)
        paths[name] = fpath
    return paths


def build_and_render_set(builders: dict, order: list):
    os.makedirs(OUT_ROOT, exist_ok=True)
    report = {}
    for charm_id in order:
        scene = clear_scene()
        coll = bpy.data.collections.new(charm_id)
        scene.collection.children.link(coll)
        builders[charm_id](coll)
        cam, _ = setup_render_rig(scene)

        charm_dir = os.path.join(OUT_ROOT, charm_id)
        os.makedirs(charm_dir, exist_ok=True)
        blend_path = os.path.join(charm_dir, f"{charm_id}.blend")

        info = validate_charm(coll)
        eu = bpy.data.collections.get("_EmptyUnion")
        if eu:
            bpy.data.collections.remove(eu)
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)
        shots = render_charm(scene, cam, charm_id, charm_dir)
        info["blend"] = blend_path
        info["shots"] = shots
        report[charm_id] = info
    return report
