"""Build and review the Poolside Spectre in an isolated Blender process."""

import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_full_reskins as review
from build_skin_roster import Nodes, bake, fingerprints, mesh_objects, rel, write_json
from check_hand_clipping import box_from, depth_inside
from skin_graphics import linear

ITEM = "Spectre"
SOURCE = review.source(ITEM)
CONCEPT = review.roster.VAULT / "Poolside/out/Spectre_concept_v01.png"
BASE = review.ART / "Skins/Poolside/Spectre"
PALETTE = {"blue": "4DB6E4", "white": "F4EBDD", "yellow": "FFD65A", "navy": "172739"}
PANELS = ("Spectre_Receiver", "Spectre_Handguard")
REST_POSITION = "PoolsideRestPosition"
LANE_START, LANE_END = -.44, 1.27
LANE_BASE, LANE_RISE = .273, .121
LANE_GAP, SHOULDER = .032, .62
CLIPS = {"Draw": "Root", "Fire": "Bolt", "Inspect": "Root",
         "Reload": "Mag", "ReloadEmpty": "ChargingHandle"}


def rgba(key):
    return (*linear(PALETTE[key]), 1)


def smooth(graph, value, start, stop, label):
    node = graph.node("MapRange", label, interpolation_type="SMOOTHERSTEP", clamp=True)
    graph.set(node.inputs["Value"], value)
    node.inputs["From Min"].default_value = start
    node.inputs["From Max"].default_value = stop
    return node.outputs["Result"]


def stripe_graph(graph):
    # A shared rest-space field keeps the side-to-top return and the
    # receiver/handguard join coherent even while Root is animated.
    xyz = graph.node("SeparateXYZ", "Rest-space position")
    graph.set(xyz.inputs[0], graph.attr(REST_POSITION).outputs["Vector"])
    x, y, z = xyz.outputs[:]
    math_node = graph.math
    shoulder = math_node("SUBTRACT", z, math_node("MULTIPLY", math_node("ABSOLUTE", y), SHOULDER))
    bend = smooth(graph, x, LANE_START, LANE_END, "Lane bend")
    lane = math_node("ADD", LANE_BASE, math_node("MULTIPLY", bend, LANE_RISE))
    offset = math_node("SUBTRACT", shoulder, lane)
    first = smooth(graph, math_node("ABSOLUTE", offset), .0095, .0130, "Outer lane edge")
    second = smooth(graph, math_node("ABSOLUTE", math_node("SUBTRACT", offset, LANE_GAP)),
                    .0095, .0130, "Inner lane edge")
    stripes = math_node("SUBTRACT", 1, math_node("MULTIPLY", first, second))
    # The yellow inlay graphic lives on the player-facing shoulder alone.
    left = smooth(graph, y, .050, .054, "Left shoulder only")
    start = smooth(graph, x, .260, .264, "Block start")
    end = smooth(graph, x, .375, .371, "Block end")
    block = smooth(graph, math_node("ABSOLUTE", math_node("SUBTRACT", offset, .053)),
                   .0075, .0100, "Block height")
    mark = math_node("MULTIPLY", math_node("MULTIPLY", left, start),
                     math_node("MULTIPLY", end, math_node("SUBTRACT", 1, block)))
    paint = graph.mix(stripes, rgba("blue"), rgba("white"), color=True)
    return graph.mix(mark, paint, rgba("yellow"), color=True)


def author():
    for name in PANELS:
        ob = bpy.data.objects[name]
        layer = ob.data.attributes.new(REST_POSITION, "FLOAT_VECTOR", "POINT")
        coords = [component for v in ob.data.vertices for component in ob.matrix_world @ v.co]
        layer.data.foreach_set("vector", coords)

    for mat in bake.gun_materials(ITEM):
        if mat.name in {"Neon", "Brass"}:
            continue
        tree = mat.node_tree
        graph = Nodes(tree)
        bsdf = tree.nodes["Principled BSDF"]
        output = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output)
        for node in list(tree.nodes):
            if node not in (bsdf, output) and mat.name != "Grip":
                tree.nodes.remove(node)

        enamel = mat.name == "Body"
        grip = mat.name == "Grip"
        base = stripe_graph(graph) if enamel else rgba("navy")
        center_rough = .32 if enamel else .74 if grip else .58
        metallic = .06 if enamel else .0 if grip else .22
        graph.set(bsdf.inputs["Base Color"], base)
        graph.set(bsdf.inputs["Roughness"], center_rough)
        graph.set(bsdf.inputs["Metallic"], metallic)
        mat.diffuse_color = rgba("blue" if enamel else "navy")
        mat.roughness = center_rough
        mat.metallic = metallic

        if enamel:
            coords = graph.node("TexCoord", "Local enamel grain")
            grain = graph.node("TexNoise", "Fine enamel grain")
            graph.set(grain.inputs["Vector"], coords.outputs["Object"])
            grain.inputs["Scale"].default_value = 68
            grain.inputs["Detail"].default_value = 1.5
            graph.set(bsdf.inputs["Roughness"], graph.mix(grain.outputs["Fac"], .288, .352))
            bump = graph.node("Bump", "Satin microtexture")
            bump.inputs["Strength"].default_value = .10
            bump.inputs["Distance"].default_value = .002
            graph.set(bump.inputs["Height"], grain.outputs["Fac"])
            graph.set(bsdf.inputs["Normal"], bump.outputs[0])
            bsdf.inputs["Coat Weight"].default_value = .13
            bsdf.inputs["Coat Roughness"].default_value = .33
        review.roster.organize_tree(tree, {output}, bsdf,
                                    ("Base Color", "Roughness", "Metallic", "Normal"))
        bsdf.location = (0, 0)
        output.location = (320, 0)


def cameras():
    framing = review.F
    aim = bpy.data.objects["Spectre_Cam_ADS"]
    hip = bpy.data.objects["Spectre_Cam_Hip"]
    lo, hi = framing.bounds(ITEM)
    center = (lo + hi) / 2
    radius = (hi - lo).length / 2
    fixed = {name: (review._cam(ITEM, name), (1280, 720))
             for name in ("hero", "left", "right", "top", "held")}
    fixed["hip"] = ((hip, center, radius), (1280, 720))
    fixed["aim"] = ((aim, center, radius), (1280, 720))
    for name, target, toward, scale in (
        ("seam", (.68, .049, .393), (.12, 1, .61), .86),
        ("grazing", (.70, .020, .396), (-.89, .39, .27), 1.02),
    ):
        ctr = Vector(target)
        cam = framing.camera(ITEM, "Poolside_" + name, ctr + 4 * Vector(toward), ctr, ortho=scale)
        fixed[name] = ((cam, ctr, .85), (1280, 720))
    return fixed


def still(name, setup, folder, *, cull=False):
    cam, center, radius = setup[0]
    size = setup[1]
    path = str(folder / (name + ".png"))
    scene = bpy.context.scene
    if cull:
        shade = scene.display.shading
        shade.light = "STUDIO"
        shade.color_type = "MATERIAL"
        shade.show_backface_culling = True
        scene.display.render_aa = "8"
        engine, film = scene.render.engine, scene.render.film_transparent
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.render.film_transparent = True
        try:
            review.F.shot(ITEM, cam, path, res=size)
        finally:
            scene.render.engine, scene.render.film_transparent = engine, film
    else:
        review.M._lights(ITEM, cam, center, radius)
        review.M._shot(ITEM, cam, path, size, studio=name not in {"hip", "aim"}, samples=24)


def snapshot(objects):
    graph = bpy.context.evaluated_depsgraph_get()
    return {ob.name: review.roster.matrix(ob.evaluated_get(graph).matrix_world) for ob in objects}


def mesh_accelerator(ob):
    mesh = ob.data
    points = [ob.matrix_world @ v.co for v in mesh.vertices]
    mesh.calc_loop_triangles()
    triangles = [tuple(t.vertices) for t in mesh.loop_triangles]
    tree = BVHTree.FromPolygons(points, triangles, all_triangles=True)
    return points, triangles, tree


def hand_contacts():
    # The project captured these arm blocks in each gun joint's local pose.
    # Apply the same archived samples to both current v05 mesh sets.
    meshes = []
    for ob in mesh_objects(ITEM):
        points, _, tree = mesh_accelerator(ob)
        meshes.append((ob, points, tree))
    directory = review.ROOT / "art-source/viewmodel/checks"
    result = {}
    for mode in ("hold", "inspect"):
        path = directory / f"Spectre_{mode}.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        samples = []
        for frame in data["frames"]:
            hits = {}
            for side, joints in frame["arms"].items():
                boxes = {joint: box_from(matrix, data["half"]) for joint, matrix in joints.items()}
                for ob, points, tree in meshes:
                    center, axes, _, box = boxes.get(ob.parent_bone, boxes["Root"])
                    depth = max(depth_inside(p, center, axes, data["half"]) for p in points)
                    if box.overlap(tree) or depth > 0:
                        hits[f"{side}/{ob.name}"] = round(max(depth, .001), 4)
            samples.append(hits)
        result[mode] = {
            "capture": rel(path), "frames": len(samples),
            "contact_parts": sorted(set().union(*(hits.keys() for hits in samples))),
            "sample_sha256": review.roster.digest(samples),
        }
    return result


def baked_seam():
    # Sample the reopened color atlas via the stock UVs on both fixed panels.
    import numpy as np

    img = bpy.data.images["Spectre_Color"]
    width, height = img.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    img.pixels.foreach_get(pixels)
    pixels = pixels.reshape(height, width, 4)
    report = {}
    probes = ((PANELS[0], .673), (PANELS[1], .718))
    for name, x in probes:
        ob = bpy.data.objects[name]
        points, triangles, tree = mesh_accelerator(ob)
        mesh = ob.data
        uv = mesh.uv_layers.active.uv
        t = min(1, max(0, (x - LANE_START) / (LANE_END - LANE_START)))
        lane = LANE_BASE + LANE_RISE * (t**3 * (t * (6*t - 15) + 10))
        bands = [[], []]
        for z in np.linspace(.355, .475, 241):
            hit, _, index, _ = tree.ray_cast(Vector((x, 1, z)), Vector((0, -1, 0)), 1.2)
            if hit is None:
                continue
            triangle = mesh.loop_triangles[index]
            if ob.material_slots[triangle.material_index].name != "Body":
                continue
            sample = barycentric_transform(hit, *(points[i] for i in triangles[index]),
                                           *(Vector((*uv[l].vector, 0)) for l in triangle.loops))
            u = max(0, min(width - 1, int(sample.x * width)))
            v = max(0, min(height - 1, int(sample.y * height)))
            r, g, b, _ = pixels[v, u]
            if r < .35 or not .76 < r / max(g, .001) < 1.24 or not .75 < r / max(b, .001) < 1.55:
                continue
            residual = hit.z - SHOULDER * abs(hit.y) - lane
            for i in (0, 1):
                offset = residual - i * LANE_GAP
                if abs(offset) < .014:
                    bands[i].append(offset)
        report[name] = {"x": x, "white_samples_per_lane": [len(band) for band in bands],
                        "mean_offset_in_model_units": [round(float(np.mean(band)), 5) if band else None
                                                       for band in bands]}
    return report


def motion(folder=None):
    scene = bpy.context.scene
    rig = bpy.data.objects["Spectre_Rig"]
    animation = rig.animation_data
    original_action, original_slot = animation.action, animation.action_slot
    original_frame = scene.frame_current
    original_pose = {bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones}
    objects = list(bpy.data.collections[ITEM].all_objects)
    reports = {}
    for clip, moving_bone in CLIPS.items():
        animation.action = None
        for bone in rig.pose.bones:
            bone.matrix_basis = original_pose[bone.name]
        action = bpy.data.actions[f"{ITEM}_{clip}"]
        animation.action = action
        animation.action_slot = action.slots[0]
        start, end = (round(frame) for frame in action.frame_range)
        frames = {}
        excursion = {}
        scene.frame_set(start)
        basis = rig.pose.bones[moving_bone].matrix.copy()
        for f in range(start, end + 1):
            scene.frame_set(f)
            frames[f] = snapshot(objects)
            pose = rig.pose.bones[moving_bone].matrix.copy()
            delta = basis.inverted() @ pose
            angle = delta.to_quaternion().angle
            excursion[f] = delta.translation.length + min(angle, 2 * math.pi - angle)
        peak = max(excursion, key=excursion.get)
        assert excursion[peak] > .001, (clip, excursion[peak])
        reports[clip] = {"frames": [start, end], "sample_count": len(frames),
                         "tracked_bone": moving_bone, "peak_frame": peak,
                         "evaluated_world_matrix_sha256": review.roster.digest(frames)}
        if folder:
            frame = peak
            scene.frame_set(frame)
            points = review.M._pts(ITEM)
            towards = (.12, .87, .44) if clip in {"Draw", "Inspect"} else (.18, .95, .17)
            cam = review.M._cam(ITEM, "Poolside_Motion", points, towards,
                                ortho=True, margin=1.10)
            still(f"{clip.lower()}-{frame:03}", (cam, (860, 484)), folder)
    animation.action = original_action
    if original_slot:
        animation.action_slot = original_slot
    for bone in rig.pose.bones:
        bone.matrix_basis = original_pose[bone.name]
    scene.frame_set(original_frame)
    return reports


def setup_review():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.image_settings.color_mode = "RGBA"
    return scene


def build(version):
    path = BASE / version
    output = path / f"Spectre_Poolside_{version}.blend"
    assert Path(bpy.data.filepath) == SOURCE and not path.exists()
    path.mkdir(parents=True)
    scene = bpy.context.scene
    objs = mesh_objects(ITEM)
    reference = fingerprints(ITEM)
    uv = review.roster.audit_uv(objs, size=1024)
    assert uv["cross_object_overlap_pixels"] == uv["same_object_overlap_pixels"] == 0
    topology = review._topology(ITEM)
    aim = review._aim(ITEM)
    sightline = review.F.sightline(ITEM)
    assert not sightline["geo_hits"] and not sightline["box_hits"]

    author()
    review.roster.bake_maps(ITEM, scene, objs, path / "textures")
    # Give the baked shader the same satin finish constants as the editable
    # enamel graph. The four PBR channels still come directly from the atlas.
    body = bpy.data.materials["Body"].node_tree.nodes
    body["PV_BSDF"].inputs["Coat Weight"].default_value = .13
    body["PV_BSDF"].inputs["Coat Roughness"].default_value = .33
    assert fingerprints(ITEM) == reference

    cams = cameras()
    cam, center, radius = cams["hero"][0]
    review.M._lights(ITEM, cam, center, radius)
    scene.camera = cam
    scene.render.engine = "BLENDER_EEVEE"
    bpy.data.collections["Spectre_RV2_Lights"].hide_render = True
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.6
    scene.render.resolution_x, scene.render.resolution_y = cams["hero"][1]
    scene.render.filepath = "//review/poolside/hero.png"
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(output), relative_remap=False, compress=True)
    write_json(path / "manifest.json", {
        "line": "Poolside", "item": ITEM, "version": version,
        "source": rel(SOURCE), "concept": rel(CONCEPT), "blend": rel(output),
        "source_file_sha256": review.sha(SOURCE), "concept_file_sha256": review.sha(CONCEPT),
        "stock_uv_preserved": True, "source_fingerprints": reference, "uv": uv,
        "triangles": review.F.tris(ITEM), "topology_and_stock_candidates": topology,
        "stock_aim_camera": aim, "stock_sightline": sightline, "palette_srgb": PALETTE,
        "painted_fixed_panels": PANELS, "protected_stock_shaders": ["Neon", "Brass"],
        "map_resolution": [1024, 1024], "bake_padding_pixels": 6,
        "stock_binding": ("Use the four shared maps on the v05 Spectre's existing mesh parts "
                          "and active UV atlas. Keep native sight emission and ammunition shaders "
                          "where those effects are required. Tangent-space normal is +Y."),
        "review_state": "Baked, pending reopen and review",
    })


def verify(version):
    path = BASE / version
    report_path = path / "manifest.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    assert bpy.data.filepath == str(path / f"Spectre_Poolside_{version}.blend")
    scene = setup_review()
    # Use the stock review ambient level for both sides of the comparisons.
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .55
    assert fingerprints(ITEM) == report["source_fingerprints"]
    assert review._topology(ITEM) == report["topology_and_stock_candidates"]
    assert review._aim(ITEM) == report["stock_aim_camera"]
    assert review.F.sightline(ITEM) == report["stock_sightline"]
    assert review.sha(SOURCE) == report["source_file_sha256"]
    report["maps"] = {}
    for name in bake.MAPS:
        image = bpy.data.images[f"{ITEM}_{name}"]
        disk = path / "textures" / f"{ITEM}_{name}.png"
        assert image.packed_file and image.packed_file.data == disk.read_bytes()
        assert list(image.size) == report["map_resolution"]
        report["maps"][name] = {"file": rel(disk), "sha256": review.sha(disk),
                                "color_space": image.colorspace_settings.name}
    for name in ("Body", "Panel", "Dark", "Metal", "Grip", "Accent"):
        assert bpy.data.materials[name].node_tree.nodes["PV_Out"].is_active_output
    seam = baked_seam()
    receiver, handguard = (seam[panel] for panel in PANELS)
    assert all(count >= 12 for panel in seam.values() for count in panel["white_samples_per_lane"]), seam
    assert all(abs(a - b) <= .004 for a, b in zip(
        receiver["mean_offset_in_model_units"], handguard["mean_offset_in_model_units"]
    )), seam
    skin_hands = hand_contacts()

    dest = path / "review"
    variant_folder, stock_folder = dest / "poolside", dest / "stock"
    variant_folder.mkdir(parents=True, exist_ok=True)
    stock_folder.mkdir(parents=True, exist_ok=True)
    views = cameras()
    for name, setup in views.items():
        still(name, setup, variant_folder)
    for name in ("left", "right", "grazing"):
        still(name + "-culled", views[name], variant_folder, cull=True)
    skin_motion = motion(variant_folder)

    review.open_file(SOURCE)
    setup_review()
    assert hand_contacts() == skin_hands, "Stock clearance against recorded arm samples changed"
    for name, setup in cameras().items():
        still(name, setup, stock_folder)
    stock_motion = motion(stock_folder)
    assert stock_motion == skin_motion, (stock_motion, skin_motion)
    report.update(saved_file_verified=True, motion=skin_motion,
                  baked_seam_samples=seam, stock_hand_clearance_parity=skin_hands,
                  matched_review_views=list(views), review_renders=rel(dest),
                  review_state="Reopened and rendered. Visual review pending.")
    write_json(report_path, report)


if __name__ == "__main__":
    command, version = sys.argv[sys.argv.index("--") + 1:]
    {"build": build, "verify": verify}[command](version)
