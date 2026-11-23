"""Shared construction and finish for the Slipframe v05 restyles."""

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix


SOURCE = Path(bpy.data.filepath)
ROOT = SOURCE.parents[4]
assert SOURCE.name == f"{GUN}_RemasterV2_v05.blend", SOURCE
DESTINATION = ROOT / "art-source/weapons/Skins/Slipframe" / GUN / VERSION / f"{GUN}_Slipframe_{VERSION}.blend"
assert not DESTINATION.exists(), DESTINATION

scene = bpy.context.scene
rig = bpy.data.objects[f"{GUN}_Rig"]
rig.data.pose_position = "REST"
bpy.context.view_layer.update()

shells = bpy.data.collections.new("COL_Slipframe")
cutters = bpy.data.collections.new("COL_Slipframe_Cutters")
scene.collection.children.link(shells)
scene.collection.children.link(cutters)
cutters.hide_render = True

SHELL, FRAME, FACE, SEAM, GRIP = range(5)
PALETTE = (
    ("Shell", "A1AEBB", 0.34, 0.68),
    ("Frame", "242A32", 0.56, 0.37),
    ("Face", "286AA3", 0.39, 0.57),
    ("Seam", "B9E0EF", 0.32, 0.61),
    ("Grip", "343B43", 0.70, 0.0),
)


def finish(role, color, roughness, metallic):
    rgb = [int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb) + (1.0,)
    material = bpy.data.materials.new(f"SF {role}")
    material["mf_hex"] = color
    material.diffuse_color = linear
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = linear
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return material


materials = [finish(*entry) for entry in PALETTE]
stock_finishes = {"Body": FRAME, "Panel": FRAME, "Dark": FRAME, "Metal": SHELL,
                  "Grip": GRIP, "Accent": FRAME, "Neon": SEAM}


def native(name):
    return bpy.data.objects[f"{GUN}_{name}"]


def replace(*names):
    for name in names:
        obj = native(name)
        obj.hide_set(True)
        obj.hide_render = True


def chamfer(obj, width):
    bevel = obj.modifiers.new("Planar chamfer", "BEVEL")
    bevel.width = width
    bevel.segments = 1
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(28)


def loft(name, sections, roles, *, bone="Root", bevel=0, loop=False, cutter=False):
    """Close authored sections into a volume or join a loop to form a through opening."""
    bm = bmesh.new()
    rings = [[bm.verts.new(point) for point in section] for section in sections]
    roles = [roles] * (len(rings) if loop else len(rings) - 1) if isinstance(roles, int) else roles
    count = len(rings[0])
    assert all(len(ring) == count for ring in rings), name
    starts = rings if loop else rings[:-1]
    ends = rings[1:] + ([rings[0]] if loop else [])
    pairs = zip(starts, ends, roles, strict=True)
    for start, end, role in pairs:
        for i in range(count):
            j = (i + 1) % count
            bm.faces.new((start[i], start[j], end[j], end[i])).material_index = role
    if not loop:
        bm.faces.new(list(reversed(rings[0]))).material_index = roles[0]
        bm.faces.new(rings[-1]).material_index = roles[-1]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
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
    sections = [[(x, y, z) for x, z in outline] for y in (near, far)]
    return loft(name, sections, role, **kwargs)


def recess(obj, name, outline, near, far, *, bone="Root"):
    tool = side(name, outline, near, far, FRAME, bone=bone, cutter=True)
    modifier = obj.modifiers.new(name, "BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.solver = "EXACT"
    modifier.object = tool


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


def boundary_loops(bm):
    remaining = {edge for edge in bm.edges if edge.is_boundary}
    while remaining:
        first = remaining.pop()
        start, vert = first.verts
        loop = [start]
        while vert != start:
            loop.append(vert)
            following = next((edge for edge in vert.link_edges if edge in remaining), None)
            if following is None:
                break
            remaining.remove(following)
            vert = following.other_vert(vert)
        if vert == start:
            yield loop


def bridge_boundary(bm, match):
    loops = [loop for loop in boundary_loops(bm) if match(loop)]
    assert len(loops) == 2, [[tuple(v.co) for v in loop] for loop in loops]
    edges = [bm.edges.get((a, b)) for loop in loops for a, b in zip(loop, loop[1:] + loop[:1])]
    assert bmesh.ops.bridge_loops(bm, edges=edges)["faces"]


def dress(name, *, slots=None, keep=None, shape=None, close=None, copy_name=None):
    """Keep bone and object transforms while repairing stock islands and refinishing surfaces."""
    obj = native(name)
    matrix = obj.matrix_world.copy()
    if copy_name:
        obj = obj.copy()
        obj.name = copy_name
        shells.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(matrix)
    if keep:
        discard = [v for island in components(bm) if not keep(island) for v in island]
        bmesh.ops.delete(bm, geom=discard, context="VERTS")
    if shape:
        for vert in bm.verts:
            shape(vert.co)
    if close:
        close(bm)
    boundaries = [edge for edge in bm.edges if edge.is_boundary]
    if boundaries:
        bmesh.ops.holes_fill(bm, edges=boundaries, sides=32)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
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


def limits(island, axis):
    values = [v.co[axis] for v in island]
    return min(values), max(values)


def paired_faces(obj, name, pocket, insert, floor, inside, face, *, bone="Root"):
    for sign, label in ((1, "Left"), (-1, "Right")):
        recess(obj, f"SF_{name}Seat_{label}", pocket, floor * sign, (face + 0.10) * sign, bone=bone)
        panel = side(f"SF_{name}_{label}", insert, inside * sign, face * sign, FACE, bone=bone, bevel=0.0015)
        panel["flat_group"] = f"SFForeEnd{label}"


def finish_master(primary):
    for collection in bpy.data.collections:
        if "ADSRange" in collection.name:
            collection.hide_render = True
            collection.hide_viewport = True
    scene["Slipframe_source"] = SOURCE.relative_to(ROOT).as_posix()
    scene["Slipframe_version"] = VERSION
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
