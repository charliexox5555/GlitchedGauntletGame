# review_vandal_v2.py: stages the Vandal review scene (lights, cameras, ADS range) and renders review shots.
# Run through Blender MCP in the interactive session after build_vandal_v2.py.
#   ns = {}; exec(compile(open(p).read(), p, "exec"), ns); ns["render"](["Cam_Side", ...], tag)
#
# ADS camera = the game's eye: Weapons.Vandal.adsDistance 0.36 studs and adsFov 68 (vertical), with the
# viewmodel at Viewmodel.SCALE 0.75 -> 0.36 / 0.75 = 0.48 model units behind AimPoint (0.0775, 0, 0.5598).
# Near-plane rule Viewmodel.ADS_NEAR 0.16 studs -> 0.213 model units; camera clip 0.1 / 0.75 = 0.133.
# Hip camera from viewmodelOffset (0.52, -0.266, -0.38) / 0.75, vertical FOV 80 (approximate held view,
# no viewmodel sway/tilt, no arms).

import bpy, os

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
OUT = ROOT + "/Vandal/renders"
ns_stage = {}
_p = ROOT + "/_Library/review_stage.py"
exec(compile(open(_p).read(), _p, "exec"), ns_stage)

AIM = (0.0775, 0.0, 0.5598)
EYE = (AIM[0] - 0.48, 0.0, AIM[2])

SPEC = {
	"center": (0.70, 0.0, 0.10),
	"ads": {"eye": EYE, "target_dist": 30.0},
	"cams": {
		"Cam_Hero": {"loc": (3.25, 3.85, 1.45), "at": (0.68, 0.0, 0.04), "lens": 40},
		"Cam_HeroR": {"loc": (-0.9, -3.3, 1.1), "at": (0.70, 0.0, 0.06), "lens": 40},
		"Cam_Side": {"loc": (0.70, 6.0, 0.075), "at": (0.70, 0.0, 0.075), "ortho": 4.3},
		"Cam_SideR": {"loc": (0.70, -6.0, 0.075), "at": (0.70, 0.0, 0.075), "ortho": 4.3},
		"Cam_Top": {"loc": (0.70, 0.0, 6.0), "at": (0.70, 0.0001, 0.0), "ortho": 4.3},
		"Cam_Front": {"loc": (8.0, 0.0, 0.07), "at": (0.0, 0.0, 0.07), "ortho": 1.12},
		"Cam_ADS": {"loc": EYE, "at": (30.0, 0.0, EYE[2]), "fov_v": 68, "clip": 0.133},
		"Cam_Hip": {"loc": (-0.507, 0.693, 0.355), "at": (30.0, 0.693, 0.355), "fov_v": 80, "clip": 0.133},
		"Cam_Mag": {"loc": (1.30, 0.78, -0.28), "at": (0.60, 0.0, 0.08), "lens": 50},
		"Cam_MagUnder": {"loc": (1.45, 0.62, -0.62), "at": (0.60, 0.0, 0.11), "lens": 45},
		"Cam_Receiver": {"loc": (0.52, 1.30, 0.44), "at": (0.38, 0.0, 0.22), "lens": 42},
		"Cam_Port": {"loc": (0.60, -1.15, 0.52), "at": (0.46, 0.0, 0.29), "lens": 50},
		"Cam_Charm": {"loc": (1.18, 0.62, 0.02), "at": (0.93, 0.10, 0.16), "lens": 60},
		"Cam_RearSight": {"loc": (-0.36, 0.46, 0.86), "at": (0.08, 0.0, 0.50), "lens": 50},
		"Cam_FrontSight": {"loc": (1.62, 0.52, 0.78), "at": (2.02, 0.0, 0.46), "lens": 50},
	},
}


def scene():
	return bpy.data.scenes["Vandal_RemasterV2_Review"]


def stage():
	return ns_stage["stage"](scene(), SPEC)


def ads_faded():
	# Mirrors ViewmodelController.findNearPlaneParts: a part whose name starts with an ADS_FADE_PREFIX
	# ("Stock") fades when its box starts behind the eye and reaches past ADS_NEAR (0.213 model units)
	# in front of it. Depth along +X from the eye.
	out = []
	for o in bpy.data.collections["Vandal"].objects:
		if o.type != "MESH" or not o.name.startswith("Vandal_Stock"):
			continue
		xs = [(o.matrix_world @ v.co).x - EYE[0] for v in o.data.vertices]
		if min(xs) < 0 and max(xs) > 0.16 / 0.75:
			out.append(o.name)
	return out


def render(cams, tag):
	os.makedirs(OUT, exist_ok=True)
	sc = scene()
	out = []
	for c in cams:
		path = "%s/%s_%s.png" % (OUT, tag, c.replace("Cam_", "").lower())
		res = (1080, 1080) if c == "Cam_Front" else (1920, 1080)
		hide = ads_faded() if c == "Cam_ADS" else ()
		ns_stage["shoot"](sc, c, path, ads=c in ("Cam_ADS", "Cam_Hip"), res=res, hide=hide)
		out.append(path)
	return out
