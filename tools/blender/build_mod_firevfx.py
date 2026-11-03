# build_mod_firevfx.py: the stylized fire kit (collection "FireVFX") for the Firewall wall and the Molly fire patch.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_mod_firevfx.py -- [--render]
# The look (vault/02 Art/Art Direction.md -> "Ability VFX: stylized, mesh-first"): Phoenix's Blaze / Brimstone's
# incendiary, a bit more grounded. Bold flame shapes from a few Neon meshes layered in three tones (yellow-white core
# low, orange body, red tips), animated in code (Util/FireKit, WallFx, MollyFx): flicker by scaling, leaning, swapping
# variants and turning the crowns. No textures: every part is one energy part; code sets its colour.
#
# Every mesh is a CLOSED volume (seen from every side without DoubleSided) with its origin at its anchor point: the
# base centre for flames, the floor centre for the wall and the patch, the middle for the spark.
#   Sheet_Energy    the wall curtain: 4.4 long (+X, a 4-stud piece plus overlap), ~1 thick (Y), 7.4..9.3 tall with a
#                   jagged flame top; the ends match so pieces join (and can be turned 180 degrees). Opaque orange:
#                   it is what blocks vision.
#   Core_Energy     the bright licks low on the wall, hugging both faces of the sheet (0.07 out), up to ~4.7 tall
#   Tongue1_Energy  flame tongues, unit height (1 stud), ~0.45 wide (X), ~0.22 deep (Y): a teardrop with an S-curve;
#   Tongue2_Energy    a tall one curling the other way; a forked one with a side lick. Code scales them (wall tops,
#   Tongue3_Energy    patch flames) and swaps between them
#   Pool_Energy     the patch's glowing floor: a flat disc, radius 0.95 with a wavy edge, 0.03 thick
#   Ring_Energy     the burning edge (the safe line): a flat band, radius 0.88..1.0, 0.06 tall
#   CrownA_Energy   rim flames: 11 lopsided flame tongues of mixed heights around a circle (r 0.975), 1 tall
#   CrownB_Energy   the inner rim: 14 shorter tongues (0.7 tall) at radius 0.92, another rhythm, leaning the other way
#   Spark_Energy    an ember shard: a long diamond, 1 tall, 0.24 wide (burst accents)
# Output: art-source/abilities/FireVFX/FireVFX.blend; --render writes vault/02 Art/References/mods/firevfx.jpg (a lit
# three-piece wall and a 5-stud fire patch, coloured as in game).

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math, random
from modkit import *  # noqa: F401,F403

MOD = "FireVFX"
TAU = 2 * math.pi


# ---------------------------------------------------------------- loft

def loft(rings, mat=ENERGY, closed=False):
	# Skins a list of rings (each a closed loop of points, or a single point = pole). closed: the last ring joins the
	# first (a band around a circle); otherwise ring loops with more than one point get an n-gon cap.
	bm = bmesh.new()
	vr = [[bm.verts.new(p) for p in ring] for ring in rings]
	n = max(len(r) for r in vr)
	pairs = list(zip(vr, vr[1:])) + ([(vr[-1], vr[0])] if closed else [])
	for a, b in pairs:
		for i in range(n):
			j = (i + 1) % n
			if len(a) == 1:
				bm.faces.new((a[0], b[i], b[j]))
			elif len(b) == 1:
				bm.faces.new((a[i], a[j], b[0]))
			else:
				bm.faces.new((a[i], a[j], b[j], b[i]))
	if not closed:
		for ring in (vr[0], vr[-1]):
			if len(ring) > 2:
				bm.faces.new(ring)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def peak(u, p=3.0):
	# Periodic (period 1) pointed bump: 1 at u = 0.5, 0 at whole numbers.
	return (0.5 + 0.5 * math.cos(TAU * (u - 0.5))) ** p


# ---------------------------------------------------------------- flame tongue

def tongue(height=1.0, width=0.45, depth=0.5, sway=0.12, curl=1.0, phase=0.0, lean=0.0, base=(0.0, 0.0, 0.0), nt=16, nr=12):
	# A flame tongue rising along Z: wide rounded base, belly at 25% height, a pointed concave taper to the tip, a
	# little wave in its width and an S-curve in its centreline (sway along X). depth: Y half-depth / X half-width.
	bx, by, bz = base
	rings = [[(bx, by, bz - 0.06 * height)]]  # rounded bottom pole, a little under the anchor
	for k in range(nt):
		t = (k / nt) ** 0.85
		w = (0.7 + 0.3 * math.sin(math.pi * t / 0.36)) if t < 0.18 else ((1 - t) / 0.82) ** 1.6
		w *= width / 2 * (1 + 0.1 * math.sin(TAU * 2.2 * t + phase))
		cx = bx + sway * math.sin(math.pi * curl * t + phase) * t ** 1.2 + lean * t * t
		z = bz + t * height
		rings.append([(cx + w * math.cos(TAU * i / nr), by + w * depth * math.sin(TAU * i / nr), z) for i in range(nr)])
	tip = bx + sway * math.sin(math.pi * curl + phase) + lean
	rings.append([(tip, by, bz + height)])
	return loft(rings)


# ---------------------------------------------------------------- wall pieces

SHEET_LEN = 4.4


def sheet_top(s):
	return 6.9 + 2.0 * peak(2 * s + 0.1, 2.2) + 0.8 * peak(3 * s + 0.35, 2.5) + 0.3 * peak(5 * s + 0.6, 2)


def sheet_half(z, s):
	# Half thickness: full at the floor, thin at the top, a slight vertical ripple (zero at the ends so pieces meet).
	return 0.5 * (1 - 0.72 * (max(z, 0) / 9.6) ** 2) + 0.045 * math.sin(TAU * 3 * s)


def core_top(s):
	return 1.5 + 3.4 * peak(2 * s + 0.62, 1.7) ** 1.4 + 1.5 * peak(3 * s + 0.1, 2.4)


def curtain(top, half, ns=24, nz=8, lean=0.25):
	# A tall thin closed slab along X (-SHEET_LEN/2 .. +SHEET_LEN/2): for each station along X a cross-section loop up
	# the front face (+Y) and down the back. The flame tips lean along +X with height.
	rings = []
	for i in range(ns + 1):
		s = i / ns
		x = (s - 0.5) * SHEET_LEN
		h = top(s)
		front, back = [], []
		for j in range(nz + 1):
			f = j / nz
			z = -0.1 + (h + 0.1) * f
			hw = half(z, s)
			dx = lean * f * f * (h / 9.0)
			front.append((x + dx, hw, z))
			back.append((x + dx, -hw, z))
		rings.append(front + back[::-1])
	return loft(rings)


# ---------------------------------------------------------------- patch pieces

def pool(n=56, r=0.95, lobes=13, top=0.03):
	edge = [r * (1 + 0.035 * math.sin(lobes * TAU * i / n) + 0.02 * math.sin(5 * TAU * i / n)) for i in range(n)]
	rings = [[(0, 0, top)]]
	for f in (0.4, 0.75, 1.0):
		rings.append([(edge[i] * f * math.cos(TAU * i / n), edge[i] * f * math.sin(TAU * i / n), top) for i in range(n)])
	rings.append([(edge[i] * math.cos(TAU * i / n), edge[i] * math.sin(TAU * i / n), 0.0) for i in range(n)])
	rings.append([(0, 0, 0.0)])
	return loft(rings)


def crown(count, height, radius=1.0, thick=0.06, base=0.15, cols=8, seed=1, twist=0.12):
	# A band of `count` flame tongues standing around a circle. Each column is a 4-point section (outer and inner
	# faces, thin at the top); tongue heights and widths vary (seeded), each tongue is lopsided (one side curls) and
	# the tips lean around the circle.
	rnd = random.Random(seed)
	amp = [rnd.uniform(0.35, 1.0) for _ in range(count)]
	skew = [rnd.uniform(1.25, 1.7) for _ in range(count)]
	n = count * cols
	rings = []
	for i in range(n):
		u = i / n
		k = int(u * count)
		frac = (u * count) % 1.0
		h = height * (base + (1 - base) * amp[k] * peak(frac ** skew[k], 1.8))
		a0 = TAU * u
		a1 = a0 + twist * (h / height)  # the tip leans along the ring
		ro, ri = radius, radius - thick
		rings.append([
			(ro * math.cos(a0), ro * math.sin(a0), -0.05),
			(ro * math.cos(a1), ro * math.sin(a1), h),
			((ri + thick * 0.7) * math.cos(a1), (ri + thick * 0.7) * math.sin(a1), h),
			(ri * math.cos(a0), ri * math.sin(a0), -0.05),
		])
	return loft(rings, closed=True)


def spark(h=1.0, w=0.24):
	bm = bmesh.new()
	top, bot = bm.verts.new((0, 0, h / 2)), bm.verts.new((0, 0, -h / 2))
	mid = [bm.verts.new((w / 2 * math.cos(TAU * i / 4), w / 2 * math.sin(TAU * i / 4), h * 0.12)) for i in range(4)]
	for i in range(4):
		j = (i + 1) % 4
		bm.faces.new((mid[i], mid[j], top))
		bm.faces.new((mid[j], mid[i], bot))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = ENERGY
	return bm


def forked():
	bm = tongue(height=1.0, width=0.44, sway=0.06, curl=1.2, phase=0.4)
	# The side lick: branches off the belly, leans out and up to 60%.
	merge(bm, tongue(height=0.58, width=0.22, sway=0.04, curl=1.0, phase=2.0, lean=0.16, base=(0.1, 0.0, 0.2), nt=10, nr=10))
	return bm


def build():
	mats = begin(MOD)
	parts = [
		Part("Sheet_Energy", uv=KEEP).add(curtain(sheet_top, sheet_half)),
		Part("Core_Energy", uv=KEEP).add(curtain(core_top, lambda z, s: sheet_half(z, s) + 0.07, nz=6, lean=0.12)),
		Part("Tongue1_Energy", uv=KEEP).add(tongue(sway=0.08, curl=1.0, phase=0.0)),
		Part("Tongue2_Energy", uv=KEEP).add(tongue(width=0.38, sway=-0.13, curl=1.6, phase=0.3, lean=-0.04)),
		Part("Tongue3_Energy", uv=KEEP).add(forked()),
		Part("Pool_Energy", uv=KEEP).add(pool()),
		Part("Ring_Energy", uv=KEEP).add(band(64, 0.88, 1.0, 0.0, 0.06, mat=ENERGY)),
		Part("CrownA_Energy", uv=KEEP).add(crown(11, 1.0, radius=0.975, seed=3)),
		Part("CrownB_Energy", uv=KEEP).add(crown(14, 0.7, radius=0.92, thick=0.05, base=0.2, cols=7, seed=7, twist=-0.14)),
		Part("Spark_Energy", uv=KEEP).add(spark()),
	]
	return assemble(MOD, parts, mats, [], {"kind": "vfx"}, smooth_angle=60)


# ---------------------------------------------------------------- check render

CORE = 0xFFD45A
BODY = 0xFF7A1E
SHEET = 0xE8501A
TIP = 0xD22E12
POOL = 0xFF5A1A


def glow(name, color, strength):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	em = nt.nodes.new("ShaderNodeEmission")
	em.inputs["Color"].default_value = (*lin(color), 1)
	em.inputs["Strength"].default_value = strength
	nt.links.new(em.outputs[0], out.inputs["Surface"])
	return m


def preview():
	# Coloured copies in a "Look" collection (the kit meshes stay at the origin, hidden from the render), laid out the
	# way WallFx / MollyFx place them.
	look = bpy.data.collections.new("Look")
	bpy.context.scene.collection.children.link(look)
	m = {
		"core": glow("LookCore", CORE, 2.2),
		"body": glow("LookBody", BODY, 2.4),
		"sheet": glow("LookSheet", SHEET, 2.0),
		"tip": glow("LookTip", TIP, 1.8),
		"pool": glow("LookPool", POOL, 1.2),
	}
	src = {o.name[len(MOD) + 1:]: o for o in bpy.data.collections[MOD].objects}
	for o in src.values():
		o.hide_render = True

	def put(name, mat, matrix):
		me = src[name].data.copy()
		me.materials.clear()
		me.materials.append(mat)
		o = bpy.data.objects.new("Look_" + name, me)
		look.objects.link(o)
		o.matrix_world = matrix

	S = Matrix.Diagonal
	rnd = random.Random(5)
	# The wall: three pieces along Blender Y (faces the +X camera), a slight curve, the middle one turned 180 degrees.
	for i, (y, yaw) in enumerate(((-4.0, 0.06), (0.0, math.pi), (4.0, -0.06))):
		base = Matrix.Translation((0, y - 6, 0)) @ Matrix.Rotation(math.pi / 2 + yaw, 4, "Z")
		put("Sheet_Energy", m["sheet"], base)
		put("Core_Energy", m["core"], base)
		for slot, (x, z, h, kind) in enumerate(((-1.2, 7.2, 2.8, "body"), (0.2, 7.0, 3.6, "tip"), (1.4, 7.3, 2.5, "body"))):
			name = "Tongue%d_Energy" % rnd.randint(1, 3)
			w = 2.4 if kind == "body" else 1.9
			mx = base @ Matrix.Translation((x, 0, z)) @ Matrix.Rotation(rnd.uniform(-0.12, 0.12), 4, "Y") @ S((w, 1.8, h, 1))
			put(name, m[kind], mx)
	# The fire patch: radius 5 at (+2, +7).
	r, c = 5.0, Vector((2.0, 7.0, 0.0))
	T = Matrix.Translation
	put("Pool_Energy", m["pool"], T(c + Vector((0, 0, 0.02))) @ S((r, r, 1, 1)))
	put("Ring_Energy", m["core"], T(c + Vector((0, 0, 0.04))) @ S((r, r, 1, 1)))
	put("CrownA_Energy", m["body"], T(c) @ S((r, r, 3.0, 1)))
	put("CrownB_Energy", m["core"], T(c) @ Matrix.Rotation(0.4, 4, "Z") @ S((r, r, 2.2, 1)))
	golden = math.pi * (3 - math.sqrt(5))
	for n in range(7):
		rr = r * 0.72 * math.sqrt((n + 0.5) / 7)
		a = n * golden
		h = rnd.uniform(1.8, 2.6)
		mx = T(c + Vector((math.cos(a) * rr, math.sin(a) * rr, 0))) @ Matrix.Rotation(rnd.uniform(-0.4, 0.4), 4, "Z") @ S((2.1, 2.1, h, 1))
		put("Tongue%d_Energy" % (n % 3 + 1), m["body"] if n % 3 else m["core"], mx)
	for n in range(4):
		a = n * 1.7
		put("Spark_Energy", m["core"], T(c + Vector((math.cos(a) * 2.5, math.sin(a) * 2.5, 3.0 + n * 0.7))) @ Matrix.Rotation(0.5, 4, "X") @ S((0.35, 0.35, 0.35, 1)))


def main():
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	report = build()
	path = blend_path(MOD)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=path)
	big = {k: v for k, v in report.items() if not k.startswith("_") and v > 1000}
	if big:
		raise ValueError("over the 1K tris budget: %s" % big)
	if "--render" in args:
		preview()
		stage(look_dir=(1.0, 0.18, 0.28), hover=0.0, lens=40, zoom=0.62)
		render(os.path.join(RENDER_DIR, "firevfx.jpg"))
	print("BUILD_MOD " + json.dumps({"mod": MOD, "blend": path, "tris": report}))


if __name__ == "__main__":
	main()
