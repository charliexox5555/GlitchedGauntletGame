# build_map_kit_metro.py: the Metro map kit, group "Station" (vault/01 Design/Maps/Metro.md, "How a map is built" in
# vault/01 Design/Maps/00 Maps.md). Meridian station: tiled hall walls, coffered ceiling, columns, platform edges,
# track, the two-car trains, escalators and stairs, the departure gantry, the end walls with the tunnel portals and
# name panels, kiosks, vending, benches, fare gates, ticket office, portals, corridor dressing and light fixtures.
#
# Every piece is a collection Map_<Piece> built at the world origin. Pieces are modelled in ROBLOX MAP SPACE terms
# (helpers rb/rx/rz/ry below convert): +X across, +Y up, +Z along the map (team B's end); Blender = (x, -z, y), which
# is the importer's own mapping, so put(piece, at(x, y, z, yaw)) in Art.luau lands them exactly. Origins:
#   wall pieces (WallBay8, WallEnd4, WallDoor8, PipeRun8, Vending, Bench): on the floor at the wall face, the piece
#     faces +X (into the room), length along Z.
#   EndWall: the hall end face (z = 48 for team B) at platform level, centre; it faces -Z (into the hall); the
#     escalator well is on its +X side.
#   Coffer10/Coffer14, PendantLight: centre on the floor below (built at their real heights: coffers recess up from
#     the 28 ceiling, pendants hang 21..28), so put() them at y = 0.
#   TrainCarHead/TrainCarTail: car centre on the car floor (platform level); platform side +X, the head car's cab at
#     +Z, the tail car's cab at -Z. TrainGangway: centre on the floor.
#   EscalatorBank, HallStairs, CorridorStair: bottom front centre on the lower floor; they rise toward +Z.
#   Gantry: centre of the hall at platform level (it hangs from 28 down to 11, the clock to 3).
#   Props (Column, Kiosk, TrackBay8, TrackBox, FareGateRow, TicketOffice, Portal10, DoorFrame8, PumpDoor,
#     CorridorLight, PlatformEdge8): on the floor at the centre (wall-mounted ones at the wall face, facing +X).
# Parts that take the end colour in Studio (team B blue #2F64C8, team A yellow #E0A82E) end in _Band, _Stripe or _Trim.
# Neon parts are separate *_Glow objects. Signs and the departure board text are SurfaceGuis made by Art.luau; the
# text here is preview-only.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_map_kit_metro.py -- [--no-render] [--samples N] [--only sheet|hero|terrace]
# Writes art-source/maps/Metro/Kit_Metro.blend and, in vault/02 Art/References/maps/metro/, contact-station.jpg
# (every piece) and preview-hall.jpg / preview-terrace.jpg (a dressed half of the hall), and prints METRO_TRIS.
# Export: blender --background --factory-startup art-source/maps/Metro/Kit_Metro.blend \
#           --python tools/blender/export_lobby_kit.py -- --maps Metro Station

import json, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
from gunkit import prism, box, merge, group, ring_pts  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ART_DIR = os.path.join(K.ROOT, "art-source", "maps", "Metro")
RENDER_DIR = os.path.join(K.ROOT, "vault", "02 Art", "References", "maps", "metro")

# Layout numbers (tools/maps/metro_layout.py)
CEIL = 28.0
TERR = 14.0
TRENCH = -4.0
HALL_X = 34.0

# ---------------------------------------------------------------- palette

C_TILE = 0xE7E6E1
C_TILE_DARK = 0x2E3440
C_BLUE = 0x2F64C8
C_YELLOW = 0xE0A82E
C_GRANITE = 0xA8A49C
C_GRANITE_DARK = 0x6F6C67
C_CONCRETE = 0xA7A49D  # mid grey: the white tile reads against it (ceiling, upper walls, beams)
C_CONCRETE_DARK = 0x6B6A68
C_STEEL = 0x22252A
C_BRUSHED = 0xA7ABB0
C_STAINLESS = 0xC9CDD2
C_BALLAST = 0x3C3D40
C_SLEEPER = 0x6A645C
C_RAIL = 0x9A9EA4
C_TACTILE = 0xE8C547
C_RUBBER = 0x2F3339
C_SEAT = 0x3E5566
C_WOOD = 0x94683F
C_SCREEN = 0x0B0D10

GLOW = {
	"G_Cool": (0xDDE8F2, 2.6),  # fluorescent tubes
	"G_Coffer": (0xB8C8DC, 2.4),  # the lit coffer panels (the "underground sky")
	"G_Warm": (0xFFD9A8, 2.2),  # kiosks, ticket office
	"G_Amber": (0xFFB547, 2.4),  # departure board, destination signs
	"G_Head": (0xFFF4E0, 3.5),  # headlights
	"G_Red": (0xE03A3A, 2.5),  # tail lights, buffer lamps, signals
	"G_Green": (0x3DDC84, 2.5),  # gate indicators
}


def tile_material(name, color, tile=(1.0, 0.5), grout=0x8C8B86):
	# Glazed tile preview: a running grid of tile x tile studs with thin grout lines and a gentle gloss. Roblox gets
	# CeramicTiles + rbx_color; the grid here only previews the scale.
	m, g, b = K._base(name, "CeramicTiles", "", color)
	u, v = g.uv()
	d, (cu, cv), _ = g.grid_dist(u, v, tile[0], tile[1])
	line = g.inv(g.smooth(0.0, 0.035, d))
	w = g.white(g.xyz(cu, cv, 2.3))
	tone = g.remap(w, 0.0, 1.0, 0.97, 1.03)
	base = g.col(color, tone)
	g.set(b.inputs["Base Color"], g.mix(line, base, (*K.lin(grout), 1)))
	g.set(b.inputs["Roughness"], g.remap(line, 0.0, 1.0, 0.18, 0.7))
	g.set(b.inputs["Normal"], g.bump(g.inv(line), 0.25, 0.02))
	return m


def stone_material(name, color, rbx="Granite", speck=0.12):
	m, g, b = K._base(name, rbx, "", color)
	u, v = g.uv()
	p = g.xyz(u, v, 0.0)
	cloud = g.remap(g.noise(p, 0.2, 3.0), 0.3, 0.7, 0.94, 1.05)
	vo = g.voronoi(p, 4.0)
	sp = g.mul(g.inv(g.smooth(0.1, 0.18, vo.outputs["Distance"])), g.smooth(0.5, 0.55, g.sep(vo.outputs["Color"])[0]))
	f = g.mul(cloud, g.add(1.0, g.mul(sp, -speck)))
	g.set(b.inputs["Base Color"], g.col(color, f))
	g.set(b.inputs["Roughness"], g.remap(g.noise(p, 0.5, 2.0), 0.3, 0.7, 0.42, 0.6))
	return m


def make_materials():
	mats = K.begin()  # the Lobby library (used for Mannequin, SignText, trims); Metro's own below
	own = [
		tile_material("M_TileWhite", C_TILE),
		tile_material("M_TileDark", C_TILE_DARK, grout=0x1E2229),
		tile_material("M_TileBand", C_BLUE, tile=(0.5, 0.5), grout=0x24498F),
		stone_material("M_Granite", C_GRANITE),
		stone_material("M_GraniteDark", C_GRANITE_DARK),
		stone_material("M_Concrete", C_CONCRETE, rbx="Concrete", speck=0.04),
		stone_material("M_ConcreteDark", C_CONCRETE_DARK, rbx="Concrete", speck=0.04),
		stone_material("M_Ballast", C_BALLAST, rbx="Slate", speck=0.3),
		K._flat("M_Sleeper", C_SLEEPER, 0.85, rbx="Concrete"),
		K._metal("M_Steel", C_STEEL, 0.38, 0.05, metallic=0.85),
		K._metal("M_Brushed", C_BRUSHED, 0.3, 0.08, brushed=True, metallic=0.75),
		K._metal("M_Stainless", C_STAINLESS, 0.28, 0.06, brushed=True, metallic=0.8),
		K._metal("M_Rail", C_RAIL, 0.3, 0.05, metallic=0.9),
		K._flat("M_Stripe", C_BLUE, 0.4, rbx="SmoothPlastic"),
		K._flat("M_Trim", C_BLUE, 0.4, rbx="SmoothPlastic"),
		K._flat("M_Tactile", C_TACTILE, 0.55, rbx="SmoothPlastic"),
		K._flat("M_Rubber", C_RUBBER, 0.85, rbx="Rubber"),
		K._flat("M_Seat", C_SEAT, 0.8, rbx="Fabric"),
		K._oak("M_Wood", C_WOOD),
		K._flat("M_Screen", C_SCREEN, 0.2),
		K._flat("M_White", 0xF2F2EE, 0.35),
		K._flat("M_Red", 0xB3262E, 0.45),
		K._flat("M_Hazard", 0xE2B93B, 0.5),
		K._flat("M_Product1", 0xC8553D, 0.5),
		K._flat("M_Product2", 0x2E86AB, 0.5),
		K._flat("M_Product3", 0xF2C14E, 0.5),
		K._glass("M_Glass", 0xA9C9CF),
	]
	dark = K._glass("M_DarkGlass", 0x1A1F26)
	dark["rbx_transparency"] = 0.12
	dark.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.92
	own.append(dark)
	for name, (c, s) in GLOW.items():
		own.append(K._emissive(name, c, s))
	for m in own:
		m["rbx_variant"] = ""  # base materials only: the match place has no MaterialVariants (K._oak sets Lobby_Oak)
		mats[m.name] = m
	return mats


# ---------------------------------------------------------------- geometry in map space

def rb(x0, x1, y0, y1, z0, z1, ch=0.0):
	# Box in Roblox (x, y up, z) terms -> Blender bmesh.
	ax0, ax1 = sorted((x0, x1))
	ay0, ay1 = sorted((y0, y1))
	az0, az1 = sorted((z0, z1))
	if ch > 0:
		return K.cbox(ax0, ax1, -az1, -az0, ay0, ay1, ch=ch)
	return K.mat_all(box(ax0, ax1, -az1, -az0, ay0, ay1), 0)


def rx(pts_zy, x0, x1):
	# Profile in Roblox (z, y), extruded along x.
	return fix(prism([(-z, y) for z, y in pts_zy], "X", min(x0, x1), max(x0, x1)))


def rz(pts_xy, z0, z1):
	# Profile in Roblox (x, y), extruded along z.
	return fix(prism(list(pts_xy), "Y", -max(z0, z1), -min(z0, z1)))


def ry(pts_xz, y0, y1):
	# Plan profile in Roblox (x, z), extruded up.
	return fix(prism([(x, -z) for x, z in pts_xz], "Z", min(y0, y1), max(y0, y1)))


def vcyl(x, z, r, y0, y1, segs=12):
	return K.cyl(x, -z, r, y0, y1, segs=segs)


def zcyl(x, y, r, z0, z1, segs=12):
	# Cylinder along Roblox z.
	return fix(prism(ring_pts(x, y, r, segs, math.pi / segs), "Y", -max(z0, z1), -min(z0, z1)))


def xcyl(y, z, r, x0, x1, segs=12):
	return fix(prism(ring_pts(-z, y, r, segs, math.pi / segs), "X", min(x0, x1), max(x0, x1)))


def fix(bm):
	K.mat_all(bm, 0)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def G(*bms):
	return group(*bms)


def yaw(deg, bm):
	# Turn a part about the Roblox Y axis (same as Blender Z).
	return K.place(bm, Matrix.Rotation(math.radians(deg), 4, "Z"))


def move(bm, x=0.0, y=0.0, z=0.0):
	return K.place(bm, Matrix.Translation((x, -z, y)))


def rtext(col, mats, body, size, x, y, z, facing, mat="SignText", font=None):
	# Preview-only stand-in for a SurfaceGui text (Art.luau makes the real one). facing: "-z", "+z", "+x", "-x".
	n = Vector({"-z": (0, 1, 0), "+z": (0, -1, 0), "+x": (1, 0, 0), "-x": (-1, 0, 0)}[facing])
	up = Vector((0, 0, 1))
	right = up.cross(n)
	ob = K.text(body, size, (x, -z, y), col, mats[mat], font=font or K.FONT_HEAVY)
	m = Matrix((right, up, n)).transposed().to_4x4()
	m.translation = Vector((x, -z, y))
	ob.matrix_world = m
	return ob


PIECES = []


def piece(name, parts, mats, kit):
	# parts: {part: (bmesh, material)}; glow parts end in _Glow.
	col = K.collection("Map_" + name, kit)
	for part, (bm, mname) in parts.items():
		oname = "%s_%s" % (name, part)
		if part.endswith("_Glow"):
			ob = K.add_glow(oname, bm, mats[mname], col)
		else:
			ob = K.add_obj(oname, bm, [mats[mname]], col)
		if mname == "M_Glass":
			ob.visible_shadow = False
	PIECES.append((name, col))
	return col


def steps(x0, x1, z0, run, rise, n, nose=0.08):
	# Solid stair: n steps from (z0, y 0) rising toward +z over `run` to `rise`. Returns (treads, nosings).
	tr = bmesh.new()
	no = bmesh.new()
	dz, dy = run / n, rise / n
	for i in range(n):
		za, zb = z0 + i * dz, z0 + (i + 1) * dz
		ya = (i + 1) * dy
		merge(tr, rb(x0, x1, 0.0, ya - nose, za, zb))
		merge(no, rb(x0, x1, ya - nose, ya, za, za + 0.35))
		merge(no, rb(x0, x1, ya - nose, ya, za + 0.35, zb))
	return tr, no


def slope_panel(x0, x1, z0, z1, y0a, y1a, ya_top, yb_top):
	# A parallelogram panel along a slope: bottom edge from (z0, y0a) to (z1, y1a), top edge raised.
	return rx([(z0, y0a), (z1, y1a), (z1, yb_top), (z0, ya_top)], x0, x1)


# ---------------------------------------------------------------- walls and ceiling

def wall_layers(z0, z1, rib=True, upper_from=20.0):
	# The hall wall cladding between z0 and z1 (faces +X, wall face at x = 0).
	p = {
		"Dado": (rb(0, 0.35, 0, 3.0, z0, z1, ch=0.05), "M_TileDark"),
		"Field": (G(rb(0, 0.25, 3.0, 9.4, z0, z1), rb(0, 0.25, 12.6, 19.0, z0, z1)), "M_TileWhite"),
		"Band": (rb(0, 0.32, 9.6, 12.4, z0, z1), "M_TileBand"),
		"BandTrim": (G(rb(0, 0.42, 9.4, 9.6, z0, z1), rb(0, 0.42, 12.4, 12.6, z0, z1)), "M_Steel"),
		"Skirting": (rb(0, 0.5, 0, 0.35, z0, z1, ch=0.04), "M_Steel"),
		"Upper": (rb(0, 0.15, upper_from, CEIL, z0, z1), "M_Concrete"),
		# Uplight cove: a shelf at 19 with a lip; the strip washes the concrete upper wall.
		"Cove": (G(rb(0, 1.4, 18.7, 19.0, z0, z1, ch=0.03), rb(1.25, 1.4, 19.0, 19.55, z0, z1)), "M_Steel"),
		"Cove_Glow": (rb(0.85, 1.15, 19.0, 19.12, z0 + 0.05, z1 - 0.05), "G_Cool"),
	}
	if upper_from > 19.0:
		p["Field"] = (G(p["Field"][0], rb(0, 0.25, 19.0, upper_from, z0, z1)), "M_TileWhite")
	if rib:
		zc = (z0 + z1) / 2
		p["Rib"] = (rb(0, 1.6, 19.55, CEIL, zc - 0.6, zc + 0.6, ch=0.12), "M_Concrete")
	return p


def p_wall_bay(mats, kit):
	piece("WallBay8", wall_layers(-4, 4), mats, kit)
	piece("WallEnd4", wall_layers(-2, 2, rib=False), mats, kit)


def p_wall_door(mats, kit):
	# An 8-wide, 10-tall service door through the 2-thick hall wall (the opening is the whole bay).
	p = {
		"Field": (rb(0, 0.25, 12.6, 19.0, -4, 4), "M_TileWhite"),
		"Band": (rb(0, 0.32, 10.2, 12.4, -4, 4), "M_TileBand"),
		"BandTrim": (G(rb(0, 0.42, 12.4, 12.6, -4, 4)), "M_Steel"),
		"Upper": (rb(0, 0.15, 19.0, CEIL, -4, 4), "M_Concrete"),
		"Cove": (G(rb(0, 1.4, 18.7, 19.0, -4, 4, ch=0.03), rb(1.25, 1.4, 19.0, 19.55, -4, 4)), "M_Steel"),
		"Cove_Glow": (rb(0.85, 1.15, 19.0, 19.12, -3.95, 3.95), "G_Cool"),
		# Steel reveal lining the opening (jambs and head, through the wall) and a frame on the face.
		"Frame": (G(
			rb(-2.0, 0.45, 0, 10.0, -4.0, -3.85), rb(-2.0, 0.45, 0, 10.0, 3.85, 4.0),
			rb(-2.0, 0.45, 9.85, 10.2, -4.0, 4.0),
		), "M_Steel"),
		"Kick": (rb(-2.0, 0.0, 0, 0.05, -3.85, 3.85), "M_Rubber"),
		# EXIT-style sign box over the door (text in Studio)
		"Sign": (rb(0.3, 1.0, 10.6, 11.9, -2.2, 2.2, ch=0.05), "M_Steel"),
		"Sign_Glow": (rb(1.0, 1.04, 10.75, 11.75, -2.05, 2.05), "G_Green"),
	}
	piece("WallDoor8", p, mats, kit)


def coffer(w, d=8.0, depth=3.0, beam=1.0):
	# One ceiling coffer w (x) by d (z): the soffit ring at y = CEIL, sloped sides up `depth`, a flat top, and a
	# hidden cove strip around the top that makes the coffer glow ("underground sky").
	hw, hd = w / 2, d / 2
	ib = beam / 2
	bottom = [(-hw + ib, -hd + ib), (hw - ib, -hd + ib), (hw - ib, hd - ib), (-hw + ib, hd - ib)]
	inset = 1.1
	top = [(-hw + ib + inset, -hd + ib + inset), (hw - ib - inset, -hd + ib + inset), (hw - ib - inset, hd - ib - inset), (-hw + ib + inset, hd - ib - inset)]
	bm = bmesh.new()
	vb = [bm.verts.new((x, -z, CEIL)) for x, z in bottom]
	vt = [bm.verts.new((x, -z, CEIL + depth)) for x, z in top]
	for i in range(4):
		j = (i + 1) % 4
		bm.faces.new((vb[i], vb[j], vt[j], vt[i]))
	bm.faces.new(vt)
	# the soffit (beam undersides) as a frame
	outer = [bm.verts.new((x, -z, CEIL)) for x, z in [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)]]
	for i in range(4):
		j = (i + 1) % 4
		bm.faces.new((outer[i], outer[j], vb[j], vb[i]))
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
	fix(bm)
	# make every face point down/inward (seen from below)
	for f in bm.faces:
		c = f.calc_center_median()
		if f.normal.z > 0.5:
			f.normal_flip()
		elif abs(f.normal.z) < 0.99 and f.normal.dot(Vector((-c.x, -c.y, 0))) < 0:
			f.normal_flip()
	# The lit panel: inset in the coffer top, a hair below it.
	tx0, tz0, tx1, tz1 = -hw + ib + inset + 0.5, -hd + ib + inset + 0.5, hw - ib - inset - 0.5, hd - ib - inset - 0.5
	glow = rb(tx0, tx1, CEIL + depth - 0.08, CEIL + depth - 0.03, tz0, tz1)
	return bm, glow


def p_coffers(mats, kit):
	for w in (10, 14):
		shell, glow = coffer(float(w))
		piece("Coffer%d" % w, {"Shell": (shell, "M_Concrete"), "Panel_Glow": (glow, "G_Coffer")}, mats, kit)


def p_pendant(mats, kit):
	# 8-long linear fluorescent pendant hung from the ceiling (origin at the ceiling plane) on two rods; bottom at 21.
	p = {
		"Rods": (G(vcyl(0, -3, 0.06, 22.0, CEIL, segs=6), vcyl(0, 3, 0.06, 22.0, CEIL, segs=6)), "M_Steel"),
		"Housing": (rb(-0.35, 0.35, 21.2, 22.0, -4, 4, ch=0.08), "M_Steel"),
		"Tube_Glow": (rb(-0.25, 0.25, 21.05, 21.2, -3.9, 3.9), "G_Cool"),
	}
	piece("PendantLight", p, mats, kit)


# ---------------------------------------------------------------- hall floor pieces

def p_column(mats, kit):
	p = {
		"Base": (rb(-2.1, 2.1, 0, 3.0, -2.1, 2.1, ch=0.08), "M_TileDark"),
		"Body": (rb(-2.0, 2.0, 3.0, 22.0, -2.0, 2.0, ch=0.2), "M_TileWhite"),
		"Band": (rb(-2.08, 2.08, 9.6, 12.4, -2.08, 2.08, ch=0.05), "M_TileBand"),
		"Guards": (G(*[rb(sx * 2.15 - 0.3, sx * 2.15 + 0.3, 0.35, 6.0, sz * 2.15 - 0.3, sz * 2.15 + 0.3, ch=0.05)
					for sx in (-1, 1) for sz in (-1, 1)]), "M_Brushed"),
		"Skirt": (rb(-2.2, 2.2, 0, 0.35, -2.2, 2.2, ch=0.04), "M_Steel"),
		# Capital: a flared neck into the coffer beams.
		"Capital": (G(
			ry([(-2.0, -2.0), (2.0, -2.0), (2.0, 2.0), (-2.0, 2.0)], 22.0, 22.4),
			_flare(2.0, 2.7, 22.4, 26.8), rb(-2.9, 2.9, 26.8, CEIL, -2.9, 2.9, ch=0.12),
		), "M_Concrete"),
	}
	piece("Column", p, mats, kit)


def _flare(r0, r1, y0, y1):
	# A square frustum (column capital).
	bm = bmesh.new()
	a = [bm.verts.new((sx * r0, sz * r0, y0)) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
	b = [bm.verts.new((sx * r1, sz * r1, y1)) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
	for i in range(4):
		j = (i + 1) % 4
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bm.faces.new(a)
	bm.faces.new(b)
	return fix(bm)


def p_platform_edge(mats, kit):
	# 8 long. Origin at the platform edge line on the platform floor; the trench is +X (the edge faces +X).
	p = {
		"Coping": (rb(-1.0, 0.08, -0.35, 0.03, -4, 4, ch=0.05), "M_Concrete"),
		"Tactile": (rb(-2.4, -1.15, 0, 0.05, -4, 4), "M_Tactile"),
		"Wall": (rb(-0.1, 0.0, TRENCH, -0.35, -4, 4), "M_ConcreteDark"),
		"Trough": (rb(0.0, 0.55, -2.4, -1.6, -4, 4, ch=0.05), "M_Brushed"),
		"Recess": (rb(-0.12, 0.02, TRENCH, -2.6, -4, 4), "M_TileDark"),
	}
	ribs = bmesh.new()
	for i in range(10):
		z = -4 + 0.4 + i * 0.8
		merge(ribs, rb(-2.35, -1.2, 0.05, 0.09, z - 0.15, z + 0.15))
	p["TactileRibs"] = (ribs, "M_Tactile")
	piece("PlatformEdge8", p, mats, kit)


def p_track(mats, kit):
	# 8 long, one track (gauge 4.4), origin at the track centreline on the trench floor (y = TRENCH = -4 in map
	# space; the piece is built with its floor at 0 and placed at y = -4).
	sl = bmesh.new()
	for i in range(4):
		z = -4 + 1.0 + i * 2.0
		merge(sl, rb(-3.2, 3.2, 0.3, 0.62, z - 0.45, z + 0.45, ch=0.06))
	rails = bmesh.new()
	for x in (-2.2, 2.2):
		prof = [(x - 0.3, 0.62), (x + 0.3, 0.62), (x + 0.3, 0.7), (x + 0.07, 0.75), (x + 0.07, 0.95), (x + 0.16, 1.0), (x + 0.16, 1.12),
				(x - 0.16, 1.12), (x - 0.16, 1.0), (x - 0.07, 0.95), (x - 0.07, 0.75), (x - 0.3, 0.7)]
		merge(rails, rz(prof, -4, 4))
	p = {
		"Ballast": (rz([(-4.8, 0.0), (4.8, 0.0), (4.2, 0.4), (-4.2, 0.4)], -4, 4), "M_Ballast"),
		"Sleepers": (sl, "M_Sleeper"),
		"Rails": (rails, "M_Rail"),
		# Conductor-rail cover on the outer side, a safety-yellow edge.
		"Cover": (rb(3.6, 4.3, 0.4, 0.9, -4, 4, ch=0.05), "M_Hazard"),
	}
	piece("TrackBay8", p, mats, kit)


def p_track_box(mats, kit):
	# Relay cabinet in the trench (collision 3 x 3.5 x 6), back on the trench wall (x = 0), facing +X.
	p = {
		"Body": (rb(0.0, 2.9, 0.0, 3.4, -2.9, 2.9, ch=0.08), "M_Brushed"),
		"Plinth": (rb(0.1, 3.0, 0.0, 0.3, -3.0, 3.0), "M_ConcreteDark"),
		"Doors": (G(rb(2.9, 2.98, 0.4, 3.1, -2.7, -0.05), rb(2.9, 2.98, 0.4, 3.1, 0.05, 2.7)), "M_Steel"),
		"Stripe": (rb(2.98, 3.0, 2.6, 2.9, -2.7, 2.7), "M_Hazard"),
	}
	piece("TrackBox", p, mats, kit)


# ---------------------------------------------------------------- trains

CAR_L = 25.0
CAR_W = 10.0


def car(head):
	# One car, centre on the floor; platform side +X. head=True: cab at +Z, gangway at -Z. Doors: platform side
	# at local -8..-2 and 2..8; track side one open door next to the gangway (head: -8..-2, tail: 2..8).
	hz = CAR_L / 2
	hw = CAR_W / 2
	cab = hz if head else -hz
	s = 1 if head else -1
	pdoors = [(-8.0, -2.0), (2.0, 8.0)]
	tdoor = (-8.0, -2.0) if head else (2.0, 8.0)
	skin = bmesh.new()
	stripe = bmesh.new()
	dark = bmesh.new()
	glass = bmesh.new()
	frames = bmesh.new()
	# Platform side (+X): lower band, door posts, upper band; windows in the gaps (glass, decor).
	edges = [-hz] + [e for d in pdoors for e in d] + [hz]
	for i in range(0, len(edges), 2):
		za, zb = edges[i], edges[i + 1]
		merge(skin, rb(hw - 0.5, hw, 0.0, 3.5, za, zb))
	for da, db in pdoors:
		merge(skin, rb(hw - 0.5, hw, 3.5, 7.0, da - 1.0, da))
		merge(skin, rb(hw - 0.5, hw, 3.5, 7.0, db, db + 1.0))
		merge(frames, rb(hw - 0.55, hw + 0.04, 0.0, 7.2, da - 0.15, da))
		merge(frames, rb(hw - 0.55, hw + 0.04, 0.0, 7.2, db, db + 0.15))
		merge(frames, rb(hw - 0.55, hw + 0.04, 7.0, 7.2, da, db))
		# (platform-side leaves are slid into wall pockets: nothing may cover the shoot-through windows)
	merge(skin, rb(hw - 0.5, hw, 7.0, 9.0, -hz, hz))
	win = [(-hz, -9.0), (-1.0, 1.0), (9.0, hz)]
	for za, zb in win:
		merge(glass, rb(hw - 0.3, hw - 0.22, 3.5, 7.0, za, zb))
		for zz in (za, zb):
			merge(frames, rb(hw - 0.5, hw + 0.03, 3.5, 7.0, zz - 0.12, zz + 0.12))
	# Track side (-X): solid skin with dark glass bands and one open door.
	ta, tb = tdoor
	for za, zb in ((-hz, ta), (tb, hz)):
		merge(skin, rb(-hw, -hw + 0.5, 0.0, 9.0, za, zb))
		merge(dark, rb(-hw - 0.03, -hw, 3.5, 7.0, za + 0.8, zb - 0.8))
	merge(skin, rb(-hw, -hw + 0.5, 7.0, 9.0, ta, tb))
	merge(frames, G(rb(-hw - 0.04, -hw + 0.55, 0.0, 7.2, ta - 0.15, ta), rb(-hw - 0.04, -hw + 0.55, 0.0, 7.2, tb, tb + 0.15), rb(-hw - 0.04, -hw + 0.55, 7.0, 7.2, ta, tb)))
	for za, zb in ((ta - 3.0, ta), (tb, tb + 3.0)):
		merge(skin, rb(-hw - 0.12, -hw, 0.1, 7.0, za, zb, ch=0.04))
	# Stripe in the end colour along both sides (on the solid skin, below the windows).
	for x0, x1 in ((hw, hw + 0.03), (-hw - 0.03, -hw)):
		for za, zb in ([(-hz, -8.0), (-2.0, 2.0), (8.0, hz)] if x0 > 0 else [(-hz, ta), (tb, hz)]):
			merge(stripe, rb(x0, x1, 2.5, 3.1, za, zb))
	# Roof: a low curved crown over the collision roof (9..10), a few flat vents.
	roof = rz([(-hw, 9.0), (hw, 9.0), (hw, 9.45), (hw - 0.9, 9.95), (-hw + 0.9, 9.95), (-hw, 9.45)], -hz, hz)
	vents = G(*[rb(-1.6, 1.6, 9.95, 10.2, z - 1.4, z + 1.4, ch=0.06) for z in (-7.0, 3.0)])
	# Underbody: skirt, bogies, wheels on the rails (rail top at -2.88 under the floor: track floor -4 + 1.12).
	under = G(
		rb(-hw + 0.3, hw - 0.3, -1.4, 0.0, -hz + 0.6, hz - 0.6),
		rb(-hw + 0.2, hw - 0.2, -2.1, -1.4, -hz + 3.0, -hz + 6.0), rb(-hw + 0.2, hw - 0.2, -2.1, -1.4, hz - 6.0, hz - 3.0),
	)
	bogie = bmesh.new()
	wheels = bmesh.new()
	for bz in (-8.0, 8.0):
		merge(bogie, rb(-3.0, 3.0, -2.5, -1.4, bz - 2.6, bz + 2.6, ch=0.1))
		for wz in (bz - 1.6, bz + 1.6):
			for wx in (-2.2, 2.2):
				merge(wheels, xcyl(-2.0, wz, 0.88, wx - 0.2, wx + 0.2, segs=12))
	# Floor and interior.
	floor = rb(-hw + 0.5, hw - 0.5, -0.1, 0.0, -hz, hz)
	ceiling = rz([(-hw + 0.5, 8.3), (hw - 0.5, 8.3), (hw - 0.5, 9.0), (-hw + 0.5, 9.0)], -hz, hz)
	seats = bmesh.new()
	seatback = bmesh.new()
	for x0, x1, sx in ((hw - 1.8, hw - 0.5, 1), (-hw + 0.5, -hw + 1.8, -1)):
		runs = [(-hz + 0.3, -9.0), (-1.0, 1.0), (9.0, hz - 0.3)] if sx > 0 else [(-hz + 0.3, ta - 0.3), (tb + 0.3, hz - 0.3)]
		for za, zb in runs:
			if zb - za < 1.5:
				continue
			merge(seats, rb(x0, x1, 1.4, 1.9, za, zb, ch=0.12))
			merge(seats, rb(x0 + 0.2 * sx, x1 - 0.2 * sx if sx > 0 else x1, 0.0, 1.4, za + 0.2, zb - 0.2))
			bx = (hw - 0.75, hw - 0.5) if sx > 0 else (-hw + 0.5, -hw + 0.75)
			merge(seatback, rb(bx[0], bx[1], 1.9, 3.4, za, zb, ch=0.08))
	poles = bmesh.new()
	for z in (-8.0, -2.0, 2.0, 8.0):
		for x in (2.6, -2.6):
			merge(poles, vcyl(x, z, 0.1, 0.0, 8.3, segs=6))
	merge(poles, zcyl(2.6, 7.6, 0.07, -hz + 0.5, hz - 0.5, segs=6))
	merge(poles, zcyl(-2.6, 7.6, 0.07, -hz + 0.5, hz - 0.5, segs=6))
	lights = G(rb(1.6, 2.2, 8.2, 8.3, -hz + 1, hz - 1), rb(-2.2, -1.6, 8.2, 8.3, -hz + 1, hz - 1))
	# The end wall: the cab (with windscreen, lights and destination sign) or the gangway end.
	ez0, ez1 = (cab - 0.5, cab) if head else (cab, cab + 0.5)
	ends = rb(-hw, hw, 0.0, 9.0, ez0, ez1)
	g_head = bmesh.new()
	g_red = bmesh.new()
	g_amber = bmesh.new()
	if True:
		# The cab end (towards ±Z): a gentle nose, windscreen, headlights, tail lights, route sign.
		f = cab
		nose = rx([(f, -1.4), (f + 0.45 * s, -1.0), (f + 0.55 * s, 2.0), (f + 0.35 * s, 8.6), (f, 9.45)], -hw + 0.15, hw - 0.15)
		merge(skin, nose)
		merge(dark, rb(-hw + 0.9, hw - 0.9, 4.0, 7.6, f + 0.47 * s, f + 0.5 * s))
		merge(stripe, rb(-hw + 0.2, hw - 0.2, 2.5, 3.1, f + 0.56 * s, f + 0.59 * s))
		for x in (-3.3, 3.3):
			merge(g_head, rb(x - 0.55, x + 0.55, 1.35, 1.85, f + 0.56 * s, f + 0.6 * s))
			merge(g_red, rb(x - 0.35, x + 0.35, 0.6, 0.95, f + 0.56 * s, f + 0.6 * s))
		merge(g_amber, rb(-2.6, 2.6, 7.75, 8.35, f + 0.4 * s, f + 0.45 * s))
		merge(frames, rb(-hw + 0.3, hw - 0.3, -1.5, -0.4, f + 0.35 * s, f + 0.7 * s, ch=0.1))  # coupler bumper
	gz = -hz if head else hz
	gang = rb(-3.4, 3.4, 0.0, 8.6, gz - 0.02 if head else gz, gz if head else gz + 0.02)
	parts = {
		"Body": (G(skin, ends), "M_Stainless"),
		"Stripe": (stripe, "M_Stripe"),
		"DarkGlass": (dark, "M_DarkGlass"),
		"Glass": (glass, "M_Glass"),
		"Frames": (frames, "M_Steel"),
		"Roof": (G(roof, vents), "M_Stainless"),
		"Under": (G(under, bogie), "M_Steel"),
		"Wheels": (wheels, "M_Rail"),
		"Floor": (floor, "M_Rubber"),
		"Ceiling": (ceiling, "M_White"),
		"Seats": (seats, "M_Seat"),
		"SeatBack": (seatback, "M_Seat"),
		"Poles": (poles, "M_Brushed"),
		"Lights_Glow": (lights, "G_Cool"),
		"Head_Glow": (g_head, "G_Head"),
		"Tail_Glow": (g_red, "G_Red"),
		"Route_Glow": (g_amber, "G_Amber"),
	}
	del gang
	return parts


def p_trains(mats, kit):
	piece("TrainCarHead", car(True), mats, kit)
	piece("TrainCarTail", car(False), mats, kit)
	ribs = bmesh.new()
	for i in range(6):
		z = -1.0 + 0.2 + i * 0.32
		merge(ribs, rb(-3.6, 3.6, 0.0, 8.7, z - 0.06, z + 0.06))
	p = {
		"Bellows": (rb(-3.4, 3.4, 0.0, 8.6, -1.0, 1.0), "M_Rubber"),
		"Ribs": (ribs, "M_Steel"),
		"Floor": (rb(-3.0, 3.0, -0.08, 0.0, -1.2, 1.2), "M_Brushed"),
		"Under": (rb(-hw_g(), hw_g(), -1.2, 0.0, -1.0, 1.0), "M_Steel"),
	}
	piece("TrainGangway", p, mats, kit)


def hw_g():
	return 4.5


# ---------------------------------------------------------------- stairs

def p_escalators(mats, kit):
	# 9 wide (x -4.5..4.5), run 24, rise 14, rising toward +Z. Two escalators and a central fixed stair.
	run, rise = 24.0, 14.0
	slope = rise / run
	lanes = [(-4.4, -1.4), (-1.0, 1.0), (1.4, 4.4)]
	treads = bmesh.new()
	nos = bmesh.new()
	for i, (x0, x1) in enumerate(lanes):
		t, n = steps(x0, x1, 0.0, run, rise, 21)
		merge(treads, t)
		merge(nos, n)
	balus = bmesh.new()
	glass = bmesh.new()
	rail = bmesh.new()
	skirt = bmesh.new()
	for xa, xb in ((-4.5, -4.4), (-1.4, -1.25), (1.25, 1.4), (4.4, 4.5)):
		# deck along the slope, glass above, handrail on top
		merge(balus, slope_panel(xa - 0.1, xb + 0.1, -1.0, run, 0.0 - 0.6, rise - 0.6, 1.2, rise + 1.2))
		merge(glass, slope_panel(xa + 0.02, xb - 0.02, -0.5, run, 1.2, rise + 1.2, 3.2, rise + 3.2))
	for xc in (-4.45, -1.32, 1.32, 4.45):
		merge(rail, slope_panel(xc - 0.18, xc + 0.18, -0.8, run, 3.2, rise + 3.2, 3.55, rise + 3.55))
	# yellow comb plates at both ends and a lit skirt line along each escalator
	combs = G(rb(-4.4, -1.4, 0.0, 0.08, -1.2, 0.0), rb(1.4, 4.4, 0.0, 0.08, -1.2, 0.0), rb(-4.4, -1.4, rise, rise + 0.08, run, run + 1.2), rb(1.4, 4.4, rise, rise + 0.08, run, run + 1.2))
	glow = bmesh.new()
	for xc in (-4.36, -1.44, 1.44, 4.36):
		merge(glow, slope_panel(xc - 0.03, xc + 0.03, 0.0, run, 0.2, rise + 0.2, 0.32, rise + 0.32))
	p = {
		"Treads": (treads, "M_Brushed"),
		"Nosing": (nos, "M_Tactile"),
		"Deck": (balus, "M_Steel"),
		"Glass": (glass, "M_Glass"),
		"Handrail": (rail, "M_Rubber"),
		"Combs": (combs, "M_Tactile"),
		"Skirt_Glow": (glow, "G_Cool"),
	}
	piece("EscalatorBank", p, mats, kit)


def p_hall_stairs(mats, kit):
	# 8 wide (x -4..4), run 22, rise 14, rising toward +Z; closed tiled sides down to the floor (the collision is a
	# solid wedge), black steel stringer caps and a rail on posts.
	run, rise, n = 22.0, 14.0, 21
	t, no = steps(-3.9, 3.9, 0.0, run, rise, n)
	sides = bmesh.new()
	caps = bmesh.new()
	for x0, x1 in ((-4.0, -3.9), (3.9, 4.0)):
		merge(sides, rx([(0.0, 0.0), (run, 0.0), (run, rise - 0.2), (0.0, 0.45)], x0 - 0.12, x1 + 0.12))
		merge(caps, slope_panel(x0 - 0.18, x1 + 0.18, 0.0, run, 0.3, rise - 0.3, 0.75, rise + 0.15))
	posts = bmesh.new()
	rail = bmesh.new()
	for xc in (-3.95, 3.95):
		for i in range(6):
			z = 1.0 + i * (run - 2.0) / 5
			y = rise * z / run + 0.6
			merge(posts, rb(xc - 0.06, xc + 0.06, y, y + 2.9, z - 0.06, z + 0.06))
		merge(rail, slope_panel(xc - 0.09, xc + 0.09, 0.5, run, 0.6 + rise * 0.5 / run + 2.9, rise + 3.5, 0.6 + rise * 0.5 / run + 3.1, rise + 3.7))
	p = {
		"Treads": (t, "M_Granite"),
		"Nosing": (no, "M_GraniteDark"),
		"Sides": (sides, "M_TileWhite"),
		"Caps": (caps, "M_Steel"),
		"Posts": (posts, "M_Steel"),
		"Rail": (rail, "M_Brushed"),
	}
	piece("HallStairs", p, mats, kit)


def p_corridor_stair(mats, kit):
	run, rise = 24.0, 14.0
	t, no = steps(-5.9, 5.9, 0.0, run, rise, 21)
	rail = bmesh.new()
	for xc in (-5.75, 5.75):
		merge(rail, slope_panel(xc - 0.1, xc + 0.1, 0.0, run, 3.2, rise + 3.2, 3.4, rise + 3.4))
		for i in range(5):
			z = 1.0 + i * (run - 2.0) / 4
			y = rise * z / run
			merge(rail, rb(xc + (0.12 if xc > 0 else -0.32), xc + (0.32 if xc > 0 else -0.12), y + 3.0, y + 3.4, z - 0.08, z + 0.08))
	p = {"Treads": (t, "M_Concrete"), "Nosing": (no, "M_Hazard"), "Rail": (rail, "M_Hazard")}
	piece("CorridorStair", p, mats, kit)


# ---------------------------------------------------------------- landmarks

def p_gantry(mats, kit):
	# Full hall width (x -34..34), z -1.5..1.5: a concrete transfer beam from 18 up, the departure board housing 11..16,
	# platform signs over the platforms, the big two-faced clock between the trains (3..11).
	beam = G(rb(-HALL_X, HALL_X, 18.0, CEIL, -1.5, 1.5, ch=0.2), rb(-HALL_X, HALL_X, 17.4, 18.0, -1.3, 1.3))
	fascia = G(rb(-HALL_X, HALL_X, 16.0, 17.4, -1.55, 1.55, ch=0.06))
	housing = G(rb(-12.5, 12.5, 11.0, 16.0, -1.5, 1.5, ch=0.12), rb(-31.5, -16.5, 12.2, 16.0, -1.4, 1.4, ch=0.1), rb(16.5, 31.5, 12.2, 16.0, -1.4, 1.4, ch=0.1))
	# The housings over the platforms don't reach 11: the collision does; a dark steel skirt closes them down to 11.
	skirt = G(rb(-HALL_X, -12.5, 11.0, 12.2, -1.2, 1.2), rb(12.5, HALL_X, 11.0, 12.2, -1.2, 1.2), rb(-16.5, -12.5, 12.2, 16.0, -1.2, 1.2), rb(12.5, 16.5, 12.2, 16.0, -1.2, 1.2),
			  rb(-HALL_X, -31.5, 12.2, 16.0, -1.2, 1.2), rb(31.5, HALL_X, 12.2, 16.0, -1.2, 1.2))
	screens = bmesh.new()
	for sz in (-1, 1):
		merge(screens, rb(-12.0, 12.0, 11.5, 15.5, sz * 1.5, sz * 1.56))
		merge(screens, rb(-31.0, -17.0, 12.6, 15.6, sz * 1.4, sz * 1.46))
		merge(screens, rb(17.0, 31.0, 12.6, 15.6, sz * 1.4, sz * 1.46))
	amber = G(rb(-12.5, 12.5, 10.95, 11.05, -1.45, 1.45))
	trims = G(rb(-HALL_X, HALL_X, 16.9, 17.2, -1.62, -1.55), rb(-HALL_X, HALL_X, 16.9, 17.2, 1.55, 1.62))
	# Clock: drop housing from the board down, a round face on each side.
	clock_body = G(rb(-0.8, 0.8, 10.4, 11.0, -0.8, 0.8), zcyl(0.0, 6.8, 3.4, -1.3, 1.3, segs=32))
	rim = bmesh.new()
	face = bmesh.new()
	marks = bmesh.new()
	for sz in (-1, 1):
		ring = zcyl(0.0, 6.8, 3.5, sz * 1.3, sz * 1.45, segs=32)
		merge(rim, ring)
		merge(face, zcyl(0.0, 6.8, 3.1, sz * 1.45, sz * 1.47, segs=32))
		for i in range(12):
			a = math.radians(i * 30)
			L = 0.55 if i % 3 == 0 else 0.3
			wdt = 0.16 if i % 3 == 0 else 0.09
			m = rb(-wdt, wdt, 2.7 - L, 2.7, sz * 1.47, sz * 1.5)
			K.place(m, Matrix.Translation((0, 0, 6.8)) @ Matrix.Rotation(-a * sz, 4, "Y") @ Matrix.Translation((0, 0, -6.8)))
			merge(marks, m)
		# hands at 10:10, the station-clock look
		for ang, L, wdt in ((-60, 1.6, 0.14), (60, 2.4, 0.1)):
			m = rb(-wdt, wdt, 6.8 - 0.3, 6.8 + L, sz * 1.5, sz * 1.53)
			K.place(m, Matrix.Translation((0, 0, 6.8)) @ Matrix.Rotation(math.radians(ang) * sz, 4, "Y") @ Matrix.Translation((0, 0, -6.8)))
			merge(marks, m)
	p = {
		"Beam": (beam, "M_Concrete"),
		"Fascia": (fascia, "M_Steel"),
		"Trim": (trims, "M_Trim"),
		"Housing": (G(housing, skirt), "M_Steel"),
		"Screen": (screens, "M_Screen"),
		"Edge_Glow": (amber, "G_Amber"),
		"ClockBody": (G(clock_body, rim), "M_Steel"),
		"ClockFace": (face, "M_White"),
		"ClockMarks": (marks, "M_Steel"),
	}
	col = piece("Gantry", p, mats, kit)
	for sz, face in ((-1, "-z"), (1, "+z")):
		rtext(col, mats, "DEPARTURES", 0.9, 0, 15.0, sz * 1.6, face)
		for i, row in enumerate(("1  NORTHGATE      2 min", "2  RIVERSIDE      4 min", "1  NORTHGATE      9 min")):
			rtext(col, mats, row, 0.75, 0, 13.7 - i * 0.9, sz * 1.6, face, mat="G_Amber", font=K.FONT_LABEL)
		for x, label in ((-24, "PLATFORM 2"), (24, "PLATFORM 1")):
			rtext(col, mats, label, 1.3, x, 14.1, sz * 1.5, face)


def p_end_wall(mats, kit):
	# The hall end under a terrace (team B's at z = 48; local z = 0 is the face, the hall is -Z). Local x as in the map.
	# Below 14: tiled faces either side, the tunnel portal (x -14..14, trench -4 to 10) and the escalator mouth (x 25..34).
	# At 14..22: the station-name panel over the portal (sign text in Studio), the solid parapet either side.
	tile = bmesh.new()
	dado = bmesh.new()
	band = bmesh.new()
	trim = bmesh.new()
	for x0, x1 in ((-HALL_X, -14.0), (14.0, 25.0)):
		merge(dado, rb(x0, x1, 0.0, 3.0, -0.35, 0.0))
		merge(tile, rb(x0, x1, 3.0, 9.6, -0.25, 0.0))
		merge(band, rb(x0, x1, 9.6, 12.4, -0.32, 0.0))
		merge(tile, rb(x0, x1, 12.4, 13.4, -0.25, 0.0))
	# Portal: deep reveal, steel frame and the end-colour ring; the tunnel beyond is dark.
	portal = G(
		rb(-14.0, -13.4, TRENCH, 10.0, -0.6, 3.0), rb(13.4, 14.0, TRENCH, 10.0, -0.6, 3.0),
		rb(-14.0, 14.0, 9.4, 10.0, -0.6, 3.0),
	)
	merge(trim, G(rb(-14.6, -14.0, TRENCH, 10.6, -0.7, -0.2), rb(14.0, 14.6, TRENCH, 10.6, -0.7, -0.2), rb(-14.6, 14.6, 10.0, 10.6, -0.7, -0.2)))
	tunnel = G(rb(-13.4, 13.4, TRENCH, 9.4, 2.9, 3.0))
	lintel_face = G(rb(-14.6, 14.6, 10.6, 14.0, -0.3, 0.0), rb(-HALL_X, 25.0, 13.4, 14.0, -0.5, 0.0, ch=0.05))
	# Buffer stop on the open track at this end (the west track at team B's end: track centre x = -8.5).
	buffer = G(rb(-11.0, -6.0, TRENCH + 0.6, TRENCH + 2.6, 1.6, 2.4, ch=0.1), rb(-10.6, -10.0, TRENCH, TRENCH + 2.4, 1.8, 2.9), rb(-7.0, -6.4, TRENCH, TRENCH + 2.4, 1.8, 2.9))
	red = G(rb(-11.2, -10.4, TRENCH + 1.0, TRENCH + 1.6, 1.4, 1.6), rb(-7.0, -6.2, TRENCH + 1.0, TRENCH + 1.6, 1.4, 1.6))
	lamps = G(rb(-11.0, -10.6, TRENCH + 2.7, TRENCH + 3.1, 1.95, 2.05), rb(-6.4, -6.0, TRENCH + 2.7, TRENCH + 3.1, 1.95, 2.05))
	# Signal heads on the tunnel walls
	sig = G(rb(-13.4, -12.6, 4.0, 6.4, 0.3, 1.0, ch=0.08), rb(12.6, 13.4, 4.0, 6.4, 0.3, 1.0, ch=0.08))
	sig_r = G(rb(-13.0, -12.55, 5.5, 6.1, 0.0, 0.3), rb(12.55, 13.0, 5.5, 6.1, 0.0, 0.3))
	# Escalator mouth frame (x 25..34) up to the terrace level, with a hanging sign.
	mouth = G(rb(24.4, 25.0, 0.0, 14.0, -0.6, 0.6), rb(24.4, HALL_X, 13.4, 14.4, -0.6, 0.6, ch=0.05))
	msign = G(rb(26.0, 33.0, 11.0, 12.6, -0.3, 0.3, ch=0.06))
	# Terrace level: name panel (x -14..14, 14..22) and the parapets either side (3 tall, 1 deep, solid).
	panel = G(rb(-14.0, 14.0, 14.0, 22.0, 0.0, 1.0, ch=0.15))
	panel_face = G(rb(-13.2, 13.2, 14.8, 21.2, -0.06, 0.0))
	roundels = G(zcyl(-11.0, 18.0, 1.6, -0.12, -0.06, segs=24), zcyl(11.0, 18.0, 1.6, -0.12, -0.06, segs=24))
	bars = G(rb(-13.0, -9.0, 17.6, 18.4, -0.16, -0.12), rb(9.0, 13.0, 17.6, 18.4, -0.16, -0.12))
	parapet = G(rb(-36.0, -22.0, 14.0, 17.0, 0.0, 1.0, ch=0.1), rb(14.0, 24.0, 14.0, 17.0, 0.0, 1.0, ch=0.1))
	cap = G(rb(-36.0, -22.0, 17.0, 17.25, -0.1, 1.1, ch=0.05), rb(14.0, 24.0, 17.0, 17.25, -0.1, 1.1, ch=0.05))
	p = {
		"Tile": (tile, "M_TileWhite"),
		"Dado": (dado, "M_TileDark"),
		"Band": (band, "M_TileBand"),
		"PortalTrim": (trim, "M_Trim"),
		"Portal": (G(portal, mouth), "M_Steel"),
		"Tunnel": (tunnel, "M_Screen"),
		"Lintel": (lintel_face, "M_Concrete"),
		"Buffer": (buffer, "M_Red"),
		"BufferFrame": (G(sig), "M_Steel"),
		"Lamp_Glow": (G(red, lamps, sig_r), "G_Red"),
		"MouthSign": (msign, "M_Steel"),
		"Panel": (panel, "M_Concrete"),
		"Parapet": (parapet, "M_TileWhite"),
		"PanelTrim": (panel_face, "M_Trim"),
		"Roundel": (roundels, "M_White"),
		"RoundelBar": (bars, "M_Steel"),
		"Cap": (cap, "M_Steel"),
	}
	col = piece("EndWall", p, mats, kit)
	rtext(col, mats, "MERIDIAN", 3.6, 0, 18.0, -0.1, "-z")
	rtext(col, mats, "PLATFORM 1", 0.8, 29.5, 11.8, -0.35, "-z")


# ---------------------------------------------------------------- props

def p_kiosk(mats, kit):
	# 6 x 6 x 10 (collision box), serving windows on +X and -X (shallow, solid behind), a lit sign band, canopy.
	body = G(rb(-2.8, 2.8, 1.0, 3.5, -2.8, 2.8, ch=0.08), rb(-2.8, 2.8, 6.5, 8.6, -2.8, 2.8, ch=0.08))
	corners = G(*[rb(sx * 2.8 - 0.45 * sx, sx * 2.8 + 0.1 * sx, 3.5, 6.5, sz * 2.8 - 0.45 * sz, sz * 2.8 + 0.1 * sz) for sx in (-1, 1) for sz in (-1, 1)])
	inner = G(rb(-2.4, 2.4, 3.5, 6.5, -2.35, 2.35))
	counter = G(rb(-3.0, 3.0, 3.4, 3.6, -2.5, 2.5, ch=0.05))
	shelves = bmesh.new()
	prods = {1: bmesh.new(), 2: bmesh.new(), 3: bmesh.new()}
	for sx in (-1, 1):
		for i, y in enumerate((4.2, 5.2)):
			merge(shelves, rb(sx * 2.0, sx * 2.4, y - 0.08, y, -2.2, 2.2))
			for j in range(7):
				z = -1.9 + j * 0.62
				merge(prods[1 + (i + j) % 3], rb(sx * 2.05, sx * 2.35, y, y + 0.5 - 0.1 * ((i + j) % 2), z - 0.22, z + 0.22))
	glow_back = G(rb(-0.15, 0.15, 3.6, 6.4, -2.2, 2.2))
	sign = G(rb(2.8, 2.86, 6.8, 8.2, -2.4, 2.4), rb(-2.86, -2.8, 6.8, 8.2, -2.4, 2.4))
	canopy = G(rb(-3.3, 3.3, 8.6, 9.2, -3.3, 3.3, ch=0.1), rb(-2.9, 2.9, 9.2, 10.0, -2.9, 2.9, ch=0.08))
	plinth = rb(-3.0, 3.0, 0.0, 1.0, -3.0, 3.0, ch=0.06)
	p = {
		"Plinth": (plinth, "M_TileDark"),
		"Body": (body, "M_Stainless"),
		"Corners": (corners, "M_Steel"),
		"Inner": (inner, "M_Wood"),
		"Counter": (counter, "M_Brushed"),
		"Shelves": (shelves, "M_Steel"),
		"Product1": (prods[1], "M_Product1"),
		"Product2": (prods[2], "M_Product2"),
		"Product3": (prods[3], "M_Product3"),
		"Back_Glow": (glow_back, "G_Warm"),
		"Sign_Glow": (sign, "G_Warm"),
		"Canopy": (canopy, "M_Steel"),
		"Trim": (rb(-3.32, 3.32, 8.75, 8.95, -3.32, 3.32), "M_Trim"),
	}
	col = piece("Kiosk", p, mats, kit)
	rtext(col, mats, "COFFEE  NEWS", 0.7, 2.9, 7.5, 0, "+x", mat="M_Steel")
	rtext(col, mats, "COFFEE  NEWS", 0.7, -2.9, 7.5, 0, "-x", mat="M_Steel")


def p_vending(mats, kit):
	# A bank of three machines, 2 deep x 6 long x 8 tall, back at x = 0, faces +X.
	body = bmesh.new()
	glass = bmesh.new()
	glow = bmesh.new()
	keys = bmesh.new()
	prods = {1: bmesh.new(), 2: bmesh.new(), 3: bmesh.new()}
	for k in range(3):
		zc = -2.0 + k * 2.0
		merge(body, rb(0.0, 1.95, 0.0, 7.8, zc - 0.97, zc + 0.97, ch=0.08))
		merge(glow, rb(1.95, 1.97, 1.6, 7.2, zc - 0.85, zc + 0.15))
		merge(glass, rb(1.98, 2.0, 1.6, 7.2, zc - 0.85, zc + 0.15))
		merge(keys, rb(1.95, 2.0, 3.6, 6.4, zc + 0.3, zc + 0.85))
		for r in range(5):
			y = 2.0 + r * 1.0
			for c in range(3):
				z = zc - 0.68 + c * 0.32
				merge(prods[1 + (r + c + k) % 3], rb(1.99, 2.02, y, y + 0.55, z - 0.11, z + 0.11))
	p = {
		"Body": (body, "M_Red"),
		"Front_Glow": (glow, "G_Cool"),
		"Keys": (keys, "M_Steel"),
		"Product1": (prods[1], "M_Product1"),
		"Product2": (prods[2], "M_Product2"),
		"Product3": (prods[3], "M_Product3"),
		"Plinth": (rb(0.0, 2.0, 0.0, 0.3, -3.0, 3.0), "M_Steel"),
	}
	piece("Vending", p, mats, kit)


def p_bench(mats, kit):
	# 2 deep x 6 long x 3 tall, back against the wall (x = 0), faces +X.
	slats = bmesh.new()
	for i in range(4):
		x = 0.55 + i * 0.36
		merge(slats, rb(x, x + 0.28, 1.45, 1.6, -2.9, 2.9, ch=0.04))
	for i in range(3):
		y = 1.9 + i * 0.36
		merge(slats, rb(0.25, 0.4, y, y + 0.28, -2.9, 2.9, ch=0.04))
	frame = G(*[G(rb(0.2, 1.9, 1.3, 1.45, z - 0.1, z + 0.1), rb(1.5, 1.7, 0.0, 1.3, z - 0.1, z + 0.1), rb(0.2, 0.4, 0.0, 3.0, z - 0.1, z + 0.1)) for z in (-2.6, 0.0, 2.6)])
	piece("Bench", {"Slats": (slats, "M_Wood"), "Frame": (frame, "M_Steel")}, mats, kit)


def p_fare_gates(mats, kit):
	# 20 long (x -10..10) x 1.5 deep, 3.5 tall: 7 cabinets with closed stainless paddles between (solid, it's cover).
	cab = bmesh.new()
	pad = bmesh.new()
	top = bmesh.new()
	glow = bmesh.new()
	n = 7
	for i in range(n):
		x = -10.0 + 0.4 + i * (19.2 / (n - 1))
		merge(cab, rb(x - 0.4, x + 0.4, 0.0, 3.3, -0.75, 0.75, ch=0.08))
		merge(top, rb(x - 0.42, x + 0.42, 3.3, 3.5, -0.78, 0.78, ch=0.05))
		merge(glow, rb(x - 0.2, x + 0.2, 3.5, 3.54, 0.2, 0.55))
		merge(glow, rb(x - 0.2, x + 0.2, 3.5, 3.54, -0.55, -0.2))
		if i < n - 1:
			merge(pad, rb(x + 0.4, x + 0.4 + 19.2 / (n - 1) - 0.8, 0.6, 3.0, -0.1, 0.1, ch=0.05))
	p = {"Cabinets": (cab, "M_Brushed"), "Paddles": (pad, "M_Stainless"), "Tops": (top, "M_Steel"), "Lamp_Glow": (glow, "G_Green")}
	piece("FareGateRow", p, mats, kit)


def p_ticket_office(mats, kit):
	# 10 deep (x -10..0) x 18 long (z -9..9) x 10 tall; the front faces +X with dark (solid) windows, a counter,
	# a warm-lit sign band.
	shell = G(rb(-10.0, 0.0, 0.0, 1.2, -9.0, 9.0, ch=0.06), rb(-10.0, 0.0, 7.2, 10.0, -9.0, 9.0, ch=0.1))
	mull = G(*[rb(-0.4, 0.0, 1.2, 7.2, z - 0.2, z + 0.2) for z in (-9.0 + 0.2, -4.5, 0.0, 4.5, 9.0 - 0.2)])
	win = G(rb(-0.3, -0.25, 1.2, 7.2, -8.8, 8.8))
	counter = G(rb(0.0, 0.8, 2.6, 2.8, -8.8, 8.8, ch=0.05))
	sign = G(rb(0.0, 0.06, 7.8, 9.4, -6.0, 6.0))
	p = {
		"Shell": (shell, "M_TileWhite"),
		"Mullions": (G(mull, rb(-0.5, 0.0, 7.0, 7.4, -9.0, 9.0)), "M_Steel"),
		"Window": (win, "M_DarkGlass"),
		"Counter": (counter, "M_Brushed"),
		"Sign_Glow": (sign, "G_Warm"),
		"Trim": (rb(0.0, 0.1, 9.6, 10.0, -9.0, 9.0), "M_Trim"),
	}
	col = piece("TicketOffice", p, mats, kit)
	rtext(col, mats, "TICKETS", 1.0, 0.1, 8.6, 0, "+x", mat="M_Steel")


def p_portal(mats, kit):
	# Frame for a 10-wide x 10-tall opening through the 2-thick concourse wall; origin at the opening's floor centre,
	# the wall's mid-plane. Lit "PLATFORMS" sign box on both faces (text in Studio).
	frame = G(rb(-5.0, -4.8, 0.0, 10.0, -1.05, 1.05), rb(4.8, 5.0, 0.0, 10.0, -1.05, 1.05), rb(-5.0, 5.0, 9.8, 10.0, -1.05, 1.05))
	face = G(*[G(rb(-5.6, -5.0, 0.0, 10.6, s * 1.0, s * 1.15), rb(5.0, 5.6, 0.0, 10.6, s * 1.0, s * 1.15), rb(-5.6, 5.6, 10.0, 10.6, s * 1.0, s * 1.15)) for s in (-1, 1)])
	sign = G(rb(-3.5, 3.5, 11.0, 12.6, -1.4, -1.0, ch=0.05), rb(-3.5, 3.5, 11.0, 12.6, 1.0, 1.4, ch=0.05))
	glow = G(rb(-3.3, 3.3, 11.15, 12.45, -1.43, -1.4), rb(-3.3, 3.3, 11.15, 12.45, 1.4, 1.43))
	p = {"Frame": (frame, "M_Steel"), "Face": (face, "M_Trim"), "Sign": (sign, "M_Steel"), "Sign_Glow": (glow, "G_Cool")}
	col = piece("Portal10", p, mats, kit)
	rtext(col, mats, "PLATFORMS", 0.8, 0, 11.8, -1.45, "-z", mat="M_Steel")
	rtext(col, mats, "EXIT", 0.8, 0, 11.8, 1.45, "+z", mat="M_Steel")


def p_door_frame(mats, kit):
	# Frame for an 8-wide x 10-tall door through a 1-thick wall (spawn doors); origin at the floor centre, mid-plane.
	frame = G(rb(-4.0, -3.85, 0.0, 10.0, -0.55, 0.55), rb(3.85, 4.0, 0.0, 10.0, -0.55, 0.55), rb(-4.0, 4.0, 9.85, 10.0, -0.55, 0.55))
	face = G(*[G(rb(-4.5, -4.0, 0.0, 10.5, s * 0.5, s * 0.62), rb(4.0, 4.5, 0.0, 10.5, s * 0.5, s * 0.62), rb(-4.5, 4.5, 10.0, 10.5, s * 0.5, s * 0.62)) for s in (-1, 1)])
	piece("DoorFrame8", {"Frame": (frame, "M_Steel"), "Trim": (face, "M_Trim")}, mats, kit)


def p_corridor(mats, kit):
	# PipeRun8: three pipes and a cable tray on brackets, 9..11 up, on the wall (x = 0) facing +X, 8 long.
	pipes = G(zcyl(0.75, 10.3, 0.38, -4, 4, segs=10), zcyl(1.65, 10.4, 0.28, -4, 4, segs=10), zcyl(0.65, 9.35, 0.24, -4, 4, segs=8))
	tray = G(rb(0.2, 2.2, 8.55, 8.65, -4, 4), rb(2.1, 2.2, 8.55, 8.9, -4, 4))
	brackets = G(*[G(rb(0.0, 2.3, 8.45, 8.55, z - 0.1, z + 0.1), rb(0.0, 0.2, 8.45, 10.9, z - 0.1, z + 0.1)) for z in (-2.5, 1.5)])
	piece("PipeRun8", {"Pipes": (pipes, "M_Brushed"), "Tray": (tray, "M_Steel"), "Brackets": (brackets, "M_Steel")}, mats, kit)
	# CorridorLight: caged bulkhead on the wall at 7.5 (origin on the floor at the wall face).
	body = G(rb(0.0, 0.5, 7.1, 7.9, -0.6, 0.6, ch=0.08))
	cage = G(*[rb(0.5, 0.6, 7.15, 7.85, z - 0.03, z + 0.03) for z in (-0.4, 0.0, 0.4)], rb(0.5, 0.6, 7.45, 7.55, -0.5, 0.5))
	glow = G(rb(0.45, 0.5, 7.25, 7.75, -0.45, 0.45))
	piece("CorridorLight", {"Body": (body, "M_Steel"), "Cage": (cage, "M_Hazard"), "Lamp_Glow": (glow, "G_Warm")}, mats, kit)
	# PumpDoor: steel double door with hazard edge and a sign plate, on a block face (x = 0), facing +X.
	door = G(rb(0.0, 0.15, 0.0, 7.0, -2.0, -0.03, ch=0.04), rb(0.0, 0.15, 0.0, 7.0, 0.03, 2.0, ch=0.04))
	frame = G(rb(0.0, 0.25, 0.0, 7.3, -2.3, -2.0), rb(0.0, 0.25, 0.0, 7.3, 2.0, 2.3), rb(0.0, 0.25, 7.0, 7.3, -2.3, 2.3))
	stripe = G(rb(0.15, 0.18, 0.2, 0.7, -1.9, 1.9))
	plate = G(rb(0.15, 0.2, 5.2, 6.0, -1.5, -0.4))
	piece("PumpDoor", {"Door": (door, "M_ConcreteDark"), "Frame": (frame, "M_Steel"), "Stripe": (stripe, "M_Hazard"), "Plate": (plate, "M_White")}, mats, kit)


def p_name_sign(mats, kit):
	# 16 x 2.8 enamel panel on the wall band (x = 0 face, +X), the station name in Studio (SurfaceGui).
	panel = rb(0.32, 0.5, 9.7, 12.3, -8.0, 8.0, ch=0.05)
	face = rb(0.5, 0.52, 9.85, 12.15, -7.85, 7.85)
	col = piece("NameSign", {"Frame": (panel, "M_Steel"), "Face": (face, "M_Trim")}, mats, kit)
	rtext(col, mats, "MERIDIAN", 1.9, 0.55, 11.0, 0, "+x")


# ---------------------------------------------------------------- contact sheet and previews

def sheet(mats, tris):
	sc = bpy.context.scene
	stage = K.collection("Sheet")
	cell = 36.0
	ncol = 6
	order = sorted(PIECES, key=lambda t: t[0])
	nrow = (len(order) + ncol - 1) // ncol
	fl = K.add_obj("SheetFloor", K.cbox(-cell * (nrow - 0.4), cell * 0.6, -cell * 0.6, cell * (ncol - 0.4), -0.2, 0, ch=0), [mats["ConcreteHoned"]], stage)
	fl["preview_only"] = True
	for idx, (name, col) in enumerate(order):
		r, c = divmod(idx, ncol)
		lo = Vector((1e9, 1e9, 1e9))
		hi = -lo
		for ob in col.all_objects:
			if ob.type != "MESH":
				continue
			for v in ob.data.vertices:
				for i in range(3):
					lo[i] = min(lo[i], v.co[i])
					hi[i] = max(hi[i], v.co[i])
		size = hi - lo
		s = min(2.5, 26.0 / max(size.x, size.y, size.z, 0.01))
		ctr = (lo + hi) / 2
		px, py = -r * cell, c * cell
		m = Matrix.Translation((px, py, 0)) @ Matrix.Scale(s, 4) @ Matrix.Translation((-ctr.x, -ctr.y, -lo.z))
		e = bpy.data.objects.new("Sheet_" + name, None)
		e.instance_type = "COLLECTION"
		e.instance_collection = col
		e.matrix_world = m
		stage.objects.link(e)
		label = "%s  %d tris  %.0fx%.0fx%.0f%s" % (name, tris[name], size.x, size.z, size.y, "" if abs(s - 1) < 1e-3 else "  (x%.2f)" % s)
		K.text(label, 1.4, (px + 15.5, py, 0.05), stage, mats["SignText"], rot=(0, 0, 90), font=K.FONT_LABEL)
	sun = bpy.data.lights.new("SheetSun", "SUN")
	sun.energy = 3.2
	sun.angle = math.radians(3)
	so = bpy.data.objects.new("SheetSun", sun)
	stage.objects.link(so)
	so.rotation_euler = (math.radians(42), math.radians(-25), math.radians(200))
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	if bg:
		bg.inputs[0].default_value = (*K.lin(0x5A6272), 1)
		bg.inputs[1].default_value = 1.3
	cx, cy = -(nrow - 1) * cell / 2, (ncol - 1) * cell / 2
	cam = K.camera((cx + 260, cy + 60, 250), (cx, cy, 4), lens=50, name="SheetCam", col=stage)
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = cell * ncol * 1.05
	K.render_settings(samples=samples(24))
	try:
		sc.eevee.use_raytracing = False
	except AttributeError:
		pass
	K.bloom(strength=0.35)
	return stage


def samples(default):
	return int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else default


def kit_col(name):
	return bpy.data.collections["Map_" + name]


def put(name, x, y, z, yaw_deg, col):
	m = Matrix.Translation((x, -z, y)) @ Matrix.Rotation(math.radians(yaw_deg), 4, "Z")
	return K.place_instance(kit_col(name), m, "P_" + name, col)


def flat(name, x0, x1, y0, y1, z0, z1, mat, col):
	ob = K.add_obj(name, rb(x0, x1, y0, y1, z0, z1), [mat], col)
	ob["preview_only"] = True
	return ob


def dress(mats, col):
	# The hall and team B's terrace, dressed the way Art.luau does it (a preview, not the source of truth): every
	# placement in team B's half is also made turned 180 degrees for team A's half.
	F = lambda n, *a: flat(n, *a, col=col)  # noqa: E731
	F("PlatE", 14, 34, -5, 0, -48, 48, mats["M_Granite"])
	F("PlatW", -34, -14, -5, 0, -48, 48, mats["M_Granite"])
	F("Trench", -14, 14, -5, -4, -51, 51, mats["M_ConcreteDark"])
	F("Mid", -3.5, 3.5, -4.0, -3.9, -51, 51, mats["M_Concrete"])
	F("TerraceB", -34, 24, 13, 14, 48, 72, mats["M_Granite"])
	F("TerraceA", -24, 34, 13, 14, -72, -48, mats["M_Granite"])
	F("Ceil", -48, 48, 31, 31.5, -72, 72, mats["M_Concrete"])
	F("WellWallB", 24, 25, -5, 17, 48, 72, mats["M_TileWhite"])
	F("WellWallA", -25, -24, -5, 17, -72, -48, mats["M_TileWhite"])
	F("ConcourseWallB", -48, 24, 14, CEIL, 66, 68, mats["M_TileWhite"])
	F("ConcourseWallA", -24, 48, 14, CEIL, -68, -66, mats["M_TileWhite"])

	def both(name, x, y, z, yaw_):
		put(name, x, y, z, yaw_, col)
		put(name, -x, y, -z, yaw_ + 180, col)

	for z in range(-44, 45, 8):
		for x0, x1, w in ((-34, -24, 10), (-24, -14, 10), (-14, 0, 14), (0, 14, 14), (14, 24, 10), (24, 34, 10)):
			put("Coffer%d" % w, (x0 + x1) / 2, 0, z, 0, col)
	for zc in range(-40, 41, 8):
		both("WallDoor8" if zc in (0, -40) else "WallBay8", HALL_X, 0, zc, 180)
	both("WallEnd4", HALL_X, 0, 46, 180)
	both("WallEnd4", HALL_X, 0, -46, 180)
	both("NameSign", -HALL_X, 0, 16, 0)
	both("NameSign", HALL_X, 0, 24, 180)
	for x, z in ((24, 24), (24, 40), (-24, 8), (-24, 24), (-24, 40)):
		both("Column", x, 0, z, 0)
	both("Kiosk", 24, 0, 8, 0)
	both("Vending", HALL_X, 0, 18, 180)
	both("Bench", -HALL_X, 0, 16, 0)
	for zc in range(-44, 45, 8):
		both("PlatformEdge8", 14, 0, zc, 180)
	for zc in range(-48, 49, 8):
		both("TrackBay8", 8.5, TRENCH, zc, 0)
	both("TrackBox", -14, TRENCH, 31, 0)
	both("TrainCarHead", 8.5, 0, 33.5, 0)
	both("TrainCarTail", 8.5, 0, 6.5, 0)
	both("TrainGangway", 8.5, 0, 20, 0)
	put("Gantry", 0, 0, 0, 0, col)
	both("EndWall", 0, 0, 48, 0)
	both("EscalatorBank", 29.5, 0, 48, 0)
	both("HallStairs", -18, 0, 26, 0)
	both("Portal10", -9, TERR, 67, 0)
	both("Portal10", 9, TERR, 67, 0)
	for x in (18, 30, -18, -30):
		for z in (16, 32):
			both("PendantLight", x, 0, z, 0)
	both("FareGateRow", -20, TERR, 82.75, 0)
	both("FareGateRow", 20, TERR, 82.75, 0)


def hall_lights(col):
	# Stand-ins for the Roblox look: cool ambient, the coffer wash, the board and kiosk accents (Lighting.luau).
	sc = bpy.context.scene
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	bg.inputs[0].default_value = (*K.lin(0x8A93A6), 1)
	bg.inputs[1].default_value = 0.55
	K.light("AREA", "CofferWash", (0, -20, 26), 32000, 0xE6EEF8, (0, -20, 0), size=60, size_y=80, shadow=True, col=col)
	K.light("AREA", "Fill", (0, -60, 12), 6000, 0xC8D4E6, (0, 0, 6), size=40, shadow=False, col=col)
	K.light("SPOT", "Board", (0, 4, 10), 2500, 0xFFB547, (0, 6, 0), spot=110, shadow=False, col=col)
	K.light("POINT", "KioskA", (24, -8, 5), 800, 0xFFD9A8, shadow=False, col=col)
	K.light("POINT", "Cab", (8.5, -47, 2), 900, 0xFFF4E0, shadow=False, col=col)
	K.light("AREA", "Escalator", (29.5, -60, 25), 4000, 0xE6EEF8, (29.5, -60, 0), size=8, size_y=20, shadow=False, col=col)


def preview(mats, kind):
	sc = bpy.context.scene
	col = K.collection("Preview_" + kind)
	dress(mats, col)
	hall_lights(col)
	K.avatar((20, 2, 0), facing=90, col=col)
	K.avatar((-22, -30, 0), facing=120, col=col)
	K.avatar((-7, -30, TRENCH), facing=-90, col=col)
	if kind == "hall":
		# West platform in team A's half, looking at team B's end (Blender coords: (x, -z, y)).
		K.camera((-18.5, 30, 6.0), (4, -46, 9), lens=22, name="HallCam", col=col)
		out = "preview-hall.jpg"
	elif kind == "trench":
		# In the trench gap between the two trains, looking up at the clock and toward team B's end.
		K.camera((0.5, 16, -2.6), (-6, -40, 12), lens=20, name="TrenchCam", col=col)
		out = "preview-trench.jpg"
	else:
		# Team B's west perch on the terrace, looking down the hall.
		K.camera((-28, -57, 19.5), (6, 20, 4), lens=22, name="TerraceCam", col=col)
		out = "preview-terrace.jpg"
	K.render_settings(samples=samples(48))
	K.bloom(strength=0.45, threshold=1.1)
	sc.view_settings.exposure = 0.0
	return col, out


# ---------------------------------------------------------------- main

def main():
	mats = make_materials()
	kit = K.collection("Kit")
	p_wall_bay(mats, kit)
	p_wall_door(mats, kit)
	p_coffers(mats, kit)
	p_pendant(mats, kit)
	p_column(mats, kit)
	p_platform_edge(mats, kit)
	p_track(mats, kit)
	p_track_box(mats, kit)
	p_trains(mats, kit)
	p_escalators(mats, kit)
	p_hall_stairs(mats, kit)
	p_corridor_stair(mats, kit)
	p_gantry(mats, kit)
	p_end_wall(mats, kit)
	p_kiosk(mats, kit)
	p_vending(mats, kit)
	p_bench(mats, kit)
	p_fare_gates(mats, kit)
	p_ticket_office(mats, kit)
	p_portal(mats, kit)
	p_door_frame(mats, kit)
	p_corridor(mats, kit)
	p_name_sign(mats, kit)
	tris, worst = {}, {}
	for name, col in PIECES:
		tris[name] = K.tri_count(col)
		for ob in col.all_objects:
			if ob.type == "MESH":
				ob.data.calc_loop_triangles()
				worst[ob.name] = len(ob.data.loop_triangles)
	print("METRO_TRIS " + json.dumps(tris))
	print("METRO_TOTAL %d" % sum(tris.values()))
	print("METRO_MAX_OBJECT " + json.dumps(max(worst.items(), key=lambda kv: kv[1])))
	only = ARGS[ARGS.index("--only") + 1] if "--only" in ARGS else None
	os.makedirs(ART_DIR, exist_ok=True)
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
	path = os.path.join(ART_DIR, "Kit_Metro.blend")
	bpy.ops.wm.save_as_mainfile(filepath=path)
	print("METRO saved", path)
	if "--no-render" in ARGS:
		return
	os.makedirs(RENDER_DIR, exist_ok=True)
	stages = []
	if only in (None, "sheet"):
		st = sheet(mats, tris)
		K.render(os.path.join(RENDER_DIR, "contact-station.jpg"), res=(2400, 1600))
		bpy.context.view_layer.layer_collection.children[st.name].exclude = True
	for kind in ("hall", "terrace", "trench"):
		if only not in (None, kind):
			continue
		col, out = preview(mats, kind)
		K.render(os.path.join(RENDER_DIR, out), res=(1920, 1080))
		bpy.context.view_layer.layer_collection.children[col.name].exclude = True
		stages.append(col)


main()
