"""Build isolated, editable Draft Duels thumbnail stages from project art.

Run with Blender: blender -b --python tools/blender/draft_duels_launch.py -- [preview]
"""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art-source"
OUT = ART / "marketing/draft-duels"
PREVIEW = "preview" in sys.argv
GOLD, BLUE, ORANGE = "FFD23F", "408DFA", "FF762B"
VANDAL = ART / "weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend"
TEMPEST = ART / "weapons/Skins/TempestStrike/Vandal/v20/Vandal_TempestStrike_StormShadow_v20.blend"
FOUNDRY = ART / "maps/Foundry4/Kit_Foundry4.blend"
IMPORTED = {}
scene = None


def linear_color(code):
    channels = [int(code[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in channels)


def material(name, color, metal=0, glow=0, rough=.68):
    cached = bpy.data.materials.get(name)
    if cached:
        return cached
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    rgba = (*linear_color(color), 1)
    mat.diffuse_color = rgba
    shader.inputs["Base Color"].default_value = rgba
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Emission Color"].default_value = rgba
    shader.inputs["Emission Strength"].default_value = glow
    return mat


def concrete():
    mat = material("Original world-space cast concrete", "636B78")
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    tex = nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = 2.4
    tex.inputs["Detail"].default_value = 2
    coordinates = nodes.new("ShaderNodeTexCoord")
    links.new(coordinates.outputs["Object"], tex.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*linear_color("535B66"), 1)
    ramp.color_ramp.elements[1].color = (*linear_color("6A737F"), 1)
    links.new(tex.outputs["Fac"], ramp.inputs[0])
    links.new(ramp.outputs[0], nodes.get("Principled BSDF").inputs["Base Color"])
    return mat


def collection(name):
    coll = bpy.data.collections.new(name)
    scene.collection.children.link(coll)
    return coll


def move(obj, target):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    target.objects.link(obj)
    return obj


def box(target, name, position, dimensions, mat, edge=.045):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = move(bpy.context.object, target)
    obj.name = name
    for vertex in obj.data.vertices:
        vertex.co = Vector(a * b for a, b in zip(vertex.co, dimensions))
    if mat:
        obj.data.materials.append(mat)
    if edge:
        bevel = obj.modifiers.new("Single cut chamfer", "BEVEL")
        bevel.width = edge
        bevel.segments = 1
        obj.modifiers.new("Face weighted normals", "WEIGHTED_NORMAL")
    return obj


def beam(target, name, point_a, point_b, width, depth, mat, edge=.02):
    a, b = Vector(point_a), Vector(point_b)
    obj = box(target, name, (a + b) / 2, (width, depth, (b - a).length), mat, edge)
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return obj


def flat_mesh(target, name, points, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(mat)
    target.objects.link(obj)
    return obj


def aim(obj, focus):
    obj.rotation_euler = (Vector(focus) - obj.location).to_track_quat("-Z", "Y").to_euler()


def camera(position, focus, lens, roll=0):
    data = bpy.data.cameras.new("Thumbnail lens")
    obj = bpy.data.objects.new("Thumbnail camera", data)
    scene.collection.objects.link(obj)
    obj.location = position
    aim(obj, focus)
    obj.rotation_euler.rotate_axis("Z", math.radians(roll))
    data.lens = lens
    scene.camera = obj
    bpy.context.view_layer.update()
    return obj


def area(name, position, focus, color, power, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size = power, "DISK", size
    data.color = linear_color(color)
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = position
    aim(obj, focus)


def point(target, name, position, color, power, radius):
    data = bpy.data.lights.new(name, "POINT")
    data.color, data.energy, data.shadow_soft_size = linear_color(color), power, radius
    obj = bpy.data.objects.new(name, data)
    target.objects.link(obj)
    obj.location = position


def load_objects(path, select):
    if path not in IMPORTED:
        with bpy.data.libraries.load(str(path)) as (source, destination):
            destination.objects = [name for name in source.objects if select(name)]
        IMPORTED[path] = [obj for obj in destination.objects if obj and obj.type == "MESH"]
    return IMPORTED[path]


def instance(target, source, matrix):
    obj = bpy.data.objects.new(source.name, source.data)
    mat = matrix @ source.matrix_world
    obj.matrix_world = mat
    target.objects.link(obj)
    return obj


def weapon(target, p, direction, scale=1, roll=0, skin=False):
    if skin:
        if TEMPEST not in IMPORTED:
            with bpy.data.libraries.load(str(TEMPEST)) as (source, loaded):
                loaded.collections = [n for n in source.collections if n[:2] in {"02", "03", "04", "05", "06"}]
            IMPORTED[TEMPEST] = [obj for coll in loaded.collections for obj in coll.objects
                                 if obj.type == "MESH" and not obj.hide_render]
            stage_sources = collection("Tempest source transforms")
            for obj in IMPORTED[TEMPEST]:
                parent = obj
                while parent:
                    if parent.name not in stage_sources.objects:
                        stage_sources.objects.link(parent)
                    parent = parent.parent
            bpy.context.view_layer.update()
            transforms = {obj.name: obj.matrix_world.copy() for obj in IMPORTED[TEMPEST]}
            bpy.data.collections.remove(stage_sources)
            for obj in IMPORTED[TEMPEST]:
                obj.parent = None
                obj.matrix_world = transforms[obj.name]
        objs = IMPORTED[TEMPEST]
    else:
        objs = load_objects(VANDAL, lambda n: n.startswith("Vandal_"))
    f = Vector(direction).normalized()
    side = Vector((0, 0, 1)).cross(f).normalized()
    up = f.cross(side)
    matrix = Matrix((f, side, up)).transposed().to_4x4()
    matrix = Matrix.Translation(p) @ matrix @ Matrix.Rotation(math.radians(roll), 4, "X") @ Matrix.Scale(scale, 4)
    for obj in objs:
        instance(target, obj, matrix)
    return matrix


def add_head(target, frame, style, team):
    gold = style == "Gold"
    metallic = material("Lobby gold enamel", GOLD, .40, .1)
    skin = material("Avatar skin warm", "DC9662", rough=.57)
    ink = material("Face ink", "1C1417", rough=.5)
    size = (1.58, 1.30, 1.52)
    obj = box(target, "Block head", (0, 0, 0), size, metallic if gold else skin, .17)
    obj.matrix_world = frame
    base = .659
    for sign in (-1, 1):
        if gold:
            shape = [(sign * .13, base, .055), (sign * .57, base, .22), (sign * .54, base, -.045), (sign * .17, base, -.125)]
            detail = flat_mesh(target, "Black visor", [frame @ Vector(co) for co in shape], [(0, 1, 2, 3)], ink)
            detail.modifiers.new("Two-sided visor", "SOLIDIFY").thickness = .012
            light = material("Visor gold", "FFE781", glow=.75)
            shape = [(sign * .19, base + .014, .03), (sign * .50, base + .014, .15), (sign * .48, base + .014, -.015), (sign * .21, base + .014, -.075)]
            detail = flat_mesh(target, "Visor reflection", [frame @ Vector(co) for co in shape], [(0, 1, 2, 3)], light)
            detail.modifiers.new("Reflection thickness", "SOLIDIFY").thickness = .012
        else:
            eye = box(target, "Eye", (0, 0, 0), (.13, .025, .24), ink, .035)
            eye.matrix_world = frame @ Matrix.Translation((sign * .29, base, .07))
            beam(target, "Brow", frame @ Vector((sign * .09, base, .21)), frame @ Vector((sign * .45, base, .31)), .09, .05, ink)
    if not gold:
        beam(target, "Mouth", frame @ Vector((-.19, base, -.23)), frame @ Vector((.20, base, -.20)), .065, .035, ink)
        dark_hair = material("Bacon hair base", "56301E", rough=.52)
        hair = box(target, "Hair crown", (0, 0, 0), (1.66, 1.36, .52), dark_hair, .16)
        hair.matrix_world = frame @ Matrix.Translation((0, -.045, .66))
        for i in range(8):
            x = (i - 3.5) * .20
            top = .94 - abs(i - 3.7) * .029
            hair_mat = material(f"Hair facet {i % 3}", ("995021", "B66A2E", "74401F")[i % 3], rough=.46)
            points = [(x - .13, -.55, .64), (x - .04, -.16, top), (x + .07, .43, top - .04), (x + .20, .70, .36 + .08 * (i % 3))]
            for a, b in zip(points, points[1:]):
                beam(target, "Bacon hair facet", frame @ Vector(a), frame @ Vector(b), .23, .27, hair_mat, .065)


def fighter(name, location, facing, team, style="Bacon", pose="hold", scale=1, head_yaw=0, aim_yaw=0):
    coll = collection(name)
    root = Matrix.Translation(location) @ Matrix.Rotation(math.radians(facing), 4, "Z") @ Matrix.Scale(scale, 4)
    jacket = material("Charcoal jacket", "222735", rough=.66)
    denim = material("Dark denim", "283740", rough=.89)
    fabric = material("Team " + team, team, .05, .12)
    skin = material("Avatar skin warm", "DC9662", rough=.57)
    glove = jacket if style == "Gold" else skin
    boot = material("Warm sneaker soles", "EEF0EF")
    body_z = 3.30 if pose != "slide" else 1.86
    chest_tilt = {"hold": .03, "slide": -.34, "air": .22}[pose]
    body = root @ Matrix.Translation((0, 0, body_z)) @ Matrix.Rotation(chest_tilt, 4, "X")

    def plate(label, xyz, dims, mat, bevel=.06):
        obj = box(coll, label, (0, 0, 0), dims, mat, bevel)
        obj.matrix_world = body @ Matrix.Translation(xyz)

    plate("Chest", (0, 0, 0), (1.94, 1.03, 1.50), jacket, .14)
    plate("Team front", (0, .507, -.05), (1.60, .11, 1.11), fabric, .06)
    plate("Chest band", (0, .576, .21), (1.47, .045, .17), jacket, .02)
    plate("Belt", (0, 0, -.69), (1.80, 1.04, .25), denim)
    add_head(coll, body @ Matrix.Translation((0, .015, 1.45)) @ Matrix.Rotation(math.radians(head_yaw), 4, "Z"), style, team)
    leg_poses = {"hold": ((-.64, .22, .29), (.68, -.38, .29)), "slide": ((-.73, 1.65, .27), (.81, .40, .27)), "air": ((-.73, .83, .85), (.86, -.77, .32))}
    for sign, foot in zip((-1, 1), leg_poses[pose]):
        hip = body @ Vector((sign * .48, 0, -.66))
        toe = root @ Vector(foot)
        knee = (hip + toe) / 2 + root.to_3x3() @ Vector((sign * .16, .24 if pose != "slide" else .37, .14))
        beam(coll, "Upper leg", hip, knee, .83 * scale, .83 * scale, denim, .09)
        beam(coll, "Lower leg", knee, toe, .77 * scale, .76 * scale, denim, .065)
        obj = box(coll, "Sole", toe, (.78 * scale, 1.03 * scale, .24 * scale), boot, .07)
        obj.rotation_euler.z = math.radians(facing)

    # The rifle uses the project's local +X barrel direction and grip locators.
    grip = body @ Vector((-.43, .96, .02))
    direction = Matrix.Rotation(math.radians(aim_yaw), 3, "Z") @ root.to_3x3() @ Vector((-.13, 1, .15 if pose != "air" else -.19))
    rifle = weapon(coll, grip, direction, .87 * scale)
    for sign, target in ((-1, rifle @ Vector((0, 0, 0))), (1, rifle @ Vector((1.32, 0, .08)))):
        shoulder = body @ Vector((sign * 1.03, .00, .43))
        elbow = body @ Vector((sign * 1.04, .46, -.46))
        beam(coll, "Sleeve", shoulder, elbow, .67 * scale, .68 * scale, fabric, .09)
        hand = target - Vector((0, 0, .19 * scale))
        beam(coll, "Forearm", elbow, hand, .46 * scale, .47 * scale, glove, .07)
        box(coll, "Grip hand", hand, (.46 * scale, .47 * scale, .44 * scale), glove, .07)
    return coll


def foundry():
    coll = collection("Foundry | original map kit and staged hall")
    cast = concrete() if not bpy.data.materials.get("Original world-space cast concrete") else bpy.data.materials["Original world-space cast concrete"]
    steel = material("Foundry blue-grey steel", "576474", .38, .018)
    black = material("Foundry roof", "303845", .14)
    trim = material("Safety yellow paint", "D9A02C", .12, .04)
    lava = material("Molten runner", "FF7A22", glow=3.5)
    lamps = material("Foundry white lamp", "ACD7F0", glow=3)
    for side in (-1, 1):
        box(coll, "Cast-floor slab", (side * 18, 12, -.6), (30.0, 83, 1.16), cast, .06)
        box(coll, "Runner edge", (side * 3.43, 12, -.07), (.80, 83, .23), trim, .05)
        box(coll, "MeltShop wall", (side * 31.9, 14, 12), (1.19, 88, 24.0), steel, .09)
        box(coll, "Catwalk deck", (side * 25.9, 14, 11.68), (5, 84, .54), black)
        box(coll, "Catwalk guard", (side * 23.5, 14, 12.7), (.13, 84, .15), trim)
        for y in range(-24, 59, 12):
            box(coll, "Portal frame column", (side * 29.3, y, 12), (2.4, 1.35, 24), black, .07)
            box(coll, "Portal floor foot", (side * 29.3, y, .70), (3.1, 2.25, 1.4), cast, .12)
            box(coll, "Window", (side * 31.24, y + 6, 18.5), (.10, 9.5, 4.2), lamps, .02)
            box(coll, "Catwalk stanchion", (side * 23.5, y, 12.35), (.17, .17, 1.1), trim)
        for y in range(-26, 54, 8):
            box(coll, "Floor joint", (side * 18, y, -.016), (28.8, .045, .014), black, 0)
    box(coll, "Molten runner surface", (0, 13, -.86), (6.2, 83, .18), lava, .04)
    for y in (-7, 18):
        box(coll, "Runner plate bridge", (0, y, -.13), (8.2, 7.2, .24), steel, .09)
    for y in range(-24, 57, 12):
        box(coll, "Portal frame roof truss", (0, y, 24), (61, 1.3, 1.8), black, .07)
        box(coll, "Roof strip", (0, y - .69, 22.92), (23, .12, .1), lamps, .01)
    box(coll, "Far hall wall", (0, 55.8, 13), (64, 1.2, 26), steel)
    for x, y, z, name in [(-12, 41, 0, "F4Furnace"), (-2, 22, 18.5, "F4Crane"), (9, 29, 0, "F4LadleCar"), (9, 29, 3, "F4Ladle"), (11, 14, .03, "F4IngotCart"), (-9, 8, .03, "F4SlabPile2"), (8, -1, .03, "F4Coil"), (-21, 29, .03, "F4Stair12")]:
        kit = load_objects(FOUNDRY, lambda n: n.startswith("F4"))
        source = next(obj for obj in kit if obj.name.split(".")[0] == name)
        obj = bpy.data.objects.new(name, source.data)
        coll.objects.link(obj)
        obj.location = (x, y, z)
    for y in (-3, 14, 29):
        point(coll, "Heat from runner", (0, y, 1.0), "FF7428", 230, 1.8)
    area("Cool steel skylight", (-7, 3, 22), (0, 8, 0), "B9DAFF", 4800, 17)
    area("Amber bounce", (7, 15, 9), (0, 5, 3), "FFD582", 3300, 10)
    area("Soft front", (-7, -7, 11), (0, 8, 3), "FFF1D8", 3800, 13)


def rooftop():
    coll = collection("Rooftops | staged roof court")
    cement = material("Roofs concrete", "8F9DAE")
    blue = material("Painted court desaturated blue", "637F9E")
    dark = material("Roof rail steel", "394760", .35)
    tan = material("Water tower cedar", "8A634E")
    amber = material("Painted court lines", "F1C55D", glow=.25)
    box(coll, "Sunken rooftop court", (0, 12, -.51), (43, 69, 1), blue)
    for side in (-1, 1):
        box(coll, "Upper roof wing", (side * 22, 14, 1.55), (8, 65, 3.1), cement, .18)
        box(coll, "Parapet cap", (side * 24.7, 14, 4.2), (.66, 65, .31), dark, .08)
        for x in (4.2, 12.7):
            box(coll, "Court painted line", (side * x, 12, .006), (.13, 62, .018), amber, 0)
        for y in range(-12, 45, 6):
            box(coll, "Parapet panel", (side * 24.7, y, 3.71), (.53, 5.84, .91), cement, .05)
    for x in (-5.5, 5.5):
        for y in (25.5, 33.5):
            box(coll, "Water tower legs", (x, y, 8), (.74, .74, 16), dark, .05)
            beam(coll, "Water tower knee brace", (x, y, 11), (x * .48, y, 15), .32, .32, dark)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=6, depth=7.4, location=(0, 29.5, 18.8))
    tank = move(bpy.context.object, coll)
    tank.name = "Faceted wooden water tower"
    tank.data.materials.append(tan)
    for z in (15.4, 18, 20.6, 22.3):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=6.08, depth=.34, location=(0, 29.5, z))
        move(bpy.context.object, coll).data.materials.append(dark)
    rng = random.Random(88)
    for i in range(35):
        x, y, height = rng.uniform(-100, 100), rng.uniform(52, 92), rng.uniform(11, 41)
        width = rng.uniform(4, 10)
        mat = material("Distant city " + str(i % 4), ("6D87A8", "6A82A2", "8C9CB3", "7795AE")[i % 4], glow=.20)
        box(coll, "City mass", (x, y, height / 2 - 8), (width, 9, height), mat, .14)
    data = bpy.data.lights.new("Blue-hour sun", "SUN")
    data.energy, data.angle = 2.2, .16
    sun = bpy.data.objects.new("Blue-hour sun", data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (.63, -.54, -.40)
    area("Roof bounce", (-3, -6, 12), (0, 8, 3), "E0EFFF", 4600, 14)


def fx_trail(coll, a, b, color, width=.04):
    mat = material("FX " + color, color, glow=4)
    beam(coll, "Tracer light", a, b, width, width, mat, 0)


def burst(coll, center, camera_obj, color, size, rays, seed):
    center = Vector(center)
    right = camera_obj.matrix_world.to_3x3() @ Vector((1, 0, 0))
    up = camera_obj.matrix_world.to_3x3() @ Vector((0, 1, 0))
    rng = random.Random(seed)
    mat = material("Burst " + color, color, glow=2.4)
    for i in range(rays):
        angle = 2 * math.pi * (i + rng.uniform(-.23, .23)) / rays
        direction = right * math.cos(angle) + up * math.sin(angle)
        cross = right * -math.sin(angle) + up * math.cos(angle)
        pts = [center + direction * size * .12, center + direction * size * .27 + cross * size * .07,
               center + direction * size * rng.uniform(.55, 1.38), center + direction * size * .27 - cross * size * .07]
        p = flat_mesh(coll, "Faceted action spark", pts, [(0, 1, 2, 3)], mat)
        p.modifiers.new("Double-sided effect", "SOLIDIFY").thickness = .008


def first_person(cam, shoot, skin=False):
    coll = collection("First person | game rifle and block arms")
    c = cam.matrix_world
    if skin:
        p = c @ Vector((.42, -.26, -3.47))
        aim_pt = c @ Vector((-1.90, 1.01, -4.15))
        matrix = weapon(coll, p, aim_pt - p, .76, roll=-6, skin=True)
    else:
        p = c @ Vector((.58, -.41, -1.85))
        matrix = weapon(coll, p, Vector(shoot) - p, .94)
    for sign, grip in ((1, (0, 0, -.15)), (-1, (1.22, 0, .02))):
        start = c @ Vector((sign * .83, -.79, -1.66))
        end = matrix @ Vector(grip)
        cuff = start.lerp(end, .68)
        sleeve = material("Viewmodel sleeve", "252E3A")
        flesh = material("Viewmodel hands", "E5A96E")
        beam(coll, "Block sleeve", start, cuff, .37, .39, sleeve, .036)
        beam(coll, "Block hand", cuff, end, .37, .36, flesh, .042)
    return coll, matrix


def ticket(coll, x, z, scale, color, angle=0):
    outline = [(-2.18, -1.75), (1.81, -1.75), (2.18, -1.39), (2.18, -.35), (1.94, 0), (2.18, .35), (2.18, 1.37), (1.82, 1.75), (-1.81, 1.75), (-2.18, 1.38), (-2.18, .35), (-1.94, 0), (-2.18, -.35), (-2.18, -1.37)]
    frame = Matrix.Translation((x, 2.0, z)) @ Matrix.Rotation(math.radians(angle), 4, "Y") @ Matrix.Scale(scale, 4)
    mat = material("Ticket edge " + color, color, .30, .20)
    inner = [(x * .90, z * .87) for x, z in outline]
    points = [frame @ Vector((x, 0, z)) for x, z in outline + inner]
    size = len(outline)
    quads = [(i, (i + 1) % size, size + (i + 1) % size, size + i) for i in range(size)]
    obj = flat_mesh(coll, "Continuous beveled ticket", points, quads, mat)
    obj.modifiers.new("Ticket depth", "SOLIDIFY").thickness = .18
    bevel = obj.modifiers.new("Ticket cut corners", "BEVEL")
    bevel.width = .038
    bevel.segments = 1


def stage(name, ratio, world_color):
    global scene
    scene = bpy.data.scenes.new(name)
    bpy.context.window.scene = scene
    scene.world = bpy.data.worlds.new(name + " ambience")
    scene.world.use_nodes = True
    back = scene.world.node_tree.nodes.get("Background")
    back.inputs[0].default_value = (*linear_color(world_color), 1)
    back.inputs[1].default_value = .67
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8 if PREVIEW else 22
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.resolution_x, scene.render.resolution_y = ratio
    scene.render.resolution_percentage = 45 if PREVIEW else 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    OUT.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(OUT / ("previews" if PREVIEW else "plates") / f"{name}.png")
    Path(scene.render.filepath).parent.mkdir(exist_ok=True)


def build():
    wide, square = (1920, 1080), (1024, 1024)
    stage("01-lock-in", wide, "87A9D3")
    rooftop()
    cam = camera((.1, -8.4, 4.8), (.4, 7, 7.0), 25, -4)
    fighter("Blue avatar | Updraft", (4.1, 4.1, 3.16), 155, BLUE, pose="air", scale=1.09, head_yaw=12, aim_yaw=-32)
    fighter("Orange opponent", (8.8, 13, 0), -155, ORANGE, style="Gold", scale=.91, aim_yaw=22)
    fx = collection("Updraft | shaped wind wedges")
    rng = random.Random(214)
    for i in range(7):
        x = 3.7 + rng.uniform(-1.7, 1.7)
        y = 3.8 + rng.uniform(-1.4, 1.4)
        a, b = (x + .75, y, .36 + i * .25), (x - .17, y + .24, rng.uniform(3.2, 6.0))
        v1, v2 = Vector(a), Vector(b)
        wedge = [v1, v1.lerp(v2, .42) + Vector((.14, 0, 0)), v2, v1.lerp(v2, .62) - Vector((.058, 0, 0))]
        flat_mesh(fx, "Tapered wind blade", wedge, [(0, 1, 2, 3)], material("Updraft wind", "66CEFF", glow=2.5))
    point(fx, "Wind accents", (4.2, 2.9, 3.7), "4AC9FF", 55, 2.2)

    stage("02-foundry-duel", wide, "313B56")
    foundry()
    cam = camera((3.5, -12.9, 4.10), (1.05, 14.0, 4.60), 22, -5)
    fighter("Gold challenger", (.5, 3.5, .25), 160, GOLD, style="Gold", pose="hold", scale=1.04)
    fx, rifle = first_person(cam, (.5, 3.5, 4.2))
    muzzle = rifle @ Vector((2.68, 0, .29))
    burst(fx, muzzle, cam, "FFC666", .32, 9, 223)
    fx_trail(fx, muzzle, (.48, 3.35, 4.18), "FFC05E", .023)
    burst(fx, (.39, 3.0, 4.14), cam, "FFB94D", .54, 10, 81)

    stage("03-blue-v-orange", wide, "343B57")
    foundry()
    cam = camera((0, -7.7, 3.95), (0, 5, 3.55), 34, 0)
    fighter("Blue team", (-3.12, 2.40, 0), -140, BLUE, head_yaw=-12, scale=1.06, aim_yaw=30)
    fighter("Orange team", (3.27, 2.13, 0), 142, ORANGE, head_yaw=16, scale=1.06, aim_yaw=-47)
    area("Blue team rim", (-5, 4, 6.5), (-2, 3, 3.4), "5BA9FF", 380, 4)
    area("Orange team rim", (5, 4, 6.5), (2, 3, 3.4), "FF9B59", 390, 4)
    fx = collection("Blue and orange challenge marks")
    for side, hue in ((-1, "58AAFF"), (1, "FF9145")):
        for i in range(3):
            fx_trail(fx, (side * (4.0 + i * .66), 3.7 + i * .18, 1.2), (side * (5.5 + i * .5), 4.9 + i * .18, 5.1), hue, .045)

    stage("04-rooftop-slide", wide, "7F9AC1")
    rooftop()
    cam = camera((-.4, -5.3, 2.5), (.3, 8.5, 3.60), 25, 6)
    fighter("Blue slide", (-2.41, 3.0, 0), -152, BLUE, pose="slide", head_yaw=-19, scale=1.19, aim_yaw=43)
    fighter("Orange on the roof lane", (6.25, 15.3, .05), 154, ORANGE, pose="hold", scale=1.03, aim_yaw=-18)
    fx = collection("Slide | short surface streaks")
    for i in range(7):
        fx_trail(fx, (-4.6 + i * .53, 3.5 + i * .13, .11), (-5.1 + i * .54, 9 + i * .22, .17), "E5C375", .036)
    burst(fx, (5.8, 14.1, 3.7), cam, "FFAE60", .52, 7, 13)

    stage("05-tempest-inspect", wide, "6E8FBE")
    rooftop()
    cam = camera((-.2, -9.2, 6.1), (-.5, 12, 8.30), 31, -5)
    cam.data.dof.use_dof = True
    cam.data.dof.focus_distance, cam.data.dof.aperture_fstop = 3.70, 4.1
    fx, rifle = first_person(cam, None, True)
    for xyz in ((.2, 0, .28), (1.0, .08, .30), (1.8, .02, .28), (2.42, 0, .22)):
        burst(fx, rifle @ Vector(xyz), cam, "76F4FF", .15, 5, 31)

    for name, style, color in (("icon-lobby-gold", "Gold", GOLD), ("icon-bacon", "Bacon", GOLD)):
        stage(name, square, "262C3E")
        cam = camera((.35, -8.4, 5.34), (.47, .3, 4.04), 66, 0)
        coll = collection("Black and gold Draft Ticket stage")
        dark = material("Icon backdrop graphite", "10141D", rough=.7)
        box(coll, "Graphite background", (0, 3.15, 4.1), (14, .25, 14), dark)
        ticket(coll, .45, 4.13, 1.23, color, -10)
        fighter("Icon duelist", (0, .1, 0), -126, color, style=style, pose="hold", head_yaw=-43, aim_yaw=20)
        area("Warm front key", (-2.2, -4.5, 7.4), (0, 0, 3.64), "FFF2C9", 530, 4)
        area("Gold rim", (3.4, 1, 6.1), (0, 0, 3.60), "FFD453", 340, 3)
        area("Cool fill", (3, -4, 3), (0, 0, 3.6), "B9D1FF", 160, 4)
        point(coll, "Ticket bounce", (0, 1.8, 3.8), "FFB62D", 120, 1.25)

    stage("icon-blue-v-orange", square, "273149")
    cam = camera((0, -8.7, 5.22), (0, .4, 4.02), 55)
    coll = collection("Split gold ticket frame")
    ticket(coll, 0, 3.88, 1.25, GOLD, -8)
    box(coll, "Blue backing", (-4, 3.25, 3.9), (8, .2, 14), material("Blue backdrop", "223C67", .03, .32))
    box(coll, "Orange backing", (4, 3.25, 3.9), (8, .2, 14), material("Orange backdrop", "81371A", .03, .40))
    fighter("Icon blue", (-1.33, .15, 0), -143, BLUE, head_yaw=-15, scale=.90, aim_yaw=-38)
    fighter("Icon orange", (1.44, .37, 0), 139, ORANGE, head_yaw=15, scale=.90, style="Gold", aim_yaw=35)
    area("Two-team key", (0, -4.6, 7), (0, 0, 3.8), "FFF1DF", 580, 4)
    area("Blue edge", (-3, 2.1, 6), (-1, 0, 3.7), "5D9FFF", 220, 2.5)
    area("Orange edge", (3, 2.1, 6), (1, 0, 3.7), "FFAC58", 260, 2.5)


def add_match_rig_reference():
    # The production FBX has five skinned segments, each with its original armature.
    rig_scene = bpy.data.scenes.new("Reference | Skinned match body")
    bpy.context.window.scene = rig_scene
    bpy.ops.import_scene.fbx(filepath=str(ART / "body/SkinnedLimbs.fbx"))
    return rig_scene


def main():
    default = bpy.context.scene
    build()
    bpy.data.scenes.remove(default)
    first = bpy.data.scenes["01-lock-in"]
    bpy.context.window.scene = first
    bpy.context.preferences.filepaths.save_version = 0
    if not PREVIEW:
        add_match_rig_reference()
        bpy.context.window.scene = first
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "DraftDuelsLaunch.blend"), compress=True)
    for shot in sorted((s for s in bpy.data.scenes if s.camera), key=lambda s: s.name):
        print(f"Rendering {shot.name}", flush=True)
        bpy.context.window.scene = shot
        bpy.ops.render.render(write_still=True, scene=shot.name)


if __name__ == "__main__":
    main()
