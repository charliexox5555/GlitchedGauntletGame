"""Build, shade, and verify one editable exotic finish in an isolated Blender worker."""

import argparse
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from build import check_gun
from designs import CHARMS,GUNS,HEROES,MELEES,QUEUE
from finish_materials import finish_materials
from guns import gun_design,gun_motion,hands_for
from scene import ART,ROOT,collection,render,setup
from verify import mesh_check,state,stock_check


MODEL_COLS=("Fixed skin and independent controls","Mounted charm","Model and controls")


def folder(line,item,version):
    return ART/"Skins"/line/item/"Finish"/version


def concept(line,item):
    parent=ART/"Skins"/line/item/"Concept"
    review=sorted(parent.glob("v*/reopen-check.json"))[-1]
    path=review.parent/f"{item}_{line}_concept_{review.parent.name}.blend"
    info=json.loads((review.parent/"review.json").read_text(encoding="utf-8"))
    bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False)
    sc=bpy.context.scene
    matches={"hero":("Beauty |", "Three-quarter", "Charm | three-quarter"),
             "right":("Join check |", "Under /", "Charm | underside"),
             "held":("First person |",item+"_FP_Hip"),
             "detail":("Cassette |",),"aim":(item+"_FP_ADS",),"mount":("Charm | outboard",)}
    views={key:next((o for o in sc.objects if o.type=="CAMERA" and o.name.startswith(starts)),None)
           for key,starts in matches.items()}
    if not views["held"]:
        views["held"]=views["hero"]
    return sc,views,info["motion"],info["source"],str(path.relative_to(ROOT)),info.get("fit",{})


def custom_meshes(sc):
    return [o for c in sc.collection.children if any(label in c.name for label in MODEL_COLS) for o in c.objects if o.type=="MESH"]


def edge_detail(objects):
    """One flat micro-chamfer on visible castings, using their existing closed mesh."""
    applied=[]
    shell_words=("cassette","ceramic cage shoulder","kiln jaw","molded window edge","rim",
                 "clipped iron slab","copper furnace seat","socketed torque yoke","glazed",
                 "faceted float","coral cap","ceramic seal","smoke-blue switch frame","ivory keycap")
    for ob in objects:
        if not any(word in ob.name.lower() for word in shell_words):
            continue
        modifier=ob.modifiers.new("Finish / Flat edge chamfer","BEVEL")
        modifier.width=min(.0035,min(ob.dimensions)*.065)
        modifier.segments=1
        modifier.limit_method="ANGLE"
        modifier.angle_limit=.53
        modifier.use_clamp_overlap=True
        applied.append(ob.name)
    return applied


def melee_actions(scene,item):
    rig=next(o for o in scene.objects if o.type=="ARMATURE")
    master=rig.animation_data.action
    master.asset_mark()
    master.asset_data.description="Complete first-person review reel with the original timing cues."
    sections=( ("Equip",5,23, None), ("Idle",24,45,None), ("Carry",46,66,None),
               ("Light A",68,82,72), ("Light B",85,100,91), ("Heavy",104,126,113),
               ("Inspect",129,174,None), ("Recovery",178,195,None), ("Cancel",198,219,None))
    catalogue={}
    for name,first,last,hit in sections:
        clip=master.copy()
        clip.name=f"{item} / {name}"
        clip.use_fake_user=True
        clip.asset_mark()
        clip.asset_data.description=f"{name} from the original {item} first-person reel. 24 fps."
        for layer in clip.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        samples=[curve.evaluate(f) for f in range(first,last+1)]
                        curve.keyframe_points.clear()
                        curve.keyframe_points.add(len(samples))
                        coords=[value for i,sample in enumerate(samples,1) for value in (i,sample)]
                        curve.keyframe_points.foreach_set("co",coords)
                        for point in curve.keyframe_points:
                            point.interpolation="LINEAR"
                        curve.update()
        clip.use_frame_range=True
        clip.frame_start,clip.frame_end=1,last-first+1
        for mark in list(clip.pose_markers):
            clip.pose_markers.remove(mark)
        if hit:
            clip.pose_markers.new("VISUAL CONTACT").frame=hit-first+1
        catalogue[name]={"frames":last-first+1,"contact":hit-first+1 if hit else None}
    return catalogue


def studio(sc,view,line):
    for ob in sc.objects:
        if ob.type=="LIGHT":
            ob.hide_render=True
    for col in sc.collection.children:
        if col.name.endswith("ADSRange"):
            col.hide_render=True
    stage=collection(sc,"REVIEW | Studio lighting")
    view.data.clip_end=max(view.data.clip_end,100)
    bpy.context.view_layer.update()
    distance=view.data.ortho_scale if view.data.type=="ORTHO" else 3
    aim=view.matrix_world.to_quaternion()
    target=view.location+aim @ Vector((0,0,-4))
    # The saved ortho cameras were placed four units from their model center.
    span=max(distance*.86,.18)
    accents={"Spindrift":(.68,.9,1),"Kilnlock":(1,.83,.70),"Stacklight":(.72,1,.95)}
    for name,pos,strength,size,color in (
        ("Key",(-.66,.8,.92),96,.92,(1,.956,.89)),
        ("Fill",(.83,.3,.42),48,1.18,(.84,.91,1)),
        ("Rim",(.23,.74,-.95),137,.74,accents[line]),
        ("Underside",(-.25,-.64,.37),18,.76,(.86,.91,1)),
    ):
        data=bpy.data.lights.new("Finish / "+name,"AREA")
        data.energy=strength*span*span
        data.shape="DISK"
        data.size=size*span
        data.color=color
        ob=bpy.data.objects.new(data.name,data)
        stage.objects.link(ob)
        ob.location=target+aim @ (Vector(pos)*span)
        ob.rotation_euler=(target-ob.location).to_track_quat("-Z","Y").to_euler()
    world=bpy.data.worlds.new("Finish / Neutral studio")
    world.use_nodes=True
    bkg=world.node_tree.nodes.get("Background")
    bkg.inputs["Color"].default_value=(.22,.28,.34,1)
    bkg.inputs["Strength"].default_value=.28
    sc.world=world
    sc.render.engine="CYCLES"
    sc.cycles.samples=16
    sc.cycles.use_denoising=True
    sc.cycles.device="CPU"
    sc.render.film_transparent=True
    sc.view_settings.view_transform="AgX"
    sc.view_settings.look="AgX - Medium High Contrast"
    sc.view_settings.exposure=-.72
    sc.render.image_settings.color_mode="RGBA"


def save_stage(sc,view,out,shape):
    sc.frame_set(1)
    sc.camera=view
    sc.render.resolution_x,sc.render.resolution_y=shape
    sc.render.resolution_percentage=100
    sc.render.filepath="//renders/"
    bpy.context.preferences.filepaths.save_version=0
    for screen in bpy.data.screens:
        for ar in screen.areas:
            if ar.type=="VIEW_3D":
                space=ar.spaces.active
                space.region_3d.view_perspective="CAMERA"
                space.overlay.show_overlays=False
                space.shading.color_type="MATERIAL"
    bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True)


def finish(line,item,version,evidence):
    key=(line,item)
    directory=folder(line,item,version)
    manifest=directory/"build.json"
    if manifest.is_file():
        return
    directory.mkdir(parents=True,exist_ok=True)
    if key in HEROES+MELEES+CHARMS:
        sc,views,motion,source,design,fit=concept(line,item)
    else:
        sc,rig,path,views,controls,charm,_,fit=gun_design(line,item)
        motion=gun_motion(sc,rig,line,item,controls,charm)
        hands_for(sc,rig,line,item,motion)
        source=str(path.relative_to(ROOT))
        design="Reviewed stock-cued concept panels"
    setup(sc)
    stock=[o for o in bpy.data.collections[item].objects if o.type=="MESH"] if key in GUNS else []
    finish_materials(line,item,stock)
    custom=custom_meshes(sc)
    assert custom and not mesh_check(custom)
    applied=edge_detail(custom)
    clips=melee_actions(sc,item) if key in MELEES else {}
    if key in GUNS:
        fit.update(check_gun(sc,line,item,motion))
        assert not any(fit[name] for name in ("moving_stock_intersections","charm_fixed_intersections","cosmetic_aim_ray_hits")), (line,item,fit)
    sc.name=f"{line} | {item} | Finish {version}"
    sc["Exotic finish"]=f"{line} / {item} / {version}"
    sc["Source"]=source
    sc["Review scope"]="Offline Blender model finish"
    sc["Review poses"]=motion
    if clips:
        sc["Reusable first-person clips"]=list(clips)
    hands=bpy.data.collections.get("EXOTIC | First-person hand pose proxies")
    if hands:
        hands.hide_render=True
        hands["Review only"]="Pose-guide geometry. Toggle for the first-person camera."
    studio(sc,views["hero"],line)
    path=directory/f"{item}_{line}_finish_{version}.blend"
    shape=(1200,650) if key in GUNS else (1080,720)
    save_stage(sc,views["hero"],path,shape)
    if evidence:
        render(sc,views["hero"],directory/"beauty.png",1,shape)
    # Reopen the delivered file; independently verify movement and source geometry.
    bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False)
    sc=bpy.context.scene
    custom=custom_meshes(sc)
    assert sc["Exotic finish"]==f"{line} / {item} / {version}" and not mesh_check(custom)
    rest=state(sc,custom,1)
    cancel=motion.get("cancel",motion.get("reset"))
    delta=max(abs(a-b) for a,b in zip(rest,state(sc,custom,cancel)))
    active=motion.get("inspect",motion.get("active"))
    travel=max(abs(a-b) for a,b in zip(rest,state(sc,custom,active)))
    assert delta<.0002 and travel>.004,(line,item,delta,travel)
    stock_count=stock_check(sc,ROOT,item,{"source":source}) if key in GUNS else 0
    manifest.write_text(json.dumps({"line":line,"item":item,"version":version,"file":path.name,
        "source":source,"concept":design,"stock_geometry_matches":stock_count,"fit":fit,
        "new_manifold_meshes":len(custom),"flat_edge_finishes":applied,
        "motion":motion,"actions":clips,"rest_pose_delta":round(delta,7),"active_pose_delta":round(travel,7),
        "beauty":"beauty.png" if evidence else None},indent=2),encoding="utf-8")


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("line")
    parser.add_argument("item")
    parser.add_argument("--version",default="v01")
    parser.add_argument("--no-render",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    if (args.line,args.item) not in QUEUE:
        parser.error("Item is outside the approved exotic lineup")
    finish(args.line,args.item,args.version,not args.no_render)
