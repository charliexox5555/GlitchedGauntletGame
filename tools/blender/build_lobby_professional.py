"""Original lobby art kit. Runs in the connected Blender without changing existing objects."""
import bpy, math, os, sys, json
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame')
OUT=ROOT/'art-source/lobby'
RENDER=Path(r'C:\Users\charl\Documents\Codex\2026-11-04\hi-i-have-been-working-on\outputs')
OUT.mkdir(parents=True,exist_ok=True)
RENDER.mkdir(parents=True,exist_ok=True)
scene=bpy.data.scenes.new('Lobby_Professional_Kit')
bpy.context.window.scene=scene
scene.unit_settings.system='NONE'
scene.unit_settings.scale_length=1
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.render.resolution_x=1600
scene.render.resolution_y=1000
scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Professional_StudioWorld')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.18,.22,.3,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5
scene.view_settings.view_transform='AgX'

def mat(name,color,metal=0,rough=.4,glow=False):
 m=bpy.data.materials.new('Professional_'+name); m.diffuse_color=(*[int(color[i:i+2],16)/255 for i in (0,2,4)],1)
 m.use_nodes=True; b=m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value=m.diffuse_color
 b.inputs['Metallic'].default_value=metal; b.inputs['Roughness'].default_value=rough
 if glow: b.inputs['Emission Color'].default_value=m.diffuse_color; b.inputs['Emission Strength'].default_value=2
 m['rbx_material']='Neon' if glow else ('Metal' if metal>.3 else 'SmoothPlastic')
 m['rbx_color']=color
 return m
DARK=mat('Graphite','222831',.55,.32)
EDGE=mat('Titanium','9AA7B5',.7,.28)
BLACK=mat('Recess','0D1219',.25,.5)
RED=mat('Carmine','C84849',.35,.38)
GOLD=mat('Champagne','CDA45C',.75,.24)
OAK=mat('Oak','865D3E',.1,.45)
GLOW=mat('Accent','F16B63',0,.4,True)
WHITE=mat('White','E8EEF2',0,.5)
col=None

def collection(name):
 global col
 col=bpy.data.collections.new('Lobby_'+name); scene.collection.children.link(col)
 return col
def link(o,name,m):
 for c in list(o.users_collection): c.objects.unlink(o)
 col.objects.link(o); o.name=col.name[6:]+'_'+name; o.data.materials.append(m)
 return o
def finish(o,b=.08):
 bpy.context.view_layer.objects.active=o; o.select_set(True)
 if b:
  mod=o.modifiers.new('MachinedEdges','BEVEL'); mod.width=b; mod.segments=1
  bpy.ops.object.modifier_apply(modifier=mod.name)
 for p in o.data.polygons: p.use_smooth=False
 return o
def box(name,loc,size,m,b=.08,rot=None):
 bpy.ops.object.select_all(action='DESELECT'); bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
 o=link(bpy.context.object,name,m); o.dimensions=size
 if rot:o.rotation_euler=rot
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,b)
def cylinder(name,loc,r,depth,m,verts=32):
 bpy.ops.object.select_all(action='DESELECT'); bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc)
 return finish(link(bpy.context.object,name,m),min(.08,depth*.15))
def shape(name,points,y0,y1,m,b=.05):
 # Counterclockwise outline in X,Z, extruded toward +Y. Recalculate consistent normals.
 n=len(points); vs=[(x,y,z) for y in (y0,y1) for x,z in points]
 fs=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 mesh=bpy.data.meshes.new(name); mesh.from_pydata(vs,[],fs); mesh.update()
 o=bpy.data.objects.new(name,mesh); col.objects.link(o); o.name=col.name[6:]+'_'+name; mesh.materials.append(m)
 bpy.context.view_layer.objects.active=o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
 bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
 return finish(o,b)
def outline(w,h,c=1):return [(-w/2+c,-h/2),(w/2-c,-h/2),(w/2,-h/2+c),(w/2,h/2-c),(w/2-c,h/2),(-w/2+c,h/2),(-w/2,h/2-c),(-w/2,-h/2+c)]

# Layered portal plaque. Its front is -Y; mounting origin is the plaque centre.
collection('ArenaHeader')
shape('Backing',outline(40,8,1.4),0,.9,DARK,.12)
shape('BrushedLip',outline(38.9,7.2,1.25),-.24,-.05,EDGE,.06)
shape('Face',outline(38.1,6.5,1.1),-.43,-.27,BLACK,.06)
for side in (-1,1):
 shape('Accent'+str(side),[(side*x,z) for x,z in [(15,-2.4),(16,-2.4),(18,.2),(18,2),(17,2),(17,.5)]],-.56,-.44,RED,.04)
 for k in range(3):
  box('Vent'+str(side)+'_'+str(k),(side*(18.1-k*.32),-.57,-2.5),(.12,.06,.55),EDGE,.015)

# Front-mounted vertical architectural fin: 0 at floor, profile tapers at the shoulder.
collection('ArenaFin')
shape('Spine',[(-1.6,0),(1.6,0),(1.6,13),(0.8,16),(-.8,16),(-1.6,13)],-.2,1.5,DARK,.13)
shape('Armour',[(-1.2,.65),(1.2,.65),(1.2,12.6),(.55,14.6),(-.55,14.6),(-1.2,12.6)],-.5,-.24,EDGE,.08)
shape('Inset',[(-.9,2),(.9,2),(.9,12.1),(.45,13.6),(-.45,13.6),(-.9,12.1)],-.66,-.53,DARK,.04)
box('Light_Glow',(0,-.73,8),(.2,.08,8.2),GLOW,.02)
for z in (1.1,14.5):box('Fastener'+str(z),(0,-.78,z),(.42,.12,.25),BLACK,.03)
box('Foot',(0,.2,.3),(3.8,2.5,.6),BLACK,.12)

# Emblem: opposing chevrons in a layered shield, deliberately original.
collection('VersusCrest')
shape('Shield',[(-3.6,2.3),(-2.3,3.5),(2.3,3.5),(3.6,2.3),(3,-1.6),(0,-4),(-3,-1.6)],-.15,.55,DARK,.10)
shape('Face',[(-3.1,2),(-2.1,2.9),(2.1,2.9),(3.1,2),(2.6,-1.3),(0,-3.35),(-2.6,-1.3)],-.34,-.18,EDGE,.05)
shape('Recess',[(-2.8,1.8),(-1.9,2.6),(1.9,2.6),(2.8,1.8),(2.3,-1.1),(0,-2.95),(-2.3,-1.1)],-.48,-.37,BLACK,.04)
for s in (-1,1):
 shape('DuelChevron'+str(s),[(s*x,z) for x,z in [(.6,-.1),(2.1,1.45),(2.1,.3),(1.2,-.5),(2.1,-1.3),(2.1,-2.1)]],-.69,-.50,RED,.03)
box('Ridge',(0,-.63,.3),(.15,.14,3.5),GOLD,.02)

# Raised armored fist trophy: nested plates give a bold silhouette at player distance.
collection('GauntletTrophy')
cylinder('PlinthFoot',(0,0,.35),4.1,.7,BLACK,12)
cylinder('PlinthEdge',(0,0,.79),3.85,.18,GOLD,12)
cylinder('Plinth',(0,0,1.45),3.45,1.15,DARK,12)
cylinder('PlinthTop',(0,0,2.08),3.55,.16,EDGE,12)
box('Mount',(0,0,2.8),(1.8,1.8,1.35),BLACK,.18)
shape('Cuff',[(-2.1,3.3),(2.1,3.3),(1.6,6.2),(-1.6,6.2)],-1.2,1.1,GOLD,.18)
shape('CuffInset',[(-1.5,3.7),(1.5,3.7),(1.12,5.85),(-1.12,5.85)],-1.41,-1.24,DARK,.08)
shape('CuffMark',[(-.55,4.7),(0,5.35),(.55,4.7),(0,4.05)],-1.55,-1.43,GOLD,.03)
shape('Palm',[(-1.6,5.8),(1.65,5.8),(2.15,8.6),(1.65,9.15),(-1.8,9.15),(-2.2,8.45)],-1.15,1.2,GOLD,.18)
shape('BackPlate',[(-1.4,6.3),(1.35,6.3),(1.7,8.3),(1.25,8.65),(-1.35,8.65),(-1.7,8.2)],-1.4,-1.17,EDGE,.08)
for i in range(4):
 x=-1.64+i*1.06; z=9.35+(.25 if i in (1,2) else 0)
 box('FingerRecess'+str(i),(x,-.13,z),(.98,2.3,1.8),BLACK,.22)
 box('Knuckle'+str(i),(x,-.35,z+.45),(.94,2.12,1.02),GOLD,.19)
 box('FingerPlate'+str(i),(x,-1.28,z-.44),(.89,.43,.85),GOLD,.12)
box('ThumbBase',(1.94,-.2,7.2),(1.2,2.1,2.1),DARK,.2,rot=(0,-.35,0))
box('ThumbArmour',(2.24,-.48,7.65),(1.25,2.05,2.1),GOLD,.22,rot=(0,-.4,0))
box('ThumbTip',(1.75,-1.23,8.2),(1.3,1,1),GOLD,.18,rot=(0,-.35,0))

# Finished equipment display case: molded corners, inset panel, banding and a real handle.
collection('EquipmentCase')
box('Body',(0,0,1.15),(4.6,2.8,2.3),DARK,.20)
box('Lid',(0,0,2.32),(4.8,3,.30),BLACK,.10)
box('TopInset',(0,0,2.51),(3.8,2.1,.08),EDGE,.035)
for x in (-1.8,1.8):
 box('Strap'+str(x),(x,-1.49,1.1),(.32,.2,1.95),RED,.04)
 box('Latch'+str(x),(x,-1.63,1.8),(.5,.18,.57),EDGE,.05)
 for y in (-1.16,1.16):box('Corner'+str(x)+str(y),(x,y,.24),(.85,.65,.48),BLACK,.08)
box('HandleTop',(0,-1.8,1.43),(1.45,.22,.24),BLACK,.065)
for x in (-.65,.65):box('HandlePost'+str(x),(x,-1.65,1.15),(.2,.35,.6),EDGE,.04)
box('Label',(0,-1.51,.55),(1.6,.06,.45),EDGE,.03)

# Cosmetic key sculpture, flat in XZ, front -Y. No purchase/collecting functionality.
collection('KeyDisplay')
def ring(name,x,z,ro,ri,depth,m,n=32):
 vs=[]
 for y in (-depth/2,depth/2):
  for r in (ro,ri):
   vs += [(x+r*math.cos(2*math.pi*i/n),y,z+r*math.sin(2*math.pi*i/n)) for i in range(n)]
 fs=[]
 for i in range(n):
  j=(i+1)%n
  fs += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
 me=bpy.data.meshes.new(name); me.from_pydata(vs,[],fs); me.update(); ob=bpy.data.objects.new(col.name[6:]+'_'+name,me); col.objects.link(ob); me.materials.append(m)
 return ob
ring('KeyBow',0,3.2,1.15,.57,.38,GOLD)
box('Shaft',(0,0,1.4),(.55,.38,2.2),GOLD,.08)
box('Tooth1',(.52,0,.65),(.9,.38,.42),GOLD,.05)
box('Tooth2',(.39,0,1.25),(.65,.38,.35),GOLD,.05)
box('BowInlay',(0,-.23,4.1),(.55,.08,.20),RED,.03)

# Record triangle counts and finite geometry, before adding preview objects.
report={}
for c in [c for c in scene.collection.children if c.name.startswith('Lobby_')]:
 tris=0
 for o in c.objects:
  o.data.calc_loop_triangles(); tris+=len(o.data.loop_triangles)
  assert len(o.data.loop_triangles)<20000
  assert all(math.isfinite(v) for vert in o.data.vertices for v in vert.co)
 report[c.name]={'parts':len(c.objects),'tris':tris}
(OUT/'Professional_Kit_Stats.json').write_text(json.dumps(report,indent=2))

# A separate preview scene shares copied geometry; original piece origins remain at zero.
preview=bpy.data.scenes.new('Professional_Preview'); bpy.context.window.scene=preview
preview.render.engine='CYCLES'; preview.cycles.samples=32
preview.world=scene.world; preview.render.resolution_x=1600; preview.render.resolution_y=1000; preview.render.resolution_percentage=100
preview.view_settings.view_transform='AgX'
pc=bpy.data.collections.new('ProfessionalPreview'); preview.collection.children.link(pc)
def show(piece,loc,scale=1):
 for original in bpy.data.collections['Lobby_'+piece].objects:
  ob=original.copy(); ob.data=original.data; pc.objects.link(ob); ob['preview_only']=True
  ob.location=Vector(loc)+original.location*scale; ob.scale*=scale
def pbox(name,loc,size,m):
 global col
 col=pc; return box(name,loc,size,m,.12)
show('ArenaHeader',(-5,0,19))
show('ArenaFin',(-24,1,0)); show('ArenaFin',(14,1,0))
show('VersusCrest',(-5,-.2,10))
show('GauntletTrophy',(25,-2,0),1.6)
show('EquipmentCase',(-21,-6,0),1.4)
show('KeyDisplay',(-14,-5,1),1.3)
pbox('Floor',(0,4,-.3),(95,60,.6),DARK)
pbox('Wall',(-5,3,13),(45,1.5,26),BLACK)
pbox('KeyPlinth',(-14,-5,.5),(4,4,1),BLACK)
fontpath=Path('C:/Windows/Fonts/bahnschrift.ttf')
font=bpy.data.fonts.load(str(fontpath)) if fontpath.exists() else None
def text_obj(body,loc,size,m,align='CENTER'):
 cu=bpy.data.curves.new('PreviewText','FONT'); cu.body=body; cu.size=size; cu.align_x=align; cu.extrude=.012
 if font:cu.font=font
 ob=bpy.data.objects.new('Preview_'+body,cu); pc.objects.link(ob); ob.location=loc; ob.rotation_euler=(math.pi/2,0,0); cu.materials.append(m)
text_obj('D U E L S',(-5,-.65,18.2),3.25,WHITE)
text_obj('01   /   THE ARENA',(-5,-.65,21),.72,RED)
text_obj('TACTICAL   /   COMPETITIVE   /   SOCIAL',(-5,-.65,16.35),.48,EDGE)
text_obj('THE GAUNTLET',(25,-6.3,1.8),.7,WHITE)
text_obj('ORIGINAL MODULAR ART KIT',(-5,-9,.1),.85,EDGE)
def light(name,loc,energy,color,size,target):
 data=bpy.data.lights.new(name,'AREA'); data.energy=energy; data.color=color; data.shape='DISK'; data.size=size
 ob=bpy.data.objects.new(name,data); pc.objects.link(ob); ob.location=loc; ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
light('Key',(-20,-20,30),16000,(.72,.84,1),22,(0,0,8))
light('WarmRim',(30,5,24),20000,(1,.63,.3),18,(20,0,8))
light('Fill',(15,-25,15),10000,(1,.9,.78),18,(15,0,6))
cam=bpy.data.cameras.new('ProfessionalPreviewCamera'); ob=bpy.data.objects.new('ProfessionalPreviewCamera',cam); pc.objects.link(ob)
ob.location=(49,-77,39); ob.rotation_euler=(Vector((1,0,10))-ob.location).to_track_quat('-Z','Y').to_euler(); cam.type='ORTHO'; cam.ortho_scale=73
preview.camera=ob
preview.render.filepath=str(RENDER/'lobby-kit-concept.png')
bpy.context.window.scene=scene
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Kit_Professional.blend'))
bpy.context.window.scene=preview
bpy.ops.render.render(write_still=True)
bpy.context.window.scene=scene
print(json.dumps({'file':str(OUT/'Kit_Professional.blend'),'report':report,'render':preview.render.filepath}))
