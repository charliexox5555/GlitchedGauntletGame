"""Skin casing meshes for ejected shells (round two, 2026-11-14).

The owner: the shell thrown from a skin should look like that skin's round
(colour, plus a touch of the line's design). Util/ShellFx flies these with a
SpecialMesh per part and colours them per line (Config/SkinCasings):

  CasingBody  8-sided case: chamfered rim, extractor groove, straight case,
              faceted shoulder, neck, chamfered mouth (no round parts:
              Style Bible, gauntlet-build-style section 0)
  CasingBand  8-sided ring proud of the case just behind the shoulder
              (the line's accent colour)

Design units: length 1 along +X (base at -0.5), case apothem 0.47; ShellFx
scales non-uniformly to each class's shell size. Exec in a Blender MCP
session; writes art-source/weapons/Skins/_casing/{SkinCasing.blend, SkinCasing.fbx}.
"""
import math, os, bmesh, bpy

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
OUT = os.path.join(ROOT, "art-source", "weapons", "Skins", "_casing")
SIDES = 8
K = 1 / math.cos(math.pi / SIDES)            # apothem -> circumradius

BODY = [(-.50, .43), (-.47, .50), (-.39, .50), (-.37, .42), (-.37, .40), (-.32, .40), (-.30, .47),
        (.26, .47), (.36, .40), (.47, .40), (.50, .36)]
BAND_OUT = [(.02, .468), (.035, .497), (.165, .497), (.18, .468)]
BAND_IN = .455


def ring(bm, x, a):
    r = a * K
    return [bm.verts.new((x, r * math.cos(math.pi / SIDES + i * 2 * math.pi / SIDES),
                          r * math.sin(math.pi / SIDES + i * 2 * math.pi / SIDES))) for i in range(SIDES)]


def loft(bm, rings, closed=False):
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for a, b in pairs:
        for i in range(SIDES):
            j = (i + 1) % SIDES
            bm.faces.new((a[i], a[j], b[j], b[i]))


def solid(name, profile, inner=None):
    bm = bmesh.new()
    rings = [ring(bm, x, a) for x, a in profile]
    if inner is None:
        loft(bm, rings)
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    else:
        back = [ring(bm, x, inner) for x, _ in (profile[-1], profile[0])]
        loft(bm, rings + back, closed=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def build():
    bpy.ops.wm.read_homefile(use_empty=True)
    os.makedirs(OUT, exist_ok=True)
    body = solid("CasingBody", BODY)
    band = solid("CasingBand", BAND_OUT, inner=BAND_IN)
    info = {}
    for o in (body, band):
        P = [v.co for v in o.data.vertices]
        lo = [min(p[i] for p in P) for i in range(3)]; hi = [max(p[i] for p in P) for i in range(3)]
        info[o.name] = {"center": [round((lo[i] + hi[i]) / 2, 5) for i in range(3)],
                        "size": [round(hi[i] - lo[i], 5) for i in range(3)], "faces": len(o.data.polygons)}
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "SkinCasing.blend"))
    win = bpy.context.window_manager.windows[0] if bpy.context.window_manager.windows else None
    with bpy.context.temp_override(window=win, selected_objects=[body, band], active_object=body):
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "SkinCasing.fbx"), use_selection=True, apply_unit_scale=True,
                                 global_scale=1.0, axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                                 object_types={"MESH"}, bake_space_transform=False)
    return info


result = build()
