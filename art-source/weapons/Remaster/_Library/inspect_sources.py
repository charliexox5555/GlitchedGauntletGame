import bpy, os, json
from mathutils import Vector
ROOT=r'C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame'
IDS=['Vandal','Classic','Bulldog','Phantom','Guardian','Stinger','Spectre','Shorty','Ghost','Sheriff','Judge','Bucky','Marshal','Outlaw','Operator','Ares','Odin','Knife']
data={}
for gun in IDS:
    bpy.ops.wm.read_homefile(use_empty=True, use_factory_startup=True)
    with bpy.data.libraries.load(f'{ROOT}/art-source/weapons/{gun}.blend') as (src,dst):
        dst.collections=[gun]
    col=dst.collections[0]
    bpy.context.scene.collection.children.link(col)
    bpy.context.view_layer.update()
    meshes=[o for o in col.all_objects if o.type=='MESH']
    coords=[o.matrix_world@Vector(p) for o in meshes for p in o.bound_box]
    rig=next(o for o in col.all_objects if o.type=='ARMATURE')
    data[gun]={'bounds':[[min(v[i] for v in coords),max(v[i] for v in coords)] for i in range(3)],
        'bones':{b.name:{'head':list(b.head_local),'tail':list(b.tail_local),'parent':b.parent.name if b.parent else None} for b in rig.data.bones},
        'attachments':{o.name.removeprefix(gun+'_'):{'pos':list(o.matrix_world.translation),'matrix':[list(row) for row in o.matrix_world],'bone':o.parent_bone} for o in col.all_objects if o.type=='EMPTY'},
        'parts':{o.name.removeprefix(gun+'_'):{'bone':o.parent_bone,'bounds':[[min((o.matrix_world@Vector(p))[i] for p in o.bound_box),max((o.matrix_world@Vector(p))[i] for p in o.bound_box)] for i in range(3)]} for o in meshes}}
    # Read originals only, including helpers and animation definitions.
    for kind in ['build','anim']:
        path=f'{ROOT}/tools/blender/{kind}_{gun.lower()}.py'
        if os.path.exists(path):
            text=open(path,encoding='utf-8-sig').read()
            data[gun][kind+'_source_lines']=len(text.splitlines())
with open(f'{ROOT}/art-source/weapons/Remaster/_Library/source_contracts.json','w') as f: json.dump(data,f,indent=2)
result={g:{'bounds':d['bounds'],'bones':list(d['bones']),'attachments':{k:v['pos'] for k,v in d['attachments'].items()}} for g,d in data.items()}
