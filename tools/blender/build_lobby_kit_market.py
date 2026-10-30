# build_lobby_kit_market.py: the Lobby kit group "Market" (vault/02 Art/Lobby Kit.md, step 4).
#
# Every piece is a Lobby_<Piece> collection built at the world origin with the Lobby Kit conventions (1 unit = 1 stud,
# Blender +X = the piece's front, +Z up, Blender +Y = plan north). Objects are <Piece>_<Part>; Neon parts are separate
# *_Glow objects. The pieces are sized to dress the Market greybox (tools/studio/lobby/Wing_Market.luau), which stays
# the collision, so every visible face that a player can touch sits within -0.5..+0.3 of its collision face.
#
# Pieces (origins):
#   MarketRockWall_A..E   flat rock wall panel 12 wide x 34 tall over the honed plinth + glowing shadow gap. Origin on
#                         the floor ON THE WALL FACE (the collision face), centred, facing +X into the street. The rock
#                         stays within -0.4..+0.3 of the face up to y 9 (low relief where hands reach), then opens up to
#                         -0.7..+1.7 above y 13 (big blasted facets). Placed flat on straights and on the chords of the
#                         outer bend walls (R58), scaled along the wall to fit.
#   MarketRockCore_A/B    the same wall bent onto the convex inner bend wall (R14), spanning bearings 0..22.5 clockwise
#                         from north. Origin at the bend centre on the floor; the rock faces outward.
#   MarketRockCeiling_A/B 24 x 24 rock panel (all four edges held on its mid plane). Origin at the panel centre on its
#                         mid plane, facing +X (turned to face down for ceilings, sideways for bulkhead bands).
#   MarketRockSlab_A..C   leaning slab, nominal 4 thick (x) x 8 long (y) x 32 tall (z), origin at the bottom centre:
#                         fits the greybox slab box (scaled per slab in Studio).
#   MarketRockPillar_A/B  the greybox two-block pillar at w 5, roof 30 (block A 5 x 4 x 32 from y -1, block B
#                         3.5 x 5.5 x 18 turned 37 deg). Origin on the floor at the centre.
#   MarketRockDrop_A/B    hanging drop, nominal 5 x 4 x 12, tapering down. Origin at the TOP centre (hangs from it).
#   MarketRockHood        rock mass above a shop pavilion (10 deep x 17 wide x 12 tall). Origin at the bottom centre
#                         of its back face (on the wall face, at the pavilion top), facing +X.
#   MarketPortal          the deep concrete portal (26.54 x 16 opening, 12 deep, 44 wide x 24.5 face). Origin on the
#                         floor at the centre of its back (hub side) face; +X points into the Market.
#   ShopPavilion          16 wide x 10 deep x 14.6: concrete frame, oak slats, counter, vitrine, canopy blade, header
#                         sign frame. Origin on the floor on the wall face (back), centred, facing +X into the street.
#   FeaturedPodium        dia 10 floor ring, concrete drum, turntable, glass case, cap. Origin on the floor at the centre.
#   BattlePassWall        LED wall bezel (42 x 22), back panel, two-step dais and three reward plinths. Origin on the
#                         floor on the cavern's west wall face, centred, facing +X (east).
#   MarketSignFrame       black steel bezel for a 10 x 2.4 panel with a 0.3 warm edge strip under it. Origin at the
#                         panel centre on its mid plane, facing +X (scaled per sign in Studio).
#   MarketShowRifle / Crate / Coins / Charm / Figure   small display items. Origin on the bottom centre.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_lobby_kit_market.py -- [--no-render] [--samples N] [--only <Piece,...>]
# Writes art-source/lobby/Kit_Market.blend and vault/02 Art/References/lobby/kit/contact-market.jpg, and prints
# MARKET_TRIS {piece: tris}.

import json, math, os, random, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402
import lobbykit as K  # noqa: E402
import gunkit  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
GROUP = "Market"


# ---------------------------------------------------------------- small helpers

def drop_faces(bm, axis, sign, at=None, tol=0.01):
	# Deletes faces pointing along (axis, sign); with `at`, only those lying on that plane.
	bm.normal_update()
	kill = []
	for f in bm.faces:
		if f.normal[axis] * sign > 0.99 and (at is None or abs(f.calc_center_median()[axis] - at) < tol):
			kill.append(f)
	bmesh.ops.delete(bm, geom=kill, context="FACES")
	return bm


def lbox(x0, x1, y0, y1, z0, z1, ch=0.0):
	return K.cbox(x0, x1, y0, y1, z0, z1, ch=ch) if ch > 0 else K.mat_all(K.box(x0, x1, y0, y1, z0, z1), 0)


def smoothstep(e0, e1, x):
	t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
	return t * t * (3 - 2 * t)


def opening_prism(inner, outer, x0, x1, ch=0.25):
	# A frame around an opening, extruded along X (x0 back .. x1 front); `inner` / `outer` are matching (y, z)
	# polylines from one foot round to the other. Convex edges get the chamfer (from build_lobby_preview_props.py).
	bm = bmesh.new()
	fr = [bm.verts.new((x0, y, z)) for y, z in inner]
	fo = [bm.verts.new((x0, y, z)) for y, z in outer]
	br = [bm.verts.new((x1, y, z)) for y, z in inner]
	bo = [bm.verts.new((x1, y, z)) for y, z in outer]
	n = len(inner)
	for i in range(n - 1):
		bm.faces.new((fr[i], fr[i + 1], fo[i + 1], fo[i]))
		bm.faces.new((br[i], bo[i], bo[i + 1], br[i + 1]))
		bm.faces.new((fr[i], br[i], br[i + 1], fr[i + 1]))
		bm.faces.new((fo[i], fo[i + 1], bo[i + 1], bo[i]))
	for k in (0, n - 1):
		bm.faces.new((fr[k], fo[k], bo[k], br[k]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	bm.edges.ensure_lookup_table()
	if ch > 0:
		edges = [e for e in bm.edges if e.is_manifold and e.is_convex and e.calc_face_angle(0) > math.radians(30)]
		bmesh.ops.bevel(bm, geom=edges, offset=ch, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
	return bm


def slice_axis(bm, axis, positions):
	# Cuts every face of bm with planes normal to `axis` at the given positions (so a box can be bent smoothly).
	no = [0, 0, 0]
	no[axis] = 1
	for p in positions:
		co = [0, 0, 0]
		co[axis] = p
		geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
		bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=co, plane_no=no)
	return bm


def new_piece(kit, piece, props=None):
	col = K.collection("Lobby_" + piece, kit)
	col["kit_group"] = GROUP
	for k, v in (props or {}).items():
		col[k] = v
	return col


# ---------------------------------------------------------------- rock generators

def wall_profile(z):
	# (scale, offset) of the rock's relief at height z: low relief where hands reach, big facets above.
	t = smoothstep(9.0, 13.0, z)
	return 0.28 + 0.72 * t, -0.05 + 0.55 * t


def rock_wall_mesh(width, height, seed, z0=2.1, cell=2.0, relief=2.4, ledges=4, chips=0.25):
	# A rock face from z0 to height, `width` along Y, its relief mapped through wall_profile (x = 0 is the wall face).
	rock = K.rock_face(width, height - z0, seed, cell=cell, depth=relief, relief=relief, ledges=ledges, chips=chips)
	mid = relief / 2
	for v in rock.verts:
		z = v.co.z + z0
		s, o = wall_profile(z)
		v.co.x = (v.co.x - mid) * s + o
		v.co.z = z
	return rock


def plinth_parts(width, nseg=1):
	# Honed plinth 1.5 (front 0.25 proud of the wall face), brushed nosing, the 0.6 shadow gap (black steel liner with
	# a soffit under the rock) and its warm Neon tucked into the top back corner. Kit space: wall face at x = 0.
	def seg(fn):
		bm = bmesh.new()
		for i in range(nseg):
			y0 = -width / 2 + width * i / nseg
			y1 = -width / 2 + width * (i + 1) / nseg
			K.merge(bm, fn(y0, y1))
		return bm

	plinth = seg(lambda a, b: drop_faces(drop_faces(lbox(-0.6, 0.25, a, b, 0.0, 1.5, ch=0.08), 2, -1), 0, -1))
	nosing = seg(lambda a, b: drop_faces(lbox(0.17, 0.27, a, b, 1.4, 1.52), 0, -1))
	liner = seg(lambda a, b: K.merge(drop_faces(lbox(-0.6, -0.25, a, b, 1.5, 2.1), 0, -1), drop_faces(lbox(-0.6, 0.02, a, b, 2.04, 2.16), 0, -1)))
	glow = seg(lambda a, b: lbox(-0.25, -0.17, a, b, 1.92, 2.04))
	return {
		"Plinth": (plinth, "ConcreteHoned"),
		"Nosing": (nosing, "SteelBrushed"),
		"GapLiner": (liner, "SteelBlack"),
		"Gap_Glow": (glow, "Glow_Cove"),
	}


def build_parts(prefix, parts, mats, col, smooth=None):
	# K.build with flat shading for rock parts.
	out = {}
	for part, (bm, mname) in parts.items():
		name = "%s_%s" % (prefix, part)
		if part.endswith("_Glow"):
			out[part] = K.add_glow(name, bm, mats[mname], col)
		else:
			flat = mname.startswith("Rock") or (smooth is not None and part in smooth)
			out[part] = K.add_obj(name, bm, [mats[mname]], col, smooth_angle=0 if flat else 35, uv_rotate=part in ("Slats", "CounterBody", "Runner"))
	return out


def rock_block(sx, sy, sz, seed, cell=2.4, out_lo=0.22, in_lo=0.3, out_hi=1.0, in_hi=0.45, z_lo=8.0, z_hi=13.0,
               top=True, bottom=False, edge_in=0.28, band=6.5, taper=None, lean=0.0):
	# Faceted rock block: a box x +-sx/2, y +-sy/2, z 0..sz cut into ~cell facets, each vertex pushed along the box
	# normal by coherent noise plus strata bands; edges and corners pulled in (broken arrises). Displacement stays in
	# -in_lo..+out_lo below z_lo (so it hugs a collision box where players touch it) and grows to -in_hi..+out_hi above
	# z_hi. taper: (bottom scale, top scale) of the cross section. Triangulated, meant for flat shading.
	rnd = random.Random(seed)
	off = Vector((rnd.uniform(0, 300), rnd.uniform(0, 300), rnd.uniform(0, 300)))
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	for v in bm.verts:
		v.co = Vector((v.co.x * sx, v.co.y * sy, (v.co.z + 0.5) * sz))

	def cuts(lo, hi):
		n = max(1, int(round((hi - lo) / cell)))
		return [lo + (hi - lo) * i / n + rnd.uniform(-0.22, 0.22) * (hi - lo) / n for i in range(1, n)]

	slice_axis(bm, 0, cuts(-sx / 2, sx / 2))
	slice_axis(bm, 1, cuts(-sy / 2, sy / 2))
	slice_axis(bm, 2, cuts(0.0, sz))
	if not top:
		drop_faces(bm, 2, 1, at=sz)
	if not bottom:
		drop_faces(bm, 2, -1, at=0.0)
	bands = [(rnd.uniform(-0.35, 0.35), rnd.uniform(0.2, 0.5)) for _ in range(int(sz / band) + 3)]
	ph = rnd.uniform(0, band)
	for v in bm.verts:
		x, y, z = v.co
		on = [abs(abs(x) - sx / 2) < 1e-4, abs(abs(y) - sy / 2) < 1e-4, abs(z) < 1e-4 or abs(z - sz) < 1e-4]
		# In-plane jitter (stays on its faces).
		jit = Vector((0, 0, 0))
		if not on[0]:
			jit.x = rnd.uniform(-0.25, 0.25) * cell
		if not on[1]:
			jit.y = rnd.uniform(-0.25, 0.25) * cell
		if not on[2]:
			jit.z = rnd.uniform(-0.2, 0.2) * cell
		p = Vector((x, y, z)) + jit
		p.x = min(max(p.x, -sx / 2), sx / 2)
		p.y = min(max(p.y, -sy / 2), sy / 2)
		p.z = min(max(p.z, 0.0), sz)
		nrm = Vector((
			(1 if x > 0 else -1) if on[0] else 0,
			(1 if y > 0 else -1) if on[1] else 0,
			(1 if z > sz / 2 else -1) if on[2] else 0,
		))
		k = sum(on)
		if nrm.length < 1e-6:
			v.co = p
			continue
		nrm.normalize()
		t = smoothstep(z_lo, z_hi, p.z)
		o_max = out_lo + (out_hi - out_lo) * t
		i_max = in_lo + (in_hi - in_lo) * t
		q = p * 0.16 + off
		h = noise.noise(q) + 0.5 * noise.noise(q * 2.4) + 0.25 * noise.noise(q * 5.3)
		h = max(-1.0, min(1.0, h * 1.1))
		bi = int((p.z + ph) / band)
		bo, bl = bands[min(bi, len(bands) - 1)]
		bt = ((p.z + ph) / band) - bi
		strata = (bo + bl * (bt - 0.5)) * (0.4 + 0.6 * t)
		d = h * (o_max if h > 0 else i_max) + strata * (o_max + i_max) * 0.5
		d = max(-i_max, min(o_max, d))
		if k >= 2:
			d -= edge_in * (k - 1)
		p += nrm * d
		v.co = p
	if taper:
		b0, b1 = taper
		for v in bm.verts:
			f = b0 + (b1 - b0) * (v.co.z / sz)
			v.co.x *= f
			v.co.y *= f
	if lean:
		for v in bm.verts:
			v.co.x += lean * v.co.z / sz
	bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
	bm.normal_update()
	return K.mat_all(bm, 0)


# ---------------------------------------------------------------- rock pieces

WALL_W, WALL_H = 12.0, 34.0


def piece_rock_wall(kit, mats, v, seed, cell=2.0, relief=2.4, ledges=4, chips=0.15):
	name = "MarketRockWall_" + v
	col = new_piece(kit, name, {"width": WALL_W, "height": WALL_H})
	parts = plinth_parts(WALL_W)
	parts["Rock"] = (rock_wall_mesh(WALL_W, WALL_H, seed, cell=cell, relief=relief, ledges=ledges, chips=chips), "Rock")
	build_parts(name, parts, mats, col)
	return col


def piece_rock_feature(kit, mats):
	# MarketRockWall_Feature: a wall panel whose lower part is a flat board-formed concrete backdrop (behind the
	# featured podiums and their wall label at y 11.5), framed by the shadow gap, with rock only above y 16.
	name = "MarketRockWall_Feature"
	col = new_piece(kit, name, {"width": WALL_W, "height": WALL_H})
	parts = plinth_parts(WALL_W)
	parts["Panel"] = (drop_faces(lbox(-0.3, 0.05, -WALL_W / 2, WALL_W / 2, 2.1, 15.4, ch=0.06), 0, -1), "ConcreteBoard")
	parts["TopLiner"] = (drop_faces(lbox(-0.3, 0.1, -WALL_W / 2, WALL_W / 2, 15.4, 16.05), 0, -1), "SteelBlack")
	parts["Top_Glow"] = (lbox(0.0, 0.08, -WALL_W / 2 + 0.05, WALL_W / 2 - 0.05, 15.72, 15.84), "Glow_Cove")
	rock = rock_wall_mesh(WALL_W, WALL_H, 377, z0=16.0, cell=2.1, relief=2.4, ledges=2, chips=0.15)
	for v in rock.verts:
		if v.co.z < 16.01:
			v.co.x = 0.05  # the rock's foot closes onto the liner (no see-through slot)
	parts["Rock"] = (rock, "Rock")
	build_parts(name, parts, mats, col)
	return col


CORE_R, CORE_SPAN = 14.0, 22.5


def bend_to_core(bm, r0=CORE_R, span=CORE_SPAN):
	# Flat kit space (x out of the wall face, y along it, z up) -> bent onto radius r0 around the origin, spanning
	# bearings 0..span (y = +w/2 at bearing 0), facing outward.
	for v in bm.verts:
		x, y, z = v.co
		b = span / 2 - math.degrees(y / r0)
		p = K.polar(r0 + x, b, z)
		v.co = p
	bm.normal_update()
	return bm


def piece_rock_core(kit, mats, v, seed):
	name = "MarketRockCore_" + v
	col = new_piece(kit, name, {"radius": CORE_R, "span": CORE_SPAN})
	width = math.radians(CORE_SPAN) * CORE_R
	parts = plinth_parts(width)
	for bm, _ in parts.values():
		slice_axis(bm, 1, [-width / 2 + width * i / 4 for i in range(1, 4)])
	parts["Rock"] = (rock_wall_mesh(width, WALL_H, seed, cell=1.85, relief=2.4, ledges=4, chips=0.15), "Rock")
	for k, (bm, m) in parts.items():
		bend_to_core(bm)
		# Outward check: faces must point away from the axis.
		bm.normal_update()
		s = 0.0
		for f in bm.faces:
			c = f.calc_center_median()
			s += f.normal.dot(Vector((c.x, c.y, 0)).normalized()) * f.calc_area()
		if k == "Rock" and s < 0:
			bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
	build_parts(name, parts, mats, col)
	return col


def piece_rock_ceiling(kit, mats, v, seed):
	name = "MarketRockCeiling_" + v
	col = new_piece(kit, name, {"size": 24.0})
	relief = 2.6
	rock = K.rock_face(24.0, 24.0, seed, cell=2.6, depth=relief, relief=relief, ledges=2, chips=0.3)
	for vt in rock.verts:
		x, y, z = vt.co
		edge = abs(abs(y) - 12.0) < 1e-3 or z < 1e-3 or abs(z - 24.0) < 1e-3
		vt.co = Vector((0.0 if edge else x - relief / 2, y, z - 12.0))
	build_parts(name, {"Rock": (rock, "Rock")}, mats, col)
	return col


def piece_rock_slab(kit, mats, v, seed, cell, lean):
	name = "MarketRockSlab_" + v
	col = new_piece(kit, name, {"nominal": "4 x 8 x 32"})
	bm = rock_block(4.0, 8.0, 32.0, seed, cell=cell, z_lo=9.0, z_hi=14.0, top=True, lean=lean)
	build_parts(name, {"Rock": (bm, "Rock")}, mats, col)
	return col


def piece_rock_pillar(kit, mats, v, seed, roll):
	name = "MarketRockPillar_" + v
	col = new_piece(kit, name, {"nominal": "w 5, roof 30"})
	a = rock_block(5.0, 4.0, 32.0, seed, cell=2.3, z_lo=9.0, z_hi=14.0)
	K.place(a, Matrix.Translation((0, 0, -1)))
	b = rock_block(3.5, 5.5, 18.0, seed + 7, cell=2.1, z_lo=9.0, z_hi=14.0, top=True, out_hi=0.6)
	K.place(b, Matrix.Rotation(math.radians(37), 4, "Z") @ Matrix.Rotation(math.radians(-roll), 4, "Y"))
	K.merge(a, b)
	build_parts(name, {"Rock": (a, "Rock")}, mats, col)
	return col


def piece_rock_drop(kit, mats, v, seed, tip):
	name = "MarketRockDrop_" + v
	col = new_piece(kit, name, {"nominal": "5 x 4 x 12, hangs from origin"})
	bm = rock_block(5.0, 4.0, 12.0, seed, cell=2.0, out_lo=0.8, in_lo=0.4, out_hi=0.8, in_hi=0.4, top=False, bottom=True, taper=(tip, 1.15), edge_in=0.35)
	# Pull the bottom face's middle down into a blunt point.
	for vt in bm.verts:
		if vt.co.z < 0.3:
			vt.co.z -= 1.2 * (1 - min(1.0, Vector((vt.co.x, vt.co.y)).length / 1.5))
	K.place(bm, Matrix.Translation((0, 0, -12.0)))
	build_parts(name, {"Rock": (bm, "Rock")}, mats, col)
	return col


def piece_rock_hood(kit, mats):
	name = "MarketRockHood"
	col = new_piece(kit, name, {"nominal": "10 deep x 17 wide x 12"})
	bm = rock_block(10.0, 17.0, 12.0, 91, cell=2.2, out_lo=1.0, in_lo=0.3, out_hi=1.0, in_hi=0.4, z_lo=0, z_hi=1, top=False, bottom=True)
	K.place(bm, Matrix.Translation((5.0, 0, 0)))
	drop_faces(bm, 0, -1)  # the back (against the wall) never shows
	# The underside rests on the pavilion top: keep it flat (no rock poking down through the canopy).
	for vt in bm.verts:
		if vt.co.z < 0.05:
			vt.co.z = 0.0
	build_parts(name, {"Rock": (bm, "Rock")}, mats, col)
	return col


# ---------------------------------------------------------------- portal

def piece_portal(kit, mats):
	name = "MarketPortal"
	col = new_piece(kit, name)
	hw_in, hw_out, h_in, h_out, deep = 13.27, 22.0, 16.0, 24.5, 12.0
	inner = [(-hw_in, 0), (-hw_in, h_in), (hw_in, h_in), (hw_in, 0)]
	outer = [(-hw_out, 0), (-hw_out, h_out), (hw_out, h_out), (hw_out, 0)]
	frame = opening_prism(inner, outer, 0.0, deep, ch=0.25)
	drop_faces(frame, 2, -1, at=0.0)
	drop_faces(frame, 1, 1, at=hw_out, tol=0.3)
	drop_faces(frame, 1, -1, at=-hw_out, tol=0.3)
	drop_faces(frame, 2, 1, at=h_out, tol=0.3)
	parts = {"Frame": (frame, "ConcreteBoard")}
	# Warm edge strips down both jambs near the market face, and a soffit pelmet hiding a cove strip.
	gl = bmesh.new()
	for s in (-1, 1):
		y0, y1 = sorted((s * hw_in, s * (hw_in - 0.08)))
		K.merge(gl, lbox(deep - 1.0, deep - 0.75, y0, y1, 0.3, h_in - 0.4))
	parts["Edge_Glow"] = (gl, "Glow_Cove")
	cove = K.trim_cove(2 * hw_in - 0.6, lip=0.7, shelf=0.8, up=False)
	for k, (bm, m) in cove.items():
		K.place(bm, Matrix.Translation((deep - 1.6, 0, h_in)))
		parts["SoffitCove_Glow" if k.endswith("_Glow") else "Pelmet"] = (bm, m)
	# Shadow gap where the concrete face meets the rock: a black steel return with a warm line, round the face.
	ret, line = bmesh.new(), bmesh.new()
	for s in (-1, 1):
		y0, y1 = sorted((s * (hw_out - 0.5), s * hw_out))
		K.merge(ret, lbox(deep - 0.02, deep + 0.12, y0, y1, 0.0, h_out - 0.5))
		y0, y1 = sorted((s * (hw_out - 0.42), s * (hw_out - 0.32)))
		K.merge(line, lbox(deep + 0.12, deep + 0.17, y0, y1, 1.6, h_out - 0.9))
	K.merge(ret, lbox(deep - 0.02, deep + 0.12, -hw_out, hw_out, h_out - 0.5, h_out))
	K.merge(line, lbox(deep + 0.12, deep + 0.17, -hw_out + 0.4, hw_out - 0.4, h_out - 0.42, h_out - 0.32))
	parts["GapReturn"] = (ret, "SteelBlack")
	parts["Gap_Glow"] = (line, "Glow_Cove")
	# A honed plinth band round the opening's foot on the market face (ties into the street plinths).
	pl = bmesh.new()
	for s in (-1, 1):
		y0, y1 = sorted((s * (hw_in + 0.25), s * (hw_out - 0.5)))
		K.merge(pl, drop_faces(lbox(deep - 0.4, deep + 0.25, y0, y1, 0.0, 1.5, ch=0.08), 2, -1))
	parts["Plinth"] = (pl, "ConcreteHoned")
	build_parts(name, parts, mats, col)
	return col


# ---------------------------------------------------------------- shop pavilion

PAV_W, PAV_D, PAV_H = 16.0, 10.0, 14.6
PAV_IN = 7.3  # visual inner face of the fins (collision face at 7.0)
PAV_CEIL = 10.0
PAV_STAGE = 0.4
SLAT_BACK = 0.65  # backing thickness: the slat fronts land on the greybox slat face (x = 1)
SLAT_D = 0.35
SIGN_W, SIGN_H, SIGN_Z = 13.0, 2.8, 12.5  # the greybox header sign (kept; its SurfaceGui is the text)


def slat(c, z0, z1, wall, sign=1, xb=SLAT_BACK, yb=None):
	# One oak slat 1 wide x 0.35 deep, chamfered front edges, only its visible faces (10 triangles).
	t = 0.06
	if wall == "X":
		xf = xb + SLAT_D
		pts = [(xb, c - 0.5), (xf - t, c - 0.5), (xf, c - 0.5 + t), (xf, c + 0.5 - t), (xf - t, c + 0.5), (xb, c + 0.5)]
	else:
		yf = yb - sign * SLAT_D
		pts = [(c - 0.5, yb), (c - 0.5, yf + sign * t), (c - 0.5 + t, yf), (c + 0.5 - t, yf), (c + 0.5, yf + sign * t), (c + 0.5, yb)]
	bm = K.mat_all(K.prism(pts, "Z", z0, z1), 0)
	gunkit.drop(bm, 2, -1)
	gunkit.drop(bm, 2, 1)
	if wall == "X":
		gunkit.drop(bm, 0, -1)
	else:
		gunkit.drop(bm, 1, sign)
	return bm


def sign_frame_parts(w, h, depth=0.5, edge=0.4, strip=0.3, back=0.0):
	# Bezel round a w x h panel opening (the panel itself is the greybox sign part, which carries the SurfaceGui),
	# with the warm edge strip under the opening. Kit space: panel centre at (0, 0, 0), front +X; bezel from
	# x = back to back + depth.
	x0, x1 = back, back + depth
	hw, hh = w / 2, h / 2
	fr = bmesh.new()
	K.merge(fr, lbox(x0, x1, -hw - edge, hw + edge, hh, hh + edge, ch=0.08))
	K.merge(fr, lbox(x0, x1, -hw - edge, hw + edge, -hh - strip - edge, -hh - strip, ch=0.08))
	for s in (-1, 1):
		y0, y1 = sorted((s * hw, s * (hw + edge)))
		K.merge(fr, lbox(x0, x1, y0, y1, -hh - strip - 0.02, hh + 0.02, ch=0.06))
	panel = lbox(x0, x0 + 0.06, -hw, hw, -hh - strip, hh)
	glow = lbox(x0 + 0.06, x1 - 0.15, -hw, hw, -hh - strip, -hh)
	return {"Bezel": (fr, "SteelBlack"), "Backer": (panel, "SignPanel"), "Strip_Glow": (glow, "Glow_Cove")}


def piece_shop_pavilion(kit, mats):
	name = "ShopPavilion"
	col = new_piece(kit, name, {"size": "16 x 10 x 14.6"})
	hw = PAV_W / 2
	iw = PAV_IN
	inner = [(-iw, 0), (-iw, PAV_CEIL), (iw, PAV_CEIL), (iw, 0)]
	outer = [(-hw, 0), (-hw, PAV_H), (hw, PAV_H), (hw, 0)]
	frame = opening_prism(inner, outer, 0.0, PAV_D, ch=0.2)
	drop_faces(frame, 2, -1, at=0.0)
	drop_faces(frame, 0, -1)
	parts = {"Frame": (frame, "ConcreteBoard")}
	parts["Stage"] = (drop_faces(K.cbox(0, PAV_D - 0.12, -iw, iw, 0, PAV_STAGE, ch=0.04), 2, -1), "Terrazzo")
	parts["StageNosing"] = (drop_faces(lbox(PAV_D - 0.15, PAV_D + 0.02, -iw, iw, 0.0, PAV_STAGE), 2, -1), "SteelBrushed")
	# Oak slats on the back wall and both side returns, on black backing.
	z0, z1 = PAV_STAGE, PAV_CEIL
	yi = iw - SLAT_D
	sl = bmesh.new()
	n = int((2 * yi - 1.0) // 1.5) + 1
	y0 = -((n - 1) * 1.5) / 2
	for i in range(n):
		K.merge(sl, slat(y0 + i * 1.5, z0, z1, "X"))
	for sgn in (-1, 1):
		c = SLAT_BACK + SLAT_D + 1.0
		while c + 0.5 <= 8.2:
			K.merge(sl, slat(c, z0, z1, "Y", sgn, yb=sgn * (iw - 0.04)))
			c += 1.5
	parts["Slats"] = (sl, "Oak")
	bk = bmesh.new()
	K.merge(bk, drop_faces(lbox(0, SLAT_BACK, -iw, iw, z0, z1), 0, -1))
	for sgn in (-1, 1):
		a, b = sorted((sgn * iw, sgn * (iw - 0.05)))
		K.merge(bk, lbox(SLAT_BACK, 8.5, a, b, z0, z1))
	parts["SlatBacking"] = (bk, "SteelBlack")
	cove = K.trim_cove(2 * yi, lip=0.75, shelf=0.8, up=False)
	for k, (bm, m) in cove.items():
		K.place(bm, Matrix.Translation((SLAT_BACK + SLAT_D, 0, PAV_CEIL)))
		parts["SlatCove_Glow" if k.endswith("_Glow") else "Pelmet"] = (bm, m)
	# Canopy blade under the header sign: 2.2 out, a fascia hiding its warm strip, end returns.
	cw = hw + 0.5
	cb0, cb1 = PAV_CEIL + 0.1, PAV_CEIL + 0.4
	cx1 = PAV_D + 2.2
	steel = bmesh.new()
	K.merge(steel, K.cbox(PAV_D, cx1, -cw, cw, cb0, cb1, ch=0.04))
	K.merge(steel, K.cbox(cx1 - 0.15, cx1, -cw, cw, cb0 - 0.3, cb1, ch=0.03))
	for s in (-1, 1):
		a, b = sorted((s * cw, s * (cw - 0.15)))
		K.merge(steel, K.cbox(PAV_D, cx1 - 0.1, a, b, cb0 - 0.3, cb1, ch=0.03))
	parts["Canopy"] = (steel, "SteelBlack")
	parts["Canopy_Glow"] = (lbox(cx1 - 0.5, cx1 - 0.2, -cw + 0.3, cw - 0.3, cb0 - 0.15, cb0), "Glow_Cove")
	# Header sign frame round the greybox sign (13 x 2.8 at z 12.5, 0.2 proud of the header face).
	sf = sign_frame_parts(SIGN_W, SIGN_H, depth=0.55, back=0.0)
	for k, (bm, m) in sf.items():
		K.place(bm, Matrix.Translation((PAV_D, 0, SIGN_Z)))
		parts["Sign" + k] = (bm, m)
	# Counter (collision x 4.5..7, y +-5, top 3.6): oak body on a recessed black toe, black steel top, POS screen.
	c0, c1, cy0, cy1 = 4.55, 6.95, -4.9, 4.9
	top = 3.6
	parts["CounterBody"] = (drop_faces(K.cbox(c0, c1, cy0, cy1, 0.75, top - 0.25, ch=0.06), 2, -1), "Oak")
	cs = bmesh.new()
	K.merge(cs, drop_faces(K.cbox(c0 + 0.3, c1 - 0.3, cy0 + 0.3, cy1 - 0.3, PAV_STAGE, 0.76, ch=0.03), 2, -1))
	K.merge(cs, K.cbox(c0 - 0.15, c1 + 0.15, cy0 - 0.15, cy1 + 0.15, top - 0.25, top, ch=0.06))
	K.merge(cs, K.cbox(c0 + 0.5, c0 + 0.9, 3.0, 3.4, top, top + 0.75, ch=0.03))
	parts["CounterSteel"] = (cs, "SteelBlack")
	pos = Matrix.Translation((c0 + 0.75, 3.2, top + 1.0)) @ Matrix.Rotation(math.radians(-35), 4, "Y")
	parts["PosScreen"] = (K.place(lbox(-0.05, 0.05, -0.6, 0.6, -0.4, 0.4), pos), "Screen")
	parts["Toe_Glow"] = (lbox(c1 - 0.33, c1 - 0.25, cy0 + 0.4, cy1 - 0.4, PAV_STAGE + 0.02, PAV_STAGE + 0.1), "Glow_Cove")
	# Vitrine (collision x 1.5..3.5, y +-1.5, top 6): black column, glass case, black cap, cradle.
	vx = 2.5
	vs = bmesh.new()
	K.merge(vs, drop_faces(K.cbox(vx - 0.6, vx + 0.6, -0.6, 0.6, PAV_STAGE, 3.35, ch=0.05), 2, -1))
	K.merge(vs, K.cbox(vx - 1.0, vx + 1.0, -1.5, 1.5, 3.35, 3.5, ch=0.04))
	K.merge(vs, K.cbox(vx - 1.0, vx + 1.0, -1.5, 1.5, 5.8, 6.0, ch=0.04))
	K.merge(vs, lbox(vx - 0.15, vx + 0.15, -0.9, 0.9, 3.5, 3.6))
	parts["Vitrine"] = (vs, "SteelBlack")
	glass = drop_faces(drop_faces(lbox(vx - 0.95, vx + 0.95, -1.45, 1.45, 3.5, 5.8), 2, 1), 2, -1)
	parts["VitrineGlass"] = (glass, "Glass")
	parts["Vitrine_Glow"] = (lbox(vx - 0.85, vx + 0.85, -1.35, 1.35, 5.72, 5.8), "Glow_Cove")
	# Top shadow gap: a black liner on the roof and a warm line just behind the front edge (where the rock hood sits).
	parts["TopLiner"] = (drop_faces(lbox(0.0, PAV_D - 0.3, -hw, hw, PAV_H, PAV_H + 0.35), 2, -1), "SteelBlack")
	parts["Top_Glow"] = (lbox(PAV_D - 0.42, PAV_D - 0.3, -hw + 0.3, hw - 0.3, PAV_H + 0.05, PAV_H + 0.25), "Glow_Cove")
	# Where the pavilion meets the rock: a black steel return up each back corner with a warm line in it
	# (the plan's "clean pavilion standing free of the rock, with a lit shadow gap").
	ret, line = bmesh.new(), bmesh.new()
	for sgn in (-1, 1):
		a0, a1 = sorted((sgn * hw, sgn * (hw + 0.12)))
		K.merge(ret, drop_faces(lbox(0.0, 0.9, a0, a1, 0.0, PAV_H + 0.35), 2, -1))
		b0, b1 = sorted((sgn * (hw + 0.12), sgn * (hw + 0.17)))
		K.merge(line, lbox(0.3, 0.42, b0, b1, 1.6, PAV_H))
	parts["SideReturn"] = (ret, "SteelBlack")
	parts["SideGap_Glow"] = (line, "Glow_Cove")
	build_parts(name, parts, mats, col)
	return col


# ---------------------------------------------------------------- featured podium

def piece_podium(kit, mats):
	name = "FeaturedPodium"
	col = new_piece(kit, name)
	parts = {}
	plate = drop_faces(K.cyl(0, 0, 5.0, 0.0, 0.12, segs=32, ch=0.03), 2, -1)
	parts["FloorRing"] = (plate, "SteelBrushed")
	parts["Ring_Glow"] = (drop_faces(K.arc(4.62, 4.9, 0, 360, 0.1, 0.14, steps=32), 2, -1), "Glow_Cove")
	toe = drop_faces(K.cyl(0, 0, 4.2, 0.12, 0.42, segs=24), 2, -1)
	parts["Toe"] = (toe, "SteelBlack")
	parts["Toe_Glow"] = (drop_faces(drop_faces(K.arc(4.2, 4.28, 0, 360, 0.16, 0.32, steps=24), 2, -1), 2, 1), "Glow_Cove")
	parts["Base"] = (drop_faces(K.cyl(0, 0, 4.5, 0.42, 1.2, segs=24, ch=0.08), 2, -1), "ConcreteBoard")
	parts["Turntable"] = (drop_faces(K.cyl(0, 0, 3.6, 1.2, 1.45, segs=24, ch=0.04), 2, -1), "SteelBrushed")
	gl = K.lathe([(3.0, 1.45), (3.0, 7.2)], 0, 360, steps=24)
	parts["Case"] = (gl, "Glass")
	cap = drop_faces(K.cyl(0, 0, 3.2, 7.2, 7.6, segs=24, ch=0.06), 2, 1)
	parts["Cap"] = (cap, "SteelBlack")
	parts["Cap_Glow"] = (drop_faces(K.arc(2.55, 2.85, 0, 360, 7.12, 7.2, steps=24), 2, 1), "Glow_Cove")
	cr = bmesh.new()
	K.merge(cr, drop_faces(K.cyl(0, 0, 0.18, 1.45, 3.0, segs=8), 2, -1))
	K.merge(cr, K.cbox(-0.35, 0.35, -0.9, 0.9, 3.0, 3.12, ch=0.03))
	parts["Cradle"] = (cr, "SteelBrushed")
	build_parts(name, parts, mats, col)
	return col


# ---------------------------------------------------------------- battle pass wall

def piece_battle_pass(kit, mats):
	name = "BattlePassWall"
	col = new_piece(kit, name)
	parts = {}
	# Bezel round the 40 x 20 LED (greybox LEDWall at x 0.55..0.85, z 5..25, y +-20).
	hw, z0, z1 = 20.0, 5.0, 25.0
	e = 1.2
	bz = bmesh.new()
	K.merge(bz, lbox(0.0, 1.15, -hw - e, hw + e, z1, z1 + e, ch=0.1))
	K.merge(bz, lbox(0.0, 1.15, -hw - e, hw + e, z0 - e, z0, ch=0.1))
	for s in (-1, 1):
		a, b = sorted((s * hw, s * (hw + e)))
		K.merge(bz, lbox(0.0, 1.15, a, b, z0 - 0.02, z1 + 0.02, ch=0.1))
	drop_faces(bz, 0, -1)
	parts["Bezel"] = (bz, "SteelBlack")
	parts["Backer"] = (lbox(0.0, 0.5, -hw, hw, z0, z1), "Screen")
	# Light hood over the screen with a warm downlight line, and a warm frame line round the bezel.
	hood = bmesh.new()
	K.merge(hood, K.cbox(0.0, 2.6, -hw - e - 0.6, hw + e + 0.6, z1 + e, z1 + e + 0.5, ch=0.06))
	K.merge(hood, K.cbox(2.45, 2.6, -hw - e - 0.6, hw + e + 0.6, z1 + e - 0.35, z1 + e + 0.5, ch=0.03))
	parts["Hood"] = (hood, "SteelBlack")
	parts["Hood_Glow"] = (lbox(2.0, 2.3, -hw - e, hw + e, z1 + e - 0.12, z1 + e), "Glow_Cove")
	ln = bmesh.new()
	for s in (-1, 1):
		a, b = sorted((s * (hw + e + 0.05), s * (hw + e + 0.2)))
		K.merge(ln, lbox(0.2, 0.45, a, b, z0 - e, z1 + e))
	parts["Frame_Glow"] = (ln, "Glow_Cove")
	# Two-step dais (collision: step 1 x 0.5..16, y +-24, top 0.75; step 2 x 0.5..11, y +-20, top 1.5).
	d1 = drop_faces(K.cbox(0.0, 16.0, -24.0, 24.0, 0.0, 0.75, ch=0.06), 2, -1)
	d2 = drop_faces(K.cbox(0.0, 11.0, -20.0, 20.0, 0.75, 1.5, ch=0.06), 2, -1)
	parts["Step1"] = (d1, "ConcretePolished")
	parts["Step2"] = (d2, "ConcretePolished")
	no = bmesh.new()
	K.merge(no, lbox(15.85, 16.03, -24.0, 24.0, 0.6, 0.77))
	K.merge(no, lbox(10.85, 11.03, -20.0, 20.0, 1.35, 1.52))
	parts["Nosing"] = (no, "SteelBrushed")
	rg = bmesh.new()
	K.merge(rg, lbox(15.9, 16.02, -23.6, 23.6, 0.18, 0.42))
	K.merge(rg, lbox(10.9, 11.02, -19.6, 19.6, 0.93, 1.17))
	parts["Riser_Glow"] = (rg, "Glow_Cove")
	# Reward plinths (collision r 2.5, 1.5..4) at x 6, y -12 / 0 / 12.
	pb, pt, pg = bmesh.new(), bmesh.new(), bmesh.new()
	for y in (-12.0, 0.0, 12.0):
		K.merge(pb, drop_faces(K.cyl(6.0, y, 2.4, 1.5, 3.7, segs=20, ch=0.05), 2, -1))
		K.merge(pt, K.cyl(6.0, y, 2.5, 3.7, 4.0, segs=20, ch=0.05))
		K.merge(pg, drop_faces(drop_faces(K.arc(2.4, 2.47, 0, 360, 1.6, 1.75, steps=20, center=(6.0, y)), 2, 1), 2, -1))
	parts["Plinths"] = (pb, "SteelBlack")
	parts["PlinthTops"] = (pt, "SteelBrushed")
	parts["Plinth_Glow"] = (pg, "Glow_Cove")
	build_parts(name, parts, mats, col)
	return col


def piece_sign_frame(kit, mats):
	name = "MarketSignFrame"
	col = new_piece(kit, name, {"panel": "10 x 2.4"})
	parts = sign_frame_parts(10.0, 2.4, depth=0.55, back=-0.2)
	build_parts(name, parts, mats, col)
	return col


# ---------------------------------------------------------------- display items

def rifle_parts():
	# Display-scale rifle (lod stand-in from build_lobby_preview_props.py's rifle()), 16.35 long at scale 1, +X muzzle.
	P, D, M = "SkinPaint", "SteelBlack", "SteelBrushed"
	parts = {}

	def add(nm, bm, mat):
		if nm in parts:
			K.merge(parts[nm][0], bm)
		else:
			parts[nm] = (bm, mat)

	def cyl_x(x0, x1, r, z, segs=8):
		return K.mat_all(gunkit.cyl_x(x0, x1, r, z, segs=segs), 0)

	add("Body", K.prism([(-2.7, -0.5), (-2.35, -0.9), (1.75, -0.9), (2.3, -0.45), (2.3, 0.8), (-2.7, 0.8)], "Y", -0.5, 0.5), D)
	add("Body", K.box(-2.5, 6.6, -0.33, 0.33, 0.8, 1.05), D)
	add("Skin", K.prism([(2.3, -0.55), (6.35, -0.55), (6.75, -0.3), (6.75, 0.8), (2.3, 0.8)], "Y", -0.46, 0.46), P)
	add("Barrel", cyl_x(6.7, 7.7, 0.19, 0.2), M)
	add("Body", cyl_x(7.6, 8.3, 0.32, 0.2), D)
	add("Skin", K.prism([(-0.5, -0.9), (-1.5, -0.9), (-2.25, -2.6), (-2.05, -2.8), (-1.3, -2.8), (-0.72, -1.45)], "Y", -0.42, 0.42), P)
	add("Body", K.prism([(0.05, -1.25), (1.4, -1.25), (1.6, -2.05), (2.05, -2.95), (0.9, -3.2), (0.32, -2.15)], "Y", -0.4, 0.4), D)
	add("Body", K.prism([(-0.05, -0.9), (1.6, -0.9), (1.5, -1.25), (0.05, -1.25)], "Y", -0.55, 0.55), D)
	add("Body", cyl_x(-4.5, -2.65, 0.3, 0.3), D)
	add("Skin", K.prism([(-4.3, 0.68), (-7.5, 0.68), (-7.8, 0.48), (-7.8, -1.12), (-7.45, -1.28), (-6.95, -1.28), (-4.3, -0.08)], "Y", -0.34, 0.34), P)
	add("Body", K.box(-0.6, 1.3, -0.3, 0.3, 1.05, 1.5), D)
	add("Body", cyl_x(-1.2, 1.9, 0.36, 1.9, segs=10), D)
	add("Body", cyl_x(1.45, 2.2, 0.48, 1.9, segs=10), D)
	return parts


def piece_show_rifle(kit, mats):
	name = "MarketShowRifle"
	col = new_piece(kit, name, {"length": 4.09})
	parts = rifle_parts()
	m = Matrix.Translation((0, 0, 3.2 * 0.25)) @ Matrix.Scale(0.25, 4)
	for bm, _ in parts.values():
		K.place(bm, m)
	build_parts(name, parts, mats, col)
	return col


def piece_show_crate(kit, mats):
	name = "MarketShowCrate"
	col = new_piece(kit, name)
	parts = {
		"Box": (K.cbox(-0.8, 0.8, -0.8, 0.8, 0.0, 1.4, ch=0.05), "Oak"),
	}
	st = bmesh.new()
	for sx in (-1, 1):
		for sy in (-1, 1):
			a, b = sorted((sx * 0.62, sx * 0.86))
			c, d = sorted((sy * 0.62, sy * 0.86))
			K.merge(st, K.cbox(a, b, c, d, -0.02, 1.44, ch=0.03))
	K.merge(st, K.cbox(-0.86, 0.86, -0.12, 0.12, 1.38, 1.47, ch=0.02))
	parts["Corners"] = (st, "SteelBlack")
	parts["Band_Glow"] = (lbox(0.8, 0.83, -0.5, 0.5, 0.6, 0.72), "Glow_Cove")
	build_parts(name, parts, mats, col)
	return col


def piece_show_coins(kit, mats):
	name = "MarketShowCoins"
	col = new_piece(kit, name)
	coins = bmesh.new()
	rnd = random.Random(5)
	for k, (cx, cy, nstack) in enumerate(((0.0, 0.0, 6), (0.9, 0.5, 4), (-0.7, 0.7, 3))):
		for i in range(nstack):
			K.merge(coins, K.cyl(cx + rnd.uniform(-0.06, 0.06), cy + rnd.uniform(-0.06, 0.06), 0.5, i * 0.16, i * 0.16 + 0.14, segs=12))
	parts = {"Coins": (coins, "Brass")}
	gem = K.rock_chunk(9, size=(0.8, 0.8, 1.1), center=(0.2, -0.7, 0.55), points=10, jag=0.1)
	parts["Gem"] = (gem, "Glass")
	build_parts(name, parts, mats, col, smooth=("Gem",))
	return col


def piece_show_charm(kit, mats):
	name = "MarketShowCharm"
	col = new_piece(kit, name)
	parts = {}
	ring = K.lathe([(0.32, 2.2), (0.42, 2.25), (0.32, 2.3), (0.22, 2.25), (0.32, 2.2)], 0, 360, steps=12)
	K.place(ring, Matrix.Translation((0, 0, 2.25)) @ Matrix.Rotation(math.radians(90), 4, "Y") @ Matrix.Translation((0, 0, -2.25)))
	parts["Ring"] = (ring, "SteelBrushed")
	med = K.mat_all(gunkit.cyl_x(-0.08, 0.08, 0.7, 1.15, segs=6), 0)
	parts["Medal"] = (med, "Brass")
	parts["Stand"] = (K.merge(K.cyl(0, 0, 0.5, 0.0, 0.1, segs=12, ch=0.02), lbox(-0.05, 0.05, -0.05, 0.05, 0.1, 2.0)), "SteelBlack")
	build_parts(name, parts, mats, col)
	return col


def piece_show_figure(kit, mats):
	name = "MarketShowFigure"
	col = new_piece(kit, name)
	s = 0.4
	body = [
		K.cbox(-0.5, 0.5, -0.98, -0.02, 0.0, 2.0, ch=0.05),
		K.cbox(-0.5, 0.5, 0.02, 0.98, 0.0, 2.0, ch=0.05),
		K.cbox(-0.5, 0.5, -1.0, 1.0, 2.0, 4.0, ch=0.08),
		K.cbox(-0.6, 0.6, -0.6, 0.6, 4.05, 5.2, ch=0.18),
	]
	arm_l = K.cbox(-0.45, 0.45, -2.0, -1.04, 2.05, 4.0, ch=0.06)
	K.place(arm_l, Matrix.Translation((0, -1.5, 3.9)) @ Matrix.Rotation(math.radians(-140), 4, "X") @ Matrix.Translation((0, 1.5, -3.9)))
	arm_r = K.cbox(-0.45, 0.45, 1.04, 2.0, 2.05, 4.0, ch=0.06)
	K.place(arm_r, Matrix.Translation((0, 1.5, 3.9)) @ Matrix.Rotation(math.radians(35), 4, "X") @ Matrix.Translation((0, -1.5, -3.9)))
	fig = gunkit.group(*body, arm_l, arm_r)
	K.place(fig, Matrix.Translation((0, 0, 0.3)) @ Matrix.Scale(s, 4))
	parts = {"Body": (fig, "Brass"), "Base": (K.cyl(0, 0, 0.6, 0.0, 0.3, segs=12, ch=0.04), "SteelBlack")}
	build_parts(name, parts, mats, col)
	return col


# ---------------------------------------------------------------- runner floors and pendants (fix pass)
# The oak runner is one finished floor instead of overlapping greybox Parts: straight tiles and 45 degree bend
# sectors, each with its steel edges and brass cross inlays cut in (no coplanar faces anywhere), oak grain running
# along the path (U = distance along the path, V = across). Its top is the collision top (0.06); the terrazzo bend
# floors sit at 0 (the collision floor top) on either side of it.

RUN_HW = 10.0  # runner half width (Wing_Market PATH)
RUN_TOP, RUN_BOT = 0.06, -0.2
RUN_EDGE = 0.24  # steel edge strip width
RUN_INLAY = 0.15  # brass inlay width
RUN_R = 36.0  # bend radius on the centre line (Wing_Market R)
BEND_SPAN = 45.0


def runner_uv_straight(bm):
	layer = bm.loops.layers.uv.verify()
	bm.normal_update()
	for f in bm.faces:
		for lp in f.loops:
			c = lp.vert.co
			lp[layer].uv = (c.x, c.y) if abs(f.normal.z) > 0.7 else (c.x + c.y, c.z)
	return bm


def runner_uv_bend(bm):
	# U = arc length at the centre line (bearing measured clockwise from north = +Y), V = across (r - R).
	layer = bm.loops.layers.uv.verify()
	bm.normal_update()
	for f in bm.faces:
		for lp in f.loops:
			c = lp.vert.co
			b = math.atan2(c.x, c.y)
			r = math.hypot(c.x, c.y)
			lp[layer].uv = (b * RUN_R, r - RUN_R) if abs(f.normal.z) > 0.7 else (b * RUN_R, c.z + r)
	return bm


def piece_runner(kit, mats):
	# MarketRunner: a 10-long straight runner tile, origin on the floor at the centre of its back (start) edge, the
	# path running along +X, width along Y. One brass cross inlay across its start edge (x 0..0.15, so tile joins sit
	# under brass, never as a grain seam), steel edges along both sides.
	name = "MarketRunner"
	col = new_piece(kit, name, {"length": 10.0, "width": 2 * RUN_HW})
	L, hw, e, t = 10.0, RUN_HW, RUN_EDGE, RUN_INLAY / 2
	oak = bmesh.new()
	K.merge(oak, drop_faces(lbox(2 * t, L, -hw + e, hw - e, RUN_BOT, RUN_TOP), 2, -1))
	inlay = drop_faces(lbox(0.0, 2 * t, -hw + e, hw - e, RUN_BOT, RUN_TOP), 2, -1)
	edge = bmesh.new()
	for y0, y1 in ((-hw, -hw + e), (hw - e, hw)):
		K.merge(edge, drop_faces(lbox(0.0, L, y0, y1, RUN_BOT, RUN_TOP), 2, -1))
	K.add_obj(name + "_Oak", oak, [mats["OakRunner"]], col, smooth_angle=0, uvs=runner_uv_straight)
	K.add_obj(name + "_Inlay", inlay, [mats["Brass"]], col, smooth_angle=0)
	K.add_obj(name + "_Edge", edge, [mats["SteelBlack"]], col, smooth_angle=0)
	return col


def piece_runner_bend(kit, mats):
	# MarketRunnerBend: the runner on a bend, a sector of the R36 centre line (r 26..46) spanning bearings 0..45
	# clockwise from north. Origin at the bend centre on the floor. Brass inlays every 15 degrees from its start edge
	# (9.4 studs on the centre line, the rhythm of the straight tiles; joins sit under brass), steel edges on both radii.
	name = "MarketRunnerBend"
	col = new_piece(kit, name, {"radius": RUN_R, "span": BEND_SPAN})
	r0, r1, e = RUN_R - RUN_HW, RUN_R + RUN_HW, RUN_EDGE
	dt = math.degrees(RUN_INLAY / RUN_R)
	cuts = [0.0, 15.0, 30.0]
	stops = []
	for c in cuts:
		stops.append(c + dt)
		stops.append(c + 15.0)

	def steps(a, b):
		return max(1, int(math.ceil((b - a) / 3.75 - 1e-6)))

	oak = bmesh.new()
	for i in range(0, len(stops), 2):
		a, b = stops[i], stops[i + 1]
		K.merge(oak, drop_faces(K.arc(r0 + e, r1 - e, a, b, RUN_BOT, RUN_TOP, steps=steps(a, b)), 2, -1))
	inlay = bmesh.new()
	for c in cuts:
		K.merge(inlay, drop_faces(K.arc(r0 + e, r1 - e, c, c + dt, RUN_BOT, RUN_TOP, steps=1), 2, -1))
	edge = bmesh.new()
	for a, b in ((r0, r0 + e), (r1 - e, r1)):
		K.merge(edge, drop_faces(K.arc(a, b, 0.0, BEND_SPAN, RUN_BOT, RUN_TOP, steps=steps(0, BEND_SPAN)), 2, -1))
	K.add_obj(name + "_Oak", oak, [mats["OakRunner"]], col, smooth_angle=0, uvs=runner_uv_bend)
	K.add_obj(name + "_Inlay", inlay, [mats["Brass"]], col, smooth_angle=0)
	K.add_obj(name + "_Edge", edge, [mats["SteelBlack"]], col, smooth_angle=0)
	return col


def piece_bend_floor(kit, mats):
	# MarketBendFloor: the terrazzo either side of the runner on a bend, r 13..26 and 46..58.6 (it tucks under the
	# R14 core rock and the R58 outer wall rock), bearings 0..45, top at 0. Replaces the overlapping greybox chords.
	name = "MarketBendFloor"
	col = new_piece(kit, name, {"radius": RUN_R, "span": BEND_SPAN})
	fl = bmesh.new()
	for a, b in ((13.0, RUN_R - RUN_HW), (RUN_R + RUN_HW, 58.6)):
		K.merge(fl, drop_faces(K.arc(a, b, 0.0, BEND_SPAN, -0.4, 0.0, steps=24), 2, -1))
	K.add_obj(name + "_Terrazzo", fl, [mats["Terrazzo"]], col, smooth_angle=0)
	return col


def piece_pendant(kit, mats):
	# MarketPendant: a black steel dome pendant with a warm glow disc and a brass collar, hung over the street.
	# Origin at the centre of the dome's bottom rim; the rod (MarketPendant_Rod) runs 1 stud up from the collar and
	# is stretched to the rock ceiling in Studio.
	name = "MarketPendant"
	col = new_piece(kit, name, {"rod": "z 1.75..2.75, stretched in Studio"})
	outer = [(0.32, 1.5), (0.8, 1.32), (1.18, 0.86), (1.38, 0.0)]
	inner = [(1.31, 0.0), (1.11, 0.84), (0.74, 1.24), (0.0, 1.4)]
	dome = K.lathe(outer, steps=16)
	K.merge(dome, K.lathe(inner, steps=16))
	K.merge(dome, K.lathe([(1.38, 0.0), (1.31, 0.0)], steps=16))
	glow = drop_faces(K.cyl(0, 0, 1.08, 0.42, 0.5, segs=16), 2, 1)
	collar = K.cyl(0, 0, 0.3, 1.45, 1.78, segs=12, ch=0.04)
	K.merge(collar, drop_faces(K.arc(1.33, 1.42, 0, 360, 0.0, 0.14, steps=16), 2, 1))
	rod = drop_faces(K.cyl(0, 0, 0.07, 1.75, 2.75, segs=6), 2, -1)
	K.add_obj(name + "_Shade", dome, [mats["SteelBlack"]], col, smooth_angle=40)
	K.add_obj(name + "_Collar", collar, [mats["Brass"]], col, smooth_angle=35)
	K.add_obj(name + "_Rod", rod, [mats["SteelBlack"]], col, smooth_angle=60)
	K.add_glow(name + "_Glow", glow, mats["Glow_Cove"], col)
	return col


# ---------------------------------------------------------------- contact sheet

def contact_sheet(pieces, path, samples=16, tile=(420, 300), cols=6):
	import numpy as np
	sc = bpy.context.scene
	sheet = K.collection("Sheet")
	K.render_settings(samples=samples)
	K.bloom(strength=0.4)
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	if bg:
		bg.inputs[0].default_value = (0.05, 0.05, 0.055, 1)
		bg.inputs[1].default_value = 1.4
	sun = bpy.data.lights.new("SheetSun", "SUN")
	sun.energy = 3.2
	sun.color = K.lin(K.L_MARKET)
	so = bpy.data.objects.new("SheetSun", sun)
	sheet.objects.link(so)
	so.rotation_euler = (-Vector((0.8, -1.0, 0.9))).to_track_quat("-Z", "Y").to_euler()
	fill = bpy.data.lights.new("SheetFill", "SUN")
	fill.energy = 0.9
	fill.color = (0.75, 0.82, 0.95)
	fo = bpy.data.objects.new("SheetFill", fill)
	sheet.objects.link(fo)
	fo.rotation_euler = (math.radians(60), 0, math.radians(150))
	tiles = []
	tmpdir = os.path.join(K.ART_DIR, "_sheet_tmp")
	os.makedirs(tmpdir, exist_ok=True)
	for name, col in pieces.items():
		inst = K.place_instance(col, Matrix.Identity(4), "Inst_" + name, sheet)
		# Bounds of the piece (kit masters at the origin).
		lo = Vector((1e9, 1e9, 1e9))
		hi = Vector((-1e9, -1e9, -1e9))
		for ob in col.all_objects:
			if ob.type != "MESH":
				continue
			for v in ob.data.vertices:
				p = ob.matrix_world @ v.co
				lo = Vector(map(min, lo, p))
				hi = Vector(map(max, hi, p))
		c = (lo + hi) / 2
		size = (hi - lo).length
		d = Vector((1.0, -0.75, 0.45)).normalized()
		ext = hi - lo
		fit = max(ext.x, ext.y, ext.z * 1.5, size * 0.6)
		cam = K.camera(c + d * fit * 1.6, c, lens=40.0, name="CamSheet", col=sheet)
		sc.camera = cam
		size = fit * 1.15
		txt = K.text(name, size * 0.022, (0, 0, 0), sheet, bpy.data.materials["SignText"], font=K.FONT_LABEL, align="LEFT")
		txt.parent = cam
		txt.location = (-size * 0.3, -size * 0.2, -size * 0.72)
		out = os.path.join(tmpdir, name + ".png")
		sc.render.resolution_x, sc.render.resolution_y = tile
		sc.render.resolution_percentage = 100
		sc.render.image_settings.file_format = "PNG"
		sc.render.filepath = out
		bpy.ops.render.render(write_still=True)
		tiles.append(out)
		bpy.data.objects.remove(inst)
		bpy.data.objects.remove(txt)
		bpy.data.objects.remove(cam)
	rows = (len(tiles) + cols - 1) // cols
	W, H = tile[0] * cols, tile[1] * rows
	big = np.zeros((H, W, 4), dtype=np.float32)
	big[:, :, 3] = 1
	for i, p in enumerate(tiles):
		img = bpy.data.images.load(p)
		px = np.array(img.pixels[:], dtype=np.float32).reshape(tile[1], tile[0], 4)
		r, c = divmod(i, cols)
		y0 = H - (r + 1) * tile[1]
		big[y0:y0 + tile[1], c * tile[0]:(c + 1) * tile[0], :] = px
		bpy.data.images.remove(img)
		os.remove(p)
	out = bpy.data.images.new("ContactSheet", W, H, alpha=False)
	out.pixels.foreach_set(big.ravel())
	out.filepath_raw = path
	out.file_format = "JPEG"
	sc.render.image_settings.quality = 90
	out.save_render(path) if hasattr(out, "save_render") else out.save()
	try:
		os.rmdir(tmpdir)
	except OSError:
		pass
	return path


# ---------------------------------------------------------------- main

def tri_count(col):
	n = 0
	for ob in col.all_objects:
		if ob.type == "MESH" and not ob.get("preview_only"):
			ob.data.calc_loop_triangles()
			n += len(ob.data.loop_triangles)
	return n


def main():
	t0 = time.time()
	mats = K.begin()
	m = K._flat("SkinPaint", 0x23B3A2, 0.32, metallic=0.2)
	m.use_fake_user = True
	mats["SkinPaint"] = m
	# The runner's oak: same variant, darker and less saturated than the slats (art review: the #94683F runner was
	# the most saturated surface on screen).
	mats["OakRunner"] = K._oak("OakRunner", 0x5A4635)
	kit = K.collection("Kit")
	pieces = {}
	for v, seed, cell, ledges in (("A", 301, 2.1, 4), ("B", 317, 2.2, 5), ("C", 333, 2.0, 4), ("D", 349, 2.5, 3), ("E", 365, 2.3, 5)):
		pieces["MarketRockWall_" + v] = piece_rock_wall(kit, mats, v, seed, cell=cell, ledges=ledges)
	pieces["MarketRockWall_Feature"] = piece_rock_feature(kit, mats)
	pieces["MarketRockCore_A"] = piece_rock_core(kit, mats, "A", 401)
	pieces["MarketRockCore_B"] = piece_rock_core(kit, mats, "B", 419)
	pieces["MarketRockCeiling_A"] = piece_rock_ceiling(kit, mats, "A", 503)
	pieces["MarketRockCeiling_B"] = piece_rock_ceiling(kit, mats, "B", 521)
	pieces["MarketRockSlab_A"] = piece_rock_slab(kit, mats, "A", 601, 2.4, 0.0)
	pieces["MarketRockSlab_B"] = piece_rock_slab(kit, mats, "B", 613, 2.1, 0.3)
	pieces["MarketRockSlab_C"] = piece_rock_slab(kit, mats, "C", 631, 2.7, -0.3)
	pieces["MarketRockPillar_A"] = piece_rock_pillar(kit, mats, "A", 701, 4.0)
	pieces["MarketRockPillar_B"] = piece_rock_pillar(kit, mats, "B", 719, -4.0)
	pieces["MarketRockDrop_A"] = piece_rock_drop(kit, mats, "A", 801, 0.35)
	pieces["MarketRockDrop_B"] = piece_rock_drop(kit, mats, "B", 823, 0.5)
	pieces["MarketRockHood"] = piece_rock_hood(kit, mats)
	pieces["MarketPortal"] = piece_portal(kit, mats)
	pieces["ShopPavilion"] = piece_shop_pavilion(kit, mats)
	pieces["FeaturedPodium"] = piece_podium(kit, mats)
	pieces["BattlePassWall"] = piece_battle_pass(kit, mats)
	pieces["MarketSignFrame"] = piece_sign_frame(kit, mats)
	pieces["MarketShowRifle"] = piece_show_rifle(kit, mats)
	pieces["MarketShowCrate"] = piece_show_crate(kit, mats)
	pieces["MarketShowCoins"] = piece_show_coins(kit, mats)
	pieces["MarketShowCharm"] = piece_show_charm(kit, mats)
	pieces["MarketShowFigure"] = piece_show_figure(kit, mats)
	pieces["MarketRunner"] = piece_runner(kit, mats)
	pieces["MarketRunnerBend"] = piece_runner_bend(kit, mats)
	pieces["MarketBendFloor"] = piece_bend_floor(kit, mats)
	pieces["MarketPendant"] = piece_pendant(kit, mats)
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True

	tris = {n: tri_count(c) for n, c in pieces.items()}
	big = {}
	for c in pieces.values():
		for ob in c.all_objects:
			if ob.type == "MESH":
				ob.data.calc_loop_triangles()
				big[ob.name] = len(ob.data.loop_triangles)
	print("MARKET_TRIS " + json.dumps(tris))
	print("MARKET_MAX_OBJECT %s %d" % max(big.items(), key=lambda kv: kv[1]))
	blend = K.save("Kit_Market")
	print("MARKET saved", blend, "%.1fs" % (time.time() - t0))
	if "--no-render" in ARGS:
		return
	samples = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 16
	only = ARGS[ARGS.index("--only") + 1].split(",") if "--only" in ARGS else None
	sel = {k: v for k, v in pieces.items() if not only or k in only}
	out = os.path.join(K.RENDER_DIR, "contact-market.jpg" if not only else "contact-market-check.jpg")
	contact_sheet(sel, out, samples=samples)
	print("MARKET contact sheet", out, "%.1fs" % (time.time() - t0))


main()
