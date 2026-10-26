# render_mods.py: lineup check render of every Mod prop, in the ally and the enemy tint.
#   blender --background --factory-startup --python tools/blender/render_mods.py
# Appends each Mod collection from art-source/abilities/<Mod>/<Mod>.blend (build them first with
# tools/blender/build_mod_<name>.py), lays them out and writes vault/02 Art/References/mods/lineup.jpg and
# lineup-enemy.jpg. Placed props are at true scale; the handheld and thrown ones are scaled up 3x so they read.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

# (Mod, label, position, z rotation in degrees, scale)
LAYOUT = [
	("Firewall", "FIREWALL", (-2.2, -7.2, 0), -12, 1),
	("LaunchPad", "LAUNCH PAD", (0.6, -1.2, 0), 0, 1),
	("Packet", "PACKET  x3", (2.4, 2.5, 0.9), 25, 3),
	("PatchUp", "PATCH UP  x3", (0.6, 5.3, 1.7), -90, 3),
	("LagField", "LAG FIELD  x3", (2.6, 8.0, 1.0), 0, 3),
]


def append(mod):
	path = blend_path(mod)
	with bpy.data.libraries.load(path, link=False) as (src, dst):
		dst.collections = [mod]
	col = dst.collections[0]
	bpy.context.scene.collection.children.link(col)
	return col


def label(text, pos):
	cu = bpy.data.curves.new("Label_" + text, "FONT")
	cu.body = text
	cu.size = 0.42
	cu.align_x = "CENTER"
	cu.align_y = "CENTER"
	m = bpy.data.materials.get("Label") or bpy.data.materials.new("Label")
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	b.inputs["Base Color"].default_value = (0.25, 0.27, 0.3, 1)
	b.inputs["Roughness"].default_value = 0.6
	cu.materials.append(m)
	o = bpy.data.objects.new("Label_" + text, cu)
	bpy.context.scene.collection.objects.link(o)
	o.location = pos
	o.rotation_euler = (0, 0, math.pi / 2)  # reads left to right from the +X camera


def main():
	bpy.ops.wm.read_homefile(use_empty=True)
	for mod, text, pos, rz, scale in LAYOUT:
		col = append(mod)
		m = Matrix.Translation(pos) @ Matrix.Rotation(math.radians(rz), 4, "Z") @ Matrix.Scale(scale, 4)
		for o in col.objects:
			if o.parent is None:
				o.matrix_world = m @ o.matrix_world
		label(text, (pos[0] + (1.6 if mod == "Firewall" else 2.9 if scale == 1 else 1.5), pos[1], 0.01))
	stage(look_dir=(1.0, 0.12, 0.4), hover=0.0, lens=40, zoom=0.68)
	out = []
	for name, team in (("lineup", ALLY), ("lineup-enemy", ENEMY)):
		set_team(team)
		out.append(render(os.path.join(RENDER_DIR, name + ".jpg"), (1920, 1080)))
	print("RENDER_MODS", out)


if __name__ == "__main__":
	main()
