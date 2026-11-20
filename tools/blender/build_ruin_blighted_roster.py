"""Shadow Mist rebuilds using the approved Guardian fit and export workflow."""

from dataclasses import dataclass, replace
import json
from math import cos, radians, sin

import bpy
from mathutils import Vector

import build_ruin_blighted_guardian as guardian
from ruin_blighted_round import round_meshes


art = guardian.support
FINISH = guardian.FINISH


@dataclass(frozen=True)
class RifleFit:
    length: tuple
    mag_height: tuple
    grip_width: float
    shoulder_width: float
    body_height: float
    fore_rise: float
    collar_x: tuple
    collar_z: tuple
    guard_x: tuple
    guard_z: tuple
    barrel: str
    ads: float | None
    fov: int
    front: tuple | None


RIFLES = {
    "Vandal": RifleFit(
        ((-1.252, -1.252), (1.98, 1.98)),
        ((-.4041, -.4041), (.2318, .2318)),
        1, 1, 1, 0,
        ((-.091,-.121),(.186,.157)), ((.136,.141),(.191,.199)),
        ((.143,.124),(.257,.214),(.446,.423)), ((.029,.035),(.121,.160),(.188,.211)),
        "Barrel", .36, 68, (0, .5598, .20),
    ),
    "Spectre": RifleFit(
        ((-1.252,-1.063),(-.75,-.761),(-.36,-.417),(-.178,-.322),
         (0,-.057),(.214,.222),(.461,.437),(.729,.588),(1.046,.727),
         (1.320,.9212),(1.685,1.122),(1.980,1.227)),
        ((-.4041,-.557),(-.34,-.476),(-.178,-.253),(.074,-.020),(.2318,.134)),
        .938, .88, .88, .058,
        ((-.091,-.184),(.186,.130)), ((.136,.117),(.191,.212)),
        ((.143,.104),(.257,.224),(.446,.405)), ((.029,.021),(.121,.152),(.188,.224)),
        "Suppressor", .337, 72, (-.990, .5236, .291),
    ),
    "Operator": RifleFit(
        ((-1.252,-1.318),(-.75,-.749),(-.36,-.291),(-.178,-.106),
         (0,.014),(.214,.251),(.461,.454),(.729,.749),(1.046,1.115),
         (1.320,1.6625),(1.685,2.207),(1.980,2.292)),
        ((-.4041,-.086),(-.34,-.065),(-.178,.014),(.074,.113),(.2318,.233)),
        1, .99, .95, .025,
        ((-.091,-.165),(.186,.157)), ((.136,.112),(.191,.216)),
        ((.143,.103),(.257,.251),(.446,.413)), ((.029,.016),(.121,.125),(.188,.219)),
        "Barrel", None, 58, None,
    ),
}


def limits(surface, i):
    values = [v[i] for v in surface.verts]
    return min(values), max(values)


def seat_point(p, x_fit, z_fit, width):
    x, y, z = p
    return Vector((guardian.interp(x,x_fit), y*width, guardian.interp(z,z_fit)))


def body_fit(profile, p):
    x,y,z = p
    rise = max(0, min(1, (x - .99) / .41))*profile.fore_rise
    return Vector((guardian.interp(x,profile.length), y*profile.shoulder_width,
                   .294+(z-.294)*profile.body_height+rise))


def rim_fit(aim, p):
    x,y,z=p
    return Vector((x+aim.x-.0775,y,z+aim.z-.5598))


def front_fit(spec, p):
    dx, center, base = spec
    x,y,z=p
    out=guardian.interp(z,((.20,base),(.5598,center),(.594,center+.031)))
    if abs(y)<.01:
        out=min(out,center-.008)
    return Vector((x+dx,y,out))


def author_panel(col, rig, name, surface, fit, colors, bone="Root"):
    ob=guardian.add_surface(col,name,surface,fit,colors)
    art.bind(ob,rig,bone)
    return ob


def add_hardware(col, rig, colors, collar_x, collar_z, guard_x, guard_z, width):
    collar, guard=guardian.lower_receiver_hardware(col,colors)
    for o,x_fit,z_fit in ((collar,collar_x,collar_z),(guard,guard_x,guard_z)):
        for v in o.data.vertices:
            v.co=seat_point(v.co,x_fit,z_fit,width)
        o.data.update()
        art.bind(o,rig,"Root")
    return [collar,guard]


def charm_saddle(gun, col, rig, colors):
    # Seat the stock plate into the fixed receiver, leaving the ring and socket at stock.
    x, low, high, inner, outer = {
        "Operator": (.945, .143, .192, .055, .092),
        "Ghost": (.860, .179, .211, .033, .064),
        "Spectre": (.800, .264, .288, .077, .091),
    }[gun]
    mount = art.prism(col, "RB_Receiver_CharmSaddle",
        [(x-.018, low+.004), (x-.012, low), (x+.013, low),
         (x+.020, low+.009), (x+.019, high-.010), (x+.007, high),
         (x-.013, high-.003), (x-.021, high-.017)],
        inner, outer, colors[FINISH+"Gunmetal"], .004)
    art.bind(mount, rig, "Root")
    return mount


def spectre_feed_fit(col, rig, colors):
    # The moving throat follows the magazine. Fixed cheeks cover the
    # feed opening when seated, leaving the chamber path open.
    throat = art.loft(col, "RB_Magazine_Throat", (
        (.580, 0, -.046, .113, .047), (.572, 0, -.032, .117, .055),
        (.565, 0, -.014, .115, .055), (.560, 0, .009, .112, .051),
    ), 12, colors[FINISH+"Magazine obsidian"])
    art.bind(throat, rig, "Mag")
    items = [throat]
    for sign in (-1, 1):
        cheek = art.prism(col, f"RB_Receiver_MagwellCheek_{sign}",
            [(.420,.140), (.459,.158), (.587,.148), (.641,.114),
             (.653,.090), (.628,.082), (.460,.086), (.433,.111)],
            sign*.0585, sign*.071, colors[FINISH+"Shadow"], .004)
        art.bind(cheek, rig, "Root")
        items.append(cheek)
    for obj in round_meshes(col, Vector((.533, 0, .114)), .147):
        art.bind(obj, rig, "Mag")
        items.append(obj)
    return items


def feed_lips_only(surface):
    # The donor combines a separate brass round and feed lips in one mesh.
    faces = [face for face, index in zip(surface.faces, surface.material_indices, strict=True)
             if surface.material_names[index] == FINISH + "Shadow"]
    used = sorted({i for face in faces for i in face})
    remap = {vertex: i for i, vertex in enumerate(used)}
    return replace(surface, verts=[surface.verts[i] for i in used],
        faces=[tuple(remap[i] for i in face) for face in faces],
        material_indices=[0] * len(faces), material_names=[FINISH+"Shadow"], edges=[])


def skin_mag_fit(blueprint, stock_mag, heights):
    fit=guardian.fitted_surface(blueprint["Vandal_Mag"],stock_mag,heights)
    mag_span=limits(stock_mag,1)
    width=(mag_span[1]-mag_span[0])/.128
    def mapped(p):
        x,y,z=fit(p)
        return Vector((x,y*width,z))
    return mapped


def skin_tape_fit(blueprint, stock_grip):
    old=limits(blueprint["Vandal_Grip"],2)
    new=limits(stock_grip,2)
    w0,w1=limits(stock_grip,1)
    fit=guardian.fitted_surface(blueprint["Vandal_Grip"],stock_grip,tuple(zip(old,new,strict=True)))
    def mapped(p):
        x,y,z=fit(p)
        return Vector((x,y*(w1-w0)/.128,z))
    return mapped


def mover_for(name, ob, bone, area, aim):
    if area=="Sight" and "_Fragment_" in name:
        center=art.position_origin(ob)
        axis=Vector((0,center.y,center.z-aim.z)).normalized()
        return (ob,bone,center,area,axis,.010)
    receiver=guardian.receiver_shard(name)
    if receiver or name.startswith(guardian.FLOATING_PLATES):
        travel,rise,_=receiver or (.041,.29,0)
        center=art.position_origin(ob)
        sign=1 if center.y>=0 else -1
        direction=Vector((.12,sign*.93 if abs(center.y)>.018 else 0,rise)).normalized()
        return (ob,bone,center,area,direction,travel if bone=="Root" else travel*.71)
    return None


def optic_housing(col, rig, aim):
    # A cut-collar body surrounds the existing coated lenses. The low
    # bridges keep the scope's mechanical datum and scope overlay at stock.
    art.palette(guns=True)
    collars=[
        (-.082,.126),(-.055,.141),(.013,.144),(.025,.145),(.036,.138),
        (.158,.137),(.218,.098),(.515,.092),(.542,.109),(.650,.109),
        (.713,.087),(.984,.101),(1.079,.097),(1.208,.126),(1.267,.150),
        (1.386,.157),(1.472,.155),(1.482,.149),(1.492,.151),(1.592,.143),
    ]
    result=[art.bored_tube(col,rig,"RB_Receiver_CutOptic",aim.z,collars,.069,
                          {"Jade":2,"Metal":7,"Slate":13,"Crest":17},facets=10)]
    for x in (.310,.949):
        foot=art.prism(col,"RB_Receiver_OpticSaddle",
            [(x-.083,.405),(x+.093,.402),(x+.080,.510),(x+.042,.526),(x-.056,.517)],
            -.057,.057,art.PAL["Metal"],.01)
        art.bind(foot,rig,"Root")
        result.append(foot)
    return result


def rifle_meshes(gun, profile, col, rig, blueprint, stock, colors, aim):
    mag_key="Magazine" if gun=="Operator" else "Mag"
    mag_fit=skin_mag_fit(blueprint,stock[mag_key],profile.mag_height)
    tape_fit=skin_tape_fit(blueprint,stock["Grip"])
    body=lambda p:body_fit(profile,p)
    components=[]
    moving=[]
    for name,source in blueprint.items():
        if name in {"Vandal_Mag","Vandal_Grip","Vandal_FrontSight"}:
            continue
        area=guardian.cut_region(name)
        if area=="Sight":
            if profile.front is None:
                continue
            if "_Fragment_" in name:
                fit=lambda p:rim_fit(aim,p)
            else:
                fit=lambda p:guardian.rear_point(p,aim,True)
        elif area=="Mag":
            fit=mag_fit
        elif "PistolGrip" in name:
            fit=tape_fit
        else:
            fit=body
        if gun == "Spectre" and name == "RB_Magazine_LipsAndRound":
            name = "RB_Magazine_FeedLips"
            source = feed_lips_only(source)
        obj=guardian.add_surface(col,name.replace("Vandal_","RB_Carved"),source,fit,colors)
        mover=mover_for(name,obj,source.bone,area,aim)
        if mover:
            moving.append(mover)
        art.bind(obj,rig,source.bone)
        components.append(obj)

    components.extend((
        author_panel(col,rig,f"RB_{gun}_OriginalBarrel",stock[profile.barrel],Vector,colors),
        author_panel(col,rig,f"RB_{gun}_GripCore",stock["Grip"],Vector,colors),
    ))
    components.extend(add_hardware(col,rig,colors,profile.collar_x,profile.collar_z,
                                   profile.guard_x,profile.guard_z,profile.grip_width))
    if gun == "Spectre":
        components.extend(spectre_feed_fit(col, rig, colors))
    if profile.front:
        components.append(author_panel(col,rig,"RB_FrontSight",blueprint["Vandal_FrontSight"],
                                      lambda p:front_fit(profile.front,p),colors))
    else:
        components.extend(optic_housing(col,rig,aim))
    return components,moving,mag_fit,body


def slide_fit(p):
    length=((-.176,-.215),(0,-.076),(.30,.253),(.66,.610),(1.04,.956),(1.55,1.12))
    height=((.178,.235),(.26,.260),(.35,.332),(.475,.434))
    return seat_point(p,length,height,.695)


def ghost_meshes(col, rig, blueprint, stock, colors):
    art.palette(guns=True)
    mag_fit=skin_mag_fit(blueprint,stock["Mag"],((-.4041,-.458),(-.339,-.418),
                          (-.178,-.247),(.074,-.066),(.232,.108)))
    tape_fit=skin_tape_fit(blueprint,stock["Grip"])
    # Slide and frame are authored as separate shells. All the upper seams
    # and their rigid fracture panels follow the original slide action.
    components=[
        art.carapace(col,rig,"RB_CarvedSlide",
          ((-.226,.239,.377,.047),(-.169,.227,.416,.060),(.14,.223,.402,.064),
           (.43,.229,.394,.061),(.69,.244,.364,.058),(.955,.233,.354,.052),
           (1.111,.237,.333,.043)),"Slide"),
        art.carapace(col,rig,"RB_CarvedFrame",
          ((-.237,.108,.207,.042),(-.168,.115,.230,.055),(.102,.126,.232,.064),
           (.331,.155,.231,.062),(.592,.169,.229,.057),(.875,.180,.222,.051),
           (1.086,.195,.221,.039)),"Root"),
        author_panel(col,rig,"RB_Ghost_OriginalBarrel",stock["Suppressor"],Vector,colors),
        author_panel(col,rig,"RB_Ghost_GripCore",stock["Grip"],Vector,colors),
    ]
    moving=[]
    for name,source in blueprint.items():
        if name.startswith("RB_Receiver_"):
            if "Action" in name or "Spine" in name:
                continue
            area,bone,fit="Receiver","Slide",slide_fit
        elif name.startswith("RB_Magazine_"):
            area,bone,fit="Mag","Mag",mag_fit
        elif name.startswith("RB_PistolGrip_"):
            area,bone,fit="Receiver","Root",tape_fit
        else:
            continue
        ob=guardian.add_surface(col,name,source,fit,colors)
        mover=mover_for(name,ob,bone,area,None)
        if mover:
            moving.append(mover)
        art.bind(ob,rig,bone)
        components.append(ob)

    # Low iron references ride the slide and stay inside the stock envelope.
    components.append(author_panel(col,rig,"RB_Ghost_FrontSight",blueprint["Vandal_FrontSight"],
        lambda p:seat_point(p,((1.950,.956),(2.096,1.068)),((.20,.337),(.594,.438)),.63),colors,"Slide"))
    for sign in (-1,1):
        flank=art.prism(col,f"RB_Ghost_RearSight_{sign}",
            [(-.223,.377),(-.150,.374),(-.166,.433),(-.214,.440)],
            sign*.021,sign*.043,colors[FINISH+"Obsidian"],.004)
        art.bind(flank,rig,"Slide")
        components.append(flank)
    components.extend(add_hardware(col,rig,colors,((-.091,-.177),(.186,.229)),((.136,.112),(.191,.165)),
         ((.143,.194),(.257,.424),(.446,.702)),((.029,.001),(.121,.140),(.188,.203)),.91))
    return components,moving,mag_fit,slide_fit


def energy_sockets(gun, aim, mag_fit, body, joints):
    donors=json.loads((guardian.HERO.parent/"manifest_flat.json").read_text(encoding="utf-8"))["energy"]
    anchors=[]
    if gun=="Ghost":
        return [
          {"name":"RuinMistFore","bone":"Root","point":[1.390,.086,.305],"region":"Fore","mist":True,"phase":0},
          {"name":"RuinReceiverGlow","bone":"Slide","point":[.476,.075,.320],"region":"Receiver","mist":True,"phase":.85},
          {"name":"RuinMistHeel","bone":"Slide","point":[-.116,.058,.365],"region":"Stock","mist":True,"phase":2.35},
          {"name":"RuinMagGlow","bone":"Mag","point":list(mag_fit((.734,.052,-.331))),
           "region":"Mag","mist":True,"phase":1.65},
          {"name":"RuinApertureGlow","bone":"Slide","point":[-.157,0,.372],"region":"Sight","mist":False,"phase":3.15},
        ]
    aperture=gun!="Operator"
    for sample in donors:
        area=sample["region"]
        if area=="Sight" and not aperture:
            continue
        fit=mag_fit if area=="Mag" else (lambda p:rim_fit(aim,p)) if area=="Sight" else body
        anchors.append({**sample,"point":list(fit(sample["point"]))})
    if aperture:
        names={j["source"]:j["name"] for j in joints}
        for i,(start,end) in enumerate(guardian.SIGHT_CUTS,1):
            for label,angle in (("Start",start+.65),("End",end-.65)):
                theta=radians(angle)
                p=rim_fit(aim,(.065,.078*cos(theta),.5598+.078*sin(theta)))
                anchors.append({"name":"RuinSight"+label,"bone":names[f"RB_RearSight_Fragment_{i:02}"],
                                "point":list(p),"mist":False})
    else:
        anchors.extend((
          {"name":"RuinApertureGlow","bone":"Root","point":[-.059,0,aim.z-.119],
           "region":"Sight","mist":False,"phase":3.15},
          {"name":"RuinOpticObjective","bone":"Root","point":[1.38,0,aim.z-.13],
           "region":"Sight","mist":False,"phase":3.47},
        ))
    return anchors


def build(gun, blueprint):
    scene=art.read_scene(gun)
    art.setup(scene)
    rig=bpy.data.objects[gun+"_Rig"]
    rig.data.pose_position="REST"
    scene.view_layers[0].update()
    original=art.stock.meshes(gun)
    source_models={o.name.removeprefix(gun+"_"):o for o in original}
    source={k:guardian.sample_surface(o) for k,o in source_models.items()}
    aim=art.stock.locator(gun,"AimPoint")
    views=art.get_views(gun,art.points(original))
    folder=guardian.FILES/gun
    versions=[int(p.parent.name[1:]) for p in folder.glob("v*/manifest_flat.json")]
    dest=folder/f"v{max(versions,default=0)+1:02}"
    dest.mkdir(exist_ok=True)
    for view in ("side","held","aim"):
        if view in views:
            art.render(scene,views[view],dest/"review"/f"stock_{view}.png",1,(1120,630))

    col=art.collection(scene,f"Ruin-Blighted | {gun}")
    colors=guardian.material_bank(blueprint)
    if gun=="Ghost":
        components,moving,mag_fit,body=ghost_meshes(col,rig,blueprint,source,colors)
        barrel,dist="Suppressor",None
    else:
        profile=RIFLES[gun]
        components,moving,mag_fit,body=rifle_meshes(gun,profile,col,rig,blueprint,source,colors,aim)
        barrel,dist=profile.barrel,profile.ads
        if dist:
            eye=aim-Vector((dist,0,0))
            views["aim"]=art.stock.camera(gun,"ShadowMist_ADS",eye,aim,fov_v=profile.fov,clip=.1)
    if gun in {"Operator", "Ghost", "Spectre"}:
        components.append(charm_saddle(gun, col, rig, colors))
        charm = bpy.data.objects[f"{gun}_CharmPoint"].matrix_world.translation
        views["charm"] = art.camera(col, f"{gun} charm seat", charm + Vector((0, 0, .023)),
                                    (.19, .97, .15), scale=.40, distance=1.3)
    if gun == "Spectre":
        views["magwell"] = art.camera(col, "Spectre seated magazine", (.548, 0, .042),
                                      (.28, .94, -.16), scale=.48, distance=1.3)
    retained={"Trigger","CharmLoop","ScopeLens"}
    replaced=[]
    for name,o in source_models.items():
        if name not in retained:
            o.hide_render=True
            o.hide_set(True)
            replaced.append(name)
    scene.view_layers[0].update()
    checks=art.check_aim(scene,gun,components,views.get("aim"))
    joints=art.rig_shards(rig,moving)
    for j in joints:
        name=j["source"]
        if j["region"]=="Sight":
            j["phase"]=int(name.rsplit("_",1)[1])*.7854
        elif receiver:=guardian.receiver_shard(name):
            j["phase"]=receiver[2]+(.47 if name.endswith("_R") else 0)
            j["tilt"]=.048
            j["tether"]="UpperBrow" in name
        else:
            j["tether"]="Forehead" in name or "MainCleavedPlate" in name
    energy=energy_sockets(gun,aim,mag_fit,body,joints)
    for item in energy:
        socket=art.locator(col,item["name"],item["point"])
        art.bind(socket,rig,item["bone"])
    target=Vector((.396,0,.01)) if gun=="Ghost" else Vector((.155,0,-.009))
    views["trigger_grip"]=art.camera(col,f"{gun} Trigger Fit",target,(-.14,.96,.17),scale=1.04,distance=2)
    for name,camera in views.items():
        art.render(scene,camera,dest/"review"/f"{name}.png",1,(1120,630))
    scene.camera=views["hero"]
    scene.name=f"Ruin-Blighted {gun} | Shadow Mist"
    rig.data.pose_position="POSE"
    output=dest/f"{gun}_RuinBlighted_{dest.name}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    rig.data.pose_position="REST"
    scene.view_layers[0].update()
    parts,tris=guardian.finish_manifest(components,joints,colors,dest,replaced,energy,
                                        gun=gun,ads_distance=dist)
    checks.update(stock_source=f"{gun}_RemasterV2_v05.blend", barrel_fixture=barrel,
                  parts=parts,triangles=tris,receiver_shards=sum(j["region"]=="Receiver" for j in joints),
                  body_shards=sum(j["region"]!="Sight" for j in joints),
                  sight_segments=sum(j["region"]=="Sight" for j in joints))
    (dest/"review/checks.json").write_text(json.dumps(checks,indent=2)+"\n",encoding="utf-8")
    return str(output)
