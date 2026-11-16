"""Port kit, the rest of the pieces and the kit build (map redesign batch 2, 2026-11-16).

    import port_pieces as K; K.build_all()     (live maps Blender, port 9930; see port_kit.py)

Every piece is a Map_<Piece> collection at the origin with Roblox-tagged materials, ready for
tools/blender/export_lobby_kit.py main(["--maps", "Port", "Kit"]). Pieces sit inside their greybox collision
boxes (tools/maps/port_layout.py); the greybox parts stay as the invisible collision.
"""
from math import cos, radians, sin

import arena_kit as A
import port_kit as P

ROOT = P.ROOT


def _bar_x(M, mat, y0, y1, z0, z1, x0, x1, c=0.12):
	"""A chamfered bar along X."""
	sec = A.cham(y0, y1, z0, z1, c)
	M.loft([[(x0, y, z) for y, z in sec], [(x1, y, z) for y, z in sec]], mat)


def gantry(name, half_span, height, collection=None):
	"""Gantry crane in its greybox slot: legs 5 (x) by 10 (y) at x = +-half_span from 0 to height + 1; a 5 x 5
	box girder from height - 5 to height between the legs. A red trolley and a hook block hang over the middle
	(decor). Columns are chamfered square sections, braces flat bars: nothing round."""
	col = collection or A.coll(ROOT)
	M = A.Mesh(name, col)
	S, D, R, Bar = A.mat("G_Steel"), A.mat("G_SteelDark"), A.mat("C_Red"), A.mat("C_Bar")
	top = height + 1
	for sx in (-1, 1):
		xc = sx * half_span
		M.prism(A.cham(xc - 2.5, xc + 2.5, -5, 5, 0.4), 0.0, 0.6, D)  # foot plate
		for yc in (-3.75, 3.75):
			M.prism(A.cham(xc - 1.1, xc + 1.1, yc - 1.1, yc + 1.1, 0.25), 0.6, top - 2.2, S)  # columns
		M.prism(A.cham(xc - 2.5, xc + 2.5, -5, 5, 0.45), top - 2.2, top, D)  # head that takes the girder
		z, k = 3.0, 0
		while z + 6.2 < top - 2.2:
			M.prism(A.cham(xc - 0.45, xc + 0.45, -2.65, 2.65, 0.1), z, z + 0.7, D)  # tie
			ya, yb = (-2.65, 2.65) if k % 2 == 0 else (2.65, -2.65)
			M.loft(  # brace
				[
					[(xc - 0.35, ya, z + 0.7), (xc + 0.35, ya, z + 0.7), (xc + 0.35, ya, z + 1.6), (xc - 0.35, ya, z + 1.6)],
					[(xc - 0.35, yb, z + 5.3), (xc + 0.35, yb, z + 5.3), (xc + 0.35, yb, z + 6.2), (xc - 0.35, yb, z + 6.2)],
				],
				D,
			)
			z += 6.0
			k += 1
	gx = half_span - 2.5  # girder runs between the legs' inner faces
	g0, g1 = height - 5, height
	_bar_x(M, S, -2.2, 2.2, g0 + 0.5, g1 - 0.5, -gx, gx, 0.2)
	for zf0, zf1 in ((g0, g0 + 0.5), (g1 - 0.5, g1)):
		_bar_x(M, D, -2.5, 2.5, zf0, zf1, -gx, gx, 0.12)  # flanges
	x = -gx + 2.5
	while x < gx - 1:
		for ya, yb in ((2.2, 2.45), (-2.45, -2.2)):
			M.prism([(x - 0.2, ya), (x + 0.2, ya), (x + 0.2, yb), (x - 0.2, yb)], g0 + 0.5, g1 - 0.5, D)  # stiffeners
		x += 5.0
	M.prism(A.cham(-3.0, 3.0, -2.8, 2.8, 0.4), g1, g1 + 2.4, R)  # trolley
	M.prism(A.cham(-2.0, 2.0, -1.8, 1.8, 0.3), g1 + 2.4, g1 + 3.0, R)
	for cx, cy in ((-0.9, -0.9), (0.9, -0.9), (-0.9, 0.9), (0.9, 0.9)):
		M.prism(P.hexagon(cx, cy, 0.09), g0 - 6.0, g0, Bar)  # cables
	M.prism(A.cham(-1.6, 1.6, -1.4, 1.4, 0.35), g0 - 8.2, g0 - 6.0, R)  # hook block
	M.prism(A.cham(-0.35, 0.35, -0.35, 0.35, 0.1), g0 - 9.6, g0 - 8.2, Bar)
	M.prism(A.cham(-0.35, 1.1, -0.35, 0.35, 0.12), g0 - 10.4, g0 - 9.6, Bar)  # hook (an angled block)
	return M.finish()


def _octo(r, rot=22.5):
	return [(r * cos(radians(rot + 45 * i)), r * sin(radians(rot + 45 * i))) for i in range(8)]


def bollard(name, collection=None):
	"""Mooring bollard, 8-sided: base plate, waisted post, cap. 2.4 tall, decor along the deck edges."""
	col = collection or A.coll(ROOT)
	M = A.Mesh(name, col)
	Ir = A.mat("B_Iron")
	M.prism(A.cham(-0.95, 0.95, -0.95, 0.95, 0.25), 0.0, 0.3, Ir)
	M.loft([[(x, y, 0.3) for x, y in _octo(0.62)], [(x, y, 1.2) for x, y in _octo(0.5)], [(x, y, 1.9) for x, y in _octo(0.58)]], Ir)
	M.loft([[(x, y, 1.9) for x, y in _octo(0.85)], [(x, y, 2.2) for x, y in _octo(0.85)], [(x, y, 2.4) for x, y in _octo(0.6)]], Ir)
	return M.finish()


def warehouse_roof(name, size=40.0, z0=12.0, z1=14.0, collection=None):
	"""Flat warehouse roof in its 40 x 40 slot (12..14): a slab, a corrugated top sheet (ribs along Y as angled
	plates) and a chamfered fascia band all round, its top 0.05 under the sheet."""
	col = collection or A.coll(ROOT)
	M = A.Mesh(name, col)
	Rf, T = A.mat("W_Roof"), A.mat("W_Trim")
	h = size / 2
	M.prism(A.cham(-h + 0.6, h - 0.6, -h + 0.6, h - 0.6, 0.1), z0, z1 - 0.35, Rf)
	outer = A.cham(-h, h, -h, h, 0.3)
	inner = A.cham(-h + 0.6, h - 0.6, -h + 0.6, h - 0.6, 0.1)
	for i in range(len(outer)):
		a0, a1 = outer[i], outer[(i + 1) % len(outer)]
		b0, b1 = inner[i], inner[(i + 1) % len(inner)]
		M.prism([a0, a1, b1, b0], z0 - 0.2, z1 - 0.05, T)
	n = round((size - 1.2) / P.PITCH)
	p = (size - 1.2) / n
	for i in range(n):
		xa = -h + 0.6 + i * p
		prof = [(xa, z1 - 0.35), (xa + p * 0.38, z1 - 0.35), (xa + p * 0.5, z1), (xa + p * 0.88, z1), (xa + p, z1 - 0.35)]
		M.loft([[(x, -h + 0.6, z) for x, z in prof], [(x, h - 0.6, z) for x, z in prof]], Rf)
	return M.finish()


def roof_stair(name, length=25.0, width=10.0, rise=14.0, collection=None):
	"""Steel stair rising along +X in its wedge slot: two stringers with level-cut ends, a tread per stud of
	rise, handrails on posts. The greybox wedge stays as the (invisible) walking surface."""
	col = collection or A.coll(ROOT)
	M = A.Mesh(name, col)
	S, D = A.mat("G_Steel"), A.mat("G_SteelDark")
	hx, hy = length / 2, width / 2
	steps = int(rise)
	run = length / steps
	for y0, y1 in ((hy - 0.5, hy), (-hy, -hy + 0.5)):
		prof = [(-hx, 0.0), (-hx + 1.2, 0.0), (hx, rise - 1.4), (hx, rise), (hx - 0.6, rise), (-hx, 1.2)]
		M.loft([[(x, y0, z) for x, z in prof], [(x, y1, z) for x, z in prof]], D)  # stringer
		ym = (y0 + y1) / 2
		for i in range(0, steps + 1, 4):
			x = min(-hx + i * run, hx - 0.2)
			z = i * 1.0
			M.prism(A.cham(x - 0.15, x + 0.15, ym - 0.15, ym + 0.15, 0.05), z + 0.6, z + 3.2, S)  # posts
		M.loft(  # handrail
			[
				[(-hx, ym - 0.17, 3.1), (-hx, ym + 0.17, 3.1), (-hx, ym + 0.17, 3.4), (-hx, ym - 0.17, 3.4)],
				[(hx, ym - 0.17, rise + 3.1), (hx, ym + 0.17, rise + 3.1), (hx, ym + 0.17, rise + 3.4), (hx, ym - 0.17, rise + 3.4)],
			],
			S,
		)
	for i in range(steps):
		x0 = -hx + i * run
		z = (i + 1) * 1.0
		M.prism(A.cham(x0, x0 + run, -hy + 0.5, hy - 0.5, 0.06), z - 0.35, z - 0.02, S)  # treads
	return M.finish()


CONTAINERS = [
	("ContainerGrey30", "C_Grey", "C_GreyDark", 30),
	("ContainerRed30", "C_Red", "C_RedDark", 30),
	("ContainerGrey25", "C_Grey", "C_GreyDark", 25),
	("ContainerGrey20", "C_Grey", "C_GreyDark", 20),
	("ContainerRed20", "C_Red", "C_RedDark", 20),
	("ContainerGrey15", "C_Grey", "C_GreyDark", 15),
]


def tag_materials():
	import bpy

	for name, (hx, _rough) in A.PAL.items():
		m = bpy.data.materials.get(name)
		if m is not None:
			m["rbx_material"] = "SmoothPlastic"
			m["rbx_color"] = hx.lstrip("#").upper()


def build_all():
	"""(Re)builds every kit piece in its Map_<Piece> collection. Returns triangles per piece."""
	import bpy

	for c in [c for c in bpy.data.collections if c.name.startswith("Map_")]:
		for o in list(c.all_objects):
			me = o.data
			bpy.data.objects.remove(o, do_unlink=True)
			if me is not None and me.users == 0:
				bpy.data.meshes.remove(me)
		bpy.data.collections.remove(c)
	root = A.coll(ROOT)
	made = []
	for piece, body, frame, ln in CONTAINERS:
		made.append(P.container(piece, body=body, frame=frame, length=ln, collection=A.coll("Map_" + piece, root)))
	made.append(gantry("GantryPier", 42.5, 30, collection=A.coll("Map_GantryPier", root)))
	made.append(gantry("GantryDock", 60.0, 34, collection=A.coll("Map_GantryDock", root)))
	made.append(bollard("Bollard", collection=A.coll("Map_Bollard", root)))
	made.append(warehouse_roof("WarehouseRoof", collection=A.coll("Map_WarehouseRoof", root)))
	made.append(roof_stair("RoofStair", collection=A.coll("Map_RoofStair", root)))
	tag_materials()
	return {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}
