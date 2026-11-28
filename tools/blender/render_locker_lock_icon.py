"""A flat white padlock icon from the Locker lock model (tools/blender/build_locker_lock.py), for the locked gun rows
and the skin tiles (tinted in Roblox). The keyhole is cut out (transparent).

    blender -b --python tools/blender/render_locker_lock_icon.py

Needs art-source/ui/locker-lock/LockerLock.blend. Writes art-source/ui/locker-lock/padlock_icon.png (256 x 256).
"""

import os

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIR = os.path.join(ROOT, "art-source", "ui", "locker-lock")
bpy.ops.wm.open_mainfile(filepath=os.path.join(DIR, "LockerLock.blend"))

scene = bpy.context.scene
keep = {"Padlock", "Shackle", "Keyhole"}
for ob in list(bpy.data.objects):
	if ob.type == "MESH" and ob.name not in keep:
		bpy.data.objects.remove(ob)
for ob in bpy.data.objects:
	if ob.type == "MESH":
		ob.color = (0, 0, 0, 1) if ob.name == "Keyhole" else (1, 1, 1, 1)

scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "OBJECT"
scene.display.shading.show_cavity = False
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 256
scene.view_settings.view_transform = "Standard"
cam_data = bpy.data.cameras.new("IconCam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 4.4
cam = bpy.data.objects.new("IconCam", cam_data)
scene.collection.objects.link(cam)
cam.location = (0, -10, 0.76)
cam.rotation_euler = (1.5707963, 0, 0)
scene.camera = cam
raw = os.path.join(DIR, "padlock_icon_raw.png")
scene.render.filepath = raw
bpy.ops.render.render(write_still=True)

# the keyhole (black) becomes see-through, everything else pure white
img = bpy.data.images.load(raw)
px = list(img.pixels)
for i in range(0, len(px), 4):
	r, g, b, a = px[i : i + 4]
	if a > 0.01 and (r + g + b) < 1.2:
		px[i + 3] = 0.0
	px[i], px[i + 1], px[i + 2] = 1.0, 1.0, 1.0
img.pixels = px
img.filepath_raw = os.path.join(DIR, "padlock_icon.png")
img.file_format = "PNG"
img.save()
os.remove(raw)
print("icon written")
