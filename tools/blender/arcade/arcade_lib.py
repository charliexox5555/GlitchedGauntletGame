"""Shared construction and finish for the Arcade line (Season 1 battle pass, Rare).

Exec'd by each gun script with GUN and VERSION set. Opens nothing: the live
session must have the gun's stock RemasterV2 v05 open. New geometry is built
in rest-pose world coordinates and parented to the stock bone it rides on.
Adapted from tools/blender/rework_slipframe/roster_lib.py (owner-approved method).
"""

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


SOURCE = Path(bpy.data.filepath)
ROOT = SOURCE.parents[4]
assert SOURCE.name == f"{GUN}_RemasterV2_v05.blend", SOURCE
DESTINATION = ROOT / "art-source/weapons/Skins/Arcade" / GUN / VERSION / f"{GUN}_Arcade_{VERSION}.blend"
assert not DESTINATION.exists(), DESTINATION

scene = bpy.context.scene
rig = bpy.data.objects[f"{GUN}_Rig"]
rig.data.pose_position = "REST"
bpy.context.view_layer.update()

shells = bpy.data.collections.new("COL_Arcade")
cutters = bpy.data.collections.new("COL_Arcade_Cutters")
scene.collection.children.link(shells)
scene.collection.children.link(cutters)
cutters.hide_render = True

# Role order is the material slot order on every new mesh.
(BODY, PANEL, DARK, GRIP, METAL, ACCENT, SCREEN,
 MAGENTA, CYAN, YELLOW, BTN_MAGENTA, BTN_CYAN, BTN_YELLOW) = range(13)
# (role, hex, roughness, metallic, emission)
PALETTE = (
    ("Body", "2C1650", 0.46, 0.12, 0.0),        # deep cabinet purple
    ("Panel", "47297C", 0.52, 0.08, 0.0),       # side-art field violet
    ("Dark", "17121F", 0.55, 0.10, 0.0),        # bezels, rail, sights
    ("Grip", "1E1929", 0.78, 0.0, 0.0),         # polymer
    ("Metal", "2D3040", 0.34, 0.70, 0.0),       # barrel, brake
    ("Accent", "6F6890", 0.42, 0.30, 0.0),      # lilac nickel: pins, knob
    ("Screen", "12234A", 0.30, 0.0, 0.8),       # glowing pixel screen floor (Neon, never Glass)
    ("Magenta", "E01E8C", 0.40, 0.0, 1.3),      # Neon
    ("Cyan", "14C8DC", 0.40, 0.0, 1.3),         # Neon
    ("Yellow", "F5C518", 0.40, 0.0, 1.3),       # Neon, small
    ("BtnMagenta", "E8338F", 0.32, 0.0, 0.0),   # arcade button plastics
    ("BtnCyan", "1FB8D2", 0.32, 0.0, 0.0),
    ("BtnYellow", "F2C230", 0.32, 0.0, 0.0),
)


def finish(role, color, roughness, metallic, emission):
    rgb = [int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb) + (1.0,)
    material = bpy.data.materials.new(f"AR {role}")
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
stock_finishes = {"Body": BODY, "Panel": PANEL, "Dark": DARK, "Metal": METAL,
                  "Grip": GRIP, "Accent": ACCENT, "Neon": CYAN}


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


def recess(obj, name, outline, near, far, *, role=DARK, bone="Root"):
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


def prism_along(name, origin, axis, profile, roles, *, bone="Root", bevel=0):
    """Loft polygon profiles along an axis. profile = [(t, radius), ...], 8 sides, flat facets."""
    origin = Vector(origin)
    axis = Vector(axis).normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    sections = []
    for t, radius in profile:
        center = origin + axis * t
        sections.append([tuple(center + u * a + v * b) for a, b in polygon(0, 0, radius, 8)])
    return loft(name, sections, roles, bone=bone, bevel=bevel)


def star(cu, cv, outer, inner, points=8, phase=math.pi / 2):
    out = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = phase + math.pi * i / points
        out.append((cu + r * math.cos(a), cv + r * math.sin(a)))
    return out


def plate(name, outline, near, far, role, *, bone="Root"):
    """A seated plate: extrude a convex or star outline with a centre fan (no ngon crossings)."""
    bm = bmesh.new()
    faces = []
    for y in (near, far):
        cx = sum(p[0] for p in outline) / len(outline)
        cz = sum(p[1] for p in outline) / len(outline)
        center = bm.verts.new((cx, y, cz))
        ring = [bm.verts.new((x, y, z)) for x, z in outline]
        faces.append((center, ring))
    (c0, r0), (c1, r1) = faces
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((c0, r0[j], r0[i])).material_index = role
        bm.faces.new((c1, r1[i], r1[j])).material_index = role
        bm.faces.new((r0[i], r0[j], r1[j], r1[i])).material_index = role
    return _object(name, bm, bone)


def pixel_solid(name, cells, origin_x, origin_z, size, near, far, role, *, bone="Root"):
    """One closed solid from a pixel grid: cells = set of (col, row) with row 0 at the bottom."""
    bm = bmesh.new()
    grid = {}

    def vert(i, k):
        if (i, k) not in grid:
            grid[(i, k)] = bm.verts.new((origin_x + i * size, near, origin_z + k * size))
        return grid[(i, k)]

    top = [bm.faces.new((vert(c, r), vert(c + 1, r), vert(c + 1, r + 1), vert(c, r + 1))) for c, r in cells]
    extruded = bmesh.ops.extrude_face_region(bm, geom=top)
    moved = [g for g in extruded["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0, far - near, 0))
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1), verts=bm.verts[:], edges=bm.edges[:])
    for face in bm.faces:
        face.material_index = role
    return _object(name, bm, bone)


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
    scene["Arcade_source"] = SOURCE.relative_to(ROOT).as_posix()
    scene["Arcade_version"] = VERSION
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
