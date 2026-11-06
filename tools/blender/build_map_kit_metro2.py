# build_map_kit_metro2.py: the Metro2 map kit, group "Station2" (vault/01 Design/Maps/Metro2.md, the Map Quality
# Standard in vault/01 Design/Maps/Map Quality Standard.md). Meridian Interchange rebuilt at the standard's finish:
# every visible thing a bevelled mesh with secondary and tertiary detail, tintable MaterialVariants by role, signs as
# rendered-font textures on modelled plates (the plates' *_Face parts get the art in Studio, Art.luau), and story
# props. Same layout, same piece origins and sizes as the Metro kit (tools/blender/build_map_kit_metro.py), so
# placements carry over; the concepts (art-source/maps/Metro2/concepts/) set the look: cream square tile over a dark
# dado, a deep coffered vault with chamfered haunches and a daylight slot over the tracks, a black steel truss with
# the amber board and the clock, stainless trains with an end-colour stripe.
#
# Space: every piece is built in ROBLOX MAP SPACE terms through rb / rx / rz / ry (+X across, +Y up, +Z along the map,
# team B's end); Blender = (x, -z, y). Origins as in the Metro kit:
#   wall pieces (WallBay8, WallBayPoster8, WallBayMap8, WallEnd4, WallDoor8, PipeRun8, Vending, Bench, NameSign,
#     HelpPoint, Extinguisher): on the floor at the wall face, facing +X, length along Z.
#   EndWall: the hall end face (z = 48 for team B) at platform level, facing -Z.
#   Coffer10 / Coffer14 / Skylight14, PendantLight, PlatformSign: centre on the floor below, built at real heights.
#   Train: centre on the floor, platform side +X.  EscalatorBank, HallStairs, CorridorStair: bottom front centre.
#   Gantry: hall centre at platform level.  Props: floor centre.
# Parts ending _Band / _Stripe / _Trim take the end colour in Studio (B cobalt, A sage). *_Glow are Neon. *_Face parts
# are sign plates (Art.luau puts the sign art on them). Roles: materials M_<Role> carry rbx_material / rbx_variant /
# rbx_color (tools/maps/metro2_style.py has the same table for Studio).
#
# NO Z-FIGHTING (Map Quality Standard section 3; checked offline by tools/studio/maps/zfight_check.py, which also tests
# every part as its bounding box, the way Studio's Audit.luau sees Box-fidelity MeshParts): anything on a surface
# stands >= 0.05 proud (P), bands meet edge to edge, no two parts' bounds share a plane where they overlap.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_map_kit_metro2.py -- [--no-render] [--samples N]
# Writes art-source/maps/Metro2/Kit_Metro2.blend and the contact sheet vault/02 Art/References/maps/metro2/
# kit-contact.jpg (a 5-stud R15 proxy beside each piece), prints METRO2_TRIS and COPLANAR.
# Export: blender --background --factory-startup art-source/maps/Metro2/Kit_Metro2.blend \
#           --python tools/blender/export_lobby_kit.py -- --maps Metro2 Station2

import json, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
from gunkit import prism, box, merge, group, ring_pts  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ART_DIR = os.path.join(K.ROOT, "art-source", "maps", "Metro2")
RENDER_DIR = os.path.join(K.ROOT, "vault", "02 Art", "References", "maps", "metro2")

CEIL = 28.0
TERR = 14.0
TRENCH = -4.0
HALL_X = 34.0
P = 0.06  # proud

# ---------------------------------------------------------------- palette (roles; vault Metro2.md -> Palette)
ROLE = {
	"Tile": (0xE3D8C3, "CeramicTiles", "Metro2_Tile"),
	"TileDark": (0x5D6068, "CeramicTiles", "Metro2_Tile"),
	"Band": (0x3A5A9C, "CeramicTiles", "Metro2_Tile"),  # end colour, re-tinted per half
	"Concrete": (0xBDB6A9, "Concrete", "Metro2_Concrete"),
	"ConcreteDark": (0x8E887E, "Concrete", "Metro2_Concrete"),
	"Granite": (0x8C8780, "Granite", "Metro2_Granite"),
	"Floor": (0xCFC7B8, "Marble", "Metro2_Floor"),
	"Ballast": (0x7A746C, "Slate", "Metro2_Ballast"),
	"Sleeper": (0x958B7E, "Concrete", "Metro2_Concrete"),
	"Tactile": (0xB89A5E, "SmoothPlastic", ""),
	"Charcoal": (0x444952, "SmoothPlastic", ""),
	"Stainless": (0xB9BDC3, "Plastic", "Metro2_Steel"),
	"Rail": (0xA9ACB0, "SmoothPlastic", ""),
	"TrainBody": (0xD9DCDF, "SmoothPlastic", ""),
	"TrainDark": (0x4A4F57, "SmoothPlastic", ""),
	"Rubber": (0x3A3D43, "Rubber", ""),
	"Oak": (0xA77C55, "Wood", ""),
	"Seat": (0x3F5A78, "Fabric", ""),
	"Vending": (0xA8443A, "SmoothPlastic", ""),
	"White": (0xEEEAE2, "SmoothPlastic", ""),
	"Screen": (0x1E2024, "SmoothPlastic", ""),
	"Glass": (0x9FB4C2, "Glass", ""),
	"DarkGlass": (0x4A5562, "Glass", ""),
	"Red": (0xB5473A, "SmoothPlastic", ""),
	"Stripe": (0x3A5A9C, "SmoothPlastic", ""),  # end colour on smooth parts
}
GLOW = {
	"G_Coffer": (0xF4ECDF, 2.4),
	"G_Cool": (0xDDE8F2, 2.6),
	"G_Warm": (0xFFC27A, 2.4),
	"G_Amber": (0xFFB547, 2.4),
	"G_Head": (0xFFF4E0, 3.5),
	"G_Red": (0xE03A3A, 2.5),
	"G_Green": (0x5BC85A, 2.2),
}


def make_materials():
	mats = K.begin()
	for role, (c, rbx, var) in ROLE.items():
		if rbx == "Glass":
			m = K._glass("M_" + role, c)
			m["rbx_transparency"] = 0.55 if role == "Glass" else 0.35
		else:
			rough = 0.35 if rbx in ("SmoothPlastic", "Plastic") else 0.7
			m = K._flat("M_" + role, c, rough, rbx=rbx)
		m["rbx_variant"] = var
		m["rbx_color"] = "%06X" % c
		mats[m.name] = m
	for name, (c, s) in GLOW.items():
		mats[name] = K._emissive(name, c, s)
		mats[name]["rbx_variant"] = ""
	return mats


# ---------------------------------------------------------------- geometry in map space

def fix(bm):
	K.mat_all(bm, 0)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def rb(x0, x1, y0, y1, z0, z1, ch=0.0):
	ax0, ax1 = sorted((x0, x1))
	ay0, ay1 = sorted((y0, y1))
	az0, az1 = sorted((z0, z1))
	ch = min(ch, (ax1 - ax0) * 0.45, (ay1 - ay0) * 0.45, (az1 - az0) * 0.45)
	if ch > 0.004:
		return K.cbox(ax0, ax1, -az1, -az0, ay0, ay1, ch=ch)
	return K.mat_all(box(ax0, ax1, -az1, -az0, ay0, ay1), 0)


def rx(pts_zy, x0, x1):
	return fix(prism([(-z, y) for z, y in pts_zy], "X", min(x0, x1), max(x0, x1)))


def rz(pts_xy, z0, z1):
	return fix(prism(list(pts_xy), "Y", -max(z0, z1), -min(z0, z1)))


def ry(pts_xz, y0, y1):
	return fix(prism([(x, -z) for x, z in pts_xz], "Z", min(y0, y1), max(y0, y1)))


def vcyl(x, z, r, y0, y1, segs=12):
	return fix(prism(ring_pts(x, -z, r, segs, math.pi / segs), "Z", min(y0, y1), max(y0, y1)))


def zcyl(x, y, r, z0, z1, segs=12):
	return fix(prism(ring_pts(x, y, r, segs, math.pi / segs), "Y", -max(z0, z1), -min(z0, z1)))


def xcyl(y, z, r, x0, x1, segs=12):
	return fix(prism(ring_pts(-z, y, r, segs, math.pi / segs), "X", min(x0, x1), max(x0, x1)))


def G(*bms):
	return group(*bms)


def tf(bm, m):
	# Apply a Roblox-space transform built with RT / RR below.
	return K.place(bm, m)


def RT(x=0.0, y=0.0, z=0.0):
	return Matrix.Translation((x, -z, y))


def RY(deg):
	return Matrix.Rotation(math.radians(deg), 4, "Z")


def RXr(deg):
	# rotation about Roblox X (Blender X)
	return Matrix.Rotation(math.radians(deg), 4, "X")


def RZr(deg):
	# rotation about Roblox Z (Blender -Y)
	return Matrix.Rotation(math.radians(-deg), 4, "Y")


def lathe_v(profile, x=0.0, z=0.0, segs=16):
	# Revolve (r, y) points about a vertical axis at (x, z); r = 0 points close the ends.
	bm = bmesh.new()
	rings = []
	for r, y in profile:
		if r < 1e-6:
			rings.append([bm.verts.new((x, -z, y))])
		else:
			rings.append([bm.verts.new((x + r * math.cos(2 * math.pi * i / segs), -z + r * math.sin(2 * math.pi * i / segs), y)) for i in range(segs)])
	for a, b in zip(rings, rings[1:]):
		if len(a) == 1 and len(b) == 1:
			continue
		for i in range(segs):
			j = (i + 1) % segs
			if len(a) == 1:
				bm.faces.new((a[0], b[i], b[j]))
			elif len(b) == 1:
				bm.faces.new((a[i], b[0], a[j]))
			else:
				bm.faces.new((a[i], b[i], b[j], a[j]))
	for ring in (rings[0], rings[-1]):
		if len(ring) > 2:
			bm.faces.new(ring)
	return fix(bm)


def tray(w, d, rings, cx=0.0, cz=0.0, top=True):
	# A rectangular loft: rings = [(inset, y), ...] from the outside in; quads between consecutive rings and a flat
	# top over the last ring. Faces point down/outward (seen from below), for coffers and skylights.
	bm = bmesh.new()
	vs = []
	for ins, y in rings:
		hw, hd = w / 2 - ins, d / 2 - ins
		vs.append([bm.verts.new((cx + sx, -(cz + sz), y)) for sx, sz in ((-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd))])
	for a, b in zip(vs, vs[1:]):
		for i in range(4):
			j = (i + 1) % 4
			bm.faces.new((a[i], a[j], b[j], b[i]))
	if top:
		bm.faces.new(vs[-1])
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
	K.mat_all(bm, 0)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	# open shell: orient every face to look down / toward the tray's axis (visible from the hall below)
	for f in bm.faces:
		c = f.calc_center_median()
		if f.normal.z > 0.5:
			f.normal_flip()
		elif abs(f.normal.z) <= 0.5:
			v = Vector((cx - c.x, -cz - c.y, 0))
			if f.normal.dot(v) < 0 and v.length > 1e-6:
				f.normal_flip()
	return bm


PIECES = []


def torus(x, z, R, r, y, segs=20, minor=8):
	# A ring lying flat (axis vertical) at height y: hose coils.
	bm = bmesh.new()
	rings = []
	for i in range(segs):
		a = 2 * math.pi * i / segs
		ring = []
		for j in range(minor):
			b = 2 * math.pi * j / minor
			rr = R + r * math.cos(b)
			ring.append(bm.verts.new((x + rr * math.cos(a), -z + rr * math.sin(a), y + r * math.sin(b))))
		rings.append(ring)
	for i in range(segs):
		a, c = rings[i], rings[(i + 1) % segs]
		for j in range(minor):
			k = (j + 1) % minor
			bm.faces.new((a[j], c[j], c[k], a[k]))
	return fix(bm)


def piece(name, parts, mats, kit):
	col = K.collection("Map_" + name, kit)
	for part, (bm, mname) in parts.items():
		oname = "%s_%s" % (name, part)
		if part.endswith("_Glow"):
			ob = K.add_glow(oname, bm, mats[mname], col)
		else:
			ob = K.add_obj(oname, bm, [mats[mname]], col)
		if mname in ("M_Glass", "M_DarkGlass"):
			ob.visible_shadow = False
	PIECES.append((name, col))
	return col


def steps(x0, x1, z0, run, rise, n, nose=0.1):
	tr, no = bmesh.new(), bmesh.new()
	dz, dy = run / n, rise / n
	for i in range(n):
		za, zb = z0 + i * dz, z0 + (i + 1) * dz
		ya = (i + 1) * dy
		merge(tr, rb(x0, x1, 0.0, ya - nose, za, zb))
		merge(no, rb(x0 + 0.03, x1 - 0.03, ya - nose, ya, za + (0.03 if i == 0 else 0.0), zb - (0.03 if i == n - 1 else 0.0), ch=0.03))
	return tr, no


def slope_panel(x0, x1, z0, z1, y0a, y1a, ya_top, yb_top):
	return rx([(z0, y0a), (z1, y1a), (z1, yb_top), (z0, ya_top)], x0, x1)


def bar_between(a, b, t, d):
	# A square bar of width t (in the plane) and depth d (along Roblox z, centred on a.z) between points a, b in the
	# Roblox x-y plane: for truss diagonals.
	ax, ay, az = a
	bx, by, _ = b
	L = math.hypot(bx - ax, by - ay)
	ang = math.degrees(math.atan2(by - ay, bx - ax))
	bm = rb(0, L, -t / 2, t / 2, az - d / 2, az + d / 2, ch=0.04)
	return tf(bm, RT(ax, ay, 0) @ RZr(ang))


# ---------------------------------------------------------------- walls

def wall_layers(z0, z1, door=False, rib=True):
	# Hall wall cladding between z0 and z1 (wall face x = 0, facing +X). Height bands meet edge to edge:
	# skirt 0..0.6, dado 0.6..3.4, cap 3.4..3.6, field ..9.3, bead, band 9.5..12.3, bead, field ..18.6, cornice with
	# the uplight cove, upper concrete ..22.5, and the chamfered haunch to the vault at 27.95.
	p = {
		"FieldMid": (rb(0, 0.25, 12.5, 18.6, z0, z1), "M_Tile"),
		"BeadHigh": (rb(0, 0.38, 12.3, 12.5, z0, z1, ch=0.04), "M_Charcoal"),
		"Band": (rb(0, 0.3, 10.5 if door else 9.5, 12.3, z0, z1), "M_Band"),
		"Cornice": (rz([(0, 18.6), (0.9, 18.6), (1.3, 18.95), (1.3, 19.25), (0, 19.25)], z0, z1), "M_Concrete"),
		"CoveLip": (rb(1.12, 1.3, 19.25, 19.7, z0, z1), "M_Concrete"),
		"Cove_Glow": (rb(0.5, 0.95, 19.25, 19.32, z0 + 0.05, z1 - 0.05), "G_Cool"),
		"Upper": (rb(0.0, 0.15, 19.25, 22.5, z0, z1), "M_Concrete"),
		"Haunch": (rz([(0, 22.5), (0.15, 22.5), (4.1, 27.92), (0, 27.92)], z0, z1), "M_Concrete"),
	}
	if not door:
		p["Skirt"] = (rb(0, 0.45, 0, 0.6, z0, z1, ch=0.06), "M_Granite")
		p["Dado"] = (rb(0, 0.3, 0.6, 3.4, z0, z1), "M_TileDark")
		p["DadoCap"] = (rb(0, 0.42, 3.4, 3.6, z0, z1, ch=0.05), "M_Stainless")
		p["Field"] = (rb(0, 0.25, 3.6, 9.3, z0, z1), "M_Tile")
		p["BeadLow"] = (rb(0, 0.38, 9.3, 9.5, z0, z1, ch=0.04), "M_Charcoal")
	else:
		p["BeadLow"] = (rb(0, 0.38, 10.3, 10.5, z0, z1, ch=0.04), "M_Charcoal")
	if rib:
		zc = (z0 + z1) / 2
		# The pilaster's line carries on up the haunch as a concrete rib under each coffer beam.
		p["Rib"] = (rz([(0.02, 19.7), (1.45, 19.7), (1.45, 22.2), (5.25, 27.85), (0.02, 27.85)], zc - 0.6, zc + 0.6), "M_Concrete")
	return p


def low_layers(z0, z1):
	# The concourse and spawn rooms are 14 tall (floor 14, ceiling 28): the same skirt, dado, field and end-colour
	# band as the hall walls, topped by a slim cornice just under the ceiling. Wall face x = 0, facing +X.
	return {
		"Skirt": (rb(0, 0.45, 0, 0.6, z0, z1, ch=0.06), "M_Granite"),
		"Dado": (rb(0, 0.3, 0.6, 3.4, z0, z1), "M_TileDark"),
		"DadoCap": (rb(0, 0.42, 3.4, 3.6, z0, z1, ch=0.05), "M_Stainless"),
		"Field": (rb(0, 0.25, 3.6, 9.3, z0, z1), "M_Tile"),
		"BeadLow": (rb(0, 0.38, 9.3, 9.5, z0, z1, ch=0.04), "M_Charcoal"),
		"Band": (rb(0, 0.3, 9.5, 12.3, z0, z1), "M_Band"),
		"BeadHigh": (rb(0, 0.38, 12.3, 12.5, z0, z1, ch=0.04), "M_Charcoal"),
		"FieldTop": (rb(0, 0.25, 12.5, 13.3, z0, z1), "M_Tile"),
		"Cornice": (rz([(0, 13.3), (0.7, 13.3), (0.9, 13.5), (0.9, 13.92), (0, 13.92)], z0, z1), "M_Concrete"),
	}


def pilaster(p, zc=0.0):
	# Tile pilaster on a dark base with a warm sconce: the concepts' wall rhythm. Stands proud of the field.
	p["PilasterBase"] = (rb(0.3, 1.0, 0.6, 3.75, zc - 0.85, zc + 0.85, ch=0.08), "M_TileDark")
	p["PilasterCap"] = (rb(0.42, 1.1, 3.75, 3.95, zc - 0.92, zc + 0.92, ch=0.05), "M_Stainless")
	p["Pilaster"] = (rb(0.25, 0.92, 3.95, 18.55, zc - 0.78, zc + 0.78, ch=0.1), "M_Tile")
	p["SconceBody"] = (G(rb(0.92, 1.25, 6.7, 8.3, zc - 0.32, zc + 0.32, ch=0.06), rb(0.92, 1.12, 6.45, 6.7, zc - 0.12, zc + 0.12)), "M_Charcoal")
	p["Sconce_Glow"] = (rb(1.25, 1.3, 6.9, 8.1, zc - 0.22, zc + 0.22), "G_Warm")


def lightbox(p, key, za, zb, y0, y1):
	# A framed poster lightbox on the field: stainless frame, the art plate (_Face) inside it.
	p[key + "Frame"] = (G(
		rb(0.25, 0.62, y0, y1, za, za + 0.22, ch=0.04), rb(0.25, 0.62, y0, y1, zb - 0.22, zb, ch=0.04),
		rb(0.25, 0.62, y0, y0 + 0.22, za + 0.22, zb - 0.22, ch=0.04), rb(0.25, 0.62, y1 - 0.22, y1, za + 0.22, zb - 0.22, ch=0.04),
	), "M_Stainless")
	p[key + "Back"] = (rb(0.25, 0.48, y0 + 0.22, y1 - 0.22, za + 0.22, zb - 0.22), "M_White")
	p[key + "_Face"] = (rb(0.48, 0.53, y0 + 0.24, y1 - 0.24, za + 0.24, zb - 0.24), "M_White")


def p_walls(mats, kit):
	p = wall_layers(-4, 4)
	pilaster(p)
	piece("WallBay8", p, mats, kit)
	p = wall_layers(-4, 4)
	pilaster(p)
	lightbox(p, "PosterL", -3.55, -1.15, 4.4, 8.0)
	lightbox(p, "PosterR", 1.15, 3.55, 4.4, 8.0)
	piece("WallBayPoster8", p, mats, kit)
	p = wall_layers(-4, 4)
	lightbox(p, "Map", -2.7, 2.7, 4.6, 7.3)
	piece("WallBayMap8", p, mats, kit)
	piece("WallBayPlain8", wall_layers(-4, 4), mats, kit)
	# Concourse / spawn room bays (14 tall), plain and with two poster lightboxes.
	piece("LowBay8", low_layers(-3.97, 3.97), mats, kit)
	piece("CorridorDado8", {
		"Skirt": (rb(0, 0.45, 0, 0.6, -3.95, 3.95, ch=0.06), "M_Granite"),
		"Dado": (rb(0, 0.3, 0.6, 3.4, -3.95, 3.95), "M_TileDark"),
		"DadoCap": (rb(0, 0.42, 3.4, 3.6, -3.95, 3.95, ch=0.05), "M_Stainless"),
		"Stripe": (rb(0, 0.12, 5.2, 5.8, -3.95, 3.95), "M_Stripe"),
		"Guide_Glow": (rb(0.42, 0.47, 3.45, 3.55, -3.8, 3.8), "G_Warm"),
	}, mats, kit)
	p = low_layers(-3.97, 3.97)
	lightbox(p, "PosterL", -3.55, -1.15, 4.4, 8.0)
	lightbox(p, "PosterR", 1.15, 3.55, 4.4, 8.0)
	piece("LowBayPoster8", p, mats, kit)
	piece("WallEnd4", wall_layers(-1.97, 1.97, rib=False), mats, kit)
	# Service door bay: an 8 x 10 opening through the 2-thick hall wall (the bay's whole width).
	p = wall_layers(-4, 4, door=True)
	p["Liner"] = (G(rb(-1.97, 0.0, 0, 9.85, -4.0, -3.85), rb(-1.97, 0.0, 0, 9.85, 3.85, 4.0), rb(-1.97, 0.0, 9.85, 10.0, -4.0, 4.0)), "M_Stainless")
	p["Frame"] = (G(rb(0.0, 0.32, 0, 10.3, -4.0, -3.62, ch=0.06), rb(0.0, 0.32, 0, 10.3, 3.62, 4.0, ch=0.06), rb(0.0, 0.32, 9.88, 10.3, -3.62, 3.62, ch=0.06)), "M_Charcoal")
	p["Kick"] = (rb(-1.9, 0.0, 0, 0.05, -3.85, 3.85), "M_Rubber")
	p["SignPlate"] = (rb(0.3, 0.5, 10.75, 12.05, -2.3, 2.3, ch=0.05), "M_Charcoal")
	p["Sign_Face"] = (rb(0.5, 0.56, 10.85, 11.95, -2.2, 2.2), "M_White")
	piece("WallDoor8", p, mats, kit)


def p_name_sign(mats, kit):
	# Station name on the wall band (x = 0 face): an end-colour surround, the enamel plate with MERIDIAN (art).
	p = {
		"Frame_Trim": (rb(0.3, 0.52, 9.75, 12.05, -5.6, 5.6, ch=0.06), "M_Stripe"),
		"Back": (rb(0.52, 0.6, 9.9, 11.9, -5.45, 5.45), "M_White"),
		"Name_Face": (rb(0.6, 0.65, 9.95, 11.85, -5.4, 5.4), "M_White"),
	}
	piece("NameSign", p, mats, kit)


# ---------------------------------------------------------------- ceiling

COFFER_RINGS = [(0.0, 27.4), (0.5, 27.4), (0.68, 27.58), (0.68, 28.5), (1.9, 30.6)]


def p_coffers(mats, kit):
	for w in (10, 14):
		shell = tray(float(w), 8.0, COFFER_RINGS)
		fx, fz = w / 2 - 2.2, 4.0 - 2.2
		frame = G(
			rb(-fx, fx, 30.38, 30.55, -fz, -fz + 0.25), rb(-fx, fx, 30.38, 30.55, fz - 0.25, fz),
			rb(-fx, -fx + 0.25, 30.38, 30.55, -fz + 0.25, fz - 0.25), rb(fx - 0.25, fx, 30.38, 30.55, -fz + 0.25, fz - 0.25),
		)
		glow = rb(-fx + 0.25, fx - 0.25, 30.45, 30.5, -fz + 0.25, fz - 0.25)
		piece("Coffer%d" % w, {"Shell": (shell, "M_Concrete"), "Frame": (frame, "M_Charcoal"), "Panel_Glow": (glow, "G_Coffer")}, mats, kit)
	# The daylight slot over the tracks: the same coffer, open at the top, glazed in a steel grid.
	shell = tray(14.0, 8.0, COFFER_RINGS[:-1] + [(1.9, 30.6)], top=False)
	gx, gz = 7.0 - 1.9, 4.0 - 1.9
	glass = rb(-gx, gx, 30.66, 30.7, -gz, gz)
	grid = bmesh.new()
	for x in (-gx, -gx / 3, gx / 3, gx):
		merge(grid, rb(x - 0.14, x + 0.14, 30.72, 31.1, -gz - 0.2, gz + 0.2, ch=0.04))
	for z in (-gz, gz):
		merge(grid, rb(-gx + 0.18, gx - 0.18, 30.76, 31.06, z - 0.12, z + 0.12, ch=0.04))
	upstand = G(
		rb(-gx - 0.4, gx + 0.4, 30.6, 31.4, -gz - 0.4, -gz - 0.12), rb(-gx - 0.4, gx + 0.4, 30.6, 31.4, gz + 0.12, gz + 0.4),
		rb(-gx - 0.4, -gx - 0.16, 30.6, 31.4, -gz - 0.12, gz + 0.12), rb(gx + 0.16, gx + 0.4, 30.6, 31.4, -gz - 0.12, gz + 0.12),
	)
	piece("Skylight14", {"Shell": (shell, "M_Concrete"), "Upstand": (upstand, "M_Concrete"), "Grid": (grid, "M_Charcoal"), "Glass": (glass, "M_Glass")}, mats, kit)


def p_pendant(mats, kit):
	# 8-long linear pendant on two rods (real height: body 21.2..22): a housing with end caps and a diffuser. Each rod
	# ends in a ceiling plate that meets the ceiling (nothing floats): PendantLight hangs in a hall coffer (plate just
	# under the coffer top at 30.6), PendantLightLow from the flat concourse ceiling (plate into the slab at 28).
	for name, rod_top, c0, c1 in (("PendantLight", 30.42, 30.36, 30.57), ("PendantLightLow", 28.3, 27.85, 28.25)):
		p = {
			"Rods": (G(vcyl(0, -3, 0.1, 22.0, rod_top, segs=8), vcyl(0, 3, 0.1, 22.0, rod_top, segs=8)), "M_Charcoal"),
			"Plates": (G(rb(-0.35, 0.35, c0, c1, -3.35, -2.65, ch=0.03), rb(-0.35, 0.35, c0, c1, 2.65, 3.35, ch=0.03)), "M_Charcoal"),
			"Housing": (rz([(-0.45, 21.45), (-0.3, 22.0), (0.3, 22.0), (0.45, 21.45), (0.45, 21.3), (-0.45, 21.3)], -3.9, 3.9), "M_Charcoal"),
			"Caps": (G(rb(-0.5, 0.5, 21.25, 22.05, -4.0, -3.9, ch=0.03), rb(-0.5, 0.5, 21.25, 22.05, 3.9, 4.0, ch=0.03)), "M_Stainless"),
			"Tube_Glow": (rb(-0.32, 0.32, 21.2, 21.3, -3.85, 3.85), "G_Cool"),
		}
		piece(name, p, mats, kit)


def p_platform_sign(mats, kit):
	# Hanging platform sign over a platform (13..14.6), two faces (art in Studio), rods to the vault.
	p = {
		# hung under the coffers' 0.5 bottom band where two coffers meet (x = +-24), plates touching it
		"Rods": (G(vcyl(0, -2.6, 0.12, 14.6, 27.3, segs=8), vcyl(0, 2.6, 0.12, 14.6, 27.3, segs=8)), "M_Charcoal"),
		"Plates": (G(rb(-0.3, 0.3, 27.15, 27.36, -2.9, -2.3, ch=0.03), rb(-0.3, 0.3, 27.15, 27.36, 2.3, 2.9, ch=0.03)), "M_Charcoal"),
		"Box": (rb(-0.35, 0.35, 12.9, 14.7, -3.3, 3.3, ch=0.08), "M_Charcoal"),
		"FaceA_Face": (rb(0.35, 0.4, 13.05, 14.55, -3.15, 3.15), "M_White"),
		"FaceB_Face": (rb(-0.4, -0.35, 13.05, 14.55, -3.15, 3.15), "M_White"),
	}
	piece("PlatformSign", p, mats, kit)


# ---------------------------------------------------------------- hall floor

def p_column(mats, kit):
	p = {
		"Shoe": (rb(-2.22, 2.22, 0, 0.45, -2.22, 2.22, ch=0.08), "M_Stainless"),
		"Base": (rb(-2.04, 2.04, 0.45, 3.6, -2.04, 2.04, ch=0.14), "M_TileDark"),
		"BaseCap": (rb(-2.15, 2.15, 3.6, 3.8, -2.15, 2.15, ch=0.06), "M_Stainless"),
		"Body": (rb(-1.96, 1.96, 3.8, 22.0, -1.96, 1.96, ch=0.28), "M_Tile"),
		"Band": (rb(-2.2, 2.2, 9.5, 12.3, -2.2, 2.2, ch=0.3), "M_Band"),
		"Necking": (rb(-2.1, 2.1, 22.0, 22.4, -2.1, 2.1, ch=0.08), "M_Concrete"),
		"Capital": (G(_flare(2.0, 2.8, 22.4, 26.6), rb(-2.95, 2.95, 26.6, CEIL - 0.62, -2.95, 2.95, ch=0.12)), "M_Concrete"),
		"SconceBody": (G(*[rb(-0.32, 0.32, 6.6, 8.3, sz * 1.96, sz * 2.28, ch=0.06) for sz in (-1, 1)]), "M_Charcoal"),
		"Sconce_Glow": (G(*[rb(-0.22, 0.22, 6.8, 8.1, sz * 2.28, sz * 2.33) for sz in (-1, 1)]), "G_Warm"),
	}
	piece("Column", p, mats, kit)


def _flare(r0, r1, y0, y1):
	bm = bmesh.new()
	a = [bm.verts.new((sx * r0, sz * r0, y0)) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
	b = [bm.verts.new((sx * r1, sz * r1, y1)) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
	for i in range(4):
		j = (i + 1) % 4
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bm.faces.new(a)
	bm.faces.new(b)
	return fix(bm)


def edge_parts(tactile=True):
	# Platform edge, 7.9 long (0.1 joints). Origin at the edge line on the floor; the trench is +X.
	L = 3.95
	p = {
		"Coping": (rz([(-1.15, -0.3), (0.18, -0.3), (0.3, -0.18), (0.3, -0.04), (0.2, 0.06), (-1.15, 0.06)], -L, L), "M_Granite"),
		"Line": (rb(-1.45, -1.2, 0.0, 0.065, -L, L), "M_White"),
		"Cladding": (rb(0.0, 0.07, TRENCH + 0.45, -0.3, -L, L), "M_ConcreteDark"),
		"Refuge": (rb(0.0, 0.12, TRENCH, TRENCH + 0.45, -L, L), "M_TileDark"),
		"Trough": (rb(0.07, 0.6, -2.3, -1.65, -L, L, ch=0.04), "M_Stainless"),
		"Brackets": (G(*[rb(0.07, 0.66, -2.42, -2.3, z - 0.1, z + 0.1) for z in (-2.5, 0.0, 2.5)]), "M_Charcoal"),
	}
	if tactile:
		dots = bmesh.new()
		for i in range(16):
			z = -L + 0.3 + i * (2 * L - 0.6) / 15
			for x in (-2.3, -2.0, -1.7):
				merge(dots, rb(x - 0.09, x + 0.09, 0.05, 0.1, z - 0.09, z + 0.09))
		p["Tactile"] = (rb(-2.45, -1.55, 0.0, 0.05, -L, L), "M_Tactile")
		p["TactileDots"] = (dots, "M_Tactile")
	return p


def p_platform_edge(mats, kit):
	piece("PlatformEdge8", edge_parts(), mats, kit)
	piece("PlatformEdge8Plain", edge_parts(tactile=False), mats, kit)


def p_track(mats, kit):
	# 8 long, one track (gauge 4.4), origin at the centreline on the trench floor (placed at y = -4).
	sl, clips = bmesh.new(), bmesh.new()
	for i in range(4):
		z = -4 + 1.0 + i * 2.0
		merge(sl, rz([(-3.2, 0.3), (3.2, 0.3), (3.2, 0.6), (2.9, 0.7), (-2.9, 0.7), (-3.2, 0.6)], z - 0.45, z + 0.45))
		for x in (-2.2, 2.2):
			for s in (-1, 1):
				merge(clips, rb(x + s * 0.4 - 0.1, x + s * 0.4 + 0.1, 0.64, 0.86, z - 0.18, z + 0.18, ch=0.03))
	rails = bmesh.new()
	for x in (-2.2, 2.2):
		prof = [(x - 0.3, 0.7), (x + 0.3, 0.7), (x + 0.3, 0.76), (x + 0.07, 0.82), (x + 0.07, 1.0), (x + 0.17, 1.05), (x + 0.17, 1.18),
				(x - 0.17, 1.18), (x - 0.17, 1.05), (x - 0.07, 1.0), (x - 0.07, 0.82), (x - 0.3, 0.76)]
		merge(rails, rz(prof, -4, 4))
	p = {
		"Ballast": (rz([(-4.8, 0.0), (4.8, 0.0), (4.3, 0.45), (-4.3, 0.45)], -4, 4), "M_Ballast"),
		"Sleepers": (sl, "M_Sleeper"),
		"Clips": (clips, "M_Charcoal"),
		"Rails": (rails, "M_Rail"),
		"Conductor": (rz([(3.55, 0.75), (4.35, 0.75), (4.35, 0.98), (4.1, 1.08), (3.8, 1.08), (3.55, 0.98)], -3.98, 3.98), "M_Tactile"),
		"Insulators": (G(*[vcyl(3.95, z, 0.16, 0.45, 0.75, segs=8) for z in (-2.0, 2.0)]), "M_White"),
	}
	piece("TrackBay8", p, mats, kit)


def p_track_box(mats, kit):
	# Relay cabinet in the trench (collision 3 x 3.5 x 6), back on the trench wall (x = 0), facing +X.
	louvres = bmesh.new()
	for i in range(5):
		y = 1.2 + i * 0.3
		for zc in (-1.35, 1.35):
			merge(louvres, rb(2.9, 3.0, y, y + 0.12, zc - 0.9, zc + 0.9, ch=0.02))
	p = {
		"Plinth": (rb(0.1, 3.05, 0.0, 0.36, -3.0, 3.0, ch=0.06), "M_ConcreteDark"),
		"Body": (rb(0.12, 2.9, 0.36, 3.35, -2.9, 2.9, ch=0.12), "M_Stainless"),
		"Roof": (rb(0.08, 3.0, 3.35, 3.5, -2.98, 2.98, ch=0.05), "M_Charcoal"),
		"Louvres": (louvres, "M_Charcoal"),
		"Handles": (G(rb(2.9, 3.05, 2.2, 2.9, -0.35, -0.22), rb(2.9, 3.05, 2.2, 2.9, 0.22, 0.35)), "M_Charcoal"),
		"Plate": (rb(2.9, 2.96, 2.75, 3.1, -2.4, -1.2), "M_Tactile"),
	}
	piece("TrackBox", p, mats, kit)


# ---------------------------------------------------------------- the train

TRAIN_L = 52.0
TRAIN_W = 10.0


def train():
	# One two-section unit (open gangway at the middle), as the Metro train's collision: platform side +X with four
	# 6-wide doors and two 5-wide windows, track side solid but for two doors. Now with a rounded roof, fluted lower
	# sides, framed glazing, door leaves, equipment skirts, sprung bogies and raked cab fronts.
	hz, hw = TRAIN_L / 2, TRAIN_W / 2
	pdoors = [(-22.5, -16.5), (-9.5, -3.5), (3.5, 9.5), (16.5, 22.5)]
	windows = [(-15.5, -10.5), (10.5, 15.5)]
	tdoors = [(-9.5, -3.5), (3.5, 9.5)]
	joint = (-1.5, 1.5)
	skin, stripe, frames, glass, dark, glows, bellows, flutes = (bmesh.new() for _ in range(8))
	zs, ze = -hz + 0.5, hz - 0.5

	def gaps(intervals, a, b):
		out, cur = [], a
		for x0, x1 in sorted(intervals):
			x0, x1 = max(x0, a), min(x1, b)
			if x1 <= x0:
				continue
			if x0 > cur:
				out.append((cur, x0))
			cur = max(cur, x1)
		if cur < b:
			out.append((cur, b))
		return out

	# Platform side (+X)
	for za, zb in gaps(pdoors + windows, zs, ze):
		merge(skin, rb(hw - 0.5, hw, -0.1, 7.0, za, zb))
		if zb - za > 1.0:
			for y in (0.6, 1.2, 1.8):
				merge(flutes, rb(hw, hw + 0.07, y, y + 0.22, za + 0.25, zb - 0.25, ch=0.03))
	for za, zb in windows:
		merge(skin, rb(hw - 0.5, hw, -0.1, 3.5, za, zb))
		merge(glass, rb(hw - 0.3, hw - 0.24, 3.5, 7.0, za, zb))
		merge(frames, G(rb(hw, hw + 0.09, 3.35, 7.15, za - 0.16, za), rb(hw, hw + 0.09, 3.35, 7.15, zb, zb + 0.16),
						rb(hw, hw + 0.09, 3.35, 3.5, za, zb), rb(hw, hw + 0.09, 7.0, 7.15, za, zb)))
		for y in (0.6, 1.2, 1.8):
			merge(flutes, rb(hw, hw + 0.07, y, y + 0.22, za + 0.25, zb - 0.25, ch=0.03))
	for da, db in pdoors:
		merge(frames, G(rb(hw, hw + 0.09, -0.1, 7.15, da - 0.16, da), rb(hw, hw + 0.09, -0.1, 7.15, db, db + 0.16),
						rb(hw, hw + 0.09, 7.0, 7.15, da, db)))
		merge(glows, rb(hw, hw + P, 7.4, 7.6, (da + db) / 2 - 0.25, (da + db) / 2 + 0.25))
	merge(skin, rb(hw - 0.5, hw, 7.0, 9.0, zs, ze))
	seams = bmesh.new()
	for z in (-24.0, -2.6, 2.6, 24.0):  # on the solid platform-side panels only
		merge(seams, rb(hw, hw + 0.06, 3.3, 6.9, z - 0.05, z + 0.05))
	# Track side (-X)
	for za, zb in gaps(tdoors, zs, ze):
		merge(skin, rb(-hw, -hw + 0.5, -0.1, 7.0, za, zb))
		for wa, wb in gaps([joint], za + 0.8, zb - 0.8):
			if wb - wa > 2.0:
				merge(dark, rb(-hw - P, -hw, 3.6, 6.9, wa + 0.3, wb - 0.3))
				for y in (0.6, 1.2, 1.8):
					merge(flutes, rb(-hw - 0.07, -hw, y, y + 0.22, wa + 0.3, wb - 0.3, ch=0.03))
	for da, db in tdoors:
		merge(frames, G(rb(-hw - 0.09, -hw, -0.1, 7.15, da - 0.16, da), rb(-hw - 0.09, -hw, -0.1, 7.15, db, db + 0.16),
						rb(-hw - 0.09, -hw, 7.0, 7.15, da, db)))
	merge(skin, rb(-hw, -hw + 0.5, 7.0, 9.0, zs, ze))
	thresholds = bmesh.new()
	for da, db in pdoors:
		merge(thresholds, rb(hw - 0.5, hw, -0.1, 0.04, da, db))
	for da, db in tdoors:
		merge(thresholds, rb(-hw, -hw + 0.5, -0.1, 0.04, da, db))
	# Open door leaves, slid back into pockets inside the wall (visible edge only), and grab poles at the doors.
	leaves = bmesh.new()
	for da, db in pdoors:
		for z0, z1 in ((da - 1.5, da - 0.2), (db + 0.2, db + 1.5)):
			merge(leaves, rb(hw - 0.42, hw - 0.3, 0.1, 6.9, z0, z1))
	for side, doors in ((1, pdoors), (-1, tdoors)):
		x0, x1 = (hw, hw + P) if side > 0 else (-hw - P, -hw)
		for za, zb in gaps([(a - 0.16, b + 0.16) for a, b in doors] + [(joint[0] - 0.05, joint[1] + 0.05)], zs, ze):
			merge(stripe, rb(x0, x1, 2.6, 3.2, za, zb))
	for s in (1, -1):
		x0, x1 = (hw + 0.09, hw + 0.22) if s > 0 else (-hw - 0.22, -hw - 0.09)
		merge(bellows, rb(x0, x1, -0.1, 9.05, joint[0], joint[1]))
	merge(bellows, rz([(-hw - 0.22, 9.05), (hw + 0.22, 9.05), (hw + 0.22, 9.4), (hw - 0.8, 10.0), (-hw + 0.8, 10.0), (-hw - 0.22, 9.4)], joint[0], joint[1]))
	ribs = bmesh.new()
	for k in range(5):
		z = joint[0] + 0.25 + k * 0.625
		for s in (1, -1):
			x0, x1 = (hw + 0.22, hw + 0.3) if s > 0 else (-hw - 0.3, -hw - 0.22)
			merge(ribs, rb(x0, x1, 0.2, 8.8, z - 0.08, z + 0.08))
	# Roof: rounded shoulders over the collision roof (9..10), roof units low (the roof is a play space).
	prof = [(-hw, 9.0), (hw, 9.0), (hw, 9.25), (hw - 0.25, 9.6), (hw - 0.8, 9.85), (hw - 1.8, 10.0), (-hw + 1.8, 10.0), (-hw + 0.8, 9.85), (-hw + 0.25, 9.6), (-hw, 9.25)]
	roof = bmesh.new()
	for za, zb in gaps([joint], -hz + 0.5, hz - 0.5):
		merge(roof, rz(prof, za, zb))
	units = G(*[rb(-1.8, 1.8, 10.0, 10.22, z - 2.2, z + 2.2, ch=0.08) for z in (-14.0, 14.0)])
	grilles = bmesh.new()
	for z in (-14.0, 14.0):
		for i in range(5):
			zz = z - 1.6 + i * 0.8
			merge(grilles, rb(-1.4, 1.4, 10.22, 10.27, zz - 0.15, zz + 0.15))
	ends = G(rb(-hw, hw, -0.1, 9.0, -hz, -hz + 0.5), rb(-hw, hw, -0.1, 9.0, hz - 0.5, hz))
	head, tail, bumper, cabwin, coupler = (bmesh.new() for _ in range(5))
	dest = {}
	for s in (1, -1):
		f = s * hz
		# cab nose: a raked front with rounded corners in plan
		merge(skin, rx([(f, -1.2), (f + 0.55 * s, -1.0), (f + 0.65 * s, 2.0), (f + 0.55 * s, 8.3), (f + 0.25 * s, 9.3), (f, 9.45)], -hw + 0.35, hw - 0.35))
		fz0, fz1 = sorted((f + 0.67 * s, f + 0.73 * s))
		merge(cabwin, rx([(f + 0.62 * s, 4.0), (f + 0.62 * s + P * s, 4.0), (f + 0.5 * s + P * s, 7.9), (f + 0.5 * s, 7.9)], -hw + 1.0, hw - 1.0))
		merge(stripe, rb(-hw + 0.5, hw - 0.5, 2.6, 3.2, fz0, fz1))
		hz0, hz1 = sorted((f + 0.62 * s, f + 0.72 * s))
		for x in (-3.3, 3.3):
			merge(head, rb(x - 0.6, x + 0.6, 1.3, 1.9, hz0, hz1, ch=0.04))
			merge(tail, rb(x - 0.35, x + 0.35, 0.6, 0.95, hz0, hz1, ch=0.03))
		route0, route1 = sorted((f + 0.5 * s + 0.02 * s, f + 0.5 * s + 0.08 * s))
		dest[1 if s > 0 else 2] = rb(-2.6, 2.6, 8.0, 8.5, route0, route1)
		bz0, bz1 = sorted((f + 0.3 * s, f + 0.75 * s))
		merge(bumper, rb(-hw + 0.4, hw - 0.4, -1.55, -1.1, bz0, bz1, ch=0.1))
		cz0, cz1 = sorted((f + 0.7 * s, f + 1.4 * s))
		merge(coupler, G(rb(-0.35, 0.35, -1.3, -0.7, cz0, cz1, ch=0.08)))
	under = rb(-hw + 0.3, hw - 0.3, -1.0, -0.1, -hz + 0.6, hz - 0.6)
	skirts, bogies, wheels, springs, boxes = (bmesh.new() for _ in range(5))
	bz = (-18.0, 0.0, 18.0)
	for za, zb in gaps([(b - 2.8, b + 2.8) for b in bz], -hz + 0.8, hz - 0.8):
		for s in (1, -1):
			x0, x1 = (hw - 0.62, hw - 0.25) if s > 0 else (-hw + 0.25, -hw + 0.62)
			merge(skirts, rb(x0, x1, -1.7, -1.0, za, zb, ch=0.05))
			# equipment boxes behind the skirt line
			for k in range(int((zb - za) // 4)):
				zc = za + 2.0 + k * 4.0
				bx0, bx1 = (hw - 2.4, hw - 0.7) if s > 0 else (-hw + 0.7, -hw + 2.4)
				merge(boxes, rb(bx0, bx1, -1.65, -1.0, zc - 1.4, zc + 1.4, ch=0.08))
	for b in bz:
		merge(bogies, G(rb(-3.1, 3.1, -2.2, -1.5, b - 2.7, b + 2.7, ch=0.12), rb(-0.8, 0.8, -1.5, -1.0, b - 0.8, b + 0.8, ch=0.08)))
		for wz in (b - 1.6, b + 1.6):
			for wx in (-2.2, 2.2):
				merge(wheels, xcyl(-2.0, wz, 0.88, wx - 0.22, wx + 0.22, segs=16))
				merge(wheels, xcyl(-2.0, wz, 0.42, wx + (0.22 if wx > 0 else -0.36), wx + (0.36 if wx > 0 else -0.22), segs=10))
			merge(springs, G(vcyl(-2.6, wz, 0.28, -1.5, -1.05, segs=10), vcyl(2.6, wz, 0.28, -1.5, -1.05, segs=10)))
	floor = rb(-hw + 0.5, hw - 0.5, -0.1, 0.0, zs, ze)
	ceiling = rb(-hw + 0.5, hw - 0.5, 8.3, 9.0, zs, ze)
	lights = G(rb(1.6, 2.2, 8.3 - P, 8.3, zs + 1.0, ze - 1.0), rb(-2.2, -1.6, 8.3 - P, 8.3, zs + 1.0, ze - 1.0))
	seats, backs = bmesh.new(), bmesh.new()
	runs = {1: [w for w in windows], -1: gaps(tdoors + [(-2.0, 2.0)], zs + 2.5, ze - 2.5)}
	for s, rr in runs.items():
		xin = (hw - 0.5) * s
		for za, zb in rr:
			za, zb = za + 0.2, zb - 0.2
			if zb - za < 1.5:
				continue
			c0, c1 = sorted((xin, xin - 1.3 * s))
			b0, b1 = sorted((xin, xin - 1.1 * s))
			k0, k1 = sorted((xin, xin - 0.25 * s))
			merge(seats, rb(c0, c1, 1.4, 1.9, za, zb, ch=0.08))
			merge(seats, rb(b0, b1, 0.0, 1.4, za + 0.2, zb - 0.2))
			merge(backs, rb(k0, k1, 1.9, 3.4, za, zb, ch=0.06))
	poles = bmesh.new()
	for da, db in pdoors:
		zc = (da + db) / 2
		for x in (2.4, -2.4):
			merge(poles, vcyl(x, zc, 0.12, 0.0, 8.3, segs=8))
	for x in (2.4, -2.4):
		merge(poles, zcyl(x, 7.6, 0.1, zs + 1.0, ze - 1.0, segs=8))
	return {
		"Body": (G(skin, ends), "M_TrainBody"),
		"Flutes": (flutes, "M_TrainBody"),
		"Seams": (seams, "M_TrainDark"),
		"Thresholds": (thresholds, "M_Tactile"),
		"Leaves": (leaves, "M_TrainBody"),
		"Stripe": (stripe, "M_Stripe"),
		"Frames": (frames, "M_Rubber"),
		"Glass": (glass, "M_Glass"),
		"DarkGlass": (G(dark, cabwin), "M_DarkGlass"),
		"Bellows": (bellows, "M_Rubber"),
		"BellowsRibs": (ribs, "M_Charcoal"),
		"Roof": (roof, "M_TrainBody"),
		"RoofUnits": (units, "M_Stainless"),
		"Grilles": (grilles, "M_Charcoal"),
		"Under": (G(under, bogies), "M_TrainDark"),
		"Boxes": (boxes, "M_TrainDark"),
		"Skirts": (skirts, "M_TrainDark"),
		"Springs": (springs, "M_Charcoal"),
		"Bumper": (bumper, "M_Charcoal"),
		"Coupler": (coupler, "M_Charcoal"),
		"Wheels": (wheels, "M_Rail"),
		"Floor": (floor, "M_Granite"),
		"Ceiling": (ceiling, "M_White"),
		"Seats": (seats, "M_Seat"),
		"SeatBack": (backs, "M_Seat"),
		"Poles": (poles, "M_Tactile"),
		"Lights_Glow": (lights, "G_Cool"),
		"DoorLamp_Glow": (glows, "G_Amber"),
		"Head_Glow": (head, "G_Head"),
		"Tail_Glow": (tail, "G_Red"),
		"Dest1_Face": (dest[1], "M_Screen"),
		"Dest2_Face": (dest[2], "M_Screen"),
	}


def p_trains(mats, kit):
	piece("Train", train(), mats, kit)


# ---------------------------------------------------------------- stairs

def p_escalators(mats, kit):
	# 9 wide, run 24, rise 14, rising toward +Z: two escalators and a fixed stair between balustrades with glass,
	# rubber handrails over a lit strip, rounded newel ends.
	run, rise = 24.0, 14.0
	lanes = [(-4.3, -1.5), (-1.1, 1.1), (1.5, 4.3)]
	decks = [(-4.5, -4.3), (-1.5, -1.1), (1.1, 1.5), (4.3, 4.5)]
	treads, nos = bmesh.new(), bmesh.new()
	for x0, x1 in lanes:
		t, n = steps(x0, x1, 0.0, run - 0.1, rise, 21)
		merge(treads, t)
		merge(nos, n)
	deck, glass, rail, strip, newel = (bmesh.new() for _ in range(5))
	for xa, xb in decks:
		xc = (xa + xb) / 2
		merge(deck, slope_panel(xa, xb, 0.1, run - 0.2, rise * 0.1 / run, rise * (run - 0.2) / run, 1.2 + rise * 0.1 / run, 1.2 + rise * (run - 0.2) / run))
		merge(glass, slope_panel(xc - 0.05, xc + 0.05, 0.4, run - 0.5, 1.2, rise + 1.2, 3.1, rise + 3.1))
		merge(rail, slope_panel(max(xc - 0.13, -4.5), min(xc + 0.13, 4.5), 0.3, run - 0.4, 3.2, rise + 3.2, 3.5, rise + 3.5))
		merge(strip, slope_panel(xc - 0.03, xc + 0.03, 0.4, run - 0.5, 3.12, rise + 3.12, 3.19, rise + 3.19))
		merge(newel, G(rb(max(xc - 0.16, -4.5), min(xc + 0.16, 4.5), 0.0, 3.5, -0.6, 0.3, ch=0.12)))
	combs = G(rb(-4.3, -1.5, 0.0, P, -1.0, 0.0), rb(1.5, 4.0, 0.0, P, -1.0, 0.0))
	p = {
		"Treads": (treads, "M_Stainless"),
		"Nosing": (nos, "M_Tactile"),
		"Deck": (deck, "M_Charcoal"),
		"Glass": (glass, "M_Glass"),
		"Handrail": (rail, "M_Rubber"),
		"Strip_Glow": (strip, "G_Warm"),
		"Newels": (newel, "M_Stainless"),
		"Combs": (combs, "M_Tactile"),
	}
	piece("EscalatorBank", p, mats, kit)


def p_hall_stairs(mats, kit):
	# 8 wide, run 22, rise 14: granite treads with dark nosings, tile sides on a dark plinth band, charcoal stringer
	# caps (the route language: dark rails against light tile), glass balustrade and a stainless handrail.
	run, rise, n = 22.0, 14.0, 21
	t, no = steps(-3.9, 3.9, 0.0, run - 0.1, rise, n)
	sides = {}
	caps, glass, posts = bmesh.new(), bmesh.new(), bmesh.new()
	for sgn, key in ((-1, "SideL"), (1, "SideR")):
		x0, x1 = sorted((sgn * 3.9, sgn * 4.06))
		sides[key] = rx([(0.05, 0.0), (run - 0.15, 0.0), (run - 0.15, rise - 0.25), (0.05, 0.45)], x0, x1)
		c0, c1 = sorted((sgn * 3.83, sgn * 4.18))
		merge(caps, slope_panel(c0, c1, 0.1, run - 0.2, 0.33, rise - 0.27, 0.78, rise + 0.18))
		g0, g1 = sorted((sgn * 3.96, sgn * 4.04))
		merge(glass, slope_panel(g0, g1, 0.6, run - 0.6, 0.6 + rise * 0.6 / run + 0.35, rise - rise * 0.6 / run + 0.35, 0.6 + rise * 0.6 / run + 2.9, rise - rise * 0.6 / run + 2.9))
		for i in range(6):
			z = 0.5 + i * (run - 1.0) / 5
			y = rise * z / run + 0.5
			merge(posts, rb(sgn * 4.0 - 0.1, sgn * 4.0 + 0.1, y, y + 3.0, z - 0.1, z + 0.1, ch=0.03))
	rail = bmesh.new()
	for xc in (-4.0, 4.0):
		merge(rail, slope_panel(xc - 0.13, xc + 0.13, 0.3, run - 0.3, 0.5 + rise * 0.3 / run + 3.0, rise - rise * 0.3 / run + 0.5 + 3.0, 0.5 + rise * 0.3 / run + 3.25, rise - rise * 0.3 / run + 0.5 + 3.25))
	p = {
		"Treads": (t, "M_Granite"),
		"Nosing": (no, "M_Charcoal"),
		"SideL": (sides["SideL"], "M_Tile"),
		"SideR": (sides["SideR"], "M_Tile"),
		"Caps": (caps, "M_Charcoal"),
		"Glass": (glass, "M_Glass"),
		"Posts": (posts, "M_Stainless"),
		"Rail": (rail, "M_Stainless"),
	}
	piece("HallStairs", p, mats, kit)


def p_corridor_stair(mats, kit):
	run, rise = 24.0, 14.0
	t, no = steps(-5.9, 5.9, 0.0, run - 0.1, rise, 21)
	rail, posts = bmesh.new(), bmesh.new()
	for xc in (-5.7, 5.7):
		merge(rail, slope_panel(xc - 0.12, xc + 0.12, 0.2, run - 0.3, 3.2 + rise * 0.2 / run, rise + 3.2, 3.45 + rise * 0.2 / run, rise + 3.45))
		for i in range(5):
			z = 1.0 + i * (run - 2.0) / 4
			y = rise * z / run
			merge(posts, rb(xc - 0.1, xc + 0.1, y - 0.3, y + 3.2, z - 0.1, z + 0.1, ch=0.03))
	p = {"Treads": (t, "M_Concrete"), "Nosing": (no, "M_Tactile"), "Rail": (rail, "M_Tactile"), "Posts": (posts, "M_Charcoal")}
	piece("CorridorStair", p, mats, kit)


# ---------------------------------------------------------------- the landmark: departure gantry

def p_gantry(mats, kit):
	# Full hall width (x -34.6..34.6, into each wall), z -1.5..1.5, solid from 11 up (it closes the terrace-to-terrace
	# line, so it reads solid): a concrete transfer beam carrying a black steel Warren truss on both faces, the amber
	# departure board in a riveted housing, the platform signs, and the station clock hanging between the trains.
	X = HALL_X + 0.6
	beam = G(rb(-X, X, 16.6, CEIL - 0.04, -1.0, 1.0), rb(-X, X, 11.2, 16.6, -0.9, 0.9))
	chords, members, gussets = bmesh.new(), bmesh.new(), bmesh.new()
	for s in (-1, 1):
		z0, z1 = sorted((s * 1.0, s * 1.5))
		zc = s * 1.25
		merge(chords, G(rb(-X, X, 26.7, 27.7, z0, z1, ch=0.1), rb(-X, X, 16.6, 17.6, z0, z1, ch=0.1)))
		xs = [-32.2 + i * 64.4 / 11 for i in range(12)]
		for i, x in enumerate(xs):
			merge(members, rb(x - 0.3, x + 0.3, 17.6, 26.7, zc - 0.22, zc + 0.22, ch=0.06))
			if i < len(xs) - 1:
				a, b = (x + 0.3, 17.6, zc), (xs[i + 1] - 0.3, 26.7, zc)
				if i % 2:
					a, b = (x + 0.3, 26.7, zc), (xs[i + 1] - 0.3, 17.6, zc)
				merge(members, bar_between(a, b, 0.45, 0.4))
			for y in (17.6, 26.7):
				g0, g1 = sorted((s * 1.5, s * 1.56))
				merge(gussets, rb(x - 0.7, x + 0.7, y - 0.55, y + 0.55, g0, g1))
	# Board housing (11..16.4) and the platform-sign housings.
	housing = rb(-12.6, 12.6, 11.0, 16.45, -1.5, 1.5, ch=0.14)
	sign_housing = G(rb(-31.6, -16.4, 12.4, 16.45, -1.42, 1.42, ch=0.1), rb(16.4, 31.6, 12.4, 16.45, -1.42, 1.42, ch=0.1))
	hangers = G(*[rb(x - 0.2, x + 0.2, 16.4, 16.7, -0.6, 0.6) for x in (-10.0, 10.0, -24.0, 24.0)])
	frame = bmesh.new()
	for s in (-1, 1):
		z0, z1 = sorted((s * 1.52, s * 1.62))
		merge(frame, G(rb(-12.3, 12.3, 15.98, 16.28, z0, z1), rb(-12.3, 12.3, 11.12, 11.42, z0, z1),
					   rb(-12.3, -12.03, 11.42, 15.98, z0, z1), rb(12.03, 12.3, 11.42, 15.98, z0, z1)))
	board, signs = bmesh.new(), {}
	bz = {}
	for s, key in ((-1, "S"), (1, "N")):
		z0, z1 = sorted((s * 1.5, s * (1.5 + P)))
		bz[key] = rb(-12.0, 12.0, 11.45, 15.95, z0, z1)
		z0, z1 = sorted((s * 1.42, s * (1.42 + P)))
		signs["Sign2" + key] = rb(-31.0, -17.0, 12.8, 16.05, z0, z1)
		signs["Sign1" + key] = rb(17.0, 31.0, 12.8, 16.05, z0, z1)
	amber = rb(-12.3, 12.3, 10.94, 11.0, -1.3, 1.3)
	skirt = G(rb(-X, -12.6, 11.26, 12.4, -0.95, 0.95), rb(12.6, X, 11.26, 12.4, -0.95, 0.95))
	# The clock: a steel drum on a stem, faces both sides (art: Clock), a centre cap.
	cy, R = 7.0, 3.2
	stem = rb(-0.45, 0.45, cy + R - 0.2, 10.97, -0.45, 0.45, ch=0.08)
	drum = zcyl(0.0, cy, R - 0.1, -1.1, 1.1, segs=40)
	rim, face, cap = bmesh.new(), {}, bmesh.new()
	for s, key in ((-1, "S"), (1, "N")):
		a, b = sorted((s * 1.1, s * 1.35))
		merge(rim, zcyl(0.0, cy, R, a, b, segs=40))
		a, b = sorted((s * 1.35, s * 1.41))
		face[key] = zcyl(0.0, cy, R - 0.3, a, b, segs=40)
		a, b = sorted((s * 1.41, s * 1.55))
		merge(cap, zcyl(0.0, cy, 0.22, a, b, segs=12))
	p = {
		"Beam": (beam, "M_Concrete"),
		"Chords": (chords, "M_Charcoal"),
		"Members": (members, "M_Charcoal"),
		"Gussets": (gussets, "M_Charcoal"),
		"Housing": (housing, "M_Charcoal"),
		"SignHousing": (sign_housing, "M_Charcoal"),
		"Hangers": (hangers, "M_Charcoal"),
		"Skirt": (skirt, "M_Charcoal"),
		"BoardS_Face": (bz["S"], "M_Screen"),
		"BoardN_Face": (bz["N"], "M_Screen"),
		"Edge_Glow": (amber, "G_Amber"),
		"BoardFrame_Glow": (frame, "G_Amber"),
		"ClockStem": (stem, "M_Charcoal"),
		"ClockDrum": (drum, "M_Charcoal"),
		"ClockRim": (rim, "M_Stainless"),
		"ClockS_Face": (face["S"], "M_White"),
		"ClockN_Face": (face["N"], "M_White"),
		"ClockCap": (cap, "M_Charcoal"),
	}
	for k, bm in signs.items():
		p[k + "_Face"] = (bm, "M_Screen")
	piece("Gantry", p, mats, kit)


# ---------------------------------------------------------------- end wall (tunnel portal, name panel, parapets)

def end_cladding(x0, x1):
	# The wall layers on the end wall (face z = 0, facing -Z), between x0 and x1, below the terrace (14).
	def E(d0, d1, y0, y1, ch=0.0):
		return rb(x0, x1, y0, y1, -d1, -d0, ch=ch)
	return {
		"Skirt": E(0, 0.45, 0, 0.6, 0.06), "Dado": E(0, 0.3, 0.6, 3.4), "DadoCap": E(0, 0.42, 3.4, 3.6, 0.05),
		"Field": E(0, 0.25, 3.6, 9.3), "BeadLow": E(0, 0.38, 9.3, 9.5, 0.04), "Band": E(0, 0.3, 9.5, 12.3),
		"BeadHigh": E(0, 0.38, 12.3, 12.5, 0.04), "FieldTop": E(0, 0.25, 12.5, 13.4),
	}


def p_end_wall(mats, kit):
	parts = {}
	roles = {"Skirt": "M_Granite", "Dado": "M_TileDark", "DadoCap": "M_Stainless", "Field": "M_Tile", "BeadLow": "M_Charcoal",
			 "Band": "M_Band", "BeadHigh": "M_Charcoal", "FieldTop": "M_Tile"}
	acc = {k: bmesh.new() for k in roles}
	for x0, x1 in ((-33.4, -15.4), (15.4, 24.4)):
		for k, bm in end_cladding(x0, x1).items():
			merge(acc[k], bm)
	for k, bm in acc.items():
		parts[k] = (bm, roles[k])
	# Tunnel portal: a deep chamfered concrete surround with an end-colour inner ring; lining rings, lamps and cable
	# runs inside the mouth; the dark tunnel back.
	surround = G(
		rb(-15.4, -13.85, TRENCH, 11.2, -0.75, 0.2, ch=0.3), rb(13.85, 15.4, TRENCH, 11.2, -0.75, 0.2, ch=0.3),
		rb(-14.0, 14.0, 10.0, 11.2, -0.75, 0.2, ch=0.3),
	)
	ring = G(rb(-13.85, -13.48, TRENCH, 10.0, -0.82, -0.12), rb(13.48, 13.85, TRENCH, 10.0, -0.82, -0.12), rb(-13.48, 13.48, 9.6, 10.0, -0.82, -0.12))
	lining = bmesh.new()
	for z in (0.7, 1.6, 2.5):
		merge(lining, G(rb(-13.45, -13.05, TRENCH + 0.02, 9.4, z - 0.22, z + 0.22, ch=0.06), rb(13.05, 13.45, TRENCH + 0.02, 9.4, z - 0.22, z + 0.22, ch=0.06),
						rb(-13.05, 13.05, 9.0, 9.4, z - 0.22, z + 0.22, ch=0.06)))
	reveal = G(rb(-13.6, -13.45, TRENCH, 9.6, -0.12, 2.9), rb(13.45, 13.6, TRENCH, 9.6, -0.12, 2.9), rb(-13.45, 13.45, 9.4, 9.6, -0.12, 2.9))
	cables = G(*[xcyl(y, 1.15, 0.12, -13.0, -12.5, segs=6) for y in ()])
	cables = G(zcyl(-13.3, 6.2, 0.13, -0.1, 2.95, segs=8), zcyl(-13.3, 6.6, 0.11, -0.1, 2.95, segs=8), zcyl(13.3, 6.4, 0.13, -0.1, 2.95, segs=8))
	lamps = G(rb(-13.45, -13.3, 4.3, 4.7, 1.0, 1.25), rb(13.3, 13.45, 4.3, 4.7, 1.0, 1.25), rb(-13.45, -13.3, 4.3, 4.7, 2.1, 2.35), rb(13.3, 13.45, 4.3, 4.7, 2.1, 2.35))
	tunnel = rb(-13.45, 13.45, TRENCH + 0.02, 9.4, 2.9, 3.0)
	lintel = rb(-15.4, 15.4, 11.2, 13.4, -0.4, 0.0)
	ledge = rb(-33.4, 24.4, 13.4, 13.94, -0.55, 0.0, ch=0.06)
	# Buffer stop on the open track (centre x = -8.5) and signals on brackets.
	buffer = rb(-11.0, -6.0, TRENCH + 0.78, TRENCH + 2.6, 1.6, 2.4, ch=0.12)
	buffer_frame = G(rb(-10.7, -10.1, TRENCH + 0.02, TRENCH + 0.75, 1.75, 2.85, ch=0.05), rb(-6.9, -6.3, TRENCH + 0.02, TRENCH + 0.75, 1.75, 2.85, ch=0.05),
					 bar_between((-10.4, TRENCH + 2.0, 2.6), (-10.4, TRENCH + 0.75, 2.6), 0.3, 0.3))
	red = G(rb(-11.2, -10.4, TRENCH + 1.0, TRENCH + 1.6, 1.6 - P, 1.6), rb(-6.6, -5.8, TRENCH + 1.0, TRENCH + 1.6, 1.6 - P, 1.6))
	sig = G(rb(-13.2, -12.4, 4.0, 6.4, 0.4, 1.0, ch=0.08), rb(12.4, 13.2, 4.0, 6.4, 0.4, 1.0, ch=0.08))
	sigarm = G(rb(-13.38, -13.2, 4.9, 5.5, 0.55, 0.85), rb(13.2, 13.38, 4.9, 5.5, 0.55, 0.85))
	sig_r = G(rb(-12.95, -12.65, 5.6, 6.0, 0.4 - P, 0.4), rb(12.65, 12.95, 5.6, 6.0, 0.4 - P, 0.4))
	sig_g = G(rb(-12.95, -12.65, 4.6, 5.0, 0.4 - P, 0.4), rb(12.65, 12.95, 4.6, 5.0, 0.4 - P, 0.4))
	# Escalator mouth (x 25..34) up to the terrace level, with its sign plate.
	mouth = G(rb(24.35, 24.92, 0.0, 13.4, -0.65, 0.6, ch=0.08), rb(24.35, HALL_X - 0.05, 13.4, 14.4, -0.65, 0.6, ch=0.08))
	mplate = G(rb(26.0, 33.0, 11.0, 12.7, -0.3, 0.3, ch=0.06), rb(27.0, 27.25, 12.6, 13.5, -0.12, 0.12), rb(31.75, 32.0, 12.6, 13.5, -0.12, 0.12))
	mface = rb(26.1, 32.9, 11.1, 12.6, -0.36, -0.3)
	# Terrace level: name panel (x -14..14, 14..22) with an end-colour surround and the MERIDIAN plate; tiled
	# parapets with granite copings and a stainless rail.
	panel = rb(-14.0, 14.0, 14.0, 22.0, 0.0, 1.0, ch=0.2)
	surround_t = G(rb(-12.6, 12.6, 15.0, 15.4, -0.18, 0.0), rb(-12.6, 12.6, 20.6, 21.0, -0.18, 0.0), rb(-12.6, -12.2, 15.4, 20.6, -0.18, 0.0), rb(12.2, 12.6, 15.4, 20.6, -0.18, 0.0))
	name_face = rb(-12.0, 12.0, 15.5, 20.5, -0.12, -0.06)
	name_back = rb(-12.2, 12.2, 15.4, 20.6, -0.06, 0.0)
	parapet_w = rb(-35.9, -22.0, 14.0, 17.0, 0.0, 1.0)
	parapet_e = rb(14.0, 23.9, 14.0, 17.0, 0.0, 1.0)
	cap_w = rb(-35.9, -22.0, 17.0, 17.3, -0.25, 1.15, ch=0.08)
	cap_e = rb(14.0, 23.9, 17.0, 17.3, -0.25, 1.15, ch=0.08)
	rail, rposts = bmesh.new(), bmesh.new()
	for x0, x1 in ((-35.4, -22.5), (14.5, 23.4)):
		merge(rail, xcyl(18.25, 0.45, 0.13, x0, x1, segs=10))
		n = max(2, int((x1 - x0) // 3) + 1)
		for i in range(n):
			x = x0 + 0.2 + i * (x1 - x0 - 0.4) / (n - 1)
			merge(rposts, vcyl(x, 0.45, 0.1, 17.3, 18.2, segs=8))
	parts.update({
		"Surround": (surround, "M_Concrete"),
		"Ring_Trim": (ring, "M_Stripe"),
		"Reveal": (reveal, "M_ConcreteDark"),
		"Lining": (lining, "M_Concrete"),
		"Cables": (cables, "M_Rubber"),
		"TunnelLamp_Glow": (lamps, "G_Warm"),
		"Tunnel": (tunnel, "M_TrainDark"),
		"Lintel": (lintel, "M_Concrete"),
		"Ledge": (ledge, "M_Concrete"),
		"Buffer": (buffer, "M_Red"),
		"BufferFrame": (buffer_frame, "M_Charcoal"),
		"SignalHeads": (G(sig, sigarm), "M_Charcoal"),
		"Lamp_Glow": (G(red, sig_r), "G_Red"),
		"Green_Glow": (sig_g, "G_Green"),
		"Mouth": (mouth, "M_Charcoal"),
		"MouthPlate": (mplate, "M_Charcoal"),
		"Mouth_Face": (mface, "M_Screen"),
		"Panel": (panel, "M_Concrete"),
		"Surround_Trim": (surround_t, "M_Stripe"),
		"NameBack": (name_back, "M_White"),
		"Name_Face": (name_face, "M_White"),
		"ParapetW": (parapet_w, "M_Tile"),
		"ParapetE": (parapet_e, "M_Tile"),
		"CapW": (cap_w, "M_Granite"),
		"CapE": (cap_e, "M_Granite"),
		"Rail": (rail, "M_Stainless"),
		"RailPosts": (rposts, "M_Stainless"),
	})
	piece("EndWall", parts, mats, kit)


# ---------------------------------------------------------------- furniture

def p_kiosk(mats, kit):
	# Meridian Coffee (collision 6 x 6 x 10): oak-clad counter base with slats, stainless counters on the serving
	# sides (+X, -X), a recessed lit interior with shelves and cups, the menu signs (art) on a fascia, a canopy with
	# down-lights. Story: the -X shutter is half raised (opening up for the morning).
	slats = bmesh.new()
	for s in (-1, 1):
		x0, x1 = sorted((s * 2.82, s * 2.88))
		for i in range(9):
			z = -2.4 + i * 0.6
			merge(slats, rb(x0, x1, 0.75, 3.25, z - 0.12, z + 0.12))
		z0, z1 = sorted((s * 2.82, s * 2.88))
		for i in range(9):
			x = -2.4 + i * 0.6
			merge(slats, rb(x - 0.12, x + 0.12, 0.75, 3.25, z0, z1))
	cups = bmesh.new()
	shelves = bmesh.new()
	for sx in (-1, 1):
		s0, s1 = sorted((sx * 2.4, sx * 2.72))
		for y in (4.4, 5.4):
			merge(shelves, rb(s0, s1, y - 0.08, y, -2.2, 2.2, ch=0.02))
			for j in range(6):
				z = -1.8 + j * 0.72
				merge(cups, lathe_v([(0, y), (0.16, y), (0.21, y + 0.42), (0, y + 0.42)], sx * 2.56, z, segs=10))
	shutter = bmesh.new()
	for i in range(6):
		y = 5.35 + i * 0.2
		merge(shutter, rb(-2.97, -2.88, y, y + 0.17, -2.5, 2.5, ch=0.02))
	lights = G(*[rb(sx * 3.0 - 0.25, sx * 3.0 + 0.25, 8.55, 8.6, z - 0.25, z + 0.25) for sx in (-1, 1) for z in (-1.6, 0.0, 1.6)])
	p = {
		"Plinth": (rb(-3.0, 3.0, 0.0, 0.75, -3.0, 3.0, ch=0.1), "M_Granite"),
		"Base": (rb(-2.82, 2.82, 0.75, 3.35, -2.82, 2.82), "M_Oak"),
		"Slats": (slats, "M_Oak"),
		"Counter": (rb(-3.1, 3.1, 3.35, 3.55, -2.9, 2.9, ch=0.06), "M_Stainless"),
		"Posts": (G(*[rb(*sorted((sx * 2.4, sx * 2.92)), 3.55, 6.65, *sorted((sz * 2.4, sz * 2.92)), ch=0.06) for sx in (-1, 1) for sz in (-1, 1)]), "M_Charcoal"),
		"Inner": (rb(-2.4, 2.4, 3.55, 6.65, -2.35, 2.35), "M_Oak"),
		"Shelves": (shelves, "M_Charcoal"),
		"Cups": (cups, "M_White"),
		"Back_Glow": (G(*[rb(*sorted((sx * 2.4, sx * 2.46)), 6.3, 6.55, -2.2, 2.2) for sx in (-1, 1)]), "G_Warm"),
		"Shutter": (shutter, "M_Stainless"),
		"Fascia": (rb(-2.9, 2.9, 6.65, 8.5, -2.9, 2.9, ch=0.08), "M_Oak"),
		"SignA_Face": (rb(2.9, 2.96, 6.85, 8.3, -2.4, 2.4), "M_White"),
		"SignB_Face": (rb(-2.96, -2.9, 6.85, 8.3, -2.4, 2.4), "M_White"),
		"Canopy": (G(rb(-3.45, 3.45, 8.5, 8.85, -3.45, 3.45, ch=0.1), rb(-3.0, 3.0, 8.85, 9.2, -3.0, 3.0, ch=0.08)), "M_Stainless"),
		"Trim": (rb(-3.5, 3.5, 8.6, 8.75, -3.5, 3.5), "M_Stripe"),
		"Down_Glow": (lights, "G_Warm"),
		"Roof": (rb(-2.6, 2.6, 9.2, 9.95, -2.6, 2.6, ch=0.12), "M_Charcoal"),
	}
	piece("Kiosk", p, mats, kit)


def p_vending(mats, kit):
	# Three machines (1.5 deep x 6 long x 8 tall) 0.55 off the wall, facing +X; the fronts carry the art.
	B0, F = 0.55, 2.05
	body, fronts, heads, kicks = bmesh.new(), {}, bmesh.new(), bmesh.new()
	for k in range(3):
		zc = -2.0 + k * 2.0
		merge(body, rb(B0, F, 0.35, 7.8, zc - 0.96, zc + 0.96, ch=0.1))
		fronts[k] = rb(F, F + P, 1.0, 7.2, zc - 0.82, zc + 0.82)
		merge(heads, rb(F - 0.1, F + 0.1, 7.3, 7.65, zc - 0.8, zc + 0.8, ch=0.04))
		merge(kicks, rb(F - 0.05, F + 0.08, 0.45, 0.9, zc - 0.7, zc + 0.7, ch=0.03))
	p = {
		"Body": (body, "M_Vending"),
		"Plinth": (rb(B0, F, 0.0, 0.35, -2.98, 2.98, ch=0.05), "M_Charcoal"),
		"Head_Glow": (heads, "G_Warm"),
		"Kick": (kicks, "M_Charcoal"),
	}
	for k, bm in fronts.items():
		p["Front%d_Face" % (k + 1)] = (bm, "M_Screen")
	piece("Vending", p, mats, kit)


def p_bench(mats, kit):
	o = 0.55
	slats = bmesh.new()
	for i in range(4):
		x = o + 0.4 + i * 0.36
		merge(slats, rb(x, x + 0.28, 1.45, 1.62, -2.9, 2.9, ch=0.05))
	for i in range(3):
		y = 1.95 + i * 0.36
		merge(slats, rb(o + 0.22, o + 0.4, y, y + 0.28, -2.9, 2.9, ch=0.05))
	frame = bmesh.new()
	for z in (-2.5, 0.0, 2.5):
		merge(frame, G(rb(o + 0.2, o + 1.55, 1.25, 1.45, z - 0.11, z + 0.11, ch=0.04), rb(o + 1.15, o + 1.4, 0.0, 1.25, z - 0.12, z + 0.12, ch=0.04),
					   rb(o, o + 0.22, 0.0, 3.0, z - 0.12, z + 0.12, ch=0.04), rb(o + 0.2, o + 1.55, 2.2, 2.35, z - 0.11, z + 0.11, ch=0.03) if z != 0.0 else rb(o + 1.1, o + 1.45, 0.0, 0.08, z - 0.3, z + 0.3)))
	piece("Bench", {"Slats": (slats, "M_Oak"), "Frame": (frame, "M_Charcoal")}, mats, kit)


def p_fare_gates(mats, kit):
	# 20 long x 1.5 deep x 3.5 tall: 7 stainless cabinets, glass paddles closed between (solid: it's cover).
	cab, pad, top, glow, reader = (bmesh.new() for _ in range(5))
	n = 7
	for i in range(n):
		x = -10.0 + 0.4 + i * (19.2 / (n - 1))
		merge(cab, rb(x - 0.4, x + 0.4, 0.0, 3.25, -0.75, 0.75, ch=0.12))
		merge(top, rb(x - 0.44, x + 0.44, 3.25, 3.5, -0.8, 0.8, ch=0.08))
		merge(glow, rb(x - 0.18, x + 0.18, 3.5, 3.54, 0.25, 0.55))
		merge(glow, rb(x - 0.18, x + 0.18, 3.5, 3.54, -0.55, -0.25))
		merge(reader, rb(x - 0.3, x + 0.3, 3.0, 3.25, -0.9, -0.75, ch=0.04))
		merge(reader, rb(x - 0.3, x + 0.3, 3.0, 3.25, 0.75, 0.9, ch=0.04))
		if i < n - 1:
			merge(pad, rb(x + 0.4, x + 0.4 + 19.2 / (n - 1) - 0.8, 0.8, 3.0, -0.12, 0.12, ch=0.04))
	p = {"Cabinets": (cab, "M_Stainless"), "Paddles": (pad, "M_Stainless"), "Tops": (top, "M_Charcoal"), "Readers": (reader, "M_Charcoal"), "Lamp_Glow": (glow, "G_Warm")}
	piece("FareGateRow", p, mats, kit)


def p_ticket_office(mats, kit):
	# 10 deep (x -10..0) x 18 long x 10 tall; front +X: granite base, mullioned dark glass, counter, sign (art).
	shell = G(rb(-10.0, 0.0, 1.2, 1.25, -9.0, 9.0), rb(-10.0, 0.0, 7.4, 10.0, -9.0, 9.0, ch=0.15))
	base = rb(-9.97, 0.05, 0.0, 1.2, -8.98, 8.98, ch=0.08)
	mull = G(*[rb(-0.4, -0.04, 1.28, 7.0, z - 0.2, z + 0.2, ch=0.04) for z in (-8.75, -4.5, 0.0, 4.5, 8.75)], rb(-0.5, -0.04, 7.0, 7.4, -8.95, 8.95, ch=0.04))
	win = rb(-0.3, -0.24, 1.25, 6.95, -8.55, 8.55)
	walls = G(rb(-10.0, -0.3, 1.25, 7.4, -9.0, -8.95), rb(-10.0, -0.3, 1.25, 7.4, 8.95, 9.0), rb(-10.0, -9.95, 1.25, 7.4, -8.95, 8.95))
	p = {
		"Base": (base, "M_Granite"),
		"Shell": (G(shell, walls), "M_Tile"),
		"Mullions": (mull, "M_Charcoal"),
		"Window": (win, "M_DarkGlass"),
		"Counter": (rb(-0.1, 0.85, 2.6, 2.82, -8.5, 8.5, ch=0.05), "M_Stainless"),
		"CounterBrackets": (G(*[rb(0.0, 0.6, 1.15, 2.62, z - 0.07, z + 0.07) for z in (-6.0, 0.0, 6.0)]), "M_Charcoal"),
		"SignPlate": (rb(0.0, 0.2, 7.75, 9.45, -6.1, 6.1, ch=0.05), "M_Charcoal"),
		"Sign_Face": (rb(0.2, 0.26, 7.85, 9.35, -6.0, 6.0), "M_Screen"),
		"Trim": (rb(0.0, 0.12, 9.6, 10.0, -9.0, 9.0), "M_Stripe"),
	}
	piece("TicketOffice", p, mats, kit)


def p_portal(mats, kit):
	# 10 x 10 opening through the 2-thick concourse wall: steel liners, a chamfered surround on each face, a sign box
	# over each face (art: PLATFORMS toward the ticket hall (+Z), EXIT toward the hall (-Z)).
	frame = G(rb(-5.0, -4.8, 0.0, 9.8, -1.0, 1.0), rb(4.8, 5.0, 0.0, 9.8, -1.0, 1.0), rb(-5.0, 5.0, 9.8, 10.0, -1.0, 1.0))
	face = bmesh.new()
	for s in (-1, 1):
		z0, z1 = sorted((s * 1.0, s * 1.14))
		merge(face, G(rb(-5.6, -5.0, 0.0, 10.0, z0, z1, ch=0.04), rb(5.0, 5.6, 0.0, 10.0, z0, z1, ch=0.04), rb(-5.6, 5.6, 10.0, 10.6, z0, z1, ch=0.04)))
	sign = bmesh.new()
	faces = {}
	for s, key in ((-1, "Hall"), (1, "Ticket")):
		z0, z1 = sorted((s * 1.0, s * 1.4))
		merge(sign, rb(-3.6, 3.6, 10.9, 12.7, z0, z1, ch=0.06))
		g0, g1 = sorted((s * 1.4, s * (1.4 + P)))
		faces[key] = rb(-3.4, 3.4, 11.05, 12.55, g0, g1)
	p = {"Frame": (frame, "M_Stainless"), "Face_Trim": (face, "M_Stripe"), "Sign": (sign, "M_Charcoal"),
		 "SignHall_Face": (faces["Hall"], "M_Screen"), "SignTicket_Face": (faces["Ticket"], "M_Screen")}
	piece("Portal10", p, mats, kit)


def p_door_frame(mats, kit):
	frame = G(rb(-4.0, -3.85, 0.0, 9.85, -0.5, 0.5), rb(3.85, 4.0, 0.0, 9.85, -0.5, 0.5), rb(-4.0, 4.0, 9.85, 10.0, -0.5, 0.5))
	face = G(rb(-4.45, -4.0, 0.0, 10.0, -0.64, -0.5, ch=0.03), rb(4.0, 4.45, 0.0, 10.0, -0.64, -0.5, ch=0.03), rb(-4.45, 4.45, 10.0, 10.45, -0.64, -0.5, ch=0.03))
	piece("DoorFrame8", {"Frame": (frame, "M_Stainless"), "Trim": (face, "M_Stripe")}, mats, kit)


def p_corridor(mats, kit):
	L = 3.95
	pipes = G(zcyl(0.75, 10.3, 0.38, -L, L, segs=14), zcyl(1.65, 10.4, 0.28, -L, L, segs=12), zcyl(0.65, 9.35, 0.24, -L, L, segs=10))
	flanges = G(*[zcyl(cx, cy, r + 0.1, z - 0.1, z + 0.1, segs=14) for cx, cy, r in ((0.75, 10.3, 0.38), (1.65, 10.4, 0.28)) for z in (-2.0, 2.0)])
	tray = G(rb(0.2, 2.1, 8.55, 8.65, -L, L), rb(2.1, 2.2, 8.55, 8.9, -L, L))
	cable = G(zcyl(0.9, 8.77, 0.12, -L + 0.06, L - 0.06, segs=6), zcyl(1.3, 8.77, 0.12, -L + 0.06, L - 0.06, segs=6), zcyl(1.7, 8.75, 0.1, -L + 0.06, L - 0.06, segs=6))
	brackets = G(*[G(rb(0.2, 2.3, 8.45, 8.55, z - 0.1, z + 0.1), rb(-0.1, 0.2, 8.45, 10.9, z - 0.1, z + 0.1), rb(0.2, 1.95, 8.65, 10.75, z - 0.08, z + 0.08)) for z in (-2.5, 1.5)])
	valve = G(zcyl(0.75, 10.3, 0.5, 0.3, 0.7, segs=14), vcyl(0.75, 0.5, 0.08, 10.7, 11.42, segs=6), vcyl(0.75, 0.5, 0.42, 11.42, 11.54, segs=14))
	piece("PipeRun8", {"Pipes": (pipes, "M_Stainless"), "Flanges": (flanges, "M_Charcoal"), "Valve": (valve, "M_Red"), "Tray": (tray, "M_Charcoal"),
					   "Cables": (cable, "M_Rubber"), "Brackets": (brackets, "M_Charcoal")}, mats, kit)
	body = rb(0.0, 0.5, 7.1, 7.9, -0.6, 0.6, ch=0.1)
	cage = G(*[rb(0.5 + P, 0.62, 7.15, 7.85, z - 0.04, z + 0.04) for z in (-0.4, 0.0, 0.4)], rb(0.62, 0.7, 7.45, 7.55, -0.5, 0.5))
	glow = rb(0.5, 0.5 + P, 7.25, 7.75, -0.45, 0.45)
	piece("CorridorLight", {"Body": (body, "M_Charcoal"), "Cage": (cage, "M_Tactile"), "Lamp_Glow": (glow, "G_Warm")}, mats, kit)
	door = G(rb(0.0, 0.15, 0.0, 7.0, -2.0, -0.03, ch=0.03), rb(0.0, 0.15, 0.0, 7.0, 0.03, 2.0, ch=0.03))
	frame = G(rb(0.0, 0.25, 0.0, 7.3, -2.3, -2.0, ch=0.04), rb(0.0, 0.25, 0.0, 7.3, 2.0, 2.3, ch=0.04), rb(0.0, 0.25, 7.0, 7.3, -2.0, 2.0, ch=0.04))
	vent = G(*[rb(0.15, 0.2, 0.8 + i * 0.25, 0.95 + i * 0.25, -1.5, -0.5) for i in range(4)])
	handles = G(rb(0.15, 0.32, 3.3, 3.5, -0.5, -0.15, ch=0.03), rb(0.15, 0.32, 3.3, 3.5, 0.15, 0.5, ch=0.03))
	plate = rb(0.15, 0.21, 5.2, 6.0, -1.5, -0.4)
	piece("PumpDoor", {"Door": (door, "M_ConcreteDark"), "Frame": (frame, "M_Charcoal"), "Vent": (vent, "M_Charcoal"), "Handles": (handles, "M_Stainless"),
					   "Plate": (plate, "M_Tactile")}, mats, kit)


# ---------------------------------------------------------------- small props and story groups

def p_props(mats, kit):
	# Bin (floor centre), r 0.75, 3 tall: stainless drum, charcoal lid with a slot, a band.
	piece("Bin", {
		"Drum": (lathe_v([(0, 0.0), (0.72, 0.0), (0.75, 0.15), (0.75, 2.6), (0, 2.6)], segs=16), "M_Stainless"),
		"Lid": (lathe_v([(0, 2.6), (0.8, 2.6), (0.8, 2.82), (0.5, 3.05), (0, 3.05)], segs=16), "M_Charcoal"),
		"Band": (lathe_v([(0, 1.6), (0.78, 1.6), (0.78, 1.9), (0, 1.9)], segs=16), "M_Stripe"),
	}, mats, kit)
	# CCTV (wall face x = 0, facing +X, at 12): a bracket and a camera housing tilted down.
	cam = tf(G(rb(0.0, 1.4, -0.32, 0.32, -0.3, 0.3, ch=0.08), rb(1.4, 1.55, -0.38, 0.38, -0.36, 0.36, ch=0.04)), RT(0.45, 12.0, 0) @ RZr(-20))
	piece("CCTV", {
		"Plate": (rb(0.0, 0.1, 11.6, 12.6, -0.35, 0.35, ch=0.03), "M_Charcoal"),
		"Arm": (rb(0.1, 0.55, 11.95, 12.25, -0.12, 0.12, ch=0.03), "M_Charcoal"),
		"Camera": (cam, "M_White"),
	}, mats, kit)
	# HelpPoint (wall face, +X): a stainless panel with a green call button and a grille.
	piece("HelpPoint", {
		"Panel": (rb(0.0, 0.32, 3.75, 6.75, -0.75, 0.75, ch=0.08), "M_Stainless"),
		"Head": (rb(0.32, 0.4, 5.75, 6.55, -0.6, 0.6, ch=0.03), "M_Stripe"),
		"Grille": (G(*[rb(0.32, 0.37, 4.65 + i * 0.16, 4.73 + i * 0.16, -0.4, 0.4) for i in range(5)]), "M_Charcoal"),
		"Button_Glow": (rb(0.32, 0.4, 4.15, 4.45, -0.15, 0.15), "G_Warm"),
	}, mats, kit)
	# Cone (floor centre): 2.2 tall, ochre with a white band, on a square base.
	piece("Cone", {
		"Base": (rb(-0.75, 0.75, 0.0, 0.15, -0.75, 0.75, ch=0.04), "M_Charcoal"),
		"Body": (lathe_v([(0, 0.15), (0.55, 0.15), (0.12, 2.2), (0, 2.2)], segs=14), "M_Tactile"),
		"Band": (lathe_v([(0, 1.05), (0.37, 1.05), (0.3, 1.45), (0, 1.45)], segs=14), "M_White"),
	}, mats, kit)
	# Night works (trench, by the relay box): the lifted cable-trough lid leaning on the wall, a hose coil, a toolbox.
	lid = tf(rb(0.0, 0.18, 0.0, 2.6, -1.0, 1.0, ch=0.04), RT(0.3, 0, 0) @ RZr(-12))
	coil = G(*[torus(1.0, -2.2, 0.8 - k * 0.1, 0.12, 0.12 + k * 0.22) for k in range(3)])
	piece("NightWorks", {
		"Lid": (lid, "M_Concrete"),
		"Hose": (coil, "M_Red"),
		"Toolbox": (rb(0.4, 1.4, 0.0, 0.8, 1.6, 3.3, ch=0.06), "M_Red"),
		"ToolboxLid": (rb(0.35, 1.45, 0.8, 0.95, 1.55, 3.35, ch=0.04), "M_Charcoal"),
		"Handle": (rb(0.85, 0.95, 0.95, 1.25, 2.1, 2.8, ch=0.02), "M_Charcoal"),
	}, mats, kit)
	# Lost property (floor, beside a bench, against the wall x = 0): a suitcase standing and a closed umbrella leaning.
	case = rb(0.6, 1.6, 0.2, 2.6, -0.85, 0.85, ch=0.12)
	wheels = G(*[xcyl(0.15, z, 0.15, 0.7, 0.85, segs=8) for z in (-0.6, 0.6)])
	umb = tf(G(lathe_v([(0, 0.0), (0.08, 0.15), (0.2, 0.8), (0.18, 2.4), (0.05, 2.9), (0, 2.9)], segs=10)), RT(0.35, 0, 1.6) @ RZr(-10))
	piece("LostProperty", {
		"Case": (case, "M_Seat"),
		"CaseTrim": (G(rb(0.55, 1.65, 1.35, 1.5, -0.88, 0.88), rb(0.95, 1.25, 2.6, 2.95, -0.25, 0.25, ch=0.04)), "M_Charcoal"),
		"Wheels": (wheels, "M_Rubber"),
		"Umbrella": (umb, "M_Charcoal"),
	}, mats, kit)
	# Kiosk morning delivery (floor centre): stacked boxes and a milk crate, 2-6 deg tilts.
	boxes = G(rb(-0.9, 0.9, 0.0, 1.4, -0.7, 0.7, ch=0.05), tf(rb(-0.8, 0.8, 1.4, 2.6, -0.6, 0.6, ch=0.05), RY(5)), tf(rb(-0.7, 0.7, 0.0, 1.1, 0.9, 2.1, ch=0.05), RY(-4)))
	crate = bmesh.new()
	merge(crate, rb(1.2, 2.6, 0.0, 0.12, -0.7, 0.7))
	for x0, x1, z0, z1 in ((1.2, 1.32, -0.7, 0.7), (2.48, 2.6, -0.7, 0.7), (1.32, 2.48, -0.7, -0.58), (1.32, 2.48, 0.58, 0.7)):
		merge(crate, rb(x0, x1, 0.12, 1.1, z0, z1))
	bottles = G(*[lathe_v([(0, 0.12), (0.18, 0.12), (0.18, 0.85), (0.08, 1.05), (0.08, 1.2), (0, 1.2)], x, z, segs=8) for x in (1.55, 1.9, 2.25) for z in (-0.3, 0.1)])
	piece("Delivery", {"Boxes": (boxes, "M_Oak"), "Crate": (crate, "M_Stripe"), "Bottles": (bottles, "M_White")}, mats, kit)
	# Stool (floor centre): oak seat on a charcoal pedestal.
	piece("Stool", {
		"Seat": (lathe_v([(0, 2.6), (0.65, 2.6), (0.7, 2.75), (0.65, 2.9), (0, 2.9)], segs=14), "M_Oak"),
		"Stem": (lathe_v([(0, 0.0), (0.7, 0.0), (0.7, 0.1), (0.12, 0.2), (0.12, 2.6), (0, 2.6)], segs=12), "M_Charcoal"),
		"Ring": (lathe_v([(0, 1.0), (0.45, 1.0), (0.45, 1.1), (0, 1.1)], segs=12), "M_Stainless"),
	}, mats, kit)


# ---------------------------------------------------------------- contact sheet

def sheet(mats, tris):
	sc = bpy.context.scene
	stage = K.collection("Sheet")
	cell = 40.0
	ncol = 7
	order = sorted(PIECES, key=lambda t: t[0])
	nrow = (len(order) + ncol - 1) // ncol
	fl = K.add_obj("SheetFloor", K.cbox(-cell * (nrow - 0.4), cell * 0.6, -cell * 0.6, cell * (ncol - 0.4), -0.2, 0, ch=0), [mats["M_Floor"]], stage)
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
		s = min(1.0, 30.0 / max(size.x, size.y, size.z, 0.01))
		ctr = (lo + hi) / 2
		px, py = -r * cell, c * cell
		m = Matrix.Translation((px, py, 0)) @ Matrix.Scale(s, 4) @ Matrix.Translation((-ctr.x, -ctr.y, -lo.z))
		e = bpy.data.objects.new("Sheet_" + name, None)
		e.instance_type = "COLLECTION"
		e.instance_collection = col
		e.matrix_world = m
		stage.objects.link(e)
		av = K.avatar((px + 6.0, py - min(size.y * s / 2 + 2.5, 17), 0), facing=90, col=stage, name="Proxy_" + name)
		av.scale = (s, s, s)
		label = "%s  %d tris  %.0fx%.0fx%.0f%s" % (name, tris[name], size.x, size.y, size.z, "" if abs(s - 1) < 1e-3 else "  (x%.2f, proxy too)" % s)
		K.text(label, 1.5, (px + 17.5, py, 0.05), stage, mats["SignText"], rot=(0, 0, 90), font=K.FONT_LABEL)
	sun = bpy.data.lights.new("SheetSun", "SUN")
	sun.energy = 3.4
	sun.angle = math.radians(3)
	so = bpy.data.objects.new("SheetSun", sun)
	stage.objects.link(so)
	so.rotation_euler = (math.radians(42), math.radians(-25), math.radians(200))
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	if bg:
		bg.inputs[0].default_value = (*K.lin(0x6A7282), 1)
		bg.inputs[1].default_value = 1.4
	cx, cy = -(nrow - 1) * cell / 2, (ncol - 1) * cell / 2
	cam = K.camera((cx + 300, cy + 70, 290), (cx, cy, 4), lens=50, name="SheetCam", col=stage)
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = cell * ncol * 1.05
	K.render_settings(samples=int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 24)
	try:
		sc.eevee.use_raytracing = False
	except AttributeError:
		pass
	K.bloom(strength=0.3)
	return stage


# ---------------------------------------------------------------- main

def main():
	mats = make_materials()
	kit = K.collection("Kit")
	p_walls(mats, kit)
	p_name_sign(mats, kit)
	p_coffers(mats, kit)
	p_pendant(mats, kit)
	p_platform_sign(mats, kit)
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
	p_props(mats, kit)
	tris, worst = {}, {}
	for name, col in PIECES:
		tris[name] = K.tri_count(col)
		for ob in col.all_objects:
			if ob.type == "MESH":
				ob.data.calc_loop_triangles()
				worst[ob.name] = len(ob.data.loop_triangles)
	print("METRO2_TRIS " + json.dumps(tris))
	print("METRO2_TOTAL %d" % sum(tris.values()))
	print("METRO2_MAX_OBJECT " + json.dumps(max(worst.items(), key=lambda kv: kv[1])))
	os.makedirs(ART_DIR, exist_ok=True)
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
	path = os.path.join(ART_DIR, "Kit_Metro2.blend")
	bpy.ops.wm.save_as_mainfile(filepath=path)
	print("METRO2 saved", path)
	if "--no-render" in ARGS:
		return
	os.makedirs(RENDER_DIR, exist_ok=True)
	sheet(mats, tris)
	K.render(os.path.join(RENDER_DIR, "kit-contact.jpg"), res=(2400, 1600))


main()
