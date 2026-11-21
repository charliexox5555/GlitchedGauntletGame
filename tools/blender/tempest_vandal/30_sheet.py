# Save the master and build a 2x3 review sheet from the scratchpad renders.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_vandal/tv_lib.py").read())
import numpy as np
ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/"
TAG = globals().get("TAG", "r01")
bpy.ops.wm.save_as_mainfile(filepath=ROOT + "art-source/weapons/Skins/TempestStrike/Vandal/%s/Vandal_TempestStrike_%s.blend" % (TAG, TAG))
names = [["hero", "rear34"], ["left", "right"], ["fp", "stock_left"]]
TW, TH = 800, 400
sheet = np.zeros((TH * 3, TW * 2, 4), dtype=np.float32); sheet[..., 3] = 1
for r, row in enumerate(names):
	for c, n in enumerate(row):
		im = bpy.data.images.load(SCRATCH + "tv_%s_%s.png" % (TAG, n))
		W, H = im.size
		a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)[::2, ::2]
		h, w = a.shape[:2]
		y0 = (h - TH) // 2
		a = a[y0:y0 + TH, :TW]
		sheet[(2 - r) * TH:(3 - r) * TH, c * TW:(c + 1) * TW] = a
		bpy.data.images.remove(im)
img = bpy.data.images.new("sheet", TW * 2, TH * 3, alpha=True)
img.pixels[:] = sheet.ravel()
out = ROOT + "vault/02 Art/Skins/TempestStrike/out/Vandal_%s_review.png" % TAG
img.filepath_raw = out; img.file_format = "PNG"; img.save()
bpy.data.images.remove(img)
result = {"sheet": out, "blend": bpy.data.filepath, "tris": tris(list(bpy.data.collections["COL_Model"].all_objects))}
