# Crop panels of the owner's concept sheet (reads the PNG, writes crops to the scratchpad).
import bpy, numpy as np
src = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/vault/02 Art/Skins/TempestStrike/refs/style/Tempest-Strike Vandal Reference.png"
out = r"C:/Users/charl/AppData/Local/Temp/claude/487954cbd365390d/59720a05-5fc4-46fb-9558-104afc4148ec/scratchpad/"
im = bpy.data.images.load(src, check_existing=True)
W, H = im.size
px = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1]  # top-down
s = W / 1024.0
def crop(name, x0, y0, x1, y1):
    a = px[int(y0*s):int(y1*s), int(x0*s):int(x1*s)][::-1].copy()
    h, w = a.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels[:] = a.ravel()
    img.filepath_raw = out + name + ".png"; img.file_format = "PNG"; img.save()
    bpy.data.images.remove(img)
crop("ref_34", 0, 62, 512, 310)
crop("ref_left", 512, 62, 768, 180)
crop("ref_right", 768, 62, 1024, 180)
crop("ref_top", 512, 182, 1024, 310)
crop("ref_detail", 255, 440, 1024, 572)
crop("ref_front", 255, 314, 512, 440)
bpy.data.images.remove(im)
result = {"size": [W, H]}
