"""Author the offline action board in the live Storm Shadow scene."""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


def author(api, version="v09"):
    scene=api["SCENE"]
    bpy.context.window.scene=scene
    mesh,loft,tube,hull,mat=map(api.__getitem__,("mesh","loft","tube","hull","material"))
    rig, root, balance, body, mag, charge, bolt=map(api.__getitem__,
        ("RIG","ACTION","BALANCE","BODY_CTRL","MAG_CTRL","CHARGE","BOLT"))
    stage,mag_group=map(api.__getitem__,("STAGE","MAG"))
    empty,camera=map(api.__getitem__,("empty","camera"))
    shell=api["collection"]("11 • Action animatic and hand proxies")
    glove=mat("Proxy · glove", "303C49", .05, .59)
    joint=mat("Proxy · knuckle", "536571", .12, .53)
    pad=mat("Proxy · cuff", "253541", .11, .55)
    rad=math.radians
    zero=(0,0,0)
    rest_mag=mag.location.copy()
    rest_balance=balance.location.copy()
    rest_charge=charge.location.copy()
    rest_bolt=bolt.location.copy()
    rest_right=Vector((0,.098,0))
    rest_left=Vector((1.32,.035,.093))

    def box(name, parent, position, dim, material, edge=.008):
        x,y,z=map(lambda d:d/2,dim)
        verts=[Vector(position)+Vector((a*x,b*y,c*z))
               for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                             (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        return mesh(name,verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],
                    [material],shell,parent,edge)

    fingers={}
    def hand(label):
        ctrl=empty("Hand_"+label,(0,0,0))
        box("Hand_"+label+"_Palm",ctrl,(-.021,.008,-.032),(.165,.071,.153),glove,.015)
        box("Hand_"+label+"_Dorsal",ctrl,(-.027,.047,-.041),(.133,.011,.108),joint,.007)
        root_joints=[]
        for i in range(4):
            x=.055 if i!=0 else .067
            z=.047-i*.038
            pivot=empty(f"Hand_{label}_Finger{i+1}", (x,.003,z),ctrl)
            box(f"Hand_{label}_Digit{i+1}",pivot,(x+.025,-.003,z),(.074,.035,.027),glove,.006)
            last=empty(f"Hand_{label}_FingerTip{i+1}",(x+.05,-.003,z),pivot)
            box(f"Hand_{label}_Tip{i+1}",last,(x+.065,-.011,z),(.045,.032,.022),joint,.005)
            root_joints.append((pivot,last))
        thumb=empty(f"Hand_{label}_Thumb",(-.077,-.003,.027),ctrl)
        box(f"Hand_{label}_ThumbPad",thumb,(-.072,-.03,.047),(.042,.070,.04),glove,.009)
        box(f"Hand_{label}_Wrist",ctrl,(-.09,.011,-.121),(.102,.088,.081),pad,.01)
        fingers[ctrl]=(root_joints,thumb)
        return ctrl
    right,left=hand("Right"),hand("Left")

    arm_ends={"Right":Vector((-.86,1.65,-2.48)),"Left":Vector((1.21,1.59,-2.43))}
    arms={}
    for label in arm_ends:
        rings=[[(x,y,z) for x,y in api["octagon"](w,h,.25)]
               for z,w,h in [(-.5,.149,.104),(-.24,.12,.09),(.19,.086,.068),
                             (.40,.065,.049),(.5,.056,.038)]]
        arms[label]=loft("Arm_"+label,rings,[pad,joint],shell,parent=None,
                         stripe=lambda edge,row:int(row==3 and edge in {4,5,6}))

    ghost=empty("GhostMag_Outgoing",(0,0,0))
    scene.frame_set(1)
    bpy.context.view_layer.update()
    for src in mag_group.objects:
        copy=src.copy()
        copy.name="GhostMag_"+src.name
        copy.data=src.data
        shell.objects.link(copy)
        copy.parent=ghost
        copy.matrix_basis=src.matrix_basis.copy()

    slides=sorted([o for o in rig.objects if o.name.startswith("CTRL_Plate")],key=lambda obj:obj.name)
    slide_origins=[o.location.copy() for o in slides]
    frames={
        "Ready": 1, "Draw": 9, "DrawSweep": 11, "DrawCatch": 20, "PlateLock": 23,
        "DrawReady": 24, "Idle": 39, "Fire": 65, "TacReload": 83, "TacMagRelease": 94,
        "TacWaterGather": 99, "TacMagForm": 108, "TacMagGlide": 115, "TacMagSeat": 130,
        "TacRack": 143, "TacAmmoCommit": 158, "EmptyReload": 175, "EmptyMagRelease": 187,
        "EmptyWaterGather": 193, "EmptyMagForm": 205, "EmptyMagGlide": 213, "EmptyMagSeat": 229,
        "EmptyChamber": 242, "EmptyAmmoCommit": 259, "Inspect": 275, "InspectRelease": 290,
        "InspectOrbit": 302, "InspectHalfTurn": 338, "InspectEndTurn": 374,
        "InspectCatch": 394, "InspectReady": 410, "InterruptDemo": 429, "Cancel": 459,
        "CancelledADS": 468, "CancelledFire": 471, "End": 480,
    }
    scene.frame_end=frames["End"]
    for key,value in frames.items():
        scene.timeline_markers.new(key,frame=value)

    def transform(obj, frame, loc, rot=zero, scale=1):
        obj.location=loc
        obj.rotation_mode="XYZ"
        obj.rotation_euler=rot
        obj.scale=(scale,)*3 if isinstance(scale,(float,int)) else scale
        obj.keyframe_insert(data_path="location",frame=frame,group="Placement")
        obj.keyframe_insert(data_path="rotation_euler",frame=frame,group="Placement")
        obj.keyframe_insert(data_path="scale",frame=frame,group="Reveal")

    def smooth(t):
        t=max(0,min(1,t))
        return t*t*(3-2*t)

    def span(t,a,b):
        return smooth((t-a)/(b-a))

    def bend(t,keyframes):
        if t<keyframes[0][0]:
            return Vector(keyframes[0][1])
        for (a,p),(b,q) in zip(keyframes,keyframes[1:]):
            if a<=t<=b:
                return Vector(p).lerp(Vector(q),span(t,a,b))
        return Vector(keyframes[-1][1])

    def pulse(t, start, crest, end):
        return span(t,start,crest)*(1-span(t,crest,end))

    review_cam=camera("Motion_ActionBoard",(.36,6.6,2.25),(.55,0,-.05),5.8)
    inspect_cam=camera("Motion_InspectBoard",(.33,6.7,2.15),(.65,0,.31),5.45)
    draw_cam=camera("Motion_DrawBoard",(.35,7,1.87),(.49,0,-.52),5.8)
    ads=stage.objects["TS_Vandal_Cam_ADS"]
    for f,cam in [(1,review_cam),(9,draw_cam),(39,review_cam),(275,inspect_cam),(429,review_cam),(468,ads)]:
        marker=scene.timeline_markers.new(cam.name,frame=f)
        marker.camera=cam

    def pose_hand(ctrl, label, frame, point, angle, curl, visible):
        transform(ctrl,frame,point,angle,visible)
        joints, thumb=fingers[ctrl]
        for i,(base,tip) in enumerate(joints):
            value=curl[i] if isinstance(curl,tuple) else curl
            base.rotation_euler.z=rad(-67*value)
            tip.rotation_euler.z=rad(-70*value)
            base.keyframe_insert(data_path="rotation_euler",frame=frame,group="Curl")
            tip.keyframe_insert(data_path="rotation_euler",frame=frame,group="Curl")
        thumb.rotation_euler.x=rad(12)+(rad(32)*max(curl) if isinstance(curl,tuple) else rad(32)*curl)
        thumb.keyframe_insert(data_path="rotation_euler",frame=frame,group="Curl")
        cuff=point+Vector((-.086,0,-.135))
        elbow=arm_ends[label]
        delta=cuff-elbow
        angle=delta.to_track_quat("Z","Y").to_euler()
        transform(arms[label],frame,elbow.lerp(cuff,.50),angle,(visible,visible,delta.length*visible))

    def at(obj, local=zero):
        return obj.matrix_world @ Vector(local)

    def fx(obj,f,where=zero,angle=zero,weight=0):
        transform(obj,f,where,angle,max(weight,.0001))

    checks={"frames":frames,"fps":scene.render.fps,
            "timing":{"draw_ready_seconds":.5,"tactical_seconds":2.5,"empty_seconds":2.8,
                      "stock_clip_out_fraction":.1458,"stock_clip_in_fraction":.3021,
                      "remapped_seat_tactical_seconds":47/30,"remapped_seat_empty_seconds":54/30},
            "samples":[]}
    for f in range(1,scene.frame_end+1):
        draw=f>=9 and f<39
        tac=83<=f<=158
        depleted=175<=f<=259
        inspect=275<=f<=410
        cancelled=429<=f<=471
        in_reload=tac or depleted
        start=175 if depleted else 83
        out,gather_at,form,glide,seat,rack,end=([187,193,205,213,229,242,259] if depleted
                                               else [94,99,108,115,130,143,158])
        root_loc=Vector(zero)
        root_r=Vector(zero)
        lift=0
        azimuth=0
        right_drop=0
        left_drop=0
        right_curl=(.22,.96,.96,.94)
        left_curl=(.62,.71,.78,.75)
        pull=Vector(zero)
        mag_rot=Vector(zero)
        mag_scale=1
        charge_travel=0
        fire=pulse(f,64,65,69) + pulse(f,470,471,475)
        if draw:
            root_loc=bend(f,[(9,(0,.14,-.38)),(14,(-.02,.02,-.24)),(20,(.016,0,.07)),(24,zero)])
            root_r=bend(f,[(9,(.35,.79,-.19)),(14,(-.26,.43,.10)),
                            (20,(.09,-.15,-.03)),(24,zero)])
            right_drop=(1-span(f,9,20))*.29
            left_drop=(1-span(f,20,31))*.51
            close=span(f,15,20)
            right_curl=(.10,close,close,close)
        if in_reload:
            root_r=bend(f,[(start,zero),(start+5,(.11,.064,.028)),(out-2,(-.28,-.25,.085)),
                           (out+5,(-.22,-.20,.018)),(glide,(-.25,-.16,.022)),
                           (seat-3,(-.32,-.124,.039)),(seat,(-.30,-.22,.03)),
                           (seat+6,(-.21,-.16,.015)),(rack,(-.13,-.12,.02)),(end,zero)])
            root_loc=bend(f,[(start,zero),(out,(.04,-.04,.19)),(glide,(.013,-.04,.2)),
                             (seat,(-.019,-.024,.245)),(rack,(.04,0,.116)),(end,zero)])
            # Form a recognizable magazine at the palm, then align below the rails
            # before the final straight translation into the feed seat.
            if f>=out:
                pull=bend(f,[(out,zero),(form,(-.12,.32,-.59)),
                             (glide,(-.10,.246,-.54)),(seat-7,(-.025,.051,-.307)),
                             (seat-3,(0,0,-.125)),(seat,zero)])
                mag_rot=bend(f,[(out,zero),(form,(.28,-.22,.11)),(glide,(.19,-.14,.07)),
                                (seat-6,(.04,-.018,0)),(seat-3,zero),(seat,zero)])
                mag_scale=1 if f>=form else .0001
            charge_travel=-(.078 if depleted else .041)*pulse(f,rack-3,rack,rack+5)
        if inspect:
            lift=.43*pulse(f,284,305,401)
            if 302<=f<=374:
                u=(f-302)/72
                azimuth=math.tau*(u-math.sin(math.tau*u)/math.tau*.73)
            if f>374:
                azimuth=math.tau
            root_r=bend(f,[(275,zero),(285,(-.14,-.08,-.05)),(300,(.10,-.06,0)),
                           (324,(.08,.03,0)),(365,(-.06,-.07,0)),
                           (388,(-.09,-.05,0)),(394,(.064,.048,-.016)),(410,zero)])
            right_drop=span(f,285,299)*(1-span(f,377,394))*.60
            left_drop=span(f,283,302)*(1-span(f,391,410))*.62
            grip=1-span(f,286,299)*(1-span(f,381,394))
            right_curl=(.17,grip,grip,grip)
        if cancelled:
            lift=.32*pulse(f,439,459,468)
            azimuth=.97*pulse(f,445,459,468)
            right_drop=.55*pulse(f,440,459,468)
            left_drop=.49*pulse(f,437,458,468)
            curl=1-pulse(f,439,452,468)
            right_curl=(.14,curl,curl,curl)
        if fire:
            root_r.y-=.07*fire
            root_loc.x-=.058*fire
            charge_travel-=.035*fire
        transform(root,f,root_loc,root_r)
        transform(balance,f,rest_balance+Vector((0,0,lift)),(0,0,azimuth))
        transform(mag,f,rest_mag+pull,mag_rot,mag_scale)
        transform(charge,f,rest_charge+Vector((charge_travel,0,0)))
        transform(bolt,f,rest_bolt+Vector((charge_travel,0,0)))
        for i,slide in enumerate(slides):
            lock=(17 if "Fore" in slide.name else 23)+(0 if "Player" in slide.name else -1)
            x=(slide["travel_x"]*(1-span(f,lock-5,lock)) if draw else 0)-.012*fire
            transform(slide,f,slide_origins[i]+Vector((x,0,0)))
        bpy.context.view_layer.update()

        ww=at(body,rest_right)
        lw=at(body,rest_left)
        right_angle=body.matrix_world.to_quaternion().to_euler()
        left_angle=body.matrix_world.to_quaternion().to_euler()
        if inspect or cancelled:
            # Once released, keep both palms in camera space while the rifle spins.
            ww=ww.lerp(rest_right+Vector((-.08,.23,-right_drop)), min(1,right_drop/.27))
            lw=lw.lerp(rest_left+Vector((.015,.25,-left_drop)), min(1,left_drop/.34))
            right_angle=Vector(right_angle).lerp(Vector((1.23,0,.12)),min(1,right_drop/.28))
            left_angle=Vector(left_angle).lerp(Vector((1.42,.15,-.15)),min(1,left_drop/.34))
        else:
            ww+=Vector((-.08*right_drop,.39*right_drop,-right_drop))
            lw+=Vector((0,.31*left_drop,-left_drop))
        if in_reload:
            mag_palm=at(body,rest_mag+pull+Vector((.102,.081,-.50)))
            catch_old=at(body,rest_mag+Vector((.125,.077,-.31)))
            emerge=span(f,out,gather_at)
            open_amount=span(f,out-1,gather_at+1)*(1-span(f,seat-4,seat+3))
            hand_weight=span(f,start+1,out-2)*(1-span(f,seat+2,end-2))
            target=catch_old.lerp(mag_palm,emerge)
            if f>seat+2:
                target=target.lerp(at(body,(.63,.211,.10)),pulse(f,seat+2,rack,rack+8))
            lw=lw.lerp(target,hand_weight)
            left_angle=Vector(left_angle).lerp(Vector((1.38,.12,-.27)),open_amount)
            close=1-open_amount
            left_curl=(.73*close,.87*close,.89*close,.82*close)
        hand_visibility=.0001 if f<9 or f>=468 else 1
        pose_hand(right,"Right",f,ww,right_angle,right_curl,hand_visibility)
        pose_hand(left,"Left",f,lw,left_angle,left_curl,hand_visibility)
        if in_reload and out <= f < out+15:
            phase=min(1,(f-out)/15)
            ghostpos=at(body,rest_mag+Vector((.125*phase,.16*phase,-.18*phase-1.4*phase*phase)))
            fx(ghost,f,ghostpos,(.18*phase,.39*phase,0),1)
        else:
            fx(ghost,f)
        if f in set(frames.values()):
            checks["samples"].append({"frame":f,"right_proxy":list(ww),"left_proxy":list(lw),
                "right_target":list(at(body,rest_right)),
                "right_target_residual":(at(body,rest_right)-ww).length,
                "mag_translation":list(pull),"mag_scale":mag_scale,"inspect_yaw_deg":math.degrees(azimuth)})

    for obj in [*scene.objects]:
        anim=obj.animation_data
        if obj.type=="ARMATURE" or not anim or not anim.action or not anim.action_slot:
            continue
        action=anim.action
        action.name="Storm Shadow — "+obj.name
        for layer in action.layers:
            for strip in layer.strips:
                bag=strip.channelbag(anim.action_slot)
                if bag:
                    for curve in bag.fcurves:
                        for point in curve.keyframe_points:
                            point.interpolation="LINEAR"
    scene.frame_set(1)
    scene.camera=review_cam
    scene["motion_notes"]="Mechanical rail, reload and catch rehearsal. Effects are represented only by deferred cue markers."
    folder=api["DEST"]/version/"review"
    folder.mkdir(parents=True,exist_ok=True)
    (folder/"action_timeline.json").write_text(json.dumps(checks,indent=2),encoding="utf-8")
    api["save"](version)


if __name__=="__main__":
    raise SystemExit("Call author(api) after the Storm Shadow build.")
