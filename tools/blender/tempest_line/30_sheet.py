# Save the version's master (one .blend per version) and build the review sheet from the scratchpad renders.
# Set GUN, TAG, NAMES (rows of two view names). Sheet -> vault/02 Art/Skins/TempestStrike/out/<GUN>_<TAG>_review.png
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
import numpy as np
TAG = globals().get("TAG", "s01")
dst = ROOT + "art-source/weapons/Skins/TempestStrike/%s/%s/%s_TempestStrike_%s.blend" % (GUN, TAG, GUN, TAG)
if not globals().get("NOSAVE"):
	os.makedirs(os.path.dirname(dst), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=dst, copy=False)
names = globals().get("NAMES", [["hero", "rear34"], ["left", "right"], ["top", "under"], ["fp", "ads"]])
TW, TH = 800, 400; R = len(names)
sheet = np.zeros((TH * R, TW * 2, 4), dtype=np.float32); sheet[..., 3] = 1
for r, row in enumerate(names):
	for c, n in enumerate(row):
		p = SCRATCH + "%s_%s_%s.png" % (GUN, TAG, n)
		if not os.path.exists(p):
			continue
		im = bpy.data.images.load(p)
		W, H = im.size
		a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)
		k = max(1, int(round(W / TW)))
		a = a[::k, ::k]
		h, w = a.shape[:2]
		y0 = max(0, (h - TH) // 2); x0s = max(0, (w - TW) // 2)
		a = a[y0:y0 + TH, x0s:x0s + TW]
		t = np.zeros((TH, TW, 4), dtype=np.float32); t[...] = a[2, 2]; t[..., 3] = 1
		yo = (TH - a.shape[0]) // 2; xo = (TW - a.shape[1]) // 2
		t[yo:yo + a.shape[0], xo:xo + a.shape[1]] = a
		sheet[(R - 1 - r) * TH:(R - r) * TH, c * TW:(c + 1) * TW] = t
		bpy.data.images.remove(im)
img = bpy.data.images.new("sheet", TW * 2, TH * R, alpha=True)
img.pixels[:] = sheet.ravel()
out = ROOT + "vault/02 Art/Skins/TempestStrike/out/%s_%s_review.png" % (GUN, TAG)
img.filepath_raw = out; img.file_format = "PNG"; img.save()
bpy.data.images.remove(img)
result = {"sheet": out, "blend": bpy.data.filepath, "tris": tris(visible_model()), "parts": len(visible_model())}
