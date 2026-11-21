# Tempest-Strike Vandal s04, stage E: new silhouette parts that mate EXACTLY to the stock receiver.
#  - Handguard: starts with the stock handguard's own rear section (x 1.046) inside the receiver, then
#    tapers into a longer, keeled, sharper shroud ending in a raked blade chin over the barrel.
#  - Stock: slim skeletal frame (faceted top bar, diagonal strut, thin butt with pointed toe) that starts
#    with the stock's own joint section (x -0.174), so the join to the receiver is identical to stock.
#  - Brake: two big windows replaced by three narrow raked ports per side.
# Run after stages A-D. Idempotent for TSE_ parts.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_vandal/tv_s_lib.py").read())
purge(("TSE_",))

def hide(names):
	for n in names:
		o = bpy.data.objects.get(n)
		if o:
			o.hide_render = True; o.hide_set(True); o["ts_replaced"] = True

# ================= HANDGUARD =================
def hg_sec(hw, top, side_hi, side_lo, bot, ktop=0.66, kbot=0.55):
	"""Stock handguard topology (8 pts): flat sides, lean-in top planes, keeled bottom planes."""
	R = [(hw, side_lo), (hw, side_hi), (hw * ktop, top), (-hw * ktop, top), (-hw, side_hi), (-hw, side_lo),
		(-hw * kbot, bot), (hw * kbot, bot)]
	return R
STOCK_REAR = [(0.098, 0.211), (0.098, 0.380), (0.066, 0.412), (-0.066, 0.412), (-0.098, 0.380), (-0.098, 0.211),
	(-0.058, 0.170), (0.058, 0.170)]
HG = [ring_x(1.046, STOCK_REAR), ring_x(1.110, STOCK_REAR),
	ring_x(1.480, hg_sec(0.090, 0.408, 0.374, 0.214, 0.170, 0.64, 0.52)),
	ring_x(1.700, hg_sec(0.076, 0.402, 0.368, 0.236, 0.196, 0.60, 0.48)),
	ring_x(1.800, hg_sec(0.066, 0.400, 0.366, 0.246, 0.214, 0.58, 0.46))]
# raked blade nose: top cut back, chin runs forward under the barrel
nose = hg_sec(0.058, 0.398, 0.364, 0.252, 0.226, 0.56, 0.42)
HG.append([(1.840 + 0.075 * (1 - (z - 0.226) / 0.172), y, z) for y, z in nose])
hgo = new_obj("TSE_Handguard", loft(HG), "Body", like="Vandal_Handguard", bevel=0.0012)
# raked vent slots in the upper side band (dark liner = boolean faces take the cutter's Dark material)
for s in (1, -1):
	for i in range(4):
		x = 1.20 + i * 0.062
		bm = prism_xz([(x - 0.010, 0.299), (x + 0.004, 0.299), (x + 0.016, 0.338), (x + 0.002, 0.338)], 0, 0.04)
		c = cutter("TSE_CUT_Vent%d%+d" % (i, s), bm)
		c.matrix_world = Matrix.Translation((0, (0.074 if s > 0 else -0.114), 0))
		boolean(hgo, c)
hide(["Vandal_Handguard", "TS_GuardPlate+1", "TS_GuardPlate-1", "TSD_Fin1+1", "TSD_Fin1-1", "TSD_Fin2+1", "TSD_Fin2-1",
	"TSD_FinLine+1", "TSD_FinLine-1"])
# silver armour on the new handguard (cut from its own surface): long low blade + two stacked upper fins
for s in (1, -1):
	surface_plate("TSE_Handguard", "TSE_GuardBlade%+d" % s,
		[(1.065, 0.292), (1.065, 0.222), (1.120, 0.200), (1.760, 0.226), (1.835, 0.262), (1.700, 0.276), (1.140, 0.292)], s,
		lift=0.0008, thick=0.0055)
	surface_plate("TSE_Handguard", "TSE_Fin1%+d" % s,
		[(1.080, 0.372), (1.520, 0.370), (1.640, 0.362), (1.540, 0.340), (1.120, 0.344)], s, lift=0.0008, thick=0.005)
	surface_plate("TSE_Handguard", "TSE_Fin2%+d" % s,
		[(1.300, 0.367), (1.540, 0.364), (1.600, 0.358), (1.530, 0.348), (1.330, 0.350)], s, lift=0.0062, thick=0.0045)
	surface_plate("TSE_Handguard", "TSE_HydroLine%+d" % s,
		[(1.100, 0.2955), (1.680, 0.2785), (1.684, 0.2815), (1.100, 0.2985)], s, lift=0.0004, thick=0.0016, mat="Neon")
# the fluted barrel sleeve now starts inside the new nose
sh = bpy.data.objects.get("TSC_Shroud")
if sh:
	for v in sh.data.vertices:
		w = sh.matrix_world @ v.co
		if w.x < 1.75:
			w.x = 1.840 + (w.x - 1.680) * 0.5
			v.co = sh.matrix_world.inverted() @ w

# ================= SKELETAL STOCK =================
JOINT = [(0.050, 0.231), (0.050, 0.359), (0.034, 0.375), (-0.034, 0.375), (-0.050, 0.359), (-0.050, 0.231),
	(-0.034, 0.215), (0.034, 0.215)]
col = [ring_x(-0.168, JOINT), ring_x(-0.230, JOINT), ring_x(-0.262, [(y * 0.92, 0.295 + (z - 0.295) * 0.96) for y, z in JOINT])]
new_obj("TSE_StockCollar", loft(col), "Body", like="Vandal_Stock")
def bar(p0, p1, hw, hh, k=0.55):
	"""Faceted bar (8-pt section: flat sides, lean-in top and bottom planes) between two XZ points."""
	a, b = Vector((p0[0], 0, p0[1])), Vector((p1[0], 0, p1[1]))
	t = (b - a).normalized(); n = Vector((-t.z, 0, t.x))           # in-plane normal (up-ish)
	sec = [(hw, -hh * 0.45), (hw, hh * 0.45), (hw * k, hh), (-hw * k, hh), (-hw, hh * 0.45), (-hw, -hh * 0.45),
		(-hw * k, -hh), (hw * k, -hh)]
	ring = lambda c: [tuple(c + Vector((0, y, 0)) + n * z) for y, z in sec]
	return loft([ring(a), ring(b)])
new_obj("TSE_StockTopBar", bar((-0.240, 0.352), (-1.200, 0.372), 0.030, 0.026), "Body", like="Vandal_Stock")
new_obj("TSE_StockStrut", bar((-0.240, 0.246), (-1.200, -0.102), 0.026, 0.022), "Body", like="Vandal_Stock")
butt = [(-1.252, 0.414), (-1.196, 0.414), (-1.170, 0.392), (-1.172, 0.330), (-1.188, -0.040), (-1.150, -0.188),
	(-1.252, -0.176)]
new_obj("TSE_StockButt", prism_xz(butt, -0.056, 0.056), "Body", like="Vandal_Stock", bevel=0.0015)
pad = [(-1.264, 0.404), (-1.250, 0.404), (-1.250, -0.170), (-1.264, -0.166)]
new_obj("TSE_StockPad", prism_xz(pad, -0.052, 0.052), "Dark", like="Vandal_Stock")
for s in (1, -1):         # silver side plate on the butt, pointed toe
	bp = [(-1.244, 0.400), (-1.200, 0.400), (-1.180, 0.380), (-1.196, -0.030), (-1.166, -0.170), (-1.244, -0.160)]
	y0 = s * 0.056
	new_obj("TSE_ButtPlate%+d" % s, prism_xz(bp, min(y0, y0 + s * 0.004), max(y0, y0 + s * 0.004)), "Panel", like="Vandal_Stock")
# silver blade along the top bar, water-ring hub near the butt
tb = [(-0.300, 0.381), (-1.150, 0.399), (-1.180, 0.395), (-1.150, 0.390), (-0.330, 0.374)]
new_obj("TSE_StockTopBlade", prism_xz(tb, -0.0185, 0.0185), "Panel", like="Vandal_Stock")
hub = [ring_x(x, octo(0.040, 0.036, c=0.3, cz=0.371)) for x in (-1.010, -0.996, -0.974, -0.960)]
new_obj("TSE_StockHub", loft(hub), "Panel", like="Vandal_Stock")
new_obj("TSE_StockHubLine", loft([ring_x(-0.986, octo(0.0412, 0.0372, c=0.3, cz=0.371)), ring_x(-0.984, octo(0.0412, 0.0372, c=0.3, cz=0.371))]), "Neon", like="Vandal_Stock", bevel=0)
hide(["TS_Stock", "TSC_StockBlade+1", "TSC_StockBlade-1"])

# ================= BRAKE PORTS =================
br = bpy.data.objects.get("TSC_Brake")
if br:
	for m in list(br.modifiers):
		if m.type == "BOOLEAN" and m.object and m.object.name.startswith("TSC_CUT_Window"):
			br.modifiers.remove(m)
	for i in range(3):
		x = 2.360 + i * 0.058
		for s in (1, -1):
			bm = prism_xz([(x - 0.008, 0.255), (x + 0.004, 0.255), (x + 0.016, 0.315), (x + 0.004, 0.315)], 0, 0.04)
			c = cutter("TSE_CUT_Port%d%+d" % (i, s), bm)
			c.matrix_world = Matrix.Translation((0, (0.038 if s > 0 else -0.078), 0))
			boolean(br, c)
bpy.ops.wm.save_mainfile()
result = {"made": sorted(o.name for o in TS.objects if o.name.startswith("TSE_"))}
