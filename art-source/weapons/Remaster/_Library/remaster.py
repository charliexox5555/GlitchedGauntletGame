"""Original stylised remaster geometry, executed through the Blender MCP worker.

All source files are read-only. +X muzzle, +Z up, grip origin, studs.
Stages: concept blockout -> final geometry -> UV/materials -> rig -> actions -> review.
"""
import bpy, bmesh, math, os, sys, json
from mathutils import Vector, Matrix
ROOT=r'C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame'
BASE=ROOT+'/art-source/weapons/Remaster'
LIB=BASE+'/_Library'
CONTRACTS=json.load(open(LIB+'/source_contracts.json'))
ORDER=['Vandal','Classic','Bulldog','Phantom','Guardian','Stinger','Spectre','Shorty','Ghost','Sheriff','Judge','Bucky','Marshal','Outlaw','Operator','Ares','Odin','Knife']
DESIGNS={
 'Vandal':('Rifle','reflex','Rifle','split wedge / triangular stock / swept magazine'),
 'Classic':('Sidearm','notch','Pistol','stepped slide / scalloped dust cover / two-hand grip'),
 'Bulldog':('Rifle','aperture','Rifle','bullpup / rear magazine / broad shoulder chassis'),
 'Phantom':('Rifle','holo','Rifle','integral faceted suppressor / floating cheek comb'),
 'Guardian':('Rifle','aperture','Rifle','long tapered receiver / short magazine / precision rib'),
 'Stinger':('SMG','aperture','SMG','folding twin-beam stock / grip magazine / stubby shroud'),
 'Spectre':('SMG','reflex','SMG','telescoping stock / swept magazine / suppressor'),
 'Shorty':('Sidearm','bead','Shell','side-by-side break barrels / compact ribbed fore-end'),
 'Ghost':('Sidearm','notch','Pistol','long ventless slide / polygon suppressor / wrap grip'),
 'Sheriff':('Sidearm','notch','HeavyPistol','faceted six-shot cylinder / sculpted barrel spine'),
 'Judge':('Shotgun','rib','Shell','broad high receiver / longitudinal drum / short rib'),
 'Bucky':('Shotgun','bead','Shell','sculpted ribbed pump / long tube / stepped shoulder stock'),
 'Marshal':('Sniper','scope35','Sniper','lever loop / slim 3.5x scope / long tapered fore-end'),
 'Outlaw':('Sniper','scope35','Sniper','stacked break barrels / twin visible rounds / 3.5x scope'),
 'Operator':('Sniper','scope25','Operator','premium 2.5x scope / heavy fluted barrel / adjustable stock'),
 'Ares':('Machine gun','bigreflex','Belt','wide drum / cooling jacket / broad wedge stock'),
 'Odin':('Machine gun','holo','Belt','hinged feed cover / exposed linked belt / deep ammunition box'),
 'Knife':('Melee','blade','None','faceted drop point / satin edge planes / chamfered guard')}
PALETTE={'Body':(0x414C61,.25,.42),'Panel':(0x73849C,.22,.38),'Dark':(0x19212E,.1,.53),
 'Metal':(0x7D8995,.82,.29),'Grip':(0x29303D,0,.64),'Accent':(0xBA9157,.65,.34),'Neon':(0x43C7D1,.1,.33)}
MATS={}; GUN=''; COL=None; REFS=None; PARTS=[]; CONCEPT=False

def linear(v): return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def rgba(h): return tuple(linear(((h>>s)&255)/255) for s in (16,8,0))+(1,)

def materials():
    global MATS
    # Deterministic trim: seven clean material bands, no random texture detail.
    image=bpy.data.images.new('GG_Shared_Clean_Trim',width=448,height=64)
    pixels=[]
    for y in range(64):
        for x in range(448):
            role=list(PALETTE)[x//64]; c=rgba(PALETTE[role][0]); t=.94+.06*y/63
            pixels.extend([c[0]*t,c[1]*t,c[2]*t,1])
    image.pixels.foreach_set(pixels)
    image.filepath_raw=LIB+'/clean-trim.png'; image.file_format='PNG'; image.save(); image.pack()
    rough=bpy.data.images.new('GG_Shared_Roughness_Trim',width=448,height=64)
    rough.colorspace_settings.name='Non-Color'
    rough.pixels.foreach_set([v for y in range(64) for x in range(448) for v in (PALETTE[list(PALETTE)[x//64]][2],)*3+(1,)])
    rough.filepath_raw=LIB+'/roughness-trim.png'; rough.file_format='PNG'; rough.save(); rough.pack()
    for i,(role,(h,metal,r)) in enumerate(PALETTE.items()):
        mat=bpy.data.materials.new(role); mat.use_nodes=True; mat.diffuse_color=rgba(h)
        mat['role']=role; mat['skin']='Default'; mat['rbx_color']=f'{h:06X}'
        mat['rbx_material']='Neon' if role=='Neon' else ('Metal' if metal>.5 else 'SmoothPlastic')
        nt=mat.node_tree; bs=nt.nodes.get('Principled BSDF'); bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=r
        uv=nt.nodes.new('ShaderNodeUVMap'); uv.uv_map='TrimUV'
        tex=nt.nodes.new('ShaderNodeTexImage'); tex.image=image; nt.links.new(uv.outputs[0],tex.inputs['Vector']); nt.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
        rt=nt.nodes.new('ShaderNodeTexImage'); rt.image=rough; nt.links.new(uv.outputs[0],rt.inputs['Vector']); nt.links.new(rt.outputs['Color'],bs.inputs['Roughness'])
        if role=='Neon': bs.inputs['Emission Color'].default_value=rgba(h); bs.inputs['Emission Strength'].default_value=.5
        MATS[role]=mat
    return MATS

def mesh(name,verts,faces,role='Body',bone='Root',bevel=.009,collection=None):
    # Keep the material suffix last even for repeated ribs and panels.
    stem=name; serial=1
    while bpy.data.objects.get(name+'_'+role):
        serial+=1; name=stem+f'{serial:02d}'
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    ob=bpy.data.objects.new(name+'_'+role,me); (collection or COL).objects.link(ob)
    mat=MATS[role]
    if collection is not None:
        refname='Reference_'+role
        ref=bpy.data.materials.get(refname)
        if ref is None:
            ref=bpy.data.materials.new(refname); ref.use_nodes=True
            color=0xB99B80 if role=='Panel' else PALETTE[role][0]
            ref.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=rgba(color)
            ref.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.56
        mat=ref
    ob.data.materials.append(mat); ob['role']=role; ob['rig_bone']=bone
    if bevel and not CONCEPT:
        mod=ob.modifiers.new('Craft chamfer','BEVEL'); mod.width=bevel; mod.segments=1; mod.affect='EDGES'
        mod.limit_method='ANGLE'; mod.angle_limit=math.radians(28)
        bpy.context.view_layer.objects.active=ob; ob.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name); ob.select_set(False)
    me=ob.data
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=bm.faces[:]); bm.to_mesh(me); bm.free()
    if not CONCEPT:
        for p in me.polygons: p.use_smooth=True
        me.set_sharp_from_angle(angle=math.radians(38))
        normal=ob.modifiers.new('Area weighted normals','WEIGHTED_NORMAL'); normal.keep_sharp=True; normal.weight=40
    if collection is None: PARTS.append(ob)
    return ob

def prism(name,pts,width,role='Body',bone='Root',y=0,bevel=.009,collection=None):
    n=len(pts); vs=[(x,y-width/2,z) for x,z in pts]+[(x,y+width/2,z) for x,z in pts]
    fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vs,fs,role,bone,bevel,collection)

def box(name,x0,x1,z0,z1,width,role='Body',bone='Root',y=0,bevel=.009,collection=None):
    return prism(name,[(x0,z0),(x1,z0),(x1,z1),(x0,z1)],width,role,bone,y,bevel,collection)

def beam(name,a,b,width,depth,role='Dark',bone='Root',collection=None):
    a,b=Vector(a),Vector(b); d=b-a; mid=(a+b)/2
    ob=box(name,-width/2,width/2,-d.length/2,d.length/2,depth,role,bone,bevel=min(width,depth)*.12,collection=collection)
    # Construct matrix explicitly: dependency graph may not have evaluated transforms yet.
    transform=Matrix.Translation(mid) @ d.to_track_quat('Z','Y').to_matrix().to_4x4()
    ob.data.transform(transform)
    return ob

def lathe(name,stations,y,z,role='Metal',bone='Root',n=12,cap=True,collection=None):
    # Cross-sections perpendicular to +X; modelled radial steps give clean edge highlights.
    vs=[(x,y+r*math.cos(2*math.pi*i/n),z+r*math.sin(2*math.pi*i/n)) for x,r in stations for i in range(n)]
    fs=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(stations)-1) for i in range(n)]
    if cap: fs.extend([tuple(range(n-1,-1,-1)),tuple((len(stations)-1)*n+i for i in range(n))])
    return mesh(name,vs,fs,role,bone,0,collection)

def tube(name,x0,x1,ro,ri,y,z,role='Metal',bone='Root',n=12):
    return lathe(name,[(x0,ro*.94),(x0+.008,ro),(x1-.008,ro),(x1,ro*.94),(x1,ri),(x0,ri),(x0,ro*.94)],y,z,role,bone,n,False)

def ring_profile(name,outer,inner,width,role='Dark',bone='Root',y=0):
    n=len(outer); vs=[(x,yy,z) for yy in (y-width/2,y+width/2) for pts in (outer,inner) for x,z in pts]
    fs=[]
    for i in range(n):
        j=(i+1)%n
        fs.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
    return mesh(name,vs,fs,role,bone,.004)

def grip(d,zmin=None):
    zmin=max(d['bounds'][2][0],-.37) if zmin is None else zmin
    if GUN=='Marshal': zmin=-.18
    pts=[(-.17,zmin+.04),(.04,zmin),(.18,.11),(.08,.19),(-.10,.12)]
    prism('Grip',pts,.235,'Grip',bevel=.018)
    for side in [-1,1]:
        prism('GripInset',[(x*.76,z*.79) for x,z in pts],.009,'Dark',y=side*.120,bevel=.004)
        for j in range(3):
            z=zmin+.08+j*.075
            prism('GripChevron', [(-.102,z),(.067,z+.035),(.075,z+.052),(-.10,z+.018)],.008,'Grip',y=side*.129,bevel=.002)
    box('GripHeel',-.18,.07,zmin,zmin+.045,.25,'Dark',bevel=.01)

def trigger_and_controls(d):
    bones=d['bones']; trig=bones.get('Trigger')
    if trig:
        x,y,z=trig['head']
        prism('Trigger',[(x-.015,z+.01),(x+.027,z),(x+.027,z-.055),(x+.005,z-.11),(x-.026,z-.12),(x-.02,z-.085),(x+.002,z-.045)],.036,'Accent','Trigger',bevel=.004)
        outer=[(x-.10,z+.035),(x+.21,z+.035),(x+.25,z-.12),(x+.19,z-.19),(x-.11,z-.19),(x-.15,z-.12)]
        inner=[(x-.075,z+.006),(x+.18,z+.006),(x+.213,z-.11),(x+.175,z-.154),(x-.085,z-.154),(x-.111,z-.105)]
        if 'Lever' not in bones: ring_profile('TriggerGuard',outer,inner,.07,'Dark')
    for name in ['FireSelector','SlideCatch','MagRelease','BreechLatch','CylinderRelease','Hammer']:
        if name not in bones: continue
        x,y,z=bones[name]['head']; y=.157 if y>=0 else -.157
        if name=='Hammer':
            rise=.15 if GUN=='Sheriff' else .09
            prism(name,[(x-.025,z-.025),(x+.02,z-.025),(x+.035,z+rise-.02),(x-.055,z+rise),(x-.055,z+rise-.033)],.05,'Metal',name,bevel=.005)
        else:
            prism(name,[(x-.04,z-.015),(x+.09,z-.012),(x+.105,z+.013),(x-.025,z+.027)],.035,'Accent' if name in ['FireSelector','BreechLatch'] else 'Metal',name,y,bevel=.004)
    if 'CharmPoint' in d['attachments']:
        x,y,z=d['attachments']['CharmPoint']['pos']
        outer=[(x-.035,z-.035),(x+.035,z-.035),(x+.035,z+.035),(x-.035,z+.035)]
        inner=[(x-.018,z-.018),(x+.018,z-.018),(x+.018,z+.018),(x-.018,z+.018)]
        ring_profile('CharmLoop',outer,inner,.026,'Metal','Charm' if 'Charm' in bones else 'Root',y=max(.16,y))

def stock(d,top):
    rear=d['bounds'][0][0]; end=-.25
    if GUN in ['Bulldog']: # bullpup filled chassis behind trigger, magazine remains open beneath.
        prism('BullpupStock',[(rear,-.045),(rear+.06,top+.09),(-.32,top+.08),(-.16,.08),(-.41,.035)],.31,'Body',bevel=.02)
        prism('CheekComb',[(rear+.09,top+.055),(-.39,top+.055),(-.48,top+.13),(rear+.16,top+.13)],.25,'Panel',bevel=.014)
    else:
        narrow=GUN in ['Stinger','Spectre']
        if narrow:
            for zz in [top,top-.14]: beam('StockBeam',(rear+.03,0,zz),(-.22,0,zz),.055,.14,'Metal')
            box('StockShoe',rear,rear+.12,-.06,top+.055,.23,'Dark',bevel=.018)
        else:
            outer=[(rear,-.105),(rear+.035,top+.07),(end-.02,top+.055),(end+.04,top-.075),(-.59,-.06)]
            inner=[(rear+.15,-.03),(rear+.17,top-.035),(end-.13,top-.025),(end-.19,top-.09),(-.64,.005)]
            ring_profile('OpenStock',outer,inner,.245,'Body')
            prism('CheekComb',[(rear+.11,top+.035),(-.40,top+.035),(-.47,top+.11),(rear+.17,top+.11)],.255,'Panel',bevel=.012)
        box('ButtPad',rear-.006,rear+.045,-.10,top+.075,.28,'Grip',bevel=.012)
        if GUN=='Operator':
            box('StockAdjuster',rear+.18,rear+.24,-.10,top-.08,.29,'Accent',bevel=.008)

def ammo(kind,name,pos,bone='Root',direction='X',collection=None):
    specs={'Pistol':(.125,.023),'HeavyPistol':(.18,.027),'SMG':(.15,.024),'Rifle':(.23,.027),'Shell':(.24,.043),'Sniper':(.32,.034),'Operator':(.40,.042),'Belt':(.255,.030)}
    length,r=specs[kind]; x,y,z=pos
    # No weapons instructions: these are stylised game-art rounds sized in game units.
    case=.79*length if kind!='Shell' else .24*length
    ob=lathe(name+'Case',[(x,r*.94),(x+.008,r*1.08),(x+.015,r),(x+case,r),(x+case+.008,r*.83)],y,z,'Accent',bone,10,True,collection)
    if kind=='Shell':
        lathe(name+'Hull',[(x+case,r),(x+length-.01,r),(x+length,r*.90)],y,z,'Body',bone,10,True,collection)
    else:
        lathe(name+'Tip',[(x+case,r*.82),(x+length*.88,r*.77),(x+length,r*.10)],y,z,'Metal',bone,10,True,collection)
    return ob

def magazine(d,kind):
    if 'Mag' not in d['bones'] and 'AmmoBox' not in d['bones']: return
    bone='Mag' if 'Mag' in d['bones'] else 'AmmoBox'
    p=[v['bounds'] for v in d['parts'].values() if v['bone']==bone][0]
    x0,x1=p[0]; z0,z1=p[2]; w=.19 if kind not in ['Shell','Belt'] else .27
    if GUN in ['Ares','Judge']:
        cx=(x0+x1)/2; cz=(z0+z1)/2; r=(z1-z0)/2
        lathe('Drum',[(x0,r*.84),(x0+.025,r),(x1-.025,r),(x1,r*.84)],0,cz,'Dark','Mag',16)
        tube('DrumFace',x1-.02,x1+.008,r*.77,r*.58,0,cz,'Panel','Mag',16)
        lathe('DrumHub',[(x1,.085),(x1+.025,.071)],0,cz,'Metal','Mag',10)
        for i in range(6):
            a=2*math.pi*i/6; yy=r*.80*math.cos(a); zz=cz+r*.80*math.sin(a)
            beam('DrumRib',(x0+.04,yy,zz),(x1-.04,yy,zz),.025,.025,'Grip','Mag')
        ammo(kind,'VisibleFeed',(x0+.04,0,z1+.025),'Mag')
        return
    if GUN=='Odin':
        prism('AmmunitionBox',[(x0,z0+.045),(x0+.04,z0),(x1-.04,z0),(x1,z0+.05),(x1,z1),(x0,z1)],.38,'Grip',bone,bevel=.018)
        for side in [-1,1]:
            box('BoxFace',x0+.055,x1-.055,z0+.07,z1-.05,.012,'Body',bone,side*.196,bevel=.012)
        return
    pistol=GUN in ['Classic','Ghost']
    curve=.06 if GUN in ['Vandal','Spectre'] else .0
    pts=[(x0,z1),(x1,z1),(x1+curve*.4,(z0+z1)/2),(x1+curve,z0+.045),(x1+curve-.02,z0),(x0+curve,z0),(x0+curve*.4,(z0+z1)/2)]
    prism('Magazine',pts,w,'Dark',bone,bevel=.012)
    box('MagazineShoe',x0+curve-.015,x1+curve+.02,z0-.005,z0+.045,w+.04,'Panel',bone,bevel=.009)
    if not pistol:
        for side in [-1,1]:
            for j in range(2):
                xx=x0+.07+j*max(.05,(x1-x0-.14)/2)
                prism('MagFlute',[(xx,z0+.09),(xx+.023,z0+.09),(xx+.01,z1-.06),(xx-.013,z1-.06)],.008,'Grip',bone,side*(w/2+.004),bevel=.002)
            box('RoundWindow',x0+.035,x1-.035,z1-.105,z1-.055,.009,'Accent',bone,side*(w/2+.006),bevel=.003)
    ammo(kind,'MagazineRound',(x0+.02,0,z1+.016),bone)

def moving_mechanism(d):
    for bone in ['Bolt','ChargingHandle','Pump','FeedCover','Lever','Crane','EjectorRod','Speedloader']:
        if bone not in d['bones']: continue
        ps=[v['bounds'] for v in d['parts'].values() if v['bone']==bone]
        if not ps: continue
        p=ps[0]; (x0,x1),(y0,y1),(z0,z1)=p
        if bone=='Pump':
            prism('Pump',[(x0,z0+.04),(x0+.05,z0),(x1-.04,z0),(x1,z0+.04),(x1-.025,z1),(x0+.025,z1)],.31,'Grip',bone,bevel=.016)
            for side in [-1,1]:
                for i in range(5):
                    xx=x0+.10+i*(x1-x0-.2)/4
                    prism('PumpRib',[(xx,z0+.025),(xx+.026,z0+.02),(xx+.026,z1-.025),(xx,z1-.025)],.014,'Dark',bone,side*.160,bevel=.003)
        elif bone=='Lever':
            ring_profile('LeverLoop',[(x0,z0+.045),(x1-.03,z0),(x1,z1),(x0+.15,z1+.015)],[(x0+.08,z0+.09),(x1-.09,z0+.065),(x1-.075,z1-.035),(x0+.18,z1-.035)],.065,'Metal',bone)
        elif bone=='FeedCover':
            prism('FeedCover',[(x0,z0),(x1,z0),(x1-.045,z1),(x0+.04,z1)],.31,'Panel',bone,bevel=.014)
        elif bone=='Bolt':
            z=(z0+z1)/2; yy=-.151
            box('BoltCarrier',x0,x1,z0,z1,.018,'Metal',bone,yy-.009,bevel=.004)
            if GUN=='Operator':
                beam('BoltHandle',(x0+.10,0,z),(x0+.10,-.23,z-.07),.032,.032,'Metal',bone)
                box('BoltKnob',x0+.06,x0+.14,z-.11,z-.035,.07,'Grip',bone,-.235,bevel=.012)
        elif bone=='ChargingHandle':
            y=.176
            box(bone,x0,x1,z0,z1,.045,'Metal',bone,y,bevel=.006)
            box('HandlePad',x0,x0+.055,z0-.012,z1+.008,.07,'Grip',bone,y+.022,bevel=.007)
        elif bone in ['Crane','EjectorRod']:
            box(bone,x0,x1,z0,z1,.045,'Metal',bone,bevel=.006)
        elif bone=='Speedloader':
            lathe('Speedloader',[(x0,.10),(x1,.10)],0,(z0+z1)/2,'Dark',bone,12)

def sights(d,typ):
    at=d['attachments'].get('AimPoint',{}).get('pos')
    bore=d['attachments'].get('Muzzle',{}).get('pos',[1,0,.3])[2]
    if not at: at=[-.12,0,bore+.13]
    if typ not in ['notch','bead','rib','blade']:
        rise={'Marshal':.17,'Outlaw':.20,'Operator':.28,'Guardian':.19,'Bulldog':.30,'Phantom':.28,'Stinger':.275,'Spectre':.25}.get(GUN,.33)
        at=[at[0],0,max(at[2],bore+rise)]
    x,y,z=at
    if typ=='blade': return at
    if typ in ['notch','bead','rib']:
        # Sight datum rests at top of small post; notch remains completely open.
        x=d['bounds'][0][0]+.09
        z=bore+.10 if GUN=='Sheriff' else max(z,bore+.145); at=[x,0,z]
        end=d['attachments']['Muzzle']['pos'][0]
        front=end-.09 if GUN!='Ghost' else 1.04
        if typ=='notch':
            for side in [-1,1]: box('RearNotchEar',x-.028,x+.028,z-.023,z+.005,.025,'Dark','Slide' if 'Slide' in d['bones'] else 'Root',side*.055,bevel=.003)
            box('FrontPost',front-.015,front+.018,z-.04,z,.022,'Metal','Slide' if 'Slide' in d['bones'] else 'Root',bevel=.003)
            box('FrontPip',front-.019,front-.016,z-.014,z-.004,.014,'Neon','Slide' if 'Slide' in d['bones'] else 'Root',bevel=.001)
        else:
            ribbone='Barrels' if GUN=='Shorty' else 'Root'
            ribstart=d['bones']['Barrels']['head'][0] if GUN=='Shorty' else x
            box('SightRib',ribstart,front,z-.045,z-.017,.042,'Dark',ribbone,bevel=.004)
            box('RibSupport',ribstart,front,bore+.045,z-.04,.048,'Body',ribbone,bevel=.005)
            lathe('FrontBead',[(front-.011,.012),(front+.011,.012)],0,z-.008,'Accent','Barrels' if 'Barrels' in d['bones'] else 'Root',8)
        return at
    if typ.startswith('scope'):
        # Open optical tube, with a sparse reticle at the objective. No opaque lens blocks ADS.
        premium=GUN=='Operator'; r=.135 if premium else .10
        x0=x+.11; x1=d['attachments']['ScopeAxis']['pos'][0]+.04
        tube('ScopeEyepiece',x0,x0+.18,r,r-.024,0,z,'Dark',n=16)
        tube('ScopeTube',x0+.15,x1-.20,r*.69,r*.52,0,z,'Body',n=16)
        tube('ScopeObjective',x1-.22,x1,r*1.05,r*.84,0,z,'Dark',n=16)
        tube('ScopeObjectiveRim',x1-.015,x1+.004,r*1.05,r*.84,0,z,'Metal',n=16)
        for xx in [x0+.24,x1-.30]:
            box('ScopeFoot',xx-.045,xx+.045,bore+.065,z-r*.70,.13,'Metal',bevel=.006)
        # Tiny sparse crosshair at optical centre, deliberately unobstructive.
        beam('ReticleHorizontal',(x1-.01,-r*.52,z),(x1-.01,r*.52,z),.0025,.0025,'Dark')
        beam('ReticleVertical',(x1-.01,0,z-r*.52),(x1-.01,0,z+r*.52),.0025,.0025,'Dark')
        box('ElevationDial',x0+.40,x0+.50,z+.055,z+(.10 if GUN=='Marshal' else .14),.12,'Grip',bevel=.012)
        if premium:
            tube('PremiumRing',x0+.12,x0+.14,r*1.04,r*.81,0,z,'Accent',n=16)
            box('ParallaxDial',x0+.37,x0+.47,z-.03,z+.04,.045,'Metal',y=-.13,bevel=.008)
        return at
    # aperture, reflex, and holo each have a different profile and opening.
    if typ=='aperture':
        r=.066; xx=x+.10
        tube('RearAperture',xx,xx+.028,r,.048,0,z,'Dark',n=12)
        box('ApertureFoot',xx-.01,xx+.04,z-.10,z-.05,.08,'Body',bevel=.005)
        box('ApertureRiser',xx-.012,xx+.045,bore+.10,z-.095,.07,'Dark',bevel=.004)
        front=min(d['attachments']['Muzzle']['pos'][0]-.26,x+.95)
        box('FrontBlade',front,front+.025,z-.08,z,.018,'Metal',bevel=.003)
        box('FrontSightBase',front-.015,front+.040,bore+.105,z-.075,.045,'Dark',bevel=.004)
        return at
    w=.115 if typ=='bigreflex' else (.105 if typ=='holo' else .082)
    h=.09 if typ in ['holo','bigreflex'] else .075; xx=x+.14
    for side in [-1,1]:
        beam('OpticUpright',(xx,side*w,z-h),(xx+.012,side*(w+.008),z+h*.82),.018,.022,'Dark')
    if typ=='holo': beam('OpticBrow',(xx+.012,-w-.008,z+h*.82),(xx+.012,w+.008,z+h*.82),.017,.024,'Dark')
    box('OpticFoot',xx-.035,xx+.11,z-h-.025,z-h,.25,'Dark',bevel=.008)
    box('OpticRiser',xx-.01,xx+.08,bore+.10,z-h-.02,.12,'Body',bevel=.007)
    # Small emissive dot is visible from the aim camera without an opaque glass pane.
    lathe('OpticDot',[(xx+.09,.0035),(xx+.093,.0035)],0,z,'Neon',n=8)
    return at

def rifle(d,kind):
    muzzle=d['attachments']['Muzzle']['pos']; end,_,bore=muzzle
    fore=d['attachments']['LeftGrip']['pos'][0]; top=bore+(.07 if GUN=='Marshal' else .11)
    bull=GUN=='Bulldog'; machine=kind=='Belt'; wide=.34 if machine else .29
    start=-.35 if not bull else -.95; stop=min(end-.28,max(.9,fore+.16))
    profile=[(start,.09),(start+.06,top+.015),(stop-.12,top),(stop,top-.065),(stop,bore-.13),(.41,bore-.15),(.32,.08)]
    prism('Receiver',profile,wide,'Body',bevel=.018)
    # Side armour panels deliberately leave uninterrupted skin artwork space.
    for side in [-1,1]:
        pts=[(start+.10,bore+.02),(start+.17,top-.035),(stop-.17,top-.045),(stop-.09,bore-.01),(stop-.14,bore-.085),(start+.11,bore-.085)]
        prism('ReceiverPanel',pts,.012,'Panel',y=side*(wide/2+.006),bevel=.006)
        box('PanelSeam',start+.19,stop-.20,bore-.103,bore-.092,.006,'Dark',y=side*(wide/2+.014),bevel=.0015)
    stock_drop={'Marshal':-.12,'Operator':0,'Guardian':-.10,'Bulldog':.005,'Phantom':0,'Spectre':.010}.get(GUN,.025)
    stock(d,bore+stock_drop); grip(d)
    if GUN=='Marshal': stop=min(stop,fore+.07)
    hgstart=max(.76,fore-.50)
    if bull: hgstart=.47
    hgend=end-(.47 if GUN in ['Phantom','Spectre'] else .30)
    if hgend>hgstart:
        pts=[(hgstart,bore-.16),(hgend-.06,bore-.14),(hgend,bore-.07),(hgend-.04,top-.025),(hgstart+.04,top-.025)]
        prism('ForeEnd',pts,.31 if machine else .27,'Grip' if GUN=='Marshal' else 'Body',bevel=.015)
        if not CONCEPT:
            for side in [-1,1]:
                for i in range(3 if not machine else 5):
                    xx=hgstart+.10+i*(hgend-hgstart-.22)/max(1,(2 if not machine else 4))
                    prism('CoolingInset',[(xx,bore-.015),(xx+.075,bore-.015),(xx+.10,bore+.035),(xx+.025,bore+.035)],.007,'Dark',y=side*(.160 if machine else .140),bevel=.003)
    # Clean barrel steps and hollow muzzle terminate EXACTLY at the contract attachment.
    suppress=GUN in ['Phantom','Spectre']
    r=.09 if kind in ['Belt','Operator'] else (.075 if suppress else .055)
    x0=max(stop-.05,.65)
    lathe('Barrel',[(x0,r*.75),(end-.21,r*.75),(end-.20,r*.9)],0,bore,'Metal',n=12)
    if suppress:
        tube('Suppressor',end-.48,end,r*1.30,r*.40,0,bore,'Dark',n=12)
        tube('SuppressorCap',end-.023,end,r*1.34,r*.40,0,bore,'Metal',n=12)
    else:
        tube('MuzzleCrown',end-.19,end,r*1.3,r*.50,0,bore,'Dark',n=12)
        tube('CrownRim',end-.018,end,r*1.34,r*.50,0,bore,'Metal',n=12)
    if GUN=='Bucky':
        lathe('ShellTube',[(.68,.055),(end-.28,.055),(end-.26,.045)],0,bore-.15,'Dark',n=12)
    if GUN=='Operator':
        for side in [-1,1]:
            beam('BarrelFlute',(stop+.05,side*.050,bore+.028),(end-.24,side*.050,bore+.028),.016,.016,'Dark')
        box('ChassisKeel',.43,fore+.10,.075,.12,.26,'Metal',bevel=.009)
    if GUN=='Odin':
        box('BeltGuide',.79,1.08,bore-.24,bore-.12,.37,'Dark',bevel=.012)
        for i in range(5):
            zz=.15+i*.055; yy=.19+i*.012
            ammo('Belt','BeltRound',(.81,yy,zz),'FeedBelt')
            box('BeltLink',.90,.96,zz-.018,zz+.018,.075,'Dark','FeedBelt',yy,bevel=.003)
    magazine(d,kind); moving_mechanism(d); trigger_and_controls(d)
    # Restrained accent inset, always independent Neon geometry.
    for side in [-1,1]: box('StatusInset',.45,.57,bore-.065,bore-.054,.005,'Neon',y=side*(wide/2+.015),bevel=.002)

def pistol(d,kind):
    end,_,bore=d['attachments']['Muzzle']['pos']; rear=d['bounds'][0][0]
    grip(d); trigger_and_controls(d)
    if GUN=='Shorty':
        base=d['bones']['Barrels']['head'][0]
        prism('Breech',[(rear,.06),(.55,.055),(.62,bore+.07),(-.15,bore+.075)],.28,'Body',bevel=.016)
        for idx,key in enumerate(['Muzzle','MuzzleLower']):
            x,y,z=d['attachments'][key]['pos']
            tube('BreakBarrel'+str(idx),base,end,.075,.037,y,z,'Dark','Barrels',12)
            tube('BreakCrown'+str(idx),end-.024,end,.078,.037,y,z,'Metal','Barrels',12)
        prism('BreakForeEnd',[(base+.13,.06),(end-.20,.06),(end-.13,bore-.04),(base+.13,bore-.035)],.27,'Grip','Barrels',bevel=.012)
        for b,key in [('ShellUpper','ChamberUpper'),('ShellLower','ChamberLower')]: ammo('Shell',b,d['attachments'][key]['pos'],b)
        return
    if GUN=='Sheriff':
        axis=d['attachments']['CylinderAxis']['pos']; cx,cy,cz=axis
        x0=d['attachments']['Chamber_01']['pos'][0]; x1=cx
        prism('RevolverFrame',[(rear,.10),(.30,.10),(.34,bore+.08),(.75,bore+.08),(.78,bore-.02),(.67,-.01),(.2,-.02)],.25,'Body',bevel=.015)
        prism('BackstrapFrame',[(rear+.02,.12),(.25,.10),(.32,bore+.02),(.28,bore+.09),(rear+.02,bore+.09),(rear-.015,bore+.05)],.24,'Body',bevel=.012)
        lathe('Cylinder',[(x0,.139),(x0+.016,.15),(x1-.016,.15),(x1,.139)],0,cz,'Dark','Cylinder',12)
        # Visible chamber bases and six subtle longitudinal flutes.
        for i in range(6):
            key='Chamber_%02d'%(i+1); p=d['attachments'][key]['pos']
            # Brass bases sit just proud of the cylinder face, avoiding coplanar flicker.
            ammo(kind,'CylinderRound'+str(i),(p[0]-.004,p[1],p[2]),'Rounds')
            a=2*math.pi*i/6
            yy=.144*math.cos(a); zz=cz+.144*math.sin(a)
            beam('CylinderFlute',(x0+.05,yy,zz),(x1-.04,yy,zz),.020,.020,'Metal','Cylinder')
        prism('BarrelSpine',[(cx,bore-.065),(end-.08,bore-.065),(end-.03,bore+.04),(end-.16,bore+.08),(cx+.05,bore+.08)],.21,'Panel',bevel=.012)
        tube('RevolverBore',cx+.02,end,.055,.031,0,bore,'Metal',n=12)
        moving_mechanism(d)
        return
    slide_end=end if GUN=='Classic' else 1.13
    prism('GripFrame',[(rear+.03,.15),(.16,.11),(.43,.15),(.48,bore-.065),(rear+.025,bore-.065)],.22,'Dark',bevel=.012)
    # Stepped slab sides are broken by wide top chamfers and rear ribs.
    prism('Slide',[(rear,bore-.06),(slide_end-.07,bore-.06),(slide_end,bore-.015),(slide_end,bore+.07),(slide_end-.08,bore+.115),(rear+.07,bore+.115),(rear,bore+.065)],.23,'Body','Slide',bevel=.012)
    for side in [-1,1]:
        prism('SlidePanel',[(rear+.10,bore+.025),(slide_end-.12,bore+.025),(slide_end-.17,bore+.08),(rear+.12,bore+.08)],.008,'Panel','Slide',side*.120,bevel=.004)
        if not CONCEPT:
            for i in range(4):
                xx=rear+.08+i*.046
                prism('SlideSerration',[(xx,bore-.025),(xx+.014,bore-.025),(xx+.035,bore+.04),(xx+.021,bore+.04)],.008,'Grip','Slide',side*.126,bevel=.0015)
    prism('DustCover',[(.12,.09),(slide_end-.07,.09),(slide_end-.035,bore-.055),(.13,bore-.055)],.215,'Panel',bevel=.012)
    barrelbone='Barrel' if 'Barrel' in d['bones'] else 'Root'
    tube('Bore',.32,end,.040,.023,0,bore,'Metal',barrelbone,12)
    if GUN=='Ghost':
        tube('PolygonSuppressor',slide_end,end,.10,.030,0,bore,'Dark',n=12)
        tube('SuppressorNose',end-.022,end,.103,.030,0,bore,'Metal',n=12)
    magazine(d,kind)
    for side in [-1,1]: box('SlideStatus',slide_end-.22,slide_end-.14,bore-.04,bore-.032,.006,'Neon','Slide',side*.119,bevel=.002)

def break_sniper(d):
    end,_,bore=d['attachments']['Muzzle']['pos']; base=d['bones']['Barrels']['head'][0]
    stock(d,bore-.10); grip(d); trigger_and_controls(d)
    prism('BreakReceiver',[(-.30,.12),(.72,.10),(base-.10,bore+.10),(-.25,bore+.09)],.30,'Body',bevel=.018)
    for i,key in enumerate(['Muzzle','MuzzleLower']):
        _,y,z=d['attachments'][key]['pos']
        tube('StackedBarrel'+str(i),base,end,.066,.032,y,z,'Metal','Barrels',12)
        tube('ChamberCollar'+str(i),base-.10,base+.045,.078,.036,y,z,'Dark','Barrels',12)
        tube('Crown'+str(i),end-.045,end,.079,.032,y,z,'Dark','Barrels',12)
    fore=d['attachments']['LeftGrip']['pos'][0]
    prism('BreakForeEnd',[(base+.16,.12),(fore+.42,.12),(fore+.49,bore-.20),(base+.16,bore-.20)],.30,'Panel','Barrels',bevel=.018)
    for bone,key in [('RoundUpper','ChamberUpper'),('RoundLower','ChamberLower')]: ammo('Sniper',bone,d['attachments'][key]['pos'],bone)

def knife(d):
    rear=d['bounds'][0][0]; base=d['attachments']['BladeBase']['pos'][0]; tip=d['attachments']['BladeTip']['pos'][0]
    prism('Grip',[(rear+.03,-.07),(base-.07,-.065),(base-.04,.065),(rear+.025,.065),(rear,.025),(rear,-.03)],.155,'Grip',bevel=.012)
    for side in [-1,1]:
        prism('GripPanel',[(rear+.11,-.052),(base-.12,-.045),(base-.10,.047),(rear+.10,.046)],.008,'Body',y=side*.081,bevel=.006)
        for i in range(3):
            xx=rear+.19+i*.11
            prism('GripRib',[(xx,-.05),(xx+.020,-.05),(xx+.04,.045),(xx+.02,.045)],.008,'Dark',y=side*.088,bevel=.002)
    box('Guard',base-.07,base+.025,-.097,.119,.195,'Dark',bevel=.009)
    # Three hand-authored blade planes each side make a crisp edge, full tang, and drop point.
    vs=[(base,0,-.067),(base,.040,.030),(base,0,.105),(tip-.24,0,.100),(tip,0,.0156),(tip-.32,0,-.057),
        (tip-.28,.018,.025),(base,-.040,.030),(tip-.28,-.018,.025)]
    fs=[(0,1,6,5),(1,2,3,6),(3,4,6),(4,5,6),(0,5,8,7),(7,8,3,2),(3,8,4),(4,8,5),(0,7,2,1)]
    mesh('Blade',vs,fs,'Metal',bevel=0)
    for side in [-1,1]:
        prism('BladeFlat',[(base+.06,.046),(tip-.32,.046),(tip-.23,.062),(base+.06,.080)],.003,'Panel',y=side*.023,bevel=.001)
        box('GuardInset',base-.055,base-.03,-.04,.05,.004,'Neon',y=side*.100,bevel=.001)
    box('Pommel',rear,rear+.07,-.07,.065,.17,'Metal',bevel=.008)

def model(gun,concept=False):
    global GUN,COL,REFS,PARTS,CONCEPT,MATS
    GUN=gun; CONCEPT=concept; PARTS=[]; MATS={}
    bpy.ops.wm.read_homefile(use_empty=True,use_factory_startup=True)
    bpy.context.preferences.filepaths.save_version=0
    COL=bpy.data.collections.new(gun); bpy.context.scene.collection.children.link(COL)
    COL['weapon_name']=gun; COL['skin']='Default'; COL['remaster_version']=1
    COL['design']=DESIGNS[gun][3]; COL['concept_method']='Blender concept sheet; ImageGen request rejected'
    REFS=bpy.data.collections.new('_Review_ReferenceOnly'); bpy.context.scene.collection.children.link(REFS)
    REFS['export']=False
    materials(); d=CONTRACTS[gun]; cls,sight,kind,_=DESIGNS[gun]
    if gun=='Knife': knife(d)
    elif gun=='Outlaw': break_sniper(d)
    elif cls=='Sidearm': pistol(d,kind)
    else: rifle(d,kind)
    # Reload props for single-round loaders; they follow the existing dedicated animation bones.
    if gun in ['Bucky','Marshal']:
        p=[v['bounds'] for v in d['parts'].values() if v['bone']=='Shell'][0]
        ammo(kind,'ReloadRound',(p[0][0],0,sum(p[2])/2),'Shell')
        x0=p[0][0]-.035; x1=p[0][1]+.035; z=sum(p[2])/2
        upper=.24 if gun=='Bucky' else .15
        ring_profile('LoadingGate',[(x0,z-.066),(x1,z-.066),(x1,upper),(x0,upper)],
            [(x0+.022,z-.047),(x1-.022,z-.047),(x1-.022,z+.047),(x0+.022,z+.047)],.18,'Dark')
    aim=sights(d,sight)
    if not concept: ejection_window(d,kind)
    clean_geometry()
    return d,aim

def clean_geometry():
    for ob in PARTS:
        bm=bmesh.new(); bm.from_mesh(ob.data)
        bmesh.ops.remove_doubles(bm,verts=bm.verts[:],dist=.000001)
        bmesh.ops.dissolve_degenerate(bm,edges=bm.edges[:],dist=.000002)
        tiny=[f for f in bm.faces if f.calc_area()<1e-11]
        if tiny: bmesh.ops.delete(bm,geom=tiny,context='FACES')
        bmesh.ops.recalc_face_normals(bm,faces=bm.faces[:]); bm.to_mesh(ob.data); bm.free()

def ejection_window(d,kind):
    if GUN in ['Knife','Shorty','Sheriff','Outlaw']: return
    if 'Eject' not in d['attachments']: return
    x,_,z=d['attachments']['Eject']['pos']; bore=d['attachments']['Muzzle']['pos'][2]
    x0=x-.13; x1=x+.19; z0=bore-.050; z1=bore+.072
    # A real open window, rather than a dark decal on a solid shell.
    cutter=box('_WindowCutter',x0,x1,z0,z1,.38,'Dark',y=-.135,bevel=0)
    for ob in list(PARTS):
        if not ob.name.startswith(('Receiver_','ReceiverPanel','Slide_','SlidePanel')): continue
        mod=ob.modifiers.new('Open ejection window','BOOLEAN'); mod.operation='DIFFERENCE'; mod.solver='EXACT'; mod.object=cutter
        bpy.context.view_layer.objects.active=ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bevel=ob.modifiers.new('Window lip chamfer','BEVEL'); bevel.width=.003; bevel.segments=1; bevel.limit_method='ANGLE'
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        ob.data.materials.clear(); ob.data.materials.append(MATS[ob['role']])
        for face in ob.data.polygons: face.material_index=0
    PARTS.remove(cutter); bpy.data.objects.remove(cutter,do_unlink=True)
    bone='Barrel' if 'Barrel' in d['bones'] else 'Root'
    ammo(kind,'ChamberRound',(x-.015,0,bore),bone)

def uv_texture():
    # Separate planar face charts preserve the broad shell artwork surfaces and
    # keep bevel islands disjoint. A shelf atlas gives every chart explicit padding.
    charts=[]; density=128.; size=2048; pad=3
    for ob in PARTS:
        me=ob.data
        for layer in list(me.uv_layers): me.uv_layers.remove(layer)
        main=me.uv_layers.new(name='UVMap')
        for face in me.polygons:
            points=[me.vertices[me.loops[i].vertex_index].co.copy() for i in face.loop_indices]
            edges=[points[(i+1)%len(points)]-p for i,p in enumerate(points)]
            u=max(edges,key=lambda v:v.length_squared).normalized()
            n=face.normal.normalized(); v=n.cross(u).normalized()
            if v.length<.5:
                u=Vector((1,0,0)); v=Vector((0,0,1))
            coords=[(p.dot(u)*density,p.dot(v)*density) for p in points]
            lo=[min(p[i] for p in coords) for i in range(2)]
            hi=[max(p[i] for p in coords) for i in range(2)]
            charts.append({'object':ob,'loops':list(face.loop_indices),'coords':coords,'lo':lo,
                'width':max(1,math.ceil(hi[0]-lo[0]))+2*pad,'height':max(1,math.ceil(hi[1]-lo[1]))+2*pad})
    x=pad; y=pad; row=0
    for chart in sorted(charts,key=lambda c:(-c['height'],-c['width'])):
        if x+chart['width']>size-pad: x=pad; y+=row+pad; row=0
        if y+chart['height']>size-pad: raise RuntimeError('Skin UV atlas overflow')
        main=chart['object'].data.uv_layers['UVMap']
        for li,p in zip(chart['loops'],chart['coords']):
            main.data[li].uv=((x+pad+p[0]-chart['lo'][0])/size,(y+pad+p[1]-chart['lo'][1])/size)
        x+=chart['width']+pad; row=max(row,chart['height'])
    # Maintain the exact shared density despite minor non-planar blade facets.
    area=0.0; uvarea=0.0
    for ob in PARTS:
        me=ob.data; me.calc_loop_triangles(); uv=me.uv_layers.active.data
        for tri in me.loop_triangles:
            a,b,c=[uv[i].uv for i in tri.loops]
            uvarea+=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))/2
            area+=tri.area
    factor=math.sqrt(area*(128/2048)**2/max(uvarea,1e-12))
    for ob in PARTS:
        for loop in ob.data.uv_layers.active.data: loop.uv=loop.uv*factor
    COL['skin_atlas_resolution']=2048; COL['skin_texel_density']=128
    for ob in PARTS:
        main=ob.data.uv_layers.active; main.name='UVMap'
        trim=ob.data.uv_layers.new(name='TrimUV'); index=list(PALETTE).index(ob['role'])
        for loop in ob.data.loops:
            u,v=main.data[loop.index].uv
            trim.data[loop.index].uv=((index+.10+.80*u)/7,.08+.84*v)
        ob.data.uv_layers.active=main; ob.select_set(False)

def rigging(d,aim):
    arm=bpy.data.armatures.new(GUN+'_Rig'); rig=bpy.data.objects.new(GUN+'_Rig',arm); COL.objects.link(rig)
    rig.show_in_front=True; arm.display_type='STICK'
    bpy.context.view_layer.objects.active=rig; rig.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
    for name,v in d['bones'].items():
        b=arm.edit_bones.new(name); b.head=v['head']; b.tail=v['tail']
        if name=='Root': b.head=(0,0,0); b.tail=(0,.08,0)
        if v['parent']: b.parent=arm.edit_bones[v['parent']]
    bpy.ops.object.mode_set(mode='OBJECT'); bpy.context.view_layer.update()
    for ob in PARTS:
        world=ob.matrix_world.copy(); ob.parent=rig; ob.parent_type='BONE'; ob.parent_bone=ob['rig_bone']
        bpy.context.view_layer.update(); ob.matrix_world=world
    at={k:dict(v) for k,v in d['attachments'].items()}
    for name,pos in [('RightGrip',(0,0,0)),('LeftGrip',(.06,.03,-.08)),('Muzzle',(1.27,0,.0156)),('Eject',(.35,-.13,.20)),('CharmPoint',(-.30,.10,0))]:
        at.setdefault(name,{'pos':pos,'bone':'Root'})
    at.setdefault('AimPoint',{'pos':aim,'bone':'Root'})
    at['AimPoint']['pos']=aim
    if 'ScopeAxis' in at:
        oldaxis=at['ScopeAxis']['pos']; at['ScopeAxis']['pos']=(oldaxis[0],0,aim[2])
    end=at['Muzzle']['pos']; bore=end[2]
    for name,pos in [('Socket_Muzzle',end),('Socket_Optic',(aim[0]+.16,0,aim[2]-.10)),('Socket_Under',(max(.4,at['LeftGrip']['pos'][0]),0,bore-.19))]:
        at[name]={'pos':pos,'bone':at['Muzzle']['bone'] if name=='Socket_Muzzle' else 'Root'}
    for name,v in at.items():
        ob=bpy.data.objects.new(name,None); COL.objects.link(ob)
        ob.empty_display_type='ARROWS'; ob.empty_display_size=.065
        ob.parent=rig; ob.parent_type='BONE'; ob.parent_bone=v['bone'] or 'Root'
        bpy.context.view_layer.update()
        mat=Matrix(v['matrix']) if 'matrix' in v else Matrix.Identity(4)
        mat.translation=Vector(v['pos'])
        if name in ['Muzzle','MuzzleLower','Socket_Muzzle']:
            mat=Matrix.Translation(v['pos']) @ Vector((1,0,0)).to_track_quat('-Z','Y').to_matrix().to_4x4()
        elif name=='AimPoint': mat=Matrix.Translation(aim) @ Vector((1,0,0)).to_track_quat('-Z','Y').to_matrix().to_4x4()
        ob.matrix_world=mat
    rig.select_set(False); bpy.context.view_layer.update()
    return rig

def curves(action):
    if hasattr(action,'fcurves'): return list(action.fcurves)
    return [fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]

def animate(rig):
    path=ROOT+'/tools/blender/anim_'+GUN.lower()+'.py'
    ns={'__name__':'anim_remaster','__file__':path}; exec(compile(open(path,encoding='utf-8-sig').read(),path,'exec'),ns)
    clips=ns['animate']()
    if GUN=='Knife':
        import gunkit
        for name in ['Reload','ReloadEmpty']:
            c=gunkit.Clip(GUN,name,24); c.key('Root',8,rot=(12,-8,-5)); c.key('Root',14,rot=(-4,3,2)); c.bake(); clips[name]={'frames':24,'bones':['Root'],'note':'regrip utility; no ammunition'}
    for track in rig.animation_data.nla_tracks:
        track.mute=True
        for strip in track.strips:
            act=strip.action; act.use_fake_user=True
            if track.name in clips:
                clips[track.name]['declared_frames']=clips[track.name]['frames']
                clips[track.name]['frames']=int(act.frame_range[1])
            for fc in curves(act):
                for k in fc.keyframe_points:
                    # Crisp ease with original beat times and clip lengths intact.
                    k.interpolation='BEZIER'; k.handle_left_type='AUTO_CLAMPED'; k.handle_right_type='AUTO_CLAMPED'
                    if 'Root' in fc.data_path and 'rotation_euler' in fc.data_path: k.co.y*=1.06
                    if 'Mag' in fc.data_path and 'location' in fc.data_path and fc.array_index==2 and k.co.y<-.15: k.co.y*=1.12
            markers=dict(act.get('gg_markers',{}))
            for name,frame in markers.items(): act.pose_markers.new(name).frame=int(frame)
    rig.animation_data.action=None
    for pb in rig.pose.bones: pb.matrix_basis=Matrix.Identity(4)
    bpy.context.scene.frame_set(1); bpy.context.view_layer.update()
    return clips

def camera(name,loc,target,ortho=None,lens=50):
    ca=bpy.data.cameras.new(name); ob=bpy.data.objects.new(name,ca); REFS.objects.link(ob); ob.location=loc
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    ca.clip_start=.01; ca.clip_end=100; ca.lens=lens
    if ortho: ca.type='ORTHO'; ca.ortho_scale=ortho
    return ob

def studio(d,aim):
    sc=bpy.context.scene; sc.render.engine='BLENDER_EEVEE'
    sc.render.resolution_x=1440; sc.render.resolution_y=900; sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG'; sc.render.film_transparent=False
    if hasattr(sc,'eevee'): sc.eevee.taa_render_samples=32
    sc.view_settings.view_transform='AgX'; sc.view_settings.look='AgX - Medium High Contrast'
    sc.world=bpy.data.worlds.new('Neutral studio'); sc.world.use_nodes=True
    sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.19,.21,.24,1)
    sc.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    x0,x1=d['bounds'][0]; center=(x0+x1)/2; length=x1-x0
    target=(center,0,.14); scale=max(1.9,length*1.22)
    for name,loc,power,size in [('Key',(center+1,3,4),520,4),('Fill',(center-2,-3,2),430,3),('Rim',(center+1,-2,3.7),650,2.5),('Front',(center,4,.3),90,3)]:
        light=bpy.data.lights.new(name,'AREA'); light.energy=power; light.shape='DISK'; light.size=size
        ob=bpy.data.objects.new(name,light); REFS.objects.link(ob); ob.location=loc; ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    cams={
        'hero':camera('Review_Hero',(center+length*.75,length*1.10,length*.49+.4),target,ortho=scale),
        'side':camera('Review_Side',(center,8,.14),target,ortho=scale),
        'top':camera('Review_Top',(center,0,8),(center,0,0),ortho=scale),
        'held':camera('Review_Held',(center-length*.22,length*.55,length*.95),(center,0,-.18),ortho=scale*1.13),
        'reload':camera('Review_Reload',(center-length*.48,-length*.95,length*.50+.35),(center,0,-.12),ortho=scale*1.22),
        'rig':camera('Review_Rig',(center+length*.55,length*1.1,length*.55+.7),(center,0,-.10),ortho=scale*1.13)}
    distance=.30 if DESIGNS.get(GUN,('','reflex'))[1] in ['notch','bead','rib'] else .70
    eye=Vector(aim)-Vector((distance,0,0)); cams['ads']=camera('Review_ADS',eye,eye+Vector((3,0,0)),lens=38)
    return cams

def arms(d):
    coll=bpy.data.collections.new('_Arms_ReferenceOnly'); bpy.context.scene.collection.children.link(coll); coll['export']=False
    for side,name,key in [(-1,'Right','RightGrip'),(1,'Left','LeftGrip')]:
        p=Vector(d['attachments'].get(key,{'pos':(0,0,-.08)})['pos'])
        p.y=side*.135; p.z-=.025
        back=p+Vector((-.65,side*.18,-.46))
        beam('ReferenceArm'+name,back,p-Vector((.04,0,.06)),.24,.24,'Body',collection=coll)
        box('ReferenceHand'+name,p.x-.09,p.x+.12,p.z-.13,p.z+.06,.21,'Panel',y=p.y,bevel=.025,collection=coll)
        box('ReferenceCuff'+name,back.x+.26,back.x+.38,back.z+.18,back.z+.32,.26,'Dark',y=(p.y+back.y)/2,bevel=.02,collection=coll)
    coll.hide_render=True; coll.hide_viewport=True
    return coll

def render(cam,path,width=1440,height=900):
    sc=bpy.context.scene; sc.camera=cam; sc.render.resolution_x=width; sc.render.resolution_y=height
    sc.render.filepath=path; bpy.ops.render.render(write_still=True)

def concept(gun):
    out=BASE+'/'+gun; os.makedirs(out+'/renders',exist_ok=True)
    d,aim=model(gun,True); uv_texture(); cams=studio(d,aim)
    for view in ['side','hero','ads']: render(cams[view],out+'/_concept_'+view+'.png',1024,640)
    result={'gun':gun,'stage':'concept','method':'Blender blockout; image generator rejected weapon request','design':DESIGNS[gun][3]}
    return result

def label(name,text,pos,size=.055):
    cu=bpy.data.curves.new(name,'FONT'); cu.body=text; cu.size=size; cu.extrude=0; cu.align_x='LEFT'
    ob=bpy.data.objects.new(name,cu); REFS.objects.link(ob); ob.location=pos
    ob.rotation_euler=bpy.data.objects['Review_Rig'].rotation_euler
    cu.materials.append(bpy.data.materials.get('Reference_Accent') or MATS['Accent']); return ob

def final(gun,do_render=True):
    out=BASE+'/'+gun; os.makedirs(out+'/renders',exist_ok=True)
    if not os.path.exists(out+'/concept.png'): raise RuntimeError('Concept sheet must exist before final model')
    d,aim=model(gun,False); uv_texture(); rig=rigging(d,aim); clips=animate(rig); cams=studio(d,aim); armcol=arms(d)
    # Evaluated triangle count includes the real final chamfers; reference arms excluded.
    tris=0
    for ob in PARTS:
        me=ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh(); me.calc_loop_triangles(); tris+=len(me.loop_triangles)
        ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
    budget=3000 if DESIGNS[gun][0]=='Sidearm' else (6000 if gun in ['Ares','Odin','Operator'] else 5000)
    if tris>budget: raise RuntimeError(f'{gun}: {tris} triangles exceeds {budget}')
    # Geometric clearance: ADS camera has no surface inside the 0.16-stud eye exclusion sphere.
    eye=cams['ads'].location; deps=bpy.context.evaluated_depsgraph_get(); mind=float('inf')
    from mathutils.bvhtree import BVHTree
    for ob in PARTS:
        me=ob.evaluated_get(deps).to_mesh(); verts=[ob.matrix_world@v.co for v in me.vertices]
        tree=BVHTree.FromPolygons(verts,[list(p.vertices) for p in me.polygons]); near=tree.find_nearest(eye)
        if near[0] is not None: mind=min(mind,near[3])
        ob.evaluated_get(deps).to_mesh_clear()
    if mind<.16: raise RuntimeError(f'{gun}: ADS eye clearance {mind:.4f} is below 0.16 studs')
    sc=bpy.context.scene; sc.camera=cams['hero']; sc.frame_start=1; sc.frame_end=max(v['frames'] for v in clips.values())
    bpy.ops.wm.save_as_mainfile(filepath=out+'/'+gun+'.blend',compress=True)
    if do_render:
        for view in ['hero','side','top','ads']: render(cams[view],out+'/renders/'+view+'.png')
        armcol.hide_render=False; armcol.hide_viewport=False
        render(cams['held'],out+'/renders/held.png'); armcol.hide_render=True; armcol.hide_viewport=True
        # Exploded bone offsets with rendered locator crosses and readable labels.
        offsets={'Mag':(0,0,-.35),'AmmoBox':(0,0,-.35),'Bolt':(-.15,0,.10),'Slide':(-.19,0,.12),'ChargingHandle':(0,.20,0),'FeedCover':(0,0,.25),'Cylinder':(0,.24,0),'Barrels':(0,0,.18),'Pump':(-.20,0,0)}
        for name,loc in offsets.items():
            if name in rig.pose.bones: rig.pose.bones[name].location=loc
        bpy.context.view_layer.update(); glyphs=[]
        for ob in [o for o in COL.objects if o.type=='EMPTY']:
            p=ob.matrix_world.translation; size=.038
            for vec in [(size,0,0),(0,size,0),(0,0,size)]:
                v=Vector(vec); glyphs.append(beam('LocatorGlyph',p-v,p+v,.006,.006,'Accent',collection=REFS))
            glyphs.append(label('LocatorLabel',ob.name,tuple(p+Vector((.025,.09,.055))),.042))
        render(cams['rig'],out+'/renders/rig.png')
        for ob in glyphs: bpy.data.objects.remove(ob,do_unlink=True)
        for pb in rig.pose.bones: pb.matrix_basis=Matrix.Identity(4)
        act=bpy.data.actions.get(gun+'_ReloadEmpty') or bpy.data.actions.get(gun+'_Reload')
        rig.animation_data.action=act
        last=int(act.frame_range[1]); frames=[int(last*.23),int(last*.48),int(last*.83)]
        if gun in ['Shorty','Outlaw','Sheriff']: frames=[int(last*.27),int(last*.52),int(last*.73)]
        if gun=='Outlaw': frames=[23,38,52]
        if gun=='Bucky' or gun=='Marshal': frames=[int(last*.28),int(last*.52),int(last*.80)]
        for i,f in enumerate(frames): sc.frame_set(f); render(cams['reload'],out+'/renders/reload_%02d.png'%(i+1))
        rig.animation_data.action=None
        for pb in rig.pose.bones: pb.matrix_basis=Matrix.Identity(4)
        sc.frame_set(1); sc.camera=cams['hero']
    report={'gun':gun,'tris':tris,'budget':budget,'sight':DESIGNS[gun][1],'round':DESIGNS[gun][2],
        'clips':clips,'renders':9 if do_render else 0,'eye_clearance':round(mind,4),'old_bounds':d['bounds'],
        'bones':list(rig.data.bones.keys()),'attachments':[o.name for o in COL.objects if o.type=='EMPTY'],
        'concept':'Blender-generated sheet; ImageGen rejected request','studio_validation':'Pending user; no Studio opened',
        'design':DESIGNS[gun][3]}
    with open(out+'/review.json','w') as f: json.dump(report,f,indent=2)
    bpy.ops.wm.save_as_mainfile(filepath=out+'/'+gun+'.blend',compress=True)
    return report

def library():
    global GUN,COL,PARTS,CONCEPT,MATS,REFS
    bpy.ops.wm.read_homefile(use_empty=True,use_factory_startup=True); bpy.context.preferences.filepaths.save_version=0
    GUN='_Library'; PARTS=[]; CONCEPT=False; MATS={}
    COL=bpy.data.collections.new('Shared_Style_Library'); bpy.context.scene.collection.children.link(COL)
    REFS=bpy.data.collections.new('_Library_Studio'); bpy.context.scene.collection.children.link(REFS)
    materials()
    for i,kind in enumerate(['Pistol','HeavyPistol','SMG','Rifle','Shell','Sniper','Operator','Belt']):
        start=len(PARTS); ammo(kind,'Round_'+kind,(0,0,0))
        parent=bpy.data.objects.new('Round_'+kind,None); COL.objects.link(parent)
        parent.location=(0,i*.16,.05)
        for ob in PARTS[start:]: ob['library_asset']='Round_'+kind; ob.parent=parent
        length={'Pistol':.125,'HeavyPistol':.18,'SMG':.15,'Rifle':.23,'Shell':.24,'Sniper':.32,'Operator':.40,'Belt':.255}[kind]
        r={'Pistol':.023,'HeavyPistol':.027,'SMG':.024,'Rifle':.027,'Shell':.043,'Sniper':.034,'Operator':.042,'Belt':.030}[kind]
        casing=lathe('Casing_'+kind,[(0,r),(.01,r*1.05),(length*.78,r)],0,0,'Accent',n=10)
        casing.name='Casing_'+kind; casing.location=(.55,i*.16,.05)
    arms(CONTRACTS['Classic'])
    uv_texture(); d={'bounds':[[-.15,1.1],[-.1,1.3],[-.1,.2]]}; cams=studio(d,[0,0,.5])
    cams['side'].location=(.40,3,2.6); cams['side'].rotation_euler=(Vector((.40,.55,0))-cams['side'].location).to_track_quat('-Z','Y').to_euler(); cams['side'].data.ortho_scale=2.1
    render(cams['side'],LIB+'/_round-library.png')
    bpy.ops.wm.save_as_mainfile(filepath=LIB+'/Library.blend',compress=True)
    return {'library':LIB+'/Library.blend','round_types':8}
