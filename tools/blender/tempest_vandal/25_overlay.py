# Overlay the left-side render on the owner's concept "LEFT SIDE" panel (scaled by the gun's bounding box).
# Writes ovl_<tag>.png: concept, ours, and a 50% blend, stacked. Concept muzzle points left; our left view too.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_vandal/tv_lib.py").read())
import numpy as np
TAG = globals().get("TAG", "r02")
def load(p):
	im = bpy.data.images.load(p, check_existing=False)
	W, H = im.size
	a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1].copy()  # top-down
	bpy.data.images.remove(im)
	return a
ref = load(SCRATCH + "ref_left.png")
ours = load(SCRATCH + "tv_%s_left.png" % TAG)
def bbox(a, bgref, thr):
	d = np.abs(a[..., :3] - bgref).sum(-1) > thr
	ys, xs = np.where(d)
	return xs.min(), xs.max(), ys.min(), ys.max()
rb = bbox(ref[6:], ref[60, 4, :3], 0.35); rb = (rb[0], rb[1], rb[2] + 6, rb[3] + 6)
ob = bbox(ours, ours[5, 5, :3], 0.12)
S = 4  # output scale of the concept panel
rw, rh = (rb[1] - rb[0]) * S, (rb[3] - rb[2]) * S
# resample ours into the concept's gun box (x by length; y uses the same scale so proportions are honest)
sx = (ob[1] - ob[0]) / rw
H, W = ref.shape[0] * S, ref.shape[1] * S
canvas_ref = np.repeat(np.repeat(ref, S, 0), S, 1)
canvas_our = np.ones_like(canvas_ref) * np.array([0.42, 0.43, 0.46, 1.0], dtype=np.float32)
yy, xx = np.mgrid[0:H, 0:W]
ox = ob[0] + (xx - rb[0] * S) * sx
# align the muzzle bore line: concept's gun top-left corner box vs ours, vertical anchor = bbox top
oy = ob[2] + (yy - rb[2] * S) * sx
ok = (ox >= 0) & (ox < ours.shape[1] - 1) & (oy >= 0) & (oy < ours.shape[0] - 1)
canvas_our[ok] = ours[oy[ok].astype(int), ox[ok].astype(int)]
blend = canvas_ref * 0.5 + canvas_our * 0.5
stack = np.concatenate([canvas_ref, canvas_our, blend], 0)[::-1].copy()
img = bpy.data.images.new("ovl", W, H * 3, alpha=True)
img.pixels[:] = stack.ravel()
img.filepath_raw = SCRATCH + "ovl_%s.png" % TAG; img.file_format = "PNG"; img.save()
bpy.data.images.remove(img)
result = {"ref_box": [int(v) for v in rb], "our_box": [int(v) for v in ob], "out": SCRATCH + "ovl_%s.png" % TAG}
