"""Faceted walnut shells and mineral insets for the Rootglass cosmetic line."""

import bmesh
import bpy
from mathutils import Matrix, Vector

from build_skin_roster import Nodes
from skin_graphics import linear


# Host, centre X/Z, half length/height, mineral profile. The dimensions are
# in the stock part's rest space and leave its controls and seams exposed.
MOUNTS = {
    "Vandal": ("Handguard", 1.34, .309, .324, .093, "hero"),
    "Phantom": ("Handguard", 1.27, .305, .335, .099, "long"),
    "Bulldog": ("Receiver", -.060, .443, .311, .060, "oval"),
    "Guardian": ("Handguard", 1.76, .335, .536, .081, "long"),
    "Spectre": ("Handguard", .914, .365, .197, .078, "leaf"),
    "Stinger": ("Receiver", -.286, .361, .155, .064, "leaf"),
    "Ares": ("Receiver", .709, .422, .477, .085, "hero"),
    "Odin": ("Receiver", 1.516, .317, .490, .124, "hero"),
    "Sheriff": ("Barrel", .985, .267, .220, .073, "oval"),
    "Classic": ("Slide", .550, .403, .283, .066, "oval"),
    "Ghost": ("Slide", .533, .326, .430, .063, "long"),
    "Shorty": ("Frame", .355, .196, .181, .075, "oval"),
    "Bucky": ("Receiver", .333, .302, .292, .100, "oval"),
    "Judge": ("Receiver", .760, .475, .474, .133, "hero"),
    "Marshal": ("Receiver", .507, .128, .339, .064, "long"),
    "Outlaw": ("Receiver", .599, .313, .352, .092, "long"),
    "Operator": ("Handguard", 1.580, .285, .472, .103, "long"),
}

SHELL = (
    (-1, -.18), (-.87, .30), (-.55, .77), (-.21, .90),
    (.30, .94), (.80, .86), (1, .38), (.91, -.18),
    (.64, -.62), (.31, -.75), (-.31, -.92), (-.79, -.76),
)
WINDOWS = {
    "hero": (
        (-1,-.38),(-.90,.10),(-.64,.67),(-.35,.86),(.24,.94),(.74,.87),
        (1,.51),(.90,.03),(.71,-.55),(.47,-.78),(-.41,-.92),(-.81,-.77),
    ),
    "oval": (
        (-1,-.05),(-.89,.41),(-.59,.77),(-.26,.96),(.30,.94),(.65,.74),
        (1,.30),(.95,-.21),(.66,-.64),(.27,-.88),(-.42,-.90),(-.80,-.55),
    ),
    "leaf": (
        (-1,-.40),(-.85,-.12),(-.58,.28),(-.20,.70),(.37,.96),(.82,.77),
        (1,.42),(.94,-.11),(.70,-.63),(.32,-.88),(-.38,-.84),(-.76,-.64),
    ),
    "long": (
        (-1,-.24),(-.85,.33),(-.59,.72),(-.24,.86),(.32,.89),(.81,.75),
        (1,.35),(.95,-.21),(.72,-.65),(.31,-.79),(-.40,-.86),(-.78,-.70),
    ),
}
PALETTE = {
    "Walnut": ("3B2926", .37, .0),
    "Satin Walnut": ("54372C", .34, .0),
    "Carved Walnut": ("2C1E1B", .44, .0),
    "Umber": ("221C19", .68, .0),
    "Gasket": ("1A211C", .62, .0),
    "Bronze": ("A48358", .32, .65),
    "Bronze Seat": ("745638", .43, .53),
    "Moss": ("26745E", .24, .12),
    "Green Depth": ("448F74", .20, .10),
    "Green Facet": ("67B18D", .23, .08),
    "Amber Vein": ("F1B65A", .32, .32),
    "Pale Bevel": ("DDD4B8", .32, .46),
    "Blade Core": ("302B26", .39, .42),
    "Metal": ("423832", .45, .44),
}


def rgb(hexcode):
    return (*linear(hexcode), 1)


def finish(material, role):
    color, roughness, metalness = PALETTE[role]
    graph = Nodes(material.node_tree)
    tree = material.node_tree
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    material.diffuse_color = rgb(color)
    material.roughness = roughness
    material.metallic = metalness
    graph.set(bsdf.inputs["Base Color"], rgb(color))
    graph.set(bsdf.inputs["Roughness"], roughness)
    graph.set(bsdf.inputs["Metallic"], metalness)
    if "Walnut" in role:
        tex = graph.node("TexCoord", "Grain in part space")
        stretch = graph.node("VectorMath", "Grain along length", operation="MULTIPLY")
        graph.set(stretch.inputs[0], tex.outputs["Object"])
        stretch.inputs[1].default_value = (2.9, 35, 61)
        noise = graph.node("TexNoise", "Walnut grain")
        noise.inputs["Scale"].default_value = 2.1
        noise.inputs["Detail"].default_value = 2.2
        graph.set(noise.inputs["Vector"], stretch.outputs[0])
        c = linear(color)
        tone = graph.mix(noise.outputs["Fac"], (*(v*.62 for v in c), 1),
                         (*(v*1.55 for v in c), 1), color=True)
        graph.set(bsdf.inputs["Base Color"], tone)
        bump = graph.node("Bump", "Fine walnut texture")
        bump.inputs["Strength"].default_value = .10
        bump.inputs["Distance"].default_value = .003
        graph.set(bump.inputs["Height"], noise.outputs["Fac"])
        graph.set(bsdf.inputs["Normal"], bump.outputs[0])
        bsdf.inputs["Coat Weight"].default_value = .12
        bsdf.inputs["Coat Roughness"].default_value = .4
    if role in {"Moss", "Green Depth", "Green Facet"}:
        bsdf.inputs["Coat Weight"].default_value = .66
        bsdf.inputs["Coat Roughness"].default_value = .11
    material["rootglass_finish"] = role
    return material


def palette():
    materials = {}
    for role in PALETTE:
        mat = bpy.data.materials.new(f"Rootglass {role}")
        mat.use_nodes = True
        materials[role] = finish(mat, role)
    return materials


def reskin_stock(materials):
    for name, role in (("Body","Walnut"),("Panel","Carved Walnut"),("Dark","Umber"),
                       ("Grip","Umber"),("Metal","Metal"),("Accent","Metal")):
        mat = next((m for m in materials if m.name == name), None)
        if mat and mat.use_nodes:
            finish(mat, role)


def ring_mesh(name, collection, rig, bone, rings, bands, caps=None):
    """Make an outward-facing shell, including its hidden seating surfaces."""
    count = len(rings[0])
    verts = [point for ring in rings for point in ring]
    index = []
    faces = []
    roles = []

    def face(vertices, material):
        if material not in roles:
            roles.append(material)
        faces.append(vertices)
        index.append(roles.index(material))

    for station, materials in enumerate(bands):
        a, b = station * count, ((station + 1) % len(rings)) * count
        for i in range(count):
            j = (i+1) % count
            mat = materials[i % len(materials)] if isinstance(materials, tuple) else materials
            face((a+i, a+j, b+j, b+i), mat)
    if caps:
        face(tuple(range(count)), caps[0])
        face(tuple(range(len(verts)-count, len(verts))), caps[1])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    for mat in roles:
        mesh.materials.append(mat)
    for p, i in zip(mesh.polygons, index):
        p.material_index = i
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), name
    assert all(face.calc_area() > 1e-9 for face in bm.faces), name
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    collection.objects.link(ob)
    ob.parent = rig
    ob.parent_type = "BONE"
    ob.parent_bone = bone
    bpy.context.view_layer.update()
    ob.matrix_world = Matrix.Identity(4)
    return ob


def coords(shape, cx, cz, width, height, y, side):
    return [(cx + x*width, side*y, cz + z*height) for x, z in shape]


def vein(name, collection, rig, bone, mat, points, side, radius):
    rings = []
    for i, p in enumerate(points):
        p = Vector(p)
        tangent = Vector(points[min(i+1,len(points)-1)]) - Vector(points[max(0,i-1)])
        across = Vector((-tangent.z, 0, tangent.x)).normalized()
        taper = radius * (.48 if i in (0,len(points)-1) else 1)
        v = across * taper
        depth = Vector((0, side*taper*.55, 0))
        rings.append([p+v, p+depth, p-v, p-depth])
    return ring_mesh(name, collection, rig, bone, rings, [mat]*(len(rings)-1), (mat,mat))


def specimen(name, collection, rig, bone, mats, cx, cz, width, height, y, side, profile, lift):
    outer = WINDOWS[profile]
    well = lambda w,h,depth: coords(outer,cx,cz,width*w,height*h,y+depth,side)
    ring_mesh(name+"_BronzeSeat", collection, rig, bone,
              [well(1,1,lift-.010), well(1,1,lift+.0015), well(.934,.88,lift+.0005),
               well(.900,.82,lift-.0065), well(.90,.82,lift-.010)],
              [mats["Gasket"],mats["Bronze"],mats["Bronze Seat"],mats["Gasket"],mats["Gasket"]])
    glass = (mats["Moss"],mats["Green Depth"],mats["Moss"],mats["Green Facet"],
             mats["Green Depth"],mats["Moss"],mats["Green Depth"],mats["Moss"])
    ring_mesh(name+"_FacetedMineral",collection,rig,bone,
              [well(.912,.84,lift-.009),well(.912,.84,lift-.004),well(.712,.55,lift+.001)],
              [mats["Moss"],glass],(mats["Moss"],mats["Moss"]))
    trunk = [(-.52,-.29),(-.25,-.085),(.02,-.03),(.22,.05),(.39,.19),(.61,.32)]
    branches = [[(-.25,-.085),(-.25,.06),(-.16,.28)],[(.22,.05),(.34,.046),(.48,.106)]]
    if profile == "leaf":
        branches = branches[:1]
    size = max(.00125, min(height*.057, .0043))
    for i, path in enumerate([trunk,*branches]):
        points = coords(path,cx,cz,width,height,y+lift+.0008,side)
        ob = vein(name+f"_AmberVein_{i+1}",collection,rig,bone,mats["Amber Vein"],points,
                  side,size*(1 if i==0 else .55))
        ob["inspect_pulse_target"] = True
        ob["pulse_path_direction"] = "+X along the primary vein"


def shell(name, collection, rig, bone, mats, cx, cz, dx, dz, y, side, profile):
    inner = WINDOWS[profile]
    inset = lambda w,h,depth: coords(inner,cx,cz,dx*w,dz*h,y+depth,side)
    outer = lambda w,h,depth: coords(SHELL,cx,cz,dx*w,dz*h,y+depth,side)
    depth = .015 if dx < .34 else .024
    ring_mesh(name+"_CarvedShell",collection,rig,bone,[
        outer(.99,.97,-.027), outer(1,1,.002), outer(.92,.91,depth+.007),
        inset(.705,.60,depth+.012), inset(.675,.535,depth+.008),
        inset(.665,.527,depth-.008), inset(.665,.527,-.027),
    ],[mats["Carved Walnut"],mats["Carved Walnut"],
       (mats["Walnut"],mats["Satin Walnut"],mats["Satin Walnut"],mats["Walnut"],
        mats["Satin Walnut"],mats["Walnut"],mats["Carved Walnut"],mats["Carved Walnut"]),
       mats["Satin Walnut"],mats["Carved Walnut"],mats["Gasket"],mats["Gasket"]])
    specimen(name,collection,rig,bone,mats,cx,cz,dx*.684,dz*.565,y,side,profile,depth+.002)


def plate(name, collection, rig, bone, mats, shape, y, side, thickness, role="Walnut"):
    cx = sum(x for x,z in shape)/len(shape)
    cz = sum(z for x,z in shape)/len(shape)
    def contour(scale, reach):
        return [(cx+(x-cx)*scale,side*(y+reach),cz+(z-cz)*scale) for x,z in shape]
    return ring_mesh(name,collection,rig,bone,
                     [contour(1,-.032),contour(1,.002),contour(.91,thickness)],
                     [mats["Carved Walnut"], mats["Satin Walnut"]],
                     (mats["Carved Walnut"], mats[role]))


def gun(item, collection, rig, mats):
    host, cx, cz, dx, dz, profile = MOUNTS[item]
    ob = bpy.data.objects[f"{item}_{host}"]
    from mathutils.bvhtree import BVHTree
    points = [ob.matrix_world @ v.co for v in ob.data.vertices]
    tree = BVHTree.FromPolygons(points,[list(f.vertices) for f in ob.data.polygons])
    y = min(max(abs(p.y) for p in points), .109)
    hit = tree.ray_cast((cx,1,cz),(0,-1,0),.999)[0]
    if hit:
        y = max(abs(hit.y),y-.012)
    sides = (1,-1) if item in {"Classic","Ghost","Guardian","Outlaw"} else (1,)
    for side in sides:
        suffix = "Left" if side==1 else "Right"
        shell(f"Rootglass_{suffix}",collection,rig,ob.parent_bone,mats,
              cx,cz,dx,dz,y,side,profile)
    if item == "Vandal":
        lower = [(.150,.256),(.258,.268),(.457,.268),(.697,.269),(.924,.269),
                 (1.034,.260),(.929,.249),(.675,.247),(.411,.247),(.241,.245)]
        upper = [(-.146,.346),(-.062,.394),(.17,.408),(.50,.415),(.83,.407),(1.10,.391),
                 (1.05,.369),(.77,.370),(.39,.381),(.122,.360),(-.075,.341)]
        plate("Rootglass_LowerWalnutLeaf",collection,rig,"Root",mats,lower,.082,1,.016)
        plate("Rootglass_UpperWalnutLeaf",collection,rig,"Root",mats,upper,.084,1,.019)
        right = [(.994,.229),(1.080,.316),(1.25,.347),(1.57,.357),(1.64,.297),
                 (1.58,.214),(1.28,.170),(1.10,.171)]
        plate("Rootglass_RightWalnutCheek",collection,rig,"Root",mats,right,.085,-1,.024)
    return {"host": ob.name, "bone": ob.parent_bone,
            "window_center": [cx,y+.02,cz], "width": dx*2, "height": dz*2,
            "specimen_profile": profile}


def leafblade(collection, rig, mats):
    shape = [(.341,-.049),(.341,.051),(.423,.060),(.538,.110),(.676,.146),
             (.811,.141),(.969,.102),(1.101,.051),(1.267,-.020),(1.069,-.092),
             (.913,-.123),(.729,-.134),(.548,-.110),(.424,-.066)]
    center = Vector((.72,0,0))
    def blade_ring(scale, depth):
        ring = []
        for x,z in shape:
            # A longer base tang continues inside the stock collar.
            inner_x = x if x < .36 else center.x + (x-center.x)*scale
            ring.append((inner_x,depth,center.z+(z-center.z)*scale))
        return ring
    ring_mesh("Rootglass_BroadLeafBlade",collection,rig,"Root",
              [blade_ring(.837,-.016),blade_ring(1,-.0015),
               blade_ring(1,.0015),blade_ring(.837,.016)],
              [mats["Pale Bevel"]]*3,(mats["Blade Core"],mats["Blade Core"]))
    hilt = bpy.data.objects["Knife_Hilt"]
    hilt.data.materials.append(mats["Bronze"])
    hilt.data.materials.append(mats["Satin Walnut"])
    for p in hilt.data.polygons:
        center = hilt.matrix_world @ p.center
        if center.x >= .304 or center.x < -.345:
            p.material_index = len(hilt.material_slots)-2
        elif abs(p.normal.y) > .85:
            p.material_index = len(hilt.material_slots)-1
    for side in (1,-1):
        specimen("Rootglass_Spine"+("Left" if side==1 else "Right"),collection,rig,"Root",mats,
                 .732,.023,.276,.042,.016,side,"leaf",.0055)
    for name in ("Knife_Blade","Knife_Neon"):
        ob = bpy.data.objects.get(name)
        if ob:
            ob.hide_set(True)
            ob.hide_render=True
    return {"host":"Knife_Hilt","bone":"Root","profile":"A / Broad Leaf",
            "window_center":[.732,.0215,.023],"width":.552,"height":.084}
