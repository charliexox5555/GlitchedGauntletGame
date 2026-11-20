"""Measured Blender assemblies that keep Gauntlet's stock moving parts and cues."""

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
from finish import melee_actions,studio
from finish_materials import finish_surface
from guns import bind,gun_motion,hands_for,load_stock,paint_stock,side_fit,source_for
from scene import ART,ROOT,beam,camera,collection,cut,framed_camera,material,locator,marker,pivot,points,prism,render,setup
from structural_accessories import animate_melee,buddy,buddy_key
from structural_studies import PALETTES,extent
from verify import mesh_check,state,stock_check


def palette_for(line):
    colors=PALETTES[line]
    return [material(line+" / "+name,code,metal,rough,alpha,emit) for name,code,metal,rough,alpha,emit in zip(
        ("Shell","Face plates","Active insert","Accent","Smoked seat"),colors,
        (.42,.65 if line!="Stacklight" else .25,.12,.63,.25),(.44,.28,.17,.32,.32),
        (1,1,1,1,.70 if line=="Stacklight" else 1),(0,0,.8,0,0))]


def replace_stock(col,stock,rig,line,item,palette):
    dark,pale,_,accent,shade=palette
    stub=next((o for o in stock if o.name==item+"_Stock"),None)
    if stub is None:
        return []
    (x0,y0,z0),(x1,y1,z1),dims=extent([stub])
    if dims[0]<.25 or dims[2]<.18:
        return []
    w,_,h=dims
    # The Bulldog action occupies the fore half of its bullpup stock.
    if item=="Bulldog":
        w*=.37
    mid=max(abs(y0),abs(y1))
    if line=="Spindrift":
        upper=[(0,.83),(.045,.97),(.105,.99),(.40,.786),(.88,.756),(1.027,.698),(1.023,.51),(.55,.63),(.288,.623),(.109,.733)]
        lower=[(.03,.91),(.136,.752),(.183,.263),(.43,.42),(.721,.638),(.999,.706),(1.006,.504),(.749,.485),(.456,.28),(.104,.015),(.019,.077)]
    elif line=="Kilnlock":
        upper=[(0,.92),(.079,.99),(.594,.899),(1.018,.79),(1.015,.558),(.728,.58),(.452,.698),(.084,.729)]
        lower=[(.026,.88),(.143,.765),(.169,.262),(.358,.346),(.683,.588),(.998,.717),(1.008,.533),(.784,.466),(.55,.34),(.21,.075),(.072,.017),(.03,.16)]
    else:
        upper=[(.0,.89),(.084,.979),(.511,.954),(.661,.825),(1.022,.825),(1.017,.642),(.593,.642),(.485,.747),(.074,.714)]
        lower=[(.019,.87),(.128,.758),(.121,.213),(.332,.256),(.63,.573),(.995,.689),(1.013,.522),(.722,.448),(.467,.159),(.205,.025),(.076,.022),(.03,.137)]
    def polygon(name,outline,thick,mat):
        obj=prism(col,item+" | "+name,[(x0+x*w,z0+z*h) for x,z in outline],-thick,thick,mat,min(.008,thick*.22))
        bind(obj,rig,"Root")
        return obj
    made=[polygon("Rebuilt upper stock spar",upper,mid*.83,pale if line=="Stacklight" else dark),
          polygon("Open diagonal stock return",lower,mid*.71,dark)]
    heel=[(.013,.132),(.085,.037),(.158,.102),(.147,.402),(.141,.764),(.076,.876),(.018,.809)]
    made.append(polygon("Cut heel pad",heel,mid*.97,pale if line=="Spindrift" else shade))
    # Stock stays in the file for a direct A/B check. New load-bearing silhouettes use the source join.
    if item!="Bulldog":
        stub.hide_render=True
        stub.hide_set(True)
    return made


def structural_side(col,rig,line,item,palette,shift=0):
    part,(x0,x1),(z0,z1),_=GUNS[line,item]
    if (line,item)==("Kilnlock","Odin"):
        x0,x1,z0,z1=1.39,1.87,.337,.516
    if (line,item)==("Stacklight","Phantom"):
        x0,x1,z0,z1=.175,.752,.209,.332
    if item=="Stinger":
        z1=.271
    receiver=bpy.data.objects[item+"_"+part]
    lo,outer,rays=side_fit(receiver,x0,x1,z0,z1)
    w,h=x1-x0,z1-z0
    depth=outer+shift
    dark,pale,lit,accent,shade=palette
    static,controls=[],[]
    def shape(name,profile,near,far,mat,edge=.003):
        return prism(col,item+" | "+name,[(x0+x*w,z0+z*h) for x,z in profile],depth+near,depth+far,mat,edge)
    def panel(name,xlo,xhi,zlo,zhi,near,far,mat):
        outline=cut(x0+xlo*w,x0+xhi*w,z0+zlo*h,z0+zhi*h,min(.018,h*.18))
        return prism(col,item+" | "+name,outline,depth+near,depth+far,mat,.002)
    def drive(name,ob,x,y,z,kind,amount):
        p=pivot(col,item+" | "+name,(x0+x*w,depth+y,z0+z*h),[ob],rig,"Root")
        controls.append((p,kind,amount))
    if line=="Spindrift":
        static.append(shape("Swept basalt channel spine",[(.006,.24),(.168,.04),(.721,.04),(.974,.28),(.983,.62),(.766,.74),
                (.895,1.14),(.592,.991),(.487,.735),(.279,.736),(.136,.976),(.033,.663)],-.003,.025,dark))
        static.append(shape("Pearl lower rib",[(.081,.15),(.341,.218),(.678,.199),(.941,.32),(.852,.474),(.609,.394),(.221,.333)],.019,.043,pale))
        count=1 if item in ("Ghost","Guardian") else 2
        for i in range(count):
            a=.10+i*.356
            fin=shape("Moving nacre prow fin "+str(i+1),[(a,.50),(a+.308,.463),(a+.395,.623),(a+.295,.782),
                                        (a+.174,1.27),(a+.192,.877),(a+.038,.782)],.023,.056,pale)
            drive("Fin hinge "+str(i+1),fin,a+.25,.032,.71,"leaf",1 if i==0 else -1)
        for i in range(11):
            a=.12+.069*i
            z=.468+.081*((i%5)-2)/2
            trace=shape(f"Tide trace {i+1:02d}",[(a,z-.04),(a+.075,z-.025),(a+.077,z+.045),(a,z+.036)],.041,.051,lit,.001)
            drive(f"Tide trace cue {i+1:02d}",trace,a+.027,.046,z,"ribbon",i)
        if item=="Guardian":
            bead=shape("Storm pearl",[(.22,.45),(.247,.30),(.288,.45),(.249,.592)],.048,.061,lit,.002)
            drive("Basin bead cue",bead,.249,.048,.461,"bead",w)
    elif line=="Kilnlock":
        static.append(shape("Angled graphite reactor saddle",[(.018,.29),(.166,.035),(.718,.041),(.969,.236),(.992,.59),
            (.852,.756),(.752,.904),(.12,.892),(.027,.65)],-.006,.032,dark))
        static.append(shape("Raised negative-space spine",[(.061,.927),(.149,1.16),(.491,1.166),(.701,1.21),(.976,.981),
                                         (.927,.77),(.724,.92),(.48,.914),(.188,.918)],.005,.049,pale))
        static.append(panel("Amber index seat",.302,.699,.13,.25,.023,.045,accent))
        core=shape("Faceted violet core",[(.344,.413),(.414,.291),(.60,.299),(.674,.449),(.635,.664),(.418,.667)],.038,.062,lit)
        drive("Reactor rise",core,.502,.043,.483,"heat",w)
        for i,sign in enumerate((1,-1)):
            a=.132+.384*i
            jaw=shape(f"Graphite wedge jaw {i+1}",[(a,.246),(a+.344,.225),(a+.351,.356),(a+.22,.454),
                                      (a+.34,.526),(a+.262,.749),(a+.026,.731)],.044,.069,pale)
            drive(f"Reactor aperture hinge {i+1}",jaw,a+.143,.045,.587,"jaw",sign)
    else:
        static.append(shape("Molded bridge top",[(.018,.605),(.21,.578),(.291,.719),(.683,.734),(.82,.58),(.984,.599),
                   (1.005,.814),(.874,1.11),(.743,1.205),(.282,1.22),(.128,.985)],.004,.057,pale))
        static.append(shape("Open graphite perimeter rail",[(.048,.604),(.233,.08),(.676,.078),(.958,.315),(.965,.516),
                                                (.733,.307),(.30,.27),(.143,.659)],.013,.057,dark))
        n=2 if item=="Classic" else 3
        for i in range(n):
            a=.265+i*(.506/n)
            static.append(panel("Smoked glass cell "+str(i+1),a,a+.125,.265,.663,.027,.058,shade))
            cell=panel("Mint diagnostic unit "+str(i+1),a+.021,a+.107,.338,.548,.054,.067,lit)
            drive("Sequential indicator "+str(i+1),cell,a+.062,.063,.453,"light",i)
        shuttle=panel("Sliding clear cartridge",.673,.866,.097,.244,.045,.063,shade)
        drive("Cartridge track",shuttle,.772,.049,.169,"shuttle",w)
        static.append(panel("Lilac index",.824,.895,.706,.843,.051,.061,accent))
    for ob in static:
        bind(ob,rig,"Root")
    return controls,(.5*(x0+x1),depth,.5*(z0+z1)),rays


def hero_architecture(col,stock,rig,line,item,pal):
    dark,pale,lit,accent,shade=pal
    controls=[]
    def plate(name,form,y0,y1,mat,paired=True,anchor=None,sign=1):
        pieces=[prism(col,item+" | "+name+f" {side}",form,side*y0,side*y1,mat,.006)
                for side in ((-1,1) if paired else (1,))]
        if anchor:
            root=pivot(col,item+" | "+name+" control",anchor,pieces,rig,"Root")
            controls.append((root,"leaf",sign))
        else:
            for ob in pieces:
                bind(ob,rig,"Root")

    def hide(role):
        ob=bpy.data.objects.get(item+"_"+role)
        if ob:
            ob.hide_render=True
            ob.hide_set(True)

    if line=="Spindrift":
        hide("Rail")
        plate("Sculpted slate keel flank",[(.96,.22),(1.401,.158),(1.788,.2),(1.949,.297),(1.71,.41),
                         (1.51,.425),(1.161,.387),(.963,.302)],.084,.135,dark)
        plate("Upper pearlescent shoulder flange",[(.49,.415),(.818,.385),(1.58,.435),(1.87,.351),
                         (1.917,.416),(1.729,.485),(1.089,.513),(.583,.491)],.041,.122,pale)
        plate("Recessed dorsal fin bed",[(.381,.416),(.563,.391),(1.293,.396),(1.823,.393),
                        (1.794,.455),(1.472,.483),(.523,.489)],.067,.127,shade)
        for i,x in enumerate((.58,.84,1.08,1.33,1.56),1):
            top=.54-i*.010
            plate(f"Swept dorsal nacre fin {i}",[(x-.22,.457),(x+.124,.421),(x+.224,.48),(x+.053,top-.017),
                                                (x-.088,top+.018),(x-.003,.474)],.053,.135,pale)
        plate("Upper prow fang",[(1.649,.349),(1.935,.373),(2.2,.420),(2.582,.349),(2.64,.313),(2.325,.365),
                                      (2.149,.324),(1.85,.292)],.042,.105,pale,anchor=(1.724,0,.365),sign=-1)
        plate("Lower prow fang",[(1.66,.253),(1.955,.23),(2.308,.148),(2.629,.208),(2.524,.253),(2.105,.239),
                                       (1.905,.273)],.043,.113,pale,anchor=(1.741,0,.255),sign=1)
        water=material("Spindrift / Translucent surge","6ED5ED",.08,.19,.82,.73)
        ribbons=[]
        outline=[(1.38,.325),(1.52,.293),(1.725,.274),(1.91,.302),(2.108,.341),(2.24,.312),
                 (2.421,.29),(2.604,.31),(2.524,.275),(2.356,.258),(2.218,.265),(2.093,.29),
                 (1.892,.259),(1.703,.237),(1.497,.263)]
        for side in (-1,1):
            ribbons.append(prism(col,item+f" | Active water sheet {side}",outline,side*.113,side*.144,water,.004))
        wave=pivot(col,item+" | Flow along prow",(1.86,0,.283),ribbons,rig,"Root")
        controls.append((wave,"ribbon",3))
        hide("RearSight")
        hide("FrontSight")
    elif line=="Kilnlock":
        plate("Slender dark extension shroud",[(1.72,.246),(2.12,.231),(2.63,.262),(3.25,.296),(3.343,.369),
                     (3.2,.43),(2.732,.448),(2.223,.427),(1.81,.377)],.088,.148,dark)
        plate("Raised reactor feed-side rail",[(1.43,.508),(1.651,.519),(2.01,.501),(2.571,.471),(2.779,.445),
                    (2.734,.407),(2.461,.427),(1.873,.447),(1.58,.469)],.132,.167,pale)
        plate("Violet energy seam",[(1.88,.375),(2.274,.363),(2.845,.343),(3.026,.354),(2.914,.379),
                     (2.555,.388),(2.209,.4),(1.951,.397)],.148,.160,lit)
        plate("Angled amber mounting brackets",[(2.058,.399),(2.114,.398),(2.167,.451),(2.101,.474),(2.057,.441)],.155,.174,accent)
        hide("Sights")
    else:
        plate("Stepped ivory bridge wings",[(.271,.407),(.426,.42),(.693,.441),(.973,.412),(1.331,.322),(1.445,.358),
                 (1.195,.494),(.951,.532),(.611,.516),(.358,.481)],.062,.111,pale)
        plate("Long faceted ivory jacket",[(1.095,.295),(1.224,.203),(1.636,.203),(1.801,.226),(2.348,.231),
                    (2.485,.275),(2.502,.371),(2.436,.434),(1.992,.434),(1.596,.457),(1.289,.411)],.061,.113,pale)
        plate("Graphite optical rails",[(1.22,.177),(1.673,.184),(2.363,.216),(2.486,.265),(2.401,.293),(1.791,.255),
                                         (1.31,.253)],.082,.117,dark)
        plate("Inset mint jacket readout",[(1.688,.253),(1.906,.252),(1.997,.273),(1.912,.289),(1.711,.281)],.114,.121,lit)
        hide("Sights")
        hide("Rail")

    aim=bpy.data.objects[item+"_AimPoint"].matrix_world.translation
    sx,_,sz=aim
    frame=prism(col,item+" | Seated rear Sight foot",[(sx-.093,sz-.151),(sx+.078,sz-.137),
              (sx+.073,sz-.106),(sx+.034,sz-.067),(sx-.065,sz-.052),(sx-.092,sz-.077)],-.074,.074,dark,.005)
    bind(frame,rig,"Root")
    for side in (-1,1):
        if line=="Spindrift":
            corners=[(sx,side*.037,sz-.085),(sx-.019,side*.083,sz-.038),(sx-.03,side*.085,sz+.032),
                     (sx-.029,side*.046,sz+.080)]
        elif line=="Kilnlock":
            corners=[(sx,side*.042,sz-.067),(sx-.022,side*.049,sz+.036),(sx-.024,side*.06,sz+.045)]
        else:
            corners=[(sx,side*.069,sz-.084),(sx-.042,side*.069,sz+.04),(sx-.05,side*.049,sz+.066),
                     (sx-.062,side*.015,sz+.066)]
        for index,(a,b) in enumerate(zip(corners,corners[1:])):
            ob=beam(col,f"{item} | New Sight cheek {side} {index}",a,b,.014,pale if index else dark,6,.87)
            bind(ob,rig,"Root")
    fore={"Spindrift":2.022,"Kilnlock":2.58,"Stacklight":1.523}[line]
    post=prism(col,item+" | Seated forward Sight post",[(fore-.060,sz-.235),(fore+.072,sz-.221),
                (fore+.053,sz-.159),(fore+.023,sz-.074),(fore-.020,sz-.073),(fore-.048,sz-.135)],-.037,.037,dark,.004)
    bind(post,rig,"Root")
    ob=beam(col,item+" | New Sight index",(fore,0,sz-.091),(fore,0,sz-.013),.008,accent if line=="Kilnlock" else lit,6)
    bind(ob,rig,"Root")
    return controls


def secondary_architecture(col,stock,rig,line,item,palette):
    dark,pale,lit,accent,shade=palette
    by_role={ob.name.removeprefix(item+"_"):ob for ob in stock if ob.parent_bone in ("Root","")}
    candidates=("Suppressor","Handguard","ForeEnd","Forend","Barrel","Frame")
    part=next((by_role[k] for k in candidates if k in by_role),None)
    if part is None or item in ("Shorty","Sheriff","Classic"):
        return
    (x0,y0,z0),(x1,y1,z1),(w,_,h)=extent([part])
    if item=="Bucky":
        pump=bpy.data.objects.get("Bucky_Pump")
        if pump:
            z0=max(z0,extent([pump])[1][2]+.017)
            h=z1-z0
    if w<.22 or h<.07:
        return
    y=max(abs(y0),abs(y1))
    if line=="Spindrift":
        outer=[(.11,.66),(.28,.49),(.595,.56),(.846,.41),(.965,.57),(.888,.772),
               (.663,.84),(.511,.986),(.43,.795),(.244,.873)]
        trim=[(.218,.776),(.326,.858),(.503,.936),(.671,.84),(.831,.768),(.708,.734),(.47,.835),(.324,.795)]
    elif line=="Kilnlock":
        outer=[(.057,.694),(.2,.43),(.335,.423),(.471,.545),(.85,.475),(.975,.65),
               (.91,.827),(.693,.927),(.376,.823),(.275,.902),(.109,.853)]
        trim=[(.177,.643),(.336,.61),(.48,.701),(.755,.701),(.839,.769),(.676,.779),(.461,.772),(.31,.656)]
    else:
        outer=[(.04,.65),(.244,.54),(.358,.438),(.72,.447),(.811,.59),(.944,.626),(.972,.822),
               (.805,.997),(.53,.913),(.28,.897),(.153,.806)]
        trim=[(.254,.594),(.378,.546),(.707,.54),(.791,.643),(.711,.706),(.403,.658),(.327,.626)]
    for side in (-1,1):
        for label,shape,yin,yout,mat in (
            ("Reprofiled fore shell",outer,y-.016,y+.017,pale if line=="Stacklight" else dark),
            ("Directional fore face",trim,y+.013,y+.023,pale if line=="Spindrift" else (lit if line=="Kilnlock" else shade)),
        ):
            obj=prism(col,item+" | "+label+f" {side}",[(x0+x*w,z0+z*h) for x,z in shape],side*yin,side*yout,mat,.004)
            bind(obj,rig,"Root")


def fit_roster_gun(line,item):
    sc,rig,source=load_stock(item)
    cols=collection(sc,"EXOTIC | Fixed skin and independent controls")
    mount_col=collection(sc,"EXOTIC | Mounted charm")
    cameras=collection(sc,"EXOTIC | Structural review cameras")
    pal=palette_for(line)
    stock=paint_stock(line,item,pal)
    ref=extent(stock)
    replace_stock(cols,stock,rig,line,item,pal)
    controls,detail,seat=structural_side(cols,rig,line,item,pal)
    if (line,item) in HEROES:
        controls.extend(hero_architecture(cols,stock,rig,line,item,pal))
    else:
        secondary_architecture(cols,stock,rig,line,item,pal)
    charm_id=next(name for bundle,name in CHARMS if bundle==line)
    anchor=bpy.data.objects.get(item+"_CharmPoint")
    buddy_size=.47 if item=="Judge" else (.56 if item in ("Shorty","Sheriff","Ghost","Classic") else .7)
    mounted=buddy(mount_col,line,charm_id,pal,anchor.matrix_world.translation,rig,anchor.parent_bone,buddy_size) if anchor else None
    if mounted and item=="Judge":
        mounted[0]["Outboard rest cant"]=24
    motion=gun_motion(sc,rig,line,item,controls,None)
    if mounted:
        f=sc.frame_end
        for frame,amount,turn in ((1,0,0),(motion["commit"],.8,-7),(motion["ready"],0,0),(motion["inspect"],1,10),
                (motion["cancel"],0,0),(f+8,1,15),(f+17,1,-15),(f+22,0,0)):
            buddy_key(mounted,frame,amount,turn)
        motion["charm_extremes"]=[f+8,f+17]
        marker(sc,"BUDDY EXTREME +15",f+8)
        marker(sc,"BUDDY EXTREME -15",f+17)
        sc.frame_end=f+22
    hands=hands_for(sc,rig,line,item,motion)
    hands.hide_render=True
    fit=check_gun(sc,line,item,motion)
    fit["receiver_seat_probes"]=seat
    fit["stock_bounds"]=ref
    objects=[o for o in stock if not o.hide_render]+list(cols.objects)+list(mount_col.objects)
    fit["new_bounds"]=extent(objects)
    fit["stock_anchors"]={ob.name:tuple(ob.matrix_world.translation) for ob in bpy.data.collections[item].objects
                    if ob.type=="EMPTY" and any(k in ob.name for k in ("RightGrip","LeftGrip","AimPoint","CharmPoint"))}
    coords=points(objects)
    views={"hero":framed_camera(cameras,item+" | structural view",coords,(.48,1,.25),1.87,1.11),
           "side":framed_camera(cameras,item+" | fit profile",coords,(0,1,0),1.87,1.1),
           "under":framed_camera(cameras,item+" | reverse underside",coords,(-.24,-1,-.38),1.87,1.12),
           "active":camera(cameras,item+" | active detail",(1.95,.10,.32) if item=="Vandal" else detail,
                           (.17,1,.20),scale=1.63 if item=="Vandal" else .96)}
    bind(views["active"],rig,"Root")
    from final_pass import ADS,ads_cam,hip_cam
    views["held"]=hip_cam(item)
    if item in ADS:
        views["aim"]=ads_cam(item)
    return sc,source,views,motion,fit,{}


def fit_accessory(line,item):
    sc=bpy.context.scene
    for ob in list(sc.objects):
        bpy.data.objects.remove(ob,do_unlink=True)
    col=collection(sc,"Structural | Model and controls")
    cams=collection(sc,"Structural | Review cameras")
    pal=palette_for(line)
    if (line,item) in MELEES:
        animate_melee(sc,col,item,pal)
        clips=melee_actions(sc,item)
        motion={"active":150 if item!="PatchTool" else 146,"cancel":219,"contact":[72,91,113]}
    else:
        clips={}
        b=buddy(col,line,item,pal)
        for frame,amount,spin in ((1,0,0),(12,.20,-5),(28,1,15),(39,.84,-12),(55,0,0)):
            buddy_key(b,frame,amount,spin)
        for label,f in (("REST",1),("ACTIVATE",12),("ACTIVE",28),("RESET",55)):
            marker(sc,label,f)
        sc.frame_start,sc.frame_end=1,55
        motion={"active":28,"cancel":55}
    sc.frame_set(1)
    coords=points(col.objects)
    fit={"rest_bounds":extent(col.objects)}
    if (line,item) in MELEES:
        reference=source_for("Knife")
        with bpy.data.libraries.load(str(reference),link=False) as (src,dst):
            assert "Knife" in src.collections
            dst.collections=["Knife"]
        stock=dst.collections[0]
        sc.collection.children.link(stock)
        bpy.context.view_layer.update()
        fit["stock_knife_bounds"]=extent(stock.all_objects)
        stock.name="Stock comparison | Knife"
        stock.hide_render=True
        stock.hide_viewport=True
    views={"hero":framed_camera(cams,item+" | structural view",coords,(.35,1,.22),1.5,1.12),
           "side":framed_camera(cams,item+" | profile",coords,(0,1,0),1.5,1.11),
           "under":framed_camera(cams,item+" | reverse",coords,(-.25,-1,-.36),1.5,1.12),
           "held":camera(cams,item+" | first-person",(.64,.18,.21),(-1,.39,.14),distance=1.52,lens=15.1,clip=.10)}
    if (line,item) in MELEES:
        sc.frame_set(motion["active"])
        views["active"]=framed_camera(cams,item+" | framed inspect pose",points(col.objects),(.28,1,.255),1.5,1.14)
        sc.frame_set(1)
    return sc,None,views,motion,fit,clips


def build(line,item,version):
    key=(line,item)
    out=ART/"Skins"/line/item/"StructuralBuild"/version
    out.mkdir(parents=True,exist_ok=True)
    if (out/"build.json").exists():
        return
    sc,source,views,motion,fit,clips=fit_roster_gun(line,item) if key in GUNS else fit_accessory(line,item)
    setup(sc)
    for mat in list(bpy.data.materials):
        finish_surface(mat,line)
    sc.name=f"{line} | {item} | Structural {version}"
    sc["Review scope"]="Offline structural design and stock-motion fit"
    sc["Pose index"]=motion
    skin=[ob for c in sc.collection.children if c.name.startswith(("EXOTIC | Fixed","EXOTIC | Mounted","Structural | Model"))
          for ob in c.objects if ob.type=="MESH"]
    issues=mesh_check(skin)
    assert not issues,issues
    a=state(sc,skin,1)
    b=state(sc,skin,motion["cancel"])
    reset=max(abs(x-y) for x,y in zip(a,b))
    assert reset<.0002,(line,item,reset)
    sc.frame_set(1)
    sc.camera=views["hero"]
    sc.render.resolution_x,sc.render.resolution_y=(1200,640) if key in GUNS else (1050,700)
    sc.render.filepath="//review/"
    path=out/f"{item}_{line}_structural_{version}.blend"
    bpy.context.preferences.filepaths.save_version=0
    if key in HEROES+MELEES+CHARMS:
        studio(sc,views["hero"],line)
    bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
    if key in HEROES+MELEES+CHARMS:
        shape=(1200,640) if key in GUNS else (1050,700)
        render(sc,views["hero"],out/"hero.png",1,shape)
        active=motion.get("peak",motion.get("active"))
        render(sc,views.get("active",views["hero"]),out/"active.png",active,shape)
    if key in HEROES:
        sc.render.engine="BLENDER_WORKBENCH"
        sc.view_settings.view_transform="Standard"
        render(sc,views["aim"],out/"aim.png",1,(840,470))
        render(sc,views["under"],out/"underside.png",1,(880,470))
    bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False)
    stock_count=stock_check(bpy.context.scene,ROOT,item,{"source":str(source.relative_to(ROOT))}) if source else 0
    (out/"build.json").write_text(json.dumps({"line":line,"item":item,"file":path.name,"version":version,
        "source":source.relative_to(ROOT).as_posix() if source else "Original structural accessory",
        "mesh_count":len(skin),"reset_delta":reset,"stock_meshes_preserved":stock_count,"fit":fit,
        "motion":motion,"clips":clips},indent=2),encoding="utf-8")


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("line")
    parser.add_argument("item")
    parser.add_argument("--version",default="v01")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    assert (args.line,args.item) in QUEUE
    build(args.line,args.item,args.version)
