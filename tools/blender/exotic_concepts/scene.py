"""Geometry, rig, and review-stage helpers for isolated Blender concepts."""

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / "art-source/weapons"
VAULT = ROOT / "vault/02 Art/Skins"


def rgb(hex_color):
    return tuple(int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4))


def material(name, color, metal=0, roughness=.45, alpha=1, emission=0):
    color = tuple(c / 12.92 if c < .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb(color))
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, alpha)
    mat.metallic = metal
    mat.roughness = roughness
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = mat.diffuse_color
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Alpha"].default_value = alpha
    shader.inputs["Emission Color"].default_value = (*color, 1)
    shader.inputs["Emission Strength"].default_value = emission
    if alpha < 1:
        mat.surface_render_method = "BLENDED"
    return mat


def collection(scene, name):
    col = bpy.data.collections.new(name)
    scene.collection.children.link(col)
    return col


def mesh(col, name, verts, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    data.update()
    ob = bpy.data.objects.new(name, data)
    col.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def prism(col, name, outline, y_inner, y_outer, mat, bevel=0):
    """A closed X/Z profile with optional planar edge chamfer on the outer face."""
    count = len(outline)
    center = sum((Vector(point) for point in outline), Vector((0, 0))) / count
    rings = [(outline, y_inner)]
    if bevel:
        rings.append((outline, y_outer - math.copysign(bevel, y_outer - y_inner)))
        bevel_outline = []
        for point in outline:
            delta = center - Vector(point)
            bevel_outline.append(Vector(point) + delta.normalized() * min(delta.length * .2, bevel))
        rings.append((bevel_outline, y_outer))
    else:
        rings.append((outline, y_outer))
    verts = [(x, y, z) for ring, y in rings for x, z in ring]
    faces = [tuple(reversed(range(count)))]
    for ring in range(len(rings) - 1):
        a, b = ring * count, (ring + 1) * count
        for i in range(count):
            j = (i + 1) % count
            faces.append((a + i, a + j, b + j, b + i))
    faces.append(tuple(range(len(verts) - count, len(verts))))
    return mesh(col, name, verts, faces, mat)


def cut(x0, x1, z0, z1, corner):
    c = min(corner, (x1 - x0) * .35, (z1 - z0) * .42)
    return [(x0+c,z0), (x1-c,z0), (x1,z0+c), (x1,z1-c),
            (x1-c,z1), (x0+c,z1), (x0,z1-c), (x0,z0+c)]


def profile_ring(col, name, center, radii, thickness, depth, mat, facets=10):
    x, y, z = center
    rx, rz = radii
    verts = []
    for d in (-depth / 2, depth / 2):
        for wall in (0, thickness):
            verts.extend((x + (rx-wall)*math.cos(i*math.tau/facets), y+d,
                          z + (rz-wall)*math.sin(i*math.tau/facets)) for i in range(facets))
    faces = []
    for a, b in [(0, facets), (facets, 3*facets), (3*facets, 2*facets), (2*facets, 0)]:
        for i in range(facets):
            j = (i+1) % facets
            faces.append((a+i, a+j, b+j, b+i))
    return mesh(col, name, verts, faces, mat)


def loft(col, name, rings, facets, mat):
    """Flat-sided rings normal to Z, with explicit center, radius and station height."""
    verts = [(x + rx*math.cos(math.tau*(i+.5)/facets), y + ry*math.sin(math.tau*(i+.5)/facets), z)
             for x, y, z, rx, ry in rings for i in range(facets)]
    faces = [tuple(range(facets)), tuple(range(len(verts)-facets,len(verts)))]
    for k in range(len(rings)-1):
        a, b = k*facets, (k+1)*facets
        for i in range(facets):
            j = (i+1) % facets
            faces.append((a+i,a+j,b+j,b+i))
    return mesh(col,name,verts,faces,mat)


def beam(col,name,a,b,radius,mat,facets=8,taper=.85):
    a,b=Vector(a),Vector(b)
    axis=(b-a).normalized()
    rot=axis.to_track_quat("Z","Y")
    verts=[p+rot@Vector((radius*s*math.cos(i*math.tau/facets),radius*s*math.sin(i*math.tau/facets),0))
           for p,s in ((a,1),(b,taper)) for i in range(facets)]
    faces=[tuple(range(facets)),tuple(range(facets,2*facets))]
    for i in range(facets):
        j=(i+1)%facets
        faces.append((i,j,j+facets,i+facets))
    return mesh(col,name,verts,faces,mat)


def glove(col,name,anchor,left=False,forearm=None,size=1):
    """Faceted posing proxy, with a palm, four curled fingers, thumb and cuff."""
    p=Vector(anchor)
    sign=1 if left else -1
    leather=material("Pose proxy / slate textile","4A5662",roughness=.89)
    panel=material("Pose proxy / palm guard","38414B",roughness=.83)
    sleeve=material("Pose proxy / sleeve","283343",roughness=.92)
    def point(a,b,c):
        return p+Vector((a,b*sign,c))*size
    hand=[beam(col,name+" palm",point(-.073,.054,-.057),point(.017,.043,-.022),.073*size,leather,8,.83)]
    for i in range(4):
        x=-.055+i*.036
        a=point(x,.084,-.01)
        b=point(x,.029,.037-i*.004)
        c=point(x,-.019,.018-i*.004)
        hand.extend((beam(col,name+f" finger {i+1} base",a,b,.021*size,panel,6,.91),
                     beam(col,name+f" finger {i+1} return",b,c,.018*size,leather,6,.78)))
    hand.extend([beam(col,name+" thumb",point(-.10,.055,-.032),point(-.065,-.025,.028),.026*size,leather,7),
                 beam(col,name+" cuff",point(-.17,.09,-.10),point(-.057,.062,-.051),.073*size,panel)])
    if forearm:
        hand.append(beam(col,name+" sleeve",forearm,point(-.13,.077,-.082),.104*size,sleeve,8,.72))
    return hand


def locator(col, name, location, size=.045):
    ob = bpy.data.objects.new(name, None)
    col.objects.link(ob)
    ob.location = location
    ob.empty_display_type = "PLAIN_AXES"
    ob.empty_display_size = size
    return ob


def bind(ob, parent, bone=None):
    bpy.context.view_layer.update()
    world = ob.matrix_world.copy()
    ob.parent = parent
    if bone:
        ob.parent_type = "BONE"
        ob.parent_bone = bone
        pb = parent.pose.bones[bone]
        transform = parent.matrix_world @ pb.matrix @ Matrix.Translation((0, pb.length, 0))
    else:
        transform = parent.matrix_world
    ob.matrix_parent_inverse = transform.inverted_safe()
    ob.matrix_basis = world


def pivot(col, name, location, objects, parent=None, bone=None):
    ob = locator(col, name, location)
    if parent:
        bind(ob, parent, bone)
    for piece in objects:
        bind(piece, ob)
    return ob


def pose(ob, frame, xyz=None, angles=None, scale=None):
    if xyz is not None:
        ob.location = xyz
        ob.keyframe_insert("location", frame=frame, group=ob.name)
    if angles is not None:
        ob.rotation_mode = "XYZ"
        ob.rotation_euler = tuple(math.radians(x) for x in angles)
        ob.keyframe_insert("rotation_euler", frame=frame, group=ob.name)
    if scale is not None:
        ob.scale = scale
        ob.keyframe_insert("scale", frame=frame, group=ob.name)


def armature(col, name, layout):
    data = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, data)
    col.objects.link(ob)
    ob.show_in_front = True
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for label, head, parent in layout:
        b = data.edit_bones.new(label)
        b.head = head
        b.tail = Vector(head) + Vector((0, .105, 0))
        if parent:
            b.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.select_set(False)
    return ob


def points(objects):
    bpy.context.view_layer.update()
    return [o.matrix_world @ v.co for o in objects if o.type == "MESH" for v in o.data.vertices]


def camera(col, name, at, direction, scale=None, distance=4, lens=48, clip=.01):
    target, direction = Vector(at), Vector(direction).normalized()
    data = bpy.data.cameras.new(name)
    cam = bpy.data.objects.new(name, data)
    col.objects.link(cam)
    cam.location = target + direction * distance
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    data.clip_start = clip
    if scale:
        data.type = "ORTHO"
        data.ortho_scale = scale
    else:
        data.lens = lens
        data.sensor_fit = "VERTICAL"
        data.sensor_height = 24
    return cam


def framed_camera(col, name, coords, direction, aspect=1.8, margin=1.1):
    cam = camera(col, name, (0, 0, 0), direction, scale=1)
    bpy.context.view_layer.update()
    basis = cam.matrix_world.to_3x3()
    inverse = basis.inverted()
    pts = [inverse @ p for p in coords]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    cam.location += basis @ ((lo + hi) / 2)
    cam.data.ortho_scale = max(hi.x - lo.x, (hi.y - lo.y) * aspect) * margin
    return cam


def setup(scene):
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_percentage = 100
    scene.render.fps = 24
    scene.view_settings.view_transform = "Standard"
    shade = scene.display.shading
    shade.light = "STUDIO"
    shade.studiolight_rotate_z = .2
    shade.studio_light = "studio.sl"
    shade.color_type = "MATERIAL"
    shade.show_shadows = False
    shade.show_cavity = True
    shade.cavity_type = "BOTH"
    shade.cavity_ridge_factor = .85
    shade.cavity_valley_factor = .75
    shade.curvature_ridge_factor = .7
    shade.curvature_valley_factor = .7
    shade.show_specular_highlight = True
    shade.show_backface_culling = True
    scene.display.render_aa = "8"


def render(scene, cam, path, frame, size):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.frame_set(frame)
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True, scene=scene.name)


def marker(scene, name, frame):
    scene.timeline_markers.new(name, frame=frame)
