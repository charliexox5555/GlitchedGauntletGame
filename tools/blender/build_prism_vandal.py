"""Isolated Prism v01 author/bake pass. Run author() in the connected Blender.

Then bake the saved variant with Blender --background --python this_file -- --bake.
Stock geometry, UVs, bones, attachments and actions are never edited.
"""
import bpy
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art-source/weapons/Skins/Prism/Vandal/v01'
SOURCE = ROOT / 'art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend'
VARIANT = OUT / 'Vandal_Prism_v01.blend'
PALETTE = {
    'Body': ('C62878', .16, 0), 'Panel': ('541438', .20, 0),
    'Dark': ('15141A', .78, 0), 'Grip': ('211E27', .88, 0),
    'Metal': ('3F3945', .34, 1), 'Accent': ('A6718C', .22, 1),
    'Neon': ('FF79B8', .20, 0),
}

def linear(hexcode):
    rgb = [int(hexcode[i:i+2], 16)/255 for i in (0, 2, 4)]
    return tuple(c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in rgb)+(1,)

def signature():
    data = {}
    for o in bpy.data.collections['Vandal'].all_objects:
        row = {'type': o.type, 'matrix': [list(v) for v in o.matrix_local],
               'parent': o.parent.name if o.parent else None, 'bone': o.parent_bone}
        if o.type == 'MESH':
            row.update(vertices=[list(v.co) for v in o.data.vertices],
                       faces=[list(p.vertices) for p in o.data.polygons],
                       uv=[[list(v.uv) for v in lay.data] for lay in o.data.uv_layers])
        if o.type == 'ARMATURE':
            row['bones'] = [(b.name, list(b.head_local), list(b.tail_local)) for b in o.data.bones]
        data[o.name] = row
    return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()

def author():
    assert Path(bpy.data.filepath).resolve() == SOURCE.resolve(), 'Open the stock v05 source first'
    assert not VARIANT.exists(), 'Version already exists; do not overwrite'
    OUT.mkdir(parents=True, exist_ok=True)
    before = signature()
    # Keep role names, mesh names and material assignments for the established exporter.
    for role, (color, rough, metal) in PALETTE.items():
        mat = bpy.data.materials[role]
        nt = mat.node_tree
        bs = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        for name in ('Base Color', 'Roughness', 'Metallic'):
            for link in list(bs.inputs[name].links): nt.links.remove(link)
        bs.inputs['Base Color'].default_value = linear(color)
        bs.inputs['Roughness'].default_value = rough
        bs.inputs['Metallic'].default_value = metal
        bs.inputs['Coat Weight'].default_value = .35 if role in ('Body', 'Panel') else 0
        bs.inputs['Coat Roughness'].default_value = .12
        mat.diffuse_color = linear(color)
        mat['rbx_color'] = color
        if role == 'Neon': bs.inputs['Emission Color'].default_value = linear(color)
    # A quiet pink underprint reinforces the left-side signature in flat lighting.
    # It is not the specular highlight: Roughness supplies the moving reflection.
    nt = bpy.data.materials['Body'].node_tree
    bs = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ'); nt.links.new(geo.outputs['Position'], sep.inputs[0])
    def mathnode(op, a, b):
        n = nt.nodes.new('ShaderNodeMath'); n.operation = op
        for idx, value in enumerate((a,b)):
            if isinstance(value, (int,float)): n.inputs[idx].default_value=value
            else: nt.links.new(value,n.inputs[idx])
        return n.outputs[0]
    # Physical seam x~1.055; leave a visible 0.05-stud interruption on both sides.
    zband = mathnode('MULTIPLY', mathnode('GREATER_THAN',sep.outputs['Z'],.337), mathnode('LESS_THAN',sep.outputs['Z'],.352))
    side = mathnode('GREATER_THAN',sep.outputs['Y'],.068)
    span = mathnode('MULTIPLY', mathnode('GREATER_THAN',sep.outputs['X'],.04), mathnode('LESS_THAN',sep.outputs['X'],1.61))
    seam = mathnode('GREATER_THAN',mathnode('ABSOLUTE',mathnode('SUBTRACT',sep.outputs['X'],1.055),0),.026)
    mask = mathnode('MULTIPLY',mathnode('MULTIPLY',zband,side),mathnode('MULTIPLY',span,seam))
    mix=nt.nodes.new('ShaderNodeMixRGB'); mix.blend_type='MIX'
    nt.links.new(mathnode('MULTIPLY',mask,.16),mix.inputs[0])
    mix.inputs[1].default_value=linear('C62878'); mix.inputs[2].default_value=linear('FFB6DB')
    nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
    assert signature() == before, 'Surface pass changed structure'
    report={'source':str(SOURCE), 'variant':str(VARIANT), 'structure_sha256':before,
            'geometry_uv_rig_attachments_preserved':True, 'palette':PALETTE,
            'actions':[a.name for a in bpy.data.actions], 'textures':{}, 'studio':'pending'}
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(VARIANT))
    return report

def bake():
    assert Path(bpy.data.filepath).resolve() == VARIANT.resolve()
    spec=importlib.util.spec_from_file_location('skin_bake',ROOT/'tools/blender/bake_textures.py')
    mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    tex=OUT/'textures'; tex.mkdir(exist_ok=True)
    mod.out_dir=lambda: str(tex)
    mod.AO_STRENGTH=.22
    mod.EDGE_LIGHTEN=.06
    # Preserve actual roughness at edges: lacquer must not become a chrome outline.
    setup=mod.setup_bake_nodes
    def setup_clean(mat):
        setup(mat)
        mat.node_tree.nodes['BK_Rough'].inputs[1].default_value=-.025
        mat.node_tree.nodes['BK_Metal'].inputs[1].default_value=0
    mod.setup_bake_nodes=setup_clean
    sc=next(s for s in bpy.data.scenes if bpy.data.collections['Vandal'] in list(s.collection.children_recursive))
    bpy.context.window.scene=sc
    report=mod.bake('Vandal')
    manifest=json.loads((OUT/'manifest.json').read_text())
    assert signature()==manifest['structure_sha256']
    manifest['textures']=report
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(VARIANT))
    print('PRISM_BAKE_COMPLETE '+json.dumps(report),flush=True)

if __name__=='__main__':
    import sys
    if '--bake' in sys.argv: bake()
    else: author()
