"""Run in a separate background Blender process. Inputs and output versions are explicit."""

import argparse
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from designs import CHARMS, GUNS, HEROES, MELEES, QUEUE
from scene import ART, ROOT, VAULT, setup, render
sys.path.insert(0,str(ART / "RemasterV2/_Library"))

from guns import gun_design, gun_motion, hands_for


def collider(ob):
    coords=[ob.matrix_world @ vert.co for vert in ob.data.vertices]
    faces=[tuple(p.vertices) for p in ob.data.polygons]
    return BVHTree.FromPolygons(coords,faces)


def check_gun(sc,line,item,motion):
    custom=list(bpy.data.collections["EXOTIC | Fixed skin and independent controls"].objects)
    charm=list(bpy.data.collections["EXOTIC | Mounted charm"].objects)
    extra=[o for o in custom+charm if o.type=="MESH"]
    stock=list(bpy.data.collections[item].objects)
    moving=[o for o in stock if o.type=="MESH" and o.parent_bone not in ("Root","")]
    collisions=set()
    frames={1,motion["open"],motion["commit"],motion["peak"],motion["ready"],motion["inspect"],motion["cancel"]}
    frames.update(range(motion["start"],motion["ready"]+1))
    frames.update(motion["regression"])
    frames.update(motion["charm_extremes"])
    for frame in sorted(frames):
        sc.frame_set(frame)
        bpy.context.view_layer.update()
        compared=[(o,collider(o)) for o in moving]
        for ob in extra:
            tree=collider(ob)
            for target,other in compared:
                if tree.overlap(other):
                    collisions.add((frame,ob.name,target.name))
    charm_to_fixed=[]
    fixed=[o for o in stock if o.type=="MESH" and o.parent_bone in ("Root","") and "CharmLoop" not in o.name]
    moving_charm=[o for o in charm if o.type=="MESH" and not any(
        s in o.name for s in ("Oval mount","Closed eyelet"," | closed mount"," | mount seat"))]
    for frame in motion["charm_extremes"]:
        sc.frame_set(frame)
        bpy.context.view_layer.update()
        static=[(o,collider(o)) for o in fixed]
        for ob in moving_charm:
            tree=collider(ob)
            for target,other in static:
                if tree.overlap(other):
                    charm_to_fixed.append((frame,ob.name,target.name))
    sc.frame_set(1)
    from final_pass import ADS, eye
    aim=[]
    if item in ADS:
        origin=eye(item)
        distance=(ADS[item]["dist"]-.02)/ADS[item]["scale"]
        step=.012/ADS[item]["scale"]
        for ob in extra:
            tree=collider(ob)
            for off in ((0,0),(step,0),(-step,0),(0,step),(0,-step)):
                if tree.ray_cast(origin+Vector((0,*off)),Vector((1,0,0)),distance)[0] is not None:
                    aim.append(ob.name)
                    break
    return {"sampled_frames":sorted(frames),"moving_stock_intersections":sorted(collisions),"charm_fixed_intersections":charm_to_fixed,
            "cosmetic_aim_ray_hits":aim,"aim_applicable":item in ADS}


def build(line,item,version,preview):
    key = (line,item)
    models = key in HEROES + MELEES + CHARMS
    output = ART / "Skins" / line / item / "Concept" / version if models else VAULT / line / "out" / "pose-reference" / (item+"_"+version)
    output.mkdir(parents=True,exist_ok=True)
    audit = output / "review.json"
    if audit.exists():
        print(f"Already rendered {line} {item} {version}",flush=True)
        return
    if key in GUNS:
        sc,rig,source,views,controls,charm,palette,fit = gun_design(line,item)
        motion=gun_motion(sc,rig,line,item,controls,charm)
        stills={
            "hero":("hero",1,(970,452)),"side":("side",1,(800,336)),
            "right":("right",1,(675,314)),"held":("held",1,(550,310)),
            "aim":("aim",1,(550,310)),"detail":("detail",motion["peak"],(550,310)),
            "start":("held",motion["open"],(500,282)),"commit":("held",motion["commit"],(500,282)),
            "ready":("held",motion["ready"],(500,282)),"cancel":("held",motion["cancel"],(500,282)),
        }
        for i,frame in enumerate(motion["steps"][1:],2):
            stills[f"commit_{i}"]=("held",frame,(500,282))
        if item=="Shorty":
            stills["empty_second"]=("held",motion["empty_second"],(500,282))
            stills["empty_close"]=("held",motion["empty_close"],(500,282))
        if key in HEROES:
            stills["inspect"]=("held",motion["inspect"],(500,282))
            stills["icon"]=("icon",1,(320,320))
        if charm:
            stills["mount"]=("mount",motion["charm_extremes"][0],(675,455))
            stills["mount_reverse"]=("mount",motion["charm_extremes"][1],(675,455))
        proxies=hands_for(sc,rig,line,item,motion)
        fit.update(check_gun(sc,line,item,motion))
    else:
        from objects import object_design
        sc,rig,source,views,motion,stills,fit=object_design(line,item)
        proxies=bpy.data.collections.get("EXOTIC | First-person hand pose proxies")
    sc.name=f"{line} | {item} | {version}"
    setup(sc)
    sc["Exotic item"] = f"{line} / {item} / {version}"
    sc["Review scope"] = "Offline Blender concept"
    sc["Source"] = str(source.relative_to(ROOT)) if source else "Original concept assembly"
    sc["Review poses"] = motion
    sc.frame_set(1)
    sc.camera=views.get("held",views["hero"])
    if models:
        path=output/f"{item}_{line}_concept_{version}.blend"
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(path))
    for name,(view,frame,size) in stills.items():
        if proxies:
            proxies.hide_render=view!="held"
        hidden=[]
        if view=="icon":
            for col in (bpy.data.collections[item],bpy.data.collections["EXOTIC | Fixed skin and independent controls"]):
                col.hide_render=True
                hidden.append(col)
        render(sc,views[view],output/"views"/(name+".png"),frame,size)
        for col in hidden:
            col.hide_render=False
    if models and preview:
        if proxies:
            proxies.hide_render=False
        for frame in range(sc.frame_start,sc.frame_end+1,3):
            render(sc,views.get("held",views["hero"]),output/"frames"/f"{frame:04d}.png",frame,(576,324))
    record={"line":line,"item":item,"version":version,"source":sc["Source"],"motion":motion,
            "fit":fit,"rendered_panels":list(stills),"backface_culling":True,"fps":sc.render.fps,
            "motion_frame_step":3 if models and preview else 0}
    audit.write_text(json.dumps(record,indent=2),encoding="utf-8")


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--line",required=True)
    parser.add_argument("--item",required=True)
    parser.add_argument("--version",default="v01")
    parser.add_argument("--no-preview",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    if (args.line,args.item) not in QUEUE:
        parser.error("item is outside the concept queue")
    build(args.line,args.item,args.version,not args.no_preview)
