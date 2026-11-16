# review_classic_v2.py: stages the Classic review scene and renders review shots (Blender MCP only).
#   ns = {}; exec(compile(open(p).read(), p, "exec"), ns); ns["stage"](); ns["render"](["Cam_Side"], "v01")
#
# The Classic has no ADS (Weapons.Classic.noAds). Held view from Weapons SIDEARM_VM (0.42, -0.76, -1.3) and
# SIDEARM_SCALE 1.1 -> camera at (-1.18, +0.382, +0.691) model units from the grip, vertical FOV 80 (approximate:
# no sway, tilt or arms). "Cam_SightLine" looks along the slide from behind to judge the 3-dot alignment.

import bpy, os

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
OUT = ROOT + "/Classic/renders"
PREFIX = "Classic"
ns_stage = {}
_p = ROOT + "/_Library/review_stage.py"
exec(compile(open(_p).read(), _p, "exec"), ns_stage)

SPEC = {
	"prefix": PREFIX,
	"center": (0.36, 0.0, 0.05),
	"ads": {"eye": (-1.18, 0.0, 0.515), "target_dist": 30.0},
	"cams": {
		"Cam_Hero": {"loc": (1.75, 1.85, 0.92), "at": (0.37, 0.0, 0.06), "lens": 42},
		"Cam_HeroR": {"loc": (-0.55, -1.6, 0.65), "at": (0.36, 0.0, 0.05), "lens": 42},
		"Cam_Side": {"loc": (0.36, 4.0, 0.065), "at": (0.36, 0.0, 0.065), "ortho": 1.7},
		"Cam_SideR": {"loc": (0.36, -4.0, 0.065), "at": (0.36, 0.0, 0.065), "ortho": 1.7},
		"Cam_Top": {"loc": (0.36, 0.0, 4.0), "at": (0.36, 0.0001, 0.0), "ortho": 1.7},
		"Cam_Front": {"loc": (5.0, 0.0, 0.07), "at": (0.0, 0.0, 0.07), "ortho": 1.0},
		"Cam_Hip": {"loc": (-1.18, 0.382, 0.691), "at": (30.0, 0.382, 0.691), "fov_v": 80, "clip": 0.09},
		"Cam_SightLine": {"loc": (-0.75, 0.0, 0.515), "at": (30.0, 0.0, 0.515), "fov_v": 30, "clip": 0.05},
		"Cam_Controls": {"loc": (0.42, 0.95, 0.24), "at": (0.30, 0.0, 0.16), "lens": 45},
		"Cam_Port": {"loc": (0.62, -0.62, 0.82), "at": (0.49, 0.0, 0.40), "lens": 50},
		"Cam_MagBase": {"loc": (0.45, 0.85, -0.55), "at": (0.0, 0.0, -0.28), "lens": 50},
		"Cam_Charm": {"loc": (-0.42, 0.42, 0.12), "at": (-0.215, 0.083, 0.222), "lens": 60},
		"Cam_Muzzle": {"loc": (1.55, 0.42, 0.62), "at": (0.95, 0.0, 0.33), "lens": 55},
		"Cam_Rear": {"loc": (-0.85, 0.28, 0.80), "at": (0.10, 0.0, 0.45), "lens": 45},
	},
}


def scene():
	return bpy.data.scenes["Classic_RemasterV2_Review"]


def stage():
	return ns_stage["stage"](scene(), SPEC)


def render(cams, tag):
	os.makedirs(OUT, exist_ok=True)
	sc = scene()
	out = []
	for c in cams:
		path = "%s/%s_%s.png" % (OUT, tag, c.replace("Cam_", "").lower())
		res = (1080, 1080) if c == "Cam_Front" else (1920, 1080)
		ns_stage["shoot"](sc, c, path, ads=c in ("Cam_Hip", "Cam_SightLine"), res=res, prefix=PREFIX)
		out.append(path)
	return out
