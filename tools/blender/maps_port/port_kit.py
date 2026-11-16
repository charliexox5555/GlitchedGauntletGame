"""Port kit (Pier + Dockyard, map redesign batch 2, 2026-11-16): the pieces that need real shape.

Meshes only where shape matters (owner 2026-11-16: "not everything needs to be built in Blender"): containers,
the gantry crane, bollards, the warehouse roof. The quay deck, plain walls, crates and steps stay Roblox Parts.
Our own pieces learned from RIVALS Docks' sizes (a 9.4 x 10.2 x 27.5 container), never their meshes.

Run in the maps Blender (port 9930): python tools/blender/lobby_v4/send.py tools/blender/maps_port/run_test.py --port 9930 --pid <pid>
Units: 1 unit = 1 stud. X along the piece, Y across, Z up; origin = floor centre. Faceted rules: no round
shapes (bars are 6-sided prisms), chamfered posts and rails, corrugation as angled plates.
"""
import sys

REPO = r"C:\\Users\\charl\\Documents\\GauntletGame\\GlitchedGauntletGame"
sys.path.insert(0, REPO + r"\\tools\\blender\\maps_arena")
import arena_kit as A  # noqa: E402

ROOT = "PortKit"

A.PAL.update(
	{
		"C_Red": ("#B04A40", 0.7),  # the port accent (containers)
		"C_RedDark": ("#8E3A33", 0.7),  # its frame
		"C_Grey": ("#8C919B", 0.7),  # the common container
		"C_GreyDark": ("#6F747E", 0.7),
		"C_Bar": ("#33363C", 0.6),  # lock bars, hinges
		"C_Cast": ("#4A4E56", 0.7),  # corner castings
	}
)

L, W, H = 30.0, 10.0, 10.0  # the kit module
POST = 0.9  # corner post width
RAIL = 0.8  # top and bottom rail height
PITCH = 1.6  # corrugation pitch


def hexagon(cx, cy, r):
	from math import cos, sin, radians

	return [(cx + r * cos(radians(30 + 60 * i)), cy + r * sin(radians(30 + 60 * i))) for i in range(6)]


def corrugated_wall(M, mat, x0, x1, y_face, sign, z0, z1, depth=0.32, skin=0.18):
	"""A wall of trapezoid ribs between x0 and x1, outer face at y_face, ribs pressed `depth` in (toward -sign).
	One closed prism: the rib profile on the outside, a flat skin behind."""
	n = max(2, round((x1 - x0) / PITCH))
	p = (x1 - x0) / n
	out = []
	for i in range(n):
		a = x0 + i * p
		# outer flat, slope in, inner flat, slope out (each a quarter-ish of the pitch)
		out += [(a, y_face), (a + p * 0.38, y_face), (a + p * 0.5, y_face - sign * depth), (a + p * 0.88, y_face - sign * depth)]
	out.append((x1, y_face))
	back = y_face - sign * (depth + skin)
	poly = out + [(x1, back), (x0, back)]
	M.prism(poly if sign > 0 else list(reversed(poly)), z0, z1, mat)


def container(name, body="C_Red", frame="C_RedDark", collection=None, doors=True):
	"""10 x 10 x 30 shipping container: chamfered corner posts, top and bottom rails, corrugated long sides and
	blind end, a two-leaf door end with four lock bars, corner castings. Fills its 30 x 10 x 10 box exactly."""
	col = collection or A.coll(ROOT)
	M = A.Mesh(name, col)
	B, F, Bar, Cast = A.mat(body), A.mat(frame), A.mat("C_Bar"), A.mat("C_Cast")
	hx, hy = L / 2, W / 2
	c = 0.16  # post chamfer
	# corner posts
	for sx in (-1, 1):
		for sy in (-1, 1):
			x0, x1 = (hx - POST, hx) if sx > 0 else (-hx, -hx + POST)
			y0, y1 = (hy - POST, hy) if sy > 0 else (-hy, -hy + POST)
			M.prism(A.cham(x0, x1, y0, y1, c), 0.0, H, F)
	# rails: bottom and top, along both lengths and both ends (between the posts)
	for z0, z1 in ((0.0, RAIL), (H - RAIL, H)):
		for sy in (-1, 1):
			y0, y1 = (hy - 0.6, hy) if sy > 0 else (-hy, -hy + 0.6)
			M.loft(
				[
					[(-hx + POST, y0, z0), (hx - POST, y0, z0), (hx - POST, y1, z0), (-hx + POST, y1, z0)],
					[(-hx + POST, y0, z1), (hx - POST, y0, z1), (hx - POST, y1, z1), (-hx + POST, y1, z1)],
				],
				F,
			)
		for sx in (-1, 1):
			x0, x1 = (hx - 0.6, hx) if sx > 0 else (-hx, -hx + 0.6)
			M.prism([(x0, -hy + POST), (x1, -hy + POST), (x1, hy - POST), (x0, hy - POST)], z0, z1, F)
	# corrugated long sides
	for sy in (-1, 1):
		corrugated_wall(M, B, -hx + POST, hx - POST, sy * (hy - 0.08), sy, RAIL, H - RAIL)
	# roof: a plate between the top rails, two low stiffener ribs across
	M.prism(A.cham(-hx + 0.6, hx - 0.6, -hy + 0.6, hy - 0.6, 0.05), H - RAIL, H - 0.25, B)
	for xr in (-hx / 2, hx / 2):
		M.prism(A.cham(xr - 0.4, xr + 0.4, -hy + 0.6, hy - 0.6, 0.08), H - 0.25, H - 0.1, B)
	# blind end (-X): vertical corrugation, written in the YZ plane by swapping axes through a rotated prism
	n = max(2, round((W - 2 * POST) / PITCH))
	p = (W - 2 * POST) / n
	xf = -hx + 0.08
	for i in range(n):
		y = -hy + POST + i * p
		M.loft(
			[
				[(xf, y, RAIL), (xf, y + p * 0.4, RAIL), (xf + 0.32, y + p * 0.52, RAIL), (xf + 0.32, y + p * 0.9, RAIL), (xf + 0.5, y + p * 0.9, RAIL), (xf + 0.5, y, RAIL)],
				[(xf, y, H - RAIL), (xf, y + p * 0.4, H - RAIL), (xf + 0.32, y + p * 0.52, H - RAIL), (xf + 0.32, y + p * 0.9, H - RAIL), (xf + 0.5, y + p * 0.9, H - RAIL), (xf + 0.5, y, H - RAIL)],
			],
			B,
		)
	if doors:
		# door end (+X): two leaves, each with three inset panels, four lock bars (6-sided), hinge blocks
		xo = hx - 0.06
		gap = 0.08
		for sy in (-1, 1):
			ya, yb = (gap / 2, hy - POST) if sy > 0 else (-hy + POST, -gap / 2)
			M.prism([(xo - 0.35, ya), (xo, ya), (xo, yb), (xo - 0.35, yb)], RAIL, H - RAIL, B)
			# inset panel frames: three horizontal bands proud of the leaf
			for za, zb in ((RAIL + 0.35, 3.55), (3.85, 6.15), (6.45, H - RAIL - 0.35)):
				M.prism(A.cham(xo, xo + 0.1, ya + 0.35, yb - 0.35, 0.04), za, zb, B)
			# two lock bars per leaf
			for t in (0.3, 0.7):
				yy = ya + (yb - ya) * t
				M.prism(hexagon(xo + 0.22, yy, 0.12), RAIL + 0.1, H - RAIL - 0.1, Bar)
				# handle plate at hand height
				M.prism(A.cham(xo + 0.1, xo + 0.36, yy - 0.18, yy + 0.18, 0.04), 3.9, 4.6, Bar)
			# hinges on the outer edge
			for zh in (1.6, 5.0, 8.4):
				yh = sy * (hy - POST - 0.05)
				M.prism(A.cham(xo, xo + 0.3, yh - 0.25, yh + 0.25, 0.05), zh - 0.3, zh + 0.3, Bar)
	# corner castings: small chamfered blocks proud of the posts at all eight corners
	for sx in (-1, 1):
		for sy in (-1, 1):
			for z0, z1 in ((0.0, 0.55), (H - 0.55, H + 0.0)):
				xa, xb = (hx - 0.75, hx + 0.04) if sx > 0 else (-hx - 0.04, -hx + 0.75)
				ya, yb = (hy - 0.75, hy + 0.04) if sy > 0 else (-hy - 0.04, -hy + 0.75)
				M.prism(A.cham(xa, xb, ya, yb, 0.1), z0 + 0.02 if z0 == 0 else z0, z1 - 0.02 if z1 == H else z1, Cast)
	return M.finish()
