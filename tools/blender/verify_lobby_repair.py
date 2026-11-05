import bpy,runpy,json,sys
from pathlib import Path
from mathutils import Matrix
root=Path(r'C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame')
p=root/'art-source/lobby'
scene=bpy.data.scenes.new('FullKitVerification');bpy.context.window.scene=scene
for group in ['Hub','Duels','Market','Weapons']:
 with bpy.data.libraries.load(str(p/f'Kit_{group}.blend'),link=False) as (d,l):l.collections=[n for n in d.collections if n.startswith('Lobby_')]
 for c in l.collections:scene.collection.children.link(c)
names=[v['name'] for v in json.loads((p/'SurfaceRepair_Changes.json').read_text())]
with bpy.data.libraries.load(str(p/'Kit_SurfaceRepair.blend'),link=False) as (d,l):l.objects=list(names)
for name,patch in zip(names,l.objects):
 original=bpy.data.objects[name];original.data=patch.data.copy();original.matrix_world=Matrix.Identity(4)
 bpy.data.objects.remove(patch,do_unlink=True)
bpy.context.view_layer.update()
sys.argv=['verify','--',str(p/'SurfaceRepair_Audit.json')]
runpy.run_path(str(root/'tools/blender/audit_lobby_coplanar.py'),run_name='__main__')
