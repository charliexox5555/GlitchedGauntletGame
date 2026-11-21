# Review renders for a Tempest-Strike line item (neutral light, mid-grey floor, no effects). PNGs -> scratchpad.
# Set GUN, TAG, VIEWS. Adapted from tools/blender/tempest_vandal/20_render.py (frames from the gun's own bounds).
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
VIEWS = globals().get("VIEWS", ["hero", "rear34", "left", "right", "top", "under", "fp", "stockcmp"])
TAG = globals().get("TAG", "s01")
sc = bpy.context.scene
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
	try:
		sc.render.engine = eng
		break
	except TypeError:
		pass
sc.render.film_transparent = False
sc.view_settings.view_transform = "AgX"
try:
	sc.view_settings.look = "AgX - High Contrast"
except TypeError:
	pass
w = bpy.data.worlds.get("TS_ReviewWorld") or bpy.data.worlds.new("TS_ReviewWorld")
sc.world = w
w.use_nodes = True
nt = w.node_tree
for n in list(nt.nodes):
	nt.nodes.remove(n)
out_n = nt.nodes.new("ShaderNodeOutputWorld")
bg = nt.nodes.new("ShaderNodeBackground")
tc = nt.nodes.new("ShaderNodeTexCoord"); sx = nt.nodes.new("ShaderNodeSeparateXYZ"); cr = nt.nodes.new("ShaderNodeValToRGB")
nt.links.new(tc.outputs["Generated"], sx.inputs[0]); nt.links.new(sx.outputs["Z"], cr.inputs["Fac"])
e = cr.color_ramp.elements
e[0].position = 0.40; e[0].color = (0.30, 0.31, 0.34, 1)
e[1].position = 0.56; e[1].color = (0.95, 0.96, 1.0, 1)
x_ = e.new(0.75); x_.color = (0.42, 0.44, 0.48, 1)
nt.links.new(cr.outputs["Color"], bg.inputs[0]); bg.inputs[1].default_value = 0.8
lp = nt.nodes.new("ShaderNodeLightPath"); mx = nt.nodes.new("ShaderNodeMixShader"); bg2 = nt.nodes.new("ShaderNodeBackground")
bg2.inputs[0].default_value = (0.42, 0.43, 0.46, 1); bg2.inputs[1].default_value = 1.0
nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0]); nt.links.new(bg.outputs[0], mx.inputs[1]); nt.links.new(bg2.outputs[0], mx.inputs[2])
nt.links.new(mx.outputs[0], out_n.inputs["Surface"])

L = coll("COL_ReviewRig")
for o in bpy.data.objects:
	if o.type in ("LIGHT", "CAMERA") and not o.name.startswith(("LGT_", "CAM_")):
		o.hide_render = True
for c in bpy.data.collections:
	if "ADSRange" in c.name or c.name.endswith("_Lights"):
		c.hide_render = True
def light(name, kind, loc, rot, energy, size=1.0, color=(1, 1, 1)):
	kill(name)
	ld = bpy.data.lights.get(name) or bpy.data.lights.new(name, kind)
	ld.energy = energy; ld.color = color
	if kind == "AREA":
		ld.size = size
	o = bpy.data.objects.new(name, ld); L.objects.link(o)
	o.location = loc; o.rotation_euler = [math.radians(a) for a in rot]
	return o

objs = visible_model()
ws = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
lo = Vector([min(p[i] for p in ws) for i in range(3)]); hi = Vector([max(p[i] for p in ws) for i in range(3)])
CEN = (lo + hi) / 2; LEN = hi.x - lo.x; S = max(1.0, LEN / 3.9)
light("LGT_Key", "AREA", (CEN.x - 0.1, 3.0 * S, 2.6 * S), (-48, 0, 180), 230 * S * S, 0.9 * S)
light("LGT_Fill", "AREA", (CEN.x - 0.1, -3.0 * S, 1.2 * S), (70, 0, 0), 70 * S * S, 1.5 * S, (0.85, 0.9, 1.0))
light("LGT_Rim", "AREA", (CEN.x - 3.2 * S, 0.5, 2.5 * S), (0, -45, 0), 160 * S * S, 2.0 * S)
light("LGT_Top", "AREA", (CEN.x, 0, 3.5 * S), (0, 0, 0), 120 * S * S, 3.0 * S)

cam_d = bpy.data.cameras.get("CAM_Review") or bpy.data.cameras.new("CAM_Review")
cam = bpy.data.objects.get("CAM_Review") or bpy.data.objects.new("CAM_Review", cam_d)
if cam.name not in L.objects:
	L.objects.link(cam)
sc.camera = cam
def aim(loc, tgt):
	cam.location = loc
	d = (Vector(tgt) - Vector(loc))
	cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
out = []
def shoot(name, ortho=None, lens=50, res=(1600, 800)):
	sc.render.resolution_x, sc.render.resolution_y = res
	if ortho:
		cam_d.type = "ORTHO"; cam_d.ortho_scale = ortho
	else:
		cam_d.type = "PERSP"; cam_d.lens = lens
	cam_d.clip_start = 0.01
	p = SCRATCH + "%s_%s_%s.png" % (GUN, TAG, name)
	sc.render.filepath = p
	bpy.ops.render.render(write_still=True)
	out.append(p)

stock_hidden = [o for o in bpy.data.collections[GUN].all_objects if o.type == "MESH" and o.get("ts_replaced")]
ts_vis = [o for o in TS.all_objects if o.type == "MESH" and not o.hide_render]
OS = LEN * 1.06
for v in VIEWS:
	if v == "left":
		aim((CEN.x, 6 * S, CEN.z), CEN); shoot(v, ortho=OS)
	elif v == "right":
		aim((CEN.x, -6 * S, CEN.z), CEN); shoot(v, ortho=OS)
	elif v == "top":
		aim((CEN.x, 0, 6 * S), CEN); cam.rotation_euler = (0, 0, 0); shoot(v, ortho=OS, res=(1600, 500))
	elif v == "under":
		aim((CEN.x, 0, -6 * S), CEN); cam.rotation_euler = (math.pi, 0, 0); shoot(v, ortho=OS, res=(1600, 500))
	elif v == "hero":
		aim((CEN.x + 0.95 * LEN, 1.10 * LEN, CEN.z + 0.47 * LEN), CEN); shoot(v, lens=55)
	elif v == "rear34":
		aim((CEN.x - 1.06 * LEN, -0.93 * LEN, CEN.z + 0.44 * LEN), CEN); shoot(v, lens=55)
	elif v == "stockcmp":
		for o in stock_hidden:
			o.hide_render = False
		for o in ts_vis:
			o.hide_render = True
		aim((CEN.x, 6 * S, CEN.z), CEN); shoot("stock_left", ortho=OS)
		for o in stock_hidden:
			o.hide_render = True
		for o in ts_vis:
			o.hide_render = False
	elif v.startswith("close_"):
		# close_<x>_<z>_<L|R|T|B>[_<dist>]
		p_ = v.split("_"); x, z, sd = float(p_[1]), float(p_[2]), p_[3]; d = float(p_[4]) if len(p_) > 4 else 0.75
		if sd in ("L", "R"):
			s = 1 if sd == "L" else -1
			aim((x + 0.45 * d, s * d, z + 0.3 * d), (x, 0, z))
		elif sd == "T":
			aim((x + 0.3 * d, 0.35 * d, z + d), (x, 0, z))
		else:
			aim((x + 0.3 * d, 0.45 * d, z - d), (x, 0, z))
		shoot(v, lens=50, res=(1200, 800))
	elif v == "fp":
		# rough first-person hip framing: eye behind/above the grip, looking down the barrel
		aim((lo.x + 0.30 * LEN, -0.42, hi.z + 0.10), (hi.x + 0.3, 0.25, CEN.z + 0.05)); shoot(v, lens=24, res=(1600, 900))
result = {"renders": out, "bounds": [list(map(lambda q: round(q, 3), lo)), list(map(lambda q: round(q, 3), hi))]}
