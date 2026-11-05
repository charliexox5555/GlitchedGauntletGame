"""Subtract coplanar triangle overlaps while preserving UVs. New repair asset only."""
import bpy, math, json, sys
from pathlib import Path
from collections import defaultdict
from mathutils import Matrix,Vector
ROOT=Path(r'C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame')
OUT=ROOT/'art-source/lobby'
scene=bpy.data.scenes.new('SurfaceRepair');bpy.context.window.scene=scene
cols=[]
for group in ['Hub','Duels','Market','Weapons']:
 with bpy.data.libraries.load(str(OUT/f'Kit_{group}.blend'),link=False) as (data,load):
  load.collections=[n for n in data.collections if n.startswith('Lobby_')]
 for c in load.collections:
  scene.collection.children.link(c);cols.append(c)
bpy.context.view_layer.update()

def cross(a,b,c,ax):
 i,j=ax;return (b[i]-a[i])*(c[j]-a[j])-(b[j]-a[j])*(c[i]-a[i])
def area(p,ax):
 if len(p)<3:return 0
 i,j=ax;return abs(sum(p[k][i]*p[(k+1)%len(p)][j]-p[(k+1)%len(p)][i]*p[k][j] for k in range(len(p))))*.5
def split(poly,a,b,ax):
 inside=[];outside=[];prev=poly[-1];dp=cross(a,b,prev,ax)
 for cur in poly:
  dc=cross(a,b,cur,ax)
  if (dc>=0)!=(dp>=0):
   t=dp/(dp-dc);pt=tuple(prev[k]+(cur[k]-prev[k])*t for k in range(5));inside.append(pt);outside.append(pt)
  (inside if dc>=0 else outside).append(cur)
  prev,dp=cur,dc
 return inside,outside
def subtract(poly,tri,ax):
 if cross(*tri,ax)<0:tri=list(reversed(tri))
 result=[];remaining=poly
 for k,a in enumerate(tri):
  if len(remaining)<3:break
  remaining,out=split(remaining,a,tri[(k+1)%3],ax)
  if area(out,ax)>1e-8:result.append(out)
 return result
def bounds(poly,ax):
 i,j=ax;return (min(p[i] for p in poly),max(p[i] for p in poly),min(p[j] for p in poly),max(p[j] for p in poly))
def intersects(a,b):return min(a[1],b[1])-max(a[0],b[0])>1e-6 and min(a[3],b[3])-max(a[2],b[2])>1e-6
def priority(name):
 # Narrow trims win over large substrates; energy strips win over housings.
 return (10 if 'Glow' in name else 8 if any(t in name for t in ['Nose','Nosing','Edge','Channel','Soffit','Base']) else 0,name)

changed=[];report=[]
for c in cols:
 objs=[o for o in c.all_objects if o.type=='MESH']
 groups=defaultdict(list);outputs=defaultdict(list);original={}
 for o in objs:
  me=o.data;me.calc_loop_triangles();mw=o.matrix_world.copy()
  original[o.name]=[mw@v.co for v in me.vertices]
  for t in me.loop_triangles:
   uv=me.uv_layers.active.data if me.uv_layers.active else None
   vs=[mw@me.vertices[i].co for i in t.vertices]
   normal=(vs[1]-vs[0]).cross(vs[2]-vs[0])
   if normal.length<1e-8:continue
   normal.normalize();d=normal.dot(vs[0]);drop=max(range(3),key=lambda k:abs(normal[k]));ax=tuple(k for k in range(3) if k!=drop)
   poly=[tuple(v)+(tuple(uv[loop].uv) if uv else (0,0)) for v,loop in zip(vs,t.loops)]
   key=tuple(round(v,4) for v in (*normal,d))
   groups[key].append({'o':o,'p':poly,'ax':ax,'mat':t.material_index,'bounds':bounds(poly,ax)})
 modified=set();removed=defaultdict(float)
 for plane,ts in groups.items():
  accepted=[]
  for t in sorted(ts,key=lambda t:priority(t['o'].name),reverse=True):
   pieces=[t['p']];initial=area(t['p'],t['ax'])
   for prior in accepted:
    if not intersects(t['bounds'],prior['bounds']):continue
    nextpieces=[]
    for p in pieces:
     if intersects(bounds(p,t['ax']),prior['bounds']):nextpieces.extend(subtract(p,prior['p'],t['ax']))
     else:nextpieces.append(p)
    pieces=nextpieces
    if not pieces:break
   total=sum(area(p,t['ax']) for p in pieces)
   if initial-total>1e-6:
    modified.add(t['o'].name);removed[t['o'].name]+=initial-total
   for p in pieces:
    for k in range(1,len(p)-1):outputs[t['o'].name].append(([p[0],p[k],p[k+1]],t['mat']))
   # Use original triangle for occupancy. Its union is identical to residual plus earlier triangles.
   accepted.append(t)
 for o in objs:
  if o.name not in modified:continue
  ts=outputs[o.name];vertices=[];faces=[];uvs=[];mats=[]
  for poly,matidx in ts:
   faces.append(tuple(range(len(vertices),len(vertices)+3)));vertices.extend(p[:3] for p in poly);uvs.extend(p[3:5] for p in poly);mats.append(matidx)
  me=bpy.data.meshes.new(o.name+'_Separated');me.from_pydata(vertices,[],faces);me.update()
  for m in o.data.materials:me.materials.append(m)
  layer=me.uv_layers.new(name='UVMap')
  for loop,uv in zip(layer.data,uvs):loop.uv=uv
  for p,m in zip(me.polygons,mats):p.material_index=m
  oldvs=original[o.name]
  lo=[min(v[i] for v in oldvs) for i in range(3)];hi=[max(v[i] for v in oldvs) for i in range(3)]
  info={'name':o.name,'piece':c.name[6:],'oldCenter':[(a+b)/2 for a,b in zip(lo,hi)],'oldSize':[b-a for a,b in zip(lo,hi)],'removedProjectedArea':round(removed[o.name],5),'trisBefore':len(o.data.loop_triangles),'trisAfter':len(faces)}
  o.data=me;o.matrix_world=Matrix.Identity(4);changed.append(o);report.append(info)
 # Keep only the repaired meshes in the exported partial piece.
 for o in objs:
  if o not in changed:bpy.data.objects.remove(o,do_unlink=True)
print('REPAIR_MESHES',len(report),'TRIS',sum(x['trisAfter'] for x in report))
for c in list(cols):
 if not len(c.objects):bpy.data.collections.remove(c)
(OUT/'SurfaceRepair_Changes.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Kit_SurfaceRepair.blend'))
sys.path.insert(0,str(ROOT/'tools/blender'))
import export_lobby_kit
print(json.dumps(export_lobby_kit.main(['SurfaceRepair'])))
