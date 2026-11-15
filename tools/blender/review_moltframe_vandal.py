"""Render and export Moltframe Vandal from the active Blender MCP review scene."""

import json
import sys
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(ROOT / "art-source/weapons/RemasterV2/_Library"))
import model_sheet as sheet

review_name = "MoltframeReview"
sheet.bind({"scene": lambda _gun: scene})
stock_light = next(c for c in scene.collection.children if "RV2_Lights" in c.name)
stock_range = next(c for c in scene.collection.children if "ADSRange" in c.name)
stock_light.hide_render = stock_range.hide_render = True
scene.render.film_transparent = True
scene.render.image_settings.color_mode = "RGBA"
scene.eevee.taa_samples = 32
world_bg = scene.world.node_tree.nodes.get("Background")
if world_bg:
    world_bg.inputs["Strength"].default_value = 1.6

def render(camera, name, res):
    scene.camera = camera
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(REVIEW / (name + ".png"))
    bpy.ops.render.render(write_still=True, scene=scene.name)

def studio_cam(name, points, direction, *, ortho=False, lens=60, margin=1.1, aspect=16/9):
    camera, center, radius = sheet._cam(review_name, name, points, direction, ortho=ortho,
                                      lens=lens, margin=margin, aspect=aspect)
    sheet._lights(review_name, camera, center, radius)
    return camera

def gameplay_cam(name, point, fov):
    data = bpy.data.cameras.new(name)
    camera = bpy.data.objects.new(name, data)
    scene.collection.objects.link(camera)
    data.sensor_fit = "VERTICAL"
    data.sensor_height = 24
    data.lens = 12 / math.tan(math.radians(fov) / 2)
    data.clip_start = .125
    camera.location = point
    camera.rotation_euler = Vector((1, 0, 0)).to_track_quat("-Z", "Y").to_euler()
    sheet._lights(review_name, camera, Vector((.7, 0, .115)), 1.95)
    return camera

def pair(name, camera, res=(960, 540)):
    for tag, enabled in (("stock", False), ("moltframe", True)):
        set_skin(enabled)
        render(camera, name + "_" + tag, res)

def world_bvh(obj, graph):
    evaluated = obj.evaluated_get(graph)
    mesh = evaluated.data
    return BVHTree.FromPolygons([evaluated.matrix_world @ v.co for v in mesh.vertices],
                                [p.vertices[:] for p in mesh.polygons])

def measure_clearance():
    checks = {}
    for action in actions:
        name = action.name.split(".")[0].removeprefix("Vandal_")
        if name not in {"Inspect", "Reload", "ReloadEmpty", "Fire"}:
            continue
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        hits = {}
        start, end = (int(frame) for frame in action.frame_range)
        for frame in range(start, end + 1):
            scene.frame_set(frame)
            graph = bpy.context.evaluated_depsgraph_get()
            targets = {n: world_bvh(source_meshes[n], graph) for n in
                       ("ChargingHandle", "Bolt", "Trigger", "FireSelector")}
            for part in ("Moltframe_Magazine", "Moltframe_MagHardware"):
                targets[part] = world_bvh(shell.objects[part], graph)
            for obj in shell.objects:
                if obj.parent_bone == "Mag" or obj.name.endswith("Hardware"):
                    continue
                bvh = world_bvh(obj, graph)
                for part, target in targets.items():
                    if bvh.overlap(target):
                        hits.setdefault(obj.name + " / " + part, []).append(frame)
        checks[name] = {"frames": end - start + 1, "intersections": hits}
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    scene.frame_set(1)
    return checks

def export():
    selected = list(bpy.context.selected_objects)
    active = bpy.context.view_layer.objects.active
    bpy.ops.object.select_all(action="DESELECT")
    mesh_data = {}
    copies = []
    for obj in shell.objects:
        # Roblox imports one MeshPart per object. Separate material faces while
        # retaining shared UVs and split normals at every material boundary.
        source = obj.data
        for material_index in sorted({p.material_index for p in source.polygons}):
            mat = source.materials[material_index]
            faces = [p for p in source.polygons if p.material_index == material_index]
            ids = sorted({index for face in faces for index in face.vertices})
            remap = {index: i for i, index in enumerate(ids)}
            mesh = bpy.data.meshes.new(obj.name + "_Export")
            mesh.from_pydata([obj.matrix_world @ source.vertices[i].co for i in ids], [],
                             [[remap[i] for i in face.vertices] for face in faces])
            mesh.materials.append(mat)
            mesh.update()
            uv = mesh.uv_layers.new(name="Moltframe")
            normals = []
            for polygon, face in zip(mesh.polygons, faces):
                polygon.use_smooth = True
                for new_i, old_i in zip(polygon.loop_indices, face.loop_indices):
                    if source.uv_layers.active:
                        uv.data[new_i].uv = source.uv_layers.active.data[old_i].uv
                    normals.append(obj.matrix_world.to_3x3() @ source.corner_normals[old_i].vector)
            mesh.normals_split_custom_set(normals)
            piece = bpy.data.objects.new(f"{obj.name}_{material_index:02}", mesh)
            scene.collection.objects.link(piece)
            piece.select_set(True)
            copies.append(piece)
            limits = bounds([v.co for v in mesh.vertices])
            mesh.calc_loop_triangles()
            shader = mat.node_tree.nodes.get("Principled BSDF")
            channels = list(mat.diffuse_color)[:3]
            rgb = ''.join(f'{round((v*12.92 if v <= .0031308 else 1.055*v**(1/2.4)-.055)*255):02X}' for v in channels)
            mesh_data[piece.name] = {
                "center": [(a+b)/2 for a, b in zip(*limits)],
                "size": [b-a for a, b in zip(*limits)],
                "bone": obj.parent_bone,
                "finish": mat.name,
                "mapped": mat in (alloy, fluid),
                "metal": shader.inputs["Metallic"].default_value > .3,
                "color": rgb,
                "triangles": len(mesh.loop_triangles),
            }
    try:
        bpy.ops.export_scene.fbx(filepath=str(OUT / "Vandal_Moltframe_Shell_v03.fbx"),
            use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS",
            use_mesh_modifiers=True, bake_anim=False, add_leaf_bones=False)
    finally:
        for piece in copies:
            mesh = piece.data
            bpy.data.objects.remove(piece, do_unlink=True)
            bpy.data.meshes.remove(mesh)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in selected:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = active
    return mesh_data

def review():
    motion_frames()
    for name, direction, kwargs in (
        ("hero", (.52,.72,.36), {"lens":60}),
        ("profile", (0,1,0), {"ortho":True}),
        ("held", (-.85,.34,.30), {"lens":50}),
        ("opposite", (-.34,-.86,.40), {"lens":60}),
    ):
        pair(name, studio_cam(name, stock_points, direction, **kwargs),
             (1200, 675) if name == "hero" else (960, 540))
    aim = next(o for o in gun.objects if o.name.startswith("Vandal_AimPoint")).matrix_world.translation
    pair("ads", gameplay_cam("Stock ADS 68°", aim - Vector((.45, 0, 0)), 68))
    pair("hip", gameplay_cam("Stock hip 80°", Vector((-.475, .65, .3325)), 80))
    close = [p for p in shell_points if .20 < p.x < 1.6 and p.z > .15]
    set_skin(True)
    render(studio_cam("finish", close, (-.32,.92,.22), lens=74, margin=1.14),
           "finish", (1280, 720))
    metrics = dict(result)
    metrics["clearance"] = measure_clearance()
    metrics["shell_parts"] = export()
    metrics["shell_triangles"] = sum(part["triangles"] for part in metrics["shell_parts"].values())
    clips = {a.name.split('.')[0].removeprefix('Vandal_'):a for a in actions}
    rig.animation_data.action = clips["Reload"]
    rig.animation_data.action_slot = clips["Reload"].slots[0]
    scene.frame_set(25)
    render(studio_cam("reload", stock_points, (.39,.83,.26), lens=64, margin=1.20),
           "reload_blender", (1200,675))
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    scene.frame_set(1)
    scene.camera = studio_cam("hero", stock_points, (.52,.72,.36), lens=60)
    scene["source"] = "Vandal_RemasterV2_v05.blend"
    scene["variant"] = "Moltframe Vandal v03"
    bpy.data.libraries.write(str(OUT / "Vandal_Moltframe_v03.blend"), {scene, *actions},
                             path_remap="RELATIVE_ALL", fake_user=True, compress=True)
    (OUT / "manifest.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    return metrics

