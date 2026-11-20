"""Build the editable overtime zone and a geometry-only GLB for Studio.

Run in Blender with this repository as the working directory, or call
build(repo) through Blender MCP. Deliberately leaves other scenes alone.
"""
from pathlib import Path
from collections import Counter
import math
import random

import bpy
from mathutils import Vector


def storm_mask(output: Path, sky: bool):
    """A horizontally seamless alpha tile with a lower glow and soft upper fade."""
    import numpy as np

    width, height = 512, 512
    u = np.arange(width, dtype=np.float32)[None, :] / width
    v = (np.arange(height, dtype=np.float32)[:, None] + 0.5) / height
    angle = math.tau * u
    lower = np.exp(-((v - 0.32) / 0.12) ** 2)
    upper = np.exp(-((v - 0.43) / 0.18) ** 2)
    folds = (0.5 + 0.5 * np.sin(angle * 3 + v * 10 + np.sin(angle) * 1.4)) ** 3
    grain = (0.5 + 0.5 * np.cos(angle * 13 - v * 17)) ** 4
    sweep = np.exp(-((v - 0.334 - 0.022 * np.sin(angle * 2)) / 0.008) ** 2)
    dash = (0.5 + 0.5 * np.cos(angle * 4 + v * 8)) ** 3
    fade_in = np.clip((v - 0.06) / 0.13, 0, 1)
    fade_out = np.clip((0.77 - v) / 0.25, 0, 1)
    if sky:
        # At 320 studs with a 30-stud underhang, the floor is just below V=.1.
        # The taller storm builds opacity above typical cover and feathers at the top.
        sky_body = np.clip((v - 0.075) / 0.31, 0, 1)
        feather = np.clip((0.995 - v) / 0.12, 0, 1)
        foot = np.clip(v / 0.067, 0, 1)
        ribs = (0.5 + 0.5 * np.cos(angle * 2 - v * 12 + np.sin(angle) * 0.8)) ** 2
        crest = np.exp(-((v - 0.846 - 0.021 * np.sin(angle * 2)) / 0.051) ** 2)
        opacity = foot * feather * (
            0.15 + sky_body * (0.27 + 0.16 * ribs + 0.06 * folds)
            + 0.075 * ribs + 0.22 * crest
        )
    else:
        opacity = fade_in * fade_out * (
            0.04 + lower * (0.10 + 0.18 * folds + 0.035 * grain) + upper * folds * 0.055
            + 0.14 * sweep * dash
        )
    pixels = np.ones((height, width, 4), dtype=np.float32)
    pixels[:, :, 3] = opacity
    image = bpy.data.images.new("Overtime curtain opacity", width, height, alpha=True)
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw = str(output / "OvertimeCurtain.png")
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def build(repo: Path, version: int = 2) -> dict:
    name = f"OvertimeZone_v{version:02d}"
    output = repo / "art-source" / "vfx" / "zone" / name
    output.mkdir(parents=True, exist_ok=True)
    scene = bpy.data.scenes.new(f"Overtime Zone v{version:02d}")
    bpy.context.window.scene = scene
    assets = bpy.data.collections.new("Zone meshes")
    scene.collection.children.link(assets)
    staging = bpy.data.collections.new("Review")
    scene.collection.children.link(staging)

    def emission(name, color, strength, alpha=1):
        material = bpy.data.materials.new(name)
        material.diffuse_color = (*color, alpha)
        material.use_nodes = True
        nodes = material.node_tree.nodes
        shader = nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = (*color, 1)
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = strength
        shader.inputs["Alpha"].default_value = alpha
        shader.inputs["Roughness"].default_value = 0.85
        return material

    veil = emission("Violet storm curtain", (0.33, 0.055, 0.51), 0.65, 0.22)
    stitch = veil.node_tree.nodes.new("ShaderNodeTexImage")
    stitch.image = storm_mask(output, sky=version >= 2)
    alpha = veil.node_tree.nodes.new("ShaderNodeMath")
    alpha.operation = "MULTIPLY"
    alpha.inputs[1].default_value = 1.0
    veil.node_tree.links.new(stitch.outputs["Alpha"], alpha.inputs[0])
    veil.node_tree.links.new(alpha.outputs[0], veil.node_tree.nodes["Principled BSDF"].inputs["Alpha"])
    rim = emission("Pink boundary line", (0.82, 0.17, 0.55), 2.1)
    flecks = emission("Lilac storm fragments", (0.66, 0.18, 1.0), 1.5, 0.68)
    count = 128

    def radial(radius, angle, height):
        return (radius * math.cos(angle), radius * math.sin(angle), height)

    def mesh(name, vertices, faces, material, collection=assets):
        data = bpy.data.meshes.new(name)
        data.from_pydata(vertices, [], faces)
        assert not data.validate(), name
        data.update()
        obj = bpy.data.objects.new(name, data)
        collection.objects.link(obj)
        obj.data.materials.append(material)
        return obj

    def rings(profile, close_profile=False):
        vertices = [
            radial(r, math.tau * i / count, z)
            for r, z in profile for i in range(count)
        ]
        faces = []
        for row in range(len(profile) if close_profile else len(profile) - 1):
            a, b = row * count, (row + 1) % len(profile) * count
            for i in range(count):
                j = (i + 1) % count
                faces.append((a + i, a + j, b + j, b + i))
        return vertices, faces

    curtain = mesh("Curtain", *rings([(1, -0.5), (1, 0.5)]), veil)
    uv = curtain.data.uv_layers.new(name="Storm tiles")
    for i, face in enumerate(curtain.data.polygons):
        left = (i % 8) / 8
        right = left + 1 / 8
        for loop, value in zip(face.loop_indices, ((left, 0), (right, 0), (right, 1), (left, 1))):
            uv.data[loop].uv = value
    edge = mesh(
        "GroundTrace",
        *rings([(0.976, -0.06), (1, -0.06), (1, -0.005), (0.985, 0.06)], True),
        rim,
    )

    # Tapered fracture marks ride outside the curtain. The layers never share
    # a surface, even when the drift rotates against the underlying veil.
    rng = random.Random(83)
    vertices, faces = [], []
    for i in range(32):
        a = math.tau * i / 32
        width = rng.uniform(0.013, 0.024)
        z = rng.uniform(-0.46, 0.27)
        rise = rng.uniform(0.1, 0.28)
        corners = [
            (a - width * 0.4, z), (a + width, z + 0.025),
            (a + width * 0.42, z + rise), (a - width, z + rise * 0.75),
        ]
        k = len(vertices)
        vertices.extend(radial(1.025, angle, height) for angle, height in corners)
        faces.extend(((k, k + 1, k + 2), (k, k + 2, k + 3)))
    drift = mesh("Drift", vertices, faces, flecks)
    export = [curtain, edge, drift]

    # A closed wall circumference has exactly two open ring rims.
    degree = Counter(tuple(sorted((v, face[(i + 1) % len(face)])))
                     for face in rings([(1, -0.5), (1, 0.5)])[1]
                     for i, v in enumerate(face))
    assert set(degree.values()) == {1, 2} and sum(n == 1 for n in degree.values()) == 2 * count

    bpy.ops.object.select_all(action="DESELECT")
    for obj in export:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = curtain
    if version == 1:
        glb = output / f"{name}.glb"
        bpy.ops.export_scene.gltf(filepath=str(glb), use_selection=True, export_materials="PLACEHOLDER")

    # A review ground and camera live only in the editable Blender scene.
    floor_mat = emission("Charcoal review floor", (0.038, 0.05, 0.072), 0)
    mesh("Review floor", [(-6,-6,-0.08),(6,-6,-0.08),(6,6,-0.08),(-6,6,-0.08)],
         [(0,1,2,3)], floor_mat, staging)
    curtain.location.z = 0.25
    curtain.scale.z = 0.72
    if version >= 2:
        curtain.location.z = 0.99
        curtain.scale.z = 2.45
    edge.scale.x = edge.scale.y = 0.996
    drift.location.z = 0.20
    drift.scale.z = 0.36
    camera = bpy.data.objects.new("Review camera", bpy.data.cameras.new("Review camera"))
    staging.objects.link(camera)
    camera.location = (2.8, -3.75, 2.45)
    target = Vector((0, 0, 1.15 if version >= 2 else 0.18))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.8 if version >= 2 else 3.25
    scene.camera = camera
    world = bpy.data.worlds.new("Storm review")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.1, 0.12, 0.19, 1)
    scene.world = world
    lamp = bpy.data.objects.new("Soft overhead", bpy.data.lights.new("Soft overhead", "AREA"))
    lamp.location = (1, -0.5, 4)
    lamp.data.energy = 130
    lamp.data.shape = "DISK"
    lamp.data.size = 5
    staging.objects.link(lamp)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 900, 580
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(output / f"{name}.png")
    bpy.context.view_layer.update()
    for obj in export:
        obj.data.calc_loop_triangles()
    bpy.ops.wm.save_as_mainfile(
        filepath=str(output / f"{name}.blend"), copy=True, compress=True
    )
    return {
        "scene": scene.name,
        "triangles": {obj.name: len(obj.data.loop_triangles) for obj in export},
        "output": str(output),
    }


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[2])
