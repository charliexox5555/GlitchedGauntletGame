# Review renders for the Tempest-Strike Vandal (neutral light, no effects). Writes PNGs to the scratchpad.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_vandal/tv_lib.py").read())
import os
VIEWS = globals().get("VIEWS", ["left", "right", "hero", "top", "under", "stockcmp"])
TAG = globals().get("TAG", "r01")
sc = bpy.context.scene
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
	try:
		sc.render.engine = eng
		break
	except TypeError:
		pass
sc.render.resolution_x, sc.render.resolution_y = 1600, 800
sc.render.film_transparent = False
sc.view_settings.view_transform = "AgX"
try:
	sc.view_settings.look = "AgX - Medium High Contrast"
except TypeError:
	pass
w = sc.world or bpy.data.worlds.new("World")
sc.world = w
w.use_nodes = True
bg = w.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0.36, 0.37, 0.40, 1)
bg.inputs[1].default_value = 0.9

L = coll("COL_ReviewRig")
def light(name, kind, loc, rot, energy, size=1.0, color=(1, 1, 1)):
	kill(name)
	ld = bpy.data.lights.get(name) or bpy.data.lights.new(name, kind)
	ld.energy = energy; ld.color = color
	if kind == "AREA":
		ld.size = size
	o = bpy.data.objects.new(name, ld); L.objects.link(o)
	o.location = loc; o.rotation_euler = [math.radians(a) for a in rot]
	return o
light("LGT_Key", "AREA", (0.6, 3.0, 2.6), (-48, 0, 180), 260, 3.0)
light("LGT_Fill", "AREA", (0.6, -3.0, 1.2), (70, 0, 0), 90, 3.0, (0.85, 0.9, 1.0))
light("LGT_Rim", "AREA", (-2.5, 0.5, 2.5), (0, -45, 0), 160, 2.0)
light("LGT_Top", "AREA", (0.7, 0, 3.5), (0, 0, 0), 120, 3.0)
for o in bpy.data.objects:
	if o.name in ("Light",):
		o.hide_render = True

cam_d = bpy.data.cameras.get("CAM_Review") or bpy.data.cameras.new("CAM_Review")
cam = bpy.data.objects.get("CAM_Review") or bpy.data.objects.new("CAM_Review", cam_d)
if cam.name not in L.objects:
	L.objects.link(cam)
sc.camera = cam
CEN = Vector((0.70, 0, 0.12))
def aim(loc, tgt):
	cam.location = loc
	d = (Vector(tgt) - Vector(loc))
	cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

ref = bpy.data.collections.get("REF_Stock")
model = bpy.data.collections.get("COL_Model")
def show(c, on):
	if c:
		c.hide_render = not on
		for o in c.all_objects:
			if o is not None and o.type == "MESH" and not o.name.startswith("CUT_"):
				o.hide_render = not on
out = []
def shoot(name, ortho=None, lens=50, res=(1600, 800)):
	sc.render.resolution_x, sc.render.resolution_y = res
	if ortho:
		cam_d.type = "ORTHO"; cam_d.ortho_scale = ortho
	else:
		cam_d.type = "PERSP"; cam_d.lens = lens
	cam_d.clip_start = 0.01
	p = SCRATCH + "tv_%s_%s.png" % (TAG, name)
	sc.render.filepath = p
	bpy.ops.render.render(write_still=True)
	out.append(p)

show(ref, False); show(model, True)
for c in bpy.data.collections:
	if c.name.startswith("COL_Cutters"):
		c.hide_render = True
for v in VIEWS:
	if v == "left":
		aim((0.70, 6, 0.12), CEN); shoot(v, ortho=4.1)
	elif v == "right":
		aim((0.70, -6, 0.12), CEN); shoot(v, ortho=4.1)
	elif v == "top":
		aim((0.70, 0, 6), CEN); cam.rotation_euler = (0, 0, 0); shoot(v, ortho=4.1, res=(1600, 500))
	elif v == "under":
		aim((0.70, 0, -6), CEN); cam.rotation_euler = (math.pi, 0, 0); shoot(v, ortho=4.1, res=(1600, 500))
	elif v == "hero":
		aim((3.6, 3.4, 1.5), (0.75, 0, 0.12)); shoot(v, lens=55)
	elif v == "rear34":
		aim((-2.6, -2.8, 1.4), (0.6, 0, 0.12)); shoot(v, lens=55)
	elif v == "stockcmp":
		show(model, False); show(ref, True)
		aim((0.70, 6, 0.12), CEN); shoot("stock_left", ortho=4.1)
		show(ref, False); show(model, True)
	elif v.startswith("close_"):
		# close_<x>_<z>_<side>
		_, x, z, sd = v.split("_")
		x, z = float(x), float(z); s = 1 if sd == "L" else -1
		aim((x + 0.35, s * 0.75, z + 0.25), (x, 0, z)); shoot(v, lens=50, res=(1200, 800))
	elif v == "fp":
		# rough first-person hip framing: eye behind/above the grip, looking down the barrel
		aim((-0.55, -0.42, 0.62), (1.6, 0.25, 0.25)); shoot(v, lens=24, res=(1600, 900))
	elif v == "ads":
		aim((AXZ := (0.078 - 0.36, 0, 0.56))[0:3], (3.0, 0, 0.56)); shoot(v, lens=18 / math.tan(math.radians(34)) * 1.0, res=(1600, 900))
result = {"renders": out}
