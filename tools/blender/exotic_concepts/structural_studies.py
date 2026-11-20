"""Author the three exterior silhouette studies in the live Blender MCP process."""

import json
import math
import os
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from guns import source_for
from scene import ART,ROOT,beam,camera,collection,cut,locator,material,mesh,pose,prism,render,setup
from verify import mesh_check


PALETTES={
    "Spindrift":("171C2A","B9C9D9","59CBDD","B45743","32435B"),
    "Kilnlock":("161822","353747","7956FC","D09245","272336"),
    "Stacklight":("1D2430","E1DCCF","53DDD0","9187C6","306379"),
}


class Study:
    def __init__(self,line,item):
        self.label=line+" / "+item
        self.scene=bpy.data.scenes.new(self.label+" | Structural concept v01")
        self.mats=[material(self.label+" / "+label,color,metal,rough,alpha,emission)
                   for label,color,metal,rough,alpha,emission in zip(
                       ("Main structure","Outer plates","Active effect","Index marks","Recessed layer"),PALETTES[line],
                       (.26,.56 if line=="Spindrift" else .16,.1,.48,.21),(.45,.32,.18,.44,.34),
                       (1,1,.76 if line=="Spindrift" else 1,1,.72 if line=="Stacklight" else 1),(0,0,.82,0,0))]
        self.groups={name:collection(self.scene,self.label+" | "+name) for name in (
            "Keel and grips","Prow and upper shell","Rear architecture","Actuated pieces","Sight study","Cameras")}
        self.controls=[]

    def plate(self,group,name,shape,y0,y1,index,edge=.005):
        return prism(self.groups[group],self.label+" | "+name,shape,y0,y1,self.mats[index],edge)

    def fixed(self,group,name,shape,width,index):
        return self.plate(group,name,shape,-width,width,index)

    def twins(self,group,name,shape,y0,y1,index,edge=.005):
        return [self.plate(group,name+" "+str(side),shape,side*y0,side*y1,index,edge) for side in (-1,1)]

    def band_x(self,group,name,stations,index,count=8):
        verts=[(x,ry*math.cos(math.tau*(i+.5)/count),z+rz*math.sin(math.tau*(i+.5)/count))
               for x,z,ry,rz in stations for i in range(count)]
        faces=[tuple(range(count)),tuple(range(len(verts)-count,len(verts)))]
        for k in range(len(stations)-1):
            a,b=k*count,(k+1)*count
            for i in range(count):
                j=(i+1)%count
                faces.append((a+i,a+j,b+j,b+i))
        return mesh(self.groups[group],self.label+" | "+name,verts,faces,self.mats[index])

    def part(self,name,anchor,meshes,travel=(0,0,0),turn=(0,0,0),effect=False,delay=0):
        ctrl=locator(self.groups["Actuated pieces"],self.label+" | "+name,anchor,.032)
        for ob in meshes:
            ob.parent=ctrl
            ob.matrix_parent_inverse=Matrix.Translation(-Vector(anchor))
        frames=[(1,0),(13+delay,.12),(28+delay,1),(36+delay,.78),(54,0),(65,0)]
        for frame,value in frames:
            translate=Vector(anchor)+Vector(travel)*value
            scale=(max(.001,value),)*3 if effect else (1,1,1)
            pose(ctrl,frame,translate,tuple(value*r for r in turn),scale)
        ctrl["Role"]="Cosmetic only"
        self.controls.append(ctrl)

    def sight_bar(self,name,a,b,radius,index=0):
        return beam(self.groups["Sight study"],self.label+" | "+name,a,b,radius,self.mats[index],6,.92)

    def seal(self,root,target,view_front,sight):
        sc=self.scene
        setup(sc)
        sc.frame_start,sc.frame_end=1,65
        sc.render.resolution_x,sc.render.resolution_y=1280,680
        for name,f in (("REST",1),("ANTICIPATION",13),("ACTIVATE",28),("SETTLE",54),("RESET",65)):
            sc.timeline_markers.new(name,frame=f)
        cams=self.groups["Cameras"]
        sc.camera=camera(cams,self.label+" | Hero",target,(.35,1,.265),root,distance=5)
        camera(cams,self.label+" | Fixed side",target,(0,1,0),root,distance=5)
        camera(cams,self.label+" | Underside and rear",target,(-.3,-1,-.33),root,distance=5)
        camera(cams,self.label+" | Player angle",(.52,.27,.41),(-1,.37,.13),distance=1.28,lens=28,clip=.063)
        z=sight[1]
        camera(cams,self.label+" | Aim sketch",(sight[0]+1,0,z),(-1,0,0),distance=1.48,lens=26,clip=.065)
        camera(cams,self.label+" | Animated detail",view_front,(.08,1,.16),root*.44,distance=4)
        sc["Origin"]="Authoring process Blender MCP at 127.0.0.1:9000"
        sc["Review level"]="Structural design study for silhouette and part travel"
        return sc


def spindrift():
    s=Study("Spindrift","Vandal")
    k,p,r,a,q="Keel and grips","Prow and upper shell","Rear architecture","Actuated pieces","Sight study"
    s.fixed(k,"Basalt swept keel",[(-.21,.17),(.21,.13),(.68,.212),(1.22,.22),(1.65,.168),(2.49,.21),(2.56,.341),
                                 (1.76,.46),(1.22,.534),(.65,.505),(.20,.49),(-.21,.407)],.102,0)
    s.fixed(k,"Scalloped wrist contact",[(-.13,.238),(.10,.236),(.252,.057),(.13,-.327),(-.027,-.36),(-.183,-.26),(-.16,-.08)],.062,0)
    s.fixed(k,"Swept lower fin volume",[(.41,.187),(.76,.22),(.988,.077),(.908,-.108),(.756,-.46),(.587,-.488),(.488,-.438),(.638,-.114),(.622,.022)],.067,0)
    s.twins(k,"Lower fin nacre seam",[(.491,-.424),(.566,-.463),(.744,-.414),(.902,-.031),(.829,-.042)],.057,.081,1)
    s.fixed(r,"Upper stock bow",[(-1.27,.433),(-1.312,.371),(-1.191,.30),(-.847,.291),(-.47,.303),(-.174,.231),(-.14,.369),(-.57,.369),(-1.06,.451)],.069,0)
    s.fixed(r,"Lower stock return",[(-1.266,.34),(-1.288,-.186),(-1.166,-.219),(-.781,-.027),(-.416,.179),(-.19,.231),(-.262,.313),(-.502,.23),(-1.09,-.076),(-1.14,.294)],.046,0)
    s.fixed(r,"Pearl tail insert",[(-1.278,-.184),(-1.194,-.228),(-1.11,-.11),(-1.146,-.03),(-1.256,-.08)],.077,1)
    for i,x in enumerate((.28,.59,.89,1.19,1.48)):
        height=.53 if i>2 else .59
        s.twins(p,f"Swept spine plate {i+1}",[(x-.28,.433),(x+.24,.419),(x+.33,.464),(x+.16,.539),(x-.045,height),(x+.018,.492),(x-.15,.463)],.046,.128,1)
    s.twins(p,"Dark side ridge",[(.035,.28),(.4,.259),(.744,.311),(1.56,.36),(1.85,.288),(1.738,.42),(.96,.43),(.45,.405),(.137,.407)],.091,.158,4)
    s.twins(p,"Pearl lower chevron",[(.12,.206),(.764,.225),(1.153,.256),(1.285,.30),(1.135,.324),(.702,.277),(.314,.271)],.116,.163,1)
    upper=s.twins(a,"Upper swept fang",[(1.59,.37),(1.79,.407),(2.09,.463),(2.44,.448),(2.729,.361),(2.46,.406),(2.14,.369),(1.94,.319)],.071,.131,1)
    lower=s.twins(a,"Lower swept fang",[(1.59,.274),(1.87,.241),(2.16,.187),(2.724,.197),(2.559,.264),(2.27,.26),(1.948,.296)],.079,.128,1)
    s.part("Upper fin pitch",(1.69,0,.374),upper,(.026,0,.038),(0,-11,0))
    s.part("Lower fin pitch",(1.69,0,.271),lower,(.034,0,-.014),(0,10,0))
    water=s.band_x(a,"Transient tidal flow",[(.31,.331,.007,.009),(.61,.343,.160,.017),(1.19,.278,.179,.026),
                   (1.67,.355,.181,.027),(2.21,.32,.145,.019),(2.75,.305,.026,.009)],2,10)
    s.part("Water surge",(1.78,0,.34),[water],(0,.015,0),effect=True)
    for side in (-1,1):
        pts=[(-.04,side*.044,.46),(-.063,side*.089,.489),(-.064,side*.108,.559),(-.047,side*.084,.627),(-.029,side*.039,.678)]
        for i,(u,v) in enumerate(zip(pts,pts[1:])):
            s.sight_bar(f"Split halo cheek {side} {i}",u,v,.018,1 if i==3 else 0)
    s.sight_bar("Small cyan reference",(1.32,0,.531),(1.33,0,.56),.008,2)
    return s,s.seal(4.65,(.69,0,.104),(1.66,0,.345),(-.04,.562))


def kilnlock():
    s=Study("Kilnlock","Odin")
    k,p,r,a="Keel and grips","Prow and upper shell","Rear architecture","Actuated pieces"
    s.fixed(k,"Slim reactor chassis",[(-.28,.22),(0,.145),(.488,.201),(.88,.119),(1.562,.149),(1.83,.201),(2.863,.251),
                                  (3.21,.334),(3.185,.421),(2.68,.45),(1.776,.432),(1.57,.51),(.535,.57),(.04,.515),(-.27,.476)],.127,0)
    s.fixed(k,"Recoil grip silhouette",[(-.158,.261),(.105,.235),(.164,.117),(.075,-.308),(-.061,-.343),(-.213,-.261),(-.181,-.05)],.064,0)
    s.fixed(r,"Cast upper stock rail",[(-1.241,.491),(-1.305,.388),(-1.187,.331),(-.818,.351),(-.214,.351),(-.175,.509),(-.711,.486),(-1.041,.548)],.080,0)
    s.fixed(r,"Diagonal tension frame",[(-1.269,.403),(-1.27,-.170),(-1.181,-.228),(-1.039,-.187),(-.481,.23),(-.22,.327),(-.289,.437),(-.542,.37),(-1.087,-.048),(-1.127,.365)],.057,0)
    for j in range(4):
        z=-.191+j*.154
        s.fixed(r,f"Black steel tail facet {j+1}",cut(-1.324,-1.13,z,z+.129,.044),.091,1)
    s.twins(p,"Beveled reactor shoulder",[(.82,.315),(1.2,.30),(1.59,.245),(1.94,.328),(2.15,.34),(2.69,.369),
                  (2.74,.409),(2.66,.437),(2.05,.427),(1.89,.454),(1.61,.439),(1.43,.398),(1.04,.406)],.111,.157,1,.009)
    s.band_x(p,"Narrow angular prow shell",[(2.54,.361,.14,.108),(2.8,.36,.139,.098),(3.11,.37,.104,.075),(3.21,.374,.094,.068)],0,8)
    s.fixed(p,"Raised cutout spine",[(.248,.623),(.444,.655),(1.349,.595),(2.351,.547),(2.783,.497),
                                  (2.69,.439),(2.399,.485),(1.327,.55),(.446,.604)],.079,1)
    for i,x in enumerate((.48,1.485,2.434),1):
        z=.575-(x-.48)*.052
        s.twins(p,f"Floating spine seat {i}",cut(x-.032,x+.056,z-.105,z+.025,.025),.059,.092,3,.003)
    s.twins(p,"Violet energy trail rails",[(.925,.412),(1.2,.412),(1.67,.363),(2.94,.375),(3.04,.393),
                                   (2.982,.413),(1.735,.386),(1.23,.435),(1.061,.446)],.146,.165,2,.003)
    s.fixed(k,"Finned thermal box silhouette",[(.608,.215),(1.53,.207),(1.624,.055),(1.512,-.326),(1.36,-.395),(.745,-.343),(.587,-.243),(.544,.044)],.181,0)
    for i in range(7):
        x=.615+i*.137
        s.twins(k,f"Cast box rib {i+1}",[(x,-.261),(x+.059,-.278),(x+.092,-.194),(x+.079,.108),(x+.013,.149)],.158,.211,4)
    s.twins(p,"Inset reactor cradle",cut(.432,1.416,.224,.449,.053),.108,.157,4,.006)
    core=s.twins(a,"Lifted violet reactor prism",[(.806,.267),(1.047,.264),(1.103,.325),(1.035,.413),(.857,.405),(.762,.335)],.149,.186,2,.006)
    s.part("Reactor rise",(.93,.160,.332),core,(.02,.051,.094),effect=True)
    left=s.twins(a,"Aft dark wedge jaw",[(.48,.271),(.786,.24),(.863,.3),(.758,.341),(.856,.376),(.785,.418),(.491,.396)],.155,.193,1)
    right=s.twins(a,"Forward dark wedge jaw",[(1.366,.26),(1.073,.246),(.996,.302),(1.079,.341),(.993,.374),(1.075,.414),(1.356,.393)],.157,.195,1)
    s.twins(p,"Warm reactor cradling marks",cut(.856,1.02,.257,.282,.009),.158,.20,3,.004)
    s.part("Aft jaw outward slide",(.64,0,.337),left,(-.097,0,.055),(0,-12,0))
    s.part("Forward jaw outward slide",(1.24,0,.336),right,(.093,0,-.042),(0,12,0))
    for side in (-1,1):
        s.sight_bar(f"Low offset notch ear {side}",(-.035,side*.05,.55),(-.035,side*.05,.644),.025,1)
    s.sight_bar("Amber front index",(2.52,0,.52),(2.52,0,.549),.009,3)
    return s,s.seal(5.13,(.91,0,.121),(1.03,.14,.336),(-.035,.635))


def stacklight():
    s=Study("Stacklight","Phantom")
    k,p,r,a="Keel and grips","Prow and upper shell","Rear architecture","Actuated pieces"
    s.fixed(k,"Open chassis top rail",[(-.203,.424),(.03,.372),(.528,.373),(1.431,.412),(1.652,.411),
                                    (1.721,.489),(1.391,.548),(.48,.524),(-.074,.523)],.092,0)
    s.fixed(k,"Lower perimeter arc",[(.153,.247),(.319,.14),(.475,.148),(1.354,.17),(1.567,.222),(1.65,.286),
                                     (1.521,.313),(1.147,.253),(.453,.231),(.276,.325)],.078,0)
    s.fixed(k,"Molded grip",[(-.216,.425),(.026,.395),(.171,.239),(.008,-.289),(-.103,-.329),(-.26,-.278),(-.161,.021)],.069,0)
    s.fixed(k,"Rear removable body envelope",[(.34,.214),(.575,.226),(.67,.071),(.647,-.214),(.515,-.255),(.379,-.213)],.060,0)
    s.fixed(r,"Upper stock bridge",[(-1.133,.409),(-1.168,.325),(-1.042,.308),(-.662,.336),(-.151,.368),(-.102,.475),(-.418,.444),(-.99,.445)],.056,1)
    s.fixed(r,"Open stock strut",[(-1.155,.433),(-1.177,-.061),(-1.068,-.133),(-.994,-.081),(-.31,.271),(-.197,.379),(-.376,.358),(-1.031,-.007),(-1.03,.308)],.048,0)
    s.band_x(p,"Long faceted optical jacket",[(1.38,.333,.128,.159),(1.58,.339,.126,.159),(2.61,.353,.108,.132),
                  (2.742,.353,.081,.108),(2.762,.353,.064,.091)],1,8)
    s.band_x(p,"Graphite jacket nose",[(2.643,.353,.11,.132),(2.753,.353,.085,.111),(2.798,.353,.065,.088)],0,8)
    s.twins(p,"Stepped ivory instrument bridge",[(-.225,.397),(.026,.402),(.197,.478),(.642,.489),(1.177,.488),
                   (1.343,.422),(1.57,.405),(1.656,.452),(1.522,.507),(1.264,.598),(.365,.603),(.107,.589),(-.055,.493)],.072,.138,1,.009)
    for i in range(3):
        x=.622+i*.244
        s.fixed(k,"Chamber seat "+str(i+1),cut(x-.017,x+.223,.218,.26,.018),.101,0)
        s.twins(p,"Smoked polycarbonate cell "+str(i+1),cut(x,x+.203,.246,.385,.025),.09,.125,4)
        lens=s.twins(a,"Diagnostic signal "+str(i+1),cut(x+.038,x+.161,.283,.349,.014),.124,.132,2,.002)
        s.part(f"Sweep cue {i+1}",(x+.1,0,.318),lens,effect=True,delay=i*4)
    hatch=s.twins(a,"Short clear shuttle",cut(.802,1.08,.397,.437,.012),.102,.131,4)
    s.part("Shuttle slide",(.949,0,.415),hatch,(-.23,0,0))
    s.twins(p,"Lilac service index",cut(.177,.236,.485,.511,.008),.137,.142,3,.002)
    hood=[(-.042,-.064,.53),(-.075,-.064,.685),(-.091,-.045,.723),(-.091,.045,.723),(-.075,.064,.685),(-.042,.064,.53)]
    for i,(u,v) in enumerate(zip(hood,hood[1:])):
        s.sight_bar(f"Open diagnostic hood {i+1}",u,v,.017,0)
    for side in (-1,1):
        s.sight_bar(f"Mint lower bracket {side}",(-.059,side*.035,.577),(-.059,side*.064,.577),.004,2)
    return s,s.seal(4.59,(.77,0,.161),(1.12,0,.371),(-.065,.626))


def extent(objects):
    pts=[ob.matrix_world@Vector(v) for ob in objects if ob.type=="MESH" for v in ob.bound_box]
    lo=[min(p[i] for p in pts) for i in range(3)]
    hi=[max(p[i] for p in pts) for i in range(3)]
    return lo,hi,[b-a for a,b in zip(lo,hi)]


def stock_fit(study,sc,item):
    path=source_for(item)
    with bpy.data.libraries.load(str(path),link=False) as (src,dst):
        assert item in src.collections
        dst.collections=[item]
    stock=dst.collections[0]
    sc.collection.children.link(stock)
    stock.name="Stock comparison | "+item
    rig=next(ob for ob in stock.all_objects if ob.type=="ARMATURE")
    if rig.animation_data:
        rig.animation_data.action=None
        for track in rig.animation_data.nla_tracks:
            track.mute=True
    for pb in rig.pose.bones:
        pb.matrix_basis.identity()
    sc.frame_set(1)
    bpy.context.view_layer.update()
    reference=extent(stock.all_objects)
    objects=[ob for c in study.groups.values() if not c.name.endswith("Cameras") for ob in c.objects]
    design=extent(objects)
    ratio=[max(.68,min(1.16,reference[2][i]/design[2][i])) for i in range(3)]
    # Keep the origin in the original right-hand area. Width may stay tighter than stock.
    ratio[1]=min(ratio[1],1.0)
    root=locator(study.groups["Keel and grips"],study.label+" | Stock scale envelope",(0,0,0),.06)
    for ob in objects:
        if ob.parent is None:
            ob.parent=root
    root.scale=ratio
    bpy.context.view_layer.update()
    measured=extent(objects)
    anchors={ob.name:tuple(ob.matrix_world.translation) for ob in stock.all_objects
             if ob.type=="EMPTY" and any(k in ob.name for k in ("RightGrip","LeftGrip","AimPoint","CharmPoint"))}
    for name,pt in anchors.items():
        locator(study.groups["Keel and grips"],"Stock fit guide | "+name,pt,.045)
    stock.hide_render=True
    stock.hide_viewport=True
    return {"stock_source":path.relative_to(ROOT).as_posix(),"stock_bounds":reference,"concept_bounds":measured,
            "geometry_scale_xyz":ratio,"stock_anchors":anchors}


def deliver(line,item):
    assert bpy.app.background,"Use the dedicated background MCP process for scene saves."
    author={"Spindrift":spindrift,"Kilnlock":kilnlock,"Stacklight":stacklight}[line]
    study,sc=author()
    bpy.context.window.scene=sc
    for other in list(bpy.data.scenes):
        if other!=sc:
            bpy.data.scenes.remove(other)
    fit=stock_fit(study,sc,item)
    skin=[o for col in study.groups.values() for o in col.objects if o.type=="MESH"]
    mesh_issues=mesh_check(skin)
    assert not mesh_issues,mesh_issues
    sc.frame_set(1)
    baseline=[ob.matrix_world.copy() for ob in study.controls]
    sc.frame_set(28)
    move=max((a.translation-ob.matrix_world.translation).length for a,ob in zip(baseline,study.controls))
    sc.frame_set(65)
    reset=max((a.translation-ob.matrix_world.translation).length for a,ob in zip(baseline,study.controls))
    assert move>.01 and reset<.0002,(move,reset)
    out=ART/"Skins"/line/item/"StructuralConcept"/"v01"
    out.mkdir(parents=True,exist_ok=True)
    blend=out/f"{item}_{line}_structure_v01.blend"
    sc.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    shots=(("hero","Hero",1), ("side","Fixed side",1), ("reverse","Underside and rear",1),
           ("held","Player angle",1), ("aim","Aim sketch",1), ("active","Animated detail",28), ("reset","Animated detail",65))
    for stem,label,frame in shots:
        cam=bpy.data.objects[study.label+" | "+label]
        render(sc,cam,out/(stem+".png"),frame,(1200,640))
    record={"model":str(blend.relative_to(ROOT)),"scene":sc.name,"frames":[1,13,28,54,65],
            "groups":{key:len(col.objects) for key,col in study.groups.items()},
            "controls":[obj.name for obj in study.controls],"mesh_count":len(skin),"max_move":move,"reset_delta":reset,
            "MCP port":9000,"session_pid":os.getpid(),**fit}
    (out/"study.json").write_text(json.dumps(record,indent=2),encoding="utf-8")
    return record


if __name__=="__main__":
    line,item=sys.argv[sys.argv.index("--")+1:]
    result=deliver(line,item)
