"""Asset contract audit and optional exports authorised in the user's last message.

Uses the project's exporter read-only, with its output directory redirected into
each Remaster folder. Never opens Studio or GunTest.blend.
"""
import bpy, math, os, json, re
from mathutils import Matrix, Vector
ROOT=r'C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame'
BASE=ROOT+'/art-source/weapons/Remaster'; LIB=BASE+'/_Library'
CONTRACTS=json.load(open(LIB+'/source_contracts.json'))
ORDER=['Vandal','Classic','Bulldog','Phantom','Guardian','Stinger','Spectre','Shorty','Ghost','Sheriff','Judge','Bucky','Marshal','Outlaw','Operator','Ares','Odin','Knife']
ROLES=['Body','Panel','Dark','Metal','Grip','Accent','Neon']
def overlap_area(a,b):
    def cross(u,v,w): return (v[0]-u[0])*(w[1]-u[1])-(v[1]-u[1])*(w[0]-u[0])
    orientation=1 if cross(*b)>0 else -1
    poly=list(a)
    for j in range(3):
        p,q=b[j],b[(j+1)%3]; output=[]
        if not poly: return 0.
        for k,v in enumerate(poly):
            u=poly[k-1]; cu=orientation*cross(p,q,u); cv=orientation*cross(p,q,v)
            iu=cu>=-1e-12; iv=cv>=-1e-12
            if iu!=iv:
                t=cu/(cu-cv); output.append((u[0]+t*(v[0]-u[0]),u[1]+t*(v[1]-u[1])))
            if iv: output.append(v)
        poly=output
    return abs(sum(poly[i][0]*poly[(i+1)%len(poly)][1]-poly[(i+1)%len(poly)][0]*poly[i][1] for i in range(len(poly))))/2 if len(poly)>2 else 0.
def uv_overlaps(triangles):
    grid={}; bad=[]
    for i,(name,tri) in enumerate(triangles):
        xs=[v[0] for v in tri]; ys=[v[1] for v in tri]
        cells=[(x,y) for x in range(math.floor(min(xs)*64),math.floor(max(xs)*64)+1) for y in range(math.floor(min(ys)*64),math.floor(max(ys)*64)+1)]
        candidates=set(j for cell in cells for j in grid.get(cell,[]))
        for j in candidates:
            othername,other=triangles[j]
            if min(max(xs),max(v[0] for v in other))-max(min(xs),min(v[0] for v in other))<1e-7: continue
            if min(max(ys),max(v[1] for v in other))-max(min(ys),min(v[1] for v in other))<1e-7: continue
            area=overlap_area(tri,other)
            if area>1e-8: bad.append({'parts':[name,othername],'area':area})
        for cell in cells: grid.setdefault(cell,[]).append(i)
    return bad
def open_asset(gun):
    bpy.ops.wm.open_mainfile(filepath=BASE+'/'+gun+'/'+gun+'.blend')
    bpy.context.view_layer.update()
    return bpy.data.collections[gun]
def audit(gun):
    col=open_asset(gun); old=CONTRACTS[gun]; errors=[]
    rig=next(o for o in col.all_objects if o.type=='ARMATURE')
    meshes=[o for o in col.all_objects if o.type=='MESH']; loc={o.name:o for o in col.all_objects if o.type=='EMPTY'}
    for name in set(old['attachments'])|{'Muzzle','RightGrip','LeftGrip','AimPoint','Eject','CharmPoint','Socket_Muzzle','Socket_Optic','Socket_Under'}:
        if name not in loc: errors.append('Missing attachment '+name)
    if set(rig.data.bones.keys())!=set(old['bones']): errors.append('Bone names differ from source')
    if rig.data.bones['Root'].head_local.length>1e-5: errors.append('Root is not at grip origin')
    if loc['RightGrip'].matrix_world.translation.length>1e-5: errors.append('RightGrip origin changed')
    if gun!='Knife':
        m=loc['Muzzle'].matrix_world
        if (m.translation-Vector(old['attachments']['Muzzle']['pos'])).length>1e-5: errors.append('Bore exit moved')
        forward=(m.to_3x3()@Vector((0,0,-1))).normalized()
        if (forward-Vector((1,0,0))).length>1e-4: errors.append('Muzzle orientation incorrect')
    area=0.; uvarea=0.; tris=0; pts=[]; zeroUV=0; uvtris=[]
    for ob in meshes:
        me=ob.data; me.calc_loop_triangles(); tris+=len(me.loop_triangles)
        if ob.parent!=rig or ob.parent_type!='BONE' or ob.parent_bone not in rig.data.bones: errors.append('Invalid rigid-bone parenting '+ob.name)
        if len(me.materials)!=1 or me.materials[0].name not in ROLES: errors.append('Invalid role material '+ob.name)
        if not any(ob.name.endswith('_'+r) for r in ROLES): errors.append('Part name must end in material role '+ob.name)
        if 'UVMap' not in me.uv_layers or 'TrimUV' not in me.uv_layers:
            errors.append('Missing skin or trim UV '+ob.name); continue
        uv=me.uv_layers['UVMap'].data
        for v in me.vertices:
            p=ob.matrix_world@v.co; pts.append(p)
            if not all(math.isfinite(a) for a in p): errors.append('Non-finite vertex '+ob.name)
        for tri in me.loop_triangles:
            a,b,c=[uv[i].uv for i in tri.loops]
            ar=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))/2
            uvarea+=ar; area+=tri.area
            if ar>1e-10: uvtris.append((ob.name,[tuple(a),tuple(b),tuple(c)]))
            if ar<1e-12 and tri.area>1e-8: zeroUV+=1
        for loop in uv:
            if min(loop.uv)<-.0001 or max(loop.uv)>1.0001: errors.append('UV outside skin atlas '+ob.name); break
    density=2048*math.sqrt(uvarea/area)
    if abs(density-128)>.15: errors.append(f'Skin texel density {density:.3f}')
    if zeroUV: errors.append(f'{zeroUV} zero-area skin UV triangles')
    overlaps=uv_overlaps(uvtris)
    if overlaps: errors.append(f'{len(overlaps)} overlapping skin UV triangle pairs')
    bounds=[[min(v[i] for v in pts),max(v[i] for v in pts)] for i in range(3)]
    ratios=[(bounds[i][1]-bounds[i][0])/(old['bounds'][i][1]-old['bounds'][i][0]) for i in range(3)]
    for axis in [0,2]:
        if abs(ratios[axis]-1)>.102: errors.append(f'Overall size axis {axis} changed by {(ratios[axis]-1)*100:.1f}%')
    budget=3000 if gun in ['Classic','Shorty','Ghost','Sheriff'] else (6000 if gun in ['Ares','Odin','Operator'] else 5000)
    if tris>budget: errors.append(f'{tris} tris exceeds {budget}')
    report=json.load(open(BASE+'/'+gun+'/review.json'))
    tracks={t.name:t for t in rig.animation_data.nla_tracks}
    for name in report['clips']:
        if name not in tracks: errors.append('Missing NLA '+name); continue
        action=tracks[name].strips[0].action
        if int(action.frame_range[1])!=report['clips'][name]['frames']: errors.append('Clip length '+name)
        for marker,f in dict(action.get('gg_markers',{})).items():
            pm=action.pose_markers.get(marker)
            if pm is None or pm.frame!=f: errors.append('Marker '+name+'/'+marker)
    for img in bpy.data.images:
        if img.name.startswith('GG_Shared') and img.packed_file is None: errors.append('Unpacked texture '+img.name)
    audit={'gun':gun,'passed':not errors,'errors':errors,'tris':tris,'budget':budget,'size_ratios_xyz':ratios,
        'bounds':bounds,'skin_texel_density':round(density,3),'zero_area_uv_triangles':zeroUV,'uv_overlaps':overlaps,
        'mesh_parts':len(meshes),'attachment_count':len(loc),'actions':len(tracks),'eye_clearance':report['eye_clearance']}
    with open(BASE+'/'+gun+'/audit.json','w') as f: json.dump(audit,f,indent=2)
    return audit
def export(gun):
    col=open_asset(gun)
    script=ROOT+'/tools/blender/export_weapons.py'
    ns={'__name__':'remaster_export','__file__':script}
    exec(compile(open(script,encoding='utf-8-sig').read(),script,'exec'),ns)
    ns['OUT_DIR']=BASE+'/'+gun
    rig=next(o for o in col.all_objects if o.type=='ARMATURE')
    # The exporter's per-action JSON sampler preserves markers and exact game timings.
    # Enabled NLA tracks also produce separate FBX takes.
    for track in rig.animation_data.nla_tracks: track.mute=False
    report=ns['export_gun'](col)
    # This mutated export session is deliberately never saved over the authored blend.
    return report
def roundtrip(gun):
    path=BASE+'/'+gun+'/'+gun+'.fbx'
    bpy.ops.wm.read_homefile(use_empty=True,use_factory_startup=True)
    bpy.ops.import_scene.fbx(filepath=path,use_anim=True)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    tris=0
    for ob in meshes: ob.data.calc_loop_triangles(); tris+=len(ob.data.loop_triangles)
    actions=[a.name for a in bpy.data.actions]
    expected=json.load(open(BASE+'/'+gun+'/review.json'))
    errors=[]
    if tris!=expected['tris']: errors.append(f'Triangle count changed: {tris}')
    for name in expected['clips']:
        if 'Rig|'+name not in actions: errors.append('FBX rig take missing: '+name)
    rig=next((o for o in bpy.context.scene.objects if o.type=='ARMATURE'),None)
    if rig is None or set(rig.data.bones.keys())!=set(CONTRACTS[gun]['bones']): errors.append('FBX bone contract changed')
    required={'Muzzle','RightGrip','LeftGrip','AimPoint','Eject','CharmPoint','Socket_Muzzle','Socket_Optic','Socket_Under'}
    missing=required-set(bpy.context.scene.objects.keys())
    if missing: errors.append('FBX missing locators '+str(missing))
    report={'gun':gun,'passed':not errors,'errors':errors,'tris':tris,'takes':actions,'mesh_parts':len(meshes)}
    with open(BASE+'/'+gun+'/export-check.json','w') as f: json.dump(report,f,indent=2)
    return report
def lineup(grid=False):
    bpy.ops.wm.read_homefile(use_empty=True,use_factory_startup=True)
    bpy.context.preferences.filepaths.save_version=0
    sc=bpy.context.scene; sc.render.engine='BLENDER_EEVEE'; sc.render.image_settings.file_format='PNG'
    sc.view_settings.view_transform='AgX'; sc.view_settings.look='AgX - Medium High Contrast'
    if hasattr(sc,'eevee'): sc.eevee.taa_render_samples=48
    world=bpy.data.worlds.new('Neutral grey'); sc.world=world; world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.19,.21,.24,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.45
    cursor=0.; labels=[]
    for i,gun in enumerate(ORDER):
        with bpy.data.libraries.load(BASE+'/'+gun+'/'+gun+'.blend') as (src,dst): dst.collections=[gun]
        col=dst.collections[0]; instance=bpy.data.objects.new('Lineup_'+gun,None); sc.collection.objects.link(instance)
        instance.instance_type='COLLECTION'; instance.instance_collection=col
        lo,hi=CONTRACTS[gun]['bounds'][0]; length=hi-lo
        if grid:
            cx=(2-i%3)*5.4; zz=-(i//3)*1.65
            instance.location=(cx-(lo+hi)/2,0,zz); labels.append((gun,cx,zz-.66))
        else:
            instance.location=(cursor-lo,0,0); labels.append((gun,cursor+length/2,-.73)); cursor+=length+.45
    camdata=bpy.data.cameras.new('LineupCamera'); cam=bpy.data.objects.new('LineupCamera',camdata); sc.collection.objects.link(cam); camdata.type='ORTHO'
    if grid:
        center=Vector((5.4,0,-3.9)); cam.location=center+Vector((0,20,0)); camdata.ortho_scale=17
        sc.render.resolution_x=3000; sc.render.resolution_y=1950
    else:
        center=Vector((cursor/2,0,-.1)); cam.location=center+Vector((0,20,0)); camdata.ortho_scale=cursor+.35
        sc.render.resolution_x=12000; sc.render.resolution_y=650
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler(); sc.camera=cam
    # Large softboxes keep the full set readable with the same grey studio look.
    boxsize=22 if grid else cursor*1.15
    power=2400 if grid else 18000
    for name,offset,energy in [('Key',(0,8,7),power),('Fill',(-3,6,-3),power*.50),('Rim',(0,-6,5),power*.70)]:
        light=bpy.data.lights.new(name,'AREA'); light.energy=energy; light.shape='DISK'; light.size=boxsize
        ob=bpy.data.objects.new(name,light); sc.collection.objects.link(ob); ob.location=center+Vector(offset)
        ob.rotation_euler=(center-ob.location).to_track_quat('-Z','Y').to_euler()
    mat=bpy.data.materials.new('Label'); mat.use_nodes=True; bs=mat.node_tree.nodes['Principled BSDF']; bs.inputs['Base Color'].default_value=(.75,.83,.90,1)
    bs.inputs['Emission Color'].default_value=(.75,.83,.90,1); bs.inputs['Emission Strength'].default_value=.5
    for text,x,z in labels:
        curve=bpy.data.curves.new('Label_'+text,'FONT'); curve.body=text.upper(); curve.size=.125; curve.align_x='CENTER'
        ob=bpy.data.objects.new('Label_'+text,curve); sc.collection.objects.link(ob); ob.location=(x,.50,z); ob.rotation_euler=cam.rotation_euler; curve.materials.append(mat)
    sc.render.filepath=LIB+('/lineup-grid.png' if grid else '/lineup.png')
    bpy.ops.render.render(write_still=True)
    if grid: bpy.ops.wm.save_as_mainfile(filepath=LIB+'/Lineup.blend',compress=True)
    return {'lineup':sc.render.filepath,'weapons':18,'same_scale':True}
