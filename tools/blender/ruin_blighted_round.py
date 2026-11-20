"""Shadow Mist cartridge from the owner concept's close-up."""

import json
from math import cos, sin, tau
from pathlib import Path

import bpy
from mathutils import Vector

import build_ruin_blighted_expansion as art


def round_meshes(col, center, length):
    # X is the flight axis. Make the obsidian nose and spectral heel read
    # independently even at the size of a loaded prop.
    stone = art.material("Shadow Mist cartridge - obsidian", "15232A", .35, .55)
    facets = art.material("Shadow Mist cartridge - fracture edge", "344950", .35, .48)
    jade = art.material("Shadow Mist cartridge - jade", "257969", .21, .40, emission=.19)
    seafoam = art.material("Shadow Mist cartridge - seafoam", "68EACB", .10, .35, emission=.70)

    def shell(name, rings, material, second):
        count = 9
        verts = []
        for x, radius, cut in rings:
            for i in range(count):
                theta = tau * (i + .5) / count
                r = radius * (1 + .045 * sin(i * 3.8))
                verts.append(Vector((x + cut * sin(i * 2.3), r * cos(theta), r * sin(theta))) * length + center)
        faces = [tuple(range(count)), tuple(range(len(verts) - count, len(verts)))]
        for row in range(len(rings) - 1):
            low, high = row * count, (row + 1) * count
            for i in range(count):
                j = (i + 1) % count
                faces.append((low + i, low + j, high + j, high + i))
        obj = art.mesh(col, name, verts, faces, material)
        obj.data.materials.append(second)
        for polygon in obj.data.polygons:
            if polygon.index > 1 and polygon.index % count in (1, 5, 8):
                polygon.material_index = 1
        return obj

    case = shell("RB_Round_Case", (
        (-.50, .078, 0), (-.476, .101, 0), (-.438, .105, 0),
        (-.391, .089, 0), (-.35, .103, .009), (-.10, .105, .009),
        (-.018, .084, .031), (.037, .069, .027),
    ), jade, stone)
    tip = shell("RB_Round_Obsidian", (
        (-.044, .068, .018), (.073, .086, .022), (.184, .076, .017),
        (.337, .050, .021), (.467, .016, .012), (.50, .002, 0),
    ), stone, facets)
    rim = shell("RB_Round_Heel", (
        (-.479, .095, 0), (-.459, .107, 0), (-.428, .107, .003),
        (-.408, .098, 0),
    ), seafoam, jade)
    channels = []
    for i in (0, 2, 5, 7):
        theta = tau * (i + 1) / 9
        points = []
        for x, angle, r in ((-.424, theta, .103), (-.316, theta+.18, .102),
                             (-.272, theta-.014, .105), (-.224, theta+.26, .103),
                             (-.14, theta+.22, .103)):
            points.append(center + Vector((x, cos(angle)*r, sin(angle)*r)) * length)
        for j, (a, b) in enumerate(zip(points, points[1:])):
            channels.append(art.beam(col, f"RB_Round_SpectralFissure_{i}_{j}", a, b,
                                     length * (.007 if j < 2 else .0045), seafoam, 5, taper=.75))
    return [case, tip, rim, *channels]


def build():
    scene = bpy.context.scene
    art.setup(scene)
    scene.name = "Ruin-Blighted | Shadow Mist round"
    dest = art.next_version("ShadowMistRound")
    col = art.collection(scene, "Shadow Mist | Round")
    rounds = round_meshes(col, Vector(), .45)
    rig = art.armature(col, "Shadow Mist | Export datum", [("Root", (0, 0, 0), None)])
    for obj in rounds:
        art.bind(obj, rig, "Root")
    for name, angle in (("hero", (-.20, .87, .34)), ("profile", (0, 1, 0))):
        camera = art.framed_camera(col, f"Shadow Mist round {name}", art.points(rounds), angle, 1.8, 1.22)
        art.render(scene, camera, dest / "review" / f"{name}.png", 1, (1152, 640))
        if name == "hero":
            scene.camera = camera
            hero = camera
    scene.camera = hero
    output = dest / f"ShadowMistRound_{dest.name}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    fbx, parts = art.export_flat(rounds, str(dest), "ShadowMistRound", art.LINE)
    manifest = {
        "version": dest.name,
        "file": Path(fbx).name,
        "length": .45,
        "parts": {name: {"center": spec["center"], "size": spec["size"],
                          "color": spec["color"], "material": spec["material"],
                          "glow": "seafoam" in spec["blender_material"]}
                  for name, spec in parts.items()},
    }
    (dest / "manifest_round.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return str(output)
