# build_mod_recondart.py: the Recon sensor dart (vault/01 Design/Abilities/Recon.md, "Look"), fired from the Recon
# launcher, sticks where it lands, pulses twice.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_mod_recondart.py
# A slim tactical sensor dart, plain and realistic (Sova's recon bolt as the read, no bow): a hardened steel point,
# a gunmetal sensor head with a lit ring and three small lenses (Light_Energy: blinks in flight, flashes on each
# pulse, dies when the dart is shot), a carbon shaft and three swept polymer fins with a gunmetal nock at the back.
#
# Parts: Tip, Body (head, collars, shaft, nock; split on export into Body_Gunmetal / Body_Dark ...), Fins, Light_Energy.
# Locators: Handle (the tip: the pivot, the point that embeds in the surface; the builder adds RightGrip = Handle),
# Light (centre of the light ring: glow sprite, PointLight, pulse origin) and Tail (back of the nock: trail end).
# Origin at the TIP; the dart points along +X (Roblox -Z), so when stuck, the model's -Z goes into the surface.
# Same axes as every Mod: +X forward, +Z up, +Y left, 1 unit = 1 stud. 0.9 studs long.
#
# The launcher (build_mod_recon.py) imports dart_parts() to load the same dart in its muzzle, and its --render
# draws this dart too (vault/02 Art/References/abilities/recon/recon_model.jpg). Run this script first.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

MOD = "ReconDart"
LENGTH = 0.9
HEAD_R = 0.042  # widest radius of the sensor head
RING = (-0.178, -0.196)  # light ring (x from, x to)
SEG = 16

# Extra matte materials (appended after modkit's six, same rbx_* look properties). The launcher uses the same list.
POLY, GUNMETAL, STEEL, LENS, STENCIL = 6, 7, 8, 9, 10


def extra_materials():
	def mat(name, color, metallic, rough, rbx, coat=0.0):
		m = bpy.data.materials.new(name)
		m["rbx_material"] = rbx
		m["rbx_color"] = "%06X" % color
		m.use_nodes = True
		nt = m.node_tree
		nt.nodes.clear()
		out = nt.nodes.new("ShaderNodeOutputMaterial")
		b = nt.nodes.new("ShaderNodeBsdfPrincipled")
		nt.links.new(b.outputs["BSDF"], out.inputs["Surface"])
		b.inputs["Base Color"].default_value = (*lin(color), 1)
		b.inputs["Metallic"].default_value = metallic
		b.inputs["Roughness"].default_value = rough
		b.inputs["Coat Weight"].default_value = coat
		m.diffuse_color = (*lin(color), 1)
		return m

	return [
		mat("Polymer", 0x2B2D31, 0.0, 0.62, "SmoothPlastic"),  # matte dark polymer (frame, fins)
		mat("Gunmetal", 0x4A4F57, 0.72, 0.4, "Metal"),  # barrel, sensor head, hinge, nock
		mat("Steel", 0x9EA2A8, 0.88, 0.3, "Metal"),  # bare steel point, screws
		mat("Lens", 0x101C24, 0.0, 0.08, "SmoothPlastic", coat=1.0),  # unlit dark glass (the loaded dart's ring)
		mat("Stencil", 0x8C9096, 0.0, 0.7, "SmoothPlastic"),  # light grey stencil marking
	]


def dart_parts(light_mat=ENERGY, loaded=False):
	# The dart's geometry with the tip at the origin and the body along -X: {part name: bmesh}. light_mat = ENERGY
	# for the stuck dart; the launcher passes LENS and loaded=True: its loaded dart is one plain, non-energy part and
	# only the point and the sensor head stick out of the muzzle, so the shaft, fins and nock are left out.
	seg = 10 if loaded else SEG
	tip = lathe([(0.0, 0.0), (0.0035, -0.012), (0.011, -0.045), (0.017, -0.078), (0.019, -0.096), (0.019, -0.108), (0.0, -0.108)], seg, STEEL, "X")
	# Barbs: three small swept blades just behind the point (it bites into what it hits).
	for k in range(3):
		barb = prism([(-0.05, 0.012), (-0.098, 0.014), (-0.1, 0.028), (-0.088, 0.03)], "Y", -0.0025, 0.0025, STEEL)
		tip = merge(tip, place(barb, Matrix.Rotation(math.pi / 2 + k * 2 * math.pi / 3, 4, "X")))

	body = lathe([
		(0.0, -0.104), (0.021, -0.104), (0.026, -0.112), (0.035, -0.13), (0.041, -0.15), (HEAD_R, -0.165),
		(0.0375, RING[0] + 0.004), (0.0375, RING[1] - 0.004),  # groove under the light ring
		(HEAD_R, RING[1] - 0.012), (HEAD_R, -0.238), (0.038, -0.252), (0.028, -0.266), (0.019, -0.276), (0.0, -0.276),
	], seg, GUNMETAL, "X")
	light = band(seg, 0.035, HEAD_R + 0.0015, 0.0, RING[0] - RING[1], light_mat)
	light = place(light, axis_matrix("X", (RING[1], 0, 0)))
	for k in range(0 if loaded else 3):  # small sensor lenses on the front cone, between the barbs
		a = math.pi / 2 + math.pi / 3 + k * 2 * math.pi / 3
		lens = sphere(0.0075, 8, 4, light_mat, "Z", (0, 0, 0))
		m = Matrix.Rotation(a - math.pi / 2, 4, "X") @ Matrix.Translation((-0.138, 0, 0.034))
		light = merge(light, place(lens, m))
	if loaded:
		return {"Tip": tip, "Body": body, "Light_Energy": light}
	body = merge(body, lathe([(0.0, -0.27), (0.0135, -0.27), (0.0135, -0.80), (0.0, -0.80)], 10, DARK, "X"))  # carbon shaft
	body = merge(body, lathe([(0.0, -0.272), (0.018, -0.272), (0.018, -0.292), (0.0, -0.292)], 12, GUNMETAL, "X"))  # collar
	body = merge(body, lathe([  # fin hub and nock
		(0.0, -0.6), (0.0155, -0.6), (0.019, -0.615), (0.019, -0.85), (0.016, -0.862), (0.021, -0.876), (0.016, -LENGTH),
		(0.0, -LENGTH),
	], 10, GUNMETAL, "X"))
	for k in range(3):  # three screw heads on the head's rear band
		a = math.pi / 2 + math.pi / 3 + k * 2 * math.pi / 3
		s = lathe([(0.0, 0.0), (0.0055, 0.0), (0.0055, 0.004), (0.0, 0.004)], 6, STEEL, "Z")
		m = Matrix.Rotation(a - math.pi / 2, 4, "X") @ Matrix.Translation((-0.222, 0, HEAD_R - 0.0015))
		body = merge(body, place(s, m))

	fins = bmesh.new()
	for k in range(3):
		# Swept fin (x, distance from the axis): root on the hub, leading edge raked back, square trailing edge.
		f = bevel(prism([(-0.66, 0.017), (-0.865, 0.017), (-0.865, 0.052), (-0.835, 0.056), (-0.735, 0.03)], "Y", -0.003, 0.003, POLY), 0.0015, 1)
		fins = merge(fins, place(f, Matrix.Rotation(math.pi / 2 + k * 2 * math.pi / 3, 4, "X")))
	return {"Tip": tip, "Body": body, "Fins": fins, "Light_Energy": light}


def build():
	mats = begin(MOD) + extra_materials()
	geo = dart_parts()
	parts = []
	for name in ("Tip", "Body", "Fins", "Light_Energy"):
		p = Part(name)
		p.add(geo[name])
		parts.append(p)
	locators = [
		("Handle", (0, 0, 0), None),
		("Light", ((RING[0] + RING[1]) / 2, 0, 0), None),
		("Tail", (-LENGTH, 0, 0), None),
	]
	return assemble(MOD, parts, mats, locators, {"kind": "thrown", "size_studs": LENGTH})


if __name__ == "__main__":
	report = build()
	bpy.context.view_layer.update()
	objs = [o for o in bpy.data.collections[MOD].objects if o.type == "MESH"]
	lo, hi = bounds(objs)
	path = blend_path(MOD)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=path)
	print("BUILD_MOD " + json.dumps({"mod": MOD, "blend": path, "tris": report, "bounds": [list(lo), list(hi)]}))
