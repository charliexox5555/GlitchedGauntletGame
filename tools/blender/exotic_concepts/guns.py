"""Stock-based cosmetic blockouts and stock-cued preview timelines."""

import math
import re

import bpy
from mathutils import Vector

from charms import build_charm, charm_pose
from designs import CHARMS, GUNS, HEROES, LINES
from scene import ART, ROOT, bind, camera, collection, cut, framed_camera, glove, material, marker, pivot, points, pose, prism


def source_for(gun):
    stock = ART / "RemasterV2" / gun / f"{gun}_RemasterV2_v05.blend"
    if gun == "Bulldog":
        return ART / "Skins/Shared Sources/Bulldog/BoltFix_v02/Bulldog_RemasterV2_v05_BoltFix_v02.blend"
    if gun == "Stinger":
        return ART / "Skins/Shared Sources/Stinger/HandguardFix_v01/Stinger_RemasterV2_v05_HandguardFix_v01.blend"
    return stock


def load_stock(gun):
    source = source_for(gun)
    with bpy.data.libraries.load(str(source)) as (src, dst):
        dst.scenes = [next(name for name in src.scenes if name.startswith(gun + "_RemasterV2_"))]
        dst.actions = [name for name in src.actions if name.startswith(gun + "_")]
    sc = dst.scenes[0]
    bpy.context.window.scene = sc
    for old in list(bpy.data.scenes):
        if old != sc:
            bpy.data.scenes.remove(old)
    rig = bpy.data.objects[gun+"_Rig"]
    rig.animation_data_create()
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for pb in rig.pose.bones:
        pb.matrix_basis.identity()
    for col in sc.collection.children:
        if col.name.endswith("ADSRange"):
            col.hide_render = True
    sc.frame_set(1)
    bpy.context.view_layer.update()
    return sc, rig, source


def timings(gun, clip="Reload"):
    cfg = (ROOT / "src/shared/Config/Weapons.luau").read_text(encoding="utf-8")
    start = cfg.index("\n\t" + gun + " = {")
    end = cfg.find("\n\t},", start)
    block = cfg[start:end]
    field = "emptyReloadTime" if clip == "ReloadEmpty" else "reloadTime"
    seconds = float(re.search(field + r"\s*=\s*([.\d]+)", block)[1])
    text = (ROOT / f"src/shared/WeaponAnimations/{gun}.luau").read_text(encoding="utf-8")
    chunks = re.findall(r"\n\t(\w+|\[\d+\]) = \{\n\t\tframes = (\d+),\n(?:\t\tmarkers = \{ ([^}]+) \},)?", text)
    data = {name: (int(frames), {k: float(v) for k,v in re.findall(r"(\w+) = ([.\d]+)", marks)})
            for name, frames, marks in chunks}
    return seconds, data


def stock_strip(rig, gun, clip, start, duration, cancel=None):
    action = bpy.data.actions.get(gun+"_"+clip)
    if action is None:
        return False
    strip_track = rig.animation_data.nla_tracks.new()
    strip_track.name = "Stock | " + clip + " @ " + str(start)
    strip = strip_track.strips.new(clip,start,action)
    strip.scale = duration / max(1, action.frame_range[1]-action.frame_range[0])
    strip.extrapolation = "NOTHING"
    if cancel:
        strip.frame_end = start + cancel
        strip.blend_out = min(5,cancel*.4)
    return True


def paint_stock(line, gun, palette):
    dark, pale, lit, accent, smoke = palette
    grip = material(line+" / Elastomer", "24262A", roughness=.8)
    iron = material(line+" / Protected hard surface", "353B44" if line == "Spindrift" else "353236", .4)
    meshes = [o for o in bpy.data.collections[gun].objects if o.type == "MESH"]
    keep = ("charmloop", "sight", "optic", "scope", "round", "shell", "speedloader", "feedbelt")
    for ob in meshes:
        part = ob.name.removeprefix(gun+"_").lower()
        if any(label in part for label in keep):
            continue
        for slot in ob.material_slots:
            if not slot.material:
                continue
            role = slot.material.name.split(".")[0].lower()
            if role in ("brass", "glass"):
                continue
            if "barrel" in part or "suppress" in part or "rail" in part:
                slot.material = iron
            elif "grip" in part or role in ("grip", "dark"):
                slot.material = grip
            elif role == "neon":
                slot.material = lit
            elif role in ("accent", "panel") and part not in ("receiver", "slide", "frame"):
                slot.material = pale if part in ("stock", "handguard", "ammoBox".lower(), "drum") else smoke
            elif role == "metal" or part in ("charginghandle", "bolt", "pin", "pins"):
                slot.material = iron
            else:
                slot.material = dark
        if line == "Spindrift" and part == "handguard" and gun == "Vandal":
            ob.data.materials.append(accent)
            for poly in ob.data.polygons:
                x = (ob.matrix_world @ poly.center).x
                if x > 1.614 and poly.area > .0003:
                    poly.material_index = len(ob.data.materials)-1
        if (gun,part) in (("Judge","mag"),("Ares","drum")):
            visible=[poly for poly in ob.data.polygons if poly.normal.y>.85 and .00012<poly.area<.0036]
            if visible:
                ob.data.materials.append(accent if gun=="Judge" else lit)
                mark=min(visible,key=lambda poly: abs(poly.center.z + .03))
                mark.material_index=len(ob.data.materials)-1
    return meshes


def side_fit(ob, x0,x1,z0,z1):
    inverse = ob.matrix_world.inverted()
    results = []
    # Probe the plate's footprint, including positions close to the angled corners.
    for u in (.08,.23,.42,.61,.8,.93):
        for v in (.15,.42,.7,.86):
            start = Vector((x0+(x1-x0)*u,2,z0+(z1-z0)*v))
            hit, p, _, _ = ob.ray_cast(inverse @ start,inverse.to_3x3() @ Vector((0,-1,0)))
            if hit:
                results.append((ob.matrix_world @ p).y)
    if not results:
        raise ValueError("No fixed exterior seat for " + ob.name)
    return min(results),max(results),len(results)


def face_trim(col,gun,part,outline,mat,side=1,thickness=.015):
    ob=bpy.data.objects[gun+"_"+part]
    x,z=zip(*outline)
    inv=ob.matrix_world.inverted()
    depths=[]
    # Sample corners, edge midpoints and center on the intended exterior only.
    samples=[*outline,*[((a+c)/2,(b+d)/2) for (a,b),(c,d) in zip(outline,outline[1:]+outline[:1])],
             (sum(x)/len(x),sum(z)/len(z))]
    for px,pz in samples:
        hit,p,_,_=ob.ray_cast(inv @ Vector((px,2*side,pz)),inv.to_3x3() @ Vector((0,-side,0)))
        if hit:
            depths.append((ob.matrix_world @ p).y*side)
    if len(depths)<len(samples)*.63:
        return None
    return prism(col,"Fitted "+part+" face "+str(side),outline,side*(min(depths)-.012),side*(max(depths)+thickness),mat,.004)


def treatment(col, rig, line, gun, palette):
    part, (x0,x1), (z0,z1), _ = GUNS[line,gun]
    panel = bpy.data.objects[gun+"_"+part]
    y_in,y_out,count = side_fit(panel,x0,x1,z0,z1)
    w,h = x1-x0,z1-z0
    dark,pale,lit,accent,smoke = palette
    fixed, controls = [], []
    def poly(name, shape, inner, outer, mat, bevel=.0025):
        return prism(col,name,[(x0+x*w,z0+z*h) for x,z in shape],y_out+inner,y_out+outer,mat,bevel)
    def panel_box(name,a,b,c,d,inner,outer,mat,bevel=.0025):
        outline = cut(x0+a*w,x0+b*w,z0+c*h,z0+d*h,min(.025,h*.2))
        return prism(col,name,outline,y_out+inner,y_out+outer,mat,bevel)
    inner=-.006 if gun=="Shorty" else min(-.014,y_in-y_out-.008)
    fixed.append(panel_box("Seated exterior cassette",0,1,0,1,inner,.013,smoke))
    fixed.append(panel_box("Recess liner",.12,.88,.18,.82,.012,.022,dark))
    if line == "Spindrift":
        folds = [[(.01,.12),(.105,.015),(.254,.19),(.22,.41),(.13,.59),(.23,.95),(.14,.99),(.036,.72)],
                 [(.99,.82),(.925,.99),(.743,.87),(.78,.63),(.88,.47),(.78,.11),(.867,.018),(.967,.26)]]
        fixed.extend(poly("Pearl fold "+str(i+1), shape,.006,.036,pale) for i,shape in enumerate(folds))
        if gun == "Vandal":
            shoulder = [(1.056,.337),(1.105,.322),(1.41,.346),(1.566,.38),
                        (1.516,.396),(1.159,.38),(1.089,.375)]
            inner,outer,_=side_fit(bpy.data.objects[gun+"_Handguard"],1.085,1.56,.34,.381)
            fixed.append(prism(col,"Outboard pearl shoulder",shoulder,inner-.010,outer+.017,pale,.004))
        if gun == "Ghost":
            leaves = [("Single shutter",.19,.81,.33,.73,1)]
        else:
            leaves = [("Tide leaf upper",.19,.83,.51,.80,1),("Tide leaf lower",.17,.81,.20,.47,-1)]
        for name,a,b,c,d,side in leaves:
            leaf = poly(name,[(a,c+.04),(b-.065,c),(b,d-.055),(b-.031,d),(a+.07,d)],.029,.044,pale)
            controls.append((pivot(col,name+" pivot",(x0+.50*w,y_out+.033,z0+(d if side>0 else c)*h),[leaf],rig,"Root"),"leaf",side))
        for i in range(11):
            a=.205+i*.053
            z=.505+.105*math.sin(2*math.pi*i/10)
            z1p=.505+.105*math.sin(2*math.pi*(i+1)/10)
            shard = poly("Ribbon facet %02d" % i,[(a,z-.041),(a+.058,z1p-.035),(a+.06,z1p+.038),(a,z+.04)],.029,.039,lit,.001)
            controls.append((pivot(col,"Ribbon cue %02d" % i,(x0+(a+.03)*w,y_out+.036,z0+z*h),[shard],rig,"Root"),"ribbon",i))
        if gun=="Guardian":
            bead=poly("Held sea-glass bead",[(.275,.51),(.298,.42),(.33,.51),(.298,.63)],.039,.048,lit,.001)
            controls.append((pivot(col,"Bead travel",(x0+.298*w,y_out+.042,z0+.51*h),[bead],rig,"Root"),"bead",w))
    elif line == "Kilnlock":
        for a,b in ((.02,.18),(.82,.98)):
            fixed.append(panel_box("Ceramic cage shoulder",a,b,.0,1,.007,.041,pale))
        fixed.extend([panel_box("Upper copper rail",.13,.87,.84,1,.010,.038,accent),
                      panel_box("Lower copper rail",.13,.87,0,.16,.010,.039,accent)])
        heat = panel_box("Heat index bar",.375,.625,.33,.67,.022,.037,lit)
        controls.append((pivot(col,"Heat index",(x0+.5*w,y_out+.036,z0+.5*h),[heat],rig,"Root"),"heat",w))
        jaws = [("Ceramic hatch",.15,.85,.21,.80,1)] if gun in ("Shorty","Sheriff","Bulldog") else [
            ("Kiln jaw upper",.16,.84,.51,.81,1),("Kiln jaw lower",.16,.84,.19,.48,-1)]
        for name,a,b,c,d,side in jaws:
            jaw = panel_box(name,a,b,c,d,.035,.052,pale)
            trim = panel_box(name+" iron inlay",a+.06,b-.06,c+.037,d-.037,.05,.057,smoke,.001)
            controls.append((pivot(col,name+" hinge",(x0+.5*w,y_out+.038,z0+(d if side>0 else c)*h),[jaw,trim],rig,"Root"),"jaw",side))
        trims={
            "Odin": [ ("Receiver",[(1.426,.418),(1.504,.346),(1.86,.35),(2.013,.401),(2.041,.479),(1.919,.493),(1.494,.489)],1),
                      ("Receiver",[(.293,.429),(.334,.401),(.682,.404),(.758,.44),(.704,.474),(.342,.47)],-1),
                      ("Stock",[(-1.144,.352),(-.63,.355),(-.408,.431),(-.446,.462),(-1.132,.455)],1)],
            "Phantom": [("Handguard",[(1.018,.321),(1.088,.284),(1.469,.309),(1.569,.352),(1.54,.394),(1.083,.389)],1)],
            "Judge": [("Receiver",[(.265,.477),(.379,.455),(.889,.482),(1.05,.529),(.983,.562),(.326,.558)],1)],
        }.get(gun,[])
        fixed.extend(ob for part,outline,side in trims if (ob:=face_trim(col,gun,part,outline,pale,side)))
    else:
        for a,b in ((.014,.153),(.847,.986)):
            fixed.append(panel_box("Molded window edge",a,b,0,1,.008,.045,pale))
        acrylic=material("Stacklight / Smoked acrylic",LINES[line][-1],.18,.26,.83)
        fixed.append(panel_box("Smoked window",.15,.85,.36,.88,.016,.035,acrylic))
        fixed.append(panel_box("Shuttle track",.145,.855,.08,.33,.019,.027,dark))
        cells = 2 if gun == "Classic" else 3
        for i in range(cells):
            a=.23+i*.56/cells
            fixed.append(panel_box("Recessed indicator socket",a,a+.135,.44,.79,.030,.038,dark,.001))
            cell = panel_box("Indicator cell %d" % (i+1),a+.017,a+.118,.49,.75,.037,.043,lit,.001)
            controls.append((pivot(col,"Sweep %d" % (i+1),(x0+(a+.067)*w,y_out+.042,z0+.62*h),[cell],rig,"Root"),"light",i))
        shuttle_mat=material("Stacklight / Frosted shuttle","A3C5CA",.08,.24,.74)
        shuttle = panel_box("Smoked-clear shuttle",.66,.839,.115,.295,.025,.038,shuttle_mat,.001)
        controls.append((pivot(col,"Shuttle travel",(x0+.75*w,y_out+.032,z0+.2*h),[shuttle],rig,"Root"),"shuttle",w))
        trims={
            "Phantom": [("Handguard",[(.991,.329),(1.072,.311),(1.365,.327),(1.541,.367),(1.531,.405),(1.072,.396)],1),
                        ("Stock",[(-1.016,.254),(-.972,.221),(-.609,.235),(-.46,.311),(-.526,.34),(-.983,.335)],1),
                        ("Handguard",[(1.002,.316),(1.1,.306),(1.45,.323),(1.552,.366),(1.533,.398),(1.083,.389)],-1)],
            "Ares": [("Receiver",[(1.027,.362),(1.164,.334),(1.53,.356),(1.739,.402),(1.703,.46),(1.154,.462)],1)],
        }.get(gun,[])
        fixed.extend(ob for part,outline,side in trims if (ob:=face_trim(col,gun,part,outline,pale,side)))
    for ob in fixed:
        bind(ob,rig,"Root")
    return controls, (x0+(x1-x0)/2,y_out,z0+(z1-z0)/2), w, {"seat_rays_hit":count,"seat_rays_total":24,"side_depth_variation":round(y_out-y_in,4)}


def cue(controls, frame, amount, sweep=1, beat="full"):
    for ob,control,value in controls:
        if "home" not in ob:
            ob["home"] = tuple(ob.location)
        x,y,z = ob["home"]
        if control in ("leaf","jaw"):
            opening=.24 if beat in ("ripple","bead") else 1
            pose(ob,frame,angles=(value*amount*opening*(68 if control=="jaw" else 58),0,0))
        elif control == "ribbon":
            if beat=="bead":
                strength=0
            elif beat=="ripple":
                strength=amount*max(0,1-abs(sweep*10-value)*.28)
            else:
                strength=amount*min(1,max(0,(sweep*13-value)*.8))
            pose(ob,frame,scale=(max(.001,strength),)*3)
        elif control=="bead":
            strength=max(.001,amount) if beat=="bead" else .001
            progress=sweep if beat=="bead" and amount>0 else 0
            pose(ob,frame,xyz=(x+value*.51*progress,y,z+math.sin(progress*math.tau)*.008),scale=(strength,)*3)
        elif control == "heat":
            pose(ob,frame,xyz=(x+value*.14*(sweep-.5)*amount,y+.008*amount,z))
        elif control == "light":
            strength = max(.08, min(1, .38 - amount*.18 + amount*max(0,1-abs(value+1-sweep*3.6))))
            if beat=="single":
                strength=.38+.55*amount
            pose(ob,frame,scale=(strength,)*3)
        elif control == "shuttle":
            pose(ob,frame,xyz=(x-value*.42*amount,y,z))


def gun_design(line, gun):
    scene,rig,source=load_stock(gun)
    new=collection(scene,"EXOTIC | Fixed skin and independent controls")
    cams=collection(scene,"EXOTIC | Matched review cameras")
    charm_col=collection(scene,"EXOTIC | Mounted charm")
    dark,pale,lit,accent,smoke=LINES[line]
    palette=[material(line+" / "+label,c,m,r,emission=e) for label,c,m,r,e in zip(
        ("Shell","Face plates","Active insert","Accent","Smoked seat"),(dark,pale,lit,accent,smoke),
        (.25,.45,.11,.48,.27),(.56,.4,.26,.42,.37),(0,0,.35,0,0))]
    stock=paint_stock(line,gun,palette)
    controls, target, width, fit=treatment(new,rig,line,gun,palette)
    _,charm_name=next(pair for pair in CHARMS if pair[0]==line)
    charm_point=bpy.data.objects.get(gun+"_CharmPoint")
    charm=None
    if charm_point:
        charm=build_charm(charm_col,line,charm_name,palette,tuple(charm_point.matrix_world.translation),rig,charm_point.parent_bone)
        if (line,gun) not in HEROES:
            # Compact variants use the same finish and mount eyelet center.
            scale=.75 if gun in ("Ghost","Classic","Shorty","Sheriff","Bucky","Judge") else .88
            if gun=="Judge":
                scale=.66
            charm[0].scale=(scale,)*3
            if gun=="Judge":
                charm[0]["outboard_cant"]=26
    coords=points([*stock,*new.objects,*charm_col.objects])
    views={
        "hero":framed_camera(cams,"Beauty | left three-quarter",coords,(.44,1,.24),2.1,1.12),
        "side":framed_camera(cams,"Stock match | left",coords,(0,1,0),2.3,1.11),
        "right":framed_camera(cams,"Join check | right underside",coords,(-.19,-1,-.3),2.15,1.13),
        "detail":camera(cams,"Cassette | active",target,(-.28,1,.24),scale=width*1.42),
    }
    bind(views["detail"],rig,"Root")
    from final_pass import ADS, ads_cam, hip_cam
    views["held"]=hip_cam(gun)
    views["aim"]=ads_cam(gun) if gun in ADS else bpy.data.objects.get(gun+"_Cam_Top")
    if not views["aim"]:
        views["aim"]=framed_camera(cams,"Stock sight protection | overhead",coords,(0,0,1),1.8,1.1)
    if charm:
        origin=charm_point.matrix_world.translation
        views["icon"]=framed_camera(cams,"Charm | reward icon",points(charm_col.objects),(.2,1,.14),1,1.2)
        views["mount"]=camera(cams,"Charm | outboard mount and swing",origin+Vector((0,0,-.04)),(-.12,1,.13),scale=.6)
    return scene,rig,source,views,controls,charm,palette,fit


def hands_for(scene, rig, line,gun,motion):
    proxies=collection(scene,"EXOTIC | First-person hand pose proxies")
    left=bpy.data.objects[gun+"_LeftGrip"].matrix_world.translation.copy()
    right=bpy.data.objects[gun+"_RightGrip"].matrix_world.translation.copy()
    origin=left + Vector((-.016,0,-.058))
    support=pivot(proxies,"Support-hand pose",origin,glove(proxies,"Support glove",origin,True,
                  (left.x-.8,.32,left.z-.64),1.05),rig,"Root")
    origin_r=right + Vector((.021,0,-.101))
    pivot(proxies,"Strong-hand pose",origin_r,glove(proxies,"Strong glove",origin_r,False,
          (right.x-.62,.12,right.z-.39),1.02),rig,"Root")
    mag=next((o for o in bpy.data.collections[gun].objects if o.type=="MESH" and o.parent_bone=="Mag"),None)
    if mag:
        center=(Vector(mag.bound_box[0])+Vector(mag.bound_box[6]))/2
        center=mag.matrix_world @ center
        delta=center-origin + Vector((.04,.022,-.05))
        peak=motion["commit"]
        release=motion["start"]+max(2,round((peak-motion["start"])*.29))
        # The proxy sets up the user's requested hand story. Stock animation still drives the gun.
        for frame,weight,turn in ((1,0,0),(motion["start"],0,0),(release,.37,-15),
                                  (peak,1,-26),(peak+5,.72,-14),(motion["ready"]-3,0,0),
                                  (motion["inspect"]-11,.10,17),(motion["inspect"]+8,0,0)):
            pose(support,frame,xyz=origin+delta*weight,angles=(turn,-turn*.4,0))
    return proxies


def gun_motion(scene, rig, line,gun,controls,charm):
    seconds,clips=timings(gun)
    start=9
    steps=[]
    if "ReloadStart" in clips and "ReloadInsert" in clips:
        cursor=start
        for clip in ("ReloadStart","ReloadInsert","ReloadInsert","ReloadEnd"):
            frames, marks=clips[clip]
            duration=frames-1
            stock_strip(rig,gun,clip,cursor,duration)
            if clip=="ReloadInsert":
                steps.append(cursor+round((marks.get("Insert",marks.get("ShellIn",1)))*duration))
            cursor+=duration
        ready=cursor
        commit=steps[0]
    else:
        frames,marks=clips.get("Reload",clips.get("ReloadEmpty",(60,{})))
        dur=round(seconds*24)
        stock_strip(rig,gun,"Reload" if "Reload" in clips else "ReloadEmpty",start,dur)
        source_phase={"Shorty":(52-1)/(72-1),"Sheriff":(49-1)/(110-1)}.get(gun,.52)
        commit=start+round(dur*marks.get("MagIn",marks.get("Close",source_phase)))
        ready=start+dur
    opened=min(start+8,commit-2)
    peak=min(commit+4,ready-5)
    frames=[(1,0,0),(start,0,0),(opened,.88 if line!="Kilnlock" else .15,.18),
            (commit,1,.62),(peak,1,1),(max(peak+1,ready-7),.25,1),(ready,0,0)]
    if steps:
        peak=commit
        frames=[(1,0,0),(start,0,0)]
        for f in steps:
            frames.extend([(f-3,.1,0),(f,.72,1),(f+5,0,0)])
        frames.append((ready,0,0))
    if gun=="Outlaw":
        opened=start+round(dur*marks["Open"])
        frames=[(1,0,0),(start,0,0),(opened-2,0,0),(opened,.84,.65),(opened+5,0,0),
                (commit-2,0,0),(commit,1,1),(ready,0,0)]
        marker(scene,"STOCK OPEN / FIRST PULSE",opened)
    if gun=="Ghost":
        peak=ready-9
        frames=[(1,0,0),(start,0,0),(commit,0,0),(peak-5,.53,.3),(peak,.78,1),(ready,0,0)]
        marker(scene,"RECOVERY WATER WIPE",peak)
    if gun=="Classic":
        frames=[(1,0,0),(start,0,0),(commit-2,0,0),(commit,.92,1),(commit+5,0,0),(ready,0,0)]
    if gun=="Shorty":
        frames=[(1,0,0),(start,0,0),(commit-3,.08,0),(commit,1,1),(commit+5,0,0),(ready,0,0)]
        peak=commit
    beat={"Marshal":"ripple","Bucky":"ripple","Guardian":"bead","Classic":"single"}.get(gun,"full")
    for f,value,sweep in frames:
        cue(controls,f,value,sweep,beat)
        if charm:
            charm_pose(charm,f,value,8*value*math.cos(f*.45))
    for label,f in (("REST",1),("RELOAD START",start),("STOCK COMMIT",commit),("READY",ready)):
        marker(scene,label,f)
    for i,f in enumerate(steps[1:],2):
        marker(scene,"STOCK COMMIT "+str(i),f)
    inspect=ready+9
    stock_strip(rig,gun,"Inspect",inspect,44)
    for off,val,sweep in ((0,0,0),(12,1,.4),(25,1,1),(44,0,0)):
        cue(controls,inspect+off,val,sweep)
        if charm:
            charm_pose(charm,inspect+off,val,(-1 if off==12 else 1)*val*9)
    marker(scene,"INSPECT",inspect)
    cancel=inspect+50
    clip="Reload" if "Reload" in clips else "ReloadStart"
    stock_strip(rig,gun,clip,cancel,round(seconds*24),cancel=15)
    for off,val in ((0,0),(9,.86),(11,.76),(17,0),(24,0)):
        cue(controls,cancel+off,val,.55)
        if charm:
            charm_pose(charm,cancel+off,val,-6*val)
    marker(scene,"INTERRUPT",cancel+11)
    marker(scene,"CANCEL REST",cancel+17)
    extrema=[]
    if charm:
        for off,val,swing in [(24,0,0),(32,1,15),(41,1,-15),(49,0,0)]:
            charm_pose(charm,cancel+off,val,swing)
        extrema=[cancel+32,cancel+41]
        marker(scene,"CHARM SWING / +15°",extrema[0])
        marker(scene,"CHARM SWING / -15°",extrema[1])
        marker(scene,"CHARM REST",cancel+49)
    regression=[]
    if gun in ("Bucky","Bulldog","Stinger"):
        fire=cancel+24
        duration=clips["Fire"][0]-1
        stock_strip(rig,gun,"Fire",fire,duration)
        regression=list(range(fire,fire+duration+1))
        marker(scene,"STOCK ACTION TRAVEL AUDIT",fire)
    if gun=="Shorty":
        empty=cancel+(54 if charm else 24)
        empty_seconds,_=timings(gun,"ReloadEmpty")
        duration=round(empty_seconds*24)
        stock_strip(rig,gun,"ReloadEmpty",empty,duration)
        regression=list(range(empty,empty+duration+1))
        close=empty+round((65/85)*duration)
        marker(scene,"EMPTY RELOAD / SECOND STOCK SHELL",empty+round((55/85)*duration))
        marker(scene,"EMPTY RELOAD / CLOSE",close)
        for f,value in ((empty,0),(close-3,0),(close,1),(close+5,0),(empty+duration,0)):
            cue(controls,f,value,1)
    scene.frame_start,scene.frame_end=1,regression[-1]+1 if regression else cancel+(49 if charm else 24)
    return {"start":start,"open":opened,"commit":commit,"ready":ready,"peak":peak,
            "inspect":inspect+25,"cancel":cancel+17,"steps":steps,"regression":regression,
            "game_reload_seconds":seconds,"charm_extremes":extrema,
            **({"empty_ready":empty+duration,"empty_close":close,"empty_second":empty+round((55/85)*duration)} if gun=="Shorty" else {})}
