"""Arena / Big Arena kit (map redesign 2026-11-16): RIVALS-clean panel court in our faceted style.

Run in the live Blender MCP instance for maps (port 9930) through tools/blender/lobby_v4/send.py:
    python tools/blender/lobby_v4/send.py tools/blender/maps_arena/run_test.py --port 9930 --pid <pid>
Units: 1 Blender unit = 1 stud. X along the piece, Y its thickness, Z up. Origin = floor centre of the piece.

Look (owner 2026-11-16): like the RIVALS Arena (cool grey-violet panels on a 5-stud grid with cross joints),
no gold or colour accent, built to our rules: no round shapes, carved ends, every junction has a transition,
facets big enough to read. Plan: vault/01 Design/Maps/Arena.md.
"""
from math import radians

import bmesh
import bpy
from mathutils import Vector

ROOT = "ArenaKit"

# name -> (hex, roughness)
PAL = {
	"A_Panel": ("#A9ACB6", 0.75),  # the face plates (lightest structure value)
	"A_Core": ("#7F828D", 0.8),  # the recessed body seen in the seams
	"A_Base": ("#5F626C", 0.8),  # plinths, feet
	"A_Trim": ("#C9CBD2", 0.65),  # crowns, cap plates (the light edge line)
	"A_Joint": ("#6C6F79", 0.7),  # cross plates at seam junctions
	"A_Floor": ("#B4B6BE", 0.8),
	"P_Proxy": ("#3A3D44", 0.9),  # R15 proxy
}


def hex_rgb(h):
	h = h.lstrip("#")
	c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def mat(name):
	m = bpy.data.materials.get(name)
	if m is None:
		m = bpy.data.materials.new(name)
		m.use_nodes = True
	hx, rough = PAL[name]
	bsdf = m.node_tree.nodes.get("Principled BSDF")
	r, g, b = hex_rgb(hx)
	bsdf.inputs["Base Color"].default_value = (r, g, b, 1)
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Metallic"].default_value = 0.0
	m.diffuse_color = (r, g, b, 1)
	return m


def coll(name, parent=None):
	c = bpy.data.collections.get(name)
	if c is None:
		c = bpy.data.collections.new(name)
		(parent or bpy.context.scene.collection).children.link(c)
	return c


def clear_coll(name):
	c = bpy.data.collections.get(name)
	if c is None:
		return
	for o in list(c.all_objects):
		me = o.data
		bpy.data.objects.remove(o, do_unlink=True)
		if me and me.users == 0:
			bpy.data.meshes.remove(me)
	for ch in list(c.children):
		bpy.data.collections.remove(ch)


class Mesh:
	"""Accumulates closed faceted solids, one material slot each, into one object."""

	def __init__(self, name, collection):
		self.bm = bmesh.new()
		self.name, self.col = name, collection
		self.mats = []

	def _slot(self, m):
		if m not in self.mats:
			self.mats.append(m)
		return self.mats.index(m)

	def loft(self, rings, material):
		"""rings: list of closed loops [(x, y, z), ...] with the same vertex count, bottom to top. Caps both ends."""
		bm = self.bm
		idx = self._slot(material)
		vs = [[bm.verts.new(p) for p in r] for r in rings]
		n = len(rings[0])
		faces = [bm.faces.new(list(reversed(vs[0])))]
		for a, b in zip(vs, vs[1:]):
			for i in range(n):
				faces.append(bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i])))
		faces.append(bm.faces.new(vs[-1]))
		for f in faces:
			f.material_index = idx
		return faces

	def prism(self, poly, z0, z1, material):
		return self.loft([[(x, y, z0) for x, y in poly], [(x, y, z1) for x, y in poly]], material)

	def plate(self, poly_xz, y0, y1, material):
		"""A prism along Y from a polygon drawn in the XZ plane (face plates on a wall)."""
		pts = poly_xz
		area = sum(pts[i - 1][0] * pts[i][1] - pts[i][0] * pts[i - 1][1] for i in range(len(pts)))
		if area > 0:  # make the y0 cap face -Y
			pts = list(reversed(pts))
		return self.loft([[(x, y0, z) for x, z in pts], [(x, y1, z) for x, z in pts]], material)

	def finish(self, smooth_angle=30):
		me = bpy.data.meshes.new(self.name)
		bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
		self.bm.to_mesh(me)
		self.bm.free()
		for m in self.mats:
			me.materials.append(m)
		for p in me.polygons:
			p.use_smooth = False
		o = bpy.data.objects.new(self.name, me)
		self.col.objects.link(o)
		return o


def cham(x0, x1, y0, y1, c):
	"""Rectangle with all four corners cut by c (an octagon-ish outline)."""
	return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def cham2(x0, x1, y0, y1, cx, cy=None):
	cy = cx if cy is None else cy
	return [(x0 + cx, y0), (x1 - cx, y0), (x1, y0 + cy), (x1, y1 - cy), (x1 - cx, y1), (x0 + cx, y1), (x0, y1 - cy), (x0, y0 + cy)]


def ring_at(poly, z):
	return [(x, y, z) for x, y in poly]


def plus(cx, cz, arm, w, c):
	"""A faceted plus outline in the XZ plane (counter-clockwise): arms of half-length `arm`, half-width `w`,
	each arm tip cut by c on both corners."""
	return [
		(cx + w, cz + w), (cx + arm - c, cz + w), (cx + arm, cz + w - c), (cx + arm, cz - w + c), (cx + arm - c, cz - w),
		(cx + w, cz - w), (cx + w, cz - arm + c), (cx + w - c, cz - arm), (cx - w + c, cz - arm), (cx - w, cz - arm + c),
		(cx - w, cz - w), (cx - arm + c, cz - w), (cx - arm, cz - w + c), (cx - arm, cz + w - c), (cx - arm + c, cz + w),
		(cx - w, cz + w), (cx - w, cz + arm - c), (cx - w + c, cz + arm), (cx + w - c, cz + arm), (cx + w, cz + arm - c),
	][::-1]


# ---------------------------------------------------------------------------------------------- pieces
PANEL = 5.0  # the RIVALS grid, kept as our panel module
SEAM = 0.16  # gap between face plates (the core shows through)
PROUD = 0.14  # face plates stand this far off the core
PL_CH = 0.1  # face plate edge chamfer (reads at 30+ studs)


def panel_slab(name, L=16.0, T=4.0, H=9.0, collection=None):
	"""Full-cover slab: plinth -> recessed core -> proud face plates on a 5-stud grid -> cross joints -> angled crown.
	Ends are cut back (vertical chamfers), the crown leans in on both faces. Fills its L x T x H cover box exactly."""
	col = collection or coll(ROOT)
	M = Mesh(name, col)
	P, C, Bm, Tr, J = mat("A_Panel"), mat("A_Core"), mat("A_Base"), mat("A_Trim"), mat("A_Joint")
	hx, hy = L / 2, T / 2
	base_h, crown_h = 0.7, 0.75
	core_in = PROUD + 0.02  # core sits inside the cover box so plates end flush with it
	end_c = 0.55  # cut-back on the slab ends (vertical chamfer)

	# plinth: full footprint, bevelled top edge (lofted, leans in 0.18)
	foot = cham(-hx, hx, -hy, hy, end_c)
	top = cham(-hx + 0.18, hx - 0.18, -hy + 0.18, hy - 0.18, end_c)
	M.loft([ring_at(foot, 0.0), ring_at(foot, base_h - 0.2), ring_at(top, base_h)], Bm)

	# core: recessed body
	z0, z1 = base_h, H - crown_h
	core = cham(-hx + core_in, hx - core_in, -hy + core_in, hy - core_in, end_c)
	M.prism(core, z0 - 0.02, z1 + 0.02, C)

	# face plates on both long faces: columns of PANEL, rows split at mid height
	cols = max(1, round(L / PANEL))
	pw = (L - 2 * end_c) / cols
	rows = [(z0 + 0.12, z0 + (z1 - z0) * 0.5 - SEAM / 2), (z0 + (z1 - z0) * 0.5 + SEAM / 2, z1 - 0.12)]
	for sgn in (-1, 1):
		y_out, y_in = sgn * hy, sgn * (hy - core_in - 0.02)
		for i in range(cols):
			xa = -hx + end_c + i * pw + SEAM / 2
			xb = xa + pw - SEAM
			for za, zb in rows:
				M.plate(cham(xa, xb, za, zb, PL_CH), min(y_in, y_out), max(y_in, y_out), P)
		# cross joints where the seams meet (inner columns only), 0.06 proud of the plates
		for i in range(1, cols):
			x = -hx + end_c + i * pw
			zc = z0 + (z1 - z0) * 0.5
			yo = sgn * (hy + 0.06)
			M.plate(plus(x, zc, 0.62, 0.17, 0.08), min(sgn * (hy - 0.05), yo), max(sgn * (hy - 0.05), yo), J)

	# end caps: one plate per cut-back end, leaning (the carved end)
	for sx in (-1, 1):
		xo = sx * hx
		xi = sx * (hx - end_c)
		pts = [(xi, -hy + 0.02), (xo, -hy + end_c), (xo, hy - end_c), (xi, hy - 0.02)]
		ring0 = [(x, y, z0 + 0.12) for x, y in pts]
		ring1 = [(x, y, z1 - 0.12) for x, y in pts]
		# give the end cap thickness by shrinking toward the core
		inner = [(sx * (hx - end_c - 0.3), -hy + core_in), (sx * (hx - 0.3), -hy + end_c), (sx * (hx - 0.3), hy - end_c), (sx * (hx - end_c - 0.3), hy - core_in)]
		loop = pts + list(reversed(inner))
		M.prism(loop if sx > 0 else list(reversed(loop)), z0 + 0.12, z1 - 0.12, P)

	# crown: angled cap, leans in on both faces, cut-back ends
	c0 = cham(-hx + 0.02, hx - 0.02, -hy + 0.02, hy - 0.02, end_c)
	c1 = cham(-hx + 0.3, hx - 0.3, -hy + 0.45, hy - 0.45, end_c * 0.8)
	M.loft([ring_at(c0, z1), ring_at(c0, z1 + 0.25), ring_at(c1, H)], Tr)
	return M.finish()


def r15_proxy(name="R15_Proxy", x=0.0, y=0.0, collection=None):
	"""A 5.2-stud blocky stand-in (legs, torso, arms, head) for scale renders."""
	col = collection or coll(ROOT)
	M = Mesh(name, col)
	m = mat("P_Proxy")
	box = lambda x0, x1, y0, y1, z0, z1: M.prism(cham(x0, x1, y0, y1, 0.06), z0, z1, m)
	box(x - 0.95, x - 0.05, y - 0.45, y + 0.45, 0.0, 2.0)
	box(x + 0.05, x + 0.95, y - 0.45, y + 0.45, 0.0, 2.0)
	box(x - 1.0, x + 1.0, y - 0.5, y + 0.5, 2.0, 4.0)
	box(x - 1.9, x - 1.05, y - 0.45, y + 0.45, 2.1, 4.0)
	box(x + 1.05, x + 1.9, y - 0.45, y + 0.45, 2.1, 4.0)
	box(x - 0.6, x + 0.6, y - 0.6, y + 0.6, 4.05, 5.2)
	return M.finish()
