"""Build the approved Poolside and Rootglass Blender assets.

Run headless in Blender with -- <build|review|all> <line> <item> [version].
"""

from collections import defaultdict
import json
import math
import os
from pathlib import Path
import shutil
import sys
import tempfile

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_full_reskins as tools
from build_poolside_spectre import PALETTE as POOL_PALETTE, rgba, smooth
from build_skin_roster import Nodes, bake, fingerprints, mesh_objects, rel, write_json
from check_hand_clipping import box_from
from full_reskin_uv import _available, coverage, relocate
import rootglass_geometry as rootglass
from skin_graphics import LAYOUT

F, M, roster = tools.F, tools.M, tools.roster
ROOT_COLLECTION = "Rootglass Cosmetic"
SIGHT_SEAT_SOURCE = (tools.SKINS / "Shared Sources/Bulldog/SightSeat_v01"
                     / "Bulldog_RemasterV2_v05_SightSeat_v01.blend")


def source_for(item):
    return SIGHT_SEAT_SOURCE if item == "Bulldog" else tools.source(item)


# Bias the bend to the part named in the per-item brief, in stock dimensions.
# Elements are span, centre height, rise, stripe spacing, mark placement.
POOL = {
    "Vandal": ((.05,1.65), .356,.063,.029,.51),
    "Phantom": ((-.06,1.61), .304,.104,.031,.47),
    "Bulldog": ((-.442,.551), .386,.069,.027,.33),
    "Guardian": ((.020,2.29),.348,.059,.030,.58),
    "Stinger": ((-.447,.457),.313,.058,.026,.59),
    "Ares": ((-.138,2.09),.373,.055,.034,.53),
    "Odin": ((.18,1.88),.335,.089,.043,.54),
    "Sheriff": ((.70,1.43),.267,.058,.022,.59),
    "Classic": ((-.15,.965),.396,.041,.022,.57),
    "Ghost": ((-.12,1.092),.328,.040,.019,.58),
    "Shorty": ((-.065,.51),.204,.063,.023,.53),
    "Bucky": ((-.055,.933),.272,.081,.030,.52),
    "Judge": ((-.08,1.85),.377,.086,.037,.52),
    "Marshal": ((.140,.857),.121,.057,.020,.55),
    "Outlaw": ((.164,.996),.340,.055,.025,.43),
    "Operator": ((.082,2.19),.263,.057,.028,.53),
}


def item_dir(line, item, version):
    slot = "Leafblade" if item == "Knife" else item
    return tools.ART / "Skins" / line / slot / version


def filenames(line, item, version):
    slot = "Leafblade" if item == "Knife" else item
    dest = item_dir(line, item, version)
    return dest, dest / f"{slot}_{line}_{version}.blend"


def new_uv(objects, name, angle=60):
    for ob in objects:
        layer = ob.data.uv_layers.get(name)
        if layer is None:
            layer = ob.data.uv_layers.new(name=name, do_init=False)
        ob.data.uv_layers.active = layer
        layer.active_render = True
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.hide_set(False)
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.mode_set(mode="EDIT")
    try:
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=0,
                                 area_weight=0, correct_aspect=False, scale_to_bounds=False)
        bpy.ops.uv.average_islands_scale()
        bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION",
                               margin=.008, shape_method="CONCAVE")
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")


def prepare_sight_seat(item, use_stock_atlas):
    if item != "Bulldog":
        return
    import numpy as np

    seat = bpy.data.objects["GG_Bulldog_FrontSightSeat"]
    seat.data.materials[0] = bpy.data.materials["Dark"]
    if not use_stock_atlas:
        return
    existing = [ob for ob in mesh_objects(item) if ob != seat]
    atlas,_,_ = coverage(existing)
    occupied = (atlas>0).reshape(1024,2,1024,2).any(axis=(1,3))
    height = width = 65
    ys,xs = np.where(_available(occupied,width,height))
    assert len(xs), "Stock atlas has no room for the sight seat"
    x,y = int(xs[0]),int(ys[0])
    new_uv([seat],"UVMap")
    for corner in seat.data.uv_layers.active.uv:
        u,v = corner.vector
        corner.vector = ((x+8+u*(width-16))/1024,(y+8+v*(height-16))/1024)


def approved_concept(line, item):
    refs = {("Rootglass","Vandal"): "Rootglass/out/Vandal_concept_v01.png",
            ("Rootglass","Knife"): "Rootglass/out/Leafblade_concept_v02.png"}
    return roster.VAULT / refs.get((line,item), "Battle Pass Skin Line Concepts.md")


def pool_graph(graph, item):
    (lo,hi), height,rise,gap,mark_x = POOL[item]
    axis = graph.node("SeparateXYZ", "Stock surface position")
    graph.set(axis.inputs[0], graph.attr("PoolsideRestPosition").outputs["Vector"])
    x,y,z = axis.outputs[:]
    math_node = graph.math
    unit = math_node("DIVIDE", math_node("SUBTRACT",x,lo), hi-lo)
    shift = smooth(graph,unit,.04,.88,"Lane sweep")
    base = math_node("ADD",height-rise*.54,math_node("MULTIPLY",shift,rise))
    shoulder = math_node("MULTIPLY",math_node("ABSOLUTE",y),.40)
    offset = math_node("SUBTRACT",z,math_node("ADD",base,shoulder))
    a = smooth(graph,math_node("ABSOLUTE",offset),gap*.31,gap*.42,"Lower lane")
    b = smooth(graph,math_node("ABSOLUTE",math_node("SUBTRACT",offset,gap)),
               gap*.31,gap*.42,"Upper lane")
    start = smooth(graph,unit,0,.017,"The graphic starts on the panel")
    stop = smooth(graph,unit,1,.983,"Clear the stock seam")
    extent = math_node("MULTIPLY",start,stop)
    mask = math_node("MULTIPLY",extent,math_node("SUBTRACT",1,math_node("MULTIPLY",a,b)))
    mark_span = smooth(graph,math_node("ABSOLUTE",math_node("SUBTRACT",unit,mark_x)),
                       .035,.043,"Butter-yellow block length")
    mark_offset = gap * (-.66 if item in {"Vandal","Phantom"} else 1.64)
    mark_z = smooth(graph,math_node("ABSOLUTE",math_node("SUBTRACT",offset,mark_offset)),
                    gap*.26,gap*.36,"Butter-yellow block height")
    left = smooth(graph,y,.018,.034,"Player-facing mark")
    mark = math_node("MULTIPLY",left,math_node("MULTIPLY",
                    math_node("SUBTRACT",1,mark_span),math_node("SUBTRACT",1,mark_z)))
    paint = graph.mix(mask,rgba("blue"),rgba("white"),color=True)
    return graph.mix(mark,paint,rgba("yellow"),color=True)


def poolside(item, objects):
    parts = LAYOUT[item][-1].split()
    if item == "Sheriff":
        parts = ["Frame","Barrel"]
    if item in {"Shorty","Outlaw"}:
        parts = ["Frame" if item == "Shorty" else "Receiver"]
    separate = {"Ares":("Drum",.817,-.090,.053,.023),
                "Bucky":("Pump",1.86,.207,.102,.054)}.get(item)
    for ob in objects:
        part = ob.name.removeprefix(item+"_")
        if ("Sight" in part or part in {"Suppressor", "Scope", "Rail"}
                or part == "Barrel" and item != "Sheriff"):
            ink = ob.data.attributes.new("PoolsideHardware","FLOAT","POINT")
            ink.data.foreach_set("value",[1.0]*len(ob.data.vertices))
        attribute = "PoolsideRestPosition" if part in parts else (
            "PoolsideSeparateMark" if separate and part==separate[0] else None)
        if attribute is None:
            continue
        attr = ob.data.attributes.new(attribute,"FLOAT_VECTOR","POINT")
        attr.data.foreach_set("vector",[a for v in ob.data.vertices for a in ob.matrix_world @ v.co])

    for mat in bake.gun_materials(item):
        if mat.name not in {"Body","Panel","Dark","Metal","Grip","Accent"}:
            continue
        graph = Nodes(mat.node_tree)
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        enamel = mat.name in {"Body","Panel"}
        grip = mat.name == "Grip"
        color = pool_graph(graph,item) if enamel else rgba("navy")
        if enamel:
            color = graph.mix(graph.attr("PoolsideHardware").outputs["Fac"],color,rgba("navy"),color=True)
        if (item=="Ares" and mat.name=="Panel") or (item=="Bucky" and grip):
            _,cx,cz,width,height = separate
            axis = graph.node("SeparateXYZ","Separate moving-part mark")
            graph.set(axis.inputs[0],graph.attr("PoolsideSeparateMark").outputs["Vector"])
            x,y,z = axis.outputs[:]
            dx = graph.math("ABSOLUTE",graph.math("SUBTRACT",x,cx))
            dz = graph.math("ABSOLUTE",graph.math("SUBTRACT",z,cz))
            hori = smooth(graph,dx,width+.003,width,"Moving mark length")
            vert = smooth(graph,dz,height+.003,height,"Moving mark height")
            facing = smooth(graph,y,.039,.049,"Moving mark side")
            mask = graph.math("MULTIPLY",graph.math("MULTIPLY",hori,vert),facing)
            color = graph.mix(mask,color,rgba("yellow" if item=="Ares" else "blue"),color=True)
        graph.set(bsdf.inputs["Base Color"],color)
        graph.set(bsdf.inputs["Roughness"],.32 if enamel else .75 if grip else .58)
        graph.set(bsdf.inputs["Metallic"],.06 if enamel else .0 if grip else .22)
        mat.diffuse_color = rgba("blue" if enamel else "navy")
        if enamel:
            bsdf.inputs["Coat Weight"].default_value = .13
            bsdf.inputs["Coat Roughness"].default_value = .33
    return {"painted_parts":parts,"separate_moving_mark":separate[0] if separate else None,
            "palette_srgb":POOL_PALETTE}


def visible_meshes(item):
    result = [ob for ob in mesh_objects(item) if not ob.hide_render]
    collection = bpy.data.collections.get(ROOT_COLLECTION)
    if collection:
        result.extend(ob for ob in collection.objects if ob.type == "MESH")
    return result


def root_author(item):
    rig = bpy.data.objects[item+"_Rig"]
    collection = bpy.data.collections.new(ROOT_COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    mats = rootglass.palette()
    rootglass.reskin_stock(bake.gun_materials(item))
    return (rootglass.leafblade(collection,rig,mats) if item == "Knife"
            else rootglass.gun(item,collection,rig,mats))


def export_geometry(item, objects, fbx):
    before = {ob: ob.select_get() for ob in bpy.context.view_layer.objects}
    active = bpy.context.view_layer.objects.active
    for ob in before:
        ob.select_set(False)
    for ob in [*objects,bpy.data.objects[item+"_Rig"]]:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects[item+"_Rig"]
    try:
        result = bpy.ops.export_scene.fbx(filepath=str(fbx),use_selection=True,
                    object_types={"MESH","ARMATURE"},use_mesh_modifiers=False,
                    bake_anim=False,add_leaf_bones=False,path_mode="STRIP")
        assert result == {"FINISHED"} and fbx.stat().st_size > 1_000
    finally:
        for ob, selected in before.items():
            ob.select_set(selected)
        bpy.context.view_layer.objects.active = active


def bake_asset(line,item,objects,folder):
    saved = bake.gun_meshes
    bake.gun_meshes = lambda _: objects
    try:
        roster.bake_maps(item,bpy.context.scene,objects,folder)
        for mat in bake.gun_materials(item):
            tree = mat.node_tree
            preview = tree.nodes.get("PV_BSDF")
            if preview:
                authored = tree.nodes["Principled BSDF"]
                for key in ("Coat Weight","Coat Roughness"):
                    preview.inputs[key].default_value = authored.inputs[key].default_value
            if mat.name in {"Glass","Brass","Neon"} and preview:
                bake.set_active_output(mat,"Shader_Out")
    finally:
        bake.gun_meshes = saved


def stage(item):
    scene = bpy.context.scene
    cam, center, radius = tools._cam(item,"hero")
    M._lights(item,cam,center,radius)
    bpy.data.collections[item+"_RV2_Lights"].hide_render = True
    bpy.data.collections[item+"_MS_Lights"].hide_render = False
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.6
    scene.render.engine = "BLENDER_EEVEE"
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 1280,720


def build(line,item,version):
    dest, target = filenames(line,item,version)
    if target.exists() and (dest/"manifest.json").exists():
        return
    assert not dest.exists(), f"Partial build at {dest}"
    source = source_for(item)
    tools.open_file(source)
    prepare_sight_seat(item,line=="Poolside")
    stock_fingerprints = fingerprints(item)
    rest = anchor_manifest(item)
    topology = tools._topology(item)
    stock_ob = mesh_objects(item)
    fbx = None
    if line == "Rootglass":
        art = root_author(item)
        objects = visible_meshes(item)
        for angle in (60,54,66,49):
            new_uv(objects,"RootglassAtlas",angle)
            audit = roster.audit_uv(objects,1024)
            if audit["cross_object_overlap_pixels"] == audit["same_object_overlap_pixels"] == 0:
                break
        uv_repair = (relocate(objects) if audit["cross_object_overlap_pixels"]
                     or audit["same_object_overlap_pixels"] else {})
    else:
        art = poolside(item,stock_ob)
        objects = stock_ob
        audit = roster.audit_uv(objects,1024)
        uv_repair = {}
        if audit["cross_object_overlap_pixels"] or audit["same_object_overlap_pixels"]:
            for ob in objects:
                active = ob.data.uv_layers.new(name="PoolsideAtlas",do_init=True)
                ob.data.uv_layers.active = active
                active.active_render = True
            uv_repair = relocate(objects)
    uv = roster.audit_uv(objects,1024)
    assert uv["cross_object_overlap_pixels"] == uv["same_object_overlap_pixels"] == 0, uv
    assert anchor_manifest(item) == rest
    assert all(fingerprints(item)[k] == stock_fingerprints[k] for k in
               ("hierarchy_pivots_attachments","rig_and_nla","actions"))

    dest.mkdir(parents=True)
    bake_asset(line,item,objects,dest/"textures")
    if line == "Rootglass":
        fbx = target.with_suffix(".fbx")
        export_geometry(item,objects,fbx)
    stage(item)
    bpy.context.scene.render.filepath = "//review/skin/hero.png"
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(target),compress=True,relative_remap=False)
    write_json(dest/"manifest.json",{
        "line":line, "item":item, "version":version, "source":rel(source),
        "source_file_sha256":tools.sha(source), "concept":rel(approved_concept(line,item)),
        "review_state":"Baked. Reopen and comparison pending.",
        "blend":rel(target), "fbx":rel(fbx) if fbx else None,
        "art":art, "anchors":rest, "uv":uv, "uv_repair":uv_repair,
        "original_stock_uvs_retained":True, "topology_of_stock":topology,
        "stock_fingerprints":stock_fingerprints, "saved_fingerprints":fingerprints(item),
        "built_mesh_count":len(objects), "triangles":sum(len(ob.data.loop_triangles) for ob in objects),
        "maps":{channel:{"file":rel(path),"sha256":tools.sha(path)}
                for channel in bake.MAPS if (path := dest/"textures"/f"{item}_{channel}.png").is_file()},
        "map_resolution":[1024,1024],"map_padding_pixels":6,
        "normal_space":"Tangent space, +Y",
        "binding":("Use the RootglassAtlas UVs supplied by the Blender file and local FBX."
                   if fbx else "Use the shared baked maps with the stock asset's active UV layout."
                   if not uv_repair else "Use the added PoolsideAtlas layer. Original stock UVs remain in the blend."),
        "inspect_pulse_targets":[ob.name for ob in objects if ob.get("inspect_pulse_target")],
    })


def anchor_manifest(item):
    return {ob.name:roster.matrix(ob.matrix_world) for ob in bpy.data.collections[item].objects
            if ob.type == "EMPTY" or "Sight" in ob.name}


def set_review_settings(item):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 12 if item in {"Vandal","Knife","Bulldog","Stinger"} else 6
    sc.cycles.use_denoising = True
    sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .55


def review_views(item, dest, art, hero):
    views = ["hero","left","right","top","held","aim"]
    if item in tools.DETAILS:
        views += ["flag_owner","flag_grazing"]
    dest.mkdir(parents=True,exist_ok=True)
    for view in views:
        tools.capture(item,view,dest/(view+".png"))
    if item == "Bulldog":
        ctr = Vector((.874,.022,.505))
        toward = Vector((.21,1,.27))
        cam = F.camera(item,"FrontSightSeat",ctr+2*toward,ctr,ortho=.37,clip=.05)
        M._lights(item,cam,ctr,.72)
        M._shot(item,cam,str(dest/"front-sight-seat.png"),(1000,563),samples=24)
    if hero and "window_center" in art:
        center = Vector(art["window_center"])
        for label, toward in (("window",(.12,1,.26)),("window-grazing",(-.82,.50,.29))):
            cam = F.camera(item,"Rootglass_"+label,center+4*Vector(toward),center,
                           ortho=art["width"]*1.38,clip=.05)
            M._lights(item,cam,center,.8)
            M._shot(item,cam,str(dest/(label+".png")),(960,540),samples=24)


def collider(ob, graph):
    matrix = ob.evaluated_get(graph).matrix_world
    mesh = ob.data
    mesh.calc_loop_triangles()
    points = [matrix@v.co for v in mesh.vertices]
    return BVHTree.FromPolygons(points,[tuple(t.vertices) for t in mesh.loop_triangles],
                                all_triangles=True)


def motion(item, folder=None, collisions=False):
    rig = bpy.data.objects[item+"_Rig"]
    sc = bpy.context.scene
    animation = rig.animation_data
    frame = sc.frame_current
    orig_action, orig_slot = animation.action, animation.action_slot
    pose = {bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones}
    objects = list(bpy.data.collections[item].objects)
    extras = list(bpy.data.collections[ROOT_COLLECTION].objects) if collisions else []
    moving = [ob for ob in mesh_objects(item) if ob.parent_bone not in {"","Root"}
              and not ob.hide_render]
    results = {}
    overlap = defaultdict(set)
    camera = None
    for action in sorted(bpy.data.actions,key=lambda a:a.name):
        if not action.name.startswith(item+"_"):
            continue
        animation.action = None
        for bone in rig.pose.bones:
            bone.matrix_basis = pose[bone.name]
        animation.action, animation.action_slot = action, action.slots[0]
        start,end = map(round,action.frame_range)
        sc.frame_set(start)
        origin = {bone.name:bone.matrix_basis.copy() for bone in rig.pose.bones}
        samples = {}
        travel = {}
        for step in range(start,end+1):
            sc.frame_set(step)
            graph = bpy.context.evaluated_depsgraph_get()
            samples[step] = {ob.name:roster.matrix(ob.evaluated_get(graph).matrix_world)
                             for ob in objects}
            travel[step] = 0
            for bone in rig.pose.bones:
                delta = origin[bone.name].inverted_safe() @ bone.matrix_basis
                angle = delta.to_quaternion().angle
                travel[step] += delta.translation.length + .15*min(angle,math.tau-angle)
            if extras and moving:
                movers = {ob:collider(ob,graph) for ob in moving}
                for ob in extras:
                    tree = collider(ob,graph)
                    for other, target in movers.items():
                        if other.parent_bone != ob.parent_bone and target.overlap(tree):
                            overlap[ob.name+" / "+other.name].add(action.name)
        peak = max(travel,key=travel.get)
        short = action.name.removeprefix(item+"_")
        results[short] = {"start":start,"end":end,"review_frame":peak,
                          "sample_count":len(samples),"pose_sha256":roster.digest(samples)}
        if folder and travel[peak] > .001:
            sc.frame_set(peak)
            direction = (-.53,.67,.47) if item == "Knife" else (.23,.93,.28)
            points = M._pts(item)
            camera, center, radius = M._cam(item,"BattlePassMotion",points,direction,
                                            ortho=True,margin=1.16)
            M._lights(item,camera,center,radius)
            M._shot(item,camera,str(folder/f"{short.lower()}-{peak:03}.png"),(760,428),samples=16)
    animation.action = orig_action
    if orig_slot:
        animation.action_slot = orig_slot
    for bone in rig.pose.bones:
        bone.matrix_basis = pose[bone.name]
    sc.frame_set(frame)
    return results,{k:sorted(v) for k,v in overlap.items()}


def sight_clearance(item, objects):
    if item not in F.ADS:
        return {}
    report = F.sightline(item)
    graph = bpy.context.evaluated_depsgraph_get()
    eye = Vector(report["eye"])
    spread = .012/F.ADS[item]["scale"]
    additions = []
    for ob in objects:
        tree = collider(ob,graph)
        for y,z in ((0,0),(spread,0),(-spread,0),(0,spread),(0,-spread)):
            if tree.ray_cast(eye+Vector((0,y,z)),(1,0,0),report["len"])[0]:
                additions.append(ob.name)
                break
    report["new_geometry_hits"] = additions
    return report


def hand_proxy_check(item, objects):
    directory = tools.ROOT / "art-source/viewmodel/checks"
    graph = bpy.context.evaluated_depsgraph_get()
    surfaces = {ob.name:collider(ob,graph) for ob in objects}
    report = {}
    for file in sorted(directory.glob(f"{item}_*.json")):
        if ".result." in file.name:
            continue
        data = json.loads(file.read_text(encoding="utf-8"))
        contacts = defaultdict(int)
        for frame in data["frames"]:
            for side,joints in frame["arms"].items():
                box = box_from(joints["Root"],data["half"])[-1]
                for name,surface in surfaces.items():
                    if box.overlap(surface):
                        contacts[f"{side}/{name}"] += 1
        report[data["mode"]] = {"source":rel(file),"frames":len(data["frames"]),
                                "new_shell_contacts":dict(contacts)}
    return report


def fbx_review(item, path, dest):
    source_objects = visible_meshes(item)
    before = set(bpy.data.objects)
    assert bpy.ops.import_scene.fbx(filepath=str(path),use_anim=False) == {"FINISHED"}
    imported = [ob for ob in bpy.data.objects if ob not in before and ob.type=="MESH"]
    assert len(imported)==len(source_objects), (len(imported),len(source_objects))
    part = lambda ob: (len(ob.data.vertices),sum(len(p.vertices)-2 for p in ob.data.polygons))
    assert sorted(part(ob) for ob in imported)==sorted(part(ob) for ob in source_objects)
    scene = bpy.context.scene
    scene.display.shading.show_backface_culling = True
    scene.display.shading.color_type = "MATERIAL"
    scene.display.render_aa = "8"
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    for ob in source_objects:
        ob.hide_render = True
    pts = [ob.matrix_world@v.co for ob in imported for v in ob.data.vertices]
    for name,direction in (("left",(0,1,0)),("right",(0,-1,0)),("rear",(-.66,.70,.26))):
        cam,_,_ = M._cam(item,"Reimport_"+name,pts,direction,ortho=True,margin=1.12)
        F.shot(item,cam,str(dest/(name+"-culled.png")),res=(896,504))
    return {"mesh_count":len(imported),"culling_views":["left","right","rear"]}


def copy_matched_stock(item,target,dest,manifest,hero):
    if hero or item in {"Spectre","Bulldog","Stinger"}:
        return False
    paths = tools.SKINS.glob(f"*/{item}/v[0-9][0-9]/manifest.json")
    labels = ("hero","left","right","top","held","aim")
    for path in paths:
        if path.parent == target.parent:
            continue
        try:
            other = json.loads(path.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            continue
        if (not other.get("saved_file_verified")
                or other.get("source_file_sha256") != manifest["source_file_sha256"]):
            continue
        stock = path.parent/"review/stock"
        if not all((stock/f"{name}.png").is_file() for name in labels):
            continue
        dest.mkdir(parents=True,exist_ok=True)
        for name in labels:
            shutil.copy2(stock/f"{name}.png",dest/f"{name}.png")
        return True
    return False


def verify(line,item,version):
    dest, target = filenames(line,item,version)
    record = dest/"manifest.json"
    manifest = json.loads(record.read_text(encoding="utf-8"))
    source = source_for(item)
    assert tools.sha(source) == manifest["source_file_sha256"]
    tools.open_file(target)
    assert fingerprints(item) == manifest["saved_fingerprints"]
    assert anchor_manifest(item) == manifest["anchors"]
    for key,map_info in manifest["maps"].items():
        im = bpy.data.images[f"{item}_{key}"]
        disk = tools.ROOT/map_info["file"]
        assert im.packed_file.data == disk.read_bytes() and list(im.size)==[1024,1024]
        assert map_info["sha256"]==tools.sha(disk)
    assert len(manifest["maps"]) == 4
    skin_side = dest/"review/skin"
    stock_side = dest/"review/stock"
    set_review_settings(item)
    hero = item in {"Vandal","Knife"}
    review_views(item,skin_side,manifest["art"],hero)
    root = bpy.data.collections.get(ROOT_COLLECTION)
    sight = sight_clearance(item,list(root.objects) if root else [])
    hand_proxy = hand_proxy_check(item,list(root.objects)) if root and hero else {}
    clips, contacts = motion(item,skin_side if hero or item in tools.DETAILS else None,bool(root))
    if manifest["fbx"]:
        exported = fbx_review(item,tools.ROOT/manifest["fbx"],dest/"review/reimport")
    else:
        exported = None
    tools.open_file(source)
    set_review_settings(item)
    if not copy_matched_stock(item,target,stock_side,manifest,hero):
        review_views(item,stock_side,manifest["art"],hero)
    stock_clips,_ = motion(item,stock_side if hero or item in tools.DETAILS else None)
    assert stock_clips==clips, (item,stock_clips,clips)
    manifest.update(saved_file_verified=True,sightline=sight,stock_motion=clips,
                    new_geometry_contacts=contacts,fbx_reimport=exported,
                    archived_hand_proxy=hand_proxy,
                    review_state="Reopened. Matched renders and geometry evidence saved.")
    write_json(record,manifest)
    print("VERIFIED",line,item,"new contacts:",contacts,"sight:",sight.get("new_geometry_hits",[]),flush=True)


def main(command,line,item,version):
    destination, _ = filenames(line,item,version)
    record = destination / "manifest.json"
    lock = Path(tempfile.gettempdir()) / f"gauntlet-battle-pass-{line}-{item}-{version}.lock"
    try:
        fd = os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
    except FileExistsError:
        print("Another Blender process owns this asset",line,item,version,flush=True)
        return
    try:
        with os.fdopen(fd,"w") as handle:
            handle.write(str(os.getpid()))
        if (command == "all" and record.exists()
                and json.loads(record.read_text(encoding="utf-8")).get("saved_file_verified")):
            print("Already verified",line,item,version,flush=True)
            return
        if command in {"build","all"}:
            build(line,item,version)
        if command in {"review","all"}:
            verify(line,item,version)
    finally:
        lock.unlink()


if __name__ == "__main__":
    command,line,item,*options = sys.argv[sys.argv.index("--")+1:]
    main(command,line,item,options[0] if options else "v01")
