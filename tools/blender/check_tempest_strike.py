"""Measure the saved Vandal and verify a clean GLB export round trip."""
import json
from pathlib import Path
import sys

import bmesh
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree


root=Path(__file__).resolve().parents[2]
args=sys.argv[sys.argv.index("--")+1:]
version=args[0]
folder=root/"art-source/weapons/Skins/TempestStrike/Vandal"/version
scene=bpy.data.scenes["Tempest-Strike | Storm Shadow"]
bpy.context.window.scene=scene
review=folder/"review"
review.mkdir(exist_ok=True)
scene.frame_set(1)
stock=bpy.data.scenes["Stock Vandal | Reference"]
stock_rig=stock.objects["Vandal_Rig"]
gun_rig=scene.objects["Vandal_StockRig"]
bpy.context.window.scene=stock
stock.frame_set(1)
bpy.context.view_layer.update()
stock_rest={obj.name:obj.matrix_world.copy() for obj in stock.objects if obj.type in {"EMPTY","CAMERA"}}
bpy.context.window.scene=scene
bpy.context.view_layer.update()


def maxdiff(a,b):
    return max(abs(x-y) for ar,br in zip(a,b) for x,y in zip(ar,br))


def egeo(obj,dep):
    node=obj.evaluated_get(dep)
    data=node.to_mesh()
    data.calc_loop_triangles()
    points=[node.matrix_world @ v.co for v in data.vertices]
    tris=[tuple(t.vertices) for t in data.loop_triangles]
    node.to_mesh_clear()
    return points,tris


def bounds(points):
    return [[min(p[i] for p in points) for i in range(3)],
            [max(p[i] for p in points) for i in range(3)]]


def bvh(points,tris):
    return BVHTree.FromPolygons(points,tris,all_triangles=True)


stock_parts=[o for o in stock.objects if o.type=="MESH" and o.name.startswith("Vandal_")
             and not o.hide_render]
gun_parts=[o for group in scene.collection.children if group.name[:2] in {"02","03","04","05","06","07","08"}
           for o in group.objects if o.type=="MESH" and not o.hide_render]
opaque=[o for o in gun_parts if o not in [obj for c in scene.collection.children if c.name.startswith("07") for obj in c.objects]]
dep=bpy.context.evaluated_depsgraph_get()
geo={o:egeo(o,dep) for o in gun_parts}
gun_bounds=bounds([p for o in opaque for p in geo[o][0]])
report={"dimensions":{"storm_shadow":gun_bounds},
        "rig":{"stock_bones":{},"stock_locators":{},"cameras":{}},"geometry":{},"aim":{}}
for bone in stock_rig.data.bones:
    report["rig"]["stock_bones"][bone.name]=maxdiff(bone.matrix_local,gun_rig.data.bones[bone.name].matrix_local)
for src in stock.objects:
    want=scene.objects.get("TS_"+src.name)
    if not want:
        continue
    if src.type=="EMPTY":
        report["rig"]["stock_locators"][src.name]=maxdiff(stock_rest[src.name],want.matrix_world)
    if src.type=="CAMERA":
        report["rig"]["cameras"][src.name]={"matrix_delta":maxdiff(stock_rest[src.name],want.matrix_world),
          "lens_delta":abs(src.data.lens-want.data.lens)}
report["rig"]["custom_pivots"]={o.name:list(o.matrix_world.translation) for o in scene.objects
    if o.type=="EMPTY" and o.name.startswith("CTRL_")}

bpy.context.window.scene=stock
stock_dep=bpy.context.evaluated_depsgraph_get()
stock_geometry={o:egeo(o,stock_dep) for o in stock_parts}
report["dimensions"]["stock"]=bounds([p for geom in stock_geometry.values() for p in geom[0]])
mount=scene.objects.get("BuddyMount_StockPlateAndLoop")
if mount:
    mount_src=stock_geometry[stock.objects["Vandal_CharmLoop"]][0]
    lookup=KDTree(len(mount_src))
    for i,point in enumerate(mount_src):
        lookup.insert(point,i)
    lookup.balance()
    report["rig"]["empty_buddy_mount"]={
        "stock_vertices":len(mount_src),
        "skin_vertices":len(geo[mount][0]),
        "max_stock_surface_delta":max(lookup.find(point)[2] for point in geo[mount][0]),
    }
    mouth=Vector((.930,.23,.1779))
    report["rig"]["empty_buddy_mount"]["aperture_hits_above_the_shell"]=[
        obj.name for obj,shape in geo.items()
        if bvh(*shape).ray_cast(mouth,(0,-1,0),.1365)[0] is not None
    ]
bpy.context.window.scene=scene
dep=bpy.context.evaluated_depsgraph_get()
report["geometry"]["triangles"]={o.name:len(geo[o][1]) for o in gun_parts}
report["geometry"]["opaque_triangles"]=sum(len(geo[o][1]) for o in opaque)
report["geometry"]["effects_triangles"]=sum(len(geo[o][1]) for o in gun_parts if o not in opaque)
report["geometry"]["mesh_objects"]=len(gun_parts)
report["geometry"]["materials"]=sorted({m.name for o in gun_parts for m in o.data.materials})
nonmanifold={}
degenerates={}
for o in gun_parts:
    obj=o.evaluated_get(dep)
    data=obj.to_mesh()
    bm=bmesh.new()
    bm.from_mesh(data)
    bad=sum(not e.is_manifold for e in bm.edges)
    if bad:
        nonmanifold[o.name]=bad
    count=sum(p.area<1e-11 for p in data.polygons)
    if count:
        degenerates[o.name]=count
    bm.free()
    obj.to_mesh_clear()
report["geometry"]["nonmanifold_edge_counts"]=nonmanifold
report["geometry"]["degenerate_polygon_counts"]=degenerates

for cam_name in ["TS_Vandal_Cam_ADS","TS_Vandal_FP_ADS"]:
    cam=scene.objects[cam_name]
    origin=cam.matrix_world.translation
    expected=Vector((2.028,0,.5598))
    testers=[(o.name,bvh(*geom)) for o,geom in geo.items()]
    def ray(target):
        hits=[]
        for name,tree in testers:
            loc,_,_,dist=tree.ray_cast(origin,(target-origin).normalized(),(target-origin).length)
            if loc is not None:
                hits.append((dist,name))
        return [item[1] for item in sorted(hits)]
    centers=[ray(expected+Vector((0,y,z))) for y,z in [(0,0),(.018,0),(-.018,0),(0,.020),(0,-.004)]]
    sight_hits=ray(Vector((2.0,0,.546)))
    report["aim"][cam_name]={"center_clear":not centers[0],"corridor_five_rays":centers,
                            "front_reference_ray":sight_hits}

if scene.frame_end==480:
    actions=json.loads((review/"action_timeline.json").read_text())
    ticks=actions["frames"]
    # Iterate every frame of the native preview. Camera-stage framing uses
    # transformed bounding corners from every visible weapon mesh.
    clipped={}
    catches={}
    moving_contacts={}
    moving_aim={}
    seat_contacts={}
    mag_meshes=[o for o in opaque if o.parent.name=="CTRL_Magazine"]
    receiver=[o for o in opaque if o.name in {"Receiver_Keel","Receiver_IndigoForging","Shroud_OctagonalForging",
                                            "Grip_AngledTang","TriggerGuard_RakedLoop","Grip_ShapedFactoryTang"}
              or o.name.startswith("Receiver_MagwellShoulder_")]
    plate_meshes=[o for o in opaque if o.parent.name.startswith("CTRL_Plate")]
    plate_hosts=[o for o in opaque if o.name in {"Receiver_IndigoForging","Shroud_OctagonalForging",
                                               "UpperSpine_ProwBrow","Receiver_TransferCover","Shroud_UpperSeat"}]
    for f in range(9,481):
        scene.frame_set(f)
        bpy.context.view_layer.update()
        deps=bpy.context.evaluated_depsgraph_get()
        if f in [ticks["DrawCatch"],ticks["InspectCatch"],ticks["CancelledADS"]]:
            body=scene.objects["CTRL_Chassis"]
            proxy=scene.objects["Hand_Right"]
            wanted=body.matrix_world @ Vector((0,.098,0))
            catches[str(f)]=(wanted-proxy.matrix_world.translation).length
        if f<468:
            cam=scene.camera
            # Local mesh hull bounds are deliberately conservative.
            off=False
            for o in opaque:
                for c in o.bound_box:
                    p=world_to_camera_view(scene,cam,o.matrix_world @ Vector(c))
                    if not (-.005<=p.x<=1.005 and -.005<=p.y<=1.005):
                        off=True
                        break
                if off:
                    clipped[f]=o.name
                    break
        for prefix in ["Tac","Empty"]:
            seat=ticks[prefix+"MagSeat"]
            out=ticks[prefix+"MagRelease"]
            if f==seat:
                mag=scene.objects["CTRL_Magazine"]
                seat_contacts[prefix]={"translation":list(mag.location),"rotation":list(mag.rotation_euler),
                                      "scale":list(mag.scale)}
            if out<f<seat and f>=ticks[prefix+"MagForm"] and f%2==0:
                fixed={o.name:bvh(*egeo(o,deps)) for o in receiver}
                contacts=set()
                for moving in mag_meshes:
                    tree=bvh(*egeo(moving,deps))
                    contacts.update(name for name,other in fixed.items() if tree.overlap(other))
                if contacts:
                    moving_contacts[f]=sorted(contacts)
        if f in range(9,25):
            fixed={o.name:bvh(*egeo(o,deps)) for o in plate_hosts}
            contacts={}
            for moving in plate_meshes:
                tree=bvh(*egeo(moving,deps))
                touched=[name for name,other in fixed.items() if tree.overlap(other)]
                if touched:
                    contacts[moving.name]=touched
            if contacts:
                moving_contacts["plate_"+str(f)]=contacts
        if f in range(39,61,2):
            animated=[(o.name,bvh(*egeo(o,deps))) for o in gun_parts
                      if o.name.startswith(("Water_","Spark_","Fore_Silver","Rear_Silver"))]
            for name in ["TS_Vandal_Cam_ADS","TS_Vandal_FP_ADS"]:
                eye=scene.objects[name].matrix_world.translation
                target=Vector((2.028,0,.5598))
                hits=[label for label,tree in animated if
                      tree.ray_cast(eye,(target-eye).normalized(),(target-eye).length)[0] is not None]
                if hits:
                    moving_aim[f"{name} {f}"]=hits
    report["motion"]={"proxy_rest_residuals":catches,"clipped_weapon_bound_frames":clipped,
               "seat_transforms":seat_contacts,"sampled_moving_contact_pairs":moving_contacts,
               "idle_aim_center_obstructions":moving_aim}
    scene.frame_set(1)

(review/"geometry_and_rig.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
if "--export" not in args:
    print(json.dumps({k:v for k,v in report["geometry"].items() if k!="triangles"}))
    sys.exit(0)

export_scene=bpy.data.scenes.new("Temporary evaluated export")
bpy.context.window.scene=export_scene
groups={}
nodes={}
materials={}
role_map={}
scene_dep=dep


def export_material(source):
    if source.name not in materials:
        export=source.copy()
        export.name=source.name.removeprefix("TS_").split(" · ")[0]
        shader=export.node_tree.nodes.get("Principled BSDF")
        for link in list(export.node_tree.links):
            if link.to_node==shader:
                export.node_tree.links.remove(link)
        role_map[export.name]={"srgb":source.get("srgb"),"blender":source.name,
                               "procedural_microfinish_in_master":len(source.node_tree.nodes)>2}
        materials[source.name]=export
    return materials[source.name]


def export_node(src):
    if not src or not src.name.startswith("CTRL_"):
        return None
    if src.name not in nodes:
        parent=export_node(src.parent)
        obj=bpy.data.objects.new(src.name,None)
        # The review master owns the original name in this Blender process.
        # Use glTF extras to preserve it across importer suffixes.
        obj["canonical_name"]=src.name
        export_scene.collection.objects.link(obj)
        obj.parent=parent
        if parent:
            matrix=src.parent.matrix_world.inverted() @ src.matrix_world
            obj.matrix_basis=matrix
        else:
            obj.matrix_world=src.matrix_world
        nodes[src.name]=obj
    return nodes[src.name]


def write_group(items,name,center=True):
    staging=bpy.data.scenes.new("Asset copy " + name)
    staging.world=scene.world
    bpy.context.window.scene=staging
    center_by=sum((o.matrix_world.translation for o in items),Vector())/len(items)
    for src in items:
        obj=src.copy()
        obj.data=src.data.copy()
        world=src.matrix_world.copy()
        obj.parent=None
        obj.animation_data_clear()
        staging.collection.objects.link(obj)
        if center:
            world.translation-=center_by
        obj.matrix_world=world
    target=folder/f"{name}_{version}.blend"
    bpy.data.libraries.write(str(target),{staging},fake_user=True,compress=True)
    bpy.context.window.scene=export_scene


round_group=next(c for c in scene.collection.children if c.name.startswith("10"))
write_group(list(round_group.objects),"HydroCoreRound")
bpy.context.window.scene=scene
scene.frame_set(1)
scene_dep=bpy.context.evaluated_depsgraph_get()
for src in gun_parts:
    mesh=bpy.data.meshes.new_from_object(src.evaluated_get(scene_dep),depsgraph=scene_dep)
    obj=bpy.data.objects.new(src.name,mesh)
    obj["canonical_name"]=src.name
    obj["parent_control"]=src.parent.name
    export_scene.collection.objects.link(obj)
    obj.parent=export_node(src.parent)
    obj.matrix_basis=src.parent.matrix_world.inverted() @ src.matrix_world
    for i,mat in enumerate(mesh.materials):
        mesh.materials[i]=export_material(mat)

for source in [o for o in scene.objects if o.name.startswith("TS_Vandal_") and o.type=="EMPTY"]:
    obj=bpy.data.objects.new(source.name.removeprefix("TS_Vandal_"),None)
    export_scene.collection.objects.link(obj)
    obj["canonical_name"]=obj.name
    obj.parent=nodes["CTRL_Chassis"]
    obj.matrix_basis=source.matrix_world

bpy.context.window.scene=export_scene
target=folder/f"Vandal_StormShadow_{version}.glb"
bpy.ops.export_scene.gltf(filepath=str(target),export_format="GLB",export_extras=True,use_active_scene=True,
                         export_animations=False,export_cameras=False,export_lights=False,
                         export_yup=True)

roundtrip=bpy.data.scenes.new("Round trip")
bpy.context.window.scene=roundtrip
bpy.ops.import_scene.gltf(filepath=str(target))
redep=bpy.context.evaluated_depsgraph_get()
regeo={o:egeo(o,redep) for o in roundtrip.objects if o.type=="MESH"}
reparts={o.get("canonical_name",o.name):o for o in regeo}
recount=sum(len(gs[1]) for gs in regeo.values())
original_count=sum(len(gs[1]) for gs in geo.values())
rebound=bounds([p for gs in regeo.values() for p in gs[0]])
origin_bounds=bounds([p for gs in geo.values() for p in gs[0]])
per_part_delta={o.name:maxdiff(bounds(geo[o][0]),bounds(regeo[reparts[o.name]][0]))
                for o in gun_parts if o.name in reparts}
custom_rest={}
for obj in roundtrip.objects:
    name=obj.get("canonical_name")
    if name in nodes:
        custom_rest[name]=maxdiff(nodes[name].matrix_world,obj.matrix_world)
manifest={"schema":1,"stage":"offline evaluated visual handoff","finish":"Storm Shadow",
          "units":"one Blender unit per Roblox stud","authoring_axes":"+X muzzle, +Z up",
          "export":"glTF binary","geometry":report["geometry"],"runtime_roles":role_map,
          "locators":{name:list(scene.objects["TS_"+name].matrix_world.translation)
                      for name in report["rig"]["stock_locators"]},
          "custom_pivots":report["rig"]["custom_pivots"],
          "reimport":{"mesh_count":len(regeo),"source_mesh_count":len(gun_parts),
                      "triangle_count":recount,"source_triangle_count":original_count,
                      "bounds_axis_max_delta":maxdiff(origin_bounds,rebound),
                      "max_part_bounds_delta":max(per_part_delta.values(),default=None),
                      "missing_meshes":[o.name for o in gun_parts if o.name not in reparts],
                      "control_matrix_deltas":custom_rest,
                      "sight_mesh_names":[n for n in reparts if n.startswith("Sight")]}}
(folder/"manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
print(json.dumps(manifest["reimport"]))
