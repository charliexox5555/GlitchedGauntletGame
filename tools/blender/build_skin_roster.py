"""Build versioned Blender reskins from the current concept queue.

blender -b -t 6 --python tools/blender/build_skin_roster.py -- --line Prism --item Phantom
blender -b -t 6 --python tools/blender/build_skin_roster.py -- --line Prism
"""
import argparse
from contextlib import contextmanager
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import traceback

import bpy
from mathutils import Vector
import numpy as np

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
ART = ROOT / "art-source/weapons"
VAULT = ROOT / "vault/02 Art/Skins"
REVIEW = ART / "Skins/Review"
LIB = ART / "RemasterV2/_Library"
sys.path[:0] = [str(TOOLS), str(LIB)]
import bake_textures as bake
import final_pass as framing
import model_sheet as sheet
from skin_graphics import HINGES, LAYOUT, linear, project

PALETTES = {
    "Prism": {
        "Body": ("C62878", .16, 0), "Panel": ("541438", .20, 0),
        "Dark": ("15141A", .78, 0), "Grip": ("211E27", .88, 0),
        "Metal": ("3F3945", .34, 1), "Accent": ("A6718C", .22, 1),
        "Neon": ("FF79B8", .20, 0),
    },
    "Redline": {
        "Body": ("741B2A", .68, 0), "Panel": ("33191F", .73, 0),
        "Dark": ("141316", .82, 0), "Grip": ("1D1B1E", .88, 0),
        "Metal": ("333138", .48, .86), "Accent": ("4B4248", .58, .68),
        "Neon": ("A93D49", .65, 0),
    },
    "Nitrous": {
        "Body": ("15171D", .35, 0), "Panel": ("BEC8D4", .40, .94),
        "Dark": ("111216", .77, 0), "Grip": ("22252B", .88, 0),
        "Metal": ("596370", .37, .88), "Accent": ("D1D9E2", .28, 1),
        "Neon": ("3D9DFF", .29, 0),
    },
    "PopCircuit": {
        "Body": ("539BFF", .38, .26), "Panel": ("FF9DD8", .34, .23),
        "Dark": ("231B45", .75, 0), "Grip": ("29203C", .86, 0),
        "Metal": ("6554C9", .36, .70), "Accent": ("FF6ECA", .27, .68),
        "Neon": ("61F2FF", .24, 0),
    },
}
PROTECTED = re.compile(r"scope|lens|(^|_)sights?$|rear.?sight|front.?sight|aimpoint|charmloop|round|feedbelt|shell(upper|lower)?$|speedloader|cylinder$", re.I)


def queue():
    items = []
    for line in (VAULT / "Concept Sheet Queue.md").read_text(encoding="utf-8").splitlines():
        heading = re.fullmatch(r"## (Prism|Redline|Nitrous|PopCircuit)", line)
        if heading:
            group = heading[1]
        row = re.match(r"\| (\w+) \| \[.*?\]\(((?:Prism|Redline|Nitrous|PopCircuit)/out/[^)]+)\)", line)
        if row:
            items.append((group, row[1], VAULT / row[2]))
    assert len(items) == 71 and len(set((line, item) for line, item, _ in items)) == 71
    return items


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def rel(path):
    return path.relative_to(ROOT).as_posix()


def mesh_objects(item):
    return bake.gun_meshes(item)


def matrix(value):
    return [list(v) for v in value]


def scene_for(item):
    collection = bpy.data.collections[item]
    return next(s for s in bpy.data.scenes if collection in s.collection.children_recursive[:])


def fingerprints(item):
    objects, geometry, uv, rig, actions = {}, {}, {}, {}, {}
    for ob in bpy.data.collections[item].all_objects:
        objects[ob.name] = (ob.type, ob.parent.name if ob.parent else None, ob.parent_type,
                            ob.parent_bone, matrix(ob.matrix_basis), matrix(ob.matrix_parent_inverse),
                            [(m.name, m.type) for m in ob.modifiers])
        if ob.type == "MESH":
            mesh = ob.data
            geometry[ob.name] = ([list(v.co) for v in mesh.vertices],
                                 [(list(p.vertices), p.material_index, p.use_smooth) for p in mesh.polygons],
                                 [slot.name for slot in ob.material_slots])
            uv[ob.name] = [(lay.name, [list(v.vector) for v in lay.uv]) for lay in mesh.uv_layers]
        if ob.type == "ARMATURE":
            animation = ob.animation_data
            rig[ob.name] = (
                [(b.name, b.parent.name if b.parent else None, matrix(b.matrix_local),
                  list(b.head_local), list(b.tail_local)) for b in ob.data.bones],
                [(track.name, track.mute, [(s.name, s.action.name, s.frame_start, s.frame_end,
                   s.action_frame_start, s.action_frame_end, s.repeat, s.scale, s.blend_type)
                   for s in track.strips]) for track in animation.nla_tracks] if animation else [],
                animation.action.name if animation and animation.action else None,
            )
    for action in bpy.data.actions:
        channels = []
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    curves = [
                        (curve.data_path, curve.array_index, curve.extrapolation, [
                            (list(k.co), list(k.handle_left), list(k.handle_right), k.interpolation)
                            for k in curve.keyframe_points
                        ]) for curve in bag.fcurves
                    ]
                    channels.append((layer.name, bag.slot.identifier, curves))
        markers = action.get("gg_markers")
        actions[action.name] = (channels, [(p.name, p.frame) for p in action.pose_markers],
                                markers.to_dict() if markers else {})
    return {k: digest(v) for k, v in (("hierarchy_pivots_attachments", objects),
                                       ("geometry_and_material_slots", geometry), ("uv", uv),
                                       ("rig_and_nla", rig), ("actions", actions))}


def audit_uv(objs, size=512):
    owners = np.zeros((size, size), dtype=np.int32)
    surfaces = np.zeros((size, size), dtype=np.int32)
    shared = role_conflicts = self_overlap = 0
    affected = set()
    for index, ob in enumerate(objs, 1):
        mesh = ob.data
        uv = mesh.uv_layers.active
        assert uv, f"{ob.name} has no UV atlas"
        coords = np.array([list(k.vector) for k in uv.uv])
        assert np.all((coords >= -1e-6) & (coords <= 1+1e-6)), f"{ob.name} UVs exceed the atlas"
        coords *= size
        mesh.calc_loop_triangles()
        for tri in mesh.loop_triangles:
            p,q,r = coords[list(tri.loops)]
            a,b = q-p,r-p
            det = a[0]*b[1]-a[1]*b[0]
            assert abs(det)>1e-10, f"{ob.name} has a degenerate UV triangle"
            x0,y0 = np.maximum(np.floor(np.min([p,q,r],axis=0)).astype(int),0)
            x1,y1 = np.minimum(np.ceil(np.max([p,q,r],axis=0)).astype(int),size)
            x,y = np.meshgrid(np.arange(x0,x1)+.5-p[0],np.arange(y0,y1)+.5-p[1])
            u,v = (x*b[1]-y*b[0])/det,(a[0]*y-a[1]*x)/det
            inside = (u>1e-6)&(v>1e-6)&(u+v<1-1e-6)
            tile = owners[y0:y1,x0:x1]
            roles = surfaces[y0:y1,x0:x1]
            past = tile[inside]
            cross = (past>0)&(past!=index)
            conflict = (past>0)&(roles[inside]!=tri.material_index+1)
            shared += int(np.count_nonzero(cross))
            self_overlap += int(np.count_nonzero(past==index))
            role_conflicts += int(np.count_nonzero(conflict))
            if np.any(cross|conflict):
                affected.add(ob.name)
            tile[inside] = index
            roles[inside] = tri.material_index+1
    return {"audit_pixels_per_axis":size, "used_pixels":int(np.count_nonzero(owners)),
            "cross_object_overlap_pixels":shared, "same_object_overlap_pixels":self_overlap,
            "different_role_overlap_pixels":role_conflicts, "conflicting_parts":sorted(affected)}


def projected_images(line, item):
    names = ["Left", "Right"] if line in ("Nitrous", "PopCircuit") else ["Left"]
    if item in HINGES and line in ("Nitrous", "PopCircuit"):
        names += ["Hinge"]
    result = {}
    for side in names:
        bounds, color, finish = project(line, item, side, hinged=side=="Hinge")
        images = []
        for label, data in (("Color", color), ("Finish", finish)):
            height,width,_ = data.shape
            # Store linear channel values. The shader applies alpha as the mask.
            img = bpy.data.images.new(f"{item} {line} {side} artwork {label}", width, height,
                                      alpha=True, float_buffer=True)
            img.colorspace_settings.name = "Non-Color"
            img.alpha_mode = "CHANNEL_PACKED"
            img.pixels.foreach_set(data.ravel())
            img.pack()
            images.append(img)
        result[side] = (bounds,*images)
    return result


class Nodes:
    def __init__(self, tree):
        self.tree = tree

    def node(self, kind, label, **kwargs):
        n = self.tree.nodes.new("ShaderNode"+kind)
        n.label = label
        for key,value in kwargs.items():
            setattr(n,key,value)
        return n

    def set(self, socket, value):
        for link in list(socket.links):
            self.tree.links.remove(link)
        if isinstance(value, bpy.types.NodeSocket):
            self.tree.links.new(value,socket)
        else:
            if socket.type == "RGBA" and isinstance(value, (int, float)):
                value = (value, value, value, 1)
            socket.default_value = value

    def math(self, operation, a, b=0):
        n = self.node("Math", operation.replace("_"," ").title(), operation=operation)
        self.set(n.inputs[0],a)
        self.set(n.inputs[1],b)
        return n.outputs[0]

    def mix(self, factor, a, b, color=False):
        n = self.node("Mix", "Surface blend", data_type="RGBA" if color else "FLOAT")
        if color:
            i,j,k=6,7,2
        else:
            i,j,k=2,3,0
        self.set(n.inputs[0],factor)
        self.set(n.inputs[i],a)
        self.set(n.inputs[j],b)
        return n.outputs[k]

    def attr(self, name, kind="GEOMETRY"):
        return self.node("Attribute", name, attribute_type=kind, attribute_name=name)

    def decal(self, data, x, z):
        (lo,hi,bottom,top), color, finish = data
        vector = self.node("CombineXYZ", "Panel projection")
        self.set(vector.inputs[0],self.math("DIVIDE",self.math("SUBTRACT",x,lo),hi-lo))
        self.set(vector.inputs[1],self.math("DIVIDE",self.math("SUBTRACT",z,bottom),top-bottom))
        nodes = [self.node("TexImage", image.name, image=image, extension="CLIP")
                 for image in (color,finish)]
        for node in nodes:
            self.set(node.inputs["Vector"],vector.outputs[0])
        channels = self.node("SeparateXYZ", "Roughness and metalness")
        self.set(channels.inputs[0],nodes[1].outputs["Color"])
        return nodes[0].outputs["Alpha"],nodes[0].outputs["Color"],channels.outputs[0],channels.outputs[1]


def original_inputs(bsdf, keys):
    return [bake.source(bsdf.id_data, bsdf.inputs[k]) or
            (tuple(bsdf.inputs[k].default_value) if k=="Base Color" else bsdf.inputs[k].default_value)
            for k in keys]


def organize_tree(tree, initial, bsdf, keys):
    levels = {bsdf:0}
    frontier = [bsdf]
    while frontier:
        current = frontier.pop()
        for inp in current.inputs:
            for link in inp.links:
                node = link.from_node
                if node in initial:
                    continue
                depth = levels[current]+1
                if levels.get(node,-1) < depth:
                    levels[node] = depth
                    frontier.append(node)
    counts = {}
    for node,depth in levels.items():
        if node == bsdf:
            continue
        column = counts.get(depth,0)
        node.location = (-250*depth,-column*252)
        counts[depth] = column+1
    for i,node in enumerate(initial - {bsdf}):
        node.location = (-200-210*(i%5),370+245*(i//5))


def author(line, item, objs):
    palette = PALETTES[line]
    _,_,_,_,parts = LAYOUT[item]
    parts = set(parts.split())
    artworks = projected_images(line,item)
    protected = []
    for ob in objs:
        suffix = ob.name.split("_",1)[-1]
        keep = bool(PROTECTED.search(suffix))
        if keep:
            protected.append(ob.name)
        ob["skin_stock_surface"] = float(keep)
        ob["skin_graphic_panel"] = float(suffix in parts and suffix!="Barrels")
        ob["skin_hinged_panel"] = float(suffix=="Barrels" and item in HINGES)
        ob["skin_blade"] = float(item=="Knife" and suffix=="Blade")
        attr = ob.data.attributes.new("Skin rest position","FLOAT_VECTOR","POINT")
        coords = np.array([list(ob.matrix_world @ v.co) for v in ob.data.vertices],dtype=np.float32)
        attr.data.foreach_set("vector",coords.ravel())

    for mat in bake.gun_materials(item):
        if mat.name not in palette:
            continue
        role = mat.name
        hexcode,rough,metal = palette[role]
        tree = mat.node_tree
        graph = Nodes(tree)
        bs = next(n for n in tree.nodes if n.type=="BSDF_PRINCIPLED")
        orig = set(tree.nodes)
        keys = ("Base Color","Roughness","Metallic")
        original = original_inputs(bs,keys)
        color = (*linear(hexcode),1)
        finish = (color,rough,metal)
        preserve = graph.attr("skin_stock_surface","OBJECT").outputs["Fac"]
        mat.diffuse_color = color
        mat["rbx_color"] = hexcode
        if role == "Neon":
            bs.inputs["Emission Color"].default_value = color
            bs.inputs["Emission Strength"].default_value = .65 if line=="Redline" else 1.55
            bs.inputs["Base Color"].default_value = color
            continue
        if role in ("Body","Panel") or (item=="Knife" and role=="Metal"):
            coord = graph.attr("Skin rest position").outputs["Vector"]
            axis = graph.node("SeparateXYZ","Rest-space axes")
            graph.set(axis.inputs[0],coord)
            x,y,z = axis.outputs
            x0,x1 = LAYOUT[item][0]
            if line=="Redline":
                fade = graph.node("MapRange","Muzzle to receiver", interpolation_type="SMOOTHERSTEP")
                for k,v in (("Value",x),("From Min",x0-.13),("From Max",x1+.04)):
                    graph.set(fade.inputs[k],v)
                front = "20191D" if role=="Body" else "231B20"
                rear = "551D2A" if role=="Panel" else hexcode
                if role=="Metal":
                    front,rear = "29252C","4F2430"
                shade = graph.mix(fade.outputs["Result"],(*linear(rear),1),(*linear(front),1),True)
                noise = graph.node("TexNoise","Fine dry grain")
                graph.set(noise.inputs["Vector"],coord)
                noise.inputs["Scale"].default_value = 170
                strength = graph.math("MULTIPLY_ADD",noise.outputs["Fac"],.09)
                strength.node.inputs[2].default_value = -.043
                finish = (graph.mix(graph.math("ABSOLUTE",strength),shade,(*linear("D98587"),1),True),
                          graph.math("ADD",rough,strength),metal)
            elif line=="Nitrous" and role=="Panel":
                streak = graph.node("VectorMath","Along the brush", operation="MULTIPLY")
                graph.set(streak.inputs[0],coord)
                graph.set(streak.inputs[1],(15,85,280))
                noise = graph.node("TexNoise","Fine directional brush")
                graph.set(noise.inputs["Vector"],streak.outputs[0])
                noise.inputs["Scale"].default_value = 1
                fade = graph.math("MULTIPLY",noise.outputs["Fac"],.34)
                finish = (graph.mix(fade,color,(*linear("798CA3"),1),True),
                          graph.math("ADD",rough,graph.math("MULTIPLY",noise.outputs["Fac"],.09)),metal)
            elif line=="Prism" and role=="Metal":
                finish = ((*linear("822351"),1),.27,.85)

            panel = graph.attr("skin_graphic_panel","OBJECT").outputs["Fac"]
            hinge = graph.attr("skin_hinged_panel","OBJECT").outputs["Fac"]
            for side,data in artworks.items():
                # Color-block art wraps onto upper planes. Signatures use the player-facing side.
                sign = "LESS_THAN" if side=="Right" else "GREATER_THAN"
                if line in ("Prism","Redline"):
                    edge = .003 if item=="Knife" else .034
                else:
                    edge = 0
                mask_side = graph.math(sign,y,-edge if side=="Right" else edge)
                gate = hinge if side=="Hinge" else panel
                if side=="Hinge":
                    mask_side = 1
                alpha,*tints = graph.decal(data,x,z)
                factor = graph.math("MULTIPLY",alpha,graph.math("MULTIPLY",mask_side,gate))
                finish = tuple(graph.mix(factor,a,b,i==0) for i,(a,b) in enumerate(zip(finish,tints)))
            if line=="Prism" and role in ("Body","Panel"):
                graph.set(bs.inputs["Coat Weight"],graph.math("MULTIPLY",.35,graph.math("SUBTRACT",1,preserve)))
                bs.inputs["Coat Roughness"].default_value = .12

        for i,(name,value,stock) in enumerate(zip(keys,finish,original)):
            graph.set(bs.inputs[name],graph.mix(preserve,value,stock,i==0))
        organize_tree(tree,orig,bs,keys)
    return sorted(protected)


@contextmanager
def bake_selection(scene, objs):
    before = [(ob,ob.hide_get(),ob.hide_render,ob.select_get()) for ob in bpy.context.view_layer.objects]
    active = bpy.context.view_layer.objects.active
    engine = scene.render.engine
    try:
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        for ob,_,_,_ in before:
            ob.select_set(False)
        for ob in objs:
            ob.hide_set(False)
            ob.hide_render = False
            ob.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        yield
    finally:
        for ob,hidden,render,selected in before:
            ob.select_set(selected)
            ob.hide_set(hidden)
            ob.hide_render = render
        bpy.context.view_layer.objects.active = active
        scene.render.engine = engine


def bake_maps(item, scene, objs, dest):
    # Reuse the shared image names, colour spaces, and baked-material preview.
    dest.mkdir()
    bake.out_dir = lambda: str(dest)
    images = bake.images(item)
    materials = bake.gun_materials(item)
    states = {}
    for mat in materials:
        nt = mat.node_tree
        graph = Nodes(nt)
        bsdf = next(n for n in nt.nodes if n.type=="BSDF_PRINCIPLED")
        output = next(n for n in nt.nodes if n.type=="OUTPUT_MATERIAL" and n.is_active_output)
        output.name = "Shader_Out"
        emit = graph.node("Emission","Bake output")
        scratch = graph.node("OutputMaterial","Bake surface")
        scratch.name = "Skin_Bake"
        target = graph.node("TexImage","Bake target")
        graph.set(scratch.inputs["Surface"],emit.outputs[0])
        color, rough, metal = original_inputs(bsdf,("Base Color","Roughness","Metallic"))
        if bsdf.inputs["Emission Strength"].default_value > 0:
            color = bsdf.inputs["Emission Color"].default_value[:]
        else:
            ao = graph.node("AmbientOcclusion","Light contact shading",samples=4)
            ao.inputs["Distance"].default_value = .045
            shade = graph.math("MULTIPLY_ADD",ao.outputs["AO"],.17)
            shade.node.inputs[2].default_value = .83
            color_mix = graph.node("MixRGB","Baked contact shading",blend_type="MULTIPLY")
            color_mix.inputs[0].default_value = 1
            graph.set(color_mix.inputs[1],color)
            graph.set(color_mix.inputs[2],shade)
            color = color_mix.outputs[0]
        states[mat.name] = (graph,emit,scratch,target,(color,rough,metal))

    with bake_selection(scene,objs):
        for name in bake.MAPS:
            img = images[name]
            for mat in materials:
                graph,emit,scratch,target,values = states[mat.name]
                target.image = img
                graph.tree.nodes.active = target
                if name == "Normal":
                    bake.set_active_output(mat,"Shader_Out")
                else:
                    graph.set(emit.inputs["Color"],values[("Color","Roughness","Metalness").index(name)])
                    bake.set_active_output(mat,"Skin_Bake")
            scene.cycles.samples = 4 if name=="Color" else 1
            kwargs = dict(margin=6,margin_type="EXTEND",use_clear=True)
            if name=="Normal":
                result = bpy.ops.object.bake(type="NORMAL",normal_space="TANGENT",
                                            normal_r="POS_X",normal_g="POS_Y",normal_b="POS_Z",**kwargs)
            else:
                result = bpy.ops.object.bake(type="EMIT",**kwargs)
            assert result=={"FINISHED"}, f"{item} {name} bake failed: {result}"
            img.save(filepath=img.filepath_raw)
            assert Path(img.filepath_raw).stat().st_size > 1000
    for mat in materials:
        bake.set_active_output(mat,"Shader_Out")
        graph,emit,scratch,target,_ = states[mat.name]
        # The transient bake helpers are disconnected from the editable authored output.
        for n in list(graph.tree.nodes):
            if n in (emit,scratch,target) or n.label in (
                "Light contact shading","Baked contact shading"
            ) or (n.label=="Multiply Add" and n.outputs[0].is_linked is False):
                graph.tree.nodes.remove(n)
    for name,generated in images.items():
        filename = f"{item}_{name}.png"
        loaded = bpy.data.images.load(str(dest/filename), check_existing=False)
        loaded.colorspace_settings.name = generated.colorspace_settings.name
        assert tuple(loaded.size) == (bake.RES, bake.RES)
        loaded.pack()
        loaded.filepath = "//textures/" + filename
        bpy.data.images.remove(generated)
        loaded.name = f"{item}_{name}"
    bake.preview_nodes(item)
    for mat in materials:
        if mat.name in ("Glass","Brass","Neon"):
            continue
        # Keep baked preview selected for a reliable result in both Eevee and Cycles.
        bake.set_active_output(mat,"PV_Out")


def configure_review(item, scene):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.image_settings.color_mode = "RGBA"
    rc = bpy.data.collections.get(item+"_RV2_Lights")
    if rc:
        rc.hide_render = True
    studio = bpy.data.collections.get(item+"_MS_Lights")
    if studio:
        studio.hide_render = False
    scene.render.film_transparent = True


def review(item, scene, dest, detail=False):
    dest.mkdir(parents=True,exist_ok=True)
    configure_review(item,scene)
    res = (560,260)
    pts = sheet._pts(item)
    for label,toward in (("Left",(0,1,0)),("Right",(0,-1,0))):
        cam,c,r = sheet._cam(item,label,pts,toward,ortho=True,aspect=res[0]/res[1],margin=1.08)
        sheet._lights(item,cam,c,r)
        framing.shot(item,cam,str(dest/f"{label}.png"),res=res)
    if item in framing.HIP:
        cam = framing.hip_cam(item)
    else:
        cam,_,_ = sheet._cam(item,"Hip",pts,(-.68,.79,.52),lens=49,aspect=res[0]/res[1],margin=1.15)
    lo,hi = framing.bounds(item)
    sheet._lights(item,cam,(lo+hi)/2,(hi-lo).length/2)
    framing.shot(item,cam,str(dest/"FirstPerson.png"),res=res)
    if detail:
        x,z = LAYOUT[item][1]
        h = LAYOUT[item][2]
        box = [Vector((x+i*3.5*h, .085, z+j*h)) for i in (-1,1) for j in (-1,1)]
        cam,c,r = sheet._cam(item,"Detail",box,(.09,1,.22),ortho=True,aspect=2.15,margin=1.16)
        sheet._lights(item,cam,c,r)
        framing.shot(item,cam,str(dest/"Detail.png"),res=(860,400))


def review_motion(line, item, scene, dest):
    checks = {
        ("Prism","Phantom"): ("Reload", "Mag", (0,.78,.42)),
        ("Redline","Classic"): ("Inspect", "Slide", (-.10,.81,.31)),
        ("Nitrous","Outlaw"): ("ReloadEmpty", "Barrels", (.04,.94,.25)),
        ("PopCircuit","Shorty"): ("ReloadEmpty", "Barrels", (.06,.93,.24)),
    }
    if (line,item) not in checks:
        return
    configure_review(item,scene)
    dest.mkdir(parents=True,exist_ok=True)
    clip,bone,toward = checks[line,item]
    rig = bpy.data.objects[item+"_Rig"]
    animation = rig.animation_data
    action = bpy.data.actions[f"{item}_{clip}"]
    animation.action = action
    start,end = (round(f) for f in action.frame_range)
    scene.frame_set(start)
    basis = rig.pose.bones[bone].matrix.copy()
    def movement(frame):
        scene.frame_set(frame)
        delta = basis.inverted() @ rig.pose.bones[bone].matrix
        return delta.translation.length + delta.to_quaternion().angle
    frame = max(range(start,end+1),key=movement)
    scene.frame_set(frame)
    assert movement(frame)>.02, f"{item} {clip} did not move {bone}"
    pts = sheet._pts(item)
    res = (860,400)
    cam,c,r = sheet._cam(item,"Motion",pts,toward,ortho=True,aspect=res[0]/res[1],margin=1.10)
    sheet._lights(item,cam,c,r)
    framing.shot(item,cam,str(dest/f"{clip}-{frame}.png"),res=res)


def write_json(path, value):
    path.write_text(json.dumps(value,indent=2)+"\n",encoding="utf-8")


def reskin(line,item,concept,version,skip_render=False):
    source = ART / "RemasterV2" / item / f"{item}_RemasterV2_v05.blend"
    dest = ART / "Skins" / line / item / version
    stem = f"{item}_{line}_{version}"
    staging = dest.with_name("." + dest.name + "-building")
    target = dest / (stem+".blend")
    if dest.exists():
        if target.exists() and (dest/"manifest.json").exists():
            print(f"EXISTS {line}/{item}/{version}",flush=True)
            return target
        raise RuntimeError(f"Partial delivery exists at {dest}")
    dest.parent.mkdir(parents=True,exist_ok=True)
    staging.mkdir()
    try:
        bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
        scene = scene_for(item)
        bpy.context.window.scene = scene
        bpy.context.view_layer.update()
        before = fingerprints(item)
        objs = mesh_objects(item)
        uv = audit_uv(objs)
        if uv["cross_object_overlap_pixels"]:
            raise ValueError(f"Shared atlas has inter-object overlap: {uv}")
        protected = author(line,item,objs)
        bake_maps(item,scene,objs,staging/"textures")
        assert before==fingerprints(item), "Stock fingerprints changed"
        report = {
            "line":line, "item":item, "version":version, "source":rel(source),
            "source_file_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),
            "concept":rel(concept), "blend":rel(target),
            "build_status":"baked", "studio_status":"pending Blender approval",
            "palette_color_roughness_metalness":PALETTES[line], "uv":uv,
            "fingerprints":before, "actions":sorted(bpy.data.actions.keys()),
            "protected_objects":protected, "stock_uv_preserved":True,
            "textures":{name:rel(dest/"textures"/f"{item}_{name}.png") for name in bake.MAPS},
            "texture_sha256":{name:hashlib.sha256((staging/"textures"/f"{item}_{name}.png").read_bytes()).hexdigest()
                              for name in bake.MAPS},
        }
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(staging/target.name),compress=True,relative_remap=False)
        bpy.ops.wm.open_mainfile(filepath=str(staging/target.name),load_ui=False)
        scene = scene_for(item)
        bpy.context.window.scene = scene
        bpy.context.view_layer.update()
        assert before == fingerprints(item), "Saved Blender structure differs from the stock file"
        for name in bake.MAPS:
            img = bpy.data.images[f"{item}_{name}"]
            assert img.packed_file and tuple(img.size) == (bake.RES,bake.RES), f"Saved {name} map is missing"
        report["saved_file_verified"] = True
        report["texture_settings"] = {
            "dimensions": [bake.RES, bake.RES], "padding_pixels": 6,
            "Color": "sRGB", "Normal": "OpenGL tangent space (+Y)",
            "Roughness": "Non-Color", "Metalness": "Non-Color",
        }
        write_json(staging/"manifest.json",report)
        staging.rename(dest)
    except Exception:
        if staging.is_dir() and staging.resolve().parent == dest.parent.resolve():
            for file in (staging / "textures").glob("*.png"):
                file.unlink()
            if (staging / "textures").is_dir():
                (staging / "textures").rmdir()
            for file in staging.iterdir():
                if file.is_file():
                    file.unlink()
            staging.rmdir()
        raise
    if not skip_render:
        review(item,scene,REVIEW/"renders"/line/item/version,detail=item in (
            "Phantom","Vandal","Guardian","Sheriff","Classic","Outlaw","Knife"))
    print(f"BAKED {line}/{item}/{version}",flush=True)
    return target


def main():
    sheet.bind(vars(framing))
    args = argparse.ArgumentParser()
    args.add_argument("--line", choices=PALETTES)
    args.add_argument("--item", nargs="+")
    args.add_argument("--version",default="v01")
    args.add_argument("--skip-render", action="store_true")
    args.add_argument("--render-only", action="store_true")
    args.add_argument("--motion-only", action="store_true")
    opts = args.parse_args(sys.argv[sys.argv.index("--")+1:])
    entries = [(line,item,concept) for line,item,concept in queue()
               if (not opts.line or line==opts.line) and (not opts.item or item in opts.item)]
    assert entries, "No queue entries matched"
    assert re.fullmatch(r"v\d{2}",opts.version)
    failed = []
    for line,item,concept in entries:
        if item=="Bat":
            continue
        if (line,item)==("Prism","Vandal") and opts.version=="v01" and not opts.render_only:
            continue
        try:
            if opts.render_only or opts.motion_only:
                path = ART/"Skins"/line/item/opts.version/f"{item}_{line}_{opts.version}.blend"
                if not path.is_file():
                    continue
                bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False)
                scene = scene_for(item)
                bpy.context.window.scene = scene
                bpy.context.view_layer.update()
                if (line,item)==("Prism","Vandal"):
                    bake.preview(item,True)
                dest = REVIEW/"renders"/line/item/opts.version
                if opts.motion_only:
                    review_motion(line,item,scene,dest)
                else:
                    review(item,scene,dest,detail=True)
            else:
                reskin(line,item,concept,opts.version,opts.skip_render)
        except Exception:
            failed.append((line,item))
            traceback.print_exc()
    if failed:
        raise RuntimeError(f"Failed entries: {failed}")


if __name__=="__main__":
    main()

