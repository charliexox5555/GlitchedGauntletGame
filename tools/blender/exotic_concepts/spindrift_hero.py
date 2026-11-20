"""Editable Spindrift Vandal study. Run inside the live Blender MCP scene."""

import json
import math

import bmesh
import bpy
from mathutils import Vector

from scene import ART, bind, camera, collection, framed_camera, material, mesh, pivot, pose, render


OUT = ART / "Skins/Spindrift/Vandal/HeroApproval/v01"
PREFIX = "Spindrift | "


def sampled(rows, steps=4):
    """Interpolate artist sections without changing the sampled end sections."""
    for i in range(len(rows) - 1):
        a, b, c, d = [rows[min(max(j, 0), len(rows) - 1)]
                      for j in (i - 1, i, i + 1, i + 2)]
        for k in range(steps):
            t = k / steps
            yield tuple(
                p + (q - p) * t if axis == 0 else
                .5 * (2*p + (-m+q)*t + (2*m-5*p+4*q-r)*t*t +
                      (-m+3*p-3*q+r)*t*t*t)
                for axis, (m, p, q, r) in enumerate(zip(a, b, c, d))
            )
    yield rows[-1]


def texture(name, base, light, scale, stretch, metal, roughness, relief,
            secondary=None, thin_film=False):
    mat = material(PREFIX + name, base, metal, roughness)
    nt = mat.node_tree
    nodes, wire = nt.nodes, nt.links.new
    shader = nodes.get("Principled BSDF")
    coord = nodes.new("ShaderNodeTexCoord")
    coord.location = (-920, 120)
    mapping = nodes.new("ShaderNodeVectorMath")
    mapping.operation = "MULTIPLY"
    mapping.location = (-740, 120)
    mapping.inputs[1].default_value = stretch
    wire(coord.outputs["Object"], mapping.inputs[0])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.location = (-550, 140)
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 3.2
    noise.inputs["Roughness"].default_value = .63
    wire(mapping.outputs[0], noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.location = (-305, 180)
    ramp.color_ramp.elements[0].position = .20
    ramp.color_ramp.elements[0].color = mat.diffuse_color
    ramp.color_ramp.elements[1].position = .80
    ramp.color_ramp.elements[1].color = linear_rgba(light)
    if secondary:
        ramp.color_ramp.elements.new(.53).color = linear_rgba(secondary)
    wire(noise.outputs["Fac"], ramp.inputs[0])
    wire(ramp.outputs[0], shader.inputs["Base Color"])
    granule = nodes.new("ShaderNodeTexNoise")
    granule.location = (-550, -190)
    granule.inputs["Scale"].default_value = scale * 17
    granule.inputs["Detail"].default_value = 2
    wire(mapping.outputs[0], granule.inputs["Vector"])
    if relief:
        bump = nodes.new("ShaderNodeBump")
        bump.location = (-105, -155)
        bump.inputs["Distance"].default_value = relief
        bump.inputs["Strength"].default_value = .27
        wire(granule.outputs["Fac"], bump.inputs["Height"])
        wire(bump.outputs[0], shader.inputs["Normal"])
    polish = nodes.new("ShaderNodeMapRange")
    polish.location = (-305, -23)
    polish.inputs["To Min"].default_value = max(.06, roughness - .055)
    polish.inputs["To Max"].default_value = min(.96, roughness + .06)
    wire(noise.outputs["Fac"], polish.inputs["Value"])
    wire(polish.outputs[0], shader.inputs["Roughness"])
    if thin_film and shader.inputs.get("Thin Film Thickness"):
        film = nodes.new("ShaderNodeMapRange")
        film.location = (-285, 430)
        film.inputs["To Min"].default_value = 180
        film.inputs["To Max"].default_value = 430
        wire(noise.outputs["Fac"], film.inputs["Value"])
        wire(film.outputs[0], shader.inputs["Thin Film Thickness"])
        shader.inputs["Thin Film IOR"].default_value = 1.39
    return mat


def linear_rgba(code):
    srgb = [int(code[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return (*(s / 12.92 if s < .04045 else ((s + .055) / 1.055) ** 2.4
              for s in srgb), 1)


def palette():
    shell = texture("Black-indigo lacquer", "1A202E", "333B50", 10, (.72, 4, 2.6),
                    .52, .34, .00048, "242937")
    shade = texture("Folded blue-black alloy", "111624", "28283D", 11, (.9, 4, 3),
                    .56, .39, .001)
    pearl = texture("Honed nacre", "69768D", "D7D2CE", 9, (1.14, 3.2, 2.7),
                    .45, .255, .00028, "B2B3C9", thin_film=True)
    dark_pearl = texture("Oxidized silver", "384056", "838EA6", 16, (.7, 3, 4),
                         .65, .315, .00062)
    leather = texture("Braided stormcloth", "100F18", "302936", 30, (4, 6, 2),
                      .04, .57, .002)
    water = material(PREFIX + "Glacial water", "458397", .10, .12, emission=.06)
    shader = water.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Transmission Weight"].default_value = .60
    shader.inputs["IOR"].default_value = 1.333
    shader.inputs["Coat Weight"].default_value = .7
    caustic = material(PREFIX + "Waterline glint", "A6E2F2", .2, .23, emission=.48)
    red = material(PREFIX + "Burnt cinnabar seal", "964A43", .41, .37)
    return shell, shade, pearl, dark_pearl, leather, water, caustic, red


def finish(col, name, vertices, faces, slots, indexes, smooth=True):
    ob = mesh(col, name, vertices, faces, slots[0])
    for mat in slots[1:]:
        ob.data.materials.append(mat)
    for polygon, index in zip(ob.data.polygons, indexes):
        polygon.material_index = index
        polygon.use_smooth = smooth and len(polygon.vertices) == 4
    return ob


def skin(col, name, rings, slots, strips, smooth=True):
    width = len(rings[0])
    verts = [vert for ring in rings for vert in ring]
    faces = [tuple(reversed(range(width)))]
    indices = [0]
    for n in range(len(rings) - 1):
        for j in range(width):
            a, b = n * width + j, n * width + (j + 1) % width
            faces.append((a, b, b + width, a + width))
            indices.append(strips[j])
    faces.append(tuple(range(len(verts) - width, len(verts))))
    indices.append(0)
    return finish(col, name, verts, faces, slots, indices, smooth=smooth)


def casing(col, name, rows, slots, crown):
    """A full-width sculpted shell with independent cheek, ridge and crown."""
    rings = []
    for x, low, high, width in sampled(rows):
        height = high - low
        section = [
            (0, .02), (.63, 0), (.88, .065), (.98, .24),
            (1.00, .41), (.96, .56), (.82, .79), (.60, .91),
            (.29, .97), (0, 1), (-.29, .97), (-.60, .91),
            (-.82, .79), (-.96, .56), (-1.00, .41), (-.98, .24),
            (-.88, .065), (-.63, 0),
        ]
        if not crown:
            section = [(y, 1 - z) for y, z in section]
        rings.append([(x, y * width, low + z * height) for y, z in section])
    roles = [1, 1, 1, 0, 0, 0, 2, 3, 0, 0, 3, 2, 0, 0, 0, 1, 1, 1]
    return skin(col, name, rings, slots, roles)


def sweep(col, name, rows, slots, roles=None, steps=5):
    """Elliptical sweep with separate transverse and vertical radii."""
    rings = []
    for x, y, z, half_width, half_height in sampled(rows, steps):
        rings.append([(x, y + math.cos(j*math.tau/12)*max(.0003, half_width),
                       z + math.sin(j*math.tau/12)*max(.0003, half_height))
                      for j in range(12)])
    return skin(col, name, rings, slots, roles or [0] * 12)


def frame(col, name, outer, inner, slots, trim=None):
    """Paired sculpted outlines form a true opening with chamfered walls."""
    size = len(outer)
    verts, faces, roles = [], [], []
    for side in (-1, 1):
        for blend, width in [(0, .76), (.16, 1), (.82, 1), (1, .72)]:
            for (x, z, a), (u, v, b) in zip(outer, inner):
                verts.append((x+(u-x)*blend, (a+(b-a)*blend)*width*side,
                              z+(v-z)*blend))
    for loop in range(8):
        other = [1, 2, 3, 7, 0, 4, 5, 6][loop]
        for j in range(size):
            nxt = (j + 1) % size
            faces.append((loop*size+j, loop*size+nxt, other*size+nxt, other*size+j))
            roles.append(0 if trim is not None and j not in trim and loop not in {3,4}
                         else [3, 0, 2, 1, 1, 3, 0, 2][loop])
    return finish(col, name, verts, faces, slots, roles)


def cheek(col, name, outline, fold, slots, side):
    """Raised facets with a seated root, chamfer and a hand-placed fold."""
    count = len(outline)
    center_x, center_z = fold[0], fold[2]
    vertices = [(x, side*(y-.018), z) for x,y,z in outline]
    vertices.extend((x,side*y,z) for x,y,z in outline)
    vertices.extend((x*.91+center_x*.09,side*(y+.004),z*.91+center_z*.09)
                    for x,y,z in outline)
    vertices.append((fold[0],side*fold[1],fold[2]))
    faces = [tuple(reversed(range(count)))]
    roles = [1]
    for j in range(count):
        k = (j+1)%count
        faces.extend([(j,k,k+count,j+count),
                      (j+count,k+count,k+2*count,j+2*count),
                      (j+2*count,k+2*count,3*count)])
        roles.extend((1,3,0 if j%3 else 1))
    ob = finish(col, name, vertices, faces, slots, roles, smooth=False)
    bevel = ob.modifiers.new("Edge break on honed faces", "BEVEL")
    bevel.width = .003
    bevel.segments = 2
    bevel.affect = "EDGES"
    bevel.limit_method = "ANGLE"
    return ob


def crest(col, name, x, z, span, width, lift, slots, shine):
    """A swept saddle with a curved root and a fine, recurved trailing edge."""
    rows = []
    for j in range(25):
        t = j/24
        y = (2*t-1) * width
        a = abs(2*t-1)
        ridge = (1-a**1.65) * lift
        lean = a**1.6 * span * .69
        root = x + lean
        end = x - span*(.61 + .39*(1-a)) + lean*.59
        base = z - .052*a**1.3
        rows.append([
            (root, y*.91, base-.022), (root+.018*(1-a), y*.97, base-.003),
            (root-span*.18, y, base+.017+ridge*.23),
            (root-span*.37, y, base+.025+ridge*.47),
            (end+span*.11, y*.99, base+.021+ridge*.82),
            (end, y*.985, base+.021+ridge),
            (end+span*.038, y*.95, base+.018+ridge*.85),
            (end+span*.16, y*.90, base+.004+ridge*.57),
            (root-span*.33, y*.87, base-.022+ridge*.15),
        ])
    return skin(col, name, rows, slots, [1, 0, 3, shine, 2, 2, 3, 1, 1])


def grip(col, name, rows, slots, strips=None):
    rings = []
    for z, rear, fore, w in sampled(rows):
        mid = (rear + fore) * .5
        gap = (fore - rear) * .5
        rings.append([(mid + gap * math.cos(j*math.tau/16),
                       w * math.sin(j*math.tau/16), z) for j in range(16)])
    return skin(col, name, rings, slots, strips or [0] * 16)


def strand(col, name, path, radius, mat):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "3D"
    data.resolution_u = 18
    data.bevel_depth = radius
    data.bevel_resolution = 3
    data.use_fill_caps = True
    spline = data.splines.new("BEZIER")
    spline.bezier_points.add(len(path) - 1)
    for point, (*xyz, scale) in zip(spline.bezier_points, path):
        point.co = xyz
        point.radius = scale
        point.handle_left_type = point.handle_right_type = "AUTO"
    ob = bpy.data.objects.new(name, data)
    col.objects.link(ob)
    data.materials.append(mat)
    return ob


def body(col, slots):
    upper = [
        (-.365, .288, .343, .043), (-.20, .271, .416, .102),
        (.052, .272, .461, .135), (.24, .282, .438, .128),
        (.49, .249, .411, .119), (.69, .246, .390, .113),
        (.90, .280, .385, .112), (1.11, .275, .372, .112),
        (1.38, .238, .357, .104), (1.62, .241, .342, .094),
        (1.86, .264, .333, .087), (2.11, .261, .335, .077),
        (2.33, .255, .308, .066), (2.51, .274, .300, .023),
        (2.641, .278, .281, .0018),
    ]
    lower = [
        (-.34, .210, .306, .045), (-.12, .175, .294, .113),
        (.065, .135, .245, .124), (.28, .130, .246, .116),
        (.51, .103, .193, .118), (.70, .078, .203, .115),
        (.91, .062, .236, .114), (1.16, .104, .226, .115),
        (1.43, .120, .199, .107), (1.62, .123, .206, .100),
        (1.88, .131, .221, .099), (2.08, .155, .211, .083),
        (2.30, .158, .199, .067), (2.51, .142, .177, .028),
        (2.646, .131, .136, .002),
    ]
    casing(col, "01 | Lacquer crown and upper prow", upper, slots, True)
    casing(col, "02 | Undercut keel and lower prow", lower, slots, False)
    sweep(col, "03 | Dark channel bed", [
        (-.26, 0, .282, .04, .035), (.02, 0, .258, .085, .106),
        (.31, 0, .246, .088, .103), (.64, 0, .229, .074, .088),
        (.93, 0, .259, .072, .073), (1.25, 0, .242, .074, .073),
        (1.68, 0, .235, .064, .059), (1.93, 0, .242, .044, .062),
        (2.12, 0, .241, .025, .06), (2.26, 0, .245, .008, .018),
    ], [slots[1]])
    for i, (x, z, span, width, lift) in enumerate([
        (1.79, .327, .231, .090, .021), (1.58, .337, .261, .103, .032),
        (1.34, .348, .268, .107, .050), (1.085, .363, .302, .113, .064),
        (.801, .380, .288, .120, .088), (.505, .408, .235, .122, .089),
    ], 1):
        crest(col, f"04.{i} | Recurved spine, plate {i}", x, z, span, width,
              lift, slots, 2 if i > 2 else 3)
    for side in (-1, 1):
        cheek(col, f"05 | Cutwater shoulder {side:+}", [
            (-.281,.079,.301), (-.142,.100,.390), (.065,.130,.416),
            (.284,.121,.383), (.489,.101,.357), (.385,.109,.316),
            (.286,.124,.292), (.002,.124,.268), (-.128,.100,.271),
        ], (.035,.143,.354), slots, side)
        cheek(col, f"06 | Midbody scallop {side:+}", [
            (.234,.123,.298), (.472,.103,.373), (.772,.100,.349),
            (1.059,.097,.338), (1.113,.089,.322), (.967,.110,.293),
            (.709,.108,.272), (.512,.108,.261), (.378,.128,.272),
        ], (.638,.131,.323), slots, side)
        cheek(col, f"07 | Swept cheek at the crux {side:+}", [
            (.388,.104,.117), (.527,.104,.148), (.599,.110,.186),
            (.731,.108,.188), (.925,.106,.220), (1.091,.093,.211),
            (.969,.104,.153), (.883,.080,.076), (.813,.065,.026),
            (.681,.078,.104), (.531,.112,.120),
        ], (.742,.130,.159), slots, side)
        cheek(col, f"08 | Forebody scallop {side:+}", [
            (1.033,.098,.286), (1.150,.094,.333), (1.402,.093,.317),
            (1.588,.082,.309), (1.769,.078,.303), (1.701,.078,.277),
            (1.458,.099,.251), (1.276,.101,.256),
        ], (1.345,.118,.296), slots, side)
        prow = [slots[2],slots[1],slots[0],slots[3]]
        cheek(col, f"09 | Upper nacre point {side:+}", [
            (1.968,.061,.304), (2.075,.053,.329), (2.273,.052,.317),
            (2.412,.037,.301), (2.636,.002,.279), (2.452,.036,.267),
            (2.301,.072,.267), (2.130,.084,.292),
        ], (2.279,.089,.297), prow, side)
        cheek(col, f"09 | Lower nacre point {side:+}", [
            (1.982,.059,.165), (2.091,.074,.170), (2.268,.067,.190),
            (2.407,.042,.176), (2.645,.002,.134), (2.464,.030,.133),
            (2.276,.063,.146), (2.075,.076,.151),
        ], (2.291,.083,.162), prow, side)
        x = 1.63 if side < 0 else 1.72
        for i in range(2):
            sweep(col, f"05 | Grasp recess lip {side:+} {i+1}", [
                (x+i*.14-.06, side*.085, .14, .008, .003),
                (x+i*.14, side*.106, .15, .013, .010),
                (x+i*.14+.078, side*.103, .162, .010, .007),
                (x+i*.14+.109, side*.086, .163, .003, .001),
            ], [slots[1], slots[3]], [0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0])
    return col


def furniture(col, rig, slots, leather):
    outer = [
        (-.219,.343,.092), (-.404,.373,.075), (-.613,.390,.069),
        (-.899,.427,.062), (-1.187,.485,.064), (-1.250,.466,.072),
        (-1.239,.225,.079), (-1.211,.111,.074), (-1.148,.100,.071),
        (-.921,.165,.063), (-.664,.208,.069), (-.427,.212,.082),
        (-.224,.224,.095),
    ]
    inner = [
        (-.425,.295,.064), (-.507,.319,.059), (-.655,.340,.054),
        (-.880,.373,.050), (-1.092,.422,.049), (-1.158,.414,.052),
        (-1.164,.287,.054), (-1.145,.218,.054), (-1.100,.190,.051),
        (-.937,.216,.053), (-.720,.248,.056), (-.516,.258,.057),
        (-.425,.279,.063),
    ]
    frame(col, "10 | Pierced crescent stock", outer, inner, slots, {3,4,5,7,8})
    sweep(col, "10 | Stock heel to receiver tongue", [
        (-.508,0,.303,.058,.061), (-.402,0,.298,.081,.082),
        (-.324,0,.290,.088,.070), (-.218,0,.297,.097,.064),
        (-.116,0,.302,.093,.037),
    ], [slots[1],slots[0]], [0,1,1,1,1,0,0,0,0,0,0,0])
    grip(col, "11 | Carved palm and wrapped grip", [
        (.202,-.179,.101,.059), (.112,-.181,.079,.073),
        (.033,-.186,.040,.070), (-.072,-.218,.022,.065),
        (-.183,-.269,-.027,.054), (-.261,-.300,-.059,.052),
        (-.286,-.296,-.082,.061), (-.315,-.283,-.100,.051),
    ], [slots[0], leather, slots[1]], [1,1,1,1,1,1,1,2,2,2,1,1,1,1,1,1])
    grip(col, "12 | Nacre heel cap", [
        (-.277,-.292,-.085,.058), (-.293,-.295,-.077,.064),
        (-.314,-.280,-.097,.055), (-.326,-.259,-.113,.041),
    ], [slots[2], slots[0]], [0,0,0,1,1,1,1,1,0,0,1,1,1,1,1,0])
    for index in range(5):
        z = -.041 - .044*index
        rear = -.197 - .019*index
        fore = .029 - .017*index
        w = .067 - .003*index
        for side in (-1, 1):
            strand(col, f"13.{index+1} | Bound stormcloth welt {side:+}", [
                (rear+.021,side*w*.53,z-.011,.1), (rear+.058,side*w*.94,z-.010,.76),
                ((rear+fore)*.5,side*w*1.02,z,1), (fore-.038,side*w*.79,z+.020,.75),
                (fore-.009,side*w*.40,z+.028,.1),
            ], .0030, slots[1])
    frame(col, "14 | Sculpted guard loop", [
        (.020,.127,.064), (.106,.162,.056), (.302,.152,.062),
        (.436,.137,.062), (.458,.060,.054), (.417,-.015,.052),
        (.342,-.071,.047), (.183,-.082,.048), (.037,-.050,.058),
    ], [
        (.078,.092,.050), (.141,.115,.049), (.289,.112,.051),
        (.387,.092,.050), (.396,.053,.044), (.369,.004,.044),
        (.317,-.034,.040), (.184,-.043,.042), (.089,-.023,.047),
    ], slots, {4,5})
    mag = grip(col, "15 | Tapered tidal magazine", [
        (.221,.621,.958,.059), (.153,.595,.992,.078),
        (.049,.600,.976,.079), (-.044,.581,.920,.071),
        (-.157,.553,.870,.061), (-.269,.512,.826,.053),
        (-.353,.472,.800,.050), (-.384,.486,.776,.045),
        (-.405,.516,.736,.039),
    ], slots, [1,3,0,0,0,0,0,2,1,2,0,0,0,0,0,3])
    toe = grip(col, "16 | Swept magazine shoe", [
        (-.336,.482,.814,.051), (-.357,.471,.804,.057),
        (-.379,.478,.798,.055), (-.400,.512,.751,.047),
        (-.413,.545,.700,.035),
    ], slots, [1,3,0,0,0,0,2,2,1,2,2,0,0,0,0,3])
    for part in (mag, toe):
        bind(part, rig, "Mag")


def sights(col, sc, slots, glint):
    sweep(col, "20 | Crest saddle", [
        (-.107,0,.441,.023,.007), (-.041,0,.450,.087,.016),
        (.080,0,.451,.111,.028), (.184,0,.432,.087,.025),
        (.242,0,.418,.032,.009),
    ], slots, [1,0,3,0,0,3,1,1,1,1,1,1])
    for side in (-1, 1):
        rings = []
        for t in range(25):
            u = t/24
            angle = math.radians(-70 + 137*u)
            y = side * (.082 * math.cos(angle))
            z = .555 + .091 * math.sin(angle)
            thickness = .018*(1-u)**.7 + .0018
            x = .085 - .075*u**1.2
            rings.append([(x+math.cos(j*math.tau/8)*thickness,
                           y+side*math.sin(j*math.tau/8)*thickness*math.cos(angle),
                           z+math.sin(j*math.tau/8)*thickness*math.sin(angle))
                          for j in range(8)])
        skin(col, f"21 | Split crest sight {side:+}", rings, slots, [2,2,3,0,1,1,0,3])
        strand(col, f"22 | Crest sight skirt {side:+}", [
            (.141,side*.026,.461,.4), (.099,side*.065,.483,1),
            (.041,side*.100,.471,.8), (.022,side*.126,.446,.08),
        ], .013, slots[1])
    sweep(col, "23 | Forward sight blade", [
        (1.761,0,.334,.019,.003), (1.817,0,.356,.024,.031),
        (1.872,0,.401,.011,.077), (1.916,0,.429,.008,.093),
        (1.957,0,.481,.002,.058), (1.987,0,.529,.0013,.015),
    ], slots, [1,0,2,2,3,0,1,1,1,1,1,1])
    strand(col, "24 | Cyan sight bead", [
        (1.953,0,.541,.32), (1.974,0,.547,1), (1.993,0,.546,.25),
    ], .0072, glint)


def tide(col, rig, slots, water, glint, cinnabar):
    for side in (-1, 1):
        channel = [
            (-.091,.061,.254,.005,.004), (.072,.105,.255,.020,.006),
            (.273,.110,.263,.019,.012), (.473,.111,.224,.025,.020),
            (.623,.112,.217,.028,.016), (.799,.106,.243,.030,.024),
            (.982,.107,.256,.029,.017), (1.185,.109,.234,.028,.012),
            (1.40,.101,.218,.025,.014), (1.64,.089,.222,.021,.009),
            (1.86,.074,.245,.027,.017), (2.055,.068,.243,.031,.020),
            (2.221,.061,.228,.026,.020), (2.35,.032,.229,.028,.020),
            (2.409,.012,.238,.015,.005),
        ]
        sweep(col, f"30 | Recessed tidal current {side:+}", [
            (x,(y-.009)*side,z,rx*.83,rz*1.05) for x,y,z,rx,rz in channel
        ], [water])
        for k, (start, stop) in enumerate([(1, 6), (7, 11), (10, 15)]):
            spline = [(x,side*(y+.007),z + .007*math.sin(i*2.2),
                       .08 if i in (0,stop-start-1) else (.63 if k == 1 else 1))
                      for i,(x,y,z,_,_) in enumerate(channel[start:stop])]
            strand(col, f"31.{k+1} | Water caustic {side:+}", spline, .0021, glint)
        strand(col, f"31 | Drowned teardrop {side:+}", [
            (.731,side*.126,.232,.8), (.694,side*.129,.209,.57),
            (.680,side*.133,.179,.34), (.684,side*.137,.152,1.17),
            (.689,side*.136,.135,.14),
        ], .0115, water)
        for i in range(2):
            strand(col, f"32.{i+1} | Engraved wave hallmark {side:+}", [
                (x,side*y,z-i*.014, r) for x,y,z,r in [
                    (-.189,.096,.338,.24),(-.160,.105,.349,.8),
                    (-.135,.113,.341,.74),(-.108,.119,.352,1),
                    (-.080,.124,.346,.8),(-.051,.128,.356,.18),
                ]
            ], .0031, cinnabar)
    # The peak draws liquid out between the jaws, then capillary action takes it back.
    pulse_parts = []
    for side in (-1, 1):
        path = [
            (2.110,side*.057,.235,.18), (2.226,side*.064,.212,1),
            (2.373,side*.049,.191,.73), (2.499,side*.027,.217,.96),
            (2.579,side*.010,.257,.68), (2.657,side*.021,.247,.25),
            (2.725,side*.040,.225,.015),
        ]
        pulse_parts.append(strand(col, f"33 | Cresting water {side:+}", path, .0096, water))
        pulse_parts.append(strand(col, f"34 | Cresting glint {side:+}", [
            (x,y*1.025,z+.008,r*.83) for x,y,z,r in path
        ], .0039, glint))
    ctrl = pivot(col, "CTRL | Tide release", (2.116,0,.239), pulse_parts, parent=rig)
    for f, scale, angles in [
        (1,.001,(0,0,0)), (25,.001,(0,0,0)), (37,.48,(14,11,0)),
        (49,1,(0,0,0)), (63,.64,(-14,16,0)), (82,.001,(0,0,0)),
        (96,.001,(0,0,0)),
    ]:
        pose(ctrl, f, scale=(scale,)*3, angles=angles)
    ctrl.animation_data.action.name = "Spindrift | Tide draws and recedes"


def flex_prow(art):
    for ob in art.objects:
        if not ob.name.startswith(("01 |", "02 |", "09 |")):
            continue
        direction = 1 if "upper" in ob.name.lower() or ob.name.startswith("01 |") else -1
        ob.shape_key_add(name="Rest")
        opening = ob.shape_key_add(name="Drawn by the current")
        for point in opening.data:
            fraction = max(0, (point.co.x - 1.98) / .67)
            point.co.z += direction * .046 * fraction**2
        for f, value in [(1,0), (25,0), (38,.30), (49,1), (63,.49), (82,0), (96,0)]:
            opening.value = value
            opening.keyframe_insert("value", frame=f)
        ob.data.shape_keys.animation_data.action.name = "Spindrift | Prow flex " + ob.name


def studio(sc, art, stage):
    def area(name, pos, target, power, color, size, height=None):
        data = bpy.data.lights.new(PREFIX + name, "AREA")
        ob = bpy.data.objects.new(PREFIX + name, data)
        stage.objects.link(ob)
        ob.location = pos
        ob.rotation_euler = (Vector(target)-ob.location).to_track_quat("-Z","Y").to_euler()
        data.energy, data.color, data.size = power, color, size
        if height:
            data.shape = "RECTANGLE"
            data.size_y = height

    for ob in sc.objects:
        if (ob.type == "LIGHT" or ob.name.startswith(("Range","Target"))) and ob.name not in stage.objects:
            ob.hide_set(True)
            ob.hide_render = True
    sc.world = bpy.data.worlds.new(PREFIX + "Soft grey studio")
    sc.world.use_nodes = True
    world = sc.world.node_tree.nodes.get("Background")
    world.inputs["Color"].default_value = (.25,.29,.39,1)
    world.inputs["Strength"].default_value = .34
    area("Pearl key",(1.5,2.8,3.6),(.8,0,.19),230,(.94,.95,1),4.4,2.0)
    area("Indigo rim",(.6,-1.5,2.2),(.55,0,.26),236,(.55,.70,1),4.4,.75)
    area("Soft aisle",(-1.1,2.1,1.13),(.10,0,.15),90,(1,.87,.80),2.75,.88)
    area("Low bounce",(1.5,1.6,-.14),(.85,0,.10),34,(.72,.84,1),2.8)
    area("Reverse fill",(2.05,-2.9,.39),(.61,0,.14),67,(.84,.90,1),2.6,1.1)
    ground = material(PREFIX + "Slate studio floor","32394A",.09,.71)
    mesh(stage, "Sweep floor", [(-100,-100,-.473),(100,-100,-.473),
                                 (100,100,-.473),(-100,100,-.473)], [(0,1,2,3)], ground)
    pts = [Vector((x,y,z)) for x in (-1.25,2.646) for y in (-.15,.15)
           for z in (-.414,.645)]
    hero = framed_camera(stage, PREFIX + "Hero", pts, (1.62,6,1.64), 1.85, 1.12)
    other = framed_camera(stage, PREFIX + "Reverse", pts, (-.71,-6,1.12), 1.85, 1.10)
    detail = camera(stage, PREFIX + "Prow", (2.108,.018,.236), (1.45,3,1.15), 1.29)
    aim = camera(stage, PREFIX + "Sightline", (1.6,0,.551), (-1,0,.005),
                 distance=2.11, lens=32)
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.view_settings.exposure = .45
    sc.render.film_transparent = False
    sc.render.resolution_percentage = 100
    sc.render.resolution_x, sc.render.resolution_y = 1400, 760
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.camera = hero
    return hero, other, detail, aim


def build():
    sc = bpy.context.scene
    assert not bpy.app.background and sc.get("Spindrift workshop") == "Live art working scene"
    for old in list(sc.collection.children):
        if old.name.startswith(PREFIX):
            for ob in list(old.objects):
                data = ob.data
                kind = ob.type
                bpy.data.objects.remove(ob, do_unlink=True)
                if data and not data.users and kind in {"MESH", "CURVE", "LIGHT", "CAMERA"}:
                    getattr(bpy.data, kind.lower() + "s" if kind != "MESH" else "meshes").remove(data)
            bpy.data.collections.remove(old)
    for mat in list(bpy.data.materials):
        if mat.name.startswith(PREFIX) and not mat.users:
            bpy.data.materials.remove(mat)
    for entry in list(sc.timeline_markers):
        if entry.name in {"Rest", "Draw", "Crest", "Recede", "Settle"}:
            sc.timeline_markers.remove(entry)
    rig = sc.objects["Vandal_Rig"]
    bpy.context.view_layer.update()
    for ob in sc.objects:
        if ob.name.startswith("Vandal_") and ob.type == "MESH":
            retained = ob.name.endswith(("Trigger", "CharmLoop"))
            ob.hide_set(not retained)
            ob.hide_render = not retained
    shell, shade, pearl, dark_pearl, leather, water, glint, cinnabar = palette()
    slots = [shell, shade, pearl, dark_pearl]
    art = collection(sc, PREFIX + "01 Sculpted exterior")
    current = collection(sc, PREFIX + "02 Tidal surface and motion")
    stage = collection(sc, PREFIX + "03 Review stage")
    body(art, slots)
    furniture(art, rig, slots, leather)
    sights(art, sc, slots, glint)
    tide(current, rig, slots, water, glint, cinnabar)
    flex_prow(art)
    for ob in [*art.objects, *current.objects]:
        if ob.parent is None and ob.type in {"MESH", "CURVE"}:
            bind(ob, rig)
    sc.frame_start, sc.frame_end = 1, 96
    for name, frame_number in [
        ("Rest",1), ("Draw",25), ("Crest",49), ("Recede",63), ("Settle",82),
    ]:
        sc.timeline_markers.new(name, frame=frame_number)
    sc.frame_set(1)
    studio(sc, art, stage)
    sc.name = "Spindrift Vandal | Hero review"
    bpy.context.view_layer.objects.active = None
    for ob in bpy.context.selected_objects:
        ob.select_set(False)
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.region_3d.view_perspective = "CAMERA"
                space.region_3d.view_camera_zoom = 22
                space.overlay.show_overlays = False
                space.shading.type = "MATERIAL"
    OUT.mkdir(parents=True, exist_ok=True)
    sc.render.filepath = str(OUT / "Spindrift_Hero.png")
    return {"scene": sc.name, "meshes": len(art.objects), "effect_parts": len(current.objects),
            "live": not bpy.app.background}


def review(sc):
    art = bpy.data.collections[PREFIX + "01 Sculpted exterior"]
    stage = bpy.data.collections[PREFIX + "03 Review stage"]
    current = bpy.data.collections[PREFIX + "02 Tidal surface and motion"]
    sc.frame_set(1)
    bad = []
    total = 0
    coords = []
    for ob in [*art.objects, *current.objects]:
        if ob.type == "MESH":
            bm = bmesh.new()
            bm.from_mesh(ob.data)
            if (any(not e.is_manifold for e in bm.edges) or
                    any(f.calc_area() < 1e-10 for f in bm.faces) or
                    bm.calc_volume(signed=True) <= 0):
                bad.append(ob.name)
            total += len(bm.faces)
            bm.free()
        if ob in art.objects.values():
            coords.extend(ob.matrix_world @ Vector(p) for p in ob.bound_box)
    bounds = [[round(reduction(v[i] for v in coords), 4) for i in range(3)]
              for reduction in (min, max)]
    aim = sc.objects["Vandal_AimPoint"].matrix_world.translation
    origin = Vector((-.48, aim.y, aim.z))
    ray = sc.ray_cast(bpy.context.evaluated_depsgraph_get(), origin, Vector((1,0,0)), distance=3.6)
    crest = art.objects["01 | Lacquer crown and upper prow"].data.shape_keys.key_blocks[1]
    ctrl = current.objects["CTRL | Tide release"]
    shape_states = []
    for f in (1, 25, 38, 49, 63, 82, 96):
        sc.frame_set(f)
        shape_states.append({"frame": f, "prow_flex": round(crest.value, 4),
                             "water_scale": round(ctrl.scale.x, 4)})
    sc.frame_set(1)
    data = {
        "session": {"port": 9000, "background": bpy.app.background},
        "rest_exterior_bounds": bounds,
        "stock_total_length": 3.899,
        "base_mesh_faces_checked": total,
        "base_mesh_errors": bad,
        "stock_aim_center_ray_hit": ray[4].name if ray[0] else None,
        "effect_review": shape_states,
    }
    (OUT / "review.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    return data


def save(blender_scene):
    blender_scene.camera = bpy.data.objects[PREFIX + "Hero"]
    blender_scene.frame_set(1)
    blender_scene.render.resolution_x, blender_scene.render.resolution_y = 1450, 780
    blender_scene.render.filepath = str(OUT / "Spindrift_Hero.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "Vandal_Spindrift_Hero_v01.blend"))


def stills():
    sc = bpy.context.scene
    render(sc, sc.objects[PREFIX+"Hero"], OUT/"Spindrift_Hero.png", 1, (1450,780))
    render(sc, sc.objects[PREFIX+"Reverse"], OUT/"Spindrift_Reverse.png", 1, (1250,675))
    render(sc, sc.objects[PREFIX+"Prow"], OUT/"Spindrift_Crest.png", 49, (1000,690))
    floor = bpy.data.collections[PREFIX+"03 Review stage"].objects["Sweep floor"]
    floor.hide_render = True
    try:
        render(sc, sc.objects[PREFIX+"Sightline"], OUT/"Spindrift_Sightline.png", 1, (860,620))
    finally:
        floor.hide_render = False
    save(sc)


def motion_preview(path):
    sc = bpy.context.scene
    sc.cycles.samples = 10
    try:
        for index, f in enumerate(range(21, 97, 4)):
            render(sc, sc.objects[PREFIX+"Prow"], path / f"{index:02d}.png", f, (576,384))
    finally:
        sc.cycles.samples = 24
        sc.camera = sc.objects[PREFIX+"Hero"]
        sc.frame_set(1)
        sc.render.resolution_x, sc.render.resolution_y = 1450, 780
        sc.render.filepath = str(OUT / "Spindrift_Hero.png")
