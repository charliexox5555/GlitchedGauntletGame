# Concept 3/4 (owner's sheet) above our hero render, same width, for a side-by-side read.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_vandal/tv_lib.py").read())
import numpy as np
TAG = globals().get("TAG", "r02")
OUT = globals().get("OUT", SCRATCH + "cmp_%s.png" % TAG)
def load(p):
	im = bpy.data.images.load(p, check_existing=False); W, H = im.size
	a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im); return a
ref = load(SCRATCH + "ref_34.png")          # bottom-up rows
ours = load(SCRATCH + "tv_%s_hero.png" % TAG)
S = 3
r = np.repeat(np.repeat(ref, S, 0), S, 1)    # 1536 x 744
Wt = r.shape[1]
o = ours[::1, :Wt]                            # crop ours to the same width
o = o[(o.shape[0] - 744) // 2:(o.shape[0] - 744) // 2 + 744]
stack = np.concatenate([o, r], 0)             # bottom-up: ours below, concept above
img = bpy.data.images.new("cmp", Wt, stack.shape[0], alpha=True); img.pixels[:] = stack.ravel()
img.filepath_raw = OUT; img.file_format = "PNG"; img.save(); bpy.data.images.remove(img)
result = {"out": OUT}
