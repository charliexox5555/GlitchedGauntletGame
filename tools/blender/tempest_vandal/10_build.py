# Tempest-Strike Vandal r01: main model. Rebuilds COL_Model from scratch (idempotent).
# Design numbers live here; contract points come from the stock Vandal (see vault Vandal Hero Plan).
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_vandal/tv_lib.py").read())

M = coll("COL_Model")
K = coll("COL_Cutters")
clear_coll(M); clear_coll(K)
C = {}
def sub(n):
	c = coll("TS_" + n, M)
	C[n] = c
	return c
for n in ("Receiver", "Fore", "Muzzle", "Sight", "Grip", "Mag", "Stock", "Plates"):
	sub(n)

def kc(name, bm):
	o = to_obj("CUT_" + name, bm, K, "Dark")
	o.display_type = "WIRE"; o.hide_render = True
	return o

BORE = 0.285
HW = 0.092          # receiver half width

# ================= RECEIVER =================
# Lofted section: narrow keel, stepped lower band (8 thou narrower = a real shadow line), vertical upper
# band, an upper plane leaning in, narrow top. The brushed-silver cowl rides the leaning plane, which is
# what the player sees most in first person.
ZSTEP = 0.205
def rec_sec(zb, zt, k=1.0):
	hb, hs, ht, hp = 0.060 * k, HW * k, 0.071 * k, 0.040 * k
	zs = zt - 0.085
	R = [(hb, zb), (hs - 0.009, zb + 0.032), (hs - 0.009, ZSTEP - 0.004), (hs, ZSTEP + 0.005), (hs, zs),
		(ht, zt - 0.022), (hp, zt)]
	return R + [(-y, z) for y, z in R[::-1]]
REC = [(-0.188, 0.150, 0.352, 0.72), (-0.170, 0.122, 0.372, 0.84), (-0.100, 0.100, 0.412, 0.96),
	(0.020, 0.090, 0.430, 1.0), (0.440, 0.090, 0.430, 1.0), (0.860, 0.094, 0.430, 1.0),
	(1.000, 0.110, 0.428, 0.985), (1.092, 0.145, 0.420, 0.965)]
def rec_at(x):
	for (x0, b0, t0, k0), (x1, b1, t1, k1) in zip(REC[:-1], REC[1:]):
		if x0 <= x <= x1:
			f = (x - x0) / (x1 - x0)
			return b0 + (b1 - b0) * f, t0 + (t1 - t0) * f, k0 + (k1 - k0) * f
	return REC[-1][1:]
bm = loft([ring_x(x, rec_sec(zb, zt, k)) for x, zb, zt, k in REC])
rec = finish(to_obj("TS_Receiver", bm, C["Receiver"], "Body"), w=0.004)

# ejection port (right side) with a dark liner and a steel bolt face inside
cut(rec, kc("EjectPort", profile("e", [(0.300, 0.262), (0.330, 0.232), (0.560, 0.232), (0.585, 0.262), (0.560, 0.300),
	(0.330, 0.300)], 0.03, K, "Dark", yc=-(HW + 0.012))))
bm = profile("Bolt", [(0.31, 0.236), (0.575, 0.236), (0.575, 0.296), (0.31, 0.296)], 0.012, M, "Metal", yc=-(HW - 0.022))
finish(to_obj("TS_BoltFace", bm, C["Receiver"], "Metal"), w=0.0)
# charging slot (left side) the handle rides in
cut(rec, kc("ChargeSlot", profile("c", [(0.30, 0.252), (0.80, 0.252), (0.815, 0.262), (0.80, 0.272), (0.30, 0.272)],
	0.03, K, "Dark", yc=(HW + 0.012))))

# brushed-silver cowl: one armour plate per side wrapping the shoulder (side band + leaning plane + top
# chamfer). Lower edge: high at the tail, clears the ejection port and charging slot, then steps down
# (raked notch) into a big front shoulder that ends in a point at the collar.
def cowl_ring(x, s, zlow, f1, lift=0.0012, th=0.0060):
	zb, zt, k = rec_at(x)
	sec = rec_sec(zb, zt, k)
	P2, P3, P4 = Vector(sec[4]), Vector(sec[5]), Vector(sec[6])      # band top, lean top, top edge
	zlow = min(zlow, P2.y - 0.002)
	A = Vector((P2.x, zlow)); B = P2; Cc = P3; Dd = P3.lerp(P4, f1)
	poly = [A, B, Cc, Dd]
	def onrm(p, q):
		t = (q - p).normalized()
		n = Vector((t.y, -t.x))
		return n if n.x >= 0 else -n
	ns = [onrm(poly[0], poly[1])]
	for i in range(1, 3):
		n0, n1 = onrm(poly[i - 1], poly[i]), onrm(poly[i], poly[i + 1])
		nb = (n0 + n1).normalized()
		ns.append(nb / max(0.5, nb.dot(n0)))
	ns.append(onrm(poly[2], poly[3]))
	inner = [poly[i] + ns[i] * lift for i in range(4)]
	outer = [poly[i] + ns[i] * (lift + th) for i in range(4)]
	pts = inner + outer[::-1]
	return [(x, s * q.x, q.y) for q in pts]
CW = [(-0.110, 0.400, 0.10), (-0.080, 0.330, 0.70), (0.000, 0.312, 0.85), (0.300, 0.310, 0.85), (0.600, 0.310, 0.85), (0.640, 0.238, 0.85),
	(0.950, 0.238, 0.85), (1.030, 0.280, 0.80), (1.070, 0.330, 0.55), (1.086, 0.343, 0.12)]
for s in (1, -1):
	rings = [cowl_ring(x, s, zl, f1) for x, zl, f1 in CW]
	if s < 0:
		rings = [r[::-1] for r in rings]
	bm = loft(rings)
	cw = finish(to_obj("TS_Cowl%+d" % s, bm, C["Plates"], "Panel"), w=0.0012)
	# storm-blue inlay groove along the front shoulder
	g = kc("CowlGroove%+d" % s, profile("g", [(0.690, 0.262), (0.930, 0.262), (0.985, 0.288), (0.975, 0.296),
		(0.925, 0.272), (0.700, 0.272)], 0.006, K, "Accent", yc=s * (HW + 0.0072)))
	cut(cw, g)

# top spine: raised blade along the receiver top, silver inlay sits on it
spine_pts = [(0.20, 0.425), (1.10, 0.425), (1.10, 0.452), (1.04, 0.470), (0.30, 0.470), (0.22, 0.452)]
bm = profile("Spine", spine_pts, 0.034, M, "Body")
chamfer_edges(bm, side_edges(up=True), 0.018, segs=1)
finish(to_obj("TS_Spine", bm, C["Receiver"], "Body"), w=0.004)
inlay_pts = [(0.34, 0.466), (1.02, 0.466), (1.00, 0.476), (0.36, 0.476)]
bm = profile("Inlay", inlay_pts, 0.020, M, "Panel")
finish(to_obj("TS_SpineInlay", bm, C["Plates"], "Panel"), w=0.003)

# magwell lip (flared collar where the mag enters)
mw_pts = [(0.462, 0.100), (0.828, 0.100), (0.842, 0.058), (0.826, 0.046), (0.470, 0.046), (0.455, 0.058)]
bm = profile("Magwell", mw_pts, 0.062, M, "Metal")
chamfer_edges(bm, lambda e: True, 0.008)
finish(to_obj("TS_Magwell", bm, C["Receiver"], "Metal"), w=0.0)

# front collar: transition ring receiver -> shroud (stepped, steel)
CZ = 0.292
bm = loft([ring_x(1.075, octo(0.090, 0.130, c=0.5, cz=CZ)), ring_x(1.092, octo(0.094, 0.134, c=0.5, cz=CZ)),
	ring_x(1.128, octo(0.094, 0.134, c=0.5, cz=CZ)), ring_x(1.142, octo(0.086, 0.124, c=0.5, cz=CZ))])
finish(to_obj("TS_Collar", bm, C["Fore"], "Metal"), w=0.0025)

# ================= FORE-END: octagonal fluted shroud =================
# Section = elongated octagon with broad diagonals. Grooves are part of the section, so they taper
# with the shroud and run out cleanly (depth ramps to 0) instead of being boxes cut in.
FLUTE_SPEC = lambda dS, dD: {0: [(0.26, 0.012, dS)], 1: [(0.5, 0.012, dD)], 3: [(0.5, 0.012, dD)],
	4: [(0.74, 0.012, dS)], 5: [(0.5, 0.010, dD * 0.8)], 7: [(0.5, 0.010, dD * 0.8)]}
def shroud_sec(x, hw, hh, cz=CZ):
	ramp = lambda a, b: max(0.0, min(1.0, (x - a) / (b - a)))
	dD = 0.0065 * ramp(1.12, 1.20) * (1 - ramp(1.96, 2.10))        # diagonal flutes
	dS = 0.0060 * ramp(1.40, 1.48) * (1 - ramp(1.96, 2.10))        # side flutes start after the vents
	return fluted(octo(hw, hh, c=0.5, cz=cz), FLUTE_SPEC(dS, dD))
ST = [(1.10, 0.080, 0.116), (1.20, 0.079, 0.114), (1.44, 0.076, 0.110), (1.52, 0.075, 0.108), (1.96, 0.065, 0.094),
	(2.10, 0.062, 0.090), (2.18, 0.060, 0.087)]
rings = [ring_x(x, shroud_sec(x, hw, hh)) for x, hw, hh in ST]
rings.append(ring_x(2.205, shroud_sec(2.205, 0.050, 0.074, cz=CZ - 0.002)))
bm = loft(rings)
shroud = finish(to_obj("TS_Shroud", bm, C["Fore"], "Body"), w=0.0025, angle=25)

# side vents near the collar: three raked slots each side, cut through to a dark liner
FL = coll("COL_Cutters_Vents", K)
for s in (1, -1):
	for i in range(3):
		bmv = box(-0.014, 0.014, -0.03, 0.03, -0.022, 0.022)
		o = to_obj("CUT_Vent%d%+d" % (i, s), bmv, FL, "Dark")
		o.location = (1.215 + i * 0.062, s * 0.082, CZ - 0.044)
		o.rotation_euler = (0, math.radians(28), 0)
cut_coll(shroud, FL, "Vents")
bm = loft([ring_x(1.16, octo(0.060, 0.096, c=0.5, cz=CZ)), ring_x(1.42, octo(0.060, 0.096, c=0.5, cz=CZ))])
finish(to_obj("TS_VentLiner", bm, C["Fore"], "Dark"), w=0.0)

# silver side blades on the shroud: cover the upper side face, sharp point forward-down
def hw_at(x):
	for (x0, w0, h0), (x1, w1, h1) in zip(ST[:-1], ST[1:]):
		if x0 <= x <= x1:
			f = (x - x0) / (x1 - x0)
			return w0 + (w1 - w0) * f, h0 + (h1 - h0) * f
	return ST[-1][1:]
for s in (1, -1):
	rings = []
	for x, f0, f1 in ((1.150, 0.46, 0.93), (1.60, 0.46, 0.93), (1.78, 0.50, 0.90), (1.86, 0.62, 0.80), (1.895, 0.70, 0.72)):
		hw, hh = hw_at(x)
		z0, z1 = CZ - hh + 0.5 * hw, CZ + hh - 0.5 * hw
		za, zb_ = z0 + (z1 - z0) * f0, z0 + (z1 - z0) * f1
		yi, yo = hw + 0.0008, hw + 0.0050
		r = [(x, yi, za), (x, yo, za + 0.002), (x, yo, zb_ - 0.002), (x, yi, zb_)]
		r = [(px, s * py, pz) for px, py, pz in r]
		rings.append(r if s > 0 else r[::-1])
	bm = loft(rings)
	finish(to_obj("TS_ShroudBlade%+d" % s, bm, C["Plates"], "Panel"), w=0.0012)

# silver top plate: a blade riding the shroud's top face, tapering to a point before the front sight
tp = []
for x, hw, z in ((1.13, 0.042, 0.408), (1.30, 0.041, 0.406), (1.70, 0.035, 0.396), (1.86, 0.026, 0.388), (1.91, 0.004, 0.386)):
	tp.append([(x, hw, z - 0.004), (x, hw - 0.004, z + 0.006), (x, -hw + 0.004, z + 0.006), (x, -hw, z - 0.004)])
bm = loft(tp)
finish(to_obj("TS_ShroudPlate", bm, C["Plates"], "Panel"), w=0.0015)

# exposed barrel neck + collar
bm = loft([ring_x(2.19, octo(0.040, 0.040, c=0.42, cz=BORE)), ring_x(2.32, octo(0.040, 0.040, c=0.42, cz=BORE))])
finish(to_obj("TS_Barrel", bm, C["Muzzle"], "Metal"), w=0.002)
bm = loft([ring_x(2.232, octo(0.050, 0.050, c=0.42, cz=BORE)), ring_x(2.246, octo(0.056, 0.056, c=0.42, cz=BORE)),
	ring_x(2.268, octo(0.056, 0.056, c=0.42, cz=BORE)), ring_x(2.282, octo(0.050, 0.050, c=0.42, cz=BORE))])
finish(to_obj("TS_BarrelCollar", bm, C["Muzzle"], "Panel"), w=0.0015)

# muzzle brake: stepped octagon, three through-ports, two top ports, a cut crown with fangs
br = []
for x, hw, hh in ((2.296, 0.050, 0.052), (2.312, 0.062, 0.066), (2.592, 0.062, 0.066), (2.606, 0.058, 0.062),
	(2.640, 0.058, 0.062), (2.652, 0.052, 0.056)):
	br.append(ring_x(x, octo(hw, hh, c=0.5, cz=BORE)))
bm = loft(br)
brake = finish(to_obj("TS_Brake", bm, C["Muzzle"], "Body"), w=0.002)
PC = coll("COL_Cutters_Brake", K)
for i in range(3):
	bmp = box(-0.0175, 0.0175, -0.10, 0.10, -0.034, 0.034)
	o = to_obj("CUT_Port%d" % i, bmp, PC, "Dark")
	o.location = (2.365 + i * 0.072, 0, BORE)
	o.rotation_euler = (0, math.radians(-14), 0)
for i in range(2):
	bmp = box(-0.014, 0.014, -0.020, 0.020, -0.03, 0.03)
	o = to_obj("CUT_PortTop%d" % i, bmp, PC, "Dark")
	o.location = (2.40 + i * 0.072, 0, BORE + 0.066)
for s in (1, -1):
	bmp = box(-0.026, 0.026, -0.026, 0.026, -0.10, 0.10)
	o = to_obj("CUT_Crown%+d" % s, bmp, PC, "Dark")
	o.location = (2.662, s * 0.060, BORE)
	o.rotation_euler = (0, 0, math.radians(45))
bmp = loft([ring_x(2.2, ngon_yz(0.024, 8, cz=BORE, rot=math.pi / 8)), ring_x(2.7, ngon_yz(0.024, 8, cz=BORE, rot=math.pi / 8))])
to_obj("CUT_Bore", bmp, PC, "Dark")
cut_coll(brake, PC, "Ports")
bm = loft([ring_x(2.33, ngon_yz(0.036, 8, cz=BORE, rot=math.pi / 8)), ring_x(2.60, ngon_yz(0.036, 8, cz=BORE, rot=math.pi / 8))])
finish(to_obj("TS_BrakeCore", bm, C["Muzzle"], "Dark"), w=0.0)

# ================= SIGHTS =================
# front: swept blade post on the shroud, tip on the aim line
fs_pts = [(1.925, 0.378), (2.085, 0.372), (2.045, 0.430), (2.010, 0.548), (1.996, 0.560), (1.986, 0.548), (1.965, 0.440)]
bm = profile("FrontSight", fs_pts, 0.011, M, "Body")
finish(to_obj("TS_Sight_Front", bm, C["Sight"], "Body"), w=0.002)
bm = profile("FrontSightBase", [(1.90, 0.370), (2.11, 0.362), (2.09, 0.392), (1.94, 0.400)], 0.034, M, "Metal")
chamfer_edges(bm, side_edges(up=True), 0.012)
finish(to_obj("TS_Sight_FrontBase", bm, C["Sight"], "Metal"), w=0.002)

# rear: open crescent (faceted moon), centred on AimPoint, horns open at the top
AX, AZ = 0.078, 0.560
def crescent(ro, ri, off, gap_deg, n=14):
	a0 = math.radians(90 + gap_deg)
	a1 = math.radians(90 - gap_deg + 360)
	outer = [(ro * math.cos(a0 + (a1 - a0) * i / n), AZ + ro * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
	# inner arc: circle shifted up by off, between the same horn tips
	tipL, tipR = outer[0], outer[-1]
	inner = []
	for i in range(1, n):
		a = a1 - (a1 - a0) * i / n
		inner.append((ri * math.cos(a), AZ + off + ri * math.sin(a)))
	return outer + inner
cres = crescent(0.092, 0.074, 0.016, 38)
bm = plate_yz("Crescent", cres, AX - 0.014, AX + 0.014)
finish(to_obj("TS_Sight_Crescent", bm, C["Sight"], "Body"), w=0.0025)
# silver face ring on the shooter side (thin, inset)
cres2 = crescent(0.086, 0.078, 0.008, 40)
bm = plate_yz("CrescentFace", cres2, AX - 0.018, AX - 0.012)
finish(to_obj("TS_Sight_CrescentFace", bm, C["Sight"], "Panel"), w=0.0)
# pedestal: swept mount from the receiver top into the crescent foot
ped = [(-0.005, 0.425), (0.170, 0.425), (0.125, 0.452), (AX + 0.024, 0.476), (AX - 0.024, 0.476), (0.025, 0.452)]
bm = profile("SightPed", ped, 0.030, M, "Body")
chamfer_edges(bm, side_edges(up=True), 0.010)
finish(to_obj("TS_Sight_Pedestal", bm, C["Sight"], "Body"), w=0.002)
# two pips outside the aim centre (cyan, low)
for s in (1, -1):
	a = math.radians(90 + s * 58)
	py, pz = 0.112 * math.cos(a), AZ + 0.112 * math.sin(a)
	pts = [(py, pz + 0.012), (py + 0.008, pz), (py, pz - 0.012), (py - 0.008, pz)]
	bm = plate_yz("Pip", pts, AX - 0.008, AX + 0.008)
	finish(to_obj("TS_Sight_Pip%+d" % s, bm, C["Sight"], "Neon"), w=0.0, wn=False)
	# pip arm joining the crescent
	arm = [(0.096 * math.cos(a) - 0.004, AZ + 0.096 * math.sin(a)), (0.104 * math.cos(a), AZ + 0.104 * math.sin(a) + 0.004),
		(0.104 * math.cos(a) + 0.004, AZ + 0.104 * math.sin(a) - 0.002), (0.090 * math.cos(a) + 0.004, AZ + 0.090 * math.sin(a) - 0.006)]
	bm = plate_yz("PipArm", arm, AX - 0.006, AX + 0.006)
	finish(to_obj("TS_Sight_PipArm%+d" % s, bm, C["Sight"], "Body"), w=0.0)

# ================= GRIP =================
grip_pts = [(-0.035, 0.100), (0.165, 0.100), (0.128, 0.020), (0.110, -0.050), (0.092, -0.090), (0.078, -0.170),
	(0.050, -0.262), (0.030, -0.300), (-0.130, -0.300), (-0.160, -0.262), (-0.120, -0.100), (-0.070, 0.030)]
bm = profile("Grip", grip_pts, 0.054, M, "Body")
chamfer_edges(bm, side_edges(), 0.018, segs=2)
finish(to_obj("TS_GripCore", bm, C["Grip"], "Body"), w=0.003)
# leather wrap: shell around the core, cut into slanted bands (tsuka-maki rhythm)
wrap_pts = poly_offset([(-0.083, -0.03), (0.126, -0.03), (0.110, -0.050), (0.092, -0.090), (0.078, -0.170), (0.054, -0.245),
	(-0.150, -0.245), (-0.120, -0.100), (-0.096, -0.03)], 0.006)
bm = profile("GripWrap", wrap_pts, 0.060, M, "Grip")
chamfer_edges(bm, side_edges(), 0.020, segs=2)
wrap = finish(to_obj("TS_GripWrap", bm, C["Grip"], "Grip"), w=0.002)
GW = coll("COL_Cutters_GripWrap", K)
for i in range(5):
	z = -0.045 - i * 0.045
	bmc = box(-0.30, 0.30, -0.10, 0.10, -0.0045, 0.0045)
	o = to_obj("CUT_GripGap%d" % i, bmc, GW, "Dark")
	o.location = (-0.02, 0, z)
	o.rotation_euler = (0, math.radians(-18 + (i % 2) * 8), 0)
cut_coll(wrap, GW, "Gaps")
# grip cap and top collar
cap = [(-0.168, -0.300), (0.038, -0.300), (0.050, -0.318), (0.030, -0.334), (-0.150, -0.334), (-0.178, -0.318)]
bm = profile("GripCap", cap, 0.062, M, "Panel")
chamfer_edges(bm, side_edges(), 0.012)
finish(to_obj("TS_GripCap", bm, C["Grip"], "Panel"), w=0.002)

# trigger guard + trigger
tg = band([(0.135, 0.085), (0.185, 0.012), (0.405, 0.012), (0.452, 0.078)], 0.024)
bm = profile("Guard", tg, 0.020, M, "Body")
finish(to_obj("TS_TriggerGuard", bm, C["Grip"], "Body"), w=0.004)
trig = [(0.215, 0.090), (0.236, 0.090), (0.232, 0.060), (0.246, 0.035), (0.238, 0.030), (0.218, 0.055)]
bm = profile("Trigger", trig, 0.010, M, "Metal")
finish(to_obj("TS_Trigger", bm, C["Grip"], "Metal"), w=0.002)

# ================= MAGAZINE (curved in straight segments) =================
def mag_frame(t):
	x = 0.645 + 0.10 * t + 0.13 * t * t
	z = 0.095 - 0.47 * t
	dx, dz = 0.10 + 0.26 * t, -0.47
	l = math.hypot(dx, dz)
	return Vector((x, 0, z)), Vector((dx / l, 0, dz / l)), Vector((-dz / l, 0, dx / l))  # p, tangent(down), normal(fwd)
def mag_ring(t, half_d, half_w, ch=0.012, grow=0.0):
	p, tg, nf = mag_frame(t)
	d, w = half_d + grow, half_w + grow
	sec = [(d, w - ch), (d - ch, w), (-d + ch, w), (-d, w - ch), (-d, -w + ch), (-d + ch, -w), (d - ch, -w), (d, -w + ch)]
	return [tuple(p + nf * a + Vector((0, b, 0))) for a, b in sec]
TS = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
bm = loft([mag_ring(t, 0.122, 0.048) for t in TS])
magcore = finish(to_obj("TS_MagCore", bm, C["Mag"], "Body"), w=0.003)
# wrap bands: sleeves over t-ranges, conduit gap between them
for i, (t0, t1) in enumerate(((0.10, 0.36), (0.42, 0.66), (0.72, 0.93))):
	ts = [t0 + (t1 - t0) * k / 3 for k in range(4)]
	rings = [mag_ring(t, 0.122, 0.048, grow=0.006) for t in ts]
	# taper the sleeve ends in by the wrap thickness so they read as wrapped, not boxed
	rings.insert(0, mag_ring(t0 - 0.008, 0.122, 0.048, grow=0.001))
	rings.append(mag_ring(t1 + 0.008, 0.122, 0.048, grow=0.001))
	bm = loft(rings)
	finish(to_obj("TS_MagWrap%d" % i, bm, C["Mag"], "Grip"), w=0.002)
# conduits: thin cyan strips in the gaps on both sides
for i, t in enumerate((0.39, 0.69)):
	rings = [mag_ring(t - 0.012, 0.100, 0.0505), mag_ring(t + 0.012, 0.100, 0.0505)]
	bm = loft(rings)
	finish(to_obj("TS_MagConduit%d" % i, bm, C["Mag"], "Neon"), w=0.0, wn=False)
# baseplate (silver, wider, chamfered toe)
rings = [mag_ring(0.985, 0.128, 0.052), mag_ring(1.02, 0.134, 0.056), mag_ring(1.06, 0.130, 0.054), mag_ring(1.075, 0.118, 0.046)]
bm = loft(rings)
finish(to_obj("TS_MagBase", bm, C["Mag"], "Panel"), w=0.002)

# ================= STOCK: open triangular frame =================
SW = 0.040
neck = [(-0.235, 0.120), (-0.150, 0.110), (-0.150, 0.395), (-0.205, 0.400), (-0.250, 0.360)]
bm = profile("StockNeck", neck, 0.070, M, "Body")
chamfer_edges(bm, side_edges(), 0.016, segs=2)
finish(to_obj("TS_StockNeck", bm, C["Stock"], "Body"), w=0.003)
top = band([(-0.22, 0.358), (-1.14, 0.326)], 0.074)
bm = profile("StockTop", top, SW, M, "Body")
chamfer_edges(bm, side_edges(), 0.012, segs=2)
finish(to_obj("TS_StockTop", bm, C["Stock"], "Body"), w=0.003)
strut = band([(-0.22, 0.160), (-1.14, -0.075)], 0.062)
bm = profile("StockStrut", strut, SW * 0.9, M, "Body")
chamfer_edges(bm, side_edges(), 0.012, segs=2)
finish(to_obj("TS_StockStrut", bm, C["Stock"], "Body"), w=0.003)
butt = [(-1.252, 0.400), (-1.150, 0.385), (-1.115, 0.330), (-1.120, -0.060), (-1.150, -0.150), (-1.252, -0.172)]
bm = profile("Butt", butt, 0.066, M, "Body")
chamfer_edges(bm, side_edges(), 0.020, segs=2)
finish(to_obj("TS_StockButt", bm, C["Stock"], "Body"), w=0.003)
pad = [(-1.262, 0.392), (-1.240, 0.392), (-1.240, -0.162), (-1.262, -0.160)]
bm = profile("Pad", pad, 0.060, M, "Dark")
chamfer_edges(bm, side_edges(), 0.012)
finish(to_obj("TS_StockPad", bm, C["Stock"], "Dark"), w=0.002)
# silver edge plates on the stock top bar (both sides)
for s in (1, -1):
	pp = [(-0.30, 0.380), (-1.05, 0.356), (-1.10, 0.342), (-1.05, 0.334), (-0.32, 0.356)]
	bm = profile("StockPlate", pp, 0.004, M, "Panel", yc=s * (SW + 0.002))
	finish(to_obj("TS_StockPlate%+d" % s, bm, C["Plates"], "Panel"), w=0.0015)
# ring hub at the rear junction (anchor for the water ring VFX later)
bm = plate_yz("Hub", octo(0.046, 0.046, c=0.42, cz=0.345), -1.13, -1.08)
finish(to_obj("TS_StockHub", bm, C["Stock"], "Metal"), w=0.003)

# charging handle (left side) restyled as a small blade
ch = [(0.42, 0.254), (0.50, 0.254), (0.545, 0.262), (0.50, 0.270), (0.42, 0.270)]
bm = profile("Charge", ch, 0.022, M, "Metal", yc=HW + 0.004)
chamfer_edges(bm, side_edges(), 0.006)
finish(to_obj("TS_ChargingHandle", bm, C["Receiver"], "Metal"), w=0.002)


# ================= LOWER RECEIVER DETAIL =================
# recessed trigger-housing panel (dark) with raked ends, both sides
for s in (1, -1):
	cut(rec, kc("LowerPanel%+d" % s, profile("lp", [(-0.070, 0.118), (0.395, 0.118), (0.425, 0.150), (0.395, 0.182),
		(-0.040, 0.182), (-0.085, 0.150)], 0.02, K, "Dark", yc=s * (HW - 0.009 + 0.0145))))
	# steel trim on the shadow line between the bands
	tr = [(-0.080, 0.200), (1.040, 0.200), (1.070, 0.207), (1.040, 0.214), (-0.080, 0.214), (-0.100, 0.207)]
	bm = profile("Trim", tr, 0.0022, M, "Metal", yc=s * (HW - 0.009 + 0.0024))
	finish(to_obj("TS_Trim%+d" % s, bm, C["Receiver"], "Metal"), w=0.0)
	# pins at real joints: grip/trigger pivot, front hinge, stock neck
	for (px, pz) in ((0.04, 0.150), (0.30, 0.150), (0.975, 0.150)):
		bm = loft([[(px + dx, s * (HW - 0.009), pz + dz) for dx, dz in ngon_yz(0.012, 8, rot=math.pi / 8)],
			[(px + dx * 0.8, s * (HW - 0.009 + 0.006), pz + dz * 0.8) for dx, dz in ngon_yz(0.012, 8, rot=math.pi / 8)]])
		finish(to_obj("TS_Pin_%d%+d" % (int(px * 1000), s), bm, C["Receiver"], "Metal"), w=0.0)
# fire selector (left side): hub + raked lever
bm = loft([[(0.080 + dx, HW - 0.009, 0.150 + dz) for dx, dz in ngon_yz(0.020, 8, rot=math.pi / 8)],
	[(0.080 + dx * 0.85, HW - 0.009 + 0.010, 0.150 + dz * 0.85) for dx, dz in ngon_yz(0.020, 8, rot=math.pi / 8)]])
finish(to_obj("TS_SelectorHub", bm, C["Receiver"], "Metal"), w=0.0)
bm = profile("Selector", [(0.070, 0.142), (0.150, 0.118), (0.172, 0.124), (0.150, 0.136), (0.088, 0.160)], 0.004, M, "Panel",
	yc=HW - 0.009 + 0.012)
finish(to_obj("TS_SelectorLever", bm, C["Receiver"], "Panel"), w=0.0)

# ================= STOCK DETAIL =================
for s in (1, -1):
	bp = [(-1.232, 0.372), (-1.150, 0.360), (-1.128, 0.300), (-1.132, -0.030), (-1.160, -0.120), (-1.232, -0.140)]
	bm = profile("ButtPlate", poly_offset(bp, -0.012), 0.003, M, "Panel", yc=s * (0.066 + 0.0026))
	finish(to_obj("TS_ButtPlate%+d" % s, bm, C["Plates"], "Panel"), w=0.0)
	# strut silver edge
	sp = band([(-0.30, 0.140), (-1.08, -0.040)], 0.016)
	bm = profile("StrutPlate", sp, 0.0025, M, "Panel", yc=s * (SW * 0.9 + 0.0022))
	finish(to_obj("TS_StrutPlate%+d" % s, bm, C["Plates"], "Panel"), w=0.0)

objs = list(M.all_objects)
result = {"objects": len(objs), "tris": tris(objs)}
