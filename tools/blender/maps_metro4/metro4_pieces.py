"""Metro4 v3 + shared prop kit (2026-11-20, owner notes on Metro v2 and Wharf v2).

    python tools/blender/lobby_v4/send.py tools/blender/maps_metro4/run_metro4.py --port 9897 --pid <pid>

Two export groups (tools/blender/export_lobby_kit.py):
  --maps Props  Kit  PROPS   shared dressing for Wharf and Metro4 (and later maps):
      CrateA_<h> / CrateB_<h>   5 x 5 timber crates, h = 35 / 425 / 5 / 6 (3.5, 4.25, 5, 6 studs): skids, planked
                                core with V-grooves, a lid of planks recessed in the frame, corner posts, rails;
                                A has a diagonal brace per face, B a middle rail and steel corner brackets
      Vending                   2.9 x 3 x 9 drinks machine: plinth, glass window with stocked shelves, button panel,
                                lit header, dispenser flap, cap. Parts named *Paint* take the side's colour
      LuggageCart               10 x 5 platform cart: frame, deck, swivel casters, push handle, five suitcases
      Pallet                    3.6 x 3.8 x 0.6 timber pallet (boards, blocks, stringers, gapped deck)
      Barrier                   3.7 x 1.6 x 2.2 concrete safety barrier (stepped profile, yellow band, forklift slots)
  --maps Metro4 Kit  METRO   the train and the gates:
      Bogie        a two-axle bogie: side frames with a dropped centre, axle boxes, faceted wheels with flanges
                   sitting on the rails, axles, brake blocks, a bolster that carries the body floor, a motor box
      CabFront     the driving end of a car: a raked faceted nose that meets the Parts body (joint plane x = 0),
                   framed windscreen with a display band and a wiper, headlights, a paint band, anti-climber,
                   skirt and coupler
      TicketGate   a gate cabinet with a sloped console in the side's paint, reader, side panels
      GatePaddles  the pair of glass leaves between two cabinets
Rules (gauntlet-build-style): no round shapes (wheels and posts are 8 / 12-sided flat-shaded prisms), every edge
bevelled or carved, members end in joints, flat shading. Blender units = studs; +X east, +Y north, +Z up;
Roblox = (x, z, -y), so a piece's "front" toward Roblox -Z is Blender +Y. Origin = bottom centre unless noted.
Our own designs (nothing taken from RIVALS).
"""
from math import cos, pi, sin, sqrt
import random

import arena_kit as A
import bmesh
from mathutils import Vector

ROOT = "Metro4Kit"

A.PAL.update(
	{
		# timber (matches the maps' plank colours), steel fittings
		"P_Wood": ("#A98762", 0.8),
		"P_WoodDark": ("#7E6447", 0.8),
		"P_Metal": ("#4B5058", 0.6),
		"B_Concrete": ("#B5AFA3", 0.9),
		"B_Band": ("#D9A73E", 0.6),
		"B_Dark": ("#4A4740", 0.9),
		# vending (Paint is recoloured per side in Roblox)
		"V_Paint": ("#9C4A3F", 0.6),
		"V_Trim": ("#3D3B38", 0.6),
		"V_Glass": ("#2B323C", 0.3),
		"V_Light": ("#E6DFC9", 0.5),
		"V_Panel": ("#5A5752", 0.6),
		"V_GoodsA": ("#B85A45", 0.6),
		"V_GoodsB": ("#C9A54E", 0.6),
		"V_GoodsC": ("#5B83A6", 0.6),
		# luggage
		"L_Case1": ("#8C4A3F", 0.7),
		"L_Case2": ("#A88A4E", 0.7),
		"L_Case3": ("#4A6E9A", 0.7),
		"L_Case4": ("#6E6A62", 0.7),
		# planting
		"H_Leaf": ("#5E7F4C", 0.9),
		"H_LeafDark": ("#4C6A3E", 0.9),
		"H_Bark": ("#6B5440", 0.9),
		# train
		"T_Body": ("#C4C8C6", 0.6),
		"T_Steel": ("#3D4046", 0.6),
		"T_Wheel": ("#5C5F64", 0.5),
		"T_Rubber": ("#2B2D31", 0.8),
		"T_Glass": ("#2B323C", 0.3),
		"T_Lamp": ("#E9E4D2", 0.4),
		"T_Paint": ("#4A6E9A", 0.6),
		# gates
		"G_Steel": ("#A7A9A8", 0.5),
		"G_Dark": ("#3D3B38", 0.6),
		"G_Paint": ("#4A6E9A", 0.6),
		"G_Glass": ("#C3D3DB", 0.2),
	}
)
TRANSPARENT = {"V_Glass": 0.35, "G_Glass": 0.45}


# ------------------------------------------------------------------------------------------------ helpers
def bbox(M, mat, x0, x1, y0, y1, z0, z1, c=0.06, T=None):
	"""A box with every edge bevelled by c (one segment). T: optional Matrix applied before the bevel."""
	bm = M.bm
	idx = M._slot(mat)
	c = min(c, (x1 - x0) * 0.3, (y1 - y0) * 0.3, (z1 - z0) * 0.3)
	vs = []
	for z in (z0, z1):
		for y in (y0, y1):
			for x in (x0, x1):
				p = Vector((x, y, z))
				vs.append(bm.verts.new(T @ p if T is not None else p))
	F = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
	faces = [bm.faces.new([vs[i] for i in f]) for f in F]
	for f in faces:
		f.material_index = idx
	if c > 0.001:
		edges = list({e for f in faces for e in f.edges})
		res = bmesh.ops.bevel(bm, geom=edges, offset=c, segments=1, affect="EDGES", clamp_overlap=True)
		for f in res["faces"]:
			f.material_index = idx


def bar(M, mat, p0, p1, w, h, c=None, up=Vector((0, 0, 1))):
	"""A chamfered bar from p0 to p1: w across (perpendicular to `up`), h in the up-plane."""
	p0, p1 = Vector(p0), Vector(p1)
	d = (p1 - p0).normalized()
	if abs(d.dot(up)) > 0.95:
		up = Vector((1, 0, 0))
	s = d.cross(up).normalized()
	u = s.cross(d).normalized()
	c = min(w, h) * 0.18 if c is None else c
	sec = A.cham(-w / 2, w / 2, -h / 2, h / 2, c)
	M.loft([[tuple(p0 + s * a + u * b) for a, b in sec], [tuple(p1 + s * a + u * b) for a, b in sec]], mat)


def ngon(cx, cy, r, n, rot=0.0):
	return [(cx + r * cos(rot + 2 * pi * k / n), cy + r * sin(rot + 2 * pi * k / n)) for k in range(n)]


def disc_y(M, mat, cx, cz, r, n, y0, y1, rot=0.0):
	"""An n-sided prism whose axis runs along Y (wheels, hubs, axles)."""
	pts = ngon(cx, cz, r, n, rot)
	M.loft([[(x, y0, z) for x, z in pts], [(x, y1, z) for x, z in pts]], mat)


def extrude_x(M, mat, poly_yz, x0, x1):
	"""A prism along X from a polygon drawn in the YZ plane."""
	M.loft([[(x0, y, z) for y, z in poly_yz], [(x1, y, z) for y, z in poly_yz]], mat)


def finish(M):
	return M.finish()


# ------------------------------------------------------------------------------------------------ crates
CRATE_H = {"35": 3.5, "425": 4.25, "5": 5.0, "6": 6.0}


def crate(name, collection, H, style):
	M = A.Mesh(name, collection)
	W, WD, MT = A.mat("P_Wood"), A.mat("P_WoodDark"), A.mat("P_Metal")
	core, post, sk = 2.3, 0.55, 0.3
	o = 2.5 - post  # post inner face
	# two skids under the crate (it stands on them), ends carved
	for y in (-1.6, 1.6):
		bbox(M, WD, -2.45, 2.45, y - 0.35, y + 0.35, 0.0, sk + 0.02, 0.07)
	# planked core: stacked boards, their bevels read as V-grooves on every face
	z0, z1 = sk, H - 0.3
	n = max(2, round((z1 - z0) / 0.9))
	ph = (z1 - z0) / n
	for i in range(n):
		bbox(M, W, -core, core, -core, core, z0 + i * ph, z0 + (i + 1) * ph, 0.045)
	# lid boards, recessed inside the top rails
	for i in range(4):
		y0 = -core + i * (2 * core / 4)
		bbox(M, W, -core + 0.02, core - 0.02, y0 + 0.02, y0 + 2 * core / 4 - 0.02, H - 0.32, H - 0.1, 0.04)
	# corner posts
	for sx in (-1, 1):
		for sy in (-1, 1):
			xa, xb = (o, 2.5) if sx > 0 else (-2.5, -o)
			ya, yb = (o, 2.5) if sy > 0 else (-2.5, -o)
			bbox(M, WD, xa, xb, ya, yb, sk, H, 0.08)
	# rails on each face (0.04 behind the posts' faces), buried 0.05 into the posts at their ends
	rails = [(sk, sk + 0.5), (H - 0.5, H - 0.04)]
	if style == "B":
		mid = (sk + H) / 2
		rails.append((mid - 0.22, mid + 0.22))
	for s in (-1, 1):
		ya, yb = (core, 2.46) if s > 0 else (-2.46, -core)
		xa, xb = (core, 2.46) if s > 0 else (-2.46, -core)
		for ra, rb in rails:
			bbox(M, WD, -o - 0.05, o + 0.05, ya, yb, ra, rb, 0.06)  # +-Y faces, along X
			bbox(M, WD, xa, xb, -o - 0.05, o + 0.05, ra, rb, 0.06)  # +-X faces, along Y
		if style == "A":
			# one diagonal brace per face, alternating, ends buried in the posts / rails
			lo, hi = sk + 0.45, H - 0.45
			yc = s * (core + 0.07)
			a, b = (-o + 0.05, o - 0.05) if s > 0 else (o - 0.05, -o + 0.05)
			bar(M, WD, (a, yc, lo), (b, yc, hi), 0.14, 0.46, c=0.04, up=Vector((0, 1, 0)))
			xc = s * (core + 0.07)
			bar(M, WD, (xc, -a, lo), (xc, -b, hi), 0.14, 0.46, c=0.04, up=Vector((1, 0, 0)))
	if style == "B":
		# steel corner brackets (an L of two plates round each post, top and bottom)
		for sx in (-1, 1):
			for sy in (-1, 1):
				for za, zb in ((sk + 0.08, sk + 0.75), (H - 0.75, H - 0.08)):
					xa, xb = (2.5 - 0.95, 2.53) if sx > 0 else (-2.53, -2.5 + 0.95)
					ya, yb = (2.5 - 0.95, 2.53) if sy > 0 else (-2.53, -2.5 + 0.95)
					xs = (2.5, 2.53) if sx > 0 else (-2.53, -2.5)
					ys = (2.5, 2.53) if sy > 0 else (-2.53, -2.5)
					bbox(M, MT, xs[0], xs[1], ya, yb, za, zb, 0.0)
					bbox(M, MT, xa, xb, ys[0], ys[1], za, zb, 0.0)
	return finish(M)


# ------------------------------------------------------------------------------------------------ vending
def vending(name, collection):
	"""Front = +Y (Roblox -Z). 2.9 wide, 3 deep, 9 tall."""
	M = A.Mesh(name, collection)
	P, Tr, Gl, Li, Pa = (A.mat(k) for k in ("V_Paint", "V_Trim", "V_Glass", "V_Light", "V_Panel"))
	goods = [A.mat(k) for k in ("V_GoodsA", "V_GoodsB", "V_GoodsC")]
	bbox(M, Tr, -1.35, 1.35, -1.4, 1.3, 0.0, 0.52, 0.06)  # recessed plinth
	bbox(M, P, -1.45, 1.45, -1.5, 1.22, 0.5, 8.6, 0.1)  # body
	# front frame (proud to y 1.5)
	bbox(M, P, -1.45, 1.45, 1.2, 1.5, 0.5, 2.9, 0.08)  # lower block (dispenser)
	bbox(M, P, -1.45, 1.45, 1.2, 1.5, 7.2, 8.6, 0.08)  # head block
	bbox(M, P, -1.45, -1.2, 1.2, 1.5, 2.86, 7.24, 0.05)  # left stile
	bbox(M, P, 0.5, 0.78, 1.2, 1.5, 2.86, 7.24, 0.05)  # divider
	bbox(M, P, 1.3, 1.45, 1.2, 1.5, 2.86, 7.24, 0.04)  # right stile
	# window: glass set back 0.12 behind the frame, stocked shelves behind it
	bbox(M, Gl, -1.22, 0.52, 1.3, 1.38, 2.88, 7.22, 0.0)
	for i, z in enumerate((3.0, 4.05, 5.1, 6.15)):
		bbox(M, Tr, -1.2, 0.5, 0.2, 1.28, z - 0.08, z, 0.0)  # shelf
		for j in range(4):
			x = -1.0 + j * 0.42
			hgt = 0.62 if (i + j) % 2 else 0.74
			bbox(M, goods[(i + j) % 3], x - 0.15, x + 0.15, 0.7, 1.05, z, z + hgt, 0.04)
	# button panel
	bbox(M, Pa, 0.76, 1.32, 1.24, 1.46, 2.86, 7.24, 0.04)
	for r in range(5):
		for cc in range(2):
			x = 0.9 + cc * 0.28
			z = 6.6 - r * 0.42
			bbox(M, Li, x - 0.09, x + 0.09, 1.44, 1.5, z - 0.12, z + 0.12, 0.02)
	bbox(M, Tr, 0.86, 1.22, 1.44, 1.52, 3.7, 4.3, 0.03)  # coin / card slot plate
	bbox(M, P, 0.95, 1.13, 1.5, 1.55, 3.85, 4.15, 0.0)
	# lit header and dispenser flap
	bbox(M, Li, -1.25, 1.25, 1.48, 1.56, 7.55, 8.3, 0.04)
	bbox(M, Tr, -1.0, 0.5, 1.48, 1.56, 0.95, 2.15, 0.05)
	bbox(M, Pa, -0.85, 0.35, 1.52, 1.6, 1.6, 1.85, 0.02)  # flap handle
	# cap
	bbox(M, Tr, -1.52, 1.52, -1.57, 1.58, 8.6, 9.0, 0.08)
	return finish(M)


# ------------------------------------------------------------------------------------------------ luggage cart
def pallet(name, collection):
	"""A 3.6 (X) x 3.8 (Y) x 0.6 timber pallet: three bottom boards, nine blocks, three stringer boards, seven deck
	boards across them with gaps (the Wharf stacks them two high)."""
	M = A.Mesh(name, collection)
	W, WD = A.mat("P_Wood"), A.mat("P_WoodDark")
	for y in (-1.6, 0.0, 1.6):
		bbox(M, W, -1.8, 1.8, y - 0.27, y + 0.27, 0.0, 0.1, 0.025)  # bottom board
		for x in (-1.5, 0.0, 1.5):
			bbox(M, WD, x - 0.26, x + 0.26, y - 0.24, y + 0.24, 0.09, 0.41, 0.04)  # block
		bbox(M, WD, -1.8, 1.8, y - 0.26, y + 0.26, 0.4, 0.49, 0.025)  # stringer board
	for i in range(7):
		x = -1.8 + 0.21 + i * (3.18 / 6)
		bbox(M, W, x - 0.21, x + 0.21, -1.9, 1.9, 0.48, 0.6, 0.03)  # deck board
	return finish(M)


def barrier(name, collection):
	"""A 3.7-long (X) concrete safety barrier, 1.6 wide at the foot, 2.2 tall: the stepped safety profile (a short
	upright toe, a steep lower slope, a long upper slope to a narrow chamfered top), a yellow band on both slopes,
	two forklift slots at the foot, end faces chamfered."""
	M = A.Mesh(name, collection)
	Cn, Bd, Dk = A.mat("B_Concrete"), A.mat("B_Band"), A.mat("B_Dark")
	prof = [(-0.8, 0.0), (0.8, 0.0), (0.8, 0.25), (0.55, 0.75), (0.25, 2.08), (0.16, 2.2), (-0.16, 2.2), (-0.25, 2.08), (-0.55, 0.75), (-0.8, 0.25)]
	inset = [(y * 0.9, z * 0.985 + 0.015) for y, z in prof]
	M.loft(
		[[(-1.85, y, z) for y, z in inset], [(-1.75, y, z) for y, z in prof], [(1.75, y, z) for y, z in prof], [(1.85, y, z) for y, z in inset]],
		Cn,
	)

	def yat(z):
		return 0.55 - (z - 0.75) * (0.3 / 1.33)

	band = [(-yat(1.25) - 0.03, 1.25), (yat(1.25) + 0.03, 1.25), (yat(1.65) + 0.03, 1.65), (-yat(1.65) - 0.03, 1.65)]
	extrude_x(M, Bd, band, -1.7, 1.7)
	for x in (-1.0, 1.0):  # forklift slots: dark plates through the toe
		bbox(M, Dk, x - 0.35, x + 0.35, -0.83, 0.83, 0.02, 0.2, 0.0)
	return finish(M)


def luggage_cart(name, collection):
	"""10 (X) x 5 (Y), the push handle at -X."""
	M = A.Mesh(name, collection)
	St, Dk, Wh = A.mat("V_Trim"), A.mat("T_Rubber"), A.mat("G_Steel")
	cases = [A.mat(k) for k in ("L_Case1", "L_Case2", "L_Case3", "L_Case4")]
	# casters (8-sided wheels under swivel forks)
	for x in (-4.2, 4.2):
		for y in (-1.9, 1.9):
			disc_y(M, Dk, x, 0.34, 0.34, 8, y - 0.14, y + 0.14, rot=pi / 8)
			bbox(M, St, x - 0.22, x + 0.22, y - 0.2, y + 0.2, 0.34, 0.72, 0.03)
			bbox(M, St, x - 0.32, x + 0.32, y - 0.32, y + 0.32, 0.7, 0.8, 0.03)
	# frame and deck
	for y in (-2.35, 2.35):
		bbox(M, St, -4.9, 4.9, y - 0.15, y + 0.15, 0.78, 1.12, 0.05)
	for x in (-4.6, 0.0, 4.6):
		bbox(M, St, x - 0.15, x + 0.15, -2.3, 2.3, 0.78, 1.08, 0.04)
	bbox(M, Wh, -4.85, 4.85, -2.3, 2.3, 1.06, 1.16, 0.04)
	# push handle: two uprights and a grip bar
	for y in (-2.0, 2.0):
		bar(M, St, (-4.75, y, 1.1), (-5.05, y, 4.0), 0.22, 0.22)
	bar(M, St, (-5.05, -2.15, 3.95), (-5.05, 2.15, 3.95), 0.26, 0.26)
	# suitcases: bodies with a seam band and a top handle, some lying, some standing
	S = [
		(-3.3, -1.0, 3.2, 1.9, 2.3, 0),  # x, y, length (X), depth (Y), height, case
		(-3.2, 1.25, 3.0, 1.6, 1.4, 1),
		(0.4, 1.1, 2.4, 1.9, 2.4, 2),
		(0.6, -1.05, 3.0, 2.0, 1.0, 3),
		(3.4, 0.0, 2.6, 3.4, 1.6, 1),
	]
	for x, y, lx, dy, hz, k in S:
		z0 = 1.16
		mt = cases[k]
		bbox(M, mt, x - lx / 2, x + lx / 2, y - dy / 2, y + dy / 2, z0, z0 + hz, 0.18)
		bbox(M, Dk, x - lx / 2 - 0.03, x + lx / 2 + 0.03, y - dy / 2 - 0.03, y + dy / 2 + 0.03, z0 + hz * 0.5 - 0.06, z0 + hz * 0.5 + 0.06, 0.03)
		# handle on top: two posts and a grip
		for hx in (x - 0.35, x + 0.35):
			bbox(M, Dk, hx - 0.07, hx + 0.07, y - 0.07, y + 0.07, z0 + hz - 0.02, z0 + hz + 0.22, 0.0)
		bbox(M, Dk, x - 0.45, x + 0.45, y - 0.1, y + 0.1, z0 + hz + 0.2, z0 + hz + 0.32, 0.03)
	return finish(M)


# planting: none. The faceted hedge and conifer were rejected by the owner (2026-11-20: "this greenery does not
# look good", reads as the low-poly look we avoid). Maps use Parts in LeafyGrass / Grass for clipped hedges instead.


# ------------------------------------------------------------------------------------------------ train
def bogie(name, collection):
	"""Origin = bogie centre at rail-top height. X along the track, rails at y = +-2.2. Top (bolster) at 1.85 =
	the car floor (Roblox floor 0.3, rail top -1.55)."""
	M = A.Mesh(name, collection)
	St, Wh, Rb = A.mat("T_Steel"), A.mat("T_Wheel"), A.mat("T_Rubber")
	R = 0.9
	for ax in (-2.6, 2.6):
		for s in (-1, 1):
			yt0, yt1 = sorted((s * 2.03, s * 2.4))
			disc_y(M, Wh, ax, R, R, 12, yt0, yt1, rot=pi / 2)  # tread: a vertex sits on the rail top
			yf0, yf1 = sorted((s * 1.87, s * 2.03))
			disc_y(M, Wh, ax, R, R + 0.13, 12, yf0, yf1, rot=pi / 2)  # flange, inside the rail
			yh0, yh1 = sorted((s * 2.4, s * 2.58))
			disc_y(M, St, ax, R, 0.4, 8, yh0, yh1, rot=pi / 8)  # hub
			ya0, ya1 = sorted((s * 2.5, s * 3.3))
			bbox(M, St, ax - 0.5, ax + 0.5, ya0, ya1, R - 0.45, R + 0.5, 0.08)  # axle box
			# brake block ahead of / behind each wheel
			for bx in (ax - 1.08, ax + 1.08):
				bbox(M, Rb, bx - 0.14, bx + 0.14, s * 2.2 - 0.2, s * 2.2 + 0.2, R - 0.45, R + 0.45, 0.03)
		disc_y(M, St, ax, R, 0.2, 8, -1.88, 1.88, rot=pi / 8)  # axle
	# side frames: dropped centre, carved ends
	prof = [
		(-3.9, 1.05), (-3.45, 0.8), (-1.95, 0.8), (-1.45, 0.45), (1.45, 0.45), (1.95, 0.8), (3.45, 0.8), (3.9, 1.05),
		(3.9, 1.6), (3.45, 1.85), (1.6, 1.85), (1.15, 1.45), (-1.15, 1.45), (-1.6, 1.85), (-3.45, 1.85), (-3.9, 1.6),
	]
	for s in (-1, 1):
		y0, y1 = sorted((s * 2.9, s * 3.3))
		M.plate(prof, y0, y1, St)
		# brake hangers between frame and blocks
		for bx in (-3.68, -1.52, 1.52, 3.68):
			bbox(M, St, bx - 0.1, bx + 0.1, s * 2.3 - 0.1, s * 2.95, R + 0.3, 1.6, 0.02)
	# transoms and the bolster (carries the body floor at 1.85)
	for tx in (-1.25, 1.25):
		bbox(M, St, tx - 0.22, tx + 0.22, -2.95, 2.95, 0.6, 1.1, 0.05)
	bbox(M, St, -0.85, 0.85, -3.25, 3.25, 1.35, 1.85, 0.08)
	for s in (-1, 1):  # secondary springs (8-sided) under the bolster ends
		M.loft([A.ring_at(ngon(0, s * 2.6, 0.38, 8, pi / 8), 0.9), A.ring_at(ngon(0, s * 2.6, 0.38, 8, pi / 8), 1.38)], Rb)
	bbox(M, Rb, -1.0, 1.0, -1.2, 1.2, 0.5, 1.36, 0.08)  # motor / gearbox
	return finish(M)


def cab_front(name, collection):
	"""The driving end. Joint plane x = 0 meets the Parts body (half width 4.8, floor z 0 .. 9.1, roof chamfers to
	half width 4.2 at 9.7). The nose runs toward +X to x = 2.6 (coupler to 3.2)."""
	M = A.Mesh(name, collection)
	B, St, Wh, Rb, Gl, Lp, Pt = (A.mat(k) for k in ("T_Body", "T_Steel", "T_Wheel", "T_Rubber", "T_Glass", "T_Lamp", "T_Paint"))

	def plan(w, f, k, x0=0.0):
		return [(x0, -w), (f - k, -w), (f, -w + k), (f, w - k), (f - k, w), (x0, w)]

	rings = [
		(-1.3, 4.3, 2.0, 1.2),
		(0.0, 4.8, 2.6, 1.0),
		(3.9, 4.8, 2.6, 1.0),
		(8.2, 4.8, 1.3, 0.85),
		(9.1, 4.8, 0.75, 0.6),
		(9.7, 4.2, 0.2, 0.15),
	]
	M.loft([[(x, y, z) for x, y in plan(w, f, k)] for z, w, f, k in rings], B)

	# paint band (0.1 proud) round the nose, continuing the side stripe (Roblox 1.8 .. 2.8 = here 1.5 .. 2.5)
	def nose_x(z):  # front face x at height z, below the rake it is 2.6
		return 2.6

	M.loft([[(x, y, z) for x, y in plan(4.9, 2.7, 1.04, 0.03)] for z in (1.5, 2.5)], Pt)
	# anti-climber (ribbed steel band) at the floor line
	M.loft([[(x, y, z) for x, y in plan(4.6, 2.78, 1.1, 0.03)] for z in (-0.25, 0.4)], St)
	for z in (-0.05, 0.2):
		M.loft([[(x, y, z) for x, y in plan(4.62, 2.86, 1.12, 0.06)] for z in (z - 0.04, z + 0.04)], Wh)

	# raked face plane: x = 2.6 - (z - 3.9) * (1.3 / 4.3), normal out and up
	k = 1.3 / 4.3
	nrm = Vector((1.0, 0.0, k)).normalized()

	def on_face(y, z, t):
		return Vector((2.6 - (z - 3.9) * k, y, z)) + nrm * t

	def face_slab(mat, y0, y1, z0, z1, t0, t1):
		ring = lambda t: [tuple(on_face(y, z, t)) for y, z in ((y0, z0), (y1, z0), (y1, z1), (y0, z1))]  # noqa: E731
		M.loft([ring(t0), ring(t1)], mat)

	face_slab(Rb, -3.75, 3.75, 4.15, 8.0, -0.05, 0.05)  # windscreen surround
	face_slab(Gl, -3.45, 3.45, 4.4, 7.75, -0.05, 0.09)  # glass
	face_slab(Rb, -2.2, 2.2, 7.05, 7.6, -0.05, 0.12)  # display band (no text)
	face_slab(Rb, -0.12, 0.12, 4.4, 7.05, -0.05, 0.12)  # centre post
	# wiper parked at the bottom of the left pane
	p0, p1 = on_face(-1.0, 4.55, 0.12), on_face(-3.0, 4.75, 0.12)
	bar(M, Rb, p0, p1, 0.1, 0.12, c=0.02)
	# headlights: housing + lens on the vertical lower face
	for s in (-1, 1):
		ya, yb = sorted((s * 2.45, s * 3.55))
		bbox(M, Rb, 2.55, 2.7, ya, yb, 2.95, 3.65, 0.04)
		ya, yb = sorted((s * 2.6, s * 3.4))
		bbox(M, Lp, 2.65, 2.75, ya, yb, 3.08, 3.52, 0.03)
	# skirt plate across the front under the anti-climber, and the coupler
	bbox(M, St, 1.6, 2.1, -3.6, 3.6, -1.25, -0.2, 0.06)
	bbox(M, St, 2.0, 2.9, -0.4, 0.4, -0.95, -0.35, 0.06)
	bbox(M, Wh, 2.8, 3.2, -0.65, 0.65, -1.05, -0.25, 0.06)
	return finish(M)


def ticket_gate(name, collection):
	"""Cabinet 1.2 (X) x 3 (Y) x 3.5. The console slopes down toward +Y and -Y ends."""
	M = A.Mesh(name, collection)
	St, Dk, Pt, Lp = A.mat("G_Steel"), A.mat("G_Dark"), A.mat("G_Paint"), A.mat("T_Lamp")
	bbox(M, Dk, -0.52, 0.52, -1.42, 1.42, 0.0, 0.32, 0.04)  # recessed plinth
	bbox(M, St, -0.6, 0.6, -1.5, 1.5, 0.3, 3.0, 0.1)
	for s in (-1, 1):  # inset side panels
		xa, xb = sorted((s * 0.6, s * 0.64))
		bbox(M, Dk, xa, xb, -1.15, 1.15, 0.75, 2.55, 0.0)
	poly = [(-1.5, 2.98), (1.5, 2.98), (1.5, 3.2), (1.05, 3.5), (-1.05, 3.5), (-1.5, 3.2)]
	extrude_x(M, Pt, poly, -0.62, 0.62)
	bbox(M, Dk, -0.38, 0.38, -0.85, -0.2, 3.49, 3.56, 0.02)  # reader
	bbox(M, Lp, -0.3, 0.3, 0.3, 0.75, 3.49, 3.55, 0.02)  # status light
	return finish(M)


def gate_paddles(name, collection, gap=3.13):
	"""Two glass leaves between cabinets `gap` apart (inner faces at x = +-gap/2), meeting with a small gap."""
	M = A.Mesh(name, collection)
	Gl, Dk = A.mat("G_Glass"), A.mat("G_Dark")
	h = gap / 2
	for s in (-1, 1):
		xa, xb = sorted((s * (h + 0.02), s * 0.14))
		bbox(M, Gl, xa, xb, -0.06, 0.06, 1.35, 3.05, 0.03)
		xa, xb = sorted((s * (h + 0.04), s * (h - 0.25)))
		bbox(M, Dk, xa, xb, -0.12, 0.12, 1.25, 3.15, 0.04)  # hinge stile
		xa, xb = sorted((s * 0.3, s * 0.12))
		bbox(M, Dk, xa, xb, -0.09, 0.09, 1.35, 3.05, 0.03)  # leading edge
	return finish(M)


# ------------------------------------------------------------------------------------------------ build
PROPS = tuple(f"Crate{s}_{h}" for s in ("A", "B") for h in CRATE_H) + ("Vending", "LuggageCart", "Pallet", "Barrier")
METRO = ("Bogie", "CabFront", "TicketGate", "GatePaddles")


def build_all():
	import bpy

	names = set(PROPS) | set(METRO)
	for c in [c for c in bpy.data.collections if c.name.startswith("Map_") and c.name[4:] in names]:
		for o in list(c.all_objects):
			me = o.data
			bpy.data.objects.remove(o, do_unlink=True)
			if me is not None and me.users == 0:
				bpy.data.meshes.remove(me)
		bpy.data.collections.remove(c)
	root = A.coll(ROOT)

	def C(n):
		return A.coll("Map_" + n, root)

	made = []
	for s in ("A", "B"):
		for key, H in CRATE_H.items():
			n = f"Crate{s}_{key}"
			made.append(crate(n, C(n), H, s))
	made += [
		vending("Vending", C("Vending")),
		luggage_cart("LuggageCart", C("LuggageCart")),
		pallet("Pallet", C("Pallet")),
		barrier("Barrier", C("Barrier")),
		bogie("Bogie", C("Bogie")),
		cab_front("CabFront", C("CabFront")),
		ticket_gate("TicketGate", C("TicketGate")),
		gate_paddles("GatePaddles", C("GatePaddles")),
	]
	for nm, (hx, _r) in A.PAL.items():
		m = bpy.data.materials.get(nm)
		if m is not None:
			m["rbx_material"] = "SmoothPlastic"
			m["rbx_color"] = hx.lstrip("#").upper()
			if nm in TRANSPARENT:
				m["rbx_transparency"] = TRANSPARENT[nm]
	return {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}
