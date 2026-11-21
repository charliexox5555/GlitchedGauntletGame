# Tempest-Strike Vandal s02, stage C: personality on the stock base. Run after stages A and B.
# Barrel (fluted shroud sleeves + ported shinobi brake), front blade post, true crescent rear sight,
# kunai charging handle + silver bolt, slimmer butt, hydro inlays, stock blade. Idempotent for its own parts.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_vandal/tv_s_lib.py").read())
purge(("TSC_",))
BORE = 0.285
AX, AZ = 0.078, 0.560

# ---------- barrel: stock barrel trimmed before the old compensator ----------
for n in ("TSC_Barrel",):
	if n in bpy.data.objects:
		bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)
bar = dup("Vandal_Barrel", "TSC_Barrel")
bm = bmesh.new(); bm.from_mesh(bar.data)
mw = bar.matrix_world; bm.transform(mw)
bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(2.300, 0, 0), plane_no=(1, 0, 0), clear_outer=True)
bnd = [e for e in bm.edges if e.is_boundary]
if bnd:
	bmesh.ops.holes_fill(bm, edges=bnd, sides=0)
bm.transform(mw.inverted()); bm.to_mesh(bar.data); bm.free()

# ---------- fluted shroud sleeves ----------
def sleeve(name, stations, flutes):
	rings = []
	for i, (x, hw, top, bot) in enumerate(stations):
		d = 0.0 if i in (0, len(stations) - 1) else 1.0
		spec = {k: [(t, w, dd * d) for t, w, dd in v] for k, v in flutes.items()}
		rings.append(ring_x(x, fluted(octo(hw, (top - bot) / 2, c=0.16, cz=(top + bot) / 2), spec)))
	return new_obj(name, loft(rings), "Body", bevel=0.001)
FL = {0: [(0.30, 0.008, 0.0045), (0.70, 0.008, 0.0045)], 2: [(0.30, 0.008, 0.004), (0.70, 0.008, 0.004)],
	4: [(0.30, 0.008, 0.0045), (0.70, 0.008, 0.0045)]}
sleeve("TSC_Shroud", [(1.680, 0.050, 0.392, 0.236), (1.700, 0.050, 0.392, 0.236), (1.930, 0.048, 0.388, 0.240),
	(1.948, 0.048, 0.388, 0.240)], FL)
FL2 = {0: [(0.5, 0.008, 0.004)], 4: [(0.5, 0.008, 0.004)], 2: [(0.5, 0.008, 0.0035)]}
sleeve("TSC_ShroudFwd", [(2.098, 0.048, 0.334, 0.236), (2.115, 0.048, 0.334, 0.236), (2.272, 0.046, 0.331, 0.239),
	(2.290, 0.046, 0.331, 0.239)], FL2)

# ---------- front sight: clamp collar + swept blade post + cyan dot ----------
replaced("Vandal_FrontSight")
new_obj("TSC_Sight_FrontCollar", loft([ring_x(1.946, octo(0.054, 0.084, c=0.22, cz=0.314)),
	ring_x(1.960, octo(0.058, 0.088, c=0.22, cz=0.314)), ring_x(2.086, octo(0.058, 0.088, c=0.22, cz=0.314)),
	ring_x(2.102, octo(0.052, 0.082, c=0.22, cz=0.314))]), "Panel")
post = [(1.962, 0.396), (2.094, 0.396), (2.064, 0.432), (2.036, 0.560), (2.028, 0.594), (2.018, 0.594),
	(2.008, 0.540), (1.990, 0.448)]
new_obj("TSC_Sight_FrontPost", prism_xz(post, -0.010, 0.010), "Body")
dot = [(2.0105, 0.5855), (2.0165, 0.5855), (2.0165, 0.5915), (2.0105, 0.5915)]
new_obj("TSC_Sight_FrontDot", prism_xz(dot, -0.0045, 0.0045), "Neon", bevel=0)

# ---------- rear sight: stock base kept, ring replaced by a true crescent moon ----------
base = dup("Vandal_RearSight", "TSC_Sight_RearBase")
bm = bmesh.new(); bm.from_mesh(base.data); mw = base.matrix_world; bm.transform(mw)
ring = [f for f in bm.faces if (lambda c: math.hypot(c.y, c.z - AZ) > 0.040 and c.z > 0.478)(f.calc_center_median())]
bmesh.ops.delete(bm, geom=ring, context="FACES")
bnd = [e for e in bm.edges if e.is_boundary]
if bnd:
	bmesh.ops.holes_fill(bm, edges=bnd, sides=0)
bnd = [e for e in bm.edges if e.is_boundary]
if bnd:
	bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=bnd)
bm.transform(mw.inverted()); bm.to_mesh(base.data); bm.free()
def crescent(ro, ri, off, gap, n=22):
	a0, a1 = math.radians(90 + gap), math.radians(90 - gap + 360)
	outer = [(ro * math.cos(a0 + (a1 - a0) * i / n), AZ + ro * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
	inner = []
	for i in range(1, n):
		a = a1 - (a1 - a0) * i / n
		inner.append((ri * math.cos(a), AZ + off + ri * math.sin(a)))
	return outer + inner
cres = crescent(0.074, 0.0645, 0.0055, 36)
new_obj("TSC_Sight_Crescent", prism_yz(cres, AX - 0.009, AX + 0.009), "Body")
face = crescent(0.0725, 0.0665, 0.0035, 38)
new_obj("TSC_Sight_CrescentFace", prism_yz(face, AX - 0.0112, AX - 0.0092), "Panel", bevel=0)
for s in (1, -1):         # cyan caps seated on the horn tips
	a = math.radians(90 + s * 36)
	ty, tz = 0.069 * math.cos(a), AZ + 0.069 * math.sin(a) + 0.001
	pip = [(ty, tz + 0.0065), (ty + 0.0045, tz), (ty, tz - 0.0045), (ty - 0.0045, tz)]
	new_obj("TSC_Sight_Pip%+d" % s, prism_yz(pip, AX - 0.0105, AX + 0.0105), "Neon", bevel=0)
for n in ("TS_Sight_Crescent", "TS_Sight_Pip+1", "TS_Sight_Pip-1"):
	if n in bpy.data.objects:
		o = bpy.data.objects[n]; o.hide_render = True; o.hide_set(True); o["ts_replaced"] = True

# ---------- muzzle brake: long ported block, fangs, shuriken face ----------
br = [ring_x(x, octo(hw, hh, c=0.14, cz=BORE)) for x, hw, hh in ((2.286, 0.050, 0.054), (2.300, 0.062, 0.066),
	(2.598, 0.062, 0.066), (2.612, 0.058, 0.062), (2.652, 0.058, 0.062))]
brake = new_obj("TSC_Brake", loft(br), "Body")
for i, x in enumerate((2.362, 2.480)):
	bm = prism_xz([(x - 0.036, BORE - 0.036), (x + 0.030, BORE - 0.036), (x + 0.038, BORE + 0.036), (x - 0.028, BORE + 0.036)], -0.2, 0.2)
	boolean(brake, cutter("TSC_CUT_Window%d" % i, bm))
for i in range(3):
	x = 2.556 + i * 0.020
	boolean(brake, cutter("TSC_CUT_Top%d" % i, prism_xz([(x - 0.006, BORE + 0.03), (x + 0.006, BORE + 0.03), (x + 0.006, BORE + 0.09), (x - 0.006, BORE + 0.09)], -0.022, 0.022)))
for s in (1, -1):
	bm = prism_xz([(2.632, BORE - 0.10), (2.700, BORE - 0.10), (2.700, BORE + 0.10), (2.632, BORE + 0.10)], -0.02, 0.02)
	c = cutter("TSC_CUT_Fang%+d" % s, bm); c.rotation_euler = (0, 0, math.radians(45)); c.location = (0, s * 0.0, 0)
	c.matrix_world = Matrix.Translation((0, s * 0.060, 0)) @ Matrix.Translation((2.664, 0, 0)) @ Matrix.Rotation(math.radians(45), 4, "Z") @ Matrix.Translation((-2.664, 0, 0))
	boolean(brake, c)
star = []
for i in range(8):
	a = math.radians(90 + i * 45)
	r = 0.040 if i % 2 == 0 else 0.012
	star.append((r * math.cos(a), BORE + r * math.sin(a)))
boolean(brake, cutter("TSC_CUT_Shuriken", prism_yz(star, 2.641, 2.70)))
new_obj("TSC_BrakeCore", loft([ring_x(2.31, octo(0.040, 0.040, c=0.3, cz=BORE)), ring_x(2.60, octo(0.040, 0.040, c=0.3, cz=BORE))]), "Metal", bevel=0)
new_obj("TSC_BrakeStar", prism_yz([(y * 0.92, BORE + (z - BORE) * 0.92) for y, z in star], 2.6405, 2.6425), "Neon", bevel=0)

for nm, x0, x1 in (("TSC_BrakeBandRear", 2.300, 2.318), ("TSC_BrakeBandFront", 2.600, 2.614)):
	new_obj(nm, loft([ring_x(x0, octo(0.0645, 0.0685, c=0.14, cz=BORE)), ring_x(x1, octo(0.0645, 0.0685, c=0.14, cz=BORE))]), "Panel")
# ---------- action: kunai charging handle + silver bolt with a hydro line ----------
replaced("Vandal_ChargingHandle")
slider = prism_xz([(0.560, 0.292), (0.770, 0.292), (0.782, 0.309), (0.770, 0.326), (0.560, 0.326), (0.548, 0.309)], 0.074, 0.090)
new_obj("TSC_ChargingSlider", slider, "Metal", like="Vandal_ChargingHandle")
def kunai_ring(y, hx, hz, cx=0.700, cz=0.309):
	return [(cx + hx, y, cz), (cx, y, cz + hz), (cx - hx * 0.7, y, cz), (cx, y, cz - hz)]
bm = loft([kunai_ring(0.088, 0.062, 0.018), kunai_ring(0.104, 0.050, 0.015), kunai_ring(0.120, 0.022, 0.008), kunai_ring(0.128, 0.004, 0.002)])
new_obj("TSC_ChargingHandle", bm, "Panel", like="Vandal_ChargingHandle", bevel=0.0006)
bolt = dup("Vandal_Bolt", "TSC_Bolt")
pi = list(bolt.data.materials).index(M("Panel"))
for p in bolt.data.polygons:
	p.material_index = pi
new_obj("TSC_BoltLine", prism_xz([(0.400, 0.302), (0.585, 0.302), (0.585, 0.307), (0.400, 0.307)], -0.0772, -0.0744), "Neon", like="Vandal_Bolt", bevel=0)

# ---------- slimmer butt (owner: "too thick in the back") ----------
st = bpy.data.objects["TS_Stock"]
if "Window" in st.modifiers:
	# bake the skeleton window into the mesh, then merge the boolean's coplanar triangles
	bpy.context.view_layer.objects.active = st
	with bpy.context.temp_override(object=st, active_object=st):
		bpy.ops.object.modifier_apply(modifier="Window")
	bm = bmesh.new(); bm.from_mesh(st.data)
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), verts=bm.verts[:], edges=bm.edges[:])
	bm.to_mesh(st.data); bm.free()
if not st.get("slim"):
	mw = st.matrix_world; mi = mw.inverted()
	for v in st.data.vertices:
		w = mw @ v.co
		if w.x <= -1.095:
			w.x = -1.252 + (w.x + 1.252) * 0.58
			if abs(w.y) > 0.060:
				w.y *= 0.77
			v.co = mi @ w
	st["slim"] = True

# ---------- hydro inlays + stock blade ----------
for s in (1, -1):
	surface_plate("Vandal_Receiver", "TSC_HydroRec%+d" % s, [(0.09, 0.3455), (0.97, 0.3455), (0.99, 0.3485), (0.97, 0.3515), (0.09, 0.3515), (0.07, 0.3485)],
		s, lift=0.0009, thick=0.0016, mat="Neon")
	surface_plate("Vandal_Stock", "TSC_StockBlade%+d" % s, [(-0.300, 0.405), (-1.000, 0.405), (-1.085, 0.390), (-1.010, 0.358), (-0.360, 0.358)],
		s, lift=0.0008, thick=0.0045, mat="Panel")
bpy.ops.wm.save_mainfile()
result = {"made": sorted(o.name for o in TS.objects if o.name.startswith("TSC_"))}
