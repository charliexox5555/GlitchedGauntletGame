"""Loft the replacement Moltframe housings in the stock Vandal coordinates."""

import bmesh
from collections import defaultdict

# The stock rig, mechanical meshes and review cameras remain available for a
# matched render. Replace only the stock cosmetic housings and their markings.
replaced = {"Receiver", "Handguard", "Stock", "Pins", "Neon", "Rail", "Mag", "Grip", "Barrel"}
original_visibility = {name: source_meshes[name].hide_render for name in replaced}

def link_housing(name, mesh, bone="Root"):
    obj = bpy.data.objects.new(name, mesh)
    shell.objects.link(obj)
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    scene.view_layers[0].update()
    obj.matrix_world.identity()
    scene.view_layers[0].update()
    return obj

def retain_components(name, predicate):
    source = source_meshes[name]
    connected = defaultdict(set)
    for polygon in source.data.polygons:
        for index in polygon.vertices:
            connected[index].update(polygon.vertices)
    keep, visited = set(), set()
    for index in connected:
        if index in visited:
            continue
        group = {index}
        search = [index]
        while search:
            found = connected[search.pop()] - group
            group.update(found)
            search.extend(found)
        visited.update(group)
        if predicate([source.data.vertices[i].co for i in group]):
            keep.update(group)
    copy = source.data.copy()
    mesh = bmesh.new()
    mesh.from_mesh(copy)
    mesh.verts.ensure_lookup_table()
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if v.index not in keep], context="VERTS")
    mesh.to_mesh(copy)
    mesh.free()
    obj = link_housing("Moltframe_" + name + "Hardware", copy, source.parent_bone)
    for index, slot in enumerate(obj.material_slots):
        slot.material = skin_materials.get((name, index), slot.material)
    return obj

retain_components("Receiver", lambda pts: max(p.z for p in pts) < .17 or min(p.y for p in pts) < -.10)
retain_components("Handguard", lambda pts: min(p.x for p in pts) > 1.63 or max(p.z for p in pts) < .177)
retain_components("Stock", lambda pts: max(p.x for p in pts) < -1.095)
retain_components("Pins", lambda pts: min(p.x for p in pts) > 2)
retain_components("Mag", lambda pts: min(p.z for p in pts) > .08 or max(p.z for p in pts) < -.30)
retain_components("Grip", lambda pts: True)

body = material("Moltframe dry graphite", "2A2F40", .42, .37)
well = material("Moltframe mechanism well", "181922", .58, .22)
edge_alloy = material("Moltframe turned edge", "838DA4", .32, .65)
for mat in (body, edge_alloy, well):
    mat.node_tree.nodes.get("Principled BSDF").inputs["Coat Weight"].default_value = .07
materials = [alloy, fluid, body, well, edge_alloy]
ARMOUR, FLUID, BODY, WELL, EDGE = range(len(materials))

def shell_section(top, bottom, side, shoulder, low, high, power, depth):
    """One ring from the crown to the underside, with an inset between hard lips."""
    crown = min(.060, side * .77)
    recess = power * depth
    lip = min(.010, (high - low) * .19)
    return [
        (crown, top),
        (crown + .009, top - .004),
        (side * .94, top - .024),
        (shoulder, high + .020),
        (shoulder * .97, high + .007),
        (side * .94, high),
        (side * .94 - recess, high - lip),
        (side * .92 - recess, high * .7 + low * .3),
        (side * .90 - recess, high * .3 + low * .7),
        (side * .88 - recess, low + lip),
        (side * .90, low),
        (side * .94, low - .005),
        (side * .91, bottom + .014),
        (side * .78, bottom),
    ]

def loft(name, keys, steps=27, windows=(), depth=.021):
    """Closed, low-poly housing. Rings carry topology through folds and recess."""
    length = keys[-1][0] - keys[0][0]
    station_x = sorted({key[0] for key in keys} | {x for pair in windows for x in pair}
                       | {keys[0][0] + i * length / steps for i in range(1, steps)})
    section_width = 28
    vertices, faces, roles, tex = [], [], [], []
    for x in station_x:
        top, bottom, side, shoulder, low, high, power = [curve(keys, x, col) for col in range(1, 8)]
        left = shell_section(top, bottom, side, shoulder, low, high, power, depth)
        vertices.extend([(x, y, z) for y, z in left] + [(x, -y, z) for y, z in reversed(left)])
        tex.append((x - keys[0][0]) / length)
    # Per-corner UVs preserve the graphic through the longitudinal folds.
    left_v = [.96, .94, .78, .65, .58, .53, .46, .38, .19, .07, .53, .62, .72, .95]
    section_v = left_v + left_v[::-1]
    def add(face, role, uv):
        faces.append(face)
        roles.append(role)
        texcoords.append(uv)
    texcoords = []
    for i, (x0, x1) in enumerate(zip(station_x, station_x[1:])):
        x = (x0 + x1) * .5
        recessed = curve(keys, x, 7) > .18
        window = next(((start, end) for start, end in windows if start < x < end), None)
        for j in range(section_width):
            k = (j + 1) % section_width
            band = j if j < 13 else 26 - j if 14 <= j <= 26 else -1
            role = BODY
            if band in {1, 2, 3, 4, 10, 11}:
                role = ARMOUR
            elif band in {0, 12}:
                role = EDGE
            if recessed and band in {5, 9}:
                role = WELL
            elif recessed and band in {6, 7, 8}:
                role = FLUID if window else WELL
            a, b = i * section_width, (i + 1) * section_width
            u0, u1 = tex[i], tex[i+1]
            if role == FLUID:
                u0, u1 = ((position-window[0])/(window[1]-window[0]) for position in (x0,x1))
            add((a+j, b+j, b+k, a+k), role,
                [(u0, section_v[j]), (u1, section_v[j]),
                 (u1, section_v[k]), (u0, section_v[k])])
    for i, ring in ((0, tuple(reversed(range(section_width)))),
                    (len(station_x)-1, tuple(range(section_width)))):
        # Fan cap avoids triangulation ambiguity at the concave recess.
        center_index = len(vertices)
        points = [vertices[i * section_width + j] for j in ring]
        vertices.append((station_x[i], 0, (max(p[2] for p in points) + min(p[2] for p in points))/2))
        for j, k in zip(ring, ring[1:] + ring[:1]):
            add((center_index, i*section_width+j, i*section_width+k), BODY, [(.5,.5)] * 3)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    for mat in materials:
        mesh.materials.append(mat)
    uv = mesh.uv_layers.new(name="Moltframe")
    for polygon, role, coords in zip(mesh.polygons, roles, texcoords):
        polygon.material_index = role
        polygon.use_smooth = True
        for loop, coordinate in zip(polygon.loop_indices, coords):
            uv.data[loop].uv = coordinate
    mesh.validate()
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    for edge in bm.edges:
        edge.smooth = edge.is_manifold and edge.calc_face_angle(0) < math.radians(39)
    bm.to_mesh(mesh)
    bm.free()
    obj = link_housing(name, mesh)
    return obj

# x, crown, underside, cheek, shoulder, lower/upper chamber lips, depth.
receiver = loft("Moltframe_Receiver", [
    (-.177,.392,.184,.074,.079,.223,.248,0),
    (-.105,.422,.151,.083,.098,.210,.251,.30),
    (.042,.437,.167,.090,.103,.200,.226,.38),
    (.183,.422,.181,.096,.115,.218,.278,1),
    (.302,.409,.178,.092,.109,.209,.243,.45),
    (.373,.410,.176,.093,.108,.210,.246,.33),
    (.501,.407,.171,.102,.110,.197,.249,1),
    (.650,.410,.164,.101,.111,.204,.241,.37),
    (.722,.416,.166,.092,.111,.218,.248,.46),
    (.861,.429,.172,.103,.118,.223,.294,1),
    (1.050,.398,.185,.086,.097,.231,.259,.33),
], windows=((.119,.289),(.384,.642),(.750,1.021)), depth=.010)
fore = loft("Moltframe_Forend", [
    (1.055,.396,.185,.085,.097,.225,.261,.36),
    (1.125,.419,.177,.093,.114,.216,.287,1),
    (1.219,.428,.170,.096,.116,.224,.261,.41),
    (1.297,.419,.170,.095,.111,.221,.295,1),
    (1.386,.407,.172,.093,.105,.233,.271,.42),
    (1.466,.386,.174,.091,.105,.236,.300,1),
    (1.564,.366,.188,.078,.090,.254,.286,.37),
    (1.647,.337,.227,.056,.066,.261,.275,0),
], windows=((1.071,1.202),(1.239,1.370),(1.411,1.548)))
stock = loft("Moltframe_StockSpine", [
    (-1.112,.410,.163,.066,.068,.233,.279,0),
    (-1.041,.424,.191,.073,.084,.243,.300,.65),
    (-.922,.419,.227,.070,.082,.272,.328,.78),
    (-.782,.393,.235,.064,.079,.279,.324,.64),
    (-.629,.371,.245,.057,.066,.276,.304,.22),
    (-.451,.357,.250,.049,.056,.277,.297,0),
    (-.263,.365,.239,.045,.050,.277,.297,0),
    (-.174,.380,.223,.046,.051,.268,.293,0),
], windows=((-1.051,-.801),))
# A swept lower strut retains the open stock profile and joins the stock spine
# farther forward. The rubber heel is the original stock part.
brace = loft("Moltframe_StockBrace", [
    (-1.112,.168,-.155,.056,.061,-.082,.004,0),
    (-1.068,.167,-.153,.056,.064,-.083,.005,0),
    (-.999,.165,-.104,.050,.057,-.025,.058,0),
    (-.906,.185,-.031,.045,.054,.024,.088,0),
    (-.808,.218,.046,.039,.047,.087,.139,0),
    (-.699,.255,.130,.033,.044,.163,.195,0),
    (-.608,.302,.218,.031,.040,.242,.265,0),
], steps=17)

def cut_well(obj, x, y, z, size, *, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z))
    tool = bpy.context.object
    tool.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    tool.rotation_euler.y = math.radians(angle)
    tool.data.materials.append(well)
    bevel = tool.modifiers.new("Rounded opening corners", "BEVEL")
    bevel.width = .009
    bevel.segments = 3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Recessed opening", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = tool
    mod.material_mode = "TRANSFER"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(tool, do_unlink=True)

# Charge handle travel crosses the left wall. The smaller right opening
# restores the stock ejection-side silhouette and exposes the preserved bolt.
cut_well(receiver, .540, .159, .309, (.547, .201, .086))
cut_well(receiver, .424, -.148, .311, (.489, .263, .116))
# Hollow the underside around the moving magazine and preserve the stock feed guide.
cut_well(receiver, .716, 0, .145, (.653, .150, .211), angle=-2)
# Fire selector has a shallow pocket on the outside face of the rear cheek.
cut_well(receiver, .065, .133, .244, (.101, .093, .136), angle=-17)

spine = loft("Moltframe_DorsalSpine", [
    (.197,.434,.389,.052,.058,.407,.417,0),
    (.244,.465,.402,.055,.069,.418,.439,0),
    (.408,.470,.403,.047,.061,.420,.441,0),
    (.625,.456,.401,.040,.053,.415,.437,0),
    (.826,.470,.401,.046,.061,.416,.441,0),
    (1.049,.458,.395,.040,.053,.412,.431,0),
    (1.220,.470,.396,.047,.060,.418,.438,0),
    (1.408,.458,.379,.040,.053,.403,.427,0),
    (1.591,.407,.361,.035,.044,.379,.396,0),
], steps=30)
for x, y, z in ((.53,.043,.451),(.74,.040,.449),(1.15,.039,.449),(1.35,.041,.443)):
    for side in (-1, 1):
        cut_well(spine, x, side*y, z, (.118,.038,.034), angle=-12)

# Paired chevron cuts in the forward shoulders. Depth tapers before the
# support-hand contact plane and leaves the lower armour wall continuous.
for x, width, z, angle in ((1.160,.027,.357,-29),(1.292,.032,.361,-33),(1.421,.033,.340,-35),(1.528,.025,.319,-33)):
    for side in (-1, 1):
        cut_well(fore, x, side*.113, z, (width,.075,.104), angle=angle)

# Matte ribbing within the existing contact surface. Tone changes at the
# heel and backstrap connect the grip to the new shell without widening it.
grip = next(o for o in shell.objects if o.name == "Moltframe_GripHardware")
grip_finish = material("Moltframe grip heel", "353744", .66, .10)
grip.data.materials.append(grip_finish)
for polygon in grip.data.polygons:
    if polygon.center.z < -.24 or (polygon.center.x < -.10 and polygon.center.z < -.085):
        polygon.material_index = len(grip.data.materials) - 1

def ring_mesh(name, rings, material_indices, bone="Root", angle_steps=14):
    vertices = []
    for x, z, ry, rz in rings:
        for i in range(angle_steps):
            angle = i * math.tau / angle_steps
            fluting = 1 - .12 * math.sin(3 * angle)**2 if 2.391 < x < 2.647 and ry > .025 else 1
            vertices.append((x, fluting*ry*math.cos(angle), z + fluting*rz*math.sin(angle)))
    faces, roles, coords = [], [], []
    for n, role in enumerate(material_indices):
        for i in range(angle_steps):
            j = (i+1) % angle_steps
            faces.append((n*angle_steps+i,n*angle_steps+j,(n+1)*angle_steps+j,(n+1)*angle_steps+i))
            roles.append(role)
            v = .56 + .37 * i / angle_steps
            coords.append([(n/len(rings),v),(n/len(rings),v+.37/angle_steps),
                           ((n+1)/len(rings),v+.37/angle_steps),((n+1)/len(rings),v)])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    for mat in materials:
        mesh.materials.append(mat)
    uv = mesh.uv_layers.new(name="Moltframe")
    for polygon, role, tex in zip(mesh.polygons, roles, coords):
        polygon.material_index = role
        polygon.use_smooth = True
        for index, coord in zip(polygon.loop_indices, tex):
            uv.data[index].uv = coord
    mesh.update()
    return link_housing(name, mesh, bone)

# The smooth barrel blends into a short open, fluted collar at the same tip.
ring_mesh("Moltframe_Barrel", [
    (1.554,.285,.032,.034),(1.645,.285,.045,.043),(1.765,.285,.031,.034),
    (2.09,.285,.028,.032),(2.306,.285,.035,.038),(2.392,.285,.046,.046),
    (2.439,.285,.051,.055),(2.460,.285,.053,.057),(2.481,.285,.042,.044),
    (2.508,.285,.053,.055),(2.529,.285,.049,.052),(2.553,.285,.040,.044),
    (2.578,.285,.050,.053),(2.612,.285,.050,.052),(2.647,.285,.040,.042),
    (2.647,.285,.022,.022),(2.613,.285,.019,.019),(2.568,.285,.016,.016),
], [BODY,ARMOUR,BODY,BODY,ARMOUR,ARMOUR,EDGE,WELL,ARMOUR,EDGE,WELL,ARMOUR,ARMOUR,EDGE,EDGE,WELL,WELL])

# A contoured replaceable magazine body follows the stock curve. The feed,
# cartridge and floorplate come from the stock model and stay on the Mag joint.
def magazine():
    keys = [(-.357,.710,.972),(-.321,.682,.950),(-.251,.638,.905),
            (-.162,.583,.838),(-.073,.539,.790),(.019,.507,.741),
            (.106,.479,.714),(.197,.466,.689)]
    verts, faces, roles, texcoords = [], [], [], []
    steps = 26
    ring = [(.00,.30),(.026,.65),(.105,.92),(.19,1.0),(.24,.78),(.29,.66),
            (.50,.72),(.68,.66),(.74,.79),(.82,1.0),(.92,.9),(.982,.64),(1.,.30)]
    section = ring + [(x,-y) for x,y in reversed(ring)]
    size = len(section)
    for i in range(steps + 1):
        t = i / steps
        z = keys[0][0] + t * (keys[-1][0] - keys[0][0])
        back, front = (curve(keys, z, c) for c in (1,2))
        active = min(1.0, max(0.0, min((t-.06)/.15,(.91-t)/.16)))
        active *= .4 + .6*math.sin(math.pi*3*t)**2
        for k, (fraction, side) in enumerate(section):
            nearest = min(k,size-1-k)
            is_inset = 4 <= nearest <= 8
            sweep = .07 * active * math.sin(t * math.pi * 1.2) * math.sin(math.pi*fraction)
            y = math.copysign(.055 * (abs(side) if not is_inset else 1 - active * (1 - abs(side))),side)
            verts.append((back + (front-back)*(fraction+sweep),y,z))
    for i in range(steps):
        t = (i+.5)/steps
        window = next(((start, end) for start, end in ((.13,.32),(.37,.59),(.65,.86)) if start < t < end),None)
        for j in range(size):
            k = (j+1) % size
            index = min(j, size-2-j)
            role = BODY
            if index in (1,2,3,8,9,10):
                role = ARMOUR
            elif index in (4,7):
                role = WELL if window else ARMOUR
            elif index in (5,6):
                role = FLUID if window else WELL
            faces.append((i*size+j,i*size+k,(i+1)*size+k,(i+1)*size+j))
            roles.append(role)
            uv0, uv1 = ((.12,.28) if index == 5 else (.28,.45)) if role == FLUID else (.62,.83)
            u0, u1 = i/steps, (i+1)/steps
            if role == FLUID:
                u0, u1 = [max(0,min(1,(u-window[0])/(window[1]-window[0]))) for u in (u0,u1)]
            texcoords.append([(u0,uv0),(u0,uv1),(u1,uv1),(u1,uv0)])
    for i in (0, steps):
        faces.append(tuple(range(i*size,(i+1)*size)))
        roles.append(BODY)
        texcoords.append([(.5,.8)] * size)
    mesh = bpy.data.meshes.new("Moltframe_Magazine")
    mesh.from_pydata(verts, [], faces)
    for mat in materials:
        mesh.materials.append(mat)
    uv = mesh.uv_layers.new(name="Moltframe")
    for polygon, role, tex in zip(mesh.polygons, roles, texcoords):
        polygon.material_index = role
        polygon.use_smooth = True
        for index, coord in zip(polygon.loop_indices, tex):
            uv.data[index].uv = coord
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    for edge in bm.edges:
        edge.smooth = edge.is_manifold and edge.calc_face_angle(0) < math.radians(42)
    bm.to_mesh(mesh)
    bm.free()
    return link_housing("Moltframe_Magazine", mesh, "Mag")

magazine()

def set_skin(enabled):
    for (name, index), base in original.items():
        source_meshes[name].material_slots[index].material = skin_materials.get((name, index), base) if enabled else base
    for name, was_hidden in original_visibility.items():
        source_meshes[name].hide_render = enabled or was_hidden
        source_meshes[name].hide_set(enabled or was_hidden)
    shell.hide_render = not enabled
    shell.hide_viewport = not enabled

stock_points = [o.matrix_world @ v.co for o in source_meshes.values() for v in o.data.vertices]
shell_points = [o.matrix_world @ v.co for o in shell.objects for v in o.data.vertices]
retained_points = [o.matrix_world @ v.co for n, o in source_meshes.items() if n not in replaced for v in o.data.vertices]
result = {
    "stock_bounds": bounds(stock_points),
    "skin_bounds": bounds(retained_points + shell_points),
    "replacement_shell_bounds": bounds(shell_points),
    "replaces": sorted(replaced),
    "actions": [a.name for a in actions],
    "output": str(OUT),
}

