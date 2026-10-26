# build_mod_vfx.py: reusable VFX meshes for the Mods (collection "ModVFX"), all unit-sized for code to scale.
#   blender --background --factory-startup --python tools/blender/build_mod_vfx.py -- [--render]
# Every mesh is one energy part (tinted per viewer) with UVs laid out for a scrolling texture: U runs once around
# (seam welded, so it tiles), V runs along the effect (inner -> outer edge, base -> top).
#   Shockwave_Energy  flat ring with a soft raised profile, radius 0.7 -> 1.0 (Packet blast, Launch Pad landing)
#   Dome_Energy       open hemisphere, radius 1 (Lag Field zone, Firewall build-up, Zero-G zone)
#   Sphere_Energy     full sphere, radius 1 (Freeze Frame bubble, explosion flash)
#   ScanRing_Energy   vertical band, radius 1, 0.25 tall, flaring out (Ping pulse)
# They render single-sided; set MeshPart.DoubleSided where both faces show. Origin at each mesh's centre, on the
# floor for the dome, ring and scan ring. Output: art-source/abilities/VFX/ModVFX.blend.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

MOD = "ModVFX"


def shockwave(u, v):
	a = -2 * math.pi * u  # clockwise so the faces point up
	r = 0.7 + 0.3 * v
	return (r * math.cos(a), r * math.sin(a), 0.06 * math.sin(math.pi * v))


def dome(u, v):
	a, p = 2 * math.pi * u, v * math.pi / 2
	return (math.cos(p) * math.cos(a), math.cos(p) * math.sin(a), math.sin(p))


def ball(u, v):
	a, p = 2 * math.pi * u, (v - 0.5) * math.pi
	return (math.cos(p) * math.cos(a), math.cos(p) * math.sin(a), math.sin(p))


def scan(u, v):
	a = 2 * math.pi * u
	r = 1 + 0.08 * v * v
	return (r * math.cos(a), r * math.sin(a), 0.25 * v)


def build():
	mats = begin(MOD)
	parts = [
		Part("Shockwave_Energy", uv=KEEP).add(grid(64, 4, shockwave)),
		Part("Dome_Energy", uv=KEEP).add(grid(32, 12, dome, pole_end=True)),
		Part("Sphere_Energy", uv=KEEP).add(grid(24, 16, ball, pole_start=True, pole_end=True)),
		Part("ScanRing_Energy", uv=KEEP).add(grid(64, 2, scan)),
	]
	return assemble(MOD, parts, mats, [], {"kind": "vfx"}, smooth_angle=80)


def main():
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	report = build()
	path = os.path.join(ROOT, "art-source", "abilities", "VFX", MOD + ".blend")
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=path)
	if "--render" in args:
		# Spread them out for the check render only (the saved file keeps every mesh at the origin).
		for name, x, y, z in (("Shockwave", -1.2, -3.6, 0.0), ("Dome", 0.0, -1.2, 0.0), ("Sphere", 0.0, 1.2, 1.0), ("ScanRing", -1.2, 3.6, 0.0)):
			bpy.data.objects[MOD + "_" + name + "_Energy"].location = (x, y, z)
		stage(look_dir=(1.0, 0.0, 0.45), hover=0.0, lens=40, zoom=0.6)
		render(os.path.join(RENDER_DIR, "vfx-meshes.jpg"))
	print("BUILD_MOD " + json.dumps({"mod": MOD, "blend": path, "tris": report}))


if __name__ == "__main__":
	main()
