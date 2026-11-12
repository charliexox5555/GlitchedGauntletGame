# finalize.py: shared finalise step for a RemasterV2 weapon (Blender MCP only): rest pose, UV atlas, review renders,
# animation-pose renders, original comparison, write the .blend, and the two contact sheets (Pillow, run as a plain
# python subprocess on the rendered PNGs only: no Blender involved).
#   ns = {}; exec(compile(open(p).read(), p, "exec"), ns)
#   ns["finalize"](gun, view, extra_cams, cams, poses, compare_cams, labels)
# poses: [(action, frame, cam, tag)] ; labels: {"v01_<tag>.png": "label"} for the review sheet (order kept).

import bpy, os, sys, glob, importlib, subprocess

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"


def _load(name):
	ns = {}
	p = ROOT + "/_Library/" + name
	exec(compile(open(p).read(), p, "exec"), ns)
	return ns


def finalize(gun, view, extra_cams, cams, poses, compare_cams, labels, version="v01"):
	sys.path.insert(0, ROOT + "/_Library")
	import v2kit as K
	importlib.reload(K)
	an = _load("anim_copy.py")
	rg = _load("review_generic.py")
	sc = bpy.data.scenes[gun + "_RemasterV2_Review"]
	bpy.context.window.scene = sc
	an["rest"](gun)
	uv = K.uv_pack(gun)
	info = rg["setup"](gun, view, extra_cams)
	hide = rg["ads_faded"](gun, info["eye"]) if info["eye"] else ()
	out = ROOT + "/" + gun + "/renders"
	ck = out + "/checkpoints"
	os.makedirs(ck, exist_ok=True)
	for f in glob.glob(out + "/cp*.png"):
		os.replace(f, ck + "/" + os.path.basename(f))
	rg["render"](gun, cams, version, hide=hide)
	st = rg["ns_stage"]
	for action, frame, cam, tag in poses:
		an["pose"](gun, action, frame)
		st["shoot"](sc, cam, "%s/%s_%s.png" % (out, version, tag), ads=cam in ("Cam_ADS", "Cam_Hip"), prefix=gun)
	an["rest"](gun)
	cmp_ads = tuple(c for c in compare_cams if c in ("Cam_ADS", "Cam_Hip"))
	rg["compare"](gun, compare_cams, ads_cams=cmp_ads)
	bpy.context.window.scene = sc
	sc.camera = bpy.data.objects[gun + "_Cam_Hero"]
	path = "%s/%s/%s_RemasterV2_%s.blend" % (ROOT, gun, gun, version)
	if os.path.exists(path):
		os.remove(path)  # only ever our own file from this same pass
	chk = K.write_blend(path, sc, gun)
	# contact sheets (subprocess python + Pillow on the PNGs)
	cs = ROOT + "/_Library/contact_sheet.py"
	args = ["python", cs, "%s/%s/%s_%s_review_sheet.png" % (ROOT, gun, gun, version), "3", "760"]
	args += ["%s=%s/%s" % (lab, out, fn) for fn, lab in labels.items() if os.path.exists(out + "/" + fn)]
	r1 = subprocess.run(args, capture_output=True, text=True)
	args2 = ["python", cs, "%s/%s/%s_%s_vs_original.png" % (ROOT, gun, gun, version), "2", "900"]
	for c in compare_cams:
		t = c.replace("Cam_", "").lower()
		args2 += ["ORIGINAL %s=%s/compare_original_%s.png" % (t, out, t), "REMASTERV2 %s=%s/%s_%s.png" % (t, out, version, t)]
	r2 = subprocess.run(args2, capture_output=True, text=True)
	tris = sum(K.tri_count(o.data) for o in bpy.data.collections[gun].objects if o.type == "MESH")
	return {"tris": tris, "uv": [uv["coverage"], uv["inside_0_1"], sorted(set(uv["density"].values()))], "kb": chk["size_kb"], "actions": chk["actions"], "sheets": [r1.stdout.strip() or r1.stderr[-200:], r2.stdout.strip() or r2.stderr[-200:]]}
