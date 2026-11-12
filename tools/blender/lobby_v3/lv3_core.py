"""Lobby V3 core: builders, materials, lights and render helpers.

Run inside the owner's live Blender through Blender MCP (not background Blender):
    import sys; sys.path.insert(0, r"<repo>/tools/blender/lobby_v3")
    import lv3_core as C, lv3_hub
Units: 1 Blender unit = 1 stud. X east, Y north, Z up (Roblox Z = -Blender Y).
Plan and rules: vault/02 Art/Lobby V3 Rebuild.md
"""
import bpy
import bmesh
from math import sin, cos, pi, radians, sqrt, atan2, asin, acos
from mathutils import Vector, Matrix

ROOT = "LobbyV3"
D = radians

# Wing accents (one per wing, used nowhere else)
ACCENT = {
	"Duels": "#FF5A36",
	"Market": "#F2B33D",
	"Vault": "#3DD9F2",
	"Range": "#58E07A",
	"Gauntlet": "#B3262E",
	"Warm": "#FFE6CC",
	"Cool": "#B8D4FF",
}


def lin(h):
	h = h.lstrip("#")
	c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	f = lambda u: u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4
	return (f(c[0]), f(c[1]), f(c[2]), 1.0)


# ---------------------------------------------------------------- collections
def coll(name, parent=None):
	c = bpy.data.collections.get(name)
	if not c:
		c = bpy.data.collections.new(name)
		(parent or bpy.context.scene.collection).children.link(c)
	return c


def root():
	return coll(ROOT)


def clear(name):
	c = bpy.data.collections.get(name)
	if not c:
		return
	for o in list(c.objects):
		data = o.data
		bpy.data.objects.remove(o, do_unlink=True)
		if data is not None and data.users == 0:
			if isinstance(data, bpy.types.Mesh):
				bpy.data.meshes.remove(data)
			elif isinstance(data, bpy.types.Light):
				bpy.data.lights.remove(data)
			elif isinstance(data, bpy.types.Camera):
				bpy.data.cameras.remove(data)


# ---------------------------------------------------------------- materials
MATS = {}


def _new(name):
	m = bpy.data.materials.get(name)
	if m:
		bpy.data.materials.remove(m)
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	m.node_tree.nodes.clear()
	MATS[name] = m
	return m, m.node_tree


def surface(
	name,
	color,
	rough=0.8,
	metal=0.0,
	var=0.10,
	bump=0.3,
	grain=6.0,
	seams=None,
	ao=0.4,
	streak=0.0,
	stripe=None,
	emit=0.0,
	grime=None,
):
	"""Procedural world-space surface. seams = dict(mode, h, v, w, dark, cx, cy, rref, n)."""
	m, nt = _new(name)
	N, L = nt.nodes, nt.links

	def mt(op, a, b=None, c=None, clamp=False):
		n = N.new("ShaderNodeMath")
		n.operation = op
		n.use_clamp = clamp
		for i, v in enumerate((a, b, c)):
			if v is None:
				continue
			if isinstance(v, (int, float)):
				n.inputs[i].default_value = v
			else:
				L.new(v, n.inputs[i])
		return n.outputs[0]

	geo = N.new("ShaderNodeNewGeometry")
	sp = N.new("ShaderNodeSeparateXYZ")
	L.new(geo.outputs["Position"], sp.inputs[0])
	px, py, pz = sp.outputs[0], sp.outputs[1], sp.outputs[2]
	sn = N.new("ShaderNodeSeparateXYZ")
	L.new(geo.outputs["True Normal"], sn.inputs[0])
	anx = mt("ABSOLUTE", sn.outputs[0])
	anz = mt("ABSOLUTE", sn.outputs[2])
	vertical = mt("LESS_THAN", anz, 0.5)
	horizontal = mt("GREATER_THAN", anz, 0.5)

	def lines(coord, period, w):
		d = mt("PINGPONG", mt("DIVIDE", coord, period), 0.5)
		return mt("LESS_THAN", mt("MULTIPLY", d, period), w)

	s = seams or {}
	mode = s.get("mode")
	w = s.get("w", 0.05)
	cx, cy = s.get("cx", 0.0), s.get("cy", 0.0)
	dx, dy = mt("SUBTRACT", px, cx), mt("SUBTRACT", py, cy)
	# coordinate that runs along a wall
	if mode in ("polar_wall", "polar_slats"):
		along = mt("MULTIPLY", mt("ARCTAN2", dy, dx), s.get("rref", 38.0))
	else:
		sel = mt("GREATER_THAN", anx, 0.707)
		along = mt("ADD", mt("MULTIPLY", py, sel), mt("MULTIPLY", px, mt("SUBTRACT", 1.0, sel)))
	mask = None
	slat_id = None
	if mode in ("wall", "polar_wall"):
		hz = lines(mt("SUBTRACT", pz, s.get("z0", 0.0)), s.get("h", 4.0), w)
		vt = lines(along, s.get("v", 8.0), w)
		mask = mt("MAXIMUM", hz, vt)
		# formwork tie holes: two per panel
		hh, vv = s.get("h", 4.0), s.get("v", 8.0)
		fx = mt("FRACT", mt("DIVIDE", along, vv))
		fz = mt("FRACT", mt("DIVIDE", mt("SUBTRACT", pz, s.get("z0", 0.0)), hh))
		ux = mt("MULTIPLY", mt("SUBTRACT", mt("ABSOLUTE", mt("SUBTRACT", fx, 0.5)), 0.25), vv)
		uz = mt("MULTIPLY", mt("SUBTRACT", fz, 0.5), hh)
		hole = mt("LESS_THAN", mt("SQRT", mt("ADD", mt("MULTIPLY", ux, ux), mt("MULTIPLY", uz, uz))), 0.16)
		mask = mt("MULTIPLY", mask, vertical)
	elif mode in ("slats", "polar_slats"):
		per = s.get("v", 0.9)
		mask = mt("MULTIPLY", lines(along, per, w), vertical)
		slat_id = mt("FLOOR", mt("DIVIDE", along, per))
	elif mode == "floor":
		a = lines(mt("SUBTRACT", px, s.get("ox", 0.0)), s.get("h", 4.0), w)
		b = lines(mt("SUBTRACT", py, s.get("oy", 0.0)), s.get("v", 4.0), w)
		mask = mt("MULTIPLY", mt("MAXIMUM", a, b), horizontal)
	elif mode == "polar_floor":
		r = mt("SQRT", mt("ADD", mt("MULTIPLY", dx, dx), mt("MULTIPLY", dy, dy)))
		rings = lines(r, s.get("h", 5.0), w)
		per = 2 * pi / s.get("n", 32)
		da = mt("PINGPONG", mt("DIVIDE", mt("ARCTAN2", dy, dx), per), 0.5)
		rad = mt("LESS_THAN", mt("MULTIPLY", mt("MULTIPLY", da, per), r), w)
		mask = mt("MULTIPLY", mt("MAXIMUM", rings, rad), horizontal)

	# value variation: big blotches + fine grain
	n1 = N.new("ShaderNodeTexNoise")
	n1.inputs["Scale"].default_value = 0.07
	n1.inputs["Detail"].default_value = 5.0
	L.new(geo.outputs["Position"], n1.inputs["Vector"])
	n2 = N.new("ShaderNodeTexNoise")
	n2.inputs["Scale"].default_value = grain
	n2.inputs["Detail"].default_value = 3.0
	L.new(geo.outputs["Position"], n2.inputs["Vector"])
	big = n1.outputs[0]
	fine = n2.outputs[0]
	vfac = mt("ADD", 1.0 - var, mt("MULTIPLY", big, 2.0 * var))
	vfac = mt("MULTIPLY", vfac, mt("ADD", 0.94, mt("MULTIPLY", fine, 0.12)))
	if slat_id is not None:
		wn = N.new("ShaderNodeTexWhiteNoise")
		wn.noise_dimensions = "1D"
		L.new(slat_id, wn.inputs["W"])
		vfac = mt("MULTIPLY", vfac, mt("ADD", 0.82, mt("MULTIPLY", wn.outputs[0], 0.36)))
	if streak > 0:
		vm = N.new("ShaderNodeVectorMath")
		vm.operation = "MULTIPLY"
		L.new(geo.outputs["Position"], vm.inputs[0])
		vm.inputs[1].default_value = (0.9, 0.9, 0.06)
		n3 = N.new("ShaderNodeTexNoise")
		n3.inputs["Scale"].default_value = 1.0
		n3.inputs["Detail"].default_value = 4.0
		L.new(vm.outputs[0], n3.inputs["Vector"])
		st = mt("MULTIPLY", mt("SUBTRACT", n3.outputs[0], 0.5), 2.0 * streak)
		vfac = mt("MULTIPLY", vfac, mt("SUBTRACT", 1.0, mt("MULTIPLY", st, vertical)))
	if grime:
		gz, gh, ga = grime
		g = mt("SUBTRACT", 1.0, mt("DIVIDE", mt("SUBTRACT", pz, gz), gh), clamp=True)
		g = mt("MULTIPLY", mt("MULTIPLY", g, g), mt("ADD", 0.5, big))
		vfac = mt("MULTIPLY", vfac, mt("SUBTRACT", 1.0, mt("MULTIPLY", mt("MULTIPLY", g, vertical), ga)))
	if mask is not None:
		vfac = mt("MULTIPLY", vfac, mt("SUBTRACT", 1.0, mt("MULTIPLY", mask, s.get("dark", 0.45))))
	if ao > 0:
		aon = N.new("ShaderNodeAmbientOcclusion")
		aon.samples = 6
		aon.inputs["Distance"].default_value = 2.0
		occ = mt("SUBTRACT", 1.0, aon.outputs["AO"])
		vfac = mt("MULTIPLY", vfac, mt("SUBTRACT", 1.0, mt("MULTIPLY", occ, ao)))

	base_col = None
	if stripe:
		c2, per = stripe
		sm = lines(mt("ADD", along, pz), per, per * 0.25)
		mix = N.new("ShaderNodeMix")
		mix.data_type = "RGBA"
		L.new(sm, mix.inputs[0])
		mix.inputs[6].default_value = lin(color)
		mix.inputs[7].default_value = lin(c2)
		base_col = mix.outputs[2]
	hsv = N.new("ShaderNodeHueSaturation")
	if base_col is not None:
		L.new(base_col, hsv.inputs["Color"])
	else:
		hsv.inputs["Color"].default_value = lin(color)
	L.new(vfac, hsv.inputs["Value"])

	bs = N.new("ShaderNodeBsdfPrincipled")
	L.new(hsv.outputs[0], bs.inputs["Base Color"])
	bs.inputs["Metallic"].default_value = metal
	L.new(mt("ADD", rough - 0.08, mt("MULTIPLY", big, 0.16)), bs.inputs["Roughness"])
	if bump > 0:
		h = mt("MULTIPLY", fine, 0.6)
		h = mt("ADD", h, mt("MULTIPLY", big, 0.8))
		if mask is not None:
			h = mt("SUBTRACT", h, mt("MULTIPLY", mask, 1.5))
		bp = N.new("ShaderNodeBump")
		bp.inputs["Strength"].default_value = bump
		bp.inputs["Distance"].default_value = 0.12
		L.new(h, bp.inputs["Height"])
		L.new(bp.outputs[0], bs.inputs["Normal"])
	if emit > 0:
		bs.inputs["Emission Color"].default_value = lin(color)
		bs.inputs["Emission Strength"].default_value = emit
	out = N.new("ShaderNodeOutputMaterial")
	L.new(bs.outputs[0], out.inputs[0])
	return m


def emission(name, color, strength):
	m, nt = _new(name)
	e = nt.nodes.new("ShaderNodeEmission")
	e.inputs["Color"].default_value = lin(color)
	e.inputs["Strength"].default_value = strength
	o = nt.nodes.new("ShaderNodeOutputMaterial")
	nt.links.new(e.outputs[0], o.inputs[0])
	return m


def glass(name, color="#BFD8E0"):
	m, nt = _new(name)
	bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
	bs.inputs["Base Color"].default_value = lin(color)
	bs.inputs["Roughness"].default_value = 0.03
	bs.inputs["Transmission Weight"].default_value = 1.0
	bs.inputs["IOR"].default_value = 1.15
	o = nt.nodes.new("ShaderNodeOutputMaterial")
	nt.links.new(bs.outputs[0], o.inputs[0])
	return m


def make_materials():
	W = dict(mode="wall", h=4.0, v=8.0, w=0.05, dark=0.4)
	PW = dict(mode="polar_wall", h=4.0, v=8.0, w=0.05, dark=0.4, rref=38.0)
	surface("Concrete", "#8F8D88", 0.85, seams=W, streak=0.2, grime=(0.0, 3.0, 0.3))
	surface("ConcreteHub", "#8F8D88", 0.85, seams=PW, streak=0.2, grime=(0.0, 3.0, 0.3))
	surface("ConcreteLight", "#B5B0A6", 0.85, seams=W, streak=0.15, grime=(0.0, 3.0, 0.25))
	surface("ConcreteDark", "#55524E", 0.8, var=0.08)
	surface("ConcreteCeil", "#8A847B", 0.9, var=0.08)
	surface("FloorHub", "#8E8C86", 0.42, seams=dict(mode="polar_floor", h=3.5, n=40, w=0.04, dark=0.35), bump=0.15)
	surface("SunStone", "#A89F8C", 0.5, seams=dict(mode="polar_floor", h=3.6, n=24, w=0.05, dark=0.3), bump=0.15)
	surface("FloorDark", "#3C3E42", 0.4, seams=dict(mode="floor", h=4, v=4, w=0.04, dark=0.4), bump=0.12)
	surface("FloorPale", "#B9AE9C", 0.45, seams=dict(mode="floor", h=6, v=6, w=0.05, dark=0.3), bump=0.12)
	surface("Rubber", "#2A2C2F", 0.75, seams=dict(mode="floor", h=3, v=3, w=0.06, dark=0.35), bump=0.2)
	surface("Steel", "#22252A", 0.42, metal=0.9, var=0.06, bump=0.08, ao=0.4)
	surface("SteelBlue", "#34495A", 0.5, metal=0.35, var=0.08, bump=0.1, ao=0.45, streak=0.06)
	surface("Brushed", "#9EA3A9", 0.32, metal=1.0, var=0.05, bump=0.05, ao=0.4)
	surface("VaultPanel", "#7C858E", 0.38, metal=0.9, var=0.05, bump=0.05, ao=0.45,
		seams=dict(mode="polar_wall", h=5.0, v=4.4, w=0.05, dark=0.5, rref=26.0, cx=73.0, cy=0.0))
	surface("Brass", "#B8873F", 0.3, metal=1.0, var=0.05, bump=0.04, ao=0.3)
	surface("Rock", "#57534E", 0.95, var=0.18, bump=1.0, grain=0.9, ao=0.6)
	surface("RockDark", "#34332F", 0.95, var=0.18, bump=1.0, grain=0.9, ao=0.6)
	surface("Oak", "#A0703F", 0.55, var=0.08, seams=dict(mode="slats", v=0.9, w=0.09, dark=0.75), bump=0.2)
	surface("OakDark", "#5F4127", 0.6, var=0.1, bump=0.2)
	surface("Plaster", "#D2C4AA", 0.9, var=0.06, bump=0.12, streak=0.05)
	surface("Hazard", "#C98A2B", 0.6, stripe=("#1E1F22", 1.6), var=0.06, bump=0.08, ao=0.4)
	surface("Seam", "#8F887C", 0.8, var=0.04, bump=0.0, ao=0.2)
	surface("HazardBlack", "#1E1F22", 0.6, var=0.05, bump=0.05, ao=0.3)
	surface("Screen", "#1B2026", 0.22, var=0.0, bump=0.0, ao=0.0)
	surface("P_White", "#DAD7CF", 0.55, var=0.12, bump=0.06, ao=0.3)
	surface("Dummy", "#E8E2D6", 0.7, var=0.0, bump=0.0, ao=0.3)
	surface("Bedrock", "#050505", 1.0, var=0.0, bump=0.0, ao=0.0)
	glass("Glass")
	emission("E_Warm", ACCENT["Warm"], 5.0)  # visible diffusers: soft, never neon
	emission("E_Cool", ACCENT["Cool"], 5.0)
	emission("E_Cove", ACCENT["Warm"], 110.0)  # hidden cove sources only
	emission("E_CoveCool", ACCENT["Cool"], 110.0)
	emission("E_Down", ACCENT["Warm"], 260.0)  # small recessed downlights
	emission("E_Sky", "#CFE4FF", 3.0)
	for k in ("Duels", "Market", "Vault", "Range", "Gauntlet"):
		emission("E_" + k, ACCENT[k], 7.0)
		emission("S_" + k, ACCENT[k], 1.6)  # dim screen stand-in
		surface("P_" + k, ACCENT[k], 0.55, var=0.1, bump=0.08, ao=0.45)  # paint, not light
		surface("Trim_" + k, ACCENT[k], 0.5, var=0.06, bump=0.05, ao=0.4)  # wing-coloured structure with soft edges
		BEVEL["Trim_" + k] = 0.16
	return MATS


def mat(name):
	return bpy.data.materials[name]


# default edge softness per material (studs). Big soft edges on structure, small on trims.
BEVEL = {
	"Concrete": 0.4, "ConcreteHub": 0.4, "ConcreteLight": 0.4, "ConcreteDark": 0.35, "ConcreteCeil": 0.35,
	"Plaster": 0.4, "Rock": 0.5, "RockDark": 0.5,
	"FloorHub": 0.06, "SunStone": 0.06, "FloorDark": 0.06, "FloorPale": 0.06, "Rubber": 0.06,
	"Steel": 0.14, "SteelBlue": 0.16, "Brushed": 0.1, "VaultPanel": 0.12, "Brass": 0.05, "Oak": 0.1, "OakDark": 0.18,
	"Hazard": 0.14, "P_White": 0.0, "HazardBlack": 0.0, "Seam": 0.0, "Screen": 0.04, "Dummy": 0.12, "Glass": 0.0, "Bedrock": 0.0,
}


# ---------------------------------------------------------------- mesh builder
# ---------------------------------------------------------------- collision (for Studio)
# Opaque collider parts that sit just inside the visible solids, so players and the camera stop at them
# while nothing of them can be seen. Stored in Roblox coordinates (X, Y, Z) = (Bx, Bz, -By):
# [kind, sx, sy, sz, px, py, pz, xx, xy, xz, yx, yy, yz]; kind B box, W wedge, C cylinder (axis = local X).
COLLISION = {}
INSET = 0.04
MIN_DIM = 0.22
SEG = radians(7.5)
NO_COLLIDE = {"Screen", "ScreenOn", "Dummy", "Bedrock", "HazardBlack", "Seam"}


def _rb(v):
	return (v[0], v[2], -v[1])


def _emit(area, kind, size, pos, vx, vy):
	if min(size) < 0.05:
		return
	row = [kind] + [round(float(x), 3) for x in (*size, *_rb(pos), *_rb(vx), *_rb(vy))]
	COLLISION.setdefault(area, []).append(row)


def _inset_poly(pts, d):
	n = len(pts)
	out = []
	for i in range(n):
		p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
		e1, e2 = (p1 - p0).normalized(), (p2 - p1).normalized()
		n1, n2 = Vector((-e1.y, e1.x)), Vector((-e2.y, e2.x))  # inward for a CCW polygon
		k = 1.0 + n1.dot(n2)
		m = (n1 + n2) * (d / k) if k > 0.15 else (n1 + n2).normalized() * (3 * d) if (n1 + n2).length > 1e-6 else n1 * d
		out.append(p1 + m)
	return out


SPLIT_FACES = 1100  # base faces per exported object (bevels multiply this several times)


def collider_cyl(area, cx, cy, r, z0, z1, kind="C"):
	"""A hand-placed static collider (for moving props, which record none of their own).
	kind "C" is opaque and must sit inside a visible mesh; kind "X" is invisible (keeps players out of a display)."""
	_emit(area, kind, (z1 - z0, 2 * r, 2 * r), Vector((cx, cy, (z0 + z1) / 2)), Vector((0, 0, 1)), Vector((1, 0, 0)))


def collider_box(area, M, x0, x1, y0, y1, z0, z1, kind="Y"):
	"""A hand-placed box collider in the frame M. Kind "Y" is invisible (thin pads, glass); "B" must hide inside a mesh."""
	R = M.to_3x3()
	_emit(area, kind, (x1 - x0, y1 - y0, z1 - z0), M @ Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)), R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)))


class B:
	"""Accumulates closed solids into one mesh. All points pass through the current frame."""

	def __init__(self, name, col, material, rot=0.0, bevel=None):
		self.bm = bmesh.new()
		self.name, self.col, self.material = name, col, material
		self.base = Matrix.Rotation(rot, 4, "Z")
		self.M = self.base
		self.bevel = BEVEL.get(material.name, 0.0) if bevel is None else bevel
		mn = material.name
		self.collide = not (mn in NO_COLLIDE or mn[:2] in ("E_", "S_", "P_", "L_"))
		self.area = col.name.replace("_Ceil", "")
		self.ckind = "Y" if mn == "Glass" else "B"  # glass: invisible box colliders (an opaque one would show through)
		# a box inset by d clears a rounded bevel of width w when d >= 0.3 w (two segments) or 0.5 w (one)
		self.inset = max(0.04, self.bevel * (0.32 if self.bevel >= 0.3 else 0.52)) + 0.012

	# collision records
	def _c_box(self, x0, x1, y0, y1, z0, z1):
		d = (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0))
		if not self.collide or min(d) < MIN_DIM:
			return
		R = self.M.to_3x3()
		_emit(self.area, self.ckind, [v - 2 * self.inset for v in d], self.M @ Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)),
			R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)))

	def _c_prism(self, pts, lo, hi, U, V, W):
		if not self.collide:
			return
		lo, hi = min(lo, hi), max(lo, hi)
		q = []
		for p in pts:
			if not q or (Vector(p) - Vector(q[-1])).length > 1e-5:
				q.append(tuple(p))
		if len(q) > 1 and (Vector(q[0]) - Vector(q[-1])).length < 1e-5:
			q.pop()
		if len(q) < 3:
			return
		us, vs = [a for a, _ in q], [b for _, b in q]
		if min(hi - lo, max(us) - min(us), max(vs) - min(vs)) < MIN_DIM or hi - lo - 2 * self.inset < 0.05:
			return
		R = self.M.to_3x3()
		U, V, W = Vector(U), Vector(V), Vector(W)
		rect = len(q) == 4 and all(abs(q[i][0] - q[i - 1][0]) < 1e-6 or abs(q[i][1] - q[i - 1][1]) < 1e-6 for i in range(4))
		if rect:
			c = U * ((max(us) + min(us)) / 2) + V * ((max(vs) + min(vs)) / 2) + W * ((lo + hi) / 2)
			_emit(self.area, self.ckind, (max(us) - min(us) - 2 * self.inset, max(vs) - min(vs) - 2 * self.inset, hi - lo - 2 * self.inset), self.M @ c, R @ U, R @ V)
			return
		area2 = sum(q[i - 1][0] * q[i][1] - q[i][0] * q[i - 1][1] for i in range(len(q)))
		if area2 < 0:
			q.reverse()
		ins = _inset_poly(q, self.inset)
		from mathutils.geometry import tessellate_polygon
		tris = tessellate_polygon([[Vector((a.x, a.y, 0.0)) for a in ins]])
		f = lambda v: Vector(_rb(v))
		e = f((R @ W) * (hi - lo - 2 * self.inset))
		t = e.length
		for tri in tris:
			a, b, c = (f(self.M @ (U * ins[i].x + V * ins[i].y + W * (lo + self.inset))) for i in tri)
			ab, ac, bc = b - a, c - a, c - b
			abd, acd, bcd = ab.dot(ab), ac.dot(ac), bc.dot(bc)
			if abd > acd and abd > bcd:
				c, a = a, c
			elif acd > bcd and acd > abd:
				a, b = b, a
			ab, ac, bc = b - a, c - a, c - b
			nrm = ac.cross(ab)
			if nrm.length < 1e-4 or bc.length < 1e-4:
				continue
			right = nrm.normalized()
			up = bc.cross(right).normalized()
			back = bc.normalized()
			h = abs(ab.dot(up))
			if h < 0.03:
				continue
			for mid, ln, rr, sg in (((a + b) / 2, abs(ab.dot(back)), right, 1), ((a + c) / 2, abs(ac.dot(back)), -right, -1)):
				if ln < 0.03:
					continue
				pos = mid + e / 2
				COLLISION.setdefault(self.area, []).append(["W"] + [round(float(x), 3) for x in (t, h, ln, *pos, *rr, *up)])

	def _c_lathe(self, prof, a0, a1, cx, cy):
		if not self.collide:
			return
		if a1 < a0:
			a0, a1 = a1, a0
		span = a1 - a0
		full = span >= 2 * pi - 1e-6
		zs = sorted({round(z, 4) for _, z in prof})
		R = self.M.to_3x3()
		m = len(prof)
		for zlo, zhi in zip(zs, zs[1:]):
			if zhi - zlo < MIN_DIM:
				continue
			zm = (zlo + zhi) / 2
			xs = []
			for i in range(m):
				(r1, z1), (r2, z2) = prof[i], prof[(i + 1) % m]
				if (z1 > zm) != (z2 > zm):
					xs.append(r1 + (r2 - r1) * (zm - z1) / (z2 - z1))
			xs.sort()
			for r0, r1 in zip(xs[0::2], xs[1::2]):
				if r1 - r0 < MIN_DIM:
					continue
				segang = max(radians(2.4), min(SEG, 2 * acos(max(-1.0, 1 - 0.04 / max(r1, 0.5)))))
				nseg = max(24 if full else 1, int(span / segang + 0.999))
				seg = span / nseg
				half = seg / 2
				rin, rout = r0 + self.inset, r1 * cos(half) - self.inset
				if rout - rin < 0.06 or zhi - zlo - 2 * self.inset < 0.05:
					continue
				for i in range(nseg):
					am = a0 + (i + 0.5) * seg
					wide = full or 0 < i < nseg - 1
					hw = (r1 * sin(half) if wide else rin * sin(half) / cos(half)) - self.inset
					if hw < 0.05:
						continue
					rc = (rin + rout) / 2
					rad, tan = Vector((cos(am), sin(am), 0)), Vector((-sin(am), cos(am), 0))
					c = Vector((cx, cy, zm)) + rad * rc
					_emit(self.area, self.ckind, (rout - rin, 2 * hw, zhi - zlo - 2 * self.inset), self.M @ c, R @ rad, R @ tan)

	def _c_cyl(self, cx, cy, r, z0, z1, n):
		rr = r * cos(pi / n) - self.inset
		if not self.collide or abs(z1 - z0) < MIN_DIM or rr < 0.2:
			return
		R = self.M.to_3x3()
		_emit(self.area, "C", (abs(z1 - z0) - 2 * self.inset, 2 * rr, 2 * rr), self.M @ Vector((cx, cy, (z0 + z1) / 2)),
			R @ Vector((0, 0, 1)), R @ Vector((1, 0, 0)))

	# frames
	def frame(self, ang=0.0, x=0.0, y=0.0, z=0.0):
		self.M = self.base @ Matrix.Translation((x, y, z)) @ Matrix.Rotation(ang, 4, "Z")
		return self

	def framem(self, m):
		self.M = self.base @ m
		return self

	def reset(self):
		self.M = self.base
		return self

	# primitives
	def solid(self, a, b):
		va = [self.bm.verts.new(self.M @ Vector(p)) for p in a]
		vb = [self.bm.verts.new(self.M @ Vector(p)) for p in b]
		n = len(va)
		self.bm.faces.new(va[::-1])
		self.bm.faces.new(vb)
		for i in range(n):
			j = (i + 1) % n
			self.bm.faces.new((va[i], va[j], vb[j], vb[i]))
		return self

	def box(self, x0, x1, y0, y1, z0, z1):
		r = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
		self._c_box(x0, x1, y0, y1, z0, z1)
		return self.solid([(x, y, z0) for x, y in r], [(x, y, z1) for x, y in r])

	def prism(self, poly, z0, z1):
		self._c_prism(poly, z0, z1, (1, 0, 0), (0, 1, 0), (0, 0, 1))
		return self.solid([(x, y, z0) for x, y in poly], [(x, y, z1) for x, y in poly])

	def taper(self, r0, z0, r1, z1):
		"""r = (x0, x1, y0, y1) rectangles at two heights."""
		q = lambda r, z: [(r[0], r[2], z), (r[1], r[2], z), (r[1], r[3], z), (r[0], r[3], z)]
		self._c_box(max(min(r0[:2]), min(r1[:2])), min(max(r0[:2]), max(r1[:2])), max(min(r0[2:]), min(r1[2:])), min(max(r0[2:]), max(r1[2:])), z0, z1)
		return self.solid(q(r0, z0), q(r1, z1))

	def ext_y(self, prof, y0, y1):
		self._c_prism(prof, y0, y1, (1, 0, 0), (0, 0, 1), (0, 1, 0))
		return self.solid([(x, y0, z) for x, z in prof], [(x, y1, z) for x, z in prof])

	def ext_x(self, prof, x0, x1):
		self._c_prism(prof, x0, x1, (0, 1, 0), (0, 0, 1), (1, 0, 0))
		return self.solid([(x0, y, z) for y, z in prof], [(x1, y, z) for y, z in prof])

	def lathe(self, prof, a0=0.0, a1=2 * pi, n=None, cx=0.0, cy=0.0):
		self._c_lathe(prof, a0, a1, cx, cy)
		full = abs((a1 - a0) - 2 * pi) < 1e-6
		if n is None:
			n = max(2, round(96 * abs(a1 - a0) / (2 * pi)))
		cnt = n if full else n + 1
		rings = []
		for i in range(cnt):
			a = a0 + (a1 - a0) * i / n
			rings.append([self.bm.verts.new(self.M @ Vector((cx + r * cos(a), cy + r * sin(a), z))) for r, z in prof])
		m = len(prof)
		for i in range(n):
			ra, rb = rings[i], rings[(i + 1) % cnt]
			for k in range(m):
				k2 = (k + 1) % m
				self.bm.faces.new((ra[k], ra[k2], rb[k2], rb[k]))
		if not full:
			self.bm.faces.new(rings[0])
			self.bm.faces.new(rings[-1][::-1])
		return self

	def ring(self, r0, r1, z0, z1, a0=0.0, a1=2 * pi, n=None, cx=0.0, cy=0.0):
		return self.lathe([(r0, z0), (r1, z0), (r1, z1), (r0, z1)], a0, a1, n, cx, cy)

	def disc(self, r, z0, z1, n=64, cx=0.0, cy=0.0, r1=None):
		a = [(cx + r * cos(2 * pi * i / n), cy + r * sin(2 * pi * i / n), z0) for i in range(n)]
		rr = r if r1 is None else r1
		self._c_cyl(cx, cy, min(r, rr), z0, z1, n)
		b = [(cx + rr * cos(2 * pi * i / n), cy + rr * sin(2 * pi * i / n), z1) for i in range(n)]
		return self.solid(a, b)

	def band_y(self, cx, cz, r0, r1, a0, a1, n, y0, y1):
		"""Arc band of n separate blocks in the XZ plane (voussoirs), extruded along Y."""
		for i in range(n):
			p, q = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
			self.ext_y(
				[(cx + r0 * cos(p), cz + r0 * sin(p)), (cx + r1 * cos(p), cz + r1 * sin(p)),
				 (cx + r1 * cos(q), cz + r1 * sin(q)), (cx + r0 * cos(q), cz + r0 * sin(q))], y0, y1)
		return self

	def pipe(self, p0, p1, r, n=12):
		p0, p1 = Vector(p0), Vector(p1)
		d = (p1 - p0).normalized()
		up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
		u = d.cross(up).normalized()
		v = d.cross(u)
		a = [p0 + u * (r * cos(2 * pi * i / n)) + v * (r * sin(2 * pi * i / n)) for i in range(n)]
		return self.solid(a, [p + (p1 - p0) for p in a])

	def done(self):
		if not self.bm.faces:
			self.bm.free()
			return None
		bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
		self.bm.faces.ensure_lookup_table()
		if len(self.bm.faces) > SPLIT_FACES:
			return self._done_split()
		return self._finish(self.bm, self.name)

	def _done_split(self):
		bm = self.bm
		seen, groups = set(), []
		for f in bm.faces:  # islands in creation order
			if f.index in seen:
				continue
			stack, isl = [f], []
			seen.add(f.index)
			while stack:
				g = stack.pop()
				isl.append(g)
				for e in g.edges:
					for h in e.link_faces:
						if h.index not in seen:
							seen.add(h.index)
							stack.append(h)
			groups.append(isl)
		chunks, cur, cnt = [], [], 0
		for isl in groups:
			if cur and cnt + len(isl) > SPLIT_FACES:
				chunks.append(cur)
				cur, cnt = [], 0
			cur.extend(isl)
			cnt += len(isl)
		if cur:
			chunks.append(cur)
		obs = []
		for k, faces in enumerate(chunks):
			nb = bmesh.new()
			vmap = {}
			for f in faces:
				nb.faces.new([vmap.setdefault(v.index, nb.verts.new(v.co)) if v.index not in vmap else vmap[v.index] for v in f.verts])
			bmesh.ops.recalc_face_normals(nb, faces=nb.faces[:])
			obs.append(self._finish(nb, self.name if k == 0 else f"{self.name}_{k + 1}"))
		bm.free()
		return obs[0]

	def _finish(self, bm, name):
		me = bpy.data.meshes.new(name)
		bm.to_mesh(me)
		bm.free()
		ob = bpy.data.objects.new(name, me)
		self.col.objects.link(ob)
		me.materials.append(self.material)
		me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
		me.set_sharp_from_angle(angle=radians(40))
		if self.bevel > 0:
			md = ob.modifiers.new("Bevel", "BEVEL")
			md.width = self.bevel
			md.segments = 2 if self.bevel >= 0.3 else 1
			md.limit_method = "ANGLE"
			md.angle_limit = radians(40)
			md.harden_normals = True
		return ob


class Kit:
	"""One builder per material inside a collection: K['Concrete'].box(...)."""

	def __init__(self, col, rot=0.0, prefix=None):
		self.col, self.rot = col, rot
		self.prefix = prefix or col.name
		self.b = {}

	def __getitem__(self, m):
		if m not in self.b:
			self.b[m] = B(f"{self.prefix}_{m}", self.col, mat(m), self.rot)
			if getattr(self, "nocol", False):
				self.b[m].collide = False
		return self.b[m].reset()

	def done(self):
		return [b.done() for b in self.b.values()]


def hazard(K, x0, x1, y0, y1, z0, z1):
	"""Ochre block with black bands along its longest side (real geometry: paint does not survive the import)."""
	x0, x1, y0, y1, z0, z1 = min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1), min(z0, z1), max(z0, z1)
	K["Hazard"].box(x0, x1, y0, y1, z0, z1)
	lo, hi = [x0, y0, z0], [x1, y1, z1]
	ax = max(range(3), key=lambda i: hi[i] - lo[i])
	L = hi[ax] - lo[ax]
	pitch = 1.6 if L >= 3.2 else L / 2
	e = 0.025
	k = 0
	while lo[ax] + (k + 0.5) * pitch < hi[ax] - 1e-6:
		a, b = lo[:], hi[:]
		for i in range(3):
			if i != ax:
				a[i] -= e
				b[i] += e
		a[ax] = lo[ax] + (k + 0.5) * pitch
		b[ax] = min(hi[ax] - 0.03, lo[ax] + (k + 1) * pitch)
		if b[ax] - a[ax] < 0.08:
			break
		K["HazardBlack"].box(a[0], b[0], a[1], b[1], a[2], b[2])
		k += 1


# ---------------------------------------------------------------- profiles
def arch_opening(W, H, w, spring, n=24, x0=0.0):
	"""Wall W x H (centred on x0) with a round-arched opening of width w that touches the floor."""
	r = w / 2
	pts = [(x0 - W / 2, 0), (x0 - r, 0)]
	for i in range(n + 1):
		a = pi - pi * i / n
		pts.append((x0 + r * cos(a), spring + r * sin(a)))
	pts += [(x0 + r, 0), (x0 + W / 2, 0), (x0 + W / 2, H), (x0 - W / 2, H)]
	return pts


def cham_opening(W, H, w, h, c, z0=0.0):
	"""Wall W x H with a chamfer-cornered opening w x h (c = 0 gives a plain rectangle)."""
	a = w / 2
	inner = [(-a, z0), (-a, h - c), (-a + c, h), (a - c, h), (a, h - c), (a, z0)] if c > 0 else [(-a, z0), (-a, h), (a, h), (a, z0)]
	return [(-W / 2, z0)] + inner + [(W / 2, z0), (W / 2, H), (-W / 2, H)]


def round_opening(W, H, R, zc, n=40):
	"""Wall W x H with a circular opening (radius R, centre height zc) cut by the floor."""
	c = sqrt(R * R - zc * zc)
	a0 = 2 * pi + atan2(-zc, -c)
	a1 = atan2(-zc, c)
	pts = [(-W / 2, 0)]
	for i in range(n + 1):
		a = a0 + (a1 - a0) * i / n
		pts.append((R * cos(a), zc + R * sin(a)))
	pts += [(W / 2, 0), (W / 2, H), (-W / 2, H)]
	return pts


def dummy(K, x, y, z, yaw=0.0):
	"""Blocky 5.2-stud avatar for scale."""
	b = K["Dummy"].frame(yaw, x, y, z)
	b.box(-1.0, -0.05, -0.5, 0.5, 0, 2)
	b.box(0.05, 1.0, -0.5, 0.5, 0, 2)
	b.box(-1.0, 1.0, -0.5, 0.5, 2.05, 4)
	b.box(-2.0, -1.05, -0.5, 0.5, 2.05, 4)
	b.box(1.05, 2.0, -0.5, 0.5, 2.05, 4)
	b.box(-0.6, 0.6, -0.6, 0.6, 4.05, 5.25)
	b.reset()


# ---------------------------------------------------------------- lights, cameras, render
def light(col, name, kind, loc, color, energy, size=1.0, rot=None, spot=None):
	ld = bpy.data.lights.new(name, kind)
	ld.color = lin(color)[:3]
	ld.energy = energy
	if kind == "SUN":
		ld.angle = radians(size)
	elif kind == "AREA":
		ld.size = size
	else:
		ld.shadow_soft_size = size
	if kind == "SPOT" and spot:
		ld.spot_size = radians(spot)
		ld.spot_blend = 0.5
	ob = bpy.data.objects.new(name, ld)
	ob.location = loc
	if rot:
		ob.rotation_euler = [radians(a) for a in rot]
	col.objects.link(ob)
	return ob


def camera(name, loc, target, lens=16.0, ortho=None):
	col = coll("Cameras", root())
	old = bpy.data.objects.get(name)
	if old:
		cd = old.data
		bpy.data.objects.remove(old, do_unlink=True)
		bpy.data.cameras.remove(cd)
	cd = bpy.data.cameras.new(name)
	cd.lens = lens
	cd.clip_start, cd.clip_end = 0.2, 2000
	if ortho:
		cd.type = "ORTHO"
		cd.ortho_scale = ortho
	ob = bpy.data.objects.new(name, cd)
	ob.location = loc
	d = Vector(target) - Vector(loc)
	ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
	col.objects.link(ob)
	return ob


def setup_scene():
	sc = bpy.context.scene
	for n in ("Cube", "Light", "Camera"):
		o = bpy.data.objects.get(n)
		if o and o.users_collection and o.users_collection[0].name == "Collection":
			bpy.data.objects.remove(o, do_unlink=True)
	sc.unit_settings.system = "NONE"
	sc.render.engine = "CYCLES"
	prefs = bpy.context.preferences.addons["cycles"].preferences
	try:
		prefs.compute_device_type = "HIP"
		prefs.get_devices()
		for d in prefs.devices:
			d.use = d.type == "HIP" and "RX" in d.name
		sc.cycles.device = "GPU"
	except Exception:
		sc.cycles.device = "CPU"
	cy = sc.cycles
	cy.samples = 96
	cy.use_adaptive_sampling = True
	cy.adaptive_threshold = 0.03
	cy.use_denoising = True
	cy.max_bounces = 6
	cy.diffuse_bounces = 4
	cy.glossy_bounces = 3
	cy.sample_clamp_indirect = 8.0
	cy.caustics_reflective = False
	cy.caustics_refractive = False
	sc.render.resolution_x, sc.render.resolution_y = 1600, 900
	sc.render.resolution_percentage = 100
	sc.render.image_settings.file_format = "JPEG"
	sc.render.image_settings.quality = 90
	sc.view_settings.view_transform = "AgX"
	try:
		sc.view_settings.look = "AgX - Base Contrast"
	except Exception:
		pass
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	if bg:
		bg.inputs[0].default_value = lin("#BFD9FF")
		bg.inputs[1].default_value = 1.2
	root()


def render(cam_name, path, samples=None, res=None, exposure=0.0):
	sc = bpy.context.scene
	sc.camera = bpy.data.objects[cam_name]
	if samples:
		sc.cycles.samples = samples
	if res:
		sc.render.resolution_x, sc.render.resolution_y = res
	sc.view_settings.exposure = exposure
	sc.render.filepath = path
	bpy.ops.render.render(write_still=True)
	return path
