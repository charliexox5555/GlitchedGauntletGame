"""Reopen the nine delivered Blender files and check the saved scene, rigs and reset poses."""

import json
from pathlib import Path
import sys

import bmesh
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from designs import CHARMS, HEROES, MELEES
from scene import ART, render


def mesh_signature(data):
    return (
        tuple(tuple(v.co) for v in data.vertices),
        tuple(tuple(p.vertices) for p in data.polygons),
        tuple(tuple(tuple(uv.vector) for uv in layer.uv) for layer in data.uv_layers),
    )


def stock_check(sc,root,item,manifest):
    source=root/manifest["source"]
    stock=bpy.data.collections[item]
    original={o.data.name:mesh_signature(o.data) for o in stock.objects if o.type=="MESH"}
    with bpy.data.libraries.load(str(source),link=False) as (src,dst):
        dst.meshes=[name for name in src.meshes if name in original]
        source_names=dst.meshes[:]
    mismatch=[name for name,data in zip(source_names,dst.meshes) if mesh_signature(data)!=original[name]]
    assert len(source_names)==len(original),(item,source_names,list(original))
    assert not mismatch,(item,mismatch)
    return len(original)


def mesh_check(objects):
    findings=[]
    for o in objects:
        if o.type!="MESH":
            continue
        bm=bmesh.new()
        bm.from_mesh(o.data)
        volume=bm.calc_volume(signed=True)
        bad=sum(not edge.is_manifold for edge in bm.edges)
        small=sum(face.calc_area()<1e-10 for face in bm.faces)
        bm.free()
        if bad or small or volume<=0:
            findings.append((o.name,bad,small,round(volume,8)))
    return findings


def state(scene,objects,frame):
    scene.frame_set(frame)
    scene.view_layers[0].update()
    return tuple(c for ob in objects for row in ob.matrix_world for c in row)


def coverage(scene, objects,cam,frame):
    scene.frame_set(frame)
    scene.view_layers[0].update()
    pts=[world_to_camera_view(scene,cam,ob.matrix_world @ v.co) for ob in objects for v in ob.data.vertices]
    usable=[p for p in pts if p.z>cam.data.clip_start]
    return {"mesh_vertices_on_screen_pct":round(100*sum(0<=v.x<=1 and 0<=v.y<=1 for v in usable)/len(pts),1),
            "nearest_vertex":round(min(v.z for v in pts),3)}


def verify(root,line,item):
    parent=ART/"Skins"/line/item/"Concept"
    review=sorted(parent.glob("v*/review.json"))[-1]
    version=review.parent.name
    path=review.parent/f"{item}_{line}_concept_{version}.blend"
    record=json.loads(review.read_text(encoding="utf-8"))
    bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False)
    sc=bpy.context.scene
    assert sc["Exotic item"]==f"{line} / {item} / {version}"
    model_cols=[col for col in sc.collection.children if any(key in col.name for key in (
        "Fixed skin and independent controls","Mounted charm","Model and controls"))]
    custom=[o for c in model_cols for o in c.objects if o.type=="MESH"]
    assert custom
    check=mesh_check(custom)
    assert not check,(item,check)
    first=state(sc,custom,1)
    pose=record["motion"]
    cancel=pose.get("cancel",pose.get("reset"))
    reset=max(abs(a-b) for a,b in zip(first,state(sc,custom,cancel)))
    assert reset < .0002,(item,reset)
    active=pose.get("inspect",pose.get("active"))
    travel=max(abs(a-b) for a,b in zip(first,state(sc,custom,active)))
    assert travel>.004,(item,travel)
    saved_frame_end=sc.frame_end
    rig_data=next((o for o in sc.objects if o.type=="ARMATURE"),None)
    inventory={"actions":len(bpy.data.actions),"bones":list(rig_data.pose.bones.keys()) if rig_data else [],
               "markers":{m.name:m.frame for m in sc.timeline_markers}}
    stock=stock_check(sc,root,item,record) if (line,item) in HEROES else 0
    scan={}
    grip_projection={}
    if (line,item) in MELEES:
        camera=next(o for o in sc.objects if o.name.startswith("First person |"))
        sc.render.resolution_x,sc.render.resolution_y=500,282
        for stage in ("equip","idle","carry","light_a","light_b","heavy","inspect","recovery","cancel"):
            scan[stage]=coverage(sc,custom,camera,pose[stage])
        side=next(o for o in sc.objects if o.name.startswith("Side | grip"))
        sc.render.resolution_x,sc.render.resolution_y=650,440
        sc.frame_set(1)
        for ob in sc.objects:
            if ob.name.endswith("grip anchor"):
                position=world_to_camera_view(sc,side,ob.matrix_world.translation)
                grip_projection[ob.name]=[float(position.x),float(1-position.y)]
    camera=next(o for o in sc.objects if o.name.startswith(("Join check |","Under /","Charm | underside")))
    hands=bpy.data.collections.get("EXOTIC | First-person hand pose proxies")
    if hands:
        hands.hide_render=True
    render(sc,camera,review.parent/"views"/"reopened_culled.png",1,(760,520))
    result={"blend":path.name,"objects":len(sc.objects),"new_closed_meshes":len(custom),
            "identical_stock_meshes_and_UV":stock,"cancel_to_rest_max_delta":round(reset,7),
            "active_max_transform_delta":round(travel,5),"frame_end":saved_frame_end,"screen_coverage":scan,
            "grip_projection":grip_projection,
            **inventory}
    (review.parent/"reopen-check.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
    return result


if __name__=="__main__":
    root=HERE.parents[2]
    picks=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    for line,item in HEROES+MELEES+CHARMS:
        if not picks or item in picks:
            result=verify(root,line,item)
            print("CHECK",line,item,result["new_closed_meshes"],result["cancel_to_rest_max_delta"],flush=True)
