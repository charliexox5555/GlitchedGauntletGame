"""Fit the concept round to the feed lips of the approved Shadow Mist masters."""

import json
from pathlib import Path

import bpy
from mathutils import Vector

import build_ruin_blighted_guardian as guardian
from build_ruin_blighted_roster import feed_lips_only
from ruin_blighted_round import round_meshes


art = guardian.support


def load_round(col, rig, donor):
    donor_surface = guardian.sample_surface(donor)
    round_points = {
        i
        for face, material in zip(donor_surface.faces, donor_surface.material_indices, strict=True)
        if donor_surface.material_names[material] != guardian.FINISH + "Shadow"
        for i in face
    }
    points = [Vector(donor_surface.verts[i]) for i in round_points]
    low, high = min(p.x for p in points), max(p.x for p in points)
    length = high - low

    def end(position):
        near = [p for p in points if abs(p.x-position) < length*.10]
        return Vector((position, 0, sum(p.z for p in near)/len(near)))

    rear, nose = end(low), end(high)
    axis = nose - rear
    center = rear.lerp(nose,.5)
    rotation = axis.to_track_quat("X","Z")
    width = max(p.y for p in points) - min(p.y for p in points)
    scale = width / (.21 * axis.length)
    rounds = round_meshes(col, Vector(), axis.length)
    for obj in rounds:
        for vertex in obj.data.vertices:
            point = vertex.co
            vertex.co = rotation @ Vector((point.x, point.y*scale, point.z*scale)) + center
        obj.data.update()
        art.bind(obj, rig, donor.parent_bone)
    return rounds


def build(gun, origin):
    scene = bpy.context.scene
    rig = scene.objects[gun+"_Rig"]
    rig.data.pose_position = "REST"
    scene.frame_set(1)
    scene.view_layers[0].update()
    col = bpy.data.collections[f"Ruin-Blighted | {gun}"]
    donor = col.objects["RB_Magazine_LipsAndRound"]
    mat = donor.data.materials[0]
    lips = guardian.add_surface(col,"RB_Magazine_FeedLips",feed_lips_only(guardian.sample_surface(donor)),
                               Vector,{mat.name:mat})
    art.bind(lips, rig, donor.parent_bone)
    rounds = load_round(col,rig,donor)
    donor.hide_set(True)
    donor.hide_render = True
    scene.view_layers[0].update()
    components = [ob for ob in col.objects if ob.type=="MESH" and not ob.hide_render]
    prev = json.loads((origin/"manifest_flat.json").read_text(encoding="utf-8"))
    bank = {mat.name:mat for mat in bpy.data.materials}
    folder = origin.parent
    revisions = [int(p.name[1:]) for p in folder.glob("v[0-9][0-9]")]
    dest = folder / f"v{max(revisions)+1:02}"
    dest.mkdir()

    # Show the loaded magazine on the same side as the first-person reload.
    magazine = [ob for ob in components if ob.parent_bone == donor.parent_bone]
    hidden = [ob for ob in scene.objects if ob.type=="MESH" and ob not in magazine and not ob.hide_render]
    for ob in hidden:
        ob.hide_render = True
    review = art.collection(scene, f"{gun} | Cartridge review")
    camera = art.framed_camera(review,f"{gun} magazine with a loaded Shadow Mist round",
        art.points(magazine),(.38,.81,.43),1.65,1.16)
    old_camera = scene.camera
    try:
        art.render(scene,camera,dest/"review/loaded_magazine.png",1,(1040,630))
    finally:
        scene.camera = old_camera
        for ob in hidden:
            ob.hide_render = False

    output = dest / f"{gun}_RuinBlighted_{dest.name}.blend"
    rig.data.pose_position = "POSE"
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    rig.data.pose_position = "REST"
    scene.view_layers[0].update()
    added, triangles = guardian.finish_manifest(
        components, prev["joints"], bank, dest, list(prev["replaced"]), prev["energy"],
        gun=gun, ads_distance=prev.get("adsDistance"),
    )
    report = json.loads((dest/"manifest_flat.json").read_text())
    unrelated = lambda parts: {k:v for k,v in parts.items() if v["b"] != donor.parent_bone}
    if unrelated(prev["parts"]) != unrelated(report["parts"]):
        raise RuntimeError(f"{gun}: geometry outside magazine changed in export")
    (dest/"review/cartridge_check.json").write_text(json.dumps({
        "source":origin.name, "rigBone":donor.parent_bone,
        "loadedMeshes":len(rounds), "parts":added, "triangles":triangles,
        "otherExportPartsUnchanged":True,
    },indent=2)+"\n")
    return str(output)
