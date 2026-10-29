# build_mod_healorb.py: the Heal Orb (vault/01 Design/Abilities/Heal Orb.md), a glowing orb that hovers above the palm.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_mod_healorb.py -- [--render]
# The most "mystical" ability, kept clean: a soft green-teal orb of swirling light (Sage's healing orb as the
# reference), clearly different from Frost's icy blue. Nested shells around one centre:
#   Core   a small bright inner sphere (Neon, fixed #5CFFC8: NOT an *_Energy part, so it stays green-teal for every
#          viewer instead of taking the team colour).
#   Shell  a larger translucent sphere with clean UVs (U once around the equator, V from the bottom pole to the top),
#          for the scrolling swirl texture (art-source/vfx/abilities/healorb/healorb_swirl.png). Roblox look:
#          ForceField material in #5CFFC8, which shows the MeshPart's TextureID as a glowing, self-animating pattern;
#          spinning the Shell in code also "scrolls" it (U runs around the spin axis, model up).
#   Ring1, Ring2  two thin orbiting bands of light, tilted on different axes, each broken into tapered arcs so a spin
#          about its own axis is visible (Neon, fixed pale mint #8CFFDA). Code spins them about RING1_AXIS / RING2_AXIS
#          below (also written to the collection props, in Roblox model space, as ring1_axis / ring2_axis).
# Locators: Center (the orb centre: effects, the heal ribbon's start) and Handle (the same point; the builder adds
# RightGrip = Handle). Pivot = the orb centre. HoldOffset lives in tools/studio/make_ability_build_data.py (EXTRA), so
# the orb floats a little above and in front of the open palm.
# Same axes as every Mod: +X forward, +Z up, +Y left, 1 unit = 1 stud.
#
# --render writes vault/02 Art/References/abilities/healorb/healorb_model.jpg: a close-up from three angles (with the
# swirl texture on the Shell if it has been rendered: tools/vfx/make_healorb_vfx.py) plus a true-scale lineup next to
# the Frost canister (appended from art-source/abilities/Frost/Frost.blend, never saved), on dark with bloom.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

MOD = "HealOrb"
CORE_R = 0.068  # 0.136 across
SHELL_R = 0.15  # 0.3 across
RING1_R, RING2_R = 0.214, 0.226  # outer bands: ~0.45 studs across overall
TEAL = 0x5CFFC8
MINT = 0x8CFFDA

# Ring tilts (Blender space). Ring1: tipped 62 degrees about X, then turned 25 degrees about Z. Ring2: tipped -58 degrees
# about Y, then turned -40 degrees about Z. Their normals are the spin axes.
RING1_TILT = Matrix.Rotation(math.radians(25), 4, "Z") @ Matrix.Rotation(math.radians(62), 4, "X")
RING2_TILT = Matrix.Rotation(math.radians(-40), 4, "Z") @ Matrix.Rotation(math.radians(-58), 4, "Y")

HEALCORE, HEALSHELL, HEALRING = 6, 7, 8
SWIRL_PNG = os.path.join(ROOT, "art-source", "vfx", "abilities", "healorb", "healorb_swirl.png")


def roblox_axis(m):
	# Blender (x, y, z) -> Roblox model space (-y, z, -x), as the AbilityBuilder maps locators.
	n = (m.to_3x3() @ Vector((0, 0, 1))).normalized()
	return (round(-n.y, 4), round(n.z, 4), round(-n.x, 4))


def extra_materials():
	def new(name, rbx, color):
		m = bpy.data.materials.new(name)
		m["rbx_material"] = rbx
		m["rbx_color"] = "%06X" % color
		m.use_nodes = True
		m.node_tree.nodes.clear()
		m.diffuse_color = (*lin(color), 1)
		return m, m.node_tree

	def emission(nt, color, strength):
		e = nt.nodes.new("ShaderNodeEmission")
		e.inputs["Color"].default_value = (*color, 1) if len(color) == 3 else color
		e.inputs["Strength"].default_value = strength
		return e

	# Core: teal emission that goes whiter toward the middle of the disc (facing the camera), like a hot centre.
	core, nt = new("HealCore", "Neon", TEAL)
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	lw = nt.nodes.new("ShaderNodeLayerWeight")
	lw.inputs["Blend"].default_value = 0.5
	pw = nt.nodes.new("ShaderNodeMath")
	pw.operation = "POWER"
	pw.inputs[1].default_value = 3.0
	inv = nt.nodes.new("ShaderNodeMath")
	inv.operation = "SUBTRACT"
	inv.inputs[0].default_value = 1.0
	nt.links.new(lw.outputs["Facing"], inv.inputs[1])
	nt.links.new(inv.outputs[0], pw.inputs[0])
	mix = nt.nodes.new("ShaderNodeMixShader")
	nt.links.new(pw.outputs[0], mix.inputs[0])
	nt.links.new(emission(nt, lin(TEAL), 2.2).outputs[0], mix.inputs[1])
	nt.links.new(emission(nt, lin(0xD8FFF0), 3.2).outputs[0], mix.inputs[2])
	nt.links.new(mix.outputs[0], out.inputs["Surface"])

	# Shell: translucent teal glow with a swirl pattern (procedural here; the render swaps in the real texture) and a
	# brighter fresnel rim. The node named "Pattern" is what the pattern feeds.
	shell, nt = new("HealShell", "ForceField", TEAL)
	shell.surface_render_method = "BLENDED"
	shell.use_backface_culling = False
	L = nt.links
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	tc = nt.nodes.new("ShaderNodeTexCoord")
	noise = nt.nodes.new("ShaderNodeTexNoise")
	noise.inputs["Scale"].default_value = 6.0
	noise.inputs["Detail"].default_value = 4.0
	noise.inputs["Distortion"].default_value = 3.0
	L.new(tc.outputs["UV"], noise.inputs["Vector"])
	ramp = nt.nodes.new("ShaderNodeMapRange")
	ramp.inputs["From Min"].default_value = 0.5
	ramp.inputs["From Max"].default_value = 0.75
	L.new(noise.outputs["Fac"], ramp.inputs["Value"])
	pat = nt.nodes.new("ShaderNodeMath")
	pat.name = "Pattern"
	pat.operation = "MULTIPLY"
	pat.inputs[1].default_value = 1.0
	L.new(ramp.outputs[0], pat.inputs[0])
	lw = nt.nodes.new("ShaderNodeLayerWeight")
	lw.inputs["Blend"].default_value = 0.35
	fres = nt.nodes.new("ShaderNodeMath")
	fres.operation = "POWER"
	fres.inputs[1].default_value = 1.6
	L.new(lw.outputs["Facing"], fres.inputs[0])

	def lin_comb(base, terms):
		acc = None
		for sock, k in terms:
			mul = nt.nodes.new("ShaderNodeMath")
			mul.operation = "MULTIPLY"
			mul.inputs[1].default_value = k
			L.new(sock, mul.inputs[0])
			add = nt.nodes.new("ShaderNodeMath")
			add.operation = "ADD"
			add.use_clamp = False
			if acc is None:
				add.inputs[0].default_value = base
			else:
				L.new(acc, add.inputs[0])
			L.new(mul.outputs[0], add.inputs[1])
			acc = add.outputs[0]
		return acc

	strength = lin_comb(0.2, [(pat.outputs[0], 3.2), (fres.outputs[0], 1.6)])
	alpha = lin_comb(0.03, [(pat.outputs[0], 0.55), (fres.outputs[0], 0.5)])
	em = emission(nt, lin(TEAL), 1.0)
	L.new(strength, em.inputs["Strength"])
	tr = nt.nodes.new("ShaderNodeBsdfTransparent")
	clamp = nt.nodes.new("ShaderNodeMath")
	clamp.operation = "MINIMUM"
	clamp.inputs[1].default_value = 1.0
	L.new(alpha, clamp.inputs[0])
	mix = nt.nodes.new("ShaderNodeMixShader")
	L.new(clamp.outputs[0], mix.inputs[0])
	L.new(tr.outputs[0], mix.inputs[1])
	L.new(em.outputs[0], mix.inputs[2])
	L.new(mix.outputs[0], out.inputs["Surface"])

	ring, nt = new("HealRing", "Neon", MINT)
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	nt.links.new(emission(nt, lin(MINT), 3.0).outputs[0], out.inputs["Surface"])
	return [core, shell, ring]


def arc_band(R, half_w, th, a0, a1, segs, mat):
	# A thin band of light along a circle of radius R (in the XY plane) from angle a0 to a1: a flat ribbon facing
	# outward (width 2*half_w across Z, radial thickness th), tapering to points at both ends.
	bm = bmesh.new()
	rings = []
	for i in range(segs + 1):
		t = i / segs
		a = a0 + (a1 - a0) * t
		taper = max(0.12, math.sin(math.pi * t) ** 0.6)
		hw = half_w * taper
		ht = th / 2 * (0.4 + 0.6 * taper)
		c, s = math.cos(a), math.sin(a)
		rings.append([bm.verts.new(((R + dr) * c, (R + dr) * s, dz)) for dr, dz in ((ht, hw), (ht, -hw), (-ht, -hw), (-ht, hw))])
	for ra, rb in zip(rings, rings[1:]):
		for k in range(4):
			bm.faces.new((ra[k], ra[(k + 1) % 4], rb[(k + 1) % 4], rb[k]))
	bm.faces.new(rings[0])
	bm.faces.new(rings[-1][::-1])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def build():
	mats = begin(MOD) + extra_materials()

	core = Part("Core")
	core.add(sphere(CORE_R, 14, 8, HEALCORE))

	# Shell: a UV sphere built as a grid (U around, V bottom to top), so a swirl texture wraps it cleanly.
	shell = Part("Shell", uv=KEEP)

	def on_sphere(u, v):
		th, ph = 2 * math.pi * u, math.pi * v
		return (SHELL_R * math.sin(ph) * math.cos(th), SHELL_R * math.sin(ph) * math.sin(th), -SHELL_R * math.cos(ph))

	shell.add(grid(24, 12, on_sphere, HEALSHELL, pole_start=True, pole_end=True))

	ring1 = Part("Ring1")
	for a0 in (0.0, math.pi):
		ring1.add(place(arc_band(RING1_R, 0.011, 0.007, a0, a0 + math.radians(160), 16, HEALRING), RING1_TILT))

	ring2 = Part("Ring2")
	for k in range(3):
		a0 = k * 2 * math.pi / 3 + math.radians(20)
		ring2.add(place(arc_band(RING2_R, 0.008, 0.006, a0, a0 + math.radians(100), 11, HEALRING), RING2_TILT))

	parts = [core, shell, ring1, ring2]
	locators = [
		("Center", (0, 0, 0), None),
		("Handle", (0, 0, 0), None),
	]
	props = {
		"kind": "handheld",
		"size_studs": round(2 * (RING2_R + 0.003), 3),
		"ring1_axis": "%g,%g,%g" % roblox_axis(RING1_TILT),
		"ring2_axis": "%g,%g,%g" % roblox_axis(RING2_TILT),
	}
	return assemble(MOD, parts, mats, locators, props)


# ---------------------------------------------------------------- check render

OUT_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "abilities", "healorb")


def instance(col, pos, rz=0.0, rx=0.0):
	e = bpy.data.objects.new("Inst_" + col.name, None)
	e.instance_type = "COLLECTION"
	e.instance_collection = col
	bpy.context.scene.collection.objects.link(e)
	e.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(math.radians(rz), 4, "Z") @ Matrix.Rotation(math.radians(rx), 4, "X")
	return e


def glow_light(pos, energy=2.5):
	# A soft teal point light in the orb (render only), so the orb lights the floor like the in-game PointLight.
	ld = bpy.data.lights.new("_orb_light", "POINT")
	ld.energy = energy
	ld.color = lin(TEAL)
	ld.shadow_soft_size = 0.1
	o = bpy.data.objects.new("_orb_light", ld)
	o.location = pos
	bpy.context.scene.collection.objects.link(o)
	return o


def use_swirl_texture():
	# Swap the Shell's procedural preview pattern for the real swirl texture (alpha channel = the pattern).
	if not os.path.exists(SWIRL_PNG):
		print("HEALORB_RENDER: no swirl texture yet, using the procedural preview pattern")
		return
	m = bpy.data.materials["HealShell"]
	nt = m.node_tree
	img = bpy.data.images.load(SWIRL_PNG)
	img.alpha_mode = "STRAIGHT"
	tex = nt.nodes.new("ShaderNodeTexImage")
	tex.image = img
	tc = next(n for n in nt.nodes if n.type == "TEX_COORD")
	mp = nt.nodes.new("ShaderNodeMapping")
	mp.inputs["Scale"].default_value = (2.0, 1.0, 1.0)  # twice around, so the streams look finer on the small orb
	nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
	nt.links.new(mp.outputs[0], tex.inputs["Vector"])
	nt.links.new(tex.outputs["Alpha"], nt.nodes["Pattern"].inputs[0])


def dim_stage(k=0.35):
	# The orb is its own light: turn the studio lights down so the floor stays dark and the glow reads.
	for o in bpy.data.collections["Preview"].objects:
		if o.type == "LIGHT":
			o.data.energy *= k


def render_sheet():
	import numpy as np

	sc = bpy.context.scene
	orb = bpy.data.collections[MOD]
	sc.view_layers[0].layer_collection.children[MOD].exclude = True
	use_swirl_texture()
	tmp = os.path.join(OUT_DIR, "_tmp")
	os.makedirs(tmp, exist_ok=True)

	def proxy(name, x, y, z0, z1):
		me = bpy.data.meshes.new(name)
		bm = box(-x, x, -y, y, z0, z1, SHELL)
		bm.to_mesh(me)
		bm.free()
		p = bpy.data.objects.new(name, me)
		sc.collection.objects.link(p)
		return p

	# Row 1: three angles (front, turned, from above), hovering over the dark floor.
	H = 0.25
	insts = [instance(orb, (0, -0.56, H), 0), instance(orb, (0, 0.0, H), 70), instance(orb, (0, 0.56, H), 150, 55)]
	lights = [glow_light((0, y, H)) for y in (-0.56, 0.0, 0.56)]
	px = proxy("_proxy", 0.25, 0.82, 0.0, H + 0.25)
	stage(look_dir=(1.0, 0.06, 0.34), hover=0.0, lens=60, zoom=0.66)
	dim_stage()
	px.hide_render = True
	a = render(os.path.join(tmp, "angles.jpg"), (1800, 900))
	for o in insts + lights + [px]:
		bpy.data.objects.remove(o)

	# Row 2: true scale next to the Frost canister (0.55 studs tall; both pivots at their centre).
	path = blend_path("Frost")
	with bpy.data.libraries.load(path, link=False) as (src, dst):
		dst.collections = ["Frost"]
	frost = dst.collections[0]
	sc.collection.children.link(frost)
	sc.view_layers[0].layer_collection.children["Frost"].exclude = True
	insts = [instance(orb, (0, -0.2, 0.3), 30), instance(frost, (0, 0.2, 0.275), 20)]
	lights = [glow_light((0, -0.2, 0.3), 1.5)]
	px = proxy("_proxy2", 0.2, 0.45, 0.0, 0.56)
	stage(look_dir=(1.0, 0.0, 0.28), hover=0.0, lens=120, zoom=0.82)
	dim_stage(0.6)
	px.hide_render = True
	b = render(os.path.join(tmp, "scale.jpg"), (1800, 700))

	imgs = []
	for p in (a, b):
		im = bpy.data.images.load(p)
		imgs.append(np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4))
	stacked = np.concatenate([imgs[1], imgs[0]], axis=0)
	out = bpy.data.images.new("healorb_model", stacked.shape[1], stacked.shape[0], alpha=False)
	out.pixels.foreach_set(stacked.ravel())
	out.filepath_raw = os.path.join(OUT_DIR, "healorb_model.jpg")
	out.file_format = "JPEG"
	sc.render.image_settings.quality = 92
	out.save()
	for p in (a, b):
		os.remove(p)
	os.rmdir(tmp)
	print("HEALORB_RENDER", out.filepath_raw)


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	report = build()
	bpy.context.view_layer.update()
	objs = [o for o in bpy.data.collections[MOD].objects if o.type == "MESH"]
	lo, hi = bounds(objs)
	path = blend_path(MOD)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=path)
	col = bpy.data.collections[MOD]
	print("BUILD_MOD " + json.dumps({"mod": MOD, "blend": path, "tris": report, "bounds": [list(lo), list(hi)], "ring1_axis": col["ring1_axis"], "ring2_axis": col["ring2_axis"]}))
	if "--render" in args:
		render_sheet()
