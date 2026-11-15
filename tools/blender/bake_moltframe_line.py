"""Bake + Roblox export for a Moltframe skin built by the v04 builders.

Run in the Blender MCP session after the item's builder, with:
    ITEM = "Vandal"            # also used for file names
    OUT  = r"...\\Skins\\Moltframe\\<Item>\\v04"
    ATLAS_OBJECTS = [...]      # shell + retained hardware copies
    CHAMBER_BOUNDS = (x0, x1, z0, z1)   # side extent mapped onto the chamber map
exec(open(this_file).read())

Produces (OUT/textures):
  <Item>_Atlas_Color.png   albedo x baked AO (1024, all armour/grip/core faces)
  <Item>_Atlas_Rough.png   roughness
  <Item>_Atlas_Metal.png   metalness
  <Item>_Chamber_Color.png marbled fluid (side projection, u = x, v = z) x AO
and OUT/<Item>_Moltframe_Roblox.fbx with up to four meshes per bone:
  MF_<Bone>_Body (atlas UV) and MF_<Bone>_Chamber (chamber UV).
Returns `bake_report` with Roblox geometry checks per exported mesh.
"""

import bpy, bmesh, os, math
import numpy as np
from mathutils import Vector

TEX = os.path.join(OUT, "textures")
os.makedirs(TEX, exist_ok=True)
VIOLET_NAME = "MF4 Violet Chamber"
RES = 1024
sc = bpy.context.scene

def _img(name, w, h, non_color=False):
    # bake targets are float buffers; keep them linear (Non-Color) so the
    # numpy pass sees linear values and encodes sRGB exactly once on save
    im = bpy.data.images.get(name)
    if im and (im.size[0] != w or im.size[1] != h):
        bpy.data.images.remove(im); im = None
    if im is None:
        im = bpy.data.images.new(name, w, h, alpha=False, float_buffer=True)
    im.colorspace_settings.name = "Non-Color"
    return im

def _target(image):
    """Make `image` the active bake target in every material in use."""
    mats = {s.material for o in sc.objects if o.type == "MESH" for s in o.material_slots if s.material}
    for m in mats:
        nt = m.node_tree
        n = nt.nodes.get("BakeTarget") or nt.nodes.new("ShaderNodeTexImage")
        n.name = n.label = "BakeTarget"
        n.image = image
        nt.nodes.active = n

def _uv(obj, name):
    me = obj.data
    return me.uv_layers.get(name) or me.uv_layers.new(name=name)

def _select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.hide_set(False); o.hide_render = False; o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]

def atlas_unwrap(objs):
    for o in objs:
        _uv(o, "Atlas")
        o.data.uv_layers.active = o.data.uv_layers["Atlas"]
    _select_only(objs)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0, area_weight=0.0,
                             correct_aspect=False, scale_to_bounds=False)
    # even texel density across all parts, then fill the square (40%+ use;
    # the default pack left 4% of the atlas covered)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(udim_source="CLOSEST_UDIM", rotate=True, scale=True,
                            margin_method="FRACTION", margin=.003, shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")

def chamber_uv(objs):
    x0, x1, z0, z1 = CHAMBER_BOUNDS
    for o in objs:
        uv = _uv(o, "Chamber")
        me = o.data
        for p in me.polygons:
            for li in p.loop_indices:
                co = me.vertices[me.loops[li].vertex_index].co
                uv.data[li].uv = ((co.x - x0) / (x1 - x0), (co.z - z0) / (z1 - z0))
            # only fluid faces own chamber texels; park the rest in an unused corner
            m = me.materials[p.material_index]
            if not (m and m.name == VIOLET_NAME):
                for li in p.loop_indices:
                    uv.data[li].uv = (.9995, .9995)

def _bake(kind, image, objs, **kw):
    _target(image)
    _select_only(objs)
    bpy.ops.object.bake(type=kind, margin=6, use_clear=True, **kw)
    return np.array(image.pixels[:], dtype=np.float32).reshape(image.size[1], image.size[0], 4)

def _save(arr, name, non_color=False):
    h, w = arr.shape[:2]
    im = bpy.data.images.new(name + "_out", w, h, alpha=False)
    im.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    a = np.ones((h, w, 4), np.float32); a[..., :3] = np.clip(arr[..., :3], 0, 1)
    im.pixels[:] = a.ravel()
    im.filepath_raw = os.path.join(TEX, name + ".png"); im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)
    return os.path.join(TEX, name + ".png")

def _as_emit(channel):
    """Route a Principled input (its link or value) into Emission for an EMIT
    bake. Cycles' DIFFUSE colour pass is black on metallic surfaces, so base
    colour and metalness are both baked this way. Returns an undo list."""
    undo = []
    for m in bpy.data.materials:
        if not m.use_nodes: continue
        nt = m.node_tree
        b = nt.nodes.get("Principled BSDF")
        if not b: continue
        ec, es = b.inputs["Emission Color"], b.inputs["Emission Strength"]
        old_links = [(l.from_socket, l.to_socket) for l in nt.links if l.to_socket == ec]
        undo.append((m, tuple(ec.default_value), es.default_value, old_links))
        for l in [l for l in nt.links if l.to_socket == ec]:
            nt.links.remove(l)
        src = b.inputs[channel]
        if src.is_linked:
            nt.links.new(src.links[0].from_socket, ec)
        else:
            v = src.default_value
            ec.default_value = (v, v, v, 1) if isinstance(v, float) else tuple(v)
        es.default_value = 1.0
    return undo

def _restore(undo):
    for m, col, strength, links in undo:
        nt = m.node_tree; b = nt.nodes["Principled BSDF"]
        ec = b.inputs["Emission Color"]
        for l in [l for l in nt.links if l.to_socket == ec]:
            nt.links.remove(l)
        for a, z in links:
            nt.links.new(a, z)
        ec.default_value = col
        b.inputs["Emission Strength"].default_value = strength

def _emit_bake(channel, image, objs):
    undo = _as_emit(channel)
    try:
        return _bake("EMIT", image, objs)
    finally:
        _restore(undo)

def run():
    objs = [bpy.data.objects[n] for n in ATLAS_OBJECTS]
    prev_engine = sc.render.engine
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = False
    sc.world.light_settings.distance = .08
    atlas_unwrap(objs)
    chamber_uv(objs)
    # --- atlas maps
    for o in objs: o.data.uv_layers.active = o.data.uv_layers["Atlas"]
    col = _emit_bake("Base Color", _img("MF_bake_col", RES, RES, True), objs)
    ao = _bake("AO", _img("MF_bake_ao", RES, RES, True), objs)
    rough = _bake("ROUGHNESS", _img("MF_bake_rough", RES, RES, True), objs)
    metal = _emit_bake("Metallic", _img("MF_bake_metal", RES, RES, True), objs)
    aof = .58 + .42 * ao[..., :1]
    # bake buffers are linear float; convert albedo to sRGB for the PNG
    lin = col[..., :3] * aof
    srgb = np.where(lin <= .0031308, lin * 12.92, 1.055 * np.power(np.clip(lin, 0, None), 1 / 2.4) - .055)
    paths = [_save(srgb, ITEM + "_Atlas_Color"), _save(rough, ITEM + "_Atlas_Rough", True),
             _save(metal, ITEM + "_Atlas_Metal", True)]
    # --- chamber map (fluid colour x its own AO, side projection)
    for o in objs: o.data.uv_layers.active = o.data.uv_layers["Chamber"]
    vio = [o for o in objs if any(o.data.materials[p.material_index] and
                                   o.data.materials[p.material_index].name == VIOLET_NAME for p in o.data.polygons)]
    if not vio:
        for o in objs: o.data.uv_layers.active = o.data.uv_layers["Atlas"]
        sc.render.engine = prev_engine
        return paths
    cw, ch = 2048, max(256, int(2048 * (CHAMBER_BOUNDS[3] - CHAMBER_BOUNDS[2]) / (CHAMBER_BOUNDS[1] - CHAMBER_BOUNDS[0])))
    vcol = _emit_bake("Base Color", _img("MF_bake_vcol", cw, ch, True), vio)
    vao = _bake("AO", _img("MF_bake_vao", cw, ch, True), vio)
    # deeper than the raw albedo: the Blender look also gets depth from the
    # clear coat and grazing reflections, which Roblox's PBR does not have
    lin = (vcol[..., :3] * .78) ** 1.12 * (.40 + .60 * vao[..., :1])
    srgb = np.where(lin <= .0031308, lin * 12.92, 1.055 * np.power(np.clip(lin, 0, None), 1 / 2.4) - .055)
    paths.append(_save(srgb, ITEM + "_Chamber_Color"))
    for o in objs: o.data.uv_layers.active = o.data.uv_layers["Atlas"]
    sc.render.engine = prev_engine
    return paths

def export_roblox():
    """Merge into Body/Chamber meshes per bone, keep one UV layer each, and
    check them against Roblox mesh rules."""
    objs = [bpy.data.objects[n] for n in ATLAS_OBJECTS]
    groups = {}
    for o in objs:
        groups.setdefault(o.parent_bone or "Root", []).append(o)
    made, report = [], {}
    for bone, members in groups.items():
        for kind in ("Body", "Chamber"):
            bm = bmesh.new()
            for o in members:
                me = o.data
                want_violet = kind == "Chamber"
                faces = [p for p in me.polygons if (me.materials[p.material_index] is not None and
                         me.materials[p.material_index].name == VIOLET_NAME) == want_violet]
                if not faces: continue
                uvsrc = me.uv_layers["Chamber" if want_violet else "Atlas"]
                uvl = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
                vmap = {}
                for p in faces:
                    vs = []
                    for vi in p.vertices:
                        if vi not in vmap:
                            vmap[vi] = bm.verts.new(o.matrix_world @ me.vertices[vi].co)
                        vs.append(vmap[vi])
                    try:
                        f = bm.faces.new(vs)
                    except ValueError:
                        continue
                    for loop, li in zip(f.loops, p.loop_indices):
                        loop[uvl].uv = uvsrc.data[li].uv
            if not bm.faces:
                bm.free(); continue
            bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
            bmesh.ops.dissolve_degenerate(bm, edges=bm.edges[:], dist=1e-5)
            bmesh.ops.triangulate(bm, faces=bm.faces[:])
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_area() < 1e-9], context="FACES")
            name = f"MF_{bone}_{kind}"
            me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
            for p in me.polygons: p.use_smooth = False
            o = bpy.data.objects.new(name, me); sc.collection.objects.link(o)
            made.append(o)
            areas = [p.area for p in me.polygons]
            P = [v.co for v in me.vertices]
            size = [max(p[i] for p in P) - min(p[i] for p in P) for i in range(3)]
            uvs = [d.uv for d in me.uv_layers[0].data]
            report[name] = {
                "bone": bone, "triangles": len(me.polygons), "vertices": len(me.vertices),
                "size": [round(s, 4) for s in size],
                "degenerate_tris": sum(1 for a in areas if a < 1e-9),
                "uv_out_of_range": sum(1 for u in uvs if not (-1e-4 <= u.x <= 1.0001 and -1e-4 <= u.y <= 1.0001)),
                "center": [round((max(p[i] for p in P) + min(p[i] for p in P)) / 2, 4) for i in range(3)],
            }
    bpy.ops.object.select_all(action="DESELECT")
    for o in made: o.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    fbx = os.path.join(OUT, f"{ITEM}_{globals().get('LINE', 'Moltframe')}_Roblox.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"},
                             apply_scale_options="FBX_SCALE_UNITS", use_triangles=True, bake_anim=False,
                             add_leaf_bones=False, mesh_smooth_type="FACE")
    for o in made:
        me = o.data; bpy.data.objects.remove(o); bpy.data.meshes.remove(me)
    return fbx, report
