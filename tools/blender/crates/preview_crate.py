"""Preview renders of the crate (run after build_crate.py in the same live Blender).
Set VIEWS / OUT / OPEN before sending, or use the defaults. OPEN (0..1) poses the lid, latches and
handle so the animation pivots can be checked."""
import math
import os

import bpy
from mathutils import Vector

OUT = globals().get("OUT", r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame\art-source\lobby\crates\preview")
VIEWS = globals().get("VIEWS", ["three_quarter"])
OPEN = globals().get("OPEN", 0.0)

CAMS = {
	"three_quarter": ((-3.2, -4.6, 2.9), (0, 0, 0.5), 32),
	"front": ((0, -9, 0.55), (0, 0, 0.55), 50),
	"top": ((0, 0, 9), (0, 0, 0.5), 50),
	"side": ((9, 0, 0.55), (0, 0, 0.55), 50),
	"back": ((3.2, 4.6, 2.6), (0, 0, 0.5), 32),
}

sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 1400, 800
sc.render.film_transparent = False
w = bpy.data.worlds.get("CrateWorld") or bpy.data.worlds.new("CrateWorld")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.045, 0.045, 0.05, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sc.world = w
sc.view_settings.view_transform = "Standard"

for name, loc, energy, size in (("Key", (-4, -5, 6), 420, 4), ("Fill", (5, -3, 3), 120, 5), ("Rim", (2, 6, 5), 300, 3)):
	lt = bpy.data.objects.get("Crate" + name)
	if not lt:
		lt = bpy.data.objects.new("Crate" + name, bpy.data.lights.new("Crate" + name, "AREA"))
		sc.collection.objects.link(lt)
	lt.location = loc
	lt.data.energy, lt.data.size = energy, size
	lt.rotation_euler = (Vector((0, 0, 0.5)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()

cam = bpy.data.objects.get("CrateCam")
if not cam:
	cam = bpy.data.objects.new("CrateCam", bpy.data.cameras.new("CrateCam"))
	sc.collection.objects.link(cam)
sc.camera = cam

# pose the moving parts
pose = {"Lid": (-100 * OPEN, "X"), "LatchL": (-120 * OPEN, "X"), "LatchR": (-120 * OPEN, "X"), "Handle": (-60 * OPEN, "X")}
for ob in bpy.data.collections["CRATE"].objects:
	g = ob.get("group")
	ang, ax = pose.get(g, (0, "X"))
	ob.rotation_euler = (math.radians(ang), 0, 0)
	if g == "Gem":
		lid = next(o for o in bpy.data.collections["CRATE"].objects if o.get("group") == "Lid")
		ob.parent = None
		# the gem rides the lid: rotate its position about the lid hinge
		from mathutils import Matrix
		h = lid.location
		rot = Matrix.Rotation(math.radians(pose["Lid"][0]), 4, "X")
		base = Vector((0, 0, 1.02))
		ob.location = h + (rot @ (base - h).to_4d()).to_3d()
		ob.rotation_euler = (math.radians(pose["Lid"][0]), 0, 0)

os.makedirs(OUT, exist_ok=True)
paths = []
for v in VIEWS:
	loc, tgt, lens = CAMS[v]
	cam.location = loc
	cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
	if v in ("front", "top", "side"):
		cam.data.type = "ORTHO"
		cam.data.ortho_scale = 4.9
	else:
		cam.data.type = "PERSP"
		cam.data.lens = lens
	sc.render.filepath = os.path.join(OUT, f"{v}_{int(OPEN * 100)}.png")
	bpy.ops.render.render(write_still=True)
	paths.append(sc.render.filepath)
result = {"renders": paths}
