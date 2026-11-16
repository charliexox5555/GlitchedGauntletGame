"""Mesh helpers and Molly animation preparation for the ability rework."""

import math

import bmesh
import bpy
from mathutils import Vector


def rgba(hex_code):
    rgb = [int(hex_code[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return (*(c / 12.92 if c < .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb), 1)


def material(name, hex_code, *, emission=0, metal=0, alpha=1):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    color = rgba(hex_code)
    mat.diffuse_color = (*color[:3], alpha)
    shader = mat.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = .58
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Alpha"].default_value = alpha
    shader.inputs["Emission Color"].default_value = color
    shader.inputs["Emission Strength"].default_value = emission
    mat["rbx_color"] = hex_code
    mat["rbx_material"] = "Neon" if emission else ("Metal" if metal > .3 else "SmoothPlastic")
    if alpha != 1:
        mat["rbx_transparency"] = 1 - alpha
    return mat


class Parts:
    def __init__(self, name, collection=None):
        self.name = name
        self.collection = bpy.data.collections.new(name) if collection is None else collection

    def mesh(self, name, points, faces, mat, *, pivot=(0, 0, 0)):
        name = f"{self.name}_{name}"
        data = bpy.data.meshes.new(name)
        data.from_pydata([Vector(point) - Vector(pivot) for point in points], [], faces)
        data.materials.append(mat)
        bm = bmesh.new()
        bm.from_mesh(data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(data)
        bm.free()
        data.update()
        obj = bpy.data.objects.new(name, data)
        obj.location = pivot
        self.collection.objects.link(obj)
        return obj

    def point(self, name, at):
        obj = bpy.data.objects.new(f"{self.name}_{name}", None)
        obj.location = at
        obj.empty_display_type = "PLAIN_AXES"
        obj.empty_display_size = .035
        self.collection.objects.link(obj)
        return obj

    def loft(self, name, sections, mat, *, pivot=(0, 0, 0)):
        n = len(sections[0])
        points = [p for section in sections for p in section]
        faces = [tuple(reversed(range(n)))]
        for base in range(0, len(points) - n, n):
            faces.extend((base + i, base + (i + 1) % n, base + (i + 1) % n + n, base + i + n)
                         for i in range(n))
        faces.append(tuple(range(len(points) - n, len(points))))
        return self.mesh(name, points, faces, mat, pivot=pivot)

    def prism(self, name, tiers, mat, *, cut=.24, pivot=(0, 0, 0)):
        # Each tier gives height, center x/y, and half-extents.
        return self.loft(name, [[(x, y, z) for x, y in corners(cx, cy, w, d, cut)]
                                for z, cx, cy, w, d in tiers], mat, pivot=pivot)

    def radial(self, name, tiers, mat, *, sides=8, phase=math.pi / 8, pivot=(0, 0, 0)):
        return self.loft(name, [
            [(cx + radius * math.cos(a), cy + radius * math.sin(a), z)
             for a in angles(sides, phase)] for z, cx, cy, radius in tiers
        ], mat, pivot=pivot)

    def beam(self, name, start, end, widths, mat, *, pivot=None, cut=.34):
        start, end = Vector(start), Vector(end)
        axis = end - start
        rotation = axis.to_track_quat("Z", "Y")
        sections = [[start + rotation @ Vector((x, y, axis.length * f))
                     for x, y in corners(0, 0, w, d, cut)] for f, w, d in widths]
        return self.loft(name, sections, mat, pivot=start if pivot is None else pivot)

    def silhouette(self, name, outline, near, far, mat, *, pivot=(0, 0, 0)):
        return self.loft(name, [[(x, y, z) for x, z in outline] for y in (near, far)],
                         mat, pivot=pivot)

    def ring(self, name, profile, mat, *, sides=12, phase=0, pivot=(0, 0, 0)):
        """A closed ring. Profile points are radius and height."""
        points = [(r * math.cos(a), r * math.sin(a), z)
                  for r, z in profile for a in angles(sides, phase)]
        faces = []
        for row in range(len(profile)):
            j = (row + 1) % len(profile)
            faces.extend((row * sides + i, row * sides + (i + 1) % sides,
                          j * sides + (i + 1) % sides, j * sides + i) for i in range(sides))
        return self.mesh(name, points, faces, mat, pivot=pivot)


def angles(n, phase=0):
    return (phase + math.tau * i / n for i in range(n))


def corners(cx, cy, x, y, fraction):
    points = [(-x + x * fraction, -y), (x - x * fraction, -y), (x, -y + y * fraction),
              (x, y - y * fraction), (x - x * fraction, y), (-x + x * fraction, y),
              (-x, y - y * fraction), (-x, -y + y * fraction)]
    return [(cx + px, cy + py) for px, py in points]


def prepare_molly(parts, source_objects):
    """Clone the approved visual and preserve each animation target as one MeshPart."""
    targets = {"Lever": "Lever", "Pin": "Pin", "CapPlate": "PrimePad"}
    copies = {}
    for obj in source_objects:
        key = obj.name.split(".")[0].removeprefix("Molly_")
        target = targets.get(key, key)
        copy = obj.copy()
        if obj.type == "MESH":
            copy.data = obj.data.copy()
        copy.name = f"Molly_{target}"
        parts.collection.objects.link(copy)
        copies[target] = copy
        if key in targets:
            # The existing FBX exporter separates multi-material objects.
            index = 0 if key != "Pin" else 1
            primary = copy.data.materials[index]
            copy.data.materials.clear()
            copy.data.materials.append(primary)
            for face in copy.data.polygons:
                face.material_index = 0

    lever = copies["Lever"]
    pin = copies["Pin"]
    pad = copies["PrimePad"]
    def move_origin(obj, desired):
        local_shift = Vector(desired) - obj.location
        for vertex in obj.data.vertices:
            vertex.co -= local_shift
        obj.location += local_shift
        obj.data.update()

    move_origin(lever, (pin.location.x, 0, pin.location.z))
    pad_center = sum((vertex.co for vertex in pad.data.vertices), Vector()) / len(pad.data.vertices)
    move_origin(pad, pad.location + pad_center)
    parts.point("LeverPivot", lever.location)
    parts.point("PinPivot", pin.location)
    parts.point("PinPull", pin.location + Vector((0, -.11, 0)))
    parts.point("PrimePadPivot", pad.location)
    parts.point("PrimePadPressed", pad.location + Vector((0, 0, -.008)))
    parts.collection["kind"] = "thrown"
    return copies
