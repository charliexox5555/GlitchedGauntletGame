"""Snowpeak4 character props (2026-11-21, owner playtest: "more character"; "the skis are placeholder bricks").
Modelled with the snowcat's hard-surface helpers (snowcat_model.py: cube / prism / bar / cyl, bevel modifiers, baked
with smooth faces and sharp edges). Pieces (Map_<Piece>, part of the Snowpeak4 Kit export):

  SkiRack    a timber rack (two splayed trestles, a notched top bar, a foot rail) with four pairs of modelled skis
             (tapered bodies, curled tips, tail kick, toe and heel bindings, a top sheet stripe) and two pairs of poles
             (grips, straps, baskets). 9 long (X), front +Y.
  Sled       a wooden toboggan: three slats on two runners curling up into a rolled front, cross bars, a rope rail.
  LampPost   a lantern post: stepped plinth, fluted 8-sided shaft, collars, a cross arm, a four-pane lantern with a lit
             core (parts named *LampGlow* are made Neon in Roblox), a pyramid cap and finial. 9.6 tall.
  TrailSign  a timber post with three arrow boards and the ski-run icons on them (green circle, blue square, black
             diamond): icons only, no text.
  Bench      a timber bench (seat slats, back slats) on two timber trestles, snow on the seat and the back rail.
  FirePit    a ring of stones round a log stack and faceted flames (*LampGlow*), ash bed.
Units: studs; +X right, +Y front (Roblox -Z), +Z up; origin = bottom centre. Our own designs.
"""
from math import cos, pi, radians, sin

import bmesh
import bpy
from mathutils import Vector

import arena_kit as A
import snowcat_model as SC

cube, prism, bar, cyl, bevel, new_obj, ngon2 = SC.cube, SC.prism, SC.bar, SC.cyl, SC.bevel, SC.new_obj, SC.ngon2

A.PAL.update(
	{
		"SP_Wood": ("#8A5E3C", 0.8),
		"SP_WoodDark": ("#5A3C28", 0.8),
		"SP_WoodLight": ("#A8805A", 0.8),
		"SP_Iron": ("#2E3135", 0.5),
		"SP_Steel": ("#8E949B", 0.4),
		"SP_SkiRed": ("#B02A30", 0.4),
		"SP_SkiBlue": ("#2F5D8A", 0.4),
		"SP_SkiYellow": ("#D6A93A", 0.4),
		"SP_SkiWhite": ("#E8E4DA", 0.4),
		"SP_Black": ("#222326", 0.6),
		"SP_LampGlow": ("#E0A85A", 0.4),
		"SP_FireGlow": ("#E0702C", 0.4),
		"SP_Green": ("#3E8A4A", 0.5),
		"SP_Blue": ("#2F5D8A", 0.5),
		"SP_Snow": ("#E4EBF2", 0.9),
		"SP_Stone": ("#8A8478", 0.9),
		"SP_Ash": ("#3A3633", 0.9),
		"SP_Rope": ("#B49A6A", 0.9),
		"SP_Bark": ("#4A3526", 0.9),
		"SP_Char": ("#26211D", 0.9),
	}
)
RBX = {"SP_Snow": "Snow", "SP_LampGlow": "Neon", "SP_FireGlow": "Neon", "SP_Stone": "Slate"}


def _loft_path(bm, pts, w, t, mi):
	"""A flat strip of width w (X) and thickness t following a path of (y, z) points in the YZ plane."""
	rings = []
	for i, (y, z) in enumerate(pts):
		a = pts[max(i - 1, 0)]
		b = pts[min(i + 1, len(pts) - 1)]
		d = Vector((0, b[0] - a[0], b[1] - a[1])).normalized()
		n = Vector((0, -d.z, d.y))  # the strip's up normal in YZ
		c = Vector((0, y, z))
		rings.append([c + Vector((-w / 2, 0, 0)) - n * t / 2, c + Vector((w / 2, 0, 0)) - n * t / 2, c + Vector((w / 2, 0, 0)) + n * t / 2, c + Vector((-w / 2, 0, 0)) + n * t / 2])
	vs = [[bm.verts.new(p) for p in r] for r in rings]
	fs = [bm.faces.new(list(reversed(vs[0]))), bm.faces.new(vs[-1])]
	for r0, r1 in zip(vs, vs[1:]):
		for i in range(4):
			fs.append(bm.faces.new((r0[i], r0[(i + 1) % 4], r1[(i + 1) % 4], r1[i])))
	for f in fs:
		f.material_index = mi
	return vs


def _ski_path(L):
	"""(y, z) along a ski standing on its tail at y=0: body, then the tip curls forward (+Y side is the base)."""
	pts = [(0.0, 0.0), (0.0, 0.25)]
	pts += [(0.0, L * k / 6) for k in range(1, 6)]
	pts += [(0.06, L * 0.9), (0.16, L * 0.96), (0.32, L * 1.0)]
	return pts


def ski_rack(coll):
	bm = bmesh.new()
	W, WD, ST, IR = 0, 1, 2, 3
	# trestles: splayed legs at each end, a cross brace
	for x in (-4.3, 4.3):
		bar(bm, (x, -0.9, 0.0), (x, 0.0, 3.2), 0.28, 0.28, WD)
		bar(bm, (x, 0.9, 0.0), (x, 0.0, 3.2), 0.28, 0.28, WD)
		bar(bm, (x, -0.55, 1.0), (x, 0.55, 1.0), 0.2, 0.22, WD)
	# the notched top bar (a bar with slot blocks), the foot rail the tails rest against
	cube(bm, -4.6, 4.6, -0.16, 0.16, 3.05, 3.35, W)
	for k in range(9):
		x = -3.6 + k * 0.9
		cube(bm, x - 0.06, x + 0.06, 0.12, 0.34, 3.05, 3.42, WD)
	cube(bm, -4.5, 4.5, 0.55, 0.85, 0.08, 0.36, W)
	o = new_obj("SkiRack_Frame", bm, ["SP_Wood", "SP_WoodDark", "SP_Steel", "SP_Iron"], coll)
	bevel(o, 0.03, 2, 40)
	parts = [o]
	# skis: pairs leaning on the top bar (tails on the snow in front of the foot rail)
	cols = ["SP_SkiRed", "SP_SkiBlue", "SP_SkiYellow", "SP_SkiWhite"]
	lean = radians(13)
	for i, x in enumerate((-3.15, -1.35, 0.45, 2.25)):
		bm = bmesh.new()
		for dx in (-0.22, 0.22):
			vs = _loft_path(bm, _ski_path(4.8), 0.34, 0.07, 0)
			for r in vs:
				for v in r:
					v.co.x += x + dx
			# bindings (toe and heel) and a top sheet stripe
			# on the top sheet (+Y, facing out from the rack): toe and heel bindings, a stripe
			cube(bm, x + dx - 0.15, x + dx + 0.15, 0.035, 0.16, 1.55, 1.9, 1)
			cube(bm, x + dx - 0.13, x + dx + 0.13, 0.035, 0.15, 2.35, 2.62, 1)
			cube(bm, x + dx - 0.06, x + dx + 0.06, 0.034, 0.06, 0.4, 4.2, 2)
		ob = new_obj(f"SkiRack_Skis{i}", bm, [cols[i], "SP_Black", "SP_SkiWhite" if cols[i] != "SP_SkiWhite" else "SP_SkiRed"], coll)
		bevel(ob, 0.015, 1, 40)
		# stand them up leaning back onto the top bar: tilted about X so the tops go toward -Y (the bar), the backs
		# rest on the bar's front face (y 0.16) between the notches, the tails on the snow at the foot rail
		ob.rotation_euler = (lean, 0, 0)
		ob.location = (0, 0.915, 0.0)
		parts.append(ob)
	# poles: two pairs leaning at the right end
	bm = bmesh.new()
	for x in (3.55, 3.85, 4.05):
		top, base = Vector((x, 0.05, 3.9)), Vector((x + 0.05, 0.95, 0.0))  # leaning on the bar's front face
		cyl(bm, base, top, 0.045, 8, 0)
		d = (top - base).normalized()
		cyl(bm, top - d * 0.6, top + d * 0.05, 0.09, 8, 1)  # grip
		cyl(bm, base + d * 0.35, base + d * 0.4, 0.26, 8, 1)  # basket
	ob = new_obj("SkiRack_Poles", bm, ["SP_Steel", "SP_Black"], coll)
	parts.append(ob)
	return parts


def sled(coll):
	bm = bmesh.new()
	# the rolled front: slats run along Y and curl up at +Y
	path = [(-2.6, 0.32), (1.2, 0.32), (1.7, 0.35), (2.1, 0.46), (2.4, 0.66), (2.58, 0.92), (2.62, 1.18), (2.52, 1.4), (2.34, 1.5)]
	for x in (-0.5, 0.0, 0.5):
		vs = _loft_path(bm, path, 0.44, 0.07, 0)
		for r in vs:
			for v in r:
				v.co.x += x
	for x in (-0.6, 0.6):  # runners
		vs = _loft_path(bm, [(-2.5, 0.05), (1.4, 0.05), (2.0, 0.18), (2.35, 0.45)], 0.12, 0.1, 1)
		for r in vs:
			for v in r:
				v.co.x += x
	for y in (-2.0, -0.6, 0.8):  # cross bars under the slats, posts to the runners
		cube(bm, -0.7, 0.7, y - 0.12, y + 0.12, 0.17, 0.27, 1)
		for x in (-0.6, 0.6):
			cube(bm, x - 0.05, x + 0.05, y - 0.05, y + 0.05, 0.08, 0.2, 1)
	for x in (-0.78, 0.78):  # rope rails
		bar(bm, (x, -2.3, 0.55), (x, 1.5, 0.55), 0.06, 0.06, 2)
		for y in (-2.3, -0.3, 1.5):
			bar(bm, (x, y, 0.32), (x, y, 0.55), 0.05, 0.05, 2)
	o = new_obj("Sled", bm, ["SP_WoodLight", "SP_WoodDark", "SP_Rope"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


def lamp_post(coll):
	bm = bmesh.new()
	IRON, GLOW = 0, 1
	prism(bm, ngon2(0, 0, 0.62, 8, pi / 8), "z", 0.0, 0.35, IRON)
	prism(bm, ngon2(0, 0, 0.48, 8, pi / 8), "z", 0.35, 0.8, IRON)
	# fluted shaft: an 8-sided taper with a collar every 2.5
	sh = bm
	M = [ngon2(0, 0, 0.26, 8, pi / 8), ngon2(0, 0, 0.18, 8, pi / 8)]
	r0 = [bm.verts.new((x, y, 0.8)) for x, y in M[0]]
	r1 = [bm.verts.new((x, y, 7.6)) for x, y in M[1]]
	fs = [bm.faces.new(list(reversed(r0))), bm.faces.new(r1)]
	for i in range(8):
		fs.append(bm.faces.new((r0[i], r0[(i + 1) % 8], r1[(i + 1) % 8], r1[i])))
	for f in fs:
		f.material_index = IRON
	for z in (2.2, 4.6, 7.4):
		prism(bm, ngon2(0, 0, 0.33 - z * 0.012, 8, pi / 8), "z", z, z + 0.22, IRON)
	# lantern: base, four corner posts, lit core, roof pyramid, finial
	prism(bm, ngon2(0, 0, 0.55, 4, pi / 4), "z", 7.6, 7.8, IRON)
	for k in range(4):
		a = pi / 4 + k * pi / 2
		bar(bm, (0.42 * cos(a), 0.42 * sin(a), 7.8), (0.48 * cos(a), 0.48 * sin(a), 8.8), 0.08, 0.08, IRON)
	prism(bm, ngon2(0, 0, 0.36, 4, pi / 4), "z", 7.85, 8.75, GLOW)
	r0 = [bm.verts.new((x, y, 8.8)) for x, y in ngon2(0, 0, 0.72, 4, pi / 4)]
	top = bm.verts.new((0, 0, 9.35))
	bm.faces.new(list(reversed(r0))).material_index = IRON
	for i in range(4):
		bm.faces.new((r0[i], r0[(i + 1) % 4], top)).material_index = IRON
	prism(bm, ngon2(0, 0, 0.06, 6), "z", 9.3, 9.6, IRON)
	o = new_obj("LampPost", bm, ["SP_Iron", "SP_LampGlow"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


def trail_sign(coll):
	bm = bmesh.new()
	WD, W, G, B, K, WH = 0, 1, 2, 3, 4, 5
	cube(bm, -0.22, 0.22, -0.22, 0.22, -0.5, 7.4, WD)
	prism(bm, [(-0.3, -0.3), (0.3, -0.3), (0.3, 0.3), (-0.3, 0.3)], "z", 7.4, 7.55, WD)
	boards = [(6.4, 1, G), (5.3, -1, B), (4.2, 1, K)]
	for z, side, icon in boards:
		# an arrow board: a plank with a pointed end, standing on the post's front face
		x0, x1 = (0.2, 2.8) if side > 0 else (-2.8, -0.2)
		tip = x1 + 0.45 if side > 0 else x0 - 0.45
		poly = [(x0, z - 0.4), (x1, z - 0.4), (tip, z), (x1, z + 0.4), (x0, z + 0.4)] if side > 0 else [(x0, z), (x0 + 0.45, z - 0.4), (x1, z - 0.4), (x1, z + 0.4), (x0 + 0.45, z + 0.4)]
		if side < 0:
			poly = [(tip, z), (x0, z - 0.4), (x1, z - 0.4), (x1, z + 0.4), (x0, z + 0.4)]
		# prism in XZ along Y (the board's thickness)
		r0 = [bm.verts.new((x, 0.22, zz)) for x, zz in poly]
		r1 = [bm.verts.new((x, 0.36, zz)) for x, zz in poly]
		n = len(poly)
		fs = [bm.faces.new(r0), bm.faces.new(list(reversed(r1)))]
		for i in range(n):
			fs.append(bm.faces.new((r0[i], r1[i], r1[(i + 1) % n], r0[(i + 1) % n])))
		for f in fs:
			f.material_index = W
		cx = (x0 + x1) / 2
		# the run icon on a white disc / plate
		if icon == G:
			ic = ngon2(cx, z, 0.27, 12)
		elif icon == B:
			ic = [(cx - 0.24, z - 0.24), (cx + 0.24, z - 0.24), (cx + 0.24, z + 0.24), (cx - 0.24, z + 0.24)]
		else:
			ic = [(cx, z - 0.32), (cx + 0.3, z), (cx, z + 0.32), (cx - 0.3, z)]
		r0 = [bm.verts.new((x, 0.36, zz)) for x, zz in ic]
		r1 = [bm.verts.new((x, 0.42, zz)) for x, zz in ic]
		n = len(ic)
		fs = [bm.faces.new(r0), bm.faces.new(list(reversed(r1)))]
		for i in range(n):
			fs.append(bm.faces.new((r0[i], r1[i], r1[(i + 1) % n], r0[(i + 1) % n])))
		for f in fs:
			f.material_index = icon
	o = new_obj("TrailSign", bm, ["SP_WoodDark", "SP_WoodLight", "SP_Green", "SP_Blue", "SP_Black", "SP_SkiWhite"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


def bench(coll):
	bm = bmesh.new()
	W, WD, SN = 0, 1, 2
	for x in (-2.5, 2.5):  # trestles: two legs, a seat bearer, a back post
		bar(bm, (x, -0.7, 0.0), (x, -0.45, 1.5), 0.22, 0.22, WD)
		bar(bm, (x, 0.6, 0.0), (x, 0.45, 1.5), 0.22, 0.22, WD)
		cube(bm, x - 0.12, x + 0.12, -0.75, 0.75, 1.3, 1.5, WD)
		bar(bm, (x, 0.55, 1.5), (x, 0.8, 3.1), 0.2, 0.2, WD)
	for y in (-0.5, 0.0, 0.5):
		cube(bm, -3.0, 3.0, y - 0.2, y + 0.2, 1.5, 1.68, W)
	for z in (2.1, 2.65):
		cube(bm, -2.9, 2.9, 0.62, 0.86, z - 0.17, z + 0.17, W)
	cube(bm, -2.95, 2.95, 0.66, 0.92, 3.0, 3.18, WD)
	# snow: a soft layer on the seat (set back from the front edge) and on the back rail
	cube(bm, -2.7, 2.6, -0.45, 0.55, 1.68, 1.88, SN)
	cube(bm, -2.8, 2.8, 0.68, 0.9, 3.18, 3.33, SN)
	o = new_obj("Bench", bm, ["SP_Wood", "SP_WoodDark", "SP_Snow"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


def fire_pit(coll):
	"""v2 (owner 2026-11-21: v1 "not high enough quality and parts do not align"). Everything sits on something:
	a ring of 14 field stones packed shoulder to shoulder and half buried, snow on their tops; an ash bed sunk into
	the snow inside the ring (its edge under the stones); six bark logs in a teepee whose feet stand on the ash and
	whose tops cross just above the apex, cut ends showing light wood; two charred logs lying under the teepee and a
	bed of glowing embers. The flames are a fire ParticleEmitter in Roblox (the *Glow* embers carry it)."""
	from mathutils import Matrix, noise

	bm = bmesh.new()
	ST, BARK, END, EMBER, ASH, SNOW, CHAR = 0, 1, 2, 3, 4, 5, 6
	# ash bed: a 16-sided disc from just under the snow to 0.06 (no face on the snow plane)
	prism(bm, ngon2(0, 0, 1.75, 16, pi / 16), "z", -0.05, 0.06, ASH)
	# stones: noise-shaped, flat bottoms buried 0.12, tangentially long so neighbours touch
	n = 14
	for k in range(n):
		a2 = k * 2 * pi / n + 0.08 * ((k * 7) % 3 - 1)
		r = 1.9
		c = Vector((r * cos(a2), r * sin(a2), 0.16))
		sx, sy, sz = 0.42 + 0.05 * (k % 3), 0.34 + 0.03 * ((k + 1) % 2), 0.3 + 0.05 * ((k + 2) % 3)
		mtx = Matrix.Translation(c) @ Matrix.Rotation(a2 + pi / 2, 4, "Z") @ Matrix.Diagonal((sx, sy, sz, 1.0))
		res = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0, matrix=mtx)
		off = Vector((k * 3.1, k * 1.7, 0.5))
		vs = res["verts"]
		for v in vs:
			d = (v.co - c).normalized()
			v.co += d * 0.07 * noise.fractal(v.co * 2.6 + off, 0.5, 2.0, 2)
			if v.co.z < -0.12:
				v.co.z = -0.12
			elif v.co.z > c.z + sz * 0.8:
				v.co.z = c.z + sz * 0.8 + (v.co.z - c.z - sz * 0.8) * 0.4  # a flatter top
		bm.normal_update()
		for f in {f for v in vs for f in v.link_faces}:
			f.material_index = SNOW if (f.normal.z > 0.75 and f.calc_center_median().z > c.z + sz * 0.45) else ST
	# teepee logs: feet on the ash at radius 1.0, tops crossing above the apex
	def log(p0, p1, rad, mi_bark, mi_end):
		p0, p1 = Vector(p0), Vector(p1)
		cyl(bm, p0, p1, rad, 12, mi_bark)
		d = (p1 - p0).normalized()
		cyl(bm, p1 - d * 0.01, p1 + d * 0.025, rad * 0.86, 12, mi_end)  # the cut end
		cyl(bm, p0 - d * 0.025, p0 + d * 0.01, rad * 0.86, 12, mi_end)

	apex = Vector((0, 0, 1.55))
	for k in range(6):
		a2 = k * 2 * pi / 6 + 0.25
		foot = Vector((1.0 * cos(a2), 1.0 * sin(a2), 0.06 + 0.1))
		d = (apex - foot).normalized()
		top = apex + d * 0.14
		log(foot - d * 0.12, top, 0.12, BARK, END)
	# charred logs lying across under the teepee, and the ember bed
	log((-0.75, -0.2, 0.17), (0.75, 0.15, 0.17), 0.11, CHAR, CHAR)
	log((-0.2, -0.7, 0.2), (0.25, 0.7, 0.2), 0.1, CHAR, CHAR)
	for k in range(9):
		a2 = k * 2 * pi / 9
		rr = 0.25 + 0.3 * (k % 3) / 2
		c = Vector((rr * cos(a2), rr * sin(a2), 0.08))
		mtx = Matrix.Translation(c) @ Matrix.Diagonal((0.16, 0.12, 0.08, 1.0))
		res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0, matrix=mtx)
		for f in {f for v in res["verts"] for f in v.link_faces}:
			f.material_index = EMBER
	o = new_obj("FirePit", bm, ["SP_Stone", "SP_Bark", "SP_WoodLight", "SP_FireGlow", "SP_Ash", "SP_Snow", "SP_Char"], coll)
	return [o]


PIECES = ("SkiRack", "Sled", "LampPost", "TrailSign", "Bench", "FirePit")


def build(C):
	out = []
	out += SC.finalize(ski_rack(C("SkiRack")), bpy.data.collections["Map_SkiRack"])
	out += SC.finalize(sled(C("Sled")), bpy.data.collections["Map_Sled"])
	out += SC.finalize(lamp_post(C("LampPost")), bpy.data.collections["Map_LampPost"])
	out += SC.finalize(trail_sign(C("TrailSign")), bpy.data.collections["Map_TrailSign"])
	out += SC.finalize(bench(C("Bench")), bpy.data.collections["Map_Bench"])
	out += SC.finalize(fire_pit(C("FirePit")), bpy.data.collections["Map_FirePit"])
	for nm, (hx, _r) in A.PAL.items():
		m = bpy.data.materials.get(nm)
		if m is not None and nm.startswith("SP_"):
			m["rbx_material"] = RBX.get(nm, "SmoothPlastic")
			m["rbx_color"] = hx.lstrip("#").upper()
	return out
