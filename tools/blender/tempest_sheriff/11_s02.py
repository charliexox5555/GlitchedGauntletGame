# Tempest-Strike Sheriff s02 (on s01): raked trapezoid trigger guard (legs lean in, silver spur), six grip bands from
# under the frame down to the pommel cap, side plates reshaped into raked blades (recess recut to match).
import bpy
GUN = "Sheriff"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/Skins/TempestStrike/Sheriff/s01/Sheriff_TempestStrike_s01.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
purge(("TS2_",))
for n in ("TS_GuardRear", "TS_GuardBottom", "TS_GuardFront", "TS_GuardSpur"):
	kill(n)
new_obj("TS_GuardRear", bar((0.248, 0.012), (0.290, -0.206), 0.020, 0.012, 0.6), "Body")
new_obj("TS_GuardBottom", bar((0.280, -0.200), (0.556, -0.212), 0.020, 0.012, 0.6), "Body")
new_obj("TS_GuardFront", bar((0.544, -0.216), (0.604, 0.012), 0.020, 0.012, 0.6), "Body")
new_obj("TS_GuardSpur", prism_xz([(0.320, -0.2195), (0.530, -0.2245), (0.592, -0.2190), (0.530, -0.2175), (0.320, -0.2125)], -0.015, 0.015), "Panel", bevel=0)

# grip: six bands
GS = [(-0.392, 0.056, -0.236, 0.060), (-0.360, 0.079, -0.258, 0.066), (-0.200, 0.080, -0.234, 0.066), (0.000, 0.148, -0.174, 0.066),
	(0.090, 0.090, -0.150, 0.064), (0.175, 0.020, -0.100, 0.056)]
def gs_at(z):
	if z <= GS[0][0]:
		return GS[0][1:]
	for a, b in zip(GS[:-1], GS[1:]):
		if a[0] <= z <= b[0]:
			t = (z - a[0]) / (b[0] - a[0])
			return tuple(a[i] + (b[i] - a[i]) * t for i in (1, 2, 3))
	return GS[-1][1:]
def grip_sec(z, grow=0.0):
	fx, bx, hw = gs_at(z)
	return sec_grow([(fx, -hw * 0.40), (fx, hw * 0.40), (fx - 0.034, hw), (bx + 0.030, hw), (bx, hw * 0.55), (bx, -hw * 0.55), (bx + 0.030, -hw), (fx - 0.034, -hw)], grow)
def ring_z(secf, z0, tilt=0.0, grow=0.0):
	n = len(secf(z0)); out = []
	for i in range(n):
		z = z0
		for _ in range(3):
			x = secf(z, grow)[i][0]; z = z0 + tilt * x
		x, y = secf(z, grow)[i]
		out.append((x, y, z))
	return out
for i in range(4):
	kill("TS_GripWrap%d" % i); kill("TS_GripHydro%d" % i)
for i in range(6):
	z0 = 0.085 - i * 0.068; z1 = z0 - 0.056
	# four segments so the band follows the grip's front bulge at z 0 (two rings let the core poke through)
	new_obj("TS_GripWrap%d" % i, loft([ring_z(grip_sec, z1 + (z0 - z1) * k / 4, 0.22, 0.0040 + 0.0018 * k / 4) for k in range(5)]), "Grip", like="Sheriff_Grip", bevel=0)
	if i < 5:
		new_obj("TS_GripHydro%d" % i, loft([ring_z(grip_sec, z1 - 0.0088, 0.22, 0.0020), ring_z(grip_sec, z1 - 0.0038, 0.22, 0.0020)]), "Neon", like="Sheriff_Grip", bevel=0)

# pommel cap: follows the grip's kink at z -0.36 (a straight loft let the core touch the cap: audit coplanar)
kill("TS_GripCap")
cap = [[(x, y, z) for x, y in grip_sec(z, g)] for z, g in ((-0.346, 0.0070), (-0.360, 0.0070), (-0.392, 0.0040))]   # fuller than the bands (0.0058): the lowest band tucks under it
_c = grip_sec(-0.392, 0.0); _cx = sum(p[0] for p in _c) / len(_c)
cap.append([(_cx + (x - _cx) * 0.84 - (0.024 if x < _cx - 0.06 else 0.0), y * 0.74, -0.420) for x, y in _c])
new_obj("TS_GripCap", loft(cap), "Panel", like="Sheriff_Grip")

# side plates: raked blades
fr = bpy.data.objects["TS_Frame"]
for m in list(fr.modifiers):
	if m.type == "BOOLEAN" and m.object and m.object.name.startswith("TS_CUT_Recess"):
		c = m.object; fr.modifiers.remove(m); bpy.data.objects.remove(c, do_unlink=True)
PLATE = [(0.000, 0.170), (0.050, 0.140), (0.250, 0.140), (0.312, 0.178), (0.262, 0.232), (0.092, 0.232), (0.050, 0.205)]   # inside the frame outline (rear tang top rises from z 0.203 at x 0)
for s in (1, -1):
	kill("TS_SidePlate%+d" % s)
	y0, y1 = (0.058, 0.080) if s > 0 else (-0.080, -0.058)
	boolean(fr, cutter("TS2_CUT_Recess%+d" % s, prism_xz(poly_offset(PLATE, 0.003), y0, y1)))
	y0, y1 = (0.0575, 0.0675) if s > 0 else (-0.0675, -0.0575)
	new_obj("TS_SidePlate%+d" % s, chamfer_prism_xz(PLATE, y0, y1, 0.0014), "Panel", bevel=0)
bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model())}
