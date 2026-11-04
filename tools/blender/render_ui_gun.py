"""Side render of a gun for the UI (draft cards, kill feed, weapon slots).

    blender -b art-source/weapons/Vandal.blend --python tools/blender/render_ui_gun.py -- art-source/ui/guns/Vandal.png

Light grey Workbench render on a transparent background, camera along the gun's
thinnest axis. Then mirror it so the muzzle points right and crop it (PIL:
ImageOps.mirror, crop to getbbox). vault/02 Art/UI Design.md → Assets.
"""
import bpy, sys, mathutils
out = sys.argv[-1]
sc = bpy.context.scene
meshes = [o for o in sc.objects if o.type == 'MESH' and o.visible_get() and not o.hide_render]
for o in sc.objects:
    if o.type in ('LIGHT', 'CAMERA'):
        o.hide_render = True
pts = [o.matrix_world @ mathutils.Vector(c) for o in meshes for c in o.bound_box]
mn = mathutils.Vector((min(p[i] for p in pts) for i in range(3)))
mx = mathutils.Vector((max(p[i] for p in pts) for i in range(3)))
size = mx - mn; ctr = (mn + mx) / 2
axes = sorted(range(3), key=lambda i: size[i])
thin, long_ = axes[0], axes[2]
cam_data = bpy.data.cameras.new("UICam"); cam_data.type = 'ORTHO'
cam = bpy.data.objects.new("UICam", cam_data); sc.collection.objects.link(cam)
d = mathutils.Vector((0, 0, 0)); d[thin] = 1
cam.location = ctr + d * (size.length * 3)
up = mathutils.Vector((0, 0, 0)); up[axes[1]] = 1
cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
# point the camera's up along the middle axis
look = (-d).normalized()
right = look.cross(up).normalized(); up2 = right.cross(look)
cam.matrix_world = mathutils.Matrix((
    (right.x, up2.x, -look.x, cam.location.x),
    (right.y, up2.y, -look.y, cam.location.y),
    (right.z, up2.z, -look.z, cam.location.z),
    (0, 0, 0, 1)))
cam_data.ortho_scale = max(size[long_], size[axes[1]] * 2) * 1.08
cam_data.clip_end = size.length * 10
sc.camera = cam
r = sc.render; r.engine = 'BLENDER_WORKBENCH'; r.film_transparent = True
r.resolution_x, r.resolution_y, r.resolution_percentage = 960, 480, 100
r.image_settings.file_format = 'PNG'; r.image_settings.color_mode = 'RGBA'
sh = sc.display.shading
sh.light = 'STUDIO'; sh.color_type = 'SINGLE'; sh.single_color = (0.80, 0.83, 0.86)
sh.show_cavity = True; sh.cavity_type = 'BOTH'; sh.show_shadows = False; sh.show_specular_highlight = True
r.filepath = out
bpy.ops.render.render(write_still=True)
