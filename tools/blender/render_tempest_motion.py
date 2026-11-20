"""Render exact authored frames for the Storm Shadow offline motion preview."""
import json
from pathlib import Path
import sys
import time

import bpy


version,start,end,quality=sys.argv[sys.argv.index("--")+1:]
root=Path(__file__).resolve().parents[2]
review=root/"art-source/weapons/Skins/TempestStrike/Vandal"/version/"review"
dest=review/("motion_frames" if quality=="preview" else "motion_material_tests")
dest.mkdir(exist_ok=True)
scene=bpy.data.scenes["Tempest-Strike | Storm Shadow"]
bpy.context.window.scene=scene
scene.render.image_settings.file_format="PNG"
scene.render.image_settings.color_mode="RGBA"
scene.render.film_transparent=True
scene.render.resolution_x,scene.render.resolution_y=(864,486)
scene.render.resolution_percentage=100
start,end=int(start),int(end)
engine="BLENDER_WORKBENCH" if quality=="preview" else "BLENDER_EEVEE"
scene.render.engine=engine
scene.view_settings.view_transform="Standard" if quality=="preview" else "AgX"
if quality=="preview":
    shading=scene.display.shading
    shading.light="STUDIO"
    shading.color_type="MATERIAL"
    shading.show_cavity=True
    shading.cavity_type="BOTH"
    shading.curvature_ridge_factor=1.15
    shading.curvature_valley_factor=.66
    shading.cavity_ridge_factor=1.05
    shading.cavity_valley_factor=1.02
    shading.show_shadows=False
    shading.show_object_outline=False
    shading.show_specular_highlight=True
    scene.display.render_aa="8"
else:
    scene.view_settings.exposure=.55
    eevee=scene.eevee
    if hasattr(eevee,"taa_render_samples"):
        eevee.taa_render_samples=12
timings={}
for f in range(start,end+1):
    file=dest/f"frame_{f:04}.png"
    if file.exists():
        continue
    begin=time.perf_counter()
    scene.frame_set(f)
    scene.render.filepath=str(file)
    bpy.ops.render.render(write_still=True,scene=scene.name)
    timings[f]=time.perf_counter()-begin
summary={"engine":engine,"frame_size":[864,486],"fps":scene.render.fps,"elapsed_seconds":timings}
(dest/f"benchmark_{start:04}_{end:04}.json").write_text(json.dumps(summary,indent=2))
