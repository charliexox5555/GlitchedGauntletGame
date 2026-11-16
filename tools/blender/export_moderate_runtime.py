"""Export the moderate skins as positioned, atlas-preserving Roblox mesh packages."""
import bpy
import json
import math
import sys
from collections import defaultdict
from pathlib import Path
from mathutils import Vector

ROOT = Path.cwd()
SKINS = ROOT / 'art-source/weapons/Skins'
OUT = SKINS / 'Review/Moderate/Studio'
OUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ROOT / 'tools/blender'))
from export_roblox_flat import _mat_spec, fix_outward

LINES = ('Playback', 'Breakwater', 'Sundial')
MAP_UVS = ('Playback_Atlas', 'Moderate_Atlas')

def box_ring(x0, x1, half, bevel, z):
    return [(x0+bevel,-half,z),(x1-bevel,-half,z),(x1,-half+bevel,z),(x1,half-bevel,z),
            (x1-bevel,half,z),(x0+bevel,half,z),(x0,half-bevel,z),(x0,-half+bevel,z)]

def seat_geometry():
    stations=[(.835,.913,.028,.005,.465),(.831,.917,.031,.005,.477),(.827,.920,.033,.006,.5045)]
    pts=[Vector(p) for row in stations for p in box_ring(*row)]
    faces=[tuple(reversed(range(8)))]
    for row in (0,8):
        faces.extend((row+i,row+(i+1)%8,row+(i+1)%8+8,row+i+8) for i in range(8))
    faces.append(tuple(range(16,24)))
    return pts,faces

def part(name, points, faces, uvs, specs, bone, kind, extra=None):
    coords=list(points)
    lo=Vector(min(v[i] for v in coords) for i in range(3))
    hi=Vector(max(v[i] for v in coords) for i in range(3))
    center=(lo+hi)*.5
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(p-center) for p in coords],[],faces)
    mesh.update()
    if uvs:
        data=mesh.uv_layers.new(name='UVMap').uv
        for poly,pattern in zip(mesh.polygons,uvs):
            for corner,uv in zip(poly.loop_indices,pattern):
                data[corner].vector=uv
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location=center
    specs[name]={
        'bone':bone, 'kind':kind,
        'center':[round(v,7) for v in center],
        'size':[round(v,7) for v in hi-lo],
    }
    if extra:
        specs[name].update(extra)
    return obj

def seat(specs):
    points,faces=seat_geometry()
    return part('GG_Bulldog_FrontSightSeat',points,faces,None,specs,'Root','flat',{'color':'292A30','material':'Metal','opacity':1.})

def save_fbx(made,file):
    bpy.ops.object.select_all(action='DESELECT')
    for a in made:
        a.select_set(True)
    bpy.context.view_layer.objects.active=made[0]
    bpy.ops.export_scene.fbx(
        filepath=str(file),use_selection=True,apply_unit_scale=True,global_scale=1.0,axis_forward='-Z',axis_up='Y',
        mesh_smooth_type='FACE',use_mesh_modifiers=False,object_types={'MESH'},bake_space_transform=False
    )

def export_sight(current=False):
    src=SKINS/'Shared Sources/Bulldog/BoltFix_v02/Bulldog_RemasterV2_v05_BoltFix_v02.blend'
    if not current:
        bpy.ops.wm.open_mainfile(filepath=str(src),load_ui=False)
    bpy.context.scene.frame_set(1)
    specs={}
    obj=seat(specs)
    w=bpy.data.collections['Bulldog']
    w.objects.link(obj)
    if obj in tuple(bpy.context.scene.collection.objects):
        bpy.context.scene.collection.objects.unlink(obj)
    bpy.context.view_layer.update()
    pose=obj.matrix_world.copy()
    rig=bpy.data.objects['Bulldog_Rig']
    obj.parent=rig
    obj.parent_type='BONE'
    obj.parent_bone='Root'
    obj.matrix_world=pose
    bpy.context.view_layer.update()
    obj.matrix_world=pose
    m=bpy.data.materials.new('Bulldog sight pedestal')
    m.diffuse_color=(.03,.03,.036,1)
    obj.data.materials.append(m)
    folder=SKINS/'Shared Sources/Bulldog/SightSeat_v01'
    folder.mkdir(exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'Bulldog_RemasterV2_v05_SightSeat_v01.blend'))
    obj.parent=None
    obj.matrix_world=pose
    save_fbx([obj],OUT/'Bulldog_FrontSightSeat_v01.fbx')
    (OUT/'Bulldog_FrontSightSeat_v01.json').write_text(json.dumps({'parts':specs},indent=2)+'\n')

def classify(obj,material):
    if material is None:
        return 'flat','373741','SmoothPlastic',1.
    shader=next((n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED' and
                 any(l.to_node.is_active_output for l in n.outputs[0].links if l.to_node.type=='OUTPUT_MATERIAL')),None) if material.use_nodes else None
    spec=_mat_spec(material)
    color=material.get('finish') or spec['color']
    mat=spec['material']
    alpha=shader.inputs['Alpha'].default_value if shader else material.diffuse_color[3]
    if material.name.removesuffix('.001')=='Neon':
        return 'flat',color,'Neon',alpha
    if shader and shader.inputs['Base Color'].is_linked:
        src=shader.inputs['Base Color'].links[0].from_node
        if src.type=='TEX_IMAGE' and src.image and src.image.packed_file:
            return 'pbr',None,'SmoothPlastic',alpha
    return 'flat',color,mat,alpha

def export_skin(line, gun):
    folder=SKINS/line/gun/'v01'
    path=folder/f'{gun}_{line}_v01.blend'
    bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    stock=bpy.data.collections[gun]
    groups=defaultdict(list)
    keep=[]
    replace=set()
    for obj in stock.objects:
        if obj.type!='MESH':
            continue
        role=obj.name.removeprefix(gun+'_')
        if role.startswith('Scope'):
            keep.append(role)
            continue
        if obj.name.startswith(gun+'_'):
            replace.add(role)
        fix_outward(obj)
        bone=obj.parent_bone or 'Root'
        if obj.animation_data and obj.name.startswith(line+'_'):
            cosmetic=obj.name.removeprefix(line+'_')
        else:
            cosmetic=''
        geo=obj.data
        geo.calc_loop_triangles()
        uv=next((geo.uv_layers[k].uv for k in MAP_UVS if k in geo.uv_layers), None)
        for tri in geo.loop_triangles:
            if tri.area<1e-10:
                continue
            material=geo.materials[geo.polygons[tri.polygon_index].material_index]
            style=classify(obj,material)
            component='Sight' if 'sight' in role.lower() else ''
            # Seat and emissive references stay separate from the atlas group.
            if role in ('SlideNeon','BarrelNeon') and style[2]=='Neon':
                component='Sight'
            key=(bone,component,cosmetic,*style)
            points=[obj.matrix_world @ geo.vertices[j].co for j in tri.vertices]
            coords=[tuple(uv[j].vector) for j in tri.loops] if uv else [(0,0)]*3
            groups[key].append((points,coords,obj))
    specs,made={},[]
    for idx,(key,data) in enumerate(sorted(groups.items(),key=lambda pair:str(pair[0])),1):
        bone,component,cosmetic,kind,color,material,alpha=key
        names={'AmberLatch':'Latch','ReelFront':'ReelFront','ReelRear':'ReelRear','Reel_Front':'ReelFront','Reel_Rear':'ReelRear',
               'MeterSweep':'MeterSweep','Dial':'Dial'}
        nickname=names.get(cosmetic,cosmetic)
        n=f'GG_{bone}_{component+"_" if component else ""}{nickname+"_" if nickname else ""}{idx:02d}'
        points=[]; faces=[]; uvs=[]; cache={}
        for coordinates,texture,source in data:
            indices=[]
            for pos in coordinates:
                k=tuple(round(v,8) for v in pos)
                if k not in cache:
                    cache[k]=len(points)
                    points.append(pos)
                indices.append(cache[k])
            faces.append(tuple(indices))
            uvs.append(texture)
        src=data[0][2]
        extra={'color':color,'material':material,'opacity':round(alpha,5)}
        if cosmetic:
            mx=src.matrix_world
            extra['motion']=nickname
            extra['pivot']=[round(v,7) for v in mx.translation]
            h=(mx.to_3x3()@Vector((0,0,1))).normalized()
            if nickname in ('ReelFront','ReelRear'):
                h=(mx.to_3x3()@Vector((0,1,0))).normalized()
            elif nickname in ('Latch','MeterSweep'):
                h=(mx.to_3x3()@Vector((1,0,0))).normalized()
            extra['axis']=[round(v,7) for v in h]
        made.append(part(n,points,faces,uvs,specs,bone,kind,extra))
    if gun=='Bulldog':
        made.append(seat(specs))
    name=gun+'_'+line+'_Runtime_v01'
    file=OUT/(name+'.fbx')
    save_fbx(made,file)
    maps={p.stem.rsplit('_',1)[-1]:p.relative_to(ROOT).as_posix() for p in sorted((folder/'textures').glob('*.png'))}
    manifest={'line':line,'gun':gun,'parts':specs,'replaced':sorted(replace),'kept':keep,'maps':maps,
              'source':path.relative_to(ROOT).as_posix(),'file':file.relative_to(ROOT).as_posix()}
    (OUT/(name+'.json')).write_text(json.dumps(manifest,indent=2)+'\n')
    print('READY',line,gun,len(made),flush=True)

if __name__=='__main__':
    jobs=sys.argv[sys.argv.index('--')+1:]
    if 'sight' in jobs:
        export_sight()
        jobs.remove('sight')
    if 'all' in jobs:
        jobs=[f'{line}/{p.parent.parent.name}' for line in LINES for p in (SKINS/line).glob('*/v01/manifest.json')]
    for job in jobs:
        export_skin(*job.split('/'))

