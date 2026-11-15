"""Matched stock-vs-Moltframe review renders for any line item.

Exec in the Blender MCP session after the item's builder (which defines
`set_skin(on)`, `rig`, `col`). Set first:
    ITEM, OUT          item name and the version folder (renders go to OUT/review)
    AIM_EMPTY          name of the stock AimPoint empty
    STOCK_OBJECTS      stock mesh names (framing + stock renders)
    FINISH_TARGET      (x, y, z) close-up target on the player-facing side
    LOOP               True to also render the 6 s fluid loop frames
Same world, light rig and camera directions as the Vandal v05 review.
"""
import sys, math
from mathutils import Vector

sys.path.insert(0, r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame\art-source\weapons\RemasterV2\_Library")
import importlib, model_sheet as sheet
importlib.reload(sheet)
sc = bpy.context.scene
sheet.bind({"scene": lambda _g: sc})
REV = OUT + r"\review"
import os
os.makedirs(REV + r"\fluid_frames", exist_ok=True)

def _lin(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in c]

def review_world():
    w = bpy.data.worlds.get("MF4 Review Sky") or bpy.data.worlds.new("MF4 Review Sky")
    w.use_nodes = True
    nt = w.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld"); bg = nt.nodes.new("ShaderNodeBackground")
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = -1; mr.inputs["From Max"].default_value = 1
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = .25; ramp.color_ramp.elements[0].color = (*_lin("272C38"), 1)
    ramp.color_ramp.elements[1].position = .75; ramp.color_ramp.elements[1].color = (*_lin("A9B6CC"), 1)
    e = ramp.color_ramp.elements.new(.5); e.color = (*_lin("5D6A82"), 1)
    nt.links.new(mr.outputs[0], ramp.inputs[0]); nt.links.new(ramp.outputs[0], bg.inputs[0])
    bg.inputs[1].default_value = 1.0
    nt.links.new(bg.outputs[0], out.inputs[0])
    sc.world = w
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"

def render(cam, name, res=(960, 540), samples=48):
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.eevee.taa_render_samples = samples
    sc.render.filepath = REV + "/" + name + ".png"
    bpy.ops.render.render(write_still=True)

def studio_cam(name, pts, direction, **kw):
    cam, center, radius = sheet._cam("MFR_" + ITEM, name, pts, direction, **kw)
    sheet._lights("MFR_" + ITEM, cam, center, radius)
    return cam

def gameplay_cam(name, point, fov):
    cam = bpy.data.objects.get(name)
    if cam is None:
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name)); sc.collection.objects.link(cam)
    d = cam.data
    d.sensor_fit = "VERTICAL"; d.sensor_height = 24
    d.lens = 12 / math.tan(math.radians(fov) / 2); d.clip_start = .125
    cam.location = point
    cam.rotation_euler = Vector((1, 0, 0)).to_track_quat("-Z", "Y").to_euler()
    return cam

def rest():
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.matrix_basis.identity()
    sc.frame_set(1)

def run_review():
    review_world()
    for lc in [c for c in sc.collection.children if "RV2_Lights" in c.name or "ADSRange" in c.name]:
        lc.hide_render = True
    stock_pts = [bpy.data.objects[n].matrix_world @ v.co for n in STOCK_OBJECTS for v in bpy.data.objects[n].data.vertices]
    if globals().get("MELEE"):
        # custom melee shapes can outgrow the stock knife: frame both
        stock_pts += [o.matrix_world @ v.co for o in col.objects if o.type == "MESH" for v in o.data.vertices]
    aim = bpy.data.objects[AIM_EMPTY].matrix_world.translation.copy()
    shots = [
        ("hero", studio_cam("hero", stock_pts, (.52, .72, .36), lens=60), (1200, 675)),
        ("opposite", studio_cam("opposite", stock_pts, (-.34, -.86, .40), lens=60), (1200, 675)),
        ("profile_left", studio_cam("profile_left", stock_pts, (0, 1, 0), ortho=True), (1200, 675)),
        ("profile_right", studio_cam("profile_right", stock_pts, (0, -1, 0), ortho=True), (1200, 675)),
        ("held", studio_cam("held", stock_pts, (-.85, .34, .30), lens=50), (960, 540)),
        ("hip", gameplay_cam("MFR_" + ITEM + "_hip", aim + Vector((-.553, .65, -.2275)), 80), (960, 540)),
        ("ads", gameplay_cam("MFR_" + ITEM + "_ads", aim - Vector((.45, 0, 0)), 68), (960, 540)),
    ]
    reload_cam = studio_cam("reload", stock_pts, (.39, .83, .26), lens=64, margin=1.2)
    acts = {a.name.split(".")[0].split("_", 1)[1]: a for a in bpy.data.actions if "_" in a.name}
    if globals().get("MELEE"):
        # knife slot: stock first-person camera instead of hip/ADS; inspect + slash poses
        shots = shots[:5] + [("fp", bpy.data.objects[FP_CAM], (960, 540))]
        poses = [(n, int(sum(acts[n].frame_range) / 2)) for n in ("Inspect", "Slash1", "HeavyStab") if n in acts]
        for tag, on in (("stock", False), ("moltframe", True)):
            set_skin(on)
            for name, cam, res in shots:
                render(cam, f"{name}_{tag}", res)
            for clip, fr in poses:
                rig.animation_data.action = acts[clip]; rig.animation_data.action_slot = acts[clip].slots[0]
                sc.frame_set(fr)
                render(reload_cam, f"{clip.lower()}_{tag}", (960, 540), 32)
            rest()
        set_skin(True)
        fin = bpy.data.objects.get("MFR_" + ITEM + "_finish") or bpy.data.objects.new("MFR_" + ITEM + "_finish", bpy.data.cameras.new("MFR_" + ITEM + "_finish"))
        if fin.name not in sc.objects:
            sc.collection.objects.link(fin)
        t = Vector(FINISH_TARGET); fin.data.lens = 50; fin.data.clip_start = .02
        fin.location = t + Vector(FINISH_OFFSET); fin.rotation_euler = (t - fin.location).to_track_quat("-Z", "Y").to_euler()
        render(fin, "finish", (1600, 900), 96)
        render(shots[0][1], "hero_moltframe_large", (1920, 1080), 96)
        if LOOP:
            for f in range(1, 145, 2):
                sc.frame_set(f)
                render(fin, f"fluid_frames/f{f:03d}", (960, 540), 24)
            sc.frame_set(1)
        return {"poses": poses}
    # magazine at its lowest in Reload
    rig.animation_data.action = acts["Reload"]; rig.animation_data.action_slot = acts["Reload"].slots[0]
    s, e = (int(f) for f in acts["Reload"].frame_range)
    best = (9, s)
    for f in range(s, e + 1):
        sc.frame_set(f)
        _b = rig.pose.bones.get("Mag") or rig.pose.bones.get("Shell") or rig.pose.bones.get("Root")
        best = min(best, ((rig.matrix_world @ _b.matrix).translation.z, f))
    rest()
    ins = acts["Inspect"]; mid = int(sum(ins.frame_range) / 2)
    for tag, on in (("stock", False), ("moltframe", True)):
        set_skin(on)
        for name, cam, res in shots:
            render(cam, f"{name}_{tag}", res)
        for clip, fr in (("Reload", best[1]), ("Inspect", mid)):
            rig.animation_data.action = acts[clip]; rig.animation_data.action_slot = acts[clip].slots[0]
            sc.frame_set(fr)
            render(reload_cam, f"{clip.lower()}_{tag}", (960, 540), 32)
        rest()
    set_skin(True)
    fin = bpy.data.objects.get("MFR_" + ITEM + "_finish")
    if fin is None:
        fin = bpy.data.objects.new("MFR_" + ITEM + "_finish", bpy.data.cameras.new("MFR_" + ITEM + "_finish"))
        sc.collection.objects.link(fin)
    t = Vector(FINISH_TARGET)
    fin.data.lens = 50; fin.data.clip_start = .02
    fin.location = t + Vector(FINISH_OFFSET)
    fin.rotation_euler = (t - fin.location).to_track_quat("-Z", "Y").to_euler()
    render(fin, "finish", (1600, 900), 96)
    render(shots[0][1], "hero_moltframe_large", (1920, 1080), 96)
    if LOOP:
        for f in range(1, 145, 2):
            sc.frame_set(f)
            render(fin, f"fluid_frames/f{f:03d}", (960, 540), 24)
        sc.frame_set(1)
    return {"reload_frame": best[1], "inspect_frame": mid}
