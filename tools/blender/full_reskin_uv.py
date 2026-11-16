"""Keep the stock atlas except for faces with overlapping UV coverage."""

from collections import Counter, defaultdict

from mathutils import Vector
import numpy as np


def coverage(objects, size=2048, omitted=frozenset()):
    atlas=np.zeros((size,size),dtype=np.int32)
    faces=[None]
    overlaps=Counter()
    for ob in objects:
        mesh=ob.data
        layer=mesh.uv_layers.active
        assert layer, f"{ob.name} needs a bake UV map"
        uv=np.array([tuple(v.vector) for v in layer.uv])*size
        if not np.all((-1e-4<=uv)&(uv<=size+1e-4)):
            raise ValueError(f"{ob.name} has UV coordinates outside its atlas")
        offset=len(faces)
        faces.extend((ob,face.index) for face in mesh.polygons)
        mesh.calc_loop_triangles()
        for tri in mesh.loop_triangles:
            if (ob.name,tri.polygon_index) in omitted:
                continue
            p,q,r=uv[list(tri.loops)]
            a,b=q-p,r-p
            det=a[0]*b[1]-a[1]*b[0]
            if abs(det)<1e-10:
                raise ValueError(f"{ob.name} has a degenerate UV triangle at {tri.polygon_index}")
            x0,y0=np.maximum(np.floor(np.min([p,q,r],axis=0)).astype(int),0)
            x1,y1=np.minimum(np.ceil(np.max([p,q,r],axis=0)).astype(int),size)
            x,y=np.meshgrid(np.arange(x0,x1)+.5-p[0],np.arange(y0,y1)+.5-p[1])
            u,v=(x*b[1]-y*b[0])/det,(a[0]*y-a[1]*x)/det
            inside=(u>1e-6)&(v>1e-6)&(u+v<1-1e-6)
            tile=atlas[y0:y1,x0:x1]
            old=tile[inside]
            key=offset+tri.polygon_index
            for prev,count in zip(*np.unique(old[(old>0)&(old!=key)],return_counts=True)):
                overlaps[tuple(sorted((int(prev),key)))]+=int(count)
            tile[inside]=key
    return atlas,faces,overlaps


def _available(used,w,h):
    integral=np.pad(used.cumsum(axis=0,dtype=np.int32).cumsum(axis=1,dtype=np.int32),((1,0),(1,0)))
    return (integral[h:,w:]+integral[:-h,:-w]-integral[:-h,w:]-integral[h:,:-w])==0


def relocate(objects, approved=None):
    atlas,face_index,overlaps=coverage(objects)
    if not overlaps:
        return {"before_overlap_texels":0,"after_overlap_texels":0,"parts":{}}
    if approved is not None:
        # Bulldog's already-reviewed barrel and stock UV fragments are shared
        # across all its new skins, including the owner-approved Misprint.
        import bpy
        names={o.data.name:o for o in objects if o.name.endswith(("_Barrel","_Stock"))}
        edits={}
        with bpy.data.libraries.load(str(approved)) as (incoming,loaded):
            assert set(names)<=set(incoming.meshes)
            loaded.meshes=list(names)
        for mesh,ob in zip(loaded.meshes,names.values()):
            src=mesh.uv_layers.active.uv
            dst=ob.data.uv_layers.active.uv
            assert len(src)==len(dst)
            affected=[]
            for i,(s,d) in enumerate(zip(src,dst)):
                if s.vector!=d.vector:
                    affected.append(i)
                    d.vector=s.vector
            edits[ob.name]={"uv_corners":len(affected),"source":"Owner-approved Misprint Bulldog v03"}
            bpy.data.meshes.remove(mesh)
        _,_,after=coverage(objects)
        assert not after,after
        return {"before_overlap_texels":sum(overlaps.values()),"after_overlap_texels":0,"parts":edits}

    scale=1024
    placements={}
    def coords(index):
        ob,fi=face_index[index]
        face=ob.data.polygons[fi]
        loops=list(face.loop_indices)
        uv=ob.data.uv_layers.active.uv
        xy=np.array([tuple(uv[i].vector) for i in loops])*scale
        return ob,fi,loops,uv,xy

    # Remove the smaller conflicting faces and keep larger, readable graphic
    # surfaces at their original UV coordinates.
    edges=set(overlaps)
    movers=set()
    areas={}
    for index in set(i for pair in edges for i in pair):
        xy=coords(index)[-1]
        areas[index]=max(.5,float(np.prod(np.ptp(xy,axis=0))))
    while edges:
        degree=Counter(i for pair in edges for i in pair)
        index=min(degree,key=lambda i: (areas[i]/degree[i],areas[i],i))
        movers.add(index)
        edges={pair for pair in edges if index not in pair}

    omitted={(face_index[i][0].name,face_index[i][1]) for i in movers}
    # Use 2K coverage to conservatively reserve edge texels when placing at 1K.
    free_atlas,_,_=coverage(objects,size=scale*2,omitted=omitted)
    used=(free_atlas>0).reshape(scale,2,scale,2).any(axis=(1,3))
    for index in sorted(movers,key=lambda i:(-areas[i],i)):
        ob,fi,loops,uv,xy=coords(index)
        pad=6
        chosen=None
        for factor in (1,.9,.8,.7,.6,.5):
            for shoulder in (xy,xy[:,::-1]*[-1,1]):
                relative=(shoulder-shoulder.min(axis=0))*factor
                w,h=np.ceil(relative.max(axis=0)).astype(int)+2*pad+1
                if w>scale or h>scale:
                    continue
                rows,cols=np.where(_available(used,w,h))
                if len(rows):
                    n=int(np.argmin((cols-xy[0,0])**2+(rows-xy[0,1])**2))
                    x,y=int(cols[n]),int(rows[n])
                    chosen=(relative,x,y,w,h,factor)
                    break
            if chosen:
                break
        if chosen is None:
            raise ValueError(f"No free UV atlas space for {ob.name} face {fi}")
        relative,x,y,w,h,factor=chosen
        new=(relative+np.array([x+pad,y+pad]))/scale
        for i,point in zip(loops,new):
            uv[i].vector=Vector(point)
        used[y:y+h,x:x+w]=True
        placements.setdefault(ob.name,[]).append({"face":fi,"uv_corners":len(loops),"scale":factor})
    _,_,after=coverage(objects)
    assert not after,after
    return {"before_overlap_texels":sum(overlaps.values()),"after_overlap_texels":0,"parts":placements}
