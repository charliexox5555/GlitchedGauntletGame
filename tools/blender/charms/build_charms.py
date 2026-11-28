"""Build, validate, save (.blend), and render all 8 Season 1 Battle Pass charms.

Runs inside the live Blender instance on port 9100 via:
    python tools/blender/lobby_v4/send.py tools/blender/charms/build_charms.py --port 9100 --pid 18288

Follows gauntlet-build-style + gauntlet-model-joins:
- No round curves, no UV spheres, no smooth cylinders, no Subdivision Surface, no smooth bevels.
- Flat shading on every face; angled planar facets only (6-12 segments).
- Union-before-bevel (BOOLEAN EXACT use_self=True -> coplanar cleanup -> 1-segment BEVEL) on solid assemblies.
- Seated details (no floating parts, no blunt cutoffs, no z-fighting).
- Pivot at (0, 0, 0) = inner-top hang point; +Z up, -Y front, +X right; 1 unit = 1 stud.
- Total height ~0.36-0.42 studs; body <= 0.28 studs across; <= 600 tris; <= 3 materials.
- Neon glowing parts are separate Mesh objects (<Id>_Neon).
"""

import math
import os
import traceback

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
OUT_ROOT = os.path.join(REPO, "art-source", "charms")
CHARM_ORDER = [
    "ArcadeToken",
    "IceCube",
    "Joystick",
    "PixelHeart",
    "SnowflakeShard",
    "GameCartridge",
    "ThunderOrb",
    "HighScore",
]


# ---------------------------------------------------------------------------
# Scene & Material Helpers
# ---------------------------------------------------------------------------

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
    roughness: float = 0.42,
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

        # Clean up any degenerate tiny triangles / coplanar artifacts while preserving sharp chamfers
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
        faces.append(bm.faces.new([v_bot[i], v_bot[j], v_top[j], v_bot[i] if False else v_top[i]]))
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
    """Sweep a 4-sided diamond cross-section along a closed 3D spine loop (clean, faceted, low-tri)."""
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
    """3-link interlocked faceted chain (144 tris total: 6-seg ring + two 6-seg stadium links)."""
    bm = bmesh.new()
    # Link 0: 6-sided faceted top hang ring in YZ plane (48 tris)
    l0 = []
    cz0, r0 = -0.020, 0.020
    for i in range(6):
        a = 2 * math.pi * i / 6 + math.pi / 6
        l0.append((0.0, r0 * math.cos(a), cz0 + r0 * math.sin(a)))
    add_sweep_loop(bm, l0, tube_r=0.006, mat_idx=0)

    # Link 1: 6-sided faceted link in XZ plane (48 tris)
    l1 = stadium_spine(center_z=-0.050, half_w=0.015, half_h=0.023, plane="XZ", segs=6)
    add_sweep_loop(bm, l1, tube_r=0.0055, mat_idx=0)

    # Link 2: 6-sided faceted link in YZ plane (48 tris)
    mid2 = (-0.060 + bottom_z) * 0.5
    hh2 = abs(bottom_z - (-0.060)) * 0.5
    l2 = stadium_spine(center_z=mid2, half_w=0.015, half_h=hh2, plane="YZ", segs=6)
    add_sweep_loop(bm, l2, tube_r=0.0055, mat_idx=0)

    return bm_to_object(f"{charm_id}_Chain", bm, [chain_mat], coll, union=False, bevel_width=0.0)


def add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=0):
    """Seated 6-sided faceted diamond-section eyelet in XZ plane interlocking cleanly with Link2."""
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


def add_layered_prism_y(bm, pts_xz, y_half, cham_y, cham_in, mat_idx=0):
    """Build a crisp pre-beveled faceted slab (front/back chamfer rings) directly in bmesh with low tris."""
    # Compute 2D centroid for clean inward inset
    cx = sum(p[0] for p in pts_xz) / len(pts_xz)
    cz = sum(p[1] for p in pts_xz) / len(pts_xz)
    inner_pts = [(cx + (x - cx) * (1.0 - cham_in), cz + (z - cz) * (1.0 - cham_in)) for x, z in pts_xz]

    y_mid = y_half - cham_y
    v_fi = [bm.verts.new((x, -y_half, z)) for x, z in inner_pts]
    v_fm = [bm.verts.new((x, -y_mid, z)) for x, z in pts_xz]
    v_bm = [bm.verts.new((x, y_mid, z)) for x, z in pts_xz]
    v_bi = [bm.verts.new((x, y_half, z)) for x, z in inner_pts]

    n = len(pts_xz)
    faces = [
        bm.faces.new(list(reversed(v_fi))),
        bm.faces.new(v_bi),
    ]
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new([v_fi[i], v_fi[j], v_fm[j], v_fm[i]]))
        faces.append(bm.faces.new([v_fm[i], v_fm[j], v_bm[j], v_bm[i]]))
        faces.append(bm.faces.new([v_bm[i], v_bm[j], v_bi[j], v_bi[i]]))
    for f in faces:
        f.material_index = mat_idx
        f.smooth = False
    bmesh.ops.recalc_face_normals(bm, faces=faces)


# ---------------------------------------------------------------------------
# The 8 Charm Builders (all <= 600 tris, 0 non-manifold, <= 3 materials)
# ---------------------------------------------------------------------------

def build_ArcadeToken(coll):
    mat_gold = make_material("Token_Gold", "#F2C142", "Metal", roughness=0.25, metallic=0.88)
    mat_recess = make_material("Token_Recess", "#B87E1A", "Metal", roughness=0.38, metallic=0.78)
    mat_chain = make_material("Chain_Metal", "#9AA4B4", "Metal", roughness=0.28, metallic=0.85)

    add_chain(coll, "ArcadeToken", mat_chain, bottom_z=-0.106)

    bm = bmesh.new()
    cz = -0.245
    r_outer = 0.115
    r_inner = 0.085
    n = 10

    # Inner coin disc (mat 1 = Token_Recess)
    add_prism_y(bm, ngon_pts(0, cz, r_inner + 0.008, n, rot=math.pi / n), -0.015, 0.015, mat_idx=1)

    # Continuous closed 10-sided chamfered outer rim ring (single manifold shell, 0 internal seams!)
    prof = [
        (r_inner, -0.019),
        (r_inner + 0.005, -0.026),
        (r_outer - 0.005, -0.026),
        (r_outer, -0.018),
        (r_outer, 0.018),
        (r_outer - 0.005, 0.026),
        (r_inner + 0.005, 0.026),
        (r_inner, 0.019),
    ]
    rings = []
    for i in range(n):
        a = math.pi / n + 2 * math.pi * i / n
        ca, sa = math.cos(a), math.sin(a)
        rings.append([bm.verts.new((rad * ca, yy, cz + rad * sa)) for rad, yy in prof])
    for i in range(n):
        j = (i + 1) % n
        for k in range(len(prof)):
            kn = (k + 1) % len(prof)
            f = bm.faces.new([rings[i][k], rings[j][k], rings[j][kn], rings[i][kn]])
            f.material_index = 0
            f.smooth = False

    # Seated 5-pointed faceted star relief on front (-Y) and back (+Y), mat 0
    r_tip, r_val = 0.068, 0.027
    for y_dir in (-1, 1):
        y_base = 0.010 * y_dir
        y_apex = 0.032 * y_dir
        v_apex = bm.verts.new((0.0, y_apex, cz))
        v_back = bm.verts.new((0.0, 0.0, cz))
        star_pts = []
        for k in range(10):
            ang = math.pi / 2 + k * math.pi / 5
            rad = r_tip if k % 2 == 0 else r_val
            star_pts.append((rad * math.cos(ang), cz + rad * math.sin(ang)))
        v_ring = [bm.verts.new((px, y_base, pz)) for px, pz in star_pts]
        faces = []
        for k in range(10):
            kn = (k + 1) % 10
            if y_dir < 0:
                faces.append(bm.faces.new([v_apex, v_ring[kn], v_ring[k]]))
                faces.append(bm.faces.new([v_back, v_ring[k], v_ring[kn]]))
            else:
                faces.append(bm.faces.new([v_apex, v_ring[k], v_ring[kn]]))
                faces.append(bm.faces.new([v_back, v_ring[kn], v_ring[k]]))
        for f in faces:
            f.material_index = 0
            f.smooth = False

    # Seated bail saddle hugging top coin facet + faceted eyelet
    add_frustum_z(bm, cham_rect_pts(0, 0, 0.024, 0.018, 0.006), -0.140, cham_rect_pts(0, 0, 0.019, 0.014, 0.005), -0.124, mat_idx=0)
    add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=0)

    bm_to_object("ArcadeToken_Body", bm, [mat_gold, mat_recess], coll, union=True, bevel_width=0.0)


def build_IceCube(coll):
    mat_ice = make_material("Ice_Outer", "#9CEBFF", "SmoothPlastic", roughness=0.12, metallic=0.0, alpha=0.52, rbx_transparency=0.40)
    mat_core = make_material("Ice_Neon", "#8EE8FF", "Neon", roughness=0.2, emission_strength=2.8)
    mat_chain = make_material("Chain_Metal", "#9AA4B4", "Metal", roughness=0.28, metallic=0.85)

    add_chain(coll, "IceCube", mat_chain, bottom_z=-0.106)

    # Build faceted ice cube with corner (1,1,1) pointing straight up (+Z) so the clasp sits plumb & symmetric!
    bm_cube = bmesh.new()
    bmesh.ops.create_cube(bm_cube, size=0.168)
    # Keep top corner (1,1,1) crisp for the clasp; chip side/bottom corners for organic ice character
    chips = [
        (Vector((-1, -1, 1)).normalized(), 0.118),
        (Vector((1, -1, -1)).normalized(), 0.114),
        (Vector((-1, 1, -1)).normalized(), 0.116),
        (Vector((0.9, -0.8, 0.2)).normalized(), 0.112),
    ]
    for nvec, dist in chips:
        geom = bm_cube.verts[:] + bm_cube.edges[:] + bm_cube.faces[:]
        bmesh.ops.bisect_plane(bm_cube, geom=geom, plane_co=nvec * dist, plane_no=nvec, clear_outer=True)
        bmesh.ops.holes_fill(bm_cube, edges=[e for e in bm_cube.edges if e.is_boundary])
    bmesh.ops.bevel(bm_cube, geom=bm_cube.edges[:], offset=0.008, segments=1, affect="EDGES", clamp_overlap=True)

    # Exact rotation putting (1, 1, 1) straight up +Z, then slight 18 deg Z twist for dynamic 3/4 read
    align_up = (
        Matrix.Rotation(math.radians(18), 4, "Z")
        @ Matrix.Rotation(-math.acos(1.0 / math.sqrt(3.0)), 4, "Y")
        @ Matrix.Rotation(-math.pi / 4.0, 4, "Z")
    )
    bmesh.ops.transform(bm_cube, matrix=align_up, verts=bm_cube.verts)

    # Place the symmetric top corner at (0, 0, -0.140)
    peak_z = max(v.co.z for v in bm_cube.verts)
    shift = Vector((0.0, 0.0, -0.140 - peak_z))
    bmesh.ops.translate(bm_cube, vec=shift, verts=bm_cube.verts)

    # Copy cube into IceCube_Body
    bm_body = bmesh.new()
    vmap = {v: bm_body.verts.new(v.co) for v in bm_cube.verts}
    for f in bm_cube.faces:
        nf = bm_body.faces.new([vmap[v] for v in f.verts])
        nf.material_index = 0
        nf.smooth = False
    bm_to_object("IceCube_Body", bm_body, [mat_ice], coll, union=False, bevel_width=0.0)

    # Build flush-fitting symmetric corner cap directly from the upper corner shell of bm_cube!
    bmesh.ops.recalc_face_normals(bm_cube, faces=bm_cube.faces)
    bm_cube.normal_update()
    for v in bm_cube.verts:
        v.co += v.normal * 0.0045
    cut_z = -0.172
    geom = bm_cube.verts[:] + bm_cube.edges[:] + bm_cube.faces[:]
    bmesh.ops.bisect_plane(bm_cube, geom=geom, plane_co=(0.0, 0.0, cut_z), plane_no=(0.0, 0.0, 1.0), clear_inner=True)
    bmesh.ops.holes_fill(bm_cube, edges=[e for e in bm_cube.edges if e.is_boundary])
    for f in bm_cube.faces:
        f.material_index = 0
        f.smooth = False

    # Slim top collar seat & faceted eyelet centered directly on the corner tip
    add_frustum_z(bm_cube, cham_rect_pts(0, 0, 0.020, 0.016, 0.005), -0.156, cham_rect_pts(0, 0, 0.016, 0.013, 0.004), -0.125, mat_idx=0)
    add_eyelet(bm_cube, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=0)
    bm_to_object("IceCube_Clasp", bm_cube, [mat_chain], coll, union=True, bevel_width=0.0)

    # Center Neon crystal inside the ice cube's centroid
    bm_neon = bmesh.new()
    add_faceted_gem(bm_neon, shift, 0.044, 0.044, 0.062, n_sides=6, mat_idx=0)
    bm_to_object("IceCube_Neon", bm_neon, [mat_core], coll, union=False, bevel_width=0.0)


def build_Joystick(coll):
    mat_base = make_material("Stick_Base", "#3A4254", "SmoothPlastic", roughness=0.40)
    mat_red = make_material("Stick_Red", "#F0384B", "SmoothPlastic", roughness=0.32)
    mat_metal = make_material("Chain_Metal", "#A2ACC0", "Metal", roughness=0.28, metallic=0.86)

    add_chain(coll, "Joystick", mat_metal, bottom_z=-0.106)

    # Steeply angled fight-stick deck (46 deg) seated directly beneath Link2 so no tall stalk exists!
    deck_pivot = Vector((0.0, 0.0, -0.218))
    deck_tilt = Matrix.Translation(deck_pivot) @ Euler((math.radians(46), 0.0, 0.0), "XYZ").to_matrix().to_4x4()

    bm = bmesh.new()
    add_frustum_z(bm, cham_rect_pts(0, 0, 0.088, 0.072, 0.020), -0.030, cham_rect_pts(0, 0, 0.104, 0.086, 0.022), 0.016, mat_idx=0, xform=deck_tilt)
    add_frustum_z(bm, cham_rect_pts(0, 0, 0.096, 0.078, 0.018), 0.012, cham_rect_pts(0, 0, 0.088, 0.070, 0.016), 0.026, mat_idx=0, xform=deck_tilt)
    add_frustum_z(bm, ngon_pts(-0.036, 0.002, 0.030, 8, math.pi / 8), 0.020, ngon_pts(-0.036, 0.002, 0.024, 8, math.pi / 8), 0.034, mat_idx=2, xform=deck_tilt)
    for bx, by_off in ((0.038, -0.018), (0.064, 0.018)):
        add_frustum_z(bm, ngon_pts(bx, by_off, 0.019, 6), 0.020, ngon_pts(bx, by_off, 0.016, 6), 0.033, mat_idx=2, xform=deck_tilt)
        add_frustum_z(bm, ngon_pts(bx, by_off, 0.014, 6), 0.028, ngon_pts(bx, by_off, 0.012, 6), 0.042, mat_idx=1, xform=deck_tilt)

    # Low-profile chamfered metal lug seated flush into the deck's upper rear rim + faceted eyelet
    top_edge = deck_tilt @ Vector((0.0, 0.072, 0.010))
    add_frustum_z(
        bm,
        cham_rect_pts(0, top_edge.y * 0.42, 0.024, 0.018, 0.006),
        top_edge.z - 0.022,
        cham_rect_pts(0, 0.0, 0.018, 0.014, 0.005),
        -0.124,
        mat_idx=2,
    )
    add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=2)

    bm_to_object("Joystick_Body", bm, [mat_base, mat_red, mat_metal], coll, union=True, bevel_width=0.0)

    # Separate moving Joystick_Stick (origin at collar gimbal)
    gimbal_world = deck_tilt @ Vector((-0.036, 0.002, 0.028))
    bm_stick = bmesh.new()
    tilt_rot = Euler((math.radians(46), 0.0, 0.0), "XYZ").to_matrix().to_4x4()
    add_frustum_z(bm_stick, ngon_pts(0, 0, 0.009, 6), -0.004, ngon_pts(0, 0, 0.012, 6), 0.088, mat_idx=0, xform=tilt_rot)

    r_b = 0.043
    bc_z = 0.105
    rings_z = [
        (bc_z - r_b * 0.90, r_b * 0.45),
        (bc_z - r_b * 0.38, r_b * 0.96),
        (bc_z + r_b * 0.38, r_b * 0.96),
        (bc_z + r_b * 0.90, r_b * 0.45),
    ]
    ball_rings = []
    for rz, rr in rings_z:
        ring = [bm_stick.verts.new(tilt_rot @ Vector((px, py, rz))) for px, py in ngon_pts(0, 0, rr, 8, math.pi / 8)]
        ball_rings.append(ring)
    bm_stick.faces.new(list(reversed(ball_rings[0]))).material_index = 1
    bm_stick.faces.new(ball_rings[-1]).material_index = 1
    for r_idx in range(len(ball_rings) - 1):
        rA, rB = ball_rings[r_idx], ball_rings[r_idx + 1]
        for i in range(8):
            j = (i + 1) % 8
            f = bm_stick.faces.new([rA[i], rA[j], rB[j], rB[i]])
            f.material_index = 1
            f.smooth = False
    for v in bm_stick.verts:
        v.co += gimbal_world

    bm_to_object("Joystick_Stick", bm_stick, [mat_metal, mat_red], coll, union=True, bevel_width=0.0, origin=gimbal_world)


def build_PixelHeart(coll):
    mat_red = make_material("Heart_Red", "#E82644", "SmoothPlastic", roughness=0.35)
    mat_edge = make_material("Heart_Edge", "#FFA0B4", "SmoothPlastic", roughness=0.30)
    mat_chain = make_material("Chain_Metal", "#9AA4B4", "Metal", roughness=0.28, metallic=0.85)

    add_chain(coll, "PixelHeart", mat_chain, bottom_z=-0.106)

    bm = bmesh.new()
    px = 0.025
    z_top = -0.145
    # Outer stepped pixel heart (24-vert clean voxel steps)
    outer = [
        (-3.5 * px, z_top), (-1.5 * px, z_top), (-1.5 * px, z_top - 1 * px), (-0.5 * px, z_top - 1 * px),
        (-0.5 * px, z_top - 2 * px), (0.5 * px, z_top - 2 * px), (0.5 * px, z_top - 1 * px), (1.5 * px, z_top - 1 * px),
        (1.5 * px, z_top), (3.5 * px, z_top), (3.5 * px, z_top - 1 * px), (4.5 * px, z_top - 1 * px),
        (4.5 * px, z_top - 4 * px), (3.5 * px, z_top - 4 * px), (3.5 * px, z_top - 5 * px), (2.5 * px, z_top - 5 * px),
        (2.5 * px, z_top - 6 * px), (1.5 * px, z_top - 6 * px), (1.5 * px, z_top - 7 * px), (0.5 * px, z_top - 7 * px),
        (0.5 * px, z_top - 8 * px), (-0.5 * px, z_top - 8 * px), (-0.5 * px, z_top - 7 * px), (-1.5 * px, z_top - 7 * px),
        (-1.5 * px, z_top - 6 * px), (-2.5 * px, z_top - 6 * px), (-2.5 * px, z_top - 5 * px), (-3.5 * px, z_top - 5 * px),
        (-3.5 * px, z_top - 4 * px), (-4.5 * px, z_top - 4 * px), (-4.5 * px, z_top - 1 * px), (-3.5 * px, z_top - 1 * px),
    ]
    add_prism_y(bm, outer, -0.028, 0.028, mat_idx=0)

    # Compact seated cleft saddle bridging the heart notch cleanly + faceted eyelet
    add_frustum_z(bm, cham_rect_pts(0, 0, 0.022, 0.017, 0.005), -0.205, cham_rect_pts(0, 0, 0.018, 0.014, 0.004), -0.130, mat_idx=2)
    add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=2)

    bm_to_object("PixelHeart_Body", bm, [mat_red, mat_chain], coll, union=True, bevel_width=0.0)

    # Light-edge highlight pixel accents (separate crisp stepped plates seated into front/back faces, no union bloat!)
    bm_edge = bmesh.new()
    # Clean L-shaped pixel highlight rim on top-left lobe + lower-right edge glint (reads unmistakably as retro pixel heart!)
    for y_dir in (-1, 1):
        y0, y1 = (0.024 * y_dir, 0.035 * y_dir) if y_dir > 0 else (-0.035, -0.024)
        # Top-left pixel highlight (2x2 stepped L)
        add_box(bm_edge, -3.5 * px, -1.5 * px, y0, y1, z_top - 1.5 * px, z_top - 0.6 * px, mat_idx=0)
        add_box(bm_edge, -3.5 * px, -2.5 * px, y0, y1, z_top - 3.2 * px, z_top - 1.4 * px, mat_idx=0)
        # Top-right lobe smaller glint
        add_box(bm_edge, 1.8 * px, 3.3 * px, y0, y1, z_top - 1.5 * px, z_top - 0.6 * px, mat_idx=0)
        # Bottom-right stepped edge highlight (clean non-touching pixel steps -> 0 non-manifold)
        add_box(bm_edge, 1.6 * px, 2.5 * px, y0, y1, z_top - 5.3 * px, z_top - 4.4 * px, mat_idx=0)
        add_box(bm_edge, 0.5 * px, 1.4 * px, y0, y1, z_top - 6.4 * px, z_top - 5.5 * px, mat_idx=0)
    bm_to_object("PixelHeart_Edge", bm_edge, [mat_edge], coll, union=True, bevel_width=0.0)


def build_SnowflakeShard(coll):
    mat_ice = make_material("Snow_Ice", "#9AEBFF", "SmoothPlastic", roughness=0.14, alpha=0.84, rbx_transparency=0.15)
    mat_neon = make_material("Snow_Neon", "#B5F4FF", "Neon", roughness=0.2, emission_strength=2.8)
    mat_chain = make_material("Chain_Metal", "#9AA4B4", "Metal", roughness=0.28, metallic=0.85)

    add_chain(coll, "SnowflakeShard", mat_chain, bottom_z=-0.106)

    bm = bmesh.new()
    cz = -0.245
    # Hexagonal core hub (clean prism)
    add_prism_y(bm, ngon_pts(0, cz, 0.040, 6, math.pi / 6), -0.020, 0.020, mat_idx=0)

    # 6 single-contour faceted spear arms with crisp chevron notches (9 verts per arm -> ultra clean, < 550 tris total!)
    arm_poly = [
        (-0.011, 0.026),
        (-0.011, 0.058),
        (-0.036, 0.086),
        (-0.013, 0.084),
        (0.0, 0.122),
        (0.013, 0.084),
        (0.036, 0.086),
        (0.011, 0.058),
        (0.011, 0.026),
    ]
    for i in range(6):
        rot = Matrix.Translation((0.0, 0.0, cz)) @ Matrix.Rotation(i * math.pi / 3, 4, "Y")
        add_prism_y(bm, arm_poly, -0.012, 0.012, mat_idx=0, xform=rot)

    add_frustum_z(bm, cham_rect_pts(0, 0, 0.018, 0.015, 0.004), -0.145, cham_rect_pts(0, 0, 0.015, 0.012, 0.004), -0.122, mat_idx=1)
    add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)

    bm_to_object("SnowflakeShard_Body", bm, [mat_ice, mat_chain], coll, union=True, bevel_width=0.0)

    # Separate Neon 6-sided faceted crystal gem in center (24 tris)
    bm_neon = bmesh.new()
    add_faceted_gem(bm_neon, Vector((0.0, 0.0, cz)), 0.034, 0.026, 0.034, n_sides=6, mat_idx=0)
    bm_to_object("SnowflakeShard_Neon", bm_neon, [mat_neon], coll, union=False, bevel_width=0.0)


def build_GameCartridge(coll):
    mat_body = make_material("Cart_Body", "#465066", "SmoothPlastic", roughness=0.40)
    mat_gold = make_material("Cart_Gold", "#F5BE38", "Metal", roughness=0.25, metallic=0.90)
    mat_neon = make_material("Cart_Neon", "#3FE0F2", "Neon", roughness=0.2, emission_strength=3.0)

    add_chain(coll, "GameCartridge", mat_gold, bottom_z=-0.106)

    bm = bmesh.new()
    z_top, z_bot = -0.132, -0.355
    shell = [
        (-0.095, z_bot + 0.022),
        (0.095, z_bot + 0.022),
        (0.095, z_top - 0.036),
        (0.059, z_top),
        (-0.095, z_top),
    ]
    add_layered_prism_y(bm, shell, y_half=0.028, cham_y=0.005, cham_in=0.04, mat_idx=0)
    add_box(bm, -0.080, 0.080, -0.020, 0.020, z_bot, z_bot + 0.030, mat_idx=0)
    for gz in (z_top - 0.026, z_top - 0.046, z_top - 0.066):
        add_box(bm, -0.101, -0.070, -0.032, 0.032, gz - 0.005, gz + 0.005, mat_idx=0)
    # Recessed label bezel frame (proud front panel)
    add_box(bm, -0.070, 0.070, -0.033, -0.020, z_bot + 0.042, z_top - 0.052, mat_idx=0)
    # 4 crisp gold PCB contact teeth seated at bottom
    for px in (-0.051, -0.017, 0.017, 0.051):
        add_box(bm, px - 0.010, px + 0.010, -0.022, 0.022, z_bot - 0.012, z_bot + 0.016, mat_idx=1)

    add_frustum_z(bm, cham_rect_pts(0, 0, 0.022, 0.016, 0.005), -0.142, cham_rect_pts(0, 0, 0.018, 0.013, 0.004), -0.124, mat_idx=1)
    add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)

    bm_to_object("GameCartridge_Body", bm, [mat_body, mat_gold], coll, union=True, bevel_width=0.0)

    bm_neon = bmesh.new()
    stripe = [(-0.046, z_bot + 0.066), (-0.006, z_bot + 0.066), (0.048, z_top - 0.074), (0.008, z_top - 0.074)]
    add_prism_y(bm_neon, stripe, -0.038, -0.028, mat_idx=0)
    add_box(bm_neon, -0.056, -0.020, -0.035, -0.025, z_top - 0.032, z_top - 0.018, mat_idx=0)
    bm_to_object("GameCartridge_Neon", bm_neon, [mat_neon], coll, union=False, bevel_width=0.0)


def build_ThunderOrb(coll):
    mat_dark = make_material("Cage_Dark", "#3A4256", "Metal", roughness=0.35, metallic=0.80)
    mat_steel = make_material("Cage_Steel", "#AAB4C8", "Metal", roughness=0.25, metallic=0.88)
    mat_neon = make_material("Orb_Neon", "#6B5EFF", "Neon", roughness=0.2, emission_strength=3.6)

    add_chain(coll, "ThunderOrb", mat_steel, bottom_z=-0.106)

    cz = -0.255
    bm_orb = bmesh.new()
    bmesh.ops.create_icosphere(bm_orb, subdivisions=1, radius=0.068, matrix=Matrix.Translation((0.0, 0.0, cz)))
    for f in bm_orb.faces:
        f.material_index = 0
        f.smooth = False
    bm_to_object("ThunderOrb_Neon", bm_orb, [mat_neon], coll, union=False, bevel_width=0.0)

    bm = bmesh.new()
    # 4-sided rotated-square/chamfered caps align directly with the 4 struts (cleaner joins & <= 600 tris!)
    add_frustum_z(bm, ngon_pts(0, 0, 0.056, 4, math.pi / 4), -0.168, ngon_pts(0, 0, 0.032, 4, math.pi / 4), -0.130, mat_idx=1)
    add_frustum_z(bm, ngon_pts(0, 0, 0.008, 4, math.pi / 4), -0.390, ngon_pts(0, 0, 0.056, 4, math.pi / 4), -0.342, mat_idx=1)

    for k in range(4):
        ang = math.pi / 4 + k * math.pi / 2
        rot = Matrix.Rotation(ang, 4, "Z")
        strut_pts = [
            (0.034, -0.155), (0.052, -0.155),
            (0.110, cz + 0.032), (0.110, cz - 0.032),
            (0.052, -0.355), (0.034, -0.355),
            (0.088, cz - 0.025), (0.088, cz + 0.025),
        ]
        add_prism_y(bm, strut_pts, -0.012, 0.012, mat_idx=0, xform=rot)
        # Seated steel elbow claw clamp on each strut
        add_box(bm, 0.084, 0.116, -0.015, 0.015, cz - 0.010, cz + 0.010, mat_idx=1, xform=rot)

    add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)

    bm_to_object("ThunderOrb_Body", bm, [mat_dark, mat_steel], coll, union=True, bevel_width=0.0)


def build_HighScore(coll):
    mat_body = make_material("Console_Body", "#3E4759", "SmoothPlastic", roughness=0.38)
    mat_gold = make_material("Console_Gold", "#F5BE38", "Metal", roughness=0.25, metallic=0.90)
    mat_neon = make_material("Console_Neon", "#3CFF9E", "Neon", roughness=0.2, emission_strength=3.0)

    add_chain(coll, "HighScore", mat_gold, bottom_z=-0.106)

    bm = bmesh.new()
    z_top, z_bot = -0.132, -0.375
    add_frustum_z(bm, cham_rect_pts(0, 0, 0.090, 0.030, 0.016), z_bot, cham_rect_pts(0, 0, 0.102, 0.034, 0.018), z_bot + 0.032, mat_idx=0)
    add_prism_z(bm, cham_rect_pts(0, 0, 0.102, 0.034, 0.018), z_bot + 0.030, z_top - 0.024, mat_idx=0)
    add_frustum_z(bm, cham_rect_pts(0, 0, 0.102, 0.034, 0.018), z_top - 0.026, cham_rect_pts(0, 0, 0.086, 0.028, 0.014), z_top, mat_idx=0)

    # Gold championship crest & side bumper guards
    add_prism_z(bm, cham_rect_pts(0, 0, 0.066, 0.030, 0.008), z_top - 0.018, z_top + 0.005, mat_idx=1)
    for sx in (-1, 1):
        add_box(bm, sx * 0.092, sx * 0.108, -0.022, 0.022, z_bot + 0.042, z_top - 0.042, mat_idx=1)

    # Chamfered screen bezel rails on -Y front
    scr_z0, scr_z1 = -0.254, -0.158
    scr_hx = 0.072
    add_box(bm, -0.088, 0.088, -0.040, -0.026, scr_z1, scr_z1 + 0.013, mat_idx=0)
    add_box(bm, -0.088, 0.088, -0.040, -0.026, scr_z0 - 0.013, scr_z0, mat_idx=0)
    add_box(bm, -0.088, -scr_hx, -0.040, -0.026, scr_z0 - 0.008, scr_z1 + 0.008, mat_idx=0)
    add_box(bm, scr_hx, 0.088, -0.040, -0.026, scr_z0 - 0.008, scr_z1 + 0.008, mat_idx=0)

    # Gold D-pad (left) & two hex action buttons (right)
    dx, dz = -0.046, -0.315
    add_box(bm, dx - 0.024, dx + 0.024, -0.042, -0.026, dz - 0.008, dz + 0.008, mat_idx=1)
    add_box(bm, dx - 0.008, dx + 0.008, -0.042, -0.026, dz - 0.024, dz + 0.024, mat_idx=1)
    for bx, bz in ((0.030, -0.325), (0.058, -0.302)):
        add_prism_y(bm, ngon_pts(bx, bz, 0.014, 6), -0.043, -0.026, mat_idx=1)

    add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)

    bm_to_object("HighScore_Body", bm, [mat_body, mat_gold], coll, union=True, bevel_width=0.0)

    # Separate screen plate (uses mat_body to stay <= 3 materials, colored dark screen in Studio)
    bm_scr = bmesh.new()
    add_box(bm_scr, -scr_hx - 0.002, scr_hx + 0.002, -0.032, -0.022, scr_z0 - 0.002, scr_z1 + 0.002, mat_idx=0)
    bm_to_object("HighScore_Screen", bm_scr, [mat_body], coll, union=False, bevel_width=0.0)

    # Separate Neon LED power pip + accent bar
    bm_neon = bmesh.new()
    add_box(bm_neon, -0.018, 0.018, -0.039, -0.028, z_bot + 0.018, z_bot + 0.027, mat_idx=0)
    add_box(bm_neon, -0.080, -0.068, -0.041, -0.032, scr_z1 + 0.002, scr_z1 + 0.010, mat_idx=0)
    bm_to_object("HighScore_Neon", bm_neon, [mat_neon], coll, union=False, bevel_width=0.0)


BUILDERS = {
    "ArcadeToken": build_ArcadeToken,
    "IceCube": build_IceCube,
    "Joystick": build_Joystick,
    "PixelHeart": build_PixelHeart,
    "SnowflakeShard": build_SnowflakeShard,
    "GameCartridge": build_GameCartridge,
    "ThunderOrb": build_ThunderOrb,
    "HighScore": build_HighScore,
}


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
    add_area("KeyLight", (-0.75, -1.10, 0.35), t, 6.2, 0.85, (1.0, 0.98, 0.95))
    add_area("FillLight", (0.85, -0.85, -0.10), t, 2.8, 1.1, (0.82, 0.90, 1.0))
    add_area("RimLight", (0.45, 0.95, 0.30), t, 5.5, 0.75, (0.92, 0.96, 1.0))
    add_area("UnderBounce", (0.0, -0.45, -0.85), t, 1.4, 0.9, (0.88, 0.91, 1.0))

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


def main():
    os.makedirs(OUT_ROOT, exist_ok=True)
    report = {}
    for charm_id in CHARM_ORDER:
        scene = clear_scene()
        coll = bpy.data.collections.new(charm_id)
        scene.collection.children.link(coll)
        BUILDERS[charm_id](coll)
        cam, rig_coll = setup_render_rig(scene)

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


try:
    result = {"ok": True, "report": main()}
except Exception as e:
    result = {"ok": False, "error": str(e), "traceback": traceback.format_exc()}
