"""Style test: the same rifle (Bitrate) modeled in three art styles and rendered.

Run with Blender's Python module (pip install bpy) or inside Blender:
    python tools/blender/style_test.py <output_dir>

Gun faces +X (barrel), Z is up. 1 Blender unit = 1 Roblox stud.
"""

import math
import sys
from pathlib import Path

import bpy

OUT = Path(sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "vault/02 Art/References/style-test")
OUT.mkdir(parents=True, exist_ok=True)


def hex_rgba(h, a=1.0):
    h = h.lstrip("#")
    srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, a)


_mats = {}


def mat(name, color, metallic=0.0, rough=0.5, emit=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = hex_rgba(color)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = hex_rgba(color)
        p.inputs["Emission Strength"].default_value = emit
    _mats[name] = m
    return m


def _finish(o, coll, material, bevel, segments, smooth):
    for c in o.users_collection:
        c.objects.unlink(o)
    coll.objects.link(o)
    o.data.materials.append(material)
    if bevel:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = segments
        b.limit_method = "ANGLE"
    if smooth:
        for poly in o.data.polygons:
            poly.use_smooth = True
        try:
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
        except Exception:
            pass
    return o


def box(coll, size, loc, material, bevel=0.0, segments=2, rot=(0, 0, 0), smooth=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, coll, material, bevel, segments, smooth)


def cyl(coll, r, depth, loc, material, axis="X", verts=24, bevel=0.0, segments=2, smooth=True):
    rot = {"X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0), "Z": (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    return _finish(o, coll, material, bevel, segments, smooth)


def new_coll(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


# ---------------------------------------------------------------- A: blocky
def build_blocky():
    c = new_coll("A_Blocky")
    grey = mat("A_grey", "#63666B", rough=0.65)
    black = mat("A_black", "#1B1B1D", rough=0.6)
    red = mat("A_red", "#C4281C", rough=0.6)
    box(c, (1.7, 0.46, 0.55), (0, 0, 0), grey)
    box(c, (1.05, 0.42, 0.42), (1.3, 0, 0.02), black)
    box(c, (0.75, 0.16, 0.16), (2.15, 0, 0.05), black)
    box(c, (0.3, 0.24, 0.24), (2.6, 0, 0.05), grey)
    box(c, (1.0, 0.38, 0.5), (-1.3, 0, -0.02), black)
    box(c, (0.12, 0.42, 0.62), (-1.83, 0, -0.05), grey)
    box(c, (0.24, 0.3, 0.62), (-0.45, 0, -0.5), black, rot=(0, 0.3, 0))
    box(c, (0.32, 0.28, 0.72), (0.35, 0, -0.6), grey, rot=(0, -0.2, 0))
    box(c, (0.36, 0.24, 0.22), (0.4, 0, 0.385), black)
    box(c, (1.2, 0.47, 0.08), (0.05, 0, 0.12), red)
    # classic studs on top of receiver and stock
    for x in [i * 0.2 - 0.7 for i in range(4)] + [i * 0.2 + 0.7 for i in range(2)]:
        for y in (-0.11, 0.11):
            cyl(c, 0.065, 0.04, (x, y, 0.295), grey, axis="Z", verts=16)
    for x in [-1.7 + i * 0.2 for i in range(5)]:
        for y in (-0.09, 0.09):
            cyl(c, 0.065, 0.04, (x, y, 0.25), black, axis="Z", verts=16)
    return c


# ---------------------------------------------------------- B: stylized neon
def build_stylized():
    c = new_coll("B_Stylized")
    body = mat("B_body", "#262B3A", rough=0.45)
    trim = mat("B_trim", "#56607C", rough=0.4)
    metal = mat("B_metal", "#14161D", metallic=0.6, rough=0.35)
    neon = mat("B_neon", "#00E5FF", emit=7.0)
    lens = mat("B_lens", "#FF3DCB", emit=4.0)
    s = dict(smooth=True, segments=3)
    box(c, (1.7, 0.46, 0.55), (0, 0, 0), body, bevel=0.08, **s)
    box(c, (1.3, 0.34, 0.14), (0.15, 0, 0.32), trim, bevel=0.04, **s)
    box(c, (1.2, 0.48, 0.06), (0.05, 0, 0.08), neon)
    box(c, (1.05, 0.42, 0.42), (1.3, 0, 0.02), trim, bevel=0.1, **s)
    for x in (1.0, 1.25, 1.5):
        box(c, (0.12, 0.44, 0.1), (x, 0, 0.02), neon)
    cyl(c, 0.075, 0.75, (2.15, 0, 0.05), metal)
    cyl(c, 0.14, 0.32, (2.62, 0, 0.05), body, bevel=0.035, segments=3)
    cyl(c, 0.145, 0.05, (2.5, 0, 0.05), neon)
    box(c, (1.0, 0.38, 0.5), (-1.3, 0, -0.02), trim, bevel=0.1, **s)
    box(c, (0.14, 0.42, 0.62), (-1.83, 0, -0.05), body, bevel=0.05, **s)
    box(c, (0.6, 0.4, 0.05), (-1.3, 0, 0.1), neon)
    box(c, (0.24, 0.3, 0.62), (-0.45, 0, -0.5), body, bevel=0.07, rot=(0, 0.3, 0), **s)
    box(c, (0.42, 0.08, 0.06), (-0.2, 0, -0.33), body, bevel=0.02)
    box(c, (0.32, 0.28, 0.72), (0.35, 0, -0.6), trim, bevel=0.07, rot=(0, -0.2, 0), **s)
    box(c, (0.06, 0.29, 0.45), (0.37, 0, -0.58), neon, rot=(0, -0.2, 0))
    box(c, (0.36, 0.24, 0.22), (0.4, 0, 0.5), body, bevel=0.05, **s)
    box(c, (0.02, 0.18, 0.14), (0.585, 0, 0.51), lens)
    return c


# --------------------------------------------------------- C: semi-realistic
def build_semireal():
    c = new_coll("C_SemiReal")
    gun = mat("C_gunmetal", "#3B3F45", metallic=0.85, rough=0.38)
    steel = mat("C_steel", "#1E2024", metallic=0.9, rough=0.3)
    poly = mat("C_polymer", "#7D6B52", rough=0.75)
    blk = mat("C_black", "#151618", rough=0.7)
    glass = mat("C_glass", "#2FA8C9", rough=0.05, emit=0.6)
    box(c, (1.5, 0.32, 0.42), (0, 0, 0), gun, bevel=0.02)
    box(c, (0.3, 0.33, 0.1), (0.1, 0, 0.08), blk)  # ejection port
    box(c, (1.9, 0.2, 0.05), (0.45, 0, 0.235), steel)
    for i in range(18):
        box(c, (0.05, 0.22, 0.04), (-0.45 + i * 0.1, 0, 0.275), steel)
    box(c, (1.1, 0.3, 0.3), (1.25, 0, 0.03), gun, bevel=0.015)
    for i in range(4):
        box(c, (0.14, 0.31, 0.06), (0.9 + i * 0.23, 0, 0.03), blk)
    box(c, (0.1, 0.12, 0.12), (1.9, 0, 0.12), steel)
    cyl(c, 0.045, 0.9, (2.2, 0, 0.05), steel)
    cyl(c, 0.065, 0.22, (2.72, 0, 0.05), steel)
    for z in (0.09, 0.01):
        box(c, (0.12, 0.14, 0.015), (2.74, 0, z), blk)
    cyl(c, 0.07, 0.5, (-0.9, 0, 0.05), steel)
    box(c, (0.8, 0.22, 0.36), (-1.15, 0, -0.02), poly, bevel=0.03)
    box(c, (0.08, 0.26, 0.5), (-1.58, 0, -0.06), blk, bevel=0.02)
    box(c, (0.2, 0.24, 0.55), (-0.4, 0, -0.42), poly, bevel=0.03, rot=(0, 0.32, 0))
    box(c, (0.38, 0.04, 0.03), (-0.17, 0, -0.25), steel)
    box(c, (0.26, 0.2, 0.66), (0.3, 0, -0.52), blk, bevel=0.015, rot=(0, -0.22, 0))
    # scope
    cyl(c, 0.1, 0.9, (0.35, 0, 0.5), blk)
    cyl(c, 0.14, 0.22, (0.88, 0, 0.5), blk)
    cyl(c, 0.13, 0.16, (-0.18, 0, 0.5), blk)
    cyl(c, 0.05, 0.14, (0.35, 0, 0.63), blk, axis="Z")
    cyl(c, 0.05, 0.14, (0.35, -0.13, 0.5), blk, axis="Y")
    for x in (0.12, 0.6):
        box(c, (0.08, 0.14, 0.16), (x, 0, 0.36), steel)
    cyl(c, 0.125, 0.01, (0.995, 0, 0.5), glass)
    box(c, (0.12, 0.06, 0.06), (-0.55, -0.17, 0.12), steel)  # charging handle
    return c


# ------------------------------------------------------------------- scene
def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1400, 760
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = hex_rgba("#1A1E29")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6

    def light(name, loc, energy, size, color="#FFFFFF"):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy, ld.size, ld.color = energy, size, hex_rgba(color)[:3]
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        sc.collection.objects.link(lo)
        tr = lo.constraints.new("TRACK_TO")
        tr.target = target
        return lo

    target = bpy.data.objects.new("Target", None)
    target.location = (0.45, 0, -0.05)
    sc.collection.objects.link(target)
    light("Key", (2.5, -4.5, 4.0), 700, 4)
    light("Fill", (-4.0, -3.5, 0.5), 250, 5, "#BFD4FF")
    light("Rim", (0.0, 4.5, 3.0), 700, 3, "#9FE8FF")

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (1.6, -7.2, 1.7)
    sc.collection.objects.link(cam)
    cam.constraints.new("TRACK_TO").target = target
    sc.camera = cam


def tri_count(coll):
    dg = bpy.context.evaluated_depsgraph_get()
    n = 0
    for o in coll.objects:
        if o.type == "MESH":
            m = o.evaluated_get(dg).to_mesh()
            m.calc_loop_triangles()
            n += len(m.loop_triangles)
            o.evaluated_get(dg).to_mesh_clear()
    return n


def main():
    setup_scene()
    styles = [("a_blocky", build_blocky()), ("b_stylized", build_stylized()), ("c_semireal", build_semireal())]
    for _, coll in styles:
        coll.hide_render = True
    for name, coll in styles:
        coll.hide_render = False
        print(f"{name}: {tri_count(coll)} triangles, {len(coll.objects)} parts")
        bpy.context.scene.render.filepath = str(OUT / f"{name}.png")
        bpy.ops.render.render(write_still=True)
        coll.hide_render = True


main()
