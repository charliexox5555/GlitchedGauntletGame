# Tempest-Strike Vandal s05, stage F: sleek metal finish, new trigger guard + blade trigger, and a
# tsuka-maki handle (crossing leather straps over a pale ray-skin core). Run after stages A-E.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_vandal/tv_s_lib.py").read())
purge(("TSF_",))

def hide(names):
	for n in names:
		o = bpy.data.objects.get(n)
		if o:
			o.hide_render = True; o.hide_set(True); o["ts_replaced"] = True

# ---------- sleek metal: brushed silver with real sheen, deep enamel body ----------
def lin(h):
	h = h.lstrip("#"); f = lambda v: (v / 255) / 12.92 if v / 255 <= 0.04045 else (((v / 255) + 0.055) / 1.055) ** 2.4
	return (f(int(h[0:2], 16)), f(int(h[2:4], 16)), f(int(h[4:6], 16)), 1.0)
FIN = {"Panel": ("#DCE1E6", 0.26, 0.72), "Body": ("#1D2433", 0.30, 0.45), "Metal": ("#7A8491", 0.26, 0.95),
	"Accent": ("#3E6580", 0.32, 0.5)}
for n, (hx, r, mt) in FIN.items():
	m = M(n)
	b = next(x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED")
	cr = next((x for x in m.node_tree.nodes if x.type == "VALTORGB"), None)
	base = lin(hx)
	if cr:
		for e, k in zip(cr.color_ramp.elements, (0.97, 1.03)):
			e.color = (base[0] * k, base[1] * k, base[2] * k, 1.0)
	else:
		b.inputs["Base Color"].default_value = base
	if not b.inputs["Roughness"].is_linked:
		b.inputs["Roughness"].default_value = r
	else:
		mr = next((x for x in m.node_tree.nodes if x.type == "MAP_RANGE"), None)
		if mr:
			mr.inputs["To Min"].default_value = r - 0.04; mr.inputs["To Max"].default_value = r + 0.04
	b.inputs["Metallic"].default_value = mt
	m.diffuse_color = base

# ---------- handle: clean faceted shell in the stock hand envelope, leather bands + cyan conduits ----------
hide(["Vandal_Grip", "TS_WrapGrip0", "TS_WrapGrip1", "TS_WrapGrip2", "TS_WrapGrip3"])
# horizontal sections down the raked grip: (z, front x, back x, half width)
GS = [(0.150, 0.128, -0.082, 0.052), (0.060, 0.112, -0.090, 0.054), (-0.060, 0.072, -0.122, 0.055),
	(-0.200, 0.028, -0.150, 0.054), (-0.290, -0.006, -0.156, 0.050), (-0.302, -0.010, -0.150, 0.046)]
def gsec(z, xf, xb, hw):
	cx, hd = (xf + xb) / 2, (xf - xb) / 2
	kf, kb = 0.40 * hw, 0.55 * hw          # sharper front edge, fuller back
	return [(xf, hw - kf, z), (xf - kf, hw, z), (xb + kb, hw, z), (xb, hw - kb, z), (xb, -hw + kb, z),
		(xb + kb, -hw, z), (xf - kf, -hw, z), (xf, -hw + kf, z)]
rings = [[(x, y, z) for x, y, z in gsec(*g)] for g in GS]
core = new_obj("TSF_GripCore", loft(rings), "Body", like="Vandal_Grip", bevel=0.0012)
def band(name, lo, hi, tilt, mat, lift, thick):
	"""Sleeve of the shell between two tilted planes along the grip rake."""
	o = core; mw = o.matrix_world
	ax = Vector((math.sin(math.radians(17 + tilt)), 0, -math.cos(math.radians(17 + tilt))))
	bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(mw)
	for d in (lo, hi):
		bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=ax * d, plane_no=ax)
	keep = {f for f in bm.faces if lo < f.calc_center_median().dot(ax) < hi and abs(f.normal.dot(ax)) < 0.6}
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context="FACES")
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), verts=bm.verts[:], edges=bm.edges[:])
	bm.normal_update()
	for v in bm.verts:
		v.co += v.normal * lift
	p = new_obj(name, bm, mat, like="Vandal_Grip", bevel=0)
	so = p.modifiers.new("Thick", "SOLIDIFY"); so.thickness = thick; so.offset = 1.0; so.use_quality_normals = True
	p.modifiers.move(p.modifiers.find("Thick"), 0)
	return p
# grip-axis offsets (17 deg rake): bands from just under the receiver to the cap, alternating tilt
B = [(-0.040, 0.010, 8), (0.022, 0.072, -8), (0.084, 0.134, 8), (0.146, 0.196, -8), (0.208, 0.258, 8)]
for i, (lo, hi, t) in enumerate(B):
	band("TSF_GripWrap%d" % i, lo, hi, t, "Grip", 0.0010, 0.0055)
	if i < len(B) - 1:
		nlo, nhi, nt = B[i + 1]
		mid = (hi + nlo) / 2
		band("TSF_GripConduit%d" % i, mid - 0.003, mid + 0.003, (t + nt) / 2, "Neon", 0.0005, 0.0022)

# ---------- trigger guard: thin angular blade loop with a forward spur, silver underside ----------
def gband(path, th):
	left, right = [], []
	for i, p in enumerate(path):
		p = Vector(p)
		if i == 0:
			t = (Vector(path[1]) - p).normalized()
		elif i == len(path) - 1:
			t = (p - Vector(path[i - 1])).normalized()
		else:
			t0 = (p - Vector(path[i - 1])).normalized(); t1 = (Vector(path[i + 1]) - p).normalized(); t = (t0 + t1).normalized()
		n = Vector((-t.y, t.x)); k = 1.0
		if 0 < i < len(path) - 1:
			k = 1.0 / max(0.45, Vector((-t0.y, t0.x)).dot(n))
		left.append(tuple(p + n * th * 0.5 * k)); right.append(tuple(p - n * th * 0.5 * k))
	return left + right[::-1]
path = [(0.105, 0.040), (0.150, 0.004), (0.360, 0.004), (0.405, 0.036), (0.424, 0.094)]
new_obj("TSF_TriggerGuard", prism_xz(gband(path, 0.015), -0.013, 0.013), "Body", like="Vandal_Grip", bevel=0.0012)
spur = [(0.360, -0.004), (0.430, 0.010), (0.442, 0.020), (0.404, 0.030), (0.372, 0.008)]
new_obj("TSF_GuardSpur", prism_xz(spur, -0.009, 0.009), "Panel", like="Vandal_Grip", bevel=0.0008)
under = [(0.165, -0.0045), (0.355, -0.0045), (0.348, 0.0005), (0.172, 0.0005)]
new_obj("TSF_GuardPlate", prism_xz(under, -0.010, 0.010), "Panel", like="Vandal_Grip", bevel=0)

# ---------- blade trigger (rides the Trigger bone) ----------
trig = [(0.198, 0.150), (0.226, 0.150), (0.224, 0.120), (0.231, 0.096), (0.247, 0.066), (0.238, 0.060), (0.216, 0.086), (0.205, 0.116)]
new_obj("TSF_Trigger", prism_xz(trig, -0.0075, 0.0075), "Panel", like="Vandal_Trigger", bevel=0.0008)
hide(["Vandal_Trigger"])
bpy.ops.wm.save_mainfile()
result = {"made": sorted(o.name for o in TS.objects if o.name.startswith("TSF_"))}
