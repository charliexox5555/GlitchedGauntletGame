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
    ("Obsidian", "121720", 0.50, 0.30, 0.0),    # deep dark forged core, recesses, rail, sights
    ("Armor", "1E2634", 0.42, 0.58, 0.0),       # sculpted dark cold-slate metal chassis (Roblox Metal)
    ("FrostSteel", "586F8C", 0.32, 0.72, 0.0),  # crisp icy titanium ribs, clamps, collar (Metal)
    ("Grip", "171C26", 0.76, 0.00, 0.0),        # dark matte polymer grip & butt pad
    ("IceDeep", "1D588A", 0.24, 0.08, 0.0),     # deep glacial sapphire crystal root/core
    ("IceMid", "52B6E8", 0.20, 0.04, 0.0),      # primary vivid faceted glacier crystal
    ("IceBright", "BBEBFF", 0.16, 0.00, 0.0),   # frost-white crystal crown facets & sharp ridges
    ("CryoGlow", "9EEFFF", 0.25, 0.00, 1.25),   # restrained cold blue-white Neon seams (small)
    ("GlowWhite", "E4FAFF", 0.25, 0.00, 1.45),  # tiny ice-white core heart filament (Neon, minimal)
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


def loft(name, sections, roles, *, bone="Root", bevel=0, loop=False, cutter=False):
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


def polygon(center_u, center_v, radius, sides, phase=None):
    phase = math.pi / sides if phase is None else phase
    return [(center_u + radius * math.cos(phase + 2 * math.pi * i / sides),
             center_v + radius * math.sin(phase + 2 * math.pi * i / sides)) for i in range(sides)]


def prism_along(name, origin, axis, profile, roles, *, sides=8, bone="Root", bevel=0):
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
    return loft(name, sections, roles, bone=bone, bevel=bevel)


def _frame(axis):
    axis = axis.normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    return u, v


def _add_crystal_island(bm, base, tip, r_base, r_mid, *, sides=6, mid_t=0.45, crown_t=0.80,
                        r_crown=None, roles=(ICE_DEEP, ICE_MID, ICE_BRIGHT), twist=0.0,
                        flat_scale=(1.0, 0.66), chisel_lean=None):
    """Build one watertight, faceted glacial crystal spire with 3-tier shading."""
    base_v = Vector(base)
    tip_v = Vector(tip)
    span = tip_v - base_v
    length = span.length
    assert length > 1e-4
    axis = span / length
    u, v = _frame(axis)
    r_crown = (r_mid * 0.62) if r_crown is None else r_crown
    lean_vec = Vector(chisel_lean) if chisel_lean is not None else (u * (r_mid * 0.28))

    def make_ring(center, radius, phase):
        pts = polygon(0, 0, radius, sides, phase=phase)
        return [bm.verts.new(center + u * (a * flat_scale[0]) + v * (b * flat_scale[1])) for a, b in pts]

    r0 = make_ring(base_v, r_base, twist)
    r1 = make_ring(base_v + span * mid_t, r_mid, twist + 0.12)
    r2 = make_ring(base_v + span * crown_t + lean_vec * 0.35, r_crown, twist + 0.18)
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


def crystal_spike(name, base, tip, r_base, r_mid, *, bone="Root", **kwargs):
    """Single closed faceted glacial crystal spire."""
    bm = bmesh.new()
    _add_crystal_island(bm, base, tip, r_base, r_mid, **kwargs)
    return _object(name, bm, bone)


def crystal_cluster(name, specs, *, bone="Root", flat_group=None):
    """Multiple non-overlapping faceted spires combined into one mesh object."""
    bm = bmesh.new()
    for spec in specs:
        _add_crystal_island(bm, **spec)
    obj = _object(name, bm, bone)
    if flat_group:
        obj["flat_group"] = flat_group
    return obj


def crystal_blade(name, points_xz, near_y, far_y, ridge_y, *, roles=(ICE_DEEP, ICE_MID, ICE_BRIGHT),
                  bone="Root", flat_group=None):
    """Closed faceted crystal wedge/slab with chamfered ridge spine along (x, z) contour.
    points_xz: convex CCW loop in (x, z); builds a roofed ridge between near_y and far_y."""
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
