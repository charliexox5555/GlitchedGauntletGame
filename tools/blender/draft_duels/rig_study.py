"""Build the local Draft Duels avatar look-development file in Blender."""

import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[3]
STUDY = ROOT / "vault/03 Research/Rivals Reference/third-party/draft-duels-thumbnails/rig-study"
RIFLE = ROOT / "art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend"
SOURCE_RIG = STUDY / "Starter_Blocky_Rig.blend"
sys.path.insert(0, str(ROOT / "tools/anim"))

from tp_clips import long_hold  # noqa: E402
from tp_rig import fk, solve  # noqa: E402

ROBLOX_TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 3), (0, 0, 0, 1)))
VANDAL_TO_HANDLE = Matrix(((0, -1, 0, 0), (0, 0, 1, 0), (-1, 0, 0, 0), (0, 0, 0, 1)))


def srgb(hex_color):
    values = [int(hex_color[index:index + 2], 16) / 255 for index in (0, 2, 4)]
    return tuple(value / 12.92 if value < 0.04045 else ((value + 0.055) / 1.055) ** 2.4
                 for value in values)


def material(name, color, roughness=.64, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*srgb(color), 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = mat.diffuse_color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return mat


REGIONS = {
    "Right": (64, ((217, 355), (85, 355), (151, 355), (19, 355), (217, 289), (217, 485))),
    "Left": (64, ((308, 355), (440, 355), (506, 355), (374, 355), (308, 289), (308, 485))),
    "Torso": (128, ((231, 74), (427, 74), (165, 74), (361, 74), (231, 8), (231, 204))),
}


def classic_uv(obj, region):
    """Project through the six Roblox classic clothing regions in rest space."""
    width, origins = REGIONS[region]
    coords = [Vector((v.co.x, -v.co.z, v.co.y)) for v in obj.data.vertices]
    lower = [min(v[axis] for v in coords) for axis in range(3)]
    upper = [max(v[axis] for v in coords) for axis in range(3)]
    uvs = obj.data.uv_layers.new(name="Roblox classic clothing")
    directions = ((1, 1), (1, -1), (0, 1), (0, -1), (2, 1), (2, -1))
    for polygon in obj.data.polygons:
        normal = Vector((polygon.normal.x, -polygon.normal.z, polygon.normal.y))
        axis = max(range(3), key=lambda index: abs(normal[index]))
        face = directions.index((axis, 1 if normal[axis] >= 0 else -1))
        left, top = origins[face]
        for loop_id in polygon.loop_indices:
            vertex = coords[obj.data.loops[loop_id].vertex_index]
            x, y, z = ((vertex[i] - lower[i]) / (upper[i] - lower[i]) for i in range(3))
            horizontal = (1-x, x, y, 1-y, 1-x, 1-x)[face]
            vertical = (1-z, 1-z, 1-z, 1-z, y, 1-y)[face]
            across = 64 if face in (2, 3) else width
            down = 64 if face >= 4 else 128
            uvs.data[loop_id].uv = ((left + .5 + horizontal * (across-1)) / 585,
                                     1 - (top + .5 + vertical * (down-1)) / 559)


def clothing(source, name, color, keep_face=False, classic=None, gold=False):
    """Keep the existing UV and face overlay so outfit/face swaps stay editable."""
    mat = source.copy()
    mat.name = name
    tree = mat.node_tree
    shader = next(node for node in tree.nodes if node.type == "BSDF_PRINCIPLED")
    mix = tree.nodes.get("Mix.001")
    base = mix.inputs["A"]
    tree.links.remove(base.links[0])
    base.default_value = (*srgb(color), 1)
    if not keep_face:
        tree.links.remove(shader.inputs["Base Color"].links[0])
        shader.inputs["Base Color"].default_value = base.default_value
    if classic:
        texture = tree.nodes.get("Image Texture")
        texture.image = bpy.data.images.load(str(STUDY / f"bacon-{classic}.png"), check_existing=True)
        tree.nodes.get("UV Map.001").uv_map = "Roblox classic clothing"
        tree.links.new(texture.outputs["Alpha"], mix.inputs["Factor"])
        tree.links.new(texture.outputs["Color"], mix.inputs["B"])
        tree.links.new(mix.outputs["Result"], shader.inputs["Base Color"])
    if gold:
        shader.inputs["Emission Color"].default_value = (*srgb("FFBA31"), 1)
        shader.inputs["Emission Strength"].default_value = .22
    shader.inputs["Roughness"].default_value = .54
    return mat


def bone_parent(obj, armature, bone):
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = armature
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_world = world


def socket(collection, name, position, rig, bone):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.location = position
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = .16
    bone_parent(obj, rig, bone)
    return obj


def attach_at_socket(obj, attachment, offset=None):
    obj.parent = attachment
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_basis = Matrix.Translation(Vector(offset or (0, 0, 0)))


def pal_hair(collection, attachment):
    """Convert Roblox's legacy text triangles and keep authored UVs/normals."""
    lines = (STUDY / "pal-hair.mesh").read_text().splitlines()
    if lines[0] != "version 1.00":
        raise ValueError(f"Unexpected Pal Hair mesh format {lines[0]}")
    values = [tuple(map(float, match.split(","))) for match in re.findall(r"\[([^]]+)\]", lines[2])]
    if len(values) != int(lines[1]) * 9:
        raise ValueError("Pal Hair triangle count does not match its header")
    vertices = [(x / 2, -z / 2, y / 2) for x, y, z in values[::3]]
    # Match the current MeshPart Size measured in Studio, without recentering
    # the mesh origin used by its AccessoryWeld.
    size = (1.705076, 1.887561, 1.301894)
    spans = [max(axis) - min(axis) for axis in zip(*vertices)]
    vertices = [tuple(value * desired / span for value, desired, span in zip(vertex, size, spans))
                for vertex in vertices]
    faces = [(index, index + 1, index + 2) for index in range(0, len(vertices), 3)]
    mesh = bpy.data.meshes.new("Pal Hair · Roblox 83293901")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="Pal Hair UV")
    for item, (u, v, _) in zip(uv_layer.data, values[2::3]):
        item.uv = u, 1 - v
    mesh.normals_split_custom_set([(x, -z, y) for x, y, z in values[1::3]])
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new("Pal Hair · Roblox 63690008", mesh)
    collection.objects.link(obj)
    mat = material("Pal Hair · Roblox 6858317867", "80502F", .46)
    texture = mat.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(STUDY / "pal-hair.png"), check_existing=True)
    mat.node_tree.links.new(texture.outputs["Color"],
                            mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
    mesh.materials.append(mat)
    # AccessoryWeld.Part0 is the Handle. Convert -C0 to Blender basis.
    attach_at_socket(obj, attachment, (0, .24195792, -.34390989))
    obj["Catalog asset"] = 63690008
    obj["Attachment"] = "HairAttachment"
    return obj


def rebuild_arm(mesh_object, side):
    """Keep a full classic shoulder and a tighter, continuous elbow and wrist."""
    # Local Y is height in the starter mesh. The two narrow hinge bands
    # straddle the rig's existing elbow (Y 0.01) and wrist (Y -0.79).
    rings = [
        (.66, .29, .26, (1, 0, 0)), (.60, .38, .33, (1, 0, 0)),
        (.40, .38, .33, (1, 0, 0)), (.15, .36, .32, (1, 0, 0)),
        (.01, .35, .32, (.5, .5, 0)), (-.13, .36, .33, (0, 1, 0)),
        (-.56, .34, .31, (0, 1, 0)), (-.76, .32, .29, (0, .75, .25)),
        (-.82, .32, .29, (0, .25, .75)), (-.94, .32, .29, (0, 0, 1)),
        (-.99, .27, .24, (0, 0, 1)),
    ]
    vertices = []
    for height, width, depth, _ in rings:
        cut = .07
        center = (-.09 if side == "R" else .09) * max(0, height)
        vertices.extend((x + center, height, z) for x, z in (
            (-width + cut, -depth), (width - cut, -depth), (width, -depth + cut),
            (width, depth - cut), (width - cut, depth), (-width + cut, depth),
            (-width, depth - cut), (-width, -depth + cut),
        ))
    faces = [tuple(range(8))]
    for upper in range(len(rings)-1):
        for i in range(8):
            a, b = upper * 8 + i, upper * 8 + (i+1) % 8
            faces.append((a, b, b+8, a+8))
    faces[0] = tuple(reversed(faces[0]))
    last = (len(rings)-1)*8
    faces.append(tuple(range(last, last+8)))
    mesh = bpy.data.meshes.new(f"Classic arm · {side}")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = polygon.loop_total == 4
    mesh_object.data = mesh
    mesh_object.vertex_groups.clear()
    groups = [mesh_object.vertex_groups.new(name=f"{bone}.{side}")
              for bone in ("Upperarm", "Lowerarm", "Hand")]
    for ring, (_, _, _, weights) in enumerate(rings):
        for group, weight in zip(groups, weights):
            if weight:
                group.add(list(range(ring*8, ring*8+8)), weight, "REPLACE")
    mesh_object.modifiers.remove(mesh_object.modifiers["Subdivision"])
    mesh_object.modifiers["Armature"].use_deform_preserve_volume = False


def append_rig(scene, name, style):
    with bpy.data.libraries.load(str(SOURCE_RIG), link=False) as (source, destination):
        destination.collections = ["Starter Blocky Rig"]
    collection = destination.collections[0]
    collection.name = f"{name} | Character and accessories"
    scene.collection.children.link(collection)
    parts = {obj.name.split(".")[0]: obj for obj in collection.objects}
    rig = parts["Blocky Rig"]
    rig.name = f"{name} | Pose controls"
    for driver in list(rig.animation_data.drivers):
        if ("Front.R" in driver.data_path or "Front.L" in driver.data_path
                or 'Hand.R"].constraints["Transformation"]' in driver.data_path):
            rig.driver_remove(driver.data_path, driver.array_index)
    bpy.context.view_layer.update()
    source_mat = parts["Torso"].data.materials[0]
    skin, torso, sleeve, leg, _ = style
    for part, color in (("Torso", torso), ("Right Arm", sleeve), ("Left Arm", sleeve),
                        ("Right Leg", leg), ("Left Leg", leg), ("Head", skin)):
        mesh = parts[part]
        classic = None
        arm = part.endswith("Arm")
        if arm:
            rebuild_arm(mesh, part[0])
        if name == "Bacon" and part != "Head":
            classic_uv(mesh, "Torso" if part == "Torso" else part.split()[0])
            classic = "pants" if part.endswith("Leg") else "shirt"
            color = skin
        mat = clothing(source_mat, f"{name} | {part}", color, part == "Head" and name == "Bacon",
                       classic=classic, gold=name == "Gold")
        if arm:
            mesh.data.materials.append(mat)
        else:
            mesh.data.materials[0] = mat
            mesh.modifiers["Subdivision"].render_levels = 2
    rig["Source"] = "Roblox Starter Rigs v1.2, Softy & Paribes"
    rig["Body sizing"] = "Classic thumbnail rig, one Blender unit per Roblox stud"
    attach = {
        "HairAttachment": ((0, 0, 5.023), "Head.001"),
        "HatAttachment": ((0, 0, 5.023), "Head.001"),
        "FaceFrontAttachment": ((0, .5813, 4.4334), "Head.001"),
        "BodyBackAttachment": ((0, -.502, 3.23), "TorsoBendy"),
        "BodyFrontAttachment": ((0, .502, 3.23), "TorsoBendy"),
        "RightShoulderAttachment": ((1.48, 0, 3.74), "Upperarm.R"),
        "LeftShoulderAttachment": ((-1.48, 0, 3.74), "Upperarm.L"),
        "RightGripAttachment": ((1.5, 0, 2.10), "Hand.R"),
        "LeftGripAttachment": ((-1.5, 0, 2.10), "Hand.L"),
    }
    anchors = {label: socket(collection, label, pos, rig, bone)
               for label, (pos, bone) in attach.items()}
    if name == "Bacon":
        pal_hair(collection, anchors["HairAttachment"])
    return rig, collection


def rifle(scene, rig):
    collection = bpy.data.collections.new("Vandal | Weapon and grip sockets")
    scene.collection.children.link(collection)
    with bpy.data.libraries.load(str(RIFLE), link=False) as (source, target):
        target.objects = [name for name in source.objects if name.startswith("Vandal_")]
    for obj in target.objects:
        collection.objects.link(obj)
    bpy.context.view_layer.update()
    by_name = {obj.name.split(".")[0]: obj for obj in collection.objects}
    bind = by_name["Vandal_RightGrip"].matrix_world.translation.copy()
    root = bpy.data.objects.new("Vandal | Move together", None)
    collection.objects.link(root)
    root.empty_display_size = .25
    for obj in list(collection.objects):
        if obj != root and obj.parent is None:
            obj.parent = root
    bone_parent(root, rig, "Hand.R")
    root["Left grip"] = "Use Vandal_LeftGrip when reposing the supporting arm"
    joints = [("Lowertorso", "LowerTorso"), ("Uppertorso", "UpperTorso"),
              ("TorsoBendy", "UpperTorso"), ("Head", "Head")]
    for side in ("Right", "Left"):
        for roblox, blender in (("UpperArm", "Upperarm"), ("LowerArm", "Lowerarm"), ("Hand", "Hand"),
                                ("UpperLeg", "Upperleg"), ("LowerLeg", "Lowerleg"), ("Foot", "Foot")):
            joints.append((f"{blender}.{side[0]}", f"{side}{roblox}"))
    bones = [(rig.pose.bones[bone], part) for bone, part in joints]
    for bone, _ in bones:
        for constraint in bone.constraints:
            constraint.mute = True
    for obj in [*(bone for bone, _ in bones), root]:
        obj.rotation_mode = "QUATERNION"
    rest = fk({})
    inverse_space = ROBLOX_TO_BLENDER.inverted()
    for frame in range(1, 26):
        ease = math.sin(math.pi * (frame - 1) / 24) ** 2
        controls = long_hold(-10 * (1-ease))
        # The live Match grip controller lifts the support palm to each
        # weapon's actual grip. Sample a point just below the Vandal guard.
        controls["left_arm"] = {"on_gun": (0, -.04, -1.32), "reach": .98}
        posed = fk(solve(controls))
        for bone, part in bones:
            # CFrame contains translation. Use the full rigid inverse for the
            # retarget delta, so the source hinge translations carry through.
            delta = Matrix(posed[part].tolist()) @ Matrix(rest[part].tolist()).inverted()
            bone.matrix = ROBLOX_TO_BLENDER @ delta @ inverse_space @ bone.bone.matrix_local
            bpy.context.view_layer.update()
        transform = ROBLOX_TO_BLENDER @ Matrix(controls["_gun_cf"].tolist()) @ VANDAL_TO_HANDLE
        transform.translation -= transform.to_3x3() @ bind
        root.matrix_world = transform
        for bone, _ in bones:
            bone.keyframe_insert("location", frame=frame)
            bone.keyframe_insert("rotation_quaternion", frame=frame)
        root.keyframe_insert("location", frame=frame)
        root.keyframe_insert("rotation_quaternion", frame=frame)
    scene.frame_end = 25
    scene.render.fps = 24
    scene.frame_set(13)
    scene.timeline_markers.new("Low ready", frame=1)
    scene.timeline_markers.new("Aim", frame=13)
    scene.timeline_markers.new("Low ready", frame=25)
    rig.animation_data.action.name = f"{scene.name} | Retargeted Draft Duels rifle hold"


def camera(scene, location, target, lens):
    obj = bpy.data.objects.new("Portrait camera", bpy.data.cameras.new("Portrait camera"))
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    obj.data.lens = lens
    scene.camera = obj


def area(scene, name, position, target, energy, color, size):
    lamp = bpy.data.lights.new(name, "AREA")
    lamp.energy = energy
    lamp.color = srgb(color)
    lamp.shape = "DISK"
    lamp.size = size
    obj = bpy.data.objects.new(name, lamp)
    scene.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def stage(scene, rim):
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    scene.world = bpy.data.worlds.new("Studio ambient")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes.get("Background").inputs["Strength"].default_value = .25
    scene.view_settings.view_transform = "AgX"
    area(scene, "Key · softbox", (-3, 6, 8), (0, 0, 3.7), 1900, "FFF0D8", 4.2)
    area(scene, "Edge · color", (3, -2, 6), (0, 0, 3.6), 1500, rim, 3.1)
    area(scene, "Front fill", (4, 5, 2.6), (0, 0, 3.2), 530, "C4DFFF", 3.2)
    camera(scene, (-6.7, 8.8, 5.1), (.02, .68, 3.72), 67)
    for screen in bpy.data.screens:
        for area_region in screen.areas:
            if area_region.type == "VIEW_3D":
                area_region.spaces.active.region_3d.view_perspective = "CAMERA"


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    initial = bpy.context.scene
    styles = {
        "Gold": ("FFCD31", "DCA629", "EDB52B", "AD7421", "FFD861"),
        "Bacon": ("E9AF83", "243448", "293750", "26313F", "FFD23F"),
        "Blue": ("A46A4A", "136588", "246C96", "152E49", "58DEFF"),
        "Orange": ("DC9C65", "A74A24", "BD5B2E", "463035", "FFAA51"),
    }
    preview = "--preview" in sys.argv
    if preview:
        styles = {"Gold": styles["Gold"]}
    scenes = {}
    for name, outfit in styles.items():
        scene = bpy.data.scenes.new(name)
        bpy.context.window.scene = scene
        rig, _ = append_rig(scene, name, outfit)
        rifle(scene, rig)
        stage(scene, outfit[-1])
        scenes[name] = scene
    bpy.data.scenes.remove(initial)
    bpy.context.window.scene = scenes["Gold"]
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version = 0
    if not preview:
        bpy.ops.wm.save_as_mainfile(filepath=str(STUDY / "Draft Duels - Avatar Look Development.blend"))
    for name, scene in scenes.items():
        scene.render.filepath = str(STUDY / f"{name.lower()}-{'retarget' if preview else 'plate'}.png")
        bpy.ops.render.render(write_still=True, scene=scene.name)


if __name__ == "__main__":
    main()
