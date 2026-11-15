"""What Studio gets: re-import exported flat-skin FBXs and render them the way
Roblox draws them (one-sided faces), 2026-11-14.

Exec in the Blender MCP session with
    FBXS = [(key, fbx_path, manifest_flat_path), ...]
    OUT = <folder for the PNGs>            (optional)
    VIEWS = ("Left", "Right", "Rear")      (optional)
Each FBX is imported into an empty scene, coloured from its manifest, and
rendered in Workbench with backface culling ON on a magenta background: any
magenta inside the silhouette is a hole Studio will show, black triangles are
flipped faces. Normal Blender renders draw back faces and hide both (this is
how the broken Odin / Bulldog / Ares grips were found). See
vault/02 Art/Skins/Skin Build Pitfalls.md.
"""
import bpy, json, os, glob
from mathutils import Vector, Matrix
OUT = globals().get("OUT", os.path.join(os.path.expanduser("~"), "flat_export_check"))
os.makedirs(OUT, exist_ok=True)
VIEWS = globals().get("VIEWS", ("Left", "Right", "Rear"))
def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (1.0,)
def look(cam, eye, target):
    f = (target - eye).normalized(); r = f.cross(Vector((0, 0, 1))).normalized(); u = r.cross(f)
    cam.location = eye; cam.rotation_euler = Matrix((r, u, -f)).transposed().to_euler()
rep = {}
for key, fbx, manp in FBXS:
    bpy.ops.wm.read_homefile(use_empty=True, use_factory_startup=True)
    win = bpy.context.window_manager.windows[0] if bpy.context.window_manager.windows else None
    with bpy.context.temp_override(window=win):
        bpy.ops.import_scene.fbx(filepath=fbx, axis_forward="-Z", axis_up="Y")
    man = json.load(open(manp))
    sc = bpy.context.scene
    objs = [o for o in sc.objects if o.type == "MESH"]
    inside = []
    for o in objs:
        spec = man["parts"].get(o.name.split(".")[0])
        m = bpy.data.materials.new(o.name)
        m.diffuse_color = hexc(spec["color"]) if spec else (1, 1, 0, 1)
        o.data.materials.clear(); o.data.materials.append(m)
        M = o.matrix_world; vol = 0.0
        for p in o.data.polygons:
            vs = [M @ o.data.vertices[i].co for i in p.vertices]
            for i in range(1, len(vs) - 1):
                vol += vs[0].dot(vs[i].cross(vs[i + 1]))
        if vol < -1e-7:
            inside.append(o.name)
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    ctr = (lo + hi) / 2; ext = hi - lo
    sc.render.engine = "BLENDER_WORKBENCH"; sc.render.resolution_x, sc.render.resolution_y = 1000, 560
    sh = sc.display.shading
    sh.light = "STUDIO"; sh.color_type = "MATERIAL"; sh.show_cavity = True; sh.show_backface_culling = True
    sh.background_type = "VIEWPORT"; sh.background_color = (1.0, 0.0, 0.8)
    sc.display.render_aa = "8"
    cd = bpy.data.cameras.new("_c"); cam = bpy.data.objects.new("_c", cd); sc.collection.objects.link(cam); sc.camera = cam
    # the gun's long axis: largest extent
    L = max(range(3), key=lambda i: ext[i])
    side_axis = [i for i in range(3) if i != L]
    thin = min(side_axis, key=lambda i: ext[i]); up = [i for i in side_axis if i != thin][0]
    for name in VIEWS:
        if name in ("Left", "Right"):
            cd.type = "ORTHO"; cd.ortho_scale = max(ext[L], ext[up] * 1000 / 560) * 1.08
            dv = Vector((0, 0, 0)); dv[thin] = 1 if name == "Left" else -1
            eye = ctr + dv * 5
            f = (ctr - eye).normalized(); upv = Vector((0, 0, 0)); upv[up] = 1
            r = f.cross(upv).normalized(); u = r.cross(f)
            cam.location = eye; cam.rotation_euler = Matrix((r, u, -f)).transposed().to_euler()
        else:
            cd.type = "PERSP"; cd.lens = 35
            off = Vector((0, 0, 0)); off[L] = -ext[L] * .9; off[thin] = ext[L] * .45; off[up] = ext[L] * .3
            eye = ctr + off
            f = (ctr - eye).normalized(); upv = Vector((0, 0, 0)); upv[up] = 1
            r = f.cross(upv).normalized(); u = r.cross(f)
            cam.location = eye; cam.rotation_euler = Matrix((r, u, -f)).transposed().to_euler()
        sc.render.filepath = os.path.join(OUT, f"{key.replace('/', '_')}_{name}.png")
        bpy.ops.render.render(write_still=True)
    rep[key] = {"parts": len(objs), "inside_out": inside, "axes": ["xyz"[L], "xyz"[up], "xyz"[thin]]}
result = rep
