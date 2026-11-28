"""Shared construction and finish for the Frostbite line (Season 1 battle pass, Legendary).

Exec'd by each gun script with GUN and VERSION set. Opens nothing: the live
session must have the gun's stock RemasterV2 v05 open. New geometry is built
in rest-pose world coordinates and parented to the stock bone it rides on.
"""

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


SOURCE = Path(bpy.data.filepath)
ROOT = SOURCE.parents[4]
assert SOURCE.name == f"{GUN}_RemasterV2_v05.blend", SOURCE
DESTINATION = ROOT / "art-source/weapons/Skins/Frostbite" / GUN / VERSION / f"{GUN}_Frostbite_{VERSION}.blend"
assert not DESTINATION.exists(), DESTINATION

scene = bpy.context.scene
rig = bpy.data.objects[f"{GUN}_Rig"]
rig.data.pose_position = "REST"
bpy.context.view_layer.update()

shells = bpy.data.collections.new("COL_Frostbite")
cutters = bpy.data.collections.new("COL_Frostbite_Cutters")
scene.collection.children.link(shells)
scene.collection.children.link(cutters)
cutters.hide_render = True

# Role order is the material slot order on every new mesh.
(OBSIDIAN, ARMOR, FROSTSTEEL, GRIP, ICE_DEEP, ICE_MID, ICE_BRIGHT, CRYO_GLOW, GLOW_WHITE) = range(9)
# (role, hex, roughness, metallic, emission)
PALETTE = (
    ("Obsidian", "0F1520", 0.52, 0.28, 0.0),    # deep abyssal cold core, recesses, rail, sights
    ("Armor", "1C2536", 0.40, 0.60, 0.0),       # sculpted dark cryo-forged carapace (Metal)
    ("FrostSteel", "7A95B5", 0.28, 0.78, 0.0),  # bright brushed frost-silver exoskeleton swoop ribs (Metal)
    ("Grip", "171C26", 0.76, 0.00, 0.0),        # matte polymer grip & butt pad
    ("IceDeep", "16538A", 0.24, 0.08, 0.0),     # deep sapphire glacial fissure root (SmoothPlastic, 0.05 refl)
    ("IceMid", "3FB8F0", 0.18, 0.04, 0.0),      # vivid glacier-blue crystal facets (SmoothPlastic, 0.05 refl)
    ("IceBright", "D2F3FF", 0.15, 0.00, 0.0),   # razor-frosted snow-ice ridge highlights (SmoothPlastic, 0.12 refl)
    ("CryoGlow", "A6F2FF", 0.24, 0.00, 1.30),   # restrained cold blue-white inner fissure energy (Neon)
    ("GlowWhite", "ECFDFF", 0.24, 0.00, 1.50),  # pinpoint icy-white cryo-core heart (Neon)
)


def finish(role, color, roughness, metallic, emission):
    rgb = [int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb) + (1.0,)
    material = bpy.data.materials.new(f"FB {role}")
    material["mf_hex"] = color
    material.diffuse_color = linear
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = linear
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = linear
        bsdf.inputs["Emission Strength"].default_value = emission
    return material


materials = [finish(*entry) for entry in PALETTE]
stock_finishes = {
    "Body": ARMOR,
    "Panel": FROSTSTEEL,
    "Dark": OBSIDIAN,
    "Metal": FROSTSTEEL,
    "Grip": GRIP,
    "Accent": FROSTSTEEL,
    "Neon": CRYO_GLOW,
}


def native(name):
    return bpy.data.objects[f"{GUN}_{name}"]


def replace(*names):
    for name in names:
        obj = native(name)
        obj.hide_set(True)
        obj.hide_render = True


def chamfer(obj, width, angle=28):
    bevel = obj.modifiers.new("Planar chamfer", "BEVEL")
    bevel.width = width
    bevel.segments = 1
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(angle)
    bevel.harden_normals = False


def _object(name, bm, bone, cutter=False):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for face in bm.faces:
        face.smooth = False
    mesh = bpy.data.meshes.new(name)
    for material in materials:
        mesh.materials.append(material)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    (cutters if cutter else shells).objects.link(obj)
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = Matrix.Identity(4)
    if cutter:
        obj.hide_render = True
        obj.hide_set(True)
        obj.display_type = "WIRE"
    return obj


def loft(name, sections, roles, *, bone="Root", bevel=0, loop=False, cutter=False, flat_group=None):
    """Close authored sections into a volume, or join a loop of sections (a ring with a bore)."""
    bm = bmesh.new()
    rings = [[bm.verts.new(point) for point in section] for section in sections]
    roles = [roles] * (len(rings) if loop else len(rings) - 1) if isinstance(roles, int) else roles
    count = len(rings[0])
    assert all(len(ring) == count for ring in rings), name
    starts = rings if loop else rings[:-1]
    ends = rings[1:] + ([rings[0]] if loop else [])
    for start, end, role in zip(starts, ends, roles, strict=True):
        for i in range(count):
            j = (i + 1) % count
            bm.faces.new((start[i], start[j], end[j], end[i])).material_index = role
    if not loop:
        bm.faces.new(list(reversed(rings[0]))).material_index = roles[0]
        bm.faces.new(rings[-1]).material_index = roles[-1]
    obj = _object(name, bm, bone, cutter)
    if bevel:
        chamfer(obj, bevel)
    if flat_group:
        obj["flat_group"] = flat_group
    return obj


def fold(x, bottom, top, width, shoulder, keel, crown):
    return [(x, y, z) for y, z in (
        (-crown, top), (crown, top), (width, shoulder), (width, keel),
        (width * 0.67, bottom), (-width * 0.67, bottom), (-width, keel), (-width, shoulder),
    )]


def folded(name, sections, roles, **kwargs):
    return loft(name, [fold(*section) for section in sections], roles, **kwargs)


def side(name, outline, near, far, role, **kwargs):
    """Extrude an (x, z) outline between two y planes."""
    sections = [[(x, y, z) for x, z in outline] for y in (near, far)]
    return loft(name, sections, role, **kwargs)


def recess(obj, name, outline, near, far, *, role=OBSIDIAN, bone="Root"):
    """Cut a pocket; the pocket's floor and walls take the cutter's role colour."""
    tool = side(name, outline, near, far, role, bone=bone, cutter=True)
    modifier = obj.modifiers.new(name, "BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.solver = "EXACT"
    modifier.object = tool
    return tool


def swept_rib(name, path_pts, role, *, bone="Root", bevel=0, flat_group=None):
    """Loft a flowing 6-sided chamfered armor ribbon along 3D stations [(x, y, z, hw, ht), ...]."""
    sections = []
    pts = [Vector(p[:3]) for p in path_pts]
    n = len(pts)
    for idx, st in enumerate(path_pts):
        pos = Vector(st[:3])
        hw, ht = st[3], st[4]
        tang = (pts[min(n - 1, idx + 1)] - pts[max(0, idx - 1)]).normalized()
        lat = Vector((0, 1, 0))
        if abs(tang.dot(lat)) > 0.9:
            lat = Vector((0, 0, 1))
        normal = tang.cross(lat).normalized()
        side_v = normal.cross(tang).normalized()
        ring = [
            tuple(pos - side_v * hw - normal * (ht * 0.52)),
            tuple(pos - side_v * (hw * 0.62) - normal * ht),
            tuple(pos + side_v * (hw * 0.62) - normal * ht),
            tuple(pos + side_v * hw - normal * (ht * 0.52)),
            tuple(pos + side_v * hw + normal * (ht * 0.52)),
            tuple(pos + side_v * (hw * 0.62) + normal * ht),
            tuple(pos - side_v * (hw * 0.62) + normal * ht),
            tuple(pos - side_v * hw + normal * (ht * 0.52)),
        ]
        sections.append(ring)
    return loft(name, sections, role, bone=bone, bevel=bevel, flat_group=flat_group)


def armor_plate(name, points_xz, inner_y, outer_y, bevel_y, role, *, rim_role=None,
                inset=0.008, bone="Root", flat_group=None):
    """Closed sculpted chamfered armor plate along any sweeping (x, z) contour (0 modifier tris)."""
    bm = bmesh.new()
    n = len(points_xz)
    cx = sum(p[0] for p in points_xz) / n
    cz = sum(p[1] for p in points_xz) / n
    inner_pts = []
    for x, z in points_xz:
        dx, dz = x - cx, z - cz
        d = math.hypot(dx, dz)
        scale = max(0.25, (d - inset) / d) if d > 1e-5 else 0.5
        inner_pts.append((cx + dx * scale, cz + dz * scale))

    ring_back = [bm.verts.new((x, inner_y, z)) for x, z in points_xz]
    ring_edge = [bm.verts.new((x, outer_y, z)) for x, z in points_xz]
    ring_face = [bm.verts.new((x, bevel_y, z)) for x, z in inner_pts]
    c_back = bm.verts.new((cx, inner_y, cz))
    c_face = bm.verts.new((cx, bevel_y, cz))

    rim = role if rim_role is None else rim_role
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((c_back, ring_back[j], ring_back[i])).material_index = role
        bm.faces.new((ring_back[i], ring_back[j], ring_edge[j], ring_edge[i])).material_index = rim
        bm.faces.new((ring_edge[i], ring_edge[j], ring_face[j], ring_face[i])).material_index = rim
        bm.faces.new((ring_face[i], ring_face[j], c_face)).material_index = role

    obj = _object(name, bm, bone)
    if flat_group:
        obj["flat_group"] = flat_group
    return obj


def glacier_shard(name, points_xz, base_y, shoulder_y, crest_y, *,
                  roles=(ICE_DEEP, ICE_MID, ICE_BRIGHT), ridge_bias=(0.0, 0.0),
                  ridge_scale=0.38, bone="Root", flat_group=None):
    """Sculpted chiseled non-pencil glacier shard from an asymmetric jagged (x, z) contour."""
    bm = bmesh.new()
    n = len(points_xz)
    cx = sum(p[0] for p in points_xz) / n
    cz = sum(p[1] for p in points_xz) / n
    ax = cx + ridge_bias[0]
    az = cz + ridge_bias[1]
    crest_pts = [(ax + (x - ax) * ridge_scale, az + (z - az) * ridge_scale) for x, z in points_xz]

    ring_base = [bm.verts.new((x, base_y, z)) for x, z in points_xz]
    ring_sh = [bm.verts.new((x, shoulder_y, z)) for x, z in points_xz]
    ring_cr = [bm.verts.new((x, crest_y, z)) for x, z in crest_pts]
    c_base = bm.verts.new((cx, base_y, cz))
    sign = 1.0 if crest_y >= base_y else -1.0
    c_apex = bm.verts.new((ax, crest_y + 0.005 * sign, az))

    role_deep, role_mid, role_bright = roles
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((c_base, ring_base[j], ring_base[i])).material_index = role_deep
        bm.faces.new((ring_base[i], ring_base[j], ring_sh[j], ring_sh[i])).material_index = role_deep
        bm.faces.new((ring_sh[i], ring_sh[j], ring_cr[j], ring_cr[i])).material_index = role_mid
        bm.faces.new((ring_cr[i], ring_cr[j], c_apex)).material_index = role_bright

    obj = _object(name, bm, bone)
    if flat_group:
        obj["flat_group"] = flat_group
    return obj


def glacier_cluster(name, specs, *, bone="Root", flat_group=None):
    """Combine multiple chiseled glacier_shard polygons into one watertight mesh."""
    bm = bmesh.new()
    for sp in specs:
        pts = sp["points_xz"]
        n = len(pts)
        cx = sum(p[0] for p in pts) / n
        cz = sum(p[1] for p in pts) / n
        rb = sp.get("ridge_bias", (0.0, 0.0))
        rs = sp.get("ridge_scale", 0.38)
        ax, az = cx + rb[0], cz + rb[1]
        crest_pts = [(ax + (x - ax) * rs, az + (z - az) * rs) for x, z in pts]
        base_y, sh_y, cr_y = sp["base_y"], sp["shoulder_y"], sp["crest_y"]
        roles = sp.get("roles", (ICE_DEEP, ICE_MID, ICE_BRIGHT))
        r_base = [bm.verts.new((x, base_y, z)) for x, z in pts]
        r_sh = [bm.verts.new((x, sh_y, z)) for x, z in pts]
        r_cr = [bm.verts.new((x, cr_y, z)) for x, z in crest_pts]
        c_base = bm.verts.new((cx, base_y, cz))
        sign = 1.0 if cr_y >= base_y else -1.0
        c_apex = bm.verts.new((ax, cr_y + 0.004 * sign, az))
        rd, rm, rbr = roles
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((c_base, r_base[j], r_base[i])).material_index = rd
            bm.faces.new((r_base[i], r_base[j], r_sh[j], r_sh[i])).material_index = rd
            bm.faces.new((r_sh[i], r_sh[j], r_cr[j], r_cr[i])).material_index = rm
            bm.faces.new((r_cr[i], r_cr[j], c_apex)).material_index = rbr
    obj = _object(name, bm, bone)
    if flat_group:
        obj["flat_group"] = flat_group
    return obj


def polygon(center_u, center_v, radius, sides, phase=None):
    phase = math.pi / sides if phase is None else phase
    return [(center_u + radius * math.cos(phase + 2 * math.pi * i / sides),
             center_v + radius * math.sin(phase + 2 * math.pi * i / sides)) for i in range(sides)]


def prism_along(name, origin, axis, profile, roles, *, sides=8, bone="Root", bevel=0, flat_group=None):
    """Loft polygon profiles along an axis. profile = [(t, radius), ...], flat facets."""
    origin = Vector(origin)
    axis = Vector(axis).normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    sections = []
    for t, radius in profile:
        center = origin + axis * t
        sections.append([tuple(center + u * a + v * b) for a, b in polygon(0, 0, radius, sides)])
    return loft(name, sections, roles, bone=bone, bevel=bevel, flat_group=flat_group)


def _frame(axis):
    axis = axis.normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    return u, v


def _add_organic_crystal(bm, base, tip, r_base, r_mid, *, sides=5,
                         asym=(1.08, 0.76, 1.22, 0.68, 0.94),
                         mid_t=0.46, crown_t=0.80, r_crown=None,
                         roles=(ICE_DEEP, ICE_MID, ICE_BRIGHT), twist=0.0,
                         flat_scale=(1.0, 0.62), chisel_lean=None):
    """Build one asymmetric, irregularly faceted glacial crystal spire (flat-shaded, watertight)."""
    base_v = Vector(base)
    tip_v = Vector(tip)
    span = tip_v - base_v
    length = span.length
    assert length > 1e-4
    axis = span / length
    u, v = _frame(axis)
    r_crown = (r_mid * 0.58) if r_crown is None else r_crown
    lean_vec = Vector(chisel_lean) if chisel_lean is not None else (u * (r_mid * 0.34) + v * (r_mid * 0.14))

    def make_ring(center, radius, phase, taper_asym=1.0):
        out = []
        for i in range(sides):
            ang = phase + 2 * math.pi * i / sides
            scale_i = 1.0 + (asym[i % len(asym)] - 1.0) * taper_asym
            a = radius * scale_i * math.cos(ang) * flat_scale[0]
            b = radius * scale_i * math.sin(ang) * flat_scale[1]
            out.append(bm.verts.new(center + u * a + v * b))
        return out

    r0 = make_ring(base_v, r_base, twist, 0.7)
    r1 = make_ring(base_v + span * mid_t + lean_vec * 0.12, r_mid, twist + 0.14, 1.0)
    r2 = make_ring(base_v + span * crown_t + lean_vec * 0.48, r_crown, twist + 0.24, 1.15)
    apex = bm.verts.new(tip_v + lean_vec)

    role_deep, role_mid, role_bright = roles
    bm.faces.new(list(reversed(r0))).material_index = role_deep
    for start, end, role in ((r0, r1, role_deep), (r1, r2, role_mid)):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((start[i], start[j], end[j], end[i])).material_index = role
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((r2[i], r2[j], apex)).material_index = role_bright


def organic_crystal(name, base, tip, r_base, r_mid, *, bone="Root", flat_group=None, **kwargs):
    bm = bmesh.new()
    _add_organic_crystal(bm, base, tip, r_base, r_mid, **kwargs)
    obj = _object(name, bm, bone)
    if flat_group:
        obj["flat_group"] = flat_group
    return obj


def organic_cluster(name, specs, *, bone="Root", flat_group=None):
    """Multiple asymmetric glacial crystal spires combined into one mesh object."""
    bm = bmesh.new()
    for spec in specs:
        _add_organic_crystal(bm, **spec)
    obj = _object(name, bm, bone)
    if flat_group:
        obj["flat_group"] = flat_group
    return obj


def crystal_blade(name, points_xz, near_y, far_y, ridge_y, *, roles=(ICE_DEEP, ICE_MID, ICE_BRIGHT),
                  bone="Root", flat_group=None):
    """Closed faceted crystal wedge/slab with chamfered ridge spine along (x, z) contour."""
    bm = bmesh.new()
    n = len(points_xz)
    cx = sum(p[0] for p in points_xz) / n
    cz = sum(p[1] for p in points_xz) / n
    inner_pts = [(cx + (x - cx) * 0.56, cz + (z - cz) * 0.56) for x, z in points_xz]

    ring_near = [bm.verts.new((x, near_y, z)) for x, z in points_xz]
    ring_far = [bm.verts.new((x, far_y, z)) for x, z in points_xz]
    ridge_far = [bm.verts.new((x, ridge_y, z)) for x, z in inner_pts]
    c_near = bm.verts.new((cx, near_y, cz))
    c_ridge = bm.verts.new((cx, ridge_y + (0.005 if ridge_y > near_y else -0.005), cz))

    role_deep, role_mid, role_bright = roles
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((c_near, ring_near[j], ring_near[i])).material_index = role_deep
        bm.faces.new((ring_near[i], ring_near[j], ring_far[j], ring_far[i])).material_index = role_deep
        bm.faces.new((ring_far[i], ring_far[j], ridge_far[j], ridge_far[i])).material_index = role_mid
        bm.faces.new((ridge_far[i], ridge_far[j], c_ridge)).material_index = role_bright

    obj = _object(name, bm, bone)
    if flat_group:
        obj["flat_group"] = flat_group
    return obj


def components(bm):
    unseen = set(bm.verts)
    while unseen:
        island = [unseen.pop()]
        for vert in island:
            for edge in vert.link_edges:
                neighbor = edge.other_vert(vert)
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    island.append(neighbor)
        yield island


def limits(island, axis):
    values = [v.co[axis] for v in island]
    return min(values), max(values)


def dress(name, *, slots=None, keep=None, copy_name=None):
    """Keep bone and object transforms while removing replaced islands and refinishing surfaces."""
    obj = native(name)
    matrix = obj.matrix_world.copy()
    if copy_name:
        obj = obj.copy()
        obj.name = copy_name
        obj.hide_render = False
        shells.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(matrix)
    if keep:
        discard = [v for island in list(components(bm)) if not keep(island) for v in island]
        bmesh.ops.delete(bm, geom=discard, context="VERTS")
    for face in bm.faces:
        face.smooth = False
    bm.transform(matrix.inverted())
    obj.data = obj.data.copy()
    bm.to_mesh(obj.data)
    bm.free()
    finish_map = {**stock_finishes, **(slots or {})}
    for slot in obj.material_slots:
        if slot.material and slot.material.name in finish_map:
            slot.material = materials[finish_map[slot.material.name]]
    return obj


def nudge(obj, pick, delta, island=None):
    """Move vertices of a retained part that pick(world point) selects (rest pose, world space)."""
    matrix = obj.matrix_world
    inverse = matrix.inverted()
    allowed = None
    if island:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        allowed = set()
        for group in components(bm):
            points = [matrix @ v.co for v in group]
            lo = Vector([min(p[i] for p in points) for i in range(3)])
            hi = Vector([max(p[i] for p in points) for i in range(3)])
            if island(lo, hi):
                allowed.update(v.index for v in group)
        bm.free()
    moved = 0
    for vertex in obj.data.vertices:
        if allowed is not None and vertex.index not in allowed:
            continue
        point = matrix @ vertex.co
        if pick(point):
            vertex.co = inverse @ (point + Vector(delta))
            moved += 1
    obj.data.update()
    return moved


def surface_y(x, z, sign=1, ignore=()):
    """Outer face depth of the visible gun at (x, z), measured from the +y (sign 1) or -y side."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    hit, location, _n, _i, obj, _m = scene.ray_cast(depsgraph, Vector((x, sign * 1.0, z)), Vector((0, -sign, 0)))
    while hit and obj.name in ignore:
        hit, location, _n, _i, obj, _m = scene.ray_cast(depsgraph, location - Vector((0, sign * 1e-4, 0)), Vector((0, -sign, 0)))
    return (round(location.y, 4), obj.name) if hit else (None, None)


def finish_master(primary):
    for collection in bpy.data.collections:
        if "ADSRange" in collection.name:
            collection.hide_render = True
            collection.hide_viewport = True
    scene["Frostbite_source"] = SOURCE.relative_to(ROOT).as_posix()
    scene["Frostbite_version"] = VERSION
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    primary.select_set(True)
    bpy.context.view_layer.objects.active = primary
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.shading.color_type = "MATERIAL"
                area.spaces.active.overlay.show_extras = False
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(DESTINATION))
    return {"file": str(DESTINATION), "new_meshes": len(shells.objects), "cutters": len(cutters.objects)}
