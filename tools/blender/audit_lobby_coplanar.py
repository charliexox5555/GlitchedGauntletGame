import bpy, sys, json, math
from collections import defaultdict
from pathlib import Path

def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def area(p):return abs(sum(p[i][0]*p[(i+1)%len(p)][1]-p[(i+1)%len(p)][0]*p[i][1] for i in range(len(p))))*.5
def clip(poly,tri):
 if cross(*tri)<0:tri=list(reversed(tri))
 for i,a in enumerate(tri):
  b=tri[(i+1)%3]; out=[]
  if not poly:return []
  prev=poly[-1]; dp=cross(a,b,prev)
  for cur in poly:
   dc=cross(a,b,cur)
   if (dc>=-1e-7)!=(dp>=-1e-7):
    t=dp/(dp-dc);out.append((prev[0]+(cur[0]-prev[0])*t,prev[1]+(cur[1]-prev[1])*t))
   if dc>=-1e-7:out.append(cur)
   prev,dp=cur,dc
  poly=out
 return poly

results=[]
for c in bpy.data.collections:
 if not c.name.startswith('Lobby_'):continue
 groups=defaultdict(list)
 for o in c.all_objects:
  if o.type!='MESH':continue
  me=o.data;me.calc_loop_triangles()
  for t in me.loop_triangles:
   vs=[o.matrix_world@me.vertices[i].co for i in t.vertices]
   n=(vs[1]-vs[0]).cross(vs[2]-vs[0])
   if n.length<1e-6:continue
   n.normalize(); d=n.dot(vs[0]); axis=max(range(3),key=lambda k:abs(n[k])); axes=[k for k in range(3) if k!=axis]
   key=tuple(round(x,4) for x in (*n,d))
   p=[(float(v[axes[0]]),float(v[axes[1]])) for v in vs]
   groups[key].append((min(v[0] for v in p),max(v[0] for v in p),min(v[1] for v in p),max(v[1] for v in p),p,o.name))
 aggregate=defaultdict(float)
 for plane,ts in groups.items():
  ts.sort(key=lambda t:t[0]);active=[]
  for a in ts:
   active=[b for b in active if b[1]>a[0]+1e-6]
   for b in active:
    if b[3]<=a[2]+1e-6 or a[3]<=b[2]+1e-6:continue
    clipped=clip(list(a[4]),b[4]); overlap=area(clipped) if len(clipped)>=3 else 0
    if overlap>.001:
     key=tuple(sorted((a[5],b[5])))+(plane,);aggregate[key]+=overlap
   active.append(a)
 for (a,b,plane),value in aggregate.items():
  if value>.03:results.append({'piece':c.name,'a':a,'b':b,'plane':plane,'area':round(value,4)})
out=Path(sys.argv[sys.argv.index('--')+1])
out.write_text(json.dumps(sorted(results,key=lambda x:-x['area']),indent=2))
print('COPLANAR_AUDIT',len(results),str(out))
