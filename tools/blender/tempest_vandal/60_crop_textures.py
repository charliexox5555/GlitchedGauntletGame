# Crop thin strip textures to their alpha band (+ small margin) so Beams use the whole height.
import bpy, numpy as np
ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/vfx/tempest/"
out = {}
for name in ("water_ribbon", "water_tracer"):
	im = bpy.data.images.load(ROOT + "raw/" + name + ".png", check_existing=False)
	W, H = im.size
	a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)
	rows = np.where(a[..., 3].max(axis=1) > 0.04)[0]
	y0, y1 = max(0, rows.min() - 3), min(H, rows.max() + 4)
	crop = a[y0:y1].copy()
	h = y1 - y0
	img = bpy.data.images.new(name + "_cut", W, h, alpha=True)
	img.pixels[:] = crop.ravel()
	img.filepath_raw = ROOT + "cut/" + name + ".png"; img.file_format = "PNG"; img.save()
	bpy.data.images.remove(img); bpy.data.images.remove(im)
	corner = float(a[0, 0, 3]) + float(a[-1, -1, 3])
	out[name] = {"size": [W, H], "band": [int(y0), int(y1)], "corner_alpha": corner}
result = out
