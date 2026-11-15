"""Build the faceted PopCircuit Bat and check its poses with the project arm meshes."""
import hashlib
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_skin_roster import (
    ART, PALETTES, REVIEW, audit_uv, author, bake, bake_maps,
    fingerprints, framing, linear, mesh_objects, rel, sheet, write_json,
)
from v2kit import build_rig, parent_to_bone, uv_pack

BAT = "Bat"
FPS = 24
WIDTH = .50
LENGTH = .50 * 5.0 * 1.45
OVERSHOOT = WIDTH * .30
RIGHT = (0, -.094, -.016)
SUPPORT = (.65, .144, -.053)
ARM_SOURCE = ART.parent / "viewmodel/Arms.fbx"
REST = ((1.22,-.69,-.62), (7,-37,66))
FREE = (1.14,.69,-.69)
POSES = {
    "Idle": {1:REST, 17:((1.23,-.69,-.60),(8,-39,65)), 32:REST},
    "SlashLeft": {
        1:REST, 4:((1.18,-.80,-.52),(-16,-19,-36)),
        7:((1.47,-.40,-.50),(-7,-8,31)), 9:((1.40,-.23,-.38),(16,-9,101)),
        12:((1.27,-.10,-.43),(23,-11,125)), 18:REST,
    },
    "SlashRight": {
        1:REST, 4:((1.24,.21,-.40),(18,-24,124)),
        7:((1.32,.47,-.49),(10,-18,35)), 9:((1.32,.52,-.52),(-12,-12,-76)),
        12:((1.23,.27,-.54),(-19,-16,-101)), 18:REST,
    },
    "Smash": {
        1:REST, 6:((1.33,-.41,-.11),(12,-52,64)),
        10:((1.56,-.63,.27),(12,-67,64)), 13:((1.79,-.66,.20),(9,-24,68)),
        16:((1.93,-.60,.29),(3,31,71)), 19:((1.86,-.54,.17),(6,37,73)),
        23:((1.53,-.46,-.21),(16,6,67)), 31:REST,
    },
    "Inspect": {
        1:REST, 9:((1.48,-.76,-.42),(13,-30,64)),
        17:((1.61,-.70,-.40),(-17,-27,84)), 24:((1.59,-.68,-.39),(19,-29,90)),
        33:((1.52,-.69,-.42),(9,-27,74)), 43:REST,
    },
}
CONTACT = {"SlashLeft":9,"SlashRight":9,"Smash":16}
TRAILS = {"SlashLeft":(6,12),"SlashRight":(6,12)}


def material(name, hexcode, rough, metal):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    color = (*linear(hexcode),1)
    mat.diffuse_color = color
    bs = mat.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = color
    bs.inputs["Roughness"].default_value = rough
    bs.inputs["Metallic"].default_value = metal
    if name=="Neon":
        bs.inputs["Emission Color"].default_value = color
        bs.inputs["Emission Strength"].default_value = 1.1
    return mat


def loft(name, collection, profile, roles, sides=12):
    vertices = [(x, math.cos(theta)*radius, math.sin(theta)*radius)
                for x,radius,_ in profile
                for theta in [math.tau*(i+.5)/sides for i in range(sides)]]
    faces = [tuple(reversed(range(sides)))]
    mats = [profile[0][2]]
    for j, (_,_,role) in enumerate(profile[:-1]):
        for i in range(sides):
            a,b = j*sides+i,j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
            mats.append(role)
    faces.append(tuple(range(len(vertices)-sides,len(vertices))))
    mats.append(profile[-1][2])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    ob = bpy.data.objects.new(name,mesh)
    collection.objects.link(ob)
    for role in roles.values():
        mesh.materials.append(role)
    for face,role in zip(mesh.polygons,mats):
        face.material_index = mesh.materials.find(role)
    return ob


def grip_wrap(collection, roles):
    # One tapered grip with a small helical seam between wrap passes.
    profile = [(-.155,.087,"Dark"),(-.137,.111,"Grip"),(-.09,.117,"Grip"),
               (.93,.104,"Grip"),(.99,.106,"Dark"),(1.015,.091,"Dark")]
    grip = loft("Bat_Grip",collection,profile,roles)
    vertices,faces = [],[]
    turns = 12
    for n in range(12*turns+1):
        t = n/(12*turns)
        x = -.111 + 1.076*t
        angle = t*turns*math.tau
        radius = .1158 - t*.0114
        for dx,dr in ((-.013,-.002),(-.005,.006),(.005,.006),(.013,-.002)):
            vertices.append((x+dx,math.cos(angle)*(radius+dr),math.sin(angle)*(radius+dr)))
    for n in range(12*turns):
        i = 4*n
        faces.extend([(i+j,i+(j+1)%4,i+4+(j+1)%4,i+4+j) for j in range(4)])
    faces.extend([(3,2,1,0),tuple(range(len(vertices)-4,len(vertices)))])
    mesh = bpy.data.meshes.new("Bat_WrapSeam")
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    seam = bpy.data.objects.new(mesh.name,mesh)
    collection.objects.link(seam)
    mesh.materials.append(roles["Grip"])
    mesh.materials.append(roles["Dark"])
    for f in mesh.polygons:
        f.material_index = int(f.index%4 in (0,2))
    return [grip,seam]


def locator(name,collection,rig,position,bone="Bat"):
    ob = bpy.data.objects.new("Bat_"+name,None)
    collection.objects.link(ob)
    ob.empty_display_type = "ARROWS"
    ob.empty_display_size = .065
    parent_to_bone(ob,rig,bone,Matrix.Translation(position))
    return ob


def build_model(scene):
    collection = bpy.data.collections.new(BAT)
    scene.collection.children.link(collection)
    roles = {name:material(name,*values) for name,values in PALETTES["PopCircuit"].items()}
    barrel = loft("Bat_Barrel",collection,[
        (.994,.093,"Metal"),(1.031,.109,"Accent"),(1.072,.112,"Metal"),(1.112,.12,"Body"),
        (1.22,.142,"Body"),(1.39,.184,"Body"),(1.65,.229,"Body"),(2.06,.250,"Body"),
        (2.32,.252,"Panel"),(2.373,.247,"Panel"),(2.396,.240,"Body"),
    ],roles)
    cap = loft("Bat_Cap",collection,[
        (2.393,.233,"Metal"),(2.413,.246,"Neon"),(2.435,.246,"Panel"),
        (2.457,.243,"Metal"),(2.502,.226,"Metal"),(2.533,.185,"Dark"),
    ],roles)
    knob = loft("Bat_Knob",collection,[
        (-.253,.102,"Dark"),(-.234,.137,"Metal"),(-.199,.161,"Metal"),
        (-.173,.159,"Accent"),(-.155,.153,"Metal"),(-.129,.106,"Metal"),
    ],roles,10)
    objs = [barrel,cap,knob,*grip_wrap(collection,roles)]
    rig = build_rig(collection,"Bat_",[
        ("Root",None,(0,0,0)),("Bat","Root",(0,0,0)),("LeftHand","Root",FREE),
    ])
    for ob in objs:
        parent_to_bone(ob,rig,"Bat",Matrix.Identity(4))
    locators = {
        name:locator(name,collection,rig,position)
        for name,position in (("RightGrip",RIGHT),("LeftSupport",SUPPORT),
                              ("TrailInner",(1.66,0,0)),("TrailOuter",(2.49,0,0)))
    }
    rig["light_trail_palette"] = "539BFF,FF9DD8,6554C9"
    rig["frame_rate"] = FPS
    return rig,locators


def preview_arms(scene,rig,locators):
    collection = bpy.data.collections.new("Bat_ReviewArms")
    scene.collection.children.link(collection)
    bpy.ops.import_scene.fbx(filepath=str(ARM_SOURCE))
    skin = material("Review arm neutral","8F9DAF",.62,0)
    skin2 = material("Review arm shadow","76879C",.62,0)
    results = {}
    left = rig.pose.bones["LeftHand"]
    latch = left.constraints.new("COPY_LOCATION")
    latch.name = "Left hand support blend"
    latch.target = locators["LeftSupport"]
    latch.influence = 0
    for side,position in (("Right",(-.55,-1.95,-3)),("Left",(-.55,1.95,-3))):
        mesh = bpy.data.objects[f"Arm{side}"]
        for owner in list(mesh.users_collection):
            owner.objects.unlink(mesh)
        collection.objects.link(mesh)
        bpy.data.objects.remove(bpy.data.objects[f"Arm{side}Outline"],do_unlink=True)
        mesh.data.materials.clear()
        mesh.data.materials.append(skin if side=="Right" else skin2)
        shoulder = bpy.data.objects.new(f"Review_{side}Shoulder",None)
        shoulder.location = position
        collection.objects.link(shoulder)
        origin = bpy.data.objects.new(f"Review_{side}Hand",None)
        collection.objects.link(origin)
        follow = origin.constraints.new("COPY_LOCATION")
        follow.target = locators["RightGrip"] if side=="Right" else rig
        if side=="Left":
            follow.subtarget = "LeftHand"
        aim = origin.constraints.new("TRACK_TO")
        aim.target = shoulder
        aim.track_axis = "TRACK_Z"
        aim.up_axis = "UP_Y"
        mesh.parent = origin
        mesh.rotation_euler = (0,0,0)
        mesh.scale = (WIDTH, WIDTH, LENGTH/5)
        mesh.location = (0,0,LENGTH/2-OVERSHOOT)
        results[side] = (origin,mesh)
    return results,latch


def animate(rig,latch):
    animation = rig.animation_data_create()
    motions = {}
    bat = rig.pose.bones["Bat"]
    for name, poses in POSES.items():
        action = bpy.data.actions.new("Bat_"+name)
        action.use_fake_user = True
        animation.action = action
        for f,(location,rotation) in poses.items():
            bat.location = location
            bat.rotation_euler = tuple(math.radians(a) for a in rotation)
            bat.keyframe_insert("location",frame=f,group="Bat")
            bat.keyframe_insert("rotation_euler",frame=f,group="Bat")
        for f,value in ((1,0),(6,0),(10,1),(20,1),(25,0),(max(26,max(poses)),0)) if name=="Smash" else ((1,0),(max(poses),0)):
            latch.influence = value
            latch.keyframe_insert("influence",frame=f,group="Support hand")
        left = rig.pose.bones["LeftHand"]
        free_keys = {1:(0,0,0),max(poses):(0,0,0)}
        if name=="SlashRight":
            free_keys.update({5:(0,.26,-.27),9:(-.08,.44,-.44),13:(-.08,.35,-.32)})
        if name=="Smash":
            free_keys.update({6:(.08,.22,.02),8:(.17,.44,.07),10:(0,0,0)})
        for frame,location in sorted(free_keys.items()):
            left.location = location
            left.keyframe_insert("location",frame=frame,group="Support hand")
        if name in CONTACT:
            action.pose_markers.new("Contact").frame = CONTACT[name]
        if name in TRAILS:
            start,end = TRAILS[name]
            action.pose_markers.new("TrailOn").frame = start
            action.pose_markers.new("TrailOff").frame = end
        if name == "Smash":
            action.pose_markers.new("SupportLocked").frame = 10
            action.pose_markers.new("SupportReleased").frame = 25
        motions[name] = action
    animation.action = motions["Idle"]
    return motions


def capsule_frame(scene, rig, action, f):
    rig.animation_data.action = action
    scene.frame_set(f)
    bpy.context.view_layer.update()


def mesh_tree(ob, depsgraph):
    evaluated = ob.evaluated_get(depsgraph)
    vertices = [evaluated.matrix_world @ v.co for v in evaluated.data.vertices]
    polygons = [list(f.vertices) for f in evaluated.data.polygons]
    return BVHTree.FromPolygons(vertices,polygons)


def check_poses(scene,rig,locators,arms,motions):
    result = {}
    for name,action in motions.items():
        right_errors,left_errors,separations = [],[],[]
        frame_checks = {}
        for f in range(1,max(POSES[name])+1):
            capsule_frame(scene,rig,action,f)
            right = arms["Right"][0].matrix_world.translation
            left = arms["Left"][0].matrix_world.translation
            right_errors.append((right-locators["RightGrip"].matrix_world.translation).length)
            if name=="Smash" and 10<=f<=20:
                left_errors.append((left-locators["LeftSupport"].matrix_world.translation).length)
            separations.append((left-right).length)
            dg = bpy.context.evaluated_depsgraph_get()
            a,b = (mesh_tree(arms[side][1],dg) for side in ("Right","Left"))
            trees = [mesh_tree(bpy.data.objects[n],dg) for n in ("Bat_Barrel","Bat_Cap")]
            frame_checks[f] = {
                "arm_surfaces_intersect": bool(a.overlap(b)),
                "right_arm_intersects_barrel": any(a.overlap(tree) for tree in trees),
                "left_arm_intersects_barrel": any(b.overlap(tree) for tree in trees),
            }
        assert max(right_errors)<1e-5, "Primary grip drifted"
        assert max(left_errors,default=0)<1e-5, "Support grip drifted during the smash"
        result[name] = {"frames":max(POSES[name]),"max_primary_drift":max(right_errors),
                        "max_locked_support_drift":max(left_errors,default=0),
                        "min_hand_center_separation":min(separations),"mesh_intersections":{
                            f:checks for f,checks in frame_checks.items() if any(checks.values())
                        },"frames_checked":len(frame_checks)}
    capsule_frame(scene,rig,motions["Idle"],1)
    return result


def trail(scene,rig,locators,action,window,frame):
    start,end = window
    samples = []
    for f in range(start, min(end,frame)+1):
        capsule_frame(scene,rig,action,f)
        samples.append(tuple(locators[n].matrix_world.translation.copy()
                             for n in ("TrailInner","TrailOuter")))
    made = []
    eye = Vector((0,0,0))
    for index,hexcode in enumerate(("539BFF","FF9DD8","6554C9")):
        positions = []
        for i,(a,b) in enumerate(samples):
            progress = i/max(1,len(samples)-1)
            center = a.lerp(b,.80)
            prior = samples[max(0,i-1)][0].lerp(samples[max(0,i-1)][1],.80)
            after = samples[min(len(samples)-1,i+1)][0].lerp(samples[min(len(samples)-1,i+1)][1],.80)
            normal = (after-prior).cross(eye-center).normalized()
            spacing = .040 * progress**.7
            width = .017 * progress**.65
            center += normal*((index-1)*spacing)
            positions.extend([center-normal*width,center+normal*width])
        faces = [(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(samples)-1)]
        mesh = bpy.data.meshes.new("Slash ribbon")
        mesh.from_pydata(positions,[],faces)
        ob = bpy.data.objects.new("Bat_LightTrailPreview",mesh)
        scene.collection.objects.link(ob)
        mat = material("Ribbon preview",hexcode,.32,0)
        bs = mat.node_tree.nodes.get("Principled BSDF")
        bs.inputs["Emission Color"].default_value = (*linear(hexcode),1)
        bs.inputs["Emission Strength"].default_value = .5
        mesh.materials.append(mat)
        made.append(ob)
    return made


def renders(scene,rig,locators,arms,motions,dest):
    dest.mkdir(parents=True,exist_ok=True)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    rig.animation_data.action = None
    bone = rig.pose.bones["Bat"]
    bone.location = (0,0,0)
    bone.rotation_euler = (0,0,0)
    bpy.context.view_layer.update()
    for side in arms:
        arms[side][1].hide_render = True
    res = (560,260)
    pts = sheet._pts(BAT)
    for label,toward in (("Left",(.03,1,.14)),("Right",(-.03,-1,.13)),("Detail",(.31,1,.29))):
        cam,c,r = sheet._cam(BAT,label,pts,toward,ortho=True,aspect=res[0]/res[1],margin=1.08)
        sheet._lights(BAT,cam,c,r)
        framing.shot(BAT,cam,str(dest/f"{label}.png"),res=res)
    grip_pts = [Vector((x,y,z)) for x in (-.27,1.0) for y in (-.13,.13) for z in (-.13,.13)]
    cam,c,r = sheet._cam(BAT,"Grip",grip_pts,(0,1,.12),ortho=True,aspect=2.15,margin=1.1)
    sheet._lights(BAT,cam,c,r)
    framing.shot(BAT,cam,str(dest/"Grip.png"),res=(860,400))
    for side in arms:
        arms[side][1].hide_render = False
    cam = framing.camera(BAT,"PoseReview",(0,0,0),(1,0,0),fov_v=74,clip=.09)
    sheet._lights(BAT,cam,Vector((1.8,0,0)),1.4)
    for label,name,f in (("FirstPerson","Idle",1),("SlashLeft","SlashLeft",10),
                         ("SlashRight","SlashRight",10),("SmashSet","Smash",10),
        ("Smash","Smash",16),("Inspect","Inspect",24)):
        ribbons = trail(scene,rig,locators,motions[name],TRAILS[name],f) if name in TRAILS else []
        capsule_frame(scene,rig,motions[name],f)
        framing.shot(BAT,cam,str(dest/f"{label}.png"),res=(640,360))
        for ribbon in ribbons:
            bpy.data.objects.remove(ribbon,do_unlink=True)
    capsule_frame(scene,rig,motions["Idle"],1)


def main():
    args = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    version = next((a for a in args if a.startswith("v")), "v01")
    assert version.startswith("v") and version[1:].isdigit()
    dest = ART/"Skins/PopCircuit/Bat"/version
    check_only = "--check-poses" in args
    render_only = "--render-only" in args
    if render_only:
        file = dest/f"Bat_PopCircuit_{version}.blend"
        bpy.ops.wm.open_mainfile(filepath=str(file),load_ui=False)
        scene = framing.scene(BAT)
        bpy.context.window.scene = scene
        rig = bpy.data.objects["Bat_Rig"]
        locators = {name:bpy.data.objects["Bat_"+name]
                    for name in ("RightGrip","LeftSupport","TrailInner","TrailOuter")}
        arms = {side:(bpy.data.objects[f"Review_{side}Hand"],bpy.data.objects[f"Arm{side}"])
                for side in ("Right","Left")}
        motions = {name:bpy.data.actions["Bat_"+name] for name in POSES}
        sheet.bind(vars(framing))
        renders(scene,rig,locators,arms,motions,REVIEW/"renders/PopCircuit/Bat"/version)
        return
    assert check_only or not dest.exists(), f"Version already exists: {dest}"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = "Bat_RemasterV2_Review"
    scene.render.fps = FPS
    scene.frame_end = 43
    scene.world = bpy.data.worlds.new("Neutral review")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes.get("Background").inputs["Color"].default_value = (.23,.25,.30,1)
    scene.world.node_tree.nodes.get("Background").inputs["Strength"].default_value = .7
    rig,locators = build_model(scene)
    if check_only:
        import json
        arms,latch = preview_arms(scene,rig,locators)
        motions = animate(rig,latch)
        checks = check_poses(scene,rig,locators,arms,motions)
        print(json.dumps({name:data["mesh_intersections"] for name,data in checks.items()}))
        return
    uv_pack(BAT,margin=.008)
    objs = mesh_objects(BAT)
    uv = audit_uv(objs)
    assert uv["cross_object_overlap_pixels"]==0 and uv["different_role_overlap_pixels"]==0, uv
    assert not any(p.use_smooth or len(p.vertices)<3 for ob in objs for p in ob.data.polygons)
    assert all(m.type!="SUBSURF" for ob in objs for m in ob.modifiers)
    author("PopCircuit",BAT,objs)
    dest.mkdir(parents=True)
    bake_maps(BAT,scene,objs,dest/"textures")
    arms,latch = preview_arms(scene,rig,locators)
    motions = animate(rig,latch)
    checks = check_poses(scene,rig,locators,arms,motions)
    sheet.bind(vars(framing))
    review = REVIEW/"renders/PopCircuit/Bat"/version
    renders(scene,rig,locators,arms,motions,review)
    scene.camera = bpy.data.objects["Bat_FP_PoseReview"]
    # Open on the idle pose with the real review arm meshes and a working timeline.
    scene.render.engine = "BLENDER_EEVEE"
    if hasattr(scene,"eevee"):
        scene.eevee.taa_render_samples = 32
    for area in bpy.context.screen.areas:
        if area.type=="VIEW_3D":
            area.spaces.active.region_3d.view_perspective = "CAMERA"
            area.spaces.active.shading.type = "MATERIAL"
    file = dest/f"Bat_PopCircuit_{version}.blend"
    bpy.context.preferences.filepaths.save_version = 0
    before = fingerprints(BAT)
    bpy.ops.wm.save_as_mainfile(filepath=str(file),compress=True,relative_remap=False)
    bpy.ops.wm.open_mainfile(filepath=str(file),load_ui=False)
    assert before==fingerprints(BAT)
    assert all(bpy.data.images[f"Bat_{name}"].packed_file for name in bake.MAPS)
    write_json(dest/"manifest.json",{
        "line":"PopCircuit","item":BAT,"version":version,"build_status":"baked and pose checked",
        "studio_status":"pending Blender approval and runtime integration",
        "concept":"vault/02 Art/Skins/PopCircuit/out/Bat_v01.png",
        "blend":rel(file),"saved_file_verified":True,
        "source":"Original model", "review_arm_source":rel(ARM_SOURCE),
        "review_arm_source_sha256":hashlib.sha256(ARM_SOURCE.read_bytes()).hexdigest(),
        "uv":uv,"fingerprints":before,"pose_checks":checks,
        "actions":sorted(bpy.data.actions.keys()),"locators":list(locators),
        "grip_anchor_local":RIGHT,"support_anchor_local":SUPPORT,
        "trail_frames":TRAILS,"contact_frames":CONTACT,"fps":FPS,
        "textures":{name:rel(dest/"textures"/f"Bat_{name}.png") for name in bake.MAPS},
        "texture_sha256":{name:hashlib.sha256((dest/"textures"/f"Bat_{name}.png").read_bytes()).hexdigest()
                          for name in bake.MAPS},
        "review_renders":rel(review),
    })
    print(f"BAKED PopCircuit/Bat/{version}",flush=True)


if __name__=="__main__":
    main()

