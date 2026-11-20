"""Render views from the saved master in a separate Blender process."""
import sys
from pathlib import Path
import math

import bpy


args = sys.argv[sys.argv.index("--") + 1:]
version, *views = args
root = Path(__file__).resolve().parents[2]
folder = root / "art-source/weapons/Skins/TempestStrike/Vandal" / version / "review"
folder.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes["Tempest-Strike | Storm Shadow"]
stock = bpy.data.scenes["Stock Vandal | Reference"]
water = next(c for c in scene.collection.children if c.name.startswith("07"))
stage = next(c for c in scene.collection.children if c.name.startswith("09"))
scene.render.engine = "CYCLES"
scene.cycles.samples = 14
scene.cycles.use_denoising = True
scene.render.threads_mode = "FIXED"
scene.render.threads = 12
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.render.resolution_percentage = 100
scene.view_settings.exposure = .55
scene.frame_set(1)
if bpy.data.scenes.get("Tempest-Strike | Animation"):
    for obj in scene.objects:
        if obj.name.startswith(("Hand_", "Arm_", "FX_Action", "GhostMag_")):
            obj.hide_render = True

views = views or ["hero", "opaque", "side", "opposite", "top", "underside", "back", "front",
                   "rearquarter", "mag", "sight", "charm", "muzzle", "stock", "grip", "round",
                   "hip", "ads", "ads2", "stock_side", "stock_hip", "stock_ads", "silhouette"]
config = {
    "hero": ("Review_Hero", (1440, 680)),
    "opaque": ("Review_Hero", (1350, 640)),
    "side": ("Review_Side", (1280, 430)),
    "opposite": ("Review_Opposite", (1280, 430)),
    "top": ("Review_Top", (1050, 300)),
    "underside": ("Review_Underside", (1150, 440)),
    "back": ("Review_Back", (530, 520)),
    "front": ("Review_Front", (530, 520)),
    "rearquarter": ("Review_RearQuarter", (1200, 580)),
    "mag": ("Review_Mag", (530, 560)),
    "sight": ("Review_Sight", (590, 490)),
    "charm": ("Review_Charm", (590, 470)),
    "muzzle": ("Review_Muzzle", (650, 480)),
    "stock": ("Review_Stock", (720, 440)),
    "grip": ("Review_Grip", (580, 480)),
    "round": ("Review_Round", (740, 460)),
    "receiver": ("Review_Receiver", (1160, 500)),
    "shroud": ("Review_Shroud", (900, 470)),
    "hip": ("TS_Vandal_Cam_Hip", (1050, 600)),
    "ads": ("TS_Vandal_Cam_ADS", (1050, 600)),
    "ads2": ("TS_Vandal_FP_ADS", (1050, 600)),
    "stock_side": ("Review_Side", (1280, 430)),
    "stock_hip": ("TS_Vandal_Cam_Hip", (1050, 600)),
    "stock_ads": ("TS_Vandal_Cam_ADS", (1050, 600)),
    "silhouette": ("Review_Side", (1280, 430)),
    "amethyst": ("Review_Hero", (1120, 470)),
    "ivory": ("Review_Hero", (1120, 470)),
    "eclipse": ("Review_Hero", (1120, 470)),
}
silhouette = bpy.data.materials.get("Silhouette") or bpy.data.materials.new("Silhouette")
silhouette.diffuse_color = (.02, .027, .037, 1)
chromas = {
    "amethyst": {"Body":"251F31","Dark":"130E1B","Panel":"9998AB","PanelEdge":"CCC2D8",
                 "Metal":"564B66","Accent":"563583","Grip":"3D2C3B","GripEdge":"2B1B2F",
                 "Hydro":"6922AA","HydroEdge":"AD69EA","Spark":"E8C5FF","Glass":"9661D4"},
    "ivory": {"Body":"B5C6C8","Dark":"31494E","Panel":"E3E5DF","PanelEdge":"F5F3EB",
              "Metal":"8EA9AE","Accent":"528F90","Grip":"526167","GripEdge":"303F46",
              "Hydro":"1F9D8E","HydroEdge":"83F1DD","Spark":"BBFFEE","Glass":"91DFCD"},
    "eclipse": {"Body":"141723","Dark":"090B14","Panel":"546379","PanelEdge":"8B9EB7",
                "Metal":"393F54","Accent":"283455","Grip":"242332","GripEdge":"151723",
                "Hydro":"4790C2","HydroEdge":"9CDBFF","Spark":"E1F3FF","Glass":"719FDB"},
}
original={m.name:m.diffuse_color[:] for m in bpy.data.materials if m.name.startswith("TS_")}


def set_palette(name):
    preset=chromas.get(name,{})
    for mat_name,rgba in original.items():
        mat=bpy.data.materials[mat_name]
        role=mat.name.removeprefix("TS_").split(" · ")[0]
        value=preset.get(role)
        if value:
            rgb=[int(value[i:i+2],16)/255 for i in (0,2,4)]
            rgba=tuple(v/12.92 if v<.04045 else math.pow((v+.055)/1.055,2.4) for v in rgb)+(1,)
        mat.diffuse_color=rgba
        shader=mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value=rgba
        shader.inputs["Emission Color"].default_value=rgba

for name in views:
    if name not in config:
        raise ValueError(name)
    set_palette(name)
    uses_stock = name in {"stock_side", "stock_hip", "stock_ads"}
    actual = stock if uses_stock else scene
    actual.render.engine = scene.render.engine
    actual.cycles.samples = scene.cycles.samples
    actual.cycles.use_denoising = True
    actual.render.threads_mode = "FIXED"
    actual.render.threads = scene.render.threads
    actual.render.image_settings.file_format = "PNG"
    actual.render.image_settings.color_mode = "RGBA"
    actual.render.film_transparent = True
    actual.view_settings.view_transform = "AgX"
    actual.view_settings.exposure = .55
    if uses_stock:
        actual.world = scene.world
        # Temporary review isolation. The file on disk retains its original stage.
        for group in stock.collection.children:
            group.hide_render = group.name != "Vandal"
        if stage not in list(stock.collection.children):
            stock.collection.children.link(stage)
    camera_name, dimensions = config[name]
    actual.camera = scene.objects[camera_name]
    actual.render.resolution_x, actual.render.resolution_y = dimensions
    actual.render.resolution_percentage = 100
    actual.render.filepath = str(folder / (name + ".png"))
    model_groups = [g for g in scene.collection.children if g.name[:2] in {"02","03","04","05","06","07","08","10"}]
    for group in model_groups:
        group.hide_render = (group.name[:2] != "10" if name == "round" else group.name[:2] == "10")
        if name == "mag":
            group.hide_render = group.name[:2] not in {"05", "07"}
    for obj in water.objects:
        obj.hide_render = name == "mag" and not obj.name.startswith("Water_Mag")
    water.hide_render = name in {"opaque", "silhouette", "side", "opposite", "round"}
    actual.view_layers[0].material_override = silhouette if name == "silhouette" else None
    bpy.ops.render.render(write_still=True, scene=actual.name)
