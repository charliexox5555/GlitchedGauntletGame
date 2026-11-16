"""Blender-authored effect gradients, action studies and transparent sprite bakes."""

import math
import random

import bpy
from mathutils import Matrix, Vector

from mod_rework_fx import visual_effects
from mod_rework_kit import Parts, material, rgba
from mod_rework_review import camera, clone, floor, label, position, render_scene


def ink(name, edge, core, *, strength=1.15, opacity=1.0, radial=False):
    """Keep the gradient in the native source and bake it for the runtime."""
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    tree=mat.node_tree
    tree.nodes.clear()

    def scalar(op, a, b=None):
        node=tree.nodes.new("ShaderNodeMath")
        node.operation=op
        for i,arg in enumerate((a,b)):
            if arg is None:
                continue
            if isinstance(arg,(int,float)):
                node.inputs[i].default_value=arg
            else:
                tree.links.new(arg,node.inputs[i])
        return node.outputs[0]

    uv=tree.nodes.new("ShaderNodeUVMap")
    uv.uv_map="UVMap"
    if radial:
        distance=tree.nodes.new("ShaderNodeVectorMath")
        distance.operation="DISTANCE"
        tree.links.new(uv.outputs["UV"],distance.inputs[0])
        distance.inputs[1].default_value=(.5,.5,0)
        shape=scalar("MAXIMUM",scalar("SUBTRACT",1,scalar("MULTIPLY",distance.outputs["Value"],2)),0)
        opacity_shape=scalar("POWER",shape,1.35)
    else:
        axis=tree.nodes.new("ShaderNodeSeparateXYZ")
        tree.links.new(uv.outputs["UV"],axis.inputs[0])
        u,v=axis.outputs["X"],axis.outputs["Y"]
        shape=scalar("MAXIMUM",scalar("SUBTRACT",1,scalar("ABSOLUTE",scalar("SUBTRACT",
            scalar("MULTIPLY",v,2),1))),0)
        ends=scalar("MINIMUM",scalar("MULTIPLY",u,8),
                    scalar("MULTIPLY",scalar("SUBTRACT",1,u),10))
        opacity_shape=scalar("MULTIPLY",scalar("POWER",shape,.52),scalar("MINIMUM",ends,1))
    mix=tree.nodes.new("ShaderNodeMixRGB")
    tree.links.new(scalar("POWER",shape,1.65),mix.inputs[0])
    mix.inputs[1].default_value=rgba(edge)
    mix.inputs[2].default_value=rgba(core)
    emission=tree.nodes.new("ShaderNodeEmission")
    tree.links.new(mix.outputs["Color"],emission.inputs["Color"])
    emission.inputs["Strength"].default_value=strength
    transparent=tree.nodes.new("ShaderNodeBsdfTransparent")
    blend=tree.nodes.new("ShaderNodeMixShader")
    tree.links.new(scalar("MULTIPLY",opacity_shape,opacity),blend.inputs[0])
    tree.links.new(transparent.outputs[0],blend.inputs[1])
    tree.links.new(emission.outputs[0],blend.inputs[2])
    out=tree.nodes.new("ShaderNodeOutputMaterial")
    tree.links.new(blend.outputs[0],out.inputs["Surface"])
    return mat


def surface(scene, name, points, faces, uv, material):
    data=bpy.data.meshes.new(name)
    data.from_pydata(points,[],faces)
    data.materials.append(material)
    layer=data.uv_layers.new(name="UVMap")
    for loop in data.loops:
        layer.data[loop.index].uv=uv[loop.vertex_index]
    obj=bpy.data.objects.new(name,data)
    scene.collection.objects.link(obj)
    return obj


def stroke(scene, name, points, material, origin=(0,0,0), scale=1):
    xy=[Vector((x,y)) for x,y,_ in points]
    vertices,uv=[],[]
    for i,(pt,(_,_,wide)) in enumerate(zip(xy,points)):
        direction=xy[min(len(xy)-1,i+1)]-xy[max(0,i-1)]
        offset=Vector((-direction.y,direction.x)).normalized()*wide*.5
        for side,edge in enumerate((pt-offset,pt+offset)):
            vertices.append((origin[0]+edge.x*scale,origin[1]+edge.y*scale,origin[2]))
            uv.append((i/(len(xy)-1),side))
    faces=[(i,i+1,i+3,i+2) for i in range(0,len(vertices)-2,2)]
    return surface(scene,name,vertices,faces,uv,material)


def flowing(points):
    """Interpolate the centerline of a flame or dust ribbon between the drawn keys."""
    keys=[Vector(key) for key in points]
    output=[]
    for i,(b,c) in enumerate(zip(keys,keys[1:])):
        a,d=keys[max(0,i-1)],keys[min(len(keys)-1,i+2)]
        for j in range(5):
            t=j/5
            point=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
            output.append((point.x,point.y,max(.003,point.z)))
    return output+[points[-1]]


def glow(scene, name, loc, width, length, ink):
    x,y,z=loc
    points=[(x-width*.5,y-length*.5,z),(x+width*.5,y-length*.5,z),
            (x+width*.5,y+length*.5,z),(x-width*.5,y+length*.5,z)]
    return surface(scene,name,points,[(0,1,2,3)],[(0,0),(1,0),(1,1),(0,1)],ink)


def arc(scene,name,origin,mat,rx,ry,start,end,width,*,tilt=0,count=38):
    cs,sn=math.cos(tilt),math.sin(tilt)
    points=[]
    for i in range(count+1):
        t=i/count
        angle=start+(end-start)*t
        x,y=math.cos(angle)*rx,math.sin(angle)*ry
        taper=.22+.78*(math.sin(math.pi*t)**.55)
        points.append((x*cs-y*sn,x*sn+y*cs,width*taper))
    stroke(scene,name,points,mat,origin)


def flecks(scene,seed,origin,mat,n,spread,*,upward=False):
    randomizer=random.Random(seed)
    for _ in range(n):
        angle=randomizer.uniform(.09,math.pi-.09) if upward else randomizer.uniform(0,math.tau)
        direction=Vector((math.cos(angle),math.sin(angle)))
        distance=(randomizer.random()**.72)*spread
        x,y=direction*distance
        size=randomizer.uniform(.018,.083)
        stroke(scene,"Flying sparks",[(x,y,size*.26),(x+direction.x*size*.66,
               y+direction.y*size*.66,size*.40),(x+direction.x*size,
               y+direction.y*size,.002)],mat,origin)


def fire(scene, origin, styles, phase, scale):
    # The hot base travels across the floor. Upper tongues shear at different rates.
    glow(scene,"Heat on floor",(origin[0],origin[1]-.27*scale,origin[2]),2.42*scale,.47*scale,styles["heat"])
    for i,(offset,size,lean) in enumerate([
        (-.75,.68,-.17),(-.51,.99,.20),(-.21,1.18,.02),(.09,.88,.22),(.31,1.08,-.11),
        (.54,.79,.23),(.75,.66,.18)
    ]):
        sway=math.sin(phase*1.26+i*1.28)*.14
        lx=origin[0]+offset*scale
        ly=origin[1]-.25*scale
        z=origin[2]+.004*i+.013
        path=[(0,0,.26),(-.049,.19*size,.41),(.063,.42*size,.37),
              (-.075+sway,.63*size,.24),(.055+lean*.6,.81*size,.138),
              (.105+lean+sway,1.04*size,.024)]
        stroke(scene,"Overlapping flame",flowing(path),styles["fire"],(lx,ly,z),scale)
        flicker=.67+.29*math.cos(i*.97+phase)**2
        inner=[(-.042,.02,.073),(.021,.17*size*flicker,.15),
               (-.036+sway*.25,.34*size*flicker,.121),(.072+sway*.45,.62*size*flicker,.058),
               (.058+lean*.61,.80*size*flicker,.006)]
        stroke(scene,"Hot tongue",flowing(inner),styles["core"],(lx,ly,z+.006),scale)


def frost_burst(scene, origin, styles, phase, scale):
    glow(scene,"Cold ground flash",origin,2.17*scale,.91*scale,styles["cold"])
    for i,(angle,reach) in enumerate([(15,1.18),(38,.90),(63,.76),(79,.99),(99,1.15),
                                     (120,.89),(139,1.11),(161,1.24)]):
        direction=Vector((math.cos(math.radians(angle)),math.sin(math.radians(angle))))
        bend=math.sin(i*1.63+phase)*.10
        path=[(0,0,.111),(.18*direction.x,.18*direction.y,.17),
              (.51*direction.x+bend,.47*direction.y,.095),
              (reach*direction.x,reach*.58*direction.y,.008)]
        stroke(scene,"Frost wake",path,styles["frost"],(origin[0],origin[1],origin[2]+i*.007+.01),scale)


def dust_front(scene, origin, styles, phase, scale):
    glow(scene,"Impact scatter",origin,2.38*scale,.68*scale,styles["dust"])
    for i,(turn,x) in enumerate([(-1,.2),(-1,.55),(-1,.9),(1,.15),(1,.40),(1,.75)]):
        height=.23+.17*math.sin(i*1.4+.4)**2
        path=[(0,0,.17),(turn*.21,.047,.24),(turn*.43,height*.75,.173),
              (turn*.66,height,.116),(turn*(.75+x*.4),height*(1.1-phase*.12),.009)]
        stroke(scene,"Impact fan",flowing(path),styles["dust_ribbon"],
               (origin[0]+turn*x*.14,origin[1],origin[2]+i*.007+.015),scale)


def texture_scene(name, size, path):
    scene=render_scene(name,size,path,dark=True)
    scene.render.film_transparent=True
    scene.render.image_settings.color_mode="RGBA"
    scene.view_settings.view_transform="Standard"
    scene.cycles.samples=16
    scene.cycles.use_denoising=False
    camera(scene,(0,0,6),(0,0,0),2.0)
    return scene


def bake_sources(out, styles):
    texture_folder=out/"Textures"
    # Runtime-facing bakes have a 16:9 transparent center and hand-drawn silhouette.
    white=ink("White wind mask","FFFFFF","FFFFFF",strength=1,opacity=.94)
    masks=[
        ("Dash Edge Mask","Dash_Edge.png",[
            [(-.992,.46,.006),(-.807,.381,.075),(-.661,.303,.043),(-.525,.267,.010)],
            [(-.994,.235,.013),(-.870,.210,.044),(-.733,.180,.028),(-.650,.166,.010)],
            [(-.984,-.478,.007),(-.837,-.377,.052),(-.676,-.295,.037),(-.504,-.243,.008)],
            [(-.977,-.188,.005),(-.862,-.159,.025),(-.692,-.124,.018),(-.568,-.10,.004)],
        ]),
        ("Updraft Edge Mask","Updraft_Edge.png",[
            [(-.858,-.551,.012),(-.815,-.381,.073),(-.800,-.207,.079),(-.814,.095,.009)],
            [(-.964,-.381,.008),(-.926,-.260,.037),(-.930,-.088,.041),(-.946,.144,.007)],
            [(-.575,-.544,.008),(-.535,-.443,.046),(-.500,-.294,.030),(-.487,-.163,.006)],
            [(-.369,-.553,.002),(-.344,-.491,.026),(-.330,-.400,.024),(-.331,-.319,.004)],
        ]),
    ]
    for scene_name,filename,paths in masks:
        scene=texture_scene(scene_name,(768,432),texture_folder/filename)
        for i,path in enumerate(paths):
            stroke(scene,"Edge stroke",path,white)
            mirrored=[(-x,y+(.017 if i%2==0 else -.009),w*.91) for x,y,w in path]
            stroke(scene,"Edge stroke",mirrored,white)
    for key,filename,fn,offset in [
        ("Fire Tongue Atlas","FireTongue_2x2.png",fire,-.17),
        ("Frost Wake Atlas","FrostWake_2x2.png",frost_burst,-.16),
        ("Crash Dust Atlas","CrashDust_2x2.png",dust_front,-.08)
    ]:
        scene=texture_scene(key,(768,768),texture_folder/filename)
        for i,(x,y) in enumerate([(-.5,.5),(.5,.5),(-.5,-.5),(.5,-.5)]):
            fn(scene,(x,y+offset,0),styles,i*.87,.35+i*.013)


def action_board(previews, parts, styles):
    scene=render_scene("Effect Action Studies",(1870,1140),
                       previews/"Ability VFX v02.png",dark=True)
    scene.cycles.samples=24
    scene.cycles.transparent_max_bounces=24
    camera(scene,(0,0,12),(0,0,0),9.5)
    floor(scene,"19212F",-3)
    text=styles["text"]
    # Lettering remains legible on the dark stage without filling the effect layers.
    def cell(title,x,y):
        label(scene,title,(x,y-.86,.80),.15,text,(0,0,0))
        glow(scene,"Cell ground",(x,y-.32,-.34),2.88,1.11,styles["ambient"])
        return (x,y,0)

    def fracture(name,x,y,z,scale,tilt,turn):
        part=parts.collection.objects["ReworkVFX_"+name]
        clone(scene,part,position((x,y,z),turn,scale) @ Matrix.Rotation(math.radians(tilt),4,"X"))

    x,y,_=cell("MOLLY / FIREWALL",-3.15,1.47)
    fire(scene,(x,y-.22,0),styles,.64,1.10)
    flecks(scene,19,(x,y-.32,.28),styles["core"],26,1.11,upward=True)
    arc(scene,"Hot reflected rim",(x,y-.36,.22),styles["fire"],1.14,.28,.16,math.tau-.25,.055)

    x,y,_=cell("FROST / FREEZE",0,1.47)
    frost_burst(scene,(x,y-.26,0),styles,.34,1.03)
    arc(scene,"Crystalline edge",(x,y-.33,.12),styles["frost"],1.07,.32,.08,math.tau-.14,.068)
    for i,(dx,dy,turn,scale) in enumerate([(-.87,-.01,-37,.75),(-.50,.15,24,1.14),
            (-.24,-.07,-23,.93),(.00,.11,-6,1.33),(.32,.08,-28,1.08),(.68,-.03,27,.77),
            (.53,.55,-39,.51),(-.69,.48,51,.53)]):
        fracture("FrostChip",x+dx,y+dy,.20+i*.012,scale,-75,turn)
    flecks(scene,32,(x,y-.24,.36),styles["frost"],21,1.03,upward=True)

    x,y,_=cell("CRASH DOWN",3.15,1.47)
    dust_front(scene,(x,y-.17,0),styles,.57,1.12)
    arc(scene,"Expanding impact",(x,y-.20,.11),styles["dust_ribbon"],1.17,.36,.1,math.tau-.18,.086)
    arc(scene,"Inner pressure edge",(x,y-.22,.13),styles["dust_ribbon"],.76,.24,2.47,6.31,.041)
    for dx,dy,turn,scale in [(-.83,-.17,20,.62),(-.61,.16,-26,.51),(-.34,.35,11,.60),
                             (.06,.49,29,.64),(.27,.20,-19,.74),(.58,.28,14,.53),(.89,-.12,-34,.68)]:
        fracture("CrashChip",x+dx,y+dy,.24,scale,-65,turn)
    flecks(scene,45,(x,y-.20,.40),styles["dust_ribbon"],18,1.08,upward=True)

    x,y,_=cell("RECON SCAN",-3.15,-1.28)
    glow(scene,"Pulse volume",(x,y+.11,.02),2.12,1.72,styles["signal"])
    for i,(rx,ry,tilt,start,stop,width) in enumerate([(1.02,.78,.02,.20,6.29,.045),
            (.98,.32,.21,1.13,7.12,.032),(.84,.27,-.10,3.14,6.52,.021),
            (.66,.75,-.42,3.77,6.81,.022)]):
        arc(scene,"Spherical wave",(x,y+.11,.12+i*.02),styles["scan"],rx,ry,start,stop,width,tilt=tilt)
    glow(scene,"Scanning point",(x,y+.11,.31),.22,.22,styles["seed"])
    flecks(scene,55,(x,y+.13,.26),styles["scan"],21,.99)

    x,y,_=cell("HEAL / BARRIER",0,-1.28)
    glow(scene,"Healing ground volume",(x,y-.23,.03),2.25,.52,styles["green_glow"])
    for i,(width,height,tilt) in enumerate([(1.02,.35,.24),(.89,.47,-.17),(.67,.32,.29)]):
        arc(scene,"Healing ribbon",(x,y+.15+i*.04,.11+i*.012),styles["heal"],
            width,height,.13+i*.85,4.85+i*.37,.069-i*.008,tilt=tilt)
    for i,(dx,dy,size) in enumerate([(.62,.45,.45),(.83,.15,.32),(.36,.63,.35)]):
        fracture("BarrierHexTile_Energy",x+dx,y+dy,.14+i*.01,size,17,6)
    flecks(scene,51,(x,y+.19,.27),styles["heal"],24,1.03)

    x,y,_=cell("RECALL",3.15,-1.28)
    glow(scene,"Phase flash",(x,y+.08,.02),1.82,1.31,styles["phase_glow"])
    for i,(dx,dy,length) in enumerate([(-.36,-.24,1.24),(-.20,-.12,1.19),
                                      (.03,.03,1.13),(.23,.18,.94),(.35,.29,.84)]):
        shape=[(-length*.55,-.11,.018),(-length*.30,-.079,.101),(0,.082,.113),
               (.24,.24,.101),(.48,.29,.022),(.56,.34,.007)]
        stroke(scene,"Phase ribbons",shape,styles["recall"],(x+dx,y+dy,.13+i*.014))
    arc(scene,"Collapse edge",(x,y-.13,.17),styles["recall"],.95,.38,.05,5.91,.043,tilt=.26)
    flecks(scene,72,(x,y+.14,.34),styles["recall"],18,1.03)


def remake_fire_meshes(p):
    hot=material("Hot flame shell","EC602B",emission=.48)
    core=material("Hot inner edge","FFBB63",emission=.58,alpha=.84)
    # Two alternating sheets share their foot and can be mirrored and tapered in Studio.
    shapes={
        "FlameOuter_Energy":(-.036,.044,hot,[
            (-.311,0),(-.404,.093),(-.420,.281),(-.305,.418),(-.268,.597),
            (-.323,.787),(-.163,.743),(-.099,.589),(-.045,.708),(-.061,.862),
            (-.133,1.063),(-.008,1.017),(.115,.879),(.174,.707),(.164,.545),
            (.218,.415),(.286,.508),(.279,.669),(.367,.548),(.407,.390),
            (.375,.208),(.281,.073),(.187,0)
        ]),
        "FlameCore_Energy":(-.052,-.031,core,[
            (-.182,0),(-.242,.106),(-.211,.266),(-.104,.357),(-.085,.457),
            (-.136,.590),(-.040,.536),(.019,.407),(.061,.516),(.061,.675),
            (.005,.842),(.109,.780),(.170,.634),(.169,.494),(.119,.366),
            (.188,.246),(.174,.12),(.126,0)
        ]),
        "FlameWallSegment":(-.094,.094,hot,[
            (-.497,0),(-.575,.146),(-.546,.329),(-.487,.444),(-.451,.661),
            (-.478,.844),(-.330,.786),(-.280,.606),(-.184,.682),(-.159,.817),
            (-.185,1.053),(-.086,1.009),(.018,.849),(.052,.712),(.102,.721),
            (.153,.853),(.164,1.079),(.099,1.250),(.251,1.144),(.328,.999),
            (.314,.801),(.339,.651),(.417,.694),(.463,.832),(.536,.691),
            (.533,.492),(.583,.285),(.530,.074),(.489,0)
        ]),
        "FlameWallCrest_Energy":(-.111,-.080,core,[
            (-.435,.312),(-.423,.509),(-.465,.755),(-.343,.689),(-.269,.443),
            (-.212,.473),(-.143,.639),(-.167,.968),(-.050,.832),(.012,.604),
            (.086,.511),(.173,.720),(.220,.957),(.168,1.162),(.277,1.041),
            (.316,.865),(.283,.595),(.325,.453),(.427,.515),(.480,.674),
            (.505,.445),(.449,.354),(.309,.340),(.228,.389),(.248,.639),
            (.125,.412),(.01,.299),(-.128,.361),(-.067,.623),(-.176,.448),
            (-.252,.350),(-.340,.356),(-.384,.463)
        ]),
    }
    for name,(near,far,color,shape) in shapes.items():
        old=p.collection.objects["ReworkVFX_"+name]
        mesh=old.data
        bpy.data.objects.remove(old,do_unlink=True)
        if not mesh.users:
            bpy.data.meshes.remove(mesh)
        p.silhouette(name,shape,near,far,color)


def build_fx(out, previews):
    scene=bpy.data.scenes.new("ReworkVFX")
    parts=Parts("ReworkVFX")
    parts.collection["kind"]="vfx"
    scene.collection.children.link(parts.collection)
    visual_effects(parts)
    remake_fire_meshes(parts)
    styles={
        "text":ink("Caption", "93A5BC","D8E8F3", strength=.86),
        "ambient":ink("Soft stage", "3E5067","516C8C",opacity=.27,radial=True),
        "fire":ink("Oxide flame edge","E24823","FF8841",strength=1.34,opacity=.92),
        "core":ink("Molten tongue","FF993D","FFF0B3",strength=1.45,opacity=.86),
        "heat":ink("Heat pool","7C251C","E04A1D",opacity=.78,radial=True),
        "frost":ink("Frozen front","317EAD","CBEFFF",strength=1.33,opacity=.9),
        "cold":ink("Cold impact glow","1C3A65","58ABDA",opacity=.82,radial=True),
        "dust":ink("Pale sand cloud","684B42","C58E62",opacity=.72,radial=True),
        "dust_ribbon":ink("Pressure dust","90614E","FFD397",strength=1.12,opacity=.75),
        "signal":ink("Scan volume","173461","34B7E3",opacity=.63,radial=True),
        "seed":ink("Scan origin","46B6E7","F0FFFF",strength=1.90,radial=True),
        "scan":ink("Scan edge","43A6D4","D0FCFF",strength=1.44,opacity=.86),
        "green_glow":ink("Healing haze","205341","79D6A9",opacity=.68,radial=True),
        "heal":ink("Healing edge","41B88E","CAFFD8",strength=1.38,opacity=.91),
        "phase_glow":ink("Phase flash blob","15465E","52CED8",opacity=.62,radial=True),
        "recall":ink("Phase streaks","3279A4","B0FFF5",strength=1.50,opacity=.92),
    }
    # Captions are solid ink and use the same emission color on every glyph.
    caption=styles["text"]
    tree=caption.node_tree
    output=next(n for n in tree.nodes if n.type=="OUTPUT_MATERIAL")
    emit=next(n for n in tree.nodes if n.type=="EMISSION")
    for link in list(emit.inputs["Color"].links):
        tree.links.remove(link)
    emit.inputs["Color"].default_value=rgba("B7CADC")
    tree.links.new(emit.outputs[0],output.inputs["Surface"])
    bake_sources(out,styles)
    action_board(previews,parts,styles)
