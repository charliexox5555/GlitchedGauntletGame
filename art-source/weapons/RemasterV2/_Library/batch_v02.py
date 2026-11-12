# batch_v02.py: rebuild + finalise one RemasterV2 weapon at v02 (Blender MCP only): runs its builder, copies the
# original clips (unless the gun has its own anim_<gun>_v2.py), then finalize() with the gun's game view.
#   ns = {}; exec(compile(open(p).read(), p, "exec"), ns); ns["run"]("Phantom")
# Views: Weapons.luau viewmodelOffset / viewmodelScale, AimPoint (x, z) from the builder, adsDistance, adsFov.

import bpy, os

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"

VIEWS = {
	"Phantom": {"vm_offset": (0.52, -0.277, -0.38), "aim": (0.1536, 0.0, 0.5784), "ads_distance": 0.42, "ads_fov": 68},
	"Bulldog": {"vm_offset": (0.44, -0.246, -0.85), "aim": (-0.1976, 0.0, 0.5838), "ads_distance": 0.38, "ads_fov": 68},
	"Guardian": {"vm_offset": (0.52, -0.3, -0.38), "aim": (0.1376, 0.0, 0.4984), "ads_distance": 0.33, "ads_fov": 58},
	"Spectre": {"vm_offset": (0.46, -0.325, -0.92), "aim": (-0.0532, 0.0, 0.5236), "ads_distance": 0.37, "ads_fov": 72},
	"Stinger": {"vm_offset": (0.46, -0.324, -0.92), "aim": (-0.408, 0.0, 0.4778), "ads_distance": 0.3, "ads_fov": 72},
	"Ares": {"vm_offset": (0.52, -0.291, -0.43), "aim": (0.1088, 0.0, 0.6392), "ads_distance": 0.4, "ads_fov": 70},
	"Odin": {"vm_offset": (0.52, -0.3, -0.38), "aim": (0.021, 0.0, 0.6503), "ads_distance": 0.39, "ads_fov": 70},
	"Marshal": {"vm_offset": (0.52, -0.3, -0.47)},
	"Operator": {"vm_offset": (0.52, -0.3, -0.47)},
	"Outlaw": {"vm_offset": (0.52, -0.3, -0.47)},
	"Judge": {"vm_offset": (0.36, -0.42, -0.95)},
	"Bucky": {"vm_offset": (0.48, -0.4, -0.68)},
	"Shorty": {"vm_offset": (0.42, -0.76, -1.3), "vm_scale": 1.1},
	"Classic": {"vm_offset": (0.42, -0.76, -1.3), "vm_scale": 1.1},
	"Ghost": {"vm_offset": (0.42, -0.76, -1.3), "vm_scale": 1.1},
	"Sheriff": {"vm_offset": (0.42, -0.76, -1.3), "vm_scale": 1.1},
	"Vandal": {"vm_offset": (0.52, -0.3, -0.38), "aim": (0.0775, 0.0, 0.5598), "ads_distance": 0.36, "ads_fov": 68},
}
BASE = ["Cam_Hero", "Cam_HeroR", "Cam_Side", "Cam_SideR", "Cam_Top", "Cam_Front", "Cam_Hip", "Cam_ADS"]
LABELS = {"hero": "Hero", "heror": "Hero right", "side": "Side", "sider": "Side right", "top": "Top", "front": "Front",
	"hip": "Hip (game offset)", "ads": "ADS at the game eye (v02 sights)", "rearsight": "Rear sight", "frontsight": "Front sight"}


def _ns(path, name):
	ns = {"__name__": name}
	exec(compile(open(path).read(), path, "exec"), ns)
	return ns


def build_only(gun):
	rg = _ns(ROOT + "/_Library/review_generic.py", "rv2_rg")
	rg["append_original"](gun)
	b = _ns("%s/%s/build_%s_v2.py" % (ROOT, gun, gun.lower()), "rv2_" + gun)
	return b["RESULT"]["_total_tris"]


def run(gun, extra=None, poses=None, version="v02"):
	view = dict(VIEWS[gun])
	view.setdefault("vm_scale", 0.75)
	rg = _ns(ROOT + "/_Library/review_generic.py", "rv2_rg")
	rg["append_original"](gun)  # REF_<gun>_* clips + the original for the comparison sheet (a fresh session has none)
	b = _ns("%s/%s/build_%s_v2.py" % (ROOT, gun, gun.lower()), "rv2_" + gun)
	floating = _ns(ROOT + "/_Library/parts_check.py", "rv2_pc")["check"](gun)["floating"]  # v03: nothing may float
	own = "%s/%s/anim_%s_v2.py" % (ROOT, gun, gun.lower())
	if os.path.exists(own) and "RESULT = " in open(own).read():  # authored clips (e.g. Outlaw); older files only define helpers
		_ns(own, "rv2_anim_" + gun)
	else:
		an = _ns(ROOT + "/_Library/anim_copy.py", "rv2_anim_copy")
		names = sorted({a.name[len("REF_%s_" % gun):] for a in bpy.data.actions if a.name.startswith("REF_%s_" % gun)})
		an["apply"](gun, names)
	if extra is None:
		extra = {}
		if "aim" in view:
			ax, _, sz = view["aim"]
			extra["Cam_RearSight"] = {"loc": (ax - 0.32, 0.3, sz + 0.16), "at": (ax, 0.0, sz - 0.03), "lens": 50}
	cams = [c for c in BASE if c != "Cam_ADS" or "aim" in view] + list(extra.keys())
	if poses is None:  # show the ammo: the magazine just out, when the reload marks it
		poses = []
		rl = bpy.data.actions.get(gun + "_Reload")
		mk = dict(rl["gg_markers"]) if rl is not None and "gg_markers" in rl.keys() else {}
		if "MagOut" in mk:
			poses.append((gun + "_Reload", int(mk["MagOut"]) + 3, "Cam_Hero", "reload_magout"))
	labels = {"%s_%s.png" % (version, k): v for k, v in LABELS.items()}
	for a, f, c, t in poses:
		labels["%s_%s.png" % (version, t)] = "%s f%d" % (a.split("_", 1)[1], f)
	fz = _ns(ROOT + "/_Library/finalize.py", "rv2_finalize")
	cmp = ["Cam_Hero", "Cam_Side"] + (["Cam_ADS"] if "aim" in view else [])
	r = fz["finalize"](gun, view, extra, cams, poses, cmp, labels, version=version)
	r["build"] = b["RESULT"]["_total_tris"]
	r["floating"] = floating
	return r


def cleanup(gun):
	# Frees a finished gun from the live session (its .blend is already written): drops its review and REF scenes
	# and their now-unused data, so a long pass doesn't pile up memory. The user's own scene is never touched.
	keep = bpy.data.scenes.get("Scene")
	if keep is not None:
		bpy.context.window.scene = keep
	for name in ("%s_RemasterV2_Review" % gun, "REF_%s_Original" % gun):
		sc = bpy.data.scenes.get(name)
		if sc is not None:
			for col in list(sc.collection.children_recursive):
				for ob in list(col.objects):
					bpy.data.objects.remove(ob)
				bpy.data.collections.remove(col)
			for ob in list(sc.collection.objects):
				bpy.data.objects.remove(ob)
			bpy.data.scenes.remove(sc)
	for a in [a for a in bpy.data.actions if a.name.startswith(("REF_%s_" % gun, "%s_" % gun))]:
		bpy.data.actions.remove(a)
	bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=False, do_recursive=True)
	return len(bpy.data.scenes)
