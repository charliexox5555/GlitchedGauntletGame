"""Run through Blender MCP with the stock v05 review scene appended and active."""

from pathlib import Path
import math

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source/weapons/Skins/Moltframe/Vandal/v03"
REVIEW = OUT / "review"
TEXTURES = OUT / "textures"
for directory in (OUT, REVIEW, TEXTURES):
    directory.mkdir(parents=True, exist_ok=True)

scene = bpy.context.scene
assert scene.name.startswith("Moltframe Vandal")
scene.name = "Moltframe Vandal v03"
gun = next(c for c in scene.collection.children if c.name.split(".")[0] == "Vandal")
rig = next(o for o in gun.objects if o.type == "ARMATURE")
source_meshes = {o.name.split(".")[0][7:]: o for o in gun.objects if o.type == "MESH"}
actions = [strip.action for track in rig.animation_data.nla_tracks for strip in track.strips]
if (old := scene.collection.children.get("Moltframe Shell")) is not None:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)
shell = bpy.data.collections.new("Moltframe Shell")
scene.collection.children.link(shell)

def rgba(hex_value):
    srgb = [int(hex_value[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in srgb]

def material(name, color, roughness, metallic):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgba(color), 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = (*rgba(color), 1)
    return mat

looks = {
    "Body": ("292D39", .37, .45),
    "Panel": ("3C4252", .33, .56),
    "Dark": ("191B24", .68, .12),
    "Grip": ("22232D", .83, .0),
    "Metal": ("555D70", .32, .68),
    "Accent": ("85869D", .31, .58),
    "Neon": ("B675E6", .29, .08),
    "Brass": ("686579", .29, .66),
}
original = {}
skin_materials = {}
for name, obj in source_meshes.items():
    for index, slot in enumerate(obj.material_slots):
        role = slot.material.name.split(".")[0].removeprefix("Moltframe ")
        assert role in looks, role
        original[name, index] = slot.material
        if "Sight" not in name and name not in {"ChargingHandle", "Bolt", "FireSelector"}:
            skin_materials[name, index] = material("Moltframe " + role, *looks[role])

alloy = material("Moltframe folded graphite", "44495E", .39, .57)
fluid = material("Moltframe violet chamber", "63258C", .21, .08)
for mat in (fluid, alloy):
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Coat Weight"].default_value = .34 if mat == fluid else .11
    shader.inputs["Coat Roughness"].default_value = .17 if mat == fluid else .27

# Shared UV strip with two materials and a dry graphite return. The pale fold
# is across each plate's width. The fluid streak meanders along the channel.
WIDTH, HEIGHT = 1024, 512
u = (np.arange(WIDTH)[None, :] + .5) / WIDTH
v = (np.arange(HEIGHT)[:, None] + .5) / HEIGHT
def gauss(distance, width):
    return np.exp(-((distance / width) ** 2))
def blend(low, high, amount):
    return np.array(rgba(low)) + (np.array(rgba(high)) - rgba(low)) * np.clip(amount, 0, 1)[..., None]

plate_v = np.clip((v - .53) / .43, 0, 1)
fold = gauss(plate_v - .20 - .045 * np.sin(u * 5), .14)
edge = gauss(plate_v - .065, .055)
face = .025 + .11 * plate_v + .05 * np.sin(u * 4 + plate_v * 2) ** 2
grain = .014 * np.sin(u * 1250 + v * 40) * np.cos(v * 340)
vein = .014 * np.sin(u * 240 + 9*np.sin(plate_v * 12)) * np.cos(plate_v * 68)
plate_color = blend("242637", "8291AD", face + .51 * fold + .17 * edge + grain + vein)
fluid_v = np.clip((v - .07) / .39, 0, 1)
def fluid_pattern(phase):
    # Periodic advection in U with tapered pale branches inside each window.
    # The cross-section coordinates stay fixed so the wall never scrolls.
    angle = math.tau * (u - phase)
    flow = fluid_v + .10*np.sin(2*angle + 8*fluid_v) + .06*np.sin(5*angle - 13*fluid_v)
    stream = .43 + .19*np.sin(2*angle + .65) + .05*np.sin(6*angle)
    cloud = gauss(flow-stream, .21)
    branching = gauss(flow-stream + .08*np.sin(7*angle), .026)
    branching += .46*gauss(flow-stream - .15 + .06*np.sin(4*angle+1.4), .045)
    knot = gauss(np.sin(3*angle+.6), .27) * gauss(flow-stream, .11)
    flecks = (np.sin(43*angle+flow*39)*np.sin(29*angle-flow*71))**12 * cloud
    magenta = blend("210B34", "8F40B9", .12 + .68*cloud + .24*knot)
    highlight = np.clip((.47*branching + .20*knot + .09*flecks)*cloud,0,1)[...,None]
    return magenta*(1-highlight) + np.array(rgba("D3A3F0"))*highlight, cloud

fluid_color, glow = fluid_pattern(0)
color = np.where((v > .49)[..., None], plate_color, fluid_color)
metal = np.where(v > .49, .41 + .29 * fold, .11 + .0 * u)
rough = np.where(v > .49, .45 - .15 * fold, .20 + .07 * (1 - glow))
# Color RGB is authored in linear light, Blender writes it to an sRGB PNG.
def texture(label, channels, color_data=False):
    name = "Moltframe_" + label
    image = bpy.data.images.get(name) or bpy.data.images.new(name, width=WIDTH, height=HEIGHT, alpha=False)
    image.colorspace_settings.name = "sRGB" if color_data else "Non-Color"
    if color_data:
        channels = np.where(channels < .0031308, channels * 12.92, 1.055 * channels ** (1 / 2.4) - .055)
    rgb = np.broadcast_to(channels, (HEIGHT, WIDTH, 3))
    pixels = np.ones((HEIGHT, WIDTH, 4), dtype=np.float32)
    pixels[..., :3] = rgb
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw = str(TEXTURES / (name + ".png"))
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image

maps = {
    "Base Color": texture("Color", color, True),
    "Metallic": texture("Metalness", metal[..., None]),
    "Roughness": texture("Roughness", rough[..., None]),
}

def motion_frames():
    # Eight time samples across a single four-second loop. Three can be
    # paired on the handoff without requiring playback inside Studio.
    frames = REVIEW / "fluid_motion"
    frames.mkdir(exist_ok=True)
    image = bpy.data.images.new("Moltframe fluid motion preview", width=WIDTH, height=HEIGHT, alpha=False)
    image.colorspace_settings.name = "sRGB"
    for i in range(8):
        rgb, _ = fluid_pattern(i / 8)
        srgb = np.where(rgb < .0031308, rgb * 12.92, 1.055 * rgb ** (1/2.4) - .055)
        pixels = np.ones((HEIGHT, WIDTH, 4), dtype=np.float32)
        pixels[...,:3] = srgb
        image.pixels.foreach_set(pixels.ravel())
        image.filepath_raw = str(frames / f"fluid_{i:02}.png")
        image.file_format = "PNG"
        image.save()
    bpy.data.images.remove(image)
for mat in (alloy, fluid):
    nt = mat.node_tree
    shader = nt.nodes.get("Principled BSDF")
    for index, (socket, img) in enumerate(maps.items()):
        node = nt.nodes.get(socket + " Map") or nt.nodes.new("ShaderNodeTexImage")
        node.name = socket + " Map"
        node.label = img.name
        node.image = img
        node.extension = "EXTEND"
        node.location = (-340, 100 - 280 * index)
        nt.links.new(node.outputs["Color"], shader.inputs[socket])

def curve(keys, x, column):
    """Catmull-Rom interpolation with one-sided slopes at the end stations."""
    for i in range(len(keys) - 1):
        left, right = keys[i], keys[i + 1]
        if x <= right[0] or i == len(keys) - 2:
            before = keys[max(0, i - 1)]
            after = keys[min(len(keys) - 1, i + 2)]
            dx = right[0] - left[0]
            t = (x - left[0]) / dx
            a, b = left[column], right[column]
            m = (b - before[column]) * dx / (right[0] - before[0])
            n = (after[column] - a) * dx / (after[0] - left[0])
            return (2*t**3 - 3*t*t + 1)*a + (t**3 - 2*t*t + t)*m + (-2*t**3 + 3*t*t)*b + (t**3-t*t)*n


def bounds(points):
    return [[round(fn(p[i] for p in points), 6) for i in range(3)] for fn in (min, max)]
