# Contact sheet of close-ups: CLOSES (view names), cols 4 -> <GUN>_<TAG>_closeups.png in the vault out folder.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
import numpy as np
TAG = globals().get("TAG", "s01"); names = CLOSES; C = 4; TW, TH = 600, 400
R = (len(names) + C - 1) // C
sheet = np.zeros((TH * R, TW * C, 4), dtype=np.float32); sheet[..., 3] = 1
for i, n in enumerate(names):
	r, c = divmod(i, C)
	im = bpy.data.images.load(SCRATCH + "%s_%s_%s.png" % (GUN, TAG, n)); W, H = im.size
	a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)[::2, ::2][:TH, :TW]
	sheet[(R - 1 - r) * TH:(R - 1 - r) * TH + a.shape[0], c * TW:c * TW + a.shape[1]] = a
	bpy.data.images.remove(im)
img = bpy.data.images.new("grid", TW * C, TH * R, alpha=True); img.pixels[:] = sheet.ravel()
out = ROOT + "vault/02 Art/Skins/TempestStrike/out/%s_%s_closeups.png" % (GUN, TAG)
if globals().get("SCRATCH_ONLY"):
	out = SCRATCH + "%s_%s_closeups.png" % (GUN, TAG)
img.filepath_raw = out; img.file_format = "PNG"; img.save(); bpy.data.images.remove(img)
result = {"grid": out}
