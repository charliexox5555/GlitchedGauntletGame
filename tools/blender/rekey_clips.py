# rekey_clips.py: re-key one gun's clips and refresh only the clips in its export. No mesh, texture or FBX work.
#
#   blender --background art-source/weapons/<Id>.blend --python tools/blender/rekey_clips.py -- <Id>
#   python tools/make_weapon_anims.py <Id>
#
# Runs tools/blender/anim_<id>.py (its animate()), samples every NLA strip the same way export_weapons.py does
# (sample_animations), writes them into art-source/weapons/Exports/<Id>.json "animations" (everything else in that
# file is left as it is), resets the rig to rest and saves the .blend so it matches the script.
# The FBX in Exports/ still carries the old baked takes; nothing in the game reads them (GunAnimator plays the
# generated src/shared/WeaponAnimations/<Id>.luau).
# 2026-11-20 animation pass (vault/05 Production/Overnight 2026-11-20 Animation Pass.md).

import bpy, json, os, sys
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)


def load(path, name):
	g = {"__name__": name, "__file__": path}
	exec(compile(open(path).read(), path, "exec"), g)
	return g


def main(gun):
	anim = load(os.path.join(HERE, "anim_%s.py" % gun.lower()), "anim")
	anim["animate"]()
	rig = bpy.data.objects[gun + "_Rig"]
	export = load(os.path.join(HERE, "export_weapons.py"), "export")
	clips = export["sample_animations"](rig)
	path = os.path.join(ROOT, "art-source", "weapons", "Exports", gun + ".json")
	with open(path) as f:
		data = json.load(f)
	data["animations"] = dict(sorted(clips.items()))  # name order, as export_weapons.py left it
	with open(path, "w") as f:
		json.dump(data, f, indent=1)
	for pb in rig.pose.bones:
		pb.matrix_basis = Matrix.Identity(4)
	bpy.ops.wm.save_mainfile()
	return {name: (c["start"], c["end"], sorted(c["bones"])) for name, c in clips.items()}


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	print("REKEY", json.dumps(main(args[0])))
