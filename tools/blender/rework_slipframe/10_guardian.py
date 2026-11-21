"""Build Slipframe Guardian in the live Blender session from the open v05 file."""

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


GUN = "Guardian"
VERSION = globals().get("VERSION", "r05")
SOURCE = Path(bpy.data.filepath)
assert SOURCE.name == "Guardian_RemasterV2_v05.blend", SOURCE
ROOT = SOURCE.parents[4]
DESTINATION = ROOT / "art-source/weapons/Skins/Slipframe/Guardian" / VERSION / f"Guardian_Slipframe_{VERSION}.blend"
assert not DESTINATION.exists(), DESTINATION

scene = bpy.context.scene
stock = bpy.data.collections[GUN]
rig = bpy.data.objects[f"{GUN}_Rig"]
rig.data.pose_position = "REST"
bpy.context.view_layer.update()


def collection(name):
    group = bpy.data.collections.new(name)
    scene.collection.children.link(group)
    return group


shells = collection("COL_Slipframe")
cutters = collection("COL_Slipframe_Cutters")
cutters.hide_render = True


def finish(role, color, roughness, metallic):
    rgb = [int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = tuple(c / 12.92 if c < 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb) + (1.0,)
    material = bpy.data.materials.new(f"SF {role}")
    material["mf_hex"] = color
    material.diffuse_color = linear
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = linear
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return material


materials = {
    "Shell": finish("Shell", "A1AEBB", 0.34, 0.68),
    "Frame": finish("Frame", "242A32", 0.56, 0.37),
    "Face": finish("Face", "286AA3", 0.39, 0.57),
    "Seam": finish("Seam", "B9E0EF", 0.32, 0.61),
    "Grip": finish("Grip", "343B43", 0.70, 0.0),
}


def native(name):
    return bpy.data.objects[f"{GUN}_{name}"]


def replace(name):
    obj = native(name)
    obj.hide_set(True)
    obj.hide_render = True


def chamfer(obj, width, angle=28):
    bevel = obj.modifiers.new("Planar chamfer", "BEVEL")
    bevel.width = width
    bevel.segments = 1
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(angle)
    bevel.use_clamp_overlap = True


def make_mesh(name, rings, roles, *, host="Receiver", bevel=0, cutter=False, loop=False):
    """Join authored cross-sections. Closed loops form shrouds around an opening."""
    section_size = len(rings[0])
    assert all(len(ring) == section_size for ring in rings), name
    bm = bmesh.new()
    sections = [[bm.verts.new(point) for point in ring] for ring in rings]
    pairs = zip(sections, sections[1:] + ([sections[0]] if loop else []))
    for index, (start, end) in enumerate(pairs):
        for k in range(section_size):
            n = (k + 1) % section_size
            face = bm.faces.new((start[k], start[n], end[n], end[k]))
            face.material_index = roles[index]
    if not loop:
        bm.faces.new(list(reversed(sections[0])))
        bm.faces.new(sections[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    for material in materials.values():
        mesh.materials.append(material)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    (cutters if cutter else shells).objects.link(obj)
    ref = native(host)
    obj.parent = ref.parent
    obj.parent_type = ref.parent_type
    obj.parent_bone = ref.parent_bone
    bpy.context.view_layer.update()
    obj.matrix_world = Matrix.Identity(4)
    if cutter:
        obj.hide_render = True
        obj.hide_set(True)
        obj.display_type = "WIRE"
    if bevel:
        chamfer(obj, bevel)
    return obj


SHELL, FRAME, FACE, SEAM, GRIP = range(5)


def side_section(outline, y):
    return [(x, y, z) for x, z in outline]


def panel(name, outline, near, far, role, **kwargs):
    obj = make_mesh(name, [side_section(outline, near), side_section(outline, far)], [role], **kwargs)
    for polygon in obj.data.polygons:
        polygon.material_index = role
    return obj


def pocket(obj, name, outline, near, far):
    tool = panel(name, outline, near, far, FRAME, cutter=True)
    difference = obj.modifiers.new(name, "BOOLEAN")
    difference.operation = "DIFFERENCE"
    difference.solver = "EXACT"
    difference.object = tool
    difference.material_mode = "INDEX"


def islands(bm):
    remaining = set(bm.verts)
    while remaining:
        root = remaining.pop()
        component = [root]
        for vert in component:
            for edge in vert.link_edges:
                neighbor = edge.other_vert(vert)
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    component.append(neighbor)
        yield component


def boundary_loops(bm):
    remaining = {edge for edge in bm.edges if edge.is_boundary}
    while remaining:
        edge = remaining.pop()
        first, next_vert = edge.verts
        loop = [first]
        while next_vert != first:
            loop.append(next_vert)
            following = next((e for e in next_vert.link_edges if e in remaining), None)
            if following is None:
                break
            remaining.remove(following)
            next_vert = following.other_vert(next_vert)
        if next_vert == first:
            yield loop


def close_receiver(bm):
    # The stock lower receiver's two nested loops are the magazine opening.
    # Span the annulus and leave the interior of the magazine passage clear.
    nested = [loop for loop in boundary_loops(bm) if len(loop) == 4 and
              all(abs(v.co.z - 0.2336) < 0.00005 for v in loop)]
    assert len(nested) == 2, [{v.co[:] for v in loop} for loop in nested]

    def by_corner(loop):
        left = sorted((v for v in loop if v.co.y > 0), key=lambda v: v.co.x)
        right = sorted((v for v in loop if v.co.y < 0), key=lambda v: -v.co.x)
        return left + right

    first, second = map(by_corner, nested)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((first[i], first[j], second[j], second[i]))


def close_grip(bm):
    opening, = boundary_loops(bm)
    # The boundary follows the existing swept back of the trigger guard. Bridge
    # matched points across the grip so the closure keeps that shape.
    left = sorted((v for v in opening if v.co.y > 0), key=lambda v: v.co.x)
    right = sorted((v for v in opening if v.co.y < 0), key=lambda v: v.co.x)
    assert len(left) == len(right) == 4
    for i, j in ((0, 3), (3, 1), (1, 2)):
        bm.faces.new((left[i], right[i], right[j], left[j]))


def dress_stock(name, slots, keep=lambda vertices: True, dx=None):
    """Refinish stock geometry while keeping its object and bone transforms."""
    obj = native(name)
    matrix = obj.matrix_world.copy()
    inverse = matrix.inverted()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(matrix)
    discarded = [v for component in islands(bm) if not keep(component) for v in component]
    bmesh.ops.delete(bm, geom=discarded, context="VERTS")
    if dx:
        for vert in bm.verts:
            dx(vert.co)
    for face in bm.faces:
        face.smooth = False
    if name == "Receiver":
        close_receiver(bm)
    if name == "Grip":
        close_grip(bm)
    boundaries = [edge for edge in bm.edges if edge.is_boundary]
    if boundaries:
        bmesh.ops.holes_fill(bm, edges=boundaries, sides=32)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.transform(inverse)
    obj.data = obj.data.copy()
    bm.to_mesh(obj.data)
    bm.free()
    for slot in obj.material_slots:
        if slot.material and slot.material.name in slots:
            slot.material = materials[slots[slot.material.name]]
    obj.data.update()
    return obj


# Preserve the original action, rail and underside. The front block is now part
# of the titanium fore-end, so the original block and its two pin pairs come off.
dress_stock("Receiver", {"Body": "Frame", "Dark": "Frame"},
            lambda part: not (0.875 < min(v.co.x for v in part) < 0.88
                              and max(abs(v.co.y) for v in part) > 0.085))
dress_stock("Pins", {"Metal": "Shell"}, lambda part: 0 < part[0].co.x < 0.45)
dress_stock("Bolt", {"Metal": "Shell"})
dress_stock("BoltCatch", {"Metal": "Shell"})
dress_stock("ChargingHandle", {"Metal": "Frame", "Accent": "Shell"})
dress_stock("FireSelector", {"Metal": "Frame", "Accent": "Shell"})
dress_stock("Trigger", {"Metal": "Frame"})
dress_stock("CharmLoop", {"Metal": "Shell", "Dark": "Frame"})
replace("Handguard")
replace("Neon")


def folded_section(x, bottom, top, width, shoulder, keel, crown):
    return [(x, y, z) for y, z in (
        (-crown, top), (crown, top), (width, shoulder), (width, keel),
        (width * 0.67, bottom), (-width * 0.67, bottom), (-width, keel), (-width, shoulder),
    )]


# The section transitions continuously from a neck buried in the stock action
# to folded shoulders, then closes over the barrel seat at the nose.
fore_end = make_mesh("SF_TitaniumShroud", [folded_section(*section) for section in (
    (0.014, 0.386, 0.416, 0.060, 0.408, 0.398, 0.035),
    (0.145, 0.381, 0.444, 0.098, 0.428, 0.385, 0.058),
    (0.806, 0.381, 0.444, 0.098, 0.428, 0.385, 0.058),
    (0.934, 0.280, 0.444, 0.098, 0.414, 0.309, 0.058),
    (1.119, 0.190, 0.444, 0.098, 0.414, 0.244, 0.058),
    (2.160, 0.190, 0.444, 0.098, 0.414, 0.244, 0.058),
    (2.362, 0.288, 0.425, 0.054, 0.402, 0.307, 0.033),
)], [SHELL] * 6)

pocket_outline = [(1.129, 0.338), (1.208, 0.397), (2.166, 0.397), (2.106, 0.295), (1.129, 0.295)]
face_outline = [(1.141, 0.341), (1.213, 0.388), (2.150, 0.388), (2.100, 0.305), (1.141, 0.305)]
for sign, label in ((1, "Left"), (-1, "Right")):
    pocket(fore_end, f"SF_{label}FaceSeat", pocket_outline, 0.079 * sign, 0.126 * sign)
    panel(f"SF_ShellPanel_{label}", face_outline, 0.076 * sign, 0.092 * sign, FACE, bevel=0.0018)
    # Two raked reliefs are cut into the lower fold, below the broad blue face.
    for index, x in enumerate((1.468, 1.731), 1):
        offset = -0.004 if index == 2 else -0.008
        outline = [(x, 0.251 + offset), (x + 0.032, 0.269 + offset),
                   (x + 0.188, 0.269 + offset), (x + 0.153, 0.251 + offset)]
        pocket(fore_end, f"SF_{label}LowerRelief{index}", outline, 0.077 * sign, 0.115 * sign)

# The inspect insert and its inlay sit on the shoulder closest to the held
# camera. The nose of the slot ends under a solid bridge in the titanium.
shoulder_seat = [(0.190, 0.400), (0.240, 0.422), (0.825, 0.422), (0.801, 0.390), (0.208, 0.390)]
pocket(fore_end, "SF_InspectInsertSeat_Left", shoulder_seat, 0.084, 0.119)
panel("SF_InspectSlidingPanel_Left", [(0.205, 0.402), (0.245, 0.417), (0.813, 0.417),
      (0.802, 0.401), (0.218, 0.401)], 0.081, 0.093, FACE, bevel=0.0013)
panel("SF_SeamInlay_Left", [(0.230, 0.393), (0.244, 0.398), (0.780, 0.398), (0.774, 0.393)],
      0.082, 0.089, SEAM, bevel=0.0007)
# The shroud's edge treatment is the authored fold at every station. A global
# bevel collides with the edge of the thin receiver shoulder and relief walls.


# Keep the trigger finger and palm contact surfaces. Rake the end of the existing
# grip slightly and swap to a matte grip finish. The magazine retains its bone,
# top cartridge and insertion envelope; the heel is recut below the magwell.
def rake_grip(point):
    weight = max(0.0, min(1.0, (-point.z - 0.174) / 0.133))
    point.x += 0.012 * weight
    point.y *= 1 - 0.09 * weight


dress_stock("Grip", {"Dark": "Frame", "Grip": "Grip"}, dx=rake_grip)
dress_stock("Mag", {"Dark": "Frame", "Panel": "Shell", "Neon": "Frame"},
            lambda part: max(v.co.z for v in part) > -0.165 and len(part) > 8)
panel("SF_Mag_FoldedHeel", [(0.504, -0.164), (0.795, -0.164), (0.816, -0.182),
                           (0.801, -0.205), (0.532, -0.205), (0.490, -0.183)],
      -0.065, 0.065, SHELL, host="Mag", bevel=0.005)


# Preserve the shoulder pad exactly and give the skeleton a more open raked
# frame. Both stock rails terminate within the new frame and receiver.
dress_stock("Stock", {"Dark": "Frame", "Grip": "Grip", "Metal": "Shell"},
            lambda part: max(v.co.x for v in part) < -1.05 or min(v.co.x for v in part) > -0.365)
stock_frame = panel("SF_Stock_FoldedFrame", [(-1.114, -0.146), (-1.100, 0.401), (-0.977, 0.428),
                                            (-0.614, 0.428), (-0.385, 0.386), (-0.315, 0.352),
                                            (-0.329, 0.281), (-0.958, -0.132), (-1.057, -0.155)],
                    -0.068, 0.068, SHELL, host="Stock")
pocket(stock_frame, "SF_StockFrameOpening", [(-1.060, -0.071), (-1.059, 0.335), (-0.975, 0.365),
                                             (-0.605, 0.365), (-0.479, 0.321), (-1.015, -0.041)], -0.091, 0.091)
chamfer(stock_frame, 0.007)


# Replace the stock front cluster with an exposed dark shaft and a hand-shaped
# cosmetic nose. The dark inner face is part of the visible model silhouette.
replace("Barrel")
barrel = make_mesh("SF_Barrel", [folded_section(*section) for section in (
    (2.313, 0.331, 0.407, 0.038, 0.396, 0.344, 0.024),
    (2.394, 0.331, 0.407, 0.038, 0.396, 0.344, 0.024),
    (2.438, 0.338, 0.400, 0.031, 0.389, 0.350, 0.019),
    (2.782, 0.338, 0.400, 0.031, 0.389, 0.350, 0.019),
    (2.842, 0.329, 0.407, 0.038, 0.396, 0.341, 0.024),
)], [FRAME] * 4)
for polygon in barrel.data.polygons:
    polygon.material_index = FRAME
make_mesh("SF_Brake_Crown", [folded_section(*section) for section in (
    (2.759, 0.338, 0.402, 0.032, 0.391, 0.348, 0.022),
    (2.804, 0.318, 0.421, 0.046, 0.412, 0.326, 0.039),
    (2.881, 0.318, 0.421, 0.053, 0.412, 0.326, 0.044),
    (2.942, 0.318, 0.421, 0.053, 0.412, 0.326, 0.044),
    (2.9984, 0.331, 0.415, 0.042, 0.408, 0.337, 0.035),
    (2.9984, 0.348, 0.389, 0.023, 0.384, 0.352, 0.018),
    (2.913, 0.347, 0.389, 0.021, 0.381, 0.355, 0.014),
    (2.775, 0.348, 0.387, 0.020, 0.378, 0.356, 0.013),
)], [FRAME, SHELL, SHELL, SHELL, SHELL, FRAME, FRAME, FRAME], loop=True)


# Preserve the stock post and mark. The front sight wings and foot are a
# single raked saddle, with its underside buried inside the titanium shroud.
dress_stock("Sights", {"Metal": "Frame", "Neon": "Seam"},
            lambda part: min(v.co.x for v in part) > 2.0 and max(abs(v.co.y) for v in part) < 0.006)

front_profile = [(-0.028, 0.410), (0.028, 0.410), (0.041, 0.443),
                 (0.036, 0.491), (0.028, 0.516), (0.019, 0.520), (0.013, 0.503),
                 (0.012, 0.470), (-0.012, 0.470), (-0.013, 0.503), (-0.019, 0.520),
                 (-0.028, 0.516), (-0.036, 0.491), (-0.041, 0.443)]
rear_face = [(2.207 + 0.42 * (z - 0.410), y, z) for y, z in front_profile]
front_face = [(2.303 - 0.28 * (z - 0.410), y, z) for y, z in front_profile]
front = make_mesh("SF_FrontSight_Saddle", [rear_face, front_face], [FRAME])
for polygon in front.data.polygons:
    polygon.material_index = FRAME


def sight_section(x, profile):
    return [(x, y, z) for y, z in profile]


outer = [(-0.023, 0.420), (0.023, 0.420), (0.053, 0.454), (0.052, 0.524),
         (0.035, 0.543), (-0.035, 0.543), (-0.052, 0.524), (-0.053, 0.454)]
inner = [(-0.025, 0.458), (0.025, 0.458), (0.042, 0.475), (0.041, 0.520),
         (0.030, 0.532), (-0.030, 0.532), (-0.041, 0.520), (-0.042, 0.475)]
face = [(y * 0.96, 0.485 + (z - 0.485) * 0.96) for y, z in outer]
make_mesh("SF_RearSight_Hood", [sight_section(x, profile) for x, profile in
          ((0.1258, face), (0.1288, outer), (0.1463, outer), (0.1493, face),
           (0.1493, inner), (0.1258, inner))], [SHELL, FRAME, SHELL, FRAME, FRAME, FRAME], loop=True)


for group in bpy.data.collections:
    if "ADSRange" in group.name:
        group.hide_render = True
        group.hide_viewport = True

scene["Slipframe_source"] = str(SOURCE.relative_to(ROOT))
scene["Slipframe_version"] = VERSION
bpy.context.view_layer.update()
bpy.ops.object.select_all(action="DESELECT")
fore_end.select_set(True)
bpy.context.view_layer.objects.active = fore_end
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.shading.color_type = "MATERIAL"
            area.spaces.active.overlay.show_extras = False
DESTINATION.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(DESTINATION))
result = {"file": str(DESTINATION), "new_meshes": len(shells.objects), "cutters": len(cutters.objects)}
