"""Build the editable Slipframe Arc master from the open RemasterV2 Knife file."""

import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


SOURCE = Path(bpy.data.filepath)
assert SOURCE.name == "Knife_RemasterV2_v05.blend", SOURCE
EDITION = globals().get("ARC_EDITION", "hd01")
assert EDITION in {"hd01", "r01"}, EDITION
OPTIMIZED = EDITION == "r01"
OUTPUT = SOURCE.parents[4] / "art-source/weapons/Skins/Slipframe/Knife/Arc" / EDITION
MASTER = OUTPUT / f"Knife_Slipframe_Arc_{EDITION}.blend"
assert not MASTER.exists(), MASTER

SCENE = bpy.context.scene
RIG = bpy.data.objects["Knife_Rig"]
ROOT_BONE = bpy.data.objects["Knife_Blade"].parent_bone
assert ROOT_BONE in RIG.data.bones
RIG.data.pose_position = "REST"
bpy.context.view_layer.update()


def collection(name):
    group = bpy.data.collections.new(name)
    SCENE.collection.children.link(group)
    return group


HILT = collection("Arc · Hilt")
BLADE = collection("Arc · Blade")
TOOLS = collection("Arc · Machining tools")
TOOLS.hide_render = True


def material(name, color, metallic, roughness):
    def linear(c):
        c /= 255
        return c / 12.92 if c < .04045 else ((c + .055) / 1.055) ** 2.4

    rgba = tuple(linear(int(color[i:i+2], 16)) for i in (0, 2, 4)) + (1.0,)
    mat = bpy.data.materials.new(f"Arc · {name}")
    mat["mf_hex"] = color
    mat.diffuse_color = rgba
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    surface = nodes.get("Principled BSDF")
    surface.inputs["Base Color"].default_value = rgba
    surface.inputs["Metallic"].default_value = metallic
    surface.inputs["Roughness"].default_value = roughness
    if name in {"Satin titanium", "Graphite grip", "Anodized cobalt"}:
        grain = nodes.new("ShaderNodeTexNoise")
        grain.inputs["Scale"].default_value = 285
        spread = nodes.new("ShaderNodeMapRange")
        spread.inputs["To Min"].default_value = roughness - .035
        spread.inputs["To Max"].default_value = roughness + .035
        mat.node_tree.links.new(grain.outputs["Fac"], spread.inputs["Value"])
        mat.node_tree.links.new(spread.outputs["Result"], surface.inputs["Roughness"])
        if name == "Anodized cobalt":
            surface.inputs["Coat Weight"].default_value = .34
            surface.inputs["Coat Roughness"].default_value = .23
    return mat


MATERIALS = [
    material("Satin titanium", "A1AEBB", .74, .38 if OPTIMIZED else .32),
    material("Polished edge", "C8D5E1", .80, .31 if OPTIMIZED else .23),
    material("Smoked alloy", "394654", .62, .36),
    material("Graphite grip", "313840", .12, .55),
    material("Anodized cobalt", "276DAB", .59, .31),
    material("Recess wall", "1C2630", .26, .47),
    material("Ice inlay", "9CD9ED", .38, .30),
    material("Dark cobalt", "173E66", .52, .40),
]
TITANIUM, EDGE, ALLOY, GRIP, COBALT, POCKET, ICE, DEEP_BLUE = range(len(MATERIALS))
PARTS = []


def bind(obj, bone):
    assert bone in RIG.data.bones, bone
    obj.parent = RIG
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = Matrix.Identity(4)


def loft(name, rings, face_roles, caps, group, bone, *, smooth=()):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    stations = [[bm.verts.new(co) for co in ring] for ring in rings]
    for slot, (start, end) in enumerate(zip(stations, stations[1:])):
        for side in range(len(start)):
            following = (side + 1) % len(start)
            face = bm.faces.new((start[side], start[following], end[following], end[side]))
            face.material_index = face_roles(slot, side)
            face.smooth = side in smooth
    bm.faces.new(stations[0][::-1]).material_index = caps[0]
    bm.faces.new(stations[-1]).material_index = caps[1]
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if bm.calc_volume(signed=True) < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    for edge in bm.edges:
        edge.smooth = edge.is_manifold and all(face.smooth for face in edge.link_faces)
    bm.to_mesh(mesh)
    bm.free()
    for mat in MATERIALS:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    group.objects.link(obj)
    bind(obj, bone)
    if group == TOOLS:
        obj.hide_set(True)
        obj.hide_render = True
        obj.display_type = "WIRE"
    else:
        PARTS.append(obj)
    return obj


def sample_profile(rows, step):
    """Sample each dimension with monotonic Hermite interpolation."""
    def slopes(coords, values):
        secants = [(b - a) / (right - left)
                   for a, b, left, right in zip(values, values[1:], coords, coords[1:])]
        inner = []
        for previous, upcoming in zip(secants, secants[1:]):
            inner.append(2 * previous * upcoming / (previous + upcoming)
                         if previous * upcoming > 0 else 0)
        return [secants[0], *inner, secants[-1]]

    x, *channels = zip(*rows)
    gradients = [slopes(x, channel) for channel in channels]
    for i, (left, right) in enumerate(zip(x, x[1:])):
        span = right - left
        segments = max(1, math.ceil(span / step))
        for j in range(segments):
            t = j / segments
            t2, t3 = t*t, t*t*t
            values = [(2*t3 - 3*t2 + 1) * channel[i]
                      + (t3 - 2*t2 + t) * span * tangents[i]
                      + (-2*t3 + 3*t2) * channel[i+1]
                      + (t3 - t2) * span * tangents[i+1]
                      for channel, tangents in zip(channels, gradients)]
            yield (left + span * t, *values)
    yield rows[-1]


def blade_section(x, bottom, top, half_width, edge_height):
    height = top - bottom
    bevel_z = bottom + edge_height * height
    summit = top - height * .115
    profile = [
        (half_width * .36, top),
        (half_width * .68, top - height * .021),
        (half_width * .98, top - height * .083),
        (half_width, summit),
        (half_width, bevel_z),
        (half_width * .92, bevel_z - height * .013),
        (half_width * .19, bottom + height * .021),
        (half_width * .085, bottom),
    ]
    return [(x, y, z) for y, z in profile] + [(x, -y, z) for y, z in reversed(profile)]


blade_rows = [
    # X, lower silhouette, upper silhouette, side plane, height of the polished bevel.
    (.361, -.054, .060, .021, .30),
    (.385, -.060, .067, .023, .30),
    (.431, -.101, .091, .028, .32),
    (.483, -.128, .113, .030, .36),
    (.553, -.147, .108, .030, .37),
    (.665, -.162, .093, .030, .36),
    (.790, -.161, .086, .030, .34),
    (.904, -.144, .086, .030, .33),
    (1.017, -.109, .091, .029, .33),
    (1.106, -.061, .102, .024, .36),
    (1.185, .004, .117, .017, .45),
    (1.236, .065, .127, .0085, .47),
    (1.265, .116, .133, .0021, .49),
    (1.271, .132, .134, .00038, .49),
]
blade_roles = [ALLOY, TITANIUM, EDGE, TITANIUM, TITANIUM, EDGE, EDGE, EDGE,
               EDGE, EDGE, TITANIUM, TITANIUM, EDGE, TITANIUM, ALLOY, ALLOY]
blade_stations = list(sample_profile(blade_rows, .045 if OPTIMIZED else .011))
blade = loft(
    "Arc_Blade_SweptTitanium",
    [blade_section(*row) for row in blade_stations],
    lambda _station, side: blade_roles[side], (ALLOY, EDGE), BLADE, ROOT_BONE,
    smooth={4, 10} if OPTIMIZED else {0, 1, 2, 4, 5, 6, 8, 9, 10, 12, 13, 14},
)


def frame_section(x, bottom, top, width, shoulder):
    height = top - bottom
    profile = [
        (.46 * width, top),
        (.64 * width, top - .027 * height),
        (.89 * width, top - shoulder * height * .70),
        (.99 * width, top - shoulder * height),
        (width, top - (shoulder + .032) * height),
        (width, bottom + (shoulder + .037) * height),
        (.99 * width, bottom + (shoulder + .005) * height),
        (.89 * width, bottom + shoulder * height * .70),
        (.64 * width, bottom + .028 * height),
        (.48 * width, bottom),
    ]
    return [(x, y, z) for y, z in profile] + [(x, -y, z) for y, z in reversed(profile)]


frame_rows = [
    (-.460, -.067, .041, .029, .23),
    (-.449, -.079, .057, .045, .22),
    (-.411, -.087, .069, .056, .18),
    (-.327, -.075, .067, .059, .16),
    (-.216, -.061, .061, .059, .14),
    (-.087, -.059, .063, .059, .14),
    (.040, -.064, .074, .059, .15),
    (.147, -.073, .084, .059, .15),
    (.224, -.089, .098, .062, .17),
    (.297, -.097, .105, .060, .19),
    (.353, -.091, .099, .056, .20),
    (.390, -.076, .091, .047, .24),
    (.419, -.056, .077, .038, .28),
    (.434, -.048, .065, .028, .31),
]
frame_roles = [TITANIUM, TITANIUM, EDGE, EDGE, TITANIUM, EDGE, EDGE, TITANIUM,
               TITANIUM, ALLOY, TITANIUM, TITANIUM, EDGE, EDGE, TITANIUM, EDGE,
               EDGE, TITANIUM, TITANIUM, ALLOY]
frame = loft(
    "Arc_Hilt_ContinuousFrame",
    [frame_section(*row) for row in sample_profile(frame_rows, .040 if OPTIMIZED else .009)],
    lambda _station, side: frame_roles[side], (ALLOY, TITANIUM), HILT, "Root",
    smooth={4, 14} if OPTIMIZED else {0, 1, 2, 3, 5, 6, 7, 8, 10, 11, 12, 13, 15, 16, 17, 18},
)


def softened(points, trims, steps=7):
    if OPTIMIZED:
        steps = 3 if steps == 7 else 2
    return (list(map(Vector, points)), trims, steps)


def rounded_outline(shape, margin):
    """Offset the designed corners before adding the small radii."""
    points, trims, steps = shape
    points = inset(points, margin)
    outline = []
    for i, point in enumerate(points):
        before = point.lerp(points[i-1], trims[i])
        after = point.lerp(points[(i+1) % len(points)], trims[i])
        for j in range(steps+1):
            t = j / steps
            outline.append(before * (1-t)**2 + point * (2*t*(1-t)) + after * t*t)
    return outline


def inset(outline, margin):
    winding = sum(a.x*b.y - b.x*a.y for a, b in zip(outline, outline[1:]+outline[:1]))
    side = 1 if winding > 0 else -1
    result = []
    for i, point in enumerate(outline):
        before = (point - outline[i-1]).normalized()
        after = (outline[(i+1) % len(outline)] - point).normalized()
        normal_a = side * Vector((-before.y, before.x))
        normal_b = side * Vector((-after.y, after.x))
        bisector = (normal_a + normal_b).normalized()
        result.append(point + bisector * (margin / bisector.dot(normal_a)))
    return result


def side_volume(name, outline, sections, group, bone, face_material):
    rings = [[(x, depth, z) for x, z in rounded_outline(outline, margin)]
             for depth, margin, _ in sections]
    return loft(name, rings, lambda i, _side: sections[i][2],
                (face_material, face_material), group, bone, smooth=range(len(rings[0])))


def cut(target, name, outline, sections, bone, role=POCKET):
    tool = side_volume(name, outline, sections, TOOLS, bone, role)
    subtract(target, tool)
    return tool


def subtract(target, tool):
    modifier = target.modifiers.new(tool.name, "BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.solver = "EXACT"
    modifier.material_mode = "TRANSFER"
    modifier.object = tool


def keyed_collar():
    """Leave the guard's nose inside the socket and carry the blade in a shaped opening."""
    outer = [
        (.398, -.073, .084, .046, .16),
        (.410, -.087, .095, .050, .17),
        (.447, -.130, .122, .043, .14),
        (.458, -.131, .122, .039, .20),
    ]
    collar_rings = []
    for station in outer:
        collar_rings.append([(x + .095 * (z-.010), y, z)
                             for x, y, z in frame_section(*station)])
    collar = loft("Arc_Hilt_KeyedCollar", collar_rings,
                  lambda i, side: TITANIUM if i in {0, 2} and side not in {4, 14} else ALLOY,
                  (ALLOY, ALLOY), HILT, ROOT_BONE)
    socket_rings = []
    for station in blade_stations:
        if station[0] > .503:
            break
        _, bottom, top, _, _ = station
        center = (top + bottom) / 2
        socket_rings.append([(x, 1.085*y, center + (z-center)*1.062)
                             for x, y, z in blade_section(*station)])
    tool = loft("Machine keyed blade socket", socket_rings, lambda *_: POCKET,
                (POCKET, POCKET), TOOLS, ROOT_BONE)
    subtract(collar, tool)
    return collar


collar = keyed_collar() if OPTIMIZED else None


def pair_pocket(target, group, bone, name, outline, rim, floor, face, roles):
    for suffix, side in (("R", 1), ("L", -1)):
        cut(target, f"Machine {name} pocket {suffix}", outline, [
            (side*(rim+.025), -.0020, roles[0]),
            (side*(rim-.0016), 0, roles[0]),
            (side*(rim-.0035), .0017, POCKET),
            (side*floor, .0017, POCKET),
        ], bone)
        side_volume(f"Arc_{name}_{suffix}", outline, [
            (side*(floor+.0004), .0033, roles[1]),
            (side*(face-.0020), .0033, roles[2]),
            (side*(face-.0005), .0040, roles[2]),
            (side*face, .0063, roles[2]),
        ], group, bone, roles[3])


cobalt = softened([
    (.485, .023), (.511, .060), (.558, .077), (.701, .052), (.826, .047),
    (.990, .056), (1.077, .071), (1.032, .035), (.896, .010), (.773, .005),
    (.654, .007), (.537, .016),
], [.35, .24, .38, .38, .38, .36, .14, .32, .42, .41, .35, .39])
pair_pocket(blade, BLADE, ROOT_BONE, "CobaltInlay", cobalt, .030, .015, .0276,
            (EDGE, DEEP_BLUE, COBALT, COBALT))

# These lighter lanes sit on a keyed ledge of the insert and follow the same sweep.
inlay = softened([
    (.557, .029), (.653, .021), (.776, .018), (.903, .022),
    (.982, .033), (.900, .018), (.776, .013), (.651, .016),
], [.10, .30, .38, .38, .085, .38, .37, .34], steps=4)
for suffix, side in (("R", 1), ("L", -1)):
    panel = bpy.data.objects[f"Arc_CobaltInlay_{suffix}"]
    cut(panel, f"Machine ice lane {suffix}", inlay, [
        (side*.035, -.0003, COBALT), (side*.0254, 0, DEEP_BLUE),
    ], ROOT_BONE, DEEP_BLUE)
    side_volume(f"Arc_IceLane_{suffix}", inlay, [
        (side*.02555, .00022, ICE), (side*.02718, .00023, ICE),
    ], BLADE, ROOT_BONE, ICE)


def seat_inspect_guides():
    for i, (x, z) in enumerate(((.573, .045), (.867, .031)), 1):
        channel = softened([(x-.013, z-.005), (x+.010, z-.005),
                            (x+.013, z+.005), (x-.010, z+.005)], [.18]*4, steps=2)
        cut(blade, f"Machine reveal guide {i}", channel, [
            (.024, 0, POCKET), (-.009, 0, POCKET),
        ], ROOT_BONE)
        guide = side_volume(f"Arc_PlateGuide_{i}", channel, [
            (-.0068, .0014, ALLOY), (.017, .0014, ALLOY),
        ], BLADE, ROOT_BONE, ALLOY)
        guide["Arc plate driven"] = True

    for i, (x, z) in enumerate(((.626, .044), (.663, .040), (.700, .036)), 1):
        contact = softened([(x-.013, z-.0028), (x+.011, z-.0028),
                            (x+.015, z+.0028), (x-.009, z+.0028)], [.14]*4, steps=2)
        side_volume(f"Arc_RevealContact_{i}", contact, [
            (.014, 0, ICE), (.01526, 0, ICE),
        ], BLADE, ROOT_BONE, ICE)

    for name in ("Arc_CobaltInlay_R", "Arc_IceLane_R", "Machine ice lane R"):
        bpy.data.objects[name]["Arc plate driven"] = True


if OPTIMIZED:
    seat_inspect_guides()

grip = softened([
    (-.398, -.042), (-.352, -.054), (-.232, -.037), (-.099, -.035),
    (.034, -.042), (.142, -.049), (.184, -.033), (.182, .027),
    (.133, .054), (.023, .047), (-.114, .037), (-.254, .036), (-.357, .043),
    (-.401, .027),
], [.29, .33, .38, .37, .28, .27, .34, .32, .29, .30, .35, .34, .29, .31])
pair_pocket(frame, HILT, "Root", "GraphiteGrip", grip, .059, .041, .0565,
            (TITANIUM, POCKET, ALLOY, GRIP))

guard = softened([
    (.207, -.033), (.236, .041), (.281, .059), (.358, .049),
    (.324, .002), (.286, -.025), (.242, -.039),
], [.22, .32, .33, .19, .24, .30, .27])
guard_tool = cut(frame, "Machine tapered guard opening", guard, [
    (-.110, -.004, EDGE), (-.0615, -.004, EDGE), (-.048, 0, ALLOY),
    (.048, 0, EDGE), (.0615, -.004, EDGE), (.110, -.004, EDGE),
], "Root", EDGE)

# A locating key carries the blue through the handle without crowding the grip.
key = softened([
    (-.378, -.002), (-.343, .018), (-.239, .018), (-.257, .006), (-.351, .004),
], [.16, .27, .14, .21, .35], steps=5)
for suffix, side in (("R", 1), ("L", -1)):
    pad = bpy.data.objects[f"Arc_GraphiteGrip_{suffix}"]
    cut(pad, f"Machine grip keyway {suffix}", key, [
        (side*.072, -.0012, GRIP), (side*.052, 0, POCKET),
    ], "Root")
    side_volume(f"Arc_GripKey_{suffix}", key, [
        (side*.0523, .0011, DEEP_BLUE),
        (side*.0550, .0011, COBALT),
        (side*.0560, .0017, COBALT),
    ], HILT, "Root", COBALT)


for stock in ("Knife_Blade", "Knife_Hilt", "Knife_Neon"):
    obj = bpy.data.objects[stock]
    obj.hide_render = True
    obj.hide_set(True)

tip = bpy.data.objects.new("Arc_FX_VisualTip", None)
BLADE.objects.link(tip)
tip.empty_display_type = "PLAIN_AXES"
tip.empty_display_size = .027
bind(tip, ROOT_BONE)
tip.matrix_world = Matrix.Translation((1.271, 0, .133))
tip.hide_set(True)


def audit():
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    record, trees = {}, {}
    for obj in PARTS:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        pending = set(bm.verts)
        islands = 0
        while pending:
            islands += 1
            frontier = [pending.pop()]
            for vertex in frontier:
                for edge in vertex.link_edges:
                    neighbor = edge.other_vert(vertex)
                    if neighbor in pending:
                        pending.remove(neighbor)
                        frontier.append(neighbor)
        record[obj.name] = {
            "triangles": len(mesh.loop_triangles),
            "islands": islands,
            "nonmanifold_edges": sum(not edge.is_manifold for edge in bm.edges),
            "zero_faces": sum(face.calc_area() < 1e-12 for face in bm.faces),
            "positive_volume": bm.calc_volume(signed=True) > 0,
            "bone": obj.parent_bone,
        }
        bm.transform(evaluated.matrix_world)
        trees[obj.name] = BVHTree.FromBMesh(bm)
        bm.free()
        evaluated.to_mesh_clear()
    anchor_names = ["Knife_RightGrip", "Knife_BladeBase", "Knife_BladeTip", tip.name]
    anchors = {name: [round(c, 6) for c in bpy.data.objects[name].matrix_world.translation]
               for name in anchor_names}
    blade_tree = trees[blade.name]
    frame_tree = trees[frame.name]
    seat_overlap = bool(blade_tree.overlap(frame_tree))
    guard_faces = [tuple(polygon.vertices) for polygon in guard_tool.data.polygons]
    guard_vertices = [guard_tool.matrix_world @ vertex.co for vertex in guard_tool.data.vertices]
    clear_guard = not blade_tree.overlap(BVHTree.FromPolygons(guard_vertices, guard_faces))
    pairs = {}
    for obj in PARTS:
        role = obj.name.removeprefix("Arc_")
        if role.startswith(("CobaltInlay_", "GraphiteGrip_", "IceLane_", "GripKey_", "PlateGuide_")):
            surface = blade if role.startswith(("CobaltInlay", "PlateGuide")) else frame
            if role.startswith("IceLane"):
                surface = bpy.data.objects["Arc_CobaltInlay_" + role[-1]]
            if role.startswith("GripKey"):
                surface = bpy.data.objects["Arc_GraphiteGrip_" + role[-1]]
            pairs[obj.name] = bool(trees[obj.name].overlap(trees[surface.name]))
    return {
        "parts": record,
        "total_triangles": sum(row["triangles"] for row in record.values()),
        "frame_blade_seat_contact": seat_overlap,
        "guard_aperture_clear": clear_guard,
        "collar_socket_clear": not trees[collar.name].overlap(blade_tree) if collar else None,
        "collar_seated_on_frame": bool(trees[collar.name].overlap(frame_tree)) if collar else None,
        "insert_intersections": pairs,
        "anchors": anchors,
        "actions": sorted(action.name for action in bpy.data.actions),
    }


def setup_view():
    for obj in bpy.context.view_layer.objects:
        if obj.select_get():
            obj.select_set(False)
    bpy.context.view_layer.objects.active = blade
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.overlay.show_overlays = False
                space.shading.type = "SOLID"
                space.shading.color_type = "MATERIAL"
                space.shading.light = "STUDIO"
                space.shading.studiolight_rotate_z = .32
                direction = Vector((.10, 1, .25))
                space.region_3d.view_rotation = (-direction).to_track_quat("-Z", "Y")
                space.region_3d.view_distance = 2.55
                space.region_3d.view_location = (.41, 0, -.008)
                space.region_3d.view_perspective = "ORTHO"


checks = audit()
SCENE.name = "Slipframe Arc · Export master" if OPTIMIZED else "Slipframe Arc · HD master"
SCENE["Arc geometry audit"] = json.dumps(checks)
SCENE["Arc stage"] = ("Faceted export model with keyed collar." if OPTIMIZED
                      else "High density design review. RemasterV2 Knife pose and gameplay anchors.")
setup_view()
OUTPUT.mkdir(parents=True, exist_ok=True)
(OUTPUT / "geometry_audit.json").write_text(json.dumps(checks, indent=2) + "\n", encoding="utf-8")
print(json.dumps(checks))
assert checks["frame_blade_seat_contact"], "The frame and blade should meet at the seat."
assert checks["guard_aperture_clear"], "The blade crosses into the open guard."
if OPTIMIZED:
    assert checks["total_triangles"] < 10_000, checks["total_triangles"]
    assert checks["collar_socket_clear"] and checks["collar_seated_on_frame"], checks
assert not any(checks["insert_intersections"].values()), checks["insert_intersections"]
assert all(row["islands"] == 1 and row["nonmanifold_edges"] == 0 and row["zero_faces"] == 0
           and row["positive_volume"] for row in checks["parts"].values()), checks["parts"]
bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))
result = dict(path=str(MASTER), **checks)
