"""Build the editable Storm Shadow Vandal in the isolated Blender review scene."""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "art-source/weapons/Skins/TempestStrike/Vandal"
REF = bpy.data.scenes.get("Stock Vandal | Reference")
if not REF:
    source = ROOT / "art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend"
    with bpy.data.libraries.load(str(source), link=False) as (available, loaded):
        loaded.scenes = available.scenes
    REF = next(scene for scene in loaded.scenes if "Vandal_Rig" in scene.objects)
    REF.name = "Stock Vandal | Reference"
bpy.context.window.scene = REF
bpy.context.view_layer.update()
STOCK_TRANSFORMS = {obj.name: obj.matrix_world.copy() for obj in REF.objects}
SCENE = bpy.data.scenes.new("Tempest-Strike | Storm Shadow")
bpy.context.window.scene = SCENE


def collection(name):
    group = bpy.data.collections.new(name)
    SCENE.collection.children.link(group)
    return group


RIG = collection("01 • Rig and locators")
CHASSIS = collection("02 • Shroud and receiver")
STOCK = collection("03 • Open stock")
GRIP = collection("04 • Grip and controls")
MAG = collection("05 • Magazine")
SIGHTS = collection("06 • Sights")
GUIDES = collection("07 • Deferred effect sockets")
JEWELS = collection("08 • Stock buddy mount")
STAGE = collection("09 • Review cameras and lights")


def linear(hex_code):
    srgb = [int(hex_code[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb]


def material(role, shade, metal=0, rough=.45, grain=0, emission=0, transmission=0):
    mat = bpy.data.materials.new("TS_" + role)
    mat.diffuse_color = (*linear(shade), 1)
    mat["role"] = role
    mat["srgb"] = shade
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = mat.diffuse_color
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Coat Weight"].default_value = .17 if metal > .4 else .07
    shader.inputs["Transmission Weight"].default_value = transmission
    shader.inputs["Emission Color"].default_value = mat.diffuse_color
    shader.inputs["Emission Strength"].default_value = emission
    if grain:
        coords = nodes.new("ShaderNodeTexCoord")
        scale = nodes.new("ShaderNodeVectorMath")
        scale.operation = "MULTIPLY"
        scale.inputs[1].default_value = (8, 165, 165) if metal > .4 else (195, 195, 195)
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 1
        noise.inputs["Detail"].default_value = 2
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = grain
        bump.inputs["Distance"].default_value = .004 if metal > .4 else .009
        ramp = nodes.new("ShaderNodeMapRange")
        ramp.inputs["To Min"].default_value = rough - .06
        ramp.inputs["To Max"].default_value = rough + .06
        links.new(coords.outputs["Object"], scale.inputs[0])
        links.new(scale.outputs[0], noise.inputs["Vector"])
        links.new(noise.outputs["Fac"], ramp.inputs["Value"])
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], shader.inputs["Normal"])
        links.new(ramp.outputs["Result"], shader.inputs["Roughness"])
        if metal > .4:
            shader.inputs["Anisotropic"].default_value = .38
    return mat


BODY = material("Body · black alloy", "192433", .69, .34, .06)
DARK = material("Dark · indigo shadow", "101625", .36, .42)
PANEL = material("Panel · brushed silver", "9EACBD", .82, .29, .07)
EDGE = material("PanelEdge · nickel edge", "C6D9E8", .84, .23, .055)
STEEL = material("Metal · blued steel", "526678", .76, .33)
BLUE = material("Accent · deep blue enamel", "1A6193", .34, .29)
LEATHER = material("Grip · dark leather", "30211E", 0, .59, .19)
FOLD = material("GripEdge · compressed leather", "251818", 0, .66, .23)
RUBBER = material("Rubber · heel and grip liner", "24242C", 0, .68, .13)
SIGHT_MARK = material("SightMark · pale ceramic", "91C8CE", .15, .44)
GLASS = material("Glass · hydro core", "397C8A", .16, .19, transmission=.31)



def empty(name, position, parent=None):
    obj = bpy.data.objects.new(name, None)
    RIG.objects.link(obj)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = .052
    obj.parent = parent
    obj.location = Vector(position) - (parent.location if parent and not parent.parent else Vector())
    if parent:
        bpy.context.view_layer.update()
        obj.location = parent.matrix_world.inverted() @ Vector(position)
    return obj


ACTION = empty("CTRL_Action", (0, 0, 0))
BALANCE = empty("CTRL_InspectBalance", (.67, 0, .217), ACTION)
BODY_CTRL = empty("CTRL_Chassis", (0, 0, 0), BALANCE)
MAG_CTRL = empty("CTRL_Magazine", (.5828, 0, .155), BODY_CTRL)
CHARGE = empty("CTRL_Charge", (.6572, .08, .3069), BODY_CTRL)
BOLT = empty("CTRL_Bolt", (.4898, -.06, .3162), BODY_CTRL)
def mesh(name, verts, faces, mats, group, parent=BODY_CTRL, bevel=0, roles=None):
    pivot = sum((Vector(v) for v in verts), Vector()) / len(verts)
    data = bpy.data.meshes.new(name)
    data.from_pydata([Vector(v) - pivot for v in verts], [], faces)
    data.update()
    edit = bmesh.new()
    edit.from_mesh(data)
    bmesh.ops.recalc_face_normals(edit, faces=list(edit.faces))
    edit.to_mesh(data)
    edit.free()
    for mat in mats:
        data.materials.append(mat)
    if roles:
        for face, role in zip(data.polygons, roles):
            face.material_index = role
    obj = bpy.data.objects.new(name, data)
    group.objects.link(obj)
    obj.parent = parent
    bpy.context.view_layer.update()
    obj.location = parent.matrix_world.inverted() @ pivot if parent else pivot
    if bevel:
        mod = obj.modifiers.new("Machined edge", "BEVEL")
        mod.width, mod.segments = bevel, 1
        mod.affect = "EDGES"
        mod.limit_method = "ANGLE"
        mod.angle_limit = .31
        mod.harden_normals = True
        mod.face_strength_mode = "FSTR_AFFECTED"
        for polygon in data.polygons:
            polygon.use_smooth = True
        normals = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
        normals.keep_sharp = True
        normals.use_face_influence = True
    return obj


def loft(name, rings, mats, group, parent=BODY_CTRL, bevel=0, stripe=None, loop=False):
    count = len(rings[0])
    verts = [v for ring in rings for v in ring]
    faces, roles = [], []
    for row in range(len(rings) if loop else len(rings) - 1):
        start, end = row * count, ((row + 1) % len(rings)) * count
        for j in range(count):
            k = (j + 1) % count
            faces.append((start + j, start + k, end + k, end + j))
            roles.append(stripe(j, row) if stripe else 0)
    if not loop:
        faces.extend((tuple(range(count - 1, -1, -1)), tuple(range(len(verts) - count, len(verts)))))
        roles.extend((0, 0))
    return mesh(name, verts, faces, mats, group, parent, bevel, roles)


def octagon(a, b, cut=.28):
    return [(a*(1-cut), -b), (-a*(1-cut), -b), (-a, -b*(1-cut)), (-a, b*(1-cut)),
            (-a*(1-cut), b), (a*(1-cut), b), (a, b*(1-cut)), (a, -b*(1-cut))]


def hull(name, sections, mats, group=CHASSIS, parent=BODY_CTRL, bevel=0, stripes=None):
    rings = [[(x, y, (low+high)/2 + z) for y, z in octagon(width, (high-low)/2, .38)]
             for x, width, low, high in sections]
    return loft(name, rings, mats, group, parent, bevel, stripes)


def slab(name, profile, layers, mats, group=CHASSIS, parent=BODY_CTRL, bevel=.003):
    # Layer profiles follow the same vertex order across the thickness.
    rings = [[(x, y if isinstance(y, (float, int)) else y[i], z)
              for i, (x, z) in enumerate(shape or profile)] for y, shape in layers]
    return loft(name, rings, mats, group, parent, bevel)


def frame(name, outer, inner, width, mats, group, bevel):
    rings = [[(x, side * width, z) for x, z in poly]
             for side, poly in [(-1, outer), (1, outer), (1, inner), (-1, inner)]]
    # An extrusion with a continuous opening and independently assignable inner walls.
    return loft(name, rings, mats, group, bevel=bevel, loop=True,
                stripe=lambda edge, row: int(row == 2 and len(mats) > 1))


def pipe(name, rings, mat, group, center=(0, 0, .285), count=10, parent=BODY_CTRL):
    y, z = center[1:]
    radial = [(math.cos((i + .5) * math.tau/count), math.sin((i + .5) * math.tau/count))
              for i in range(count)]
    return loft(name, [[(x, y+r*u, z+r*v) for u, v in radial] for x, r in rings],
                [mat], group, parent, loop=True)


def tube(name, points, widths, mats, group, parent=BODY_CTRL, closed=False, sides=6, flat=.8):
    pts = [Vector(p) for p in points]
    rs = [widths] * len(pts) if isinstance(widths, (float, int)) else widths
    rings = []
    for i, pt in enumerate(pts):
        before = pts[(i-1) % len(pts)] if closed else pts[max(0, i-1)]
        after = pts[(i+1) % len(pts)] if closed else pts[min(len(pts)-1, i+1)]
        tangent = (after-before).normalized()
        v = Vector((1, 0, 0)) if abs(tangent.x) < .92 else Vector((0, 0, 1))
        v = tangent.cross(v).normalized()
        u = v.cross(tangent)
        rings.append([pt + rs[i] * (u*math.cos(a) + v*(flat*math.sin(a)))
                      for a in [j*math.tau/sides for j in range(sides)]])
    return loft(name, rings, mats, group, parent, loop=closed,
                stripe=lambda edge, row: int(len(mats) > 1 and edge == 0))


def track_wrap(name, shape, spans, bias, mats, group, parent):
    # Closed strips with irregular rolled edges and a compressed overlap.
    for index, (top, bottom) in enumerate(spans):
        def ring(t, raise_by, roll):
            cx, z, half, width = shape(t)
            points = []
            corners=octagon(half + raise_by, width + raise_by)
            for j, (x,y) in enumerate(corners):
                phase = j * math.tau / 8
                offset = bias*x + .0048*math.sin(phase*2+index*.71)
                points.append((cx+x,y,z+offset))
                u,v=corners[(j+1)%8]
                along=.42+.13*math.sin(index*.83+j)
                x=x+(u-x)*along
                y=y+(v-y)*along
                y*=1+roll*.045*math.cos(index*.63+j)
                points.append((cx+x,y,z+offset+.0034*math.sin(index*.86+j*.7)*roll))
            return points
        rings = [ring(t,h,r) for t,h,r in [(top,-.002,0),(top+.006,.004,.72),(top+.016,.007,1),
                       ((top+bottom)/2,.0046,.31),(bottom-.011,.0061,.85),(bottom-.003,.003,.38),
                       (bottom,-.001,0)]]
        loft(f"{name}_{index+1:02}", rings, mats, group, parent, loop=True,
             stripe=lambda edge, row: int(row in {0, 4, 5} or (edge == 1 and index % 3 == 1)))


def transfer_fixture():
    source = next(o for o in REF.objects if o.type == "ARMATURE")
    rig = source.copy()
    rig.data = source.data.copy()
    rig.name = "Vandal_StockRig"
    RIG.objects.link(rig)
    rig.parent = BODY_CTRL
    rig.show_in_front = False
    for src in REF.objects:
        if src.type not in {"EMPTY", "CAMERA"}:
            continue
        if src.type == "CAMERA" and src.name not in {"Vandal_Cam_Hip", "Vandal_Cam_ADS", "Vandal_FP_ADS"}:
            continue
        obj = src.copy()
        (RIG if src.type == "EMPTY" else STAGE).objects.link(obj)
        obj.name = "TS_" + src.name
        if src.type == "EMPTY":
            obj.parent = rig
            obj.empty_display_size = .028
    return rig


HOST_RIG = transfer_fixture()

# Refit the forging to the stock receiver and handguard break at x=1.046.
receiver = hull("Receiver_IndigoForging", [
    (-.178,.060,.141,.354),(-.150,.091,.104,.402),(-.085,.095,.089,.423),
    (.096,.094,.083,.425),(.33,.093,.084,.425),(.47,.093,.078,.421),
    (.728,.093,.083,.421),(.905,.093,.094,.421),(1.036,.094,.127,.409),
    (1.067,.080,.157,.382)
], [BODY,DARK], bevel=.004, stripes=lambda edge,row: int(edge in {0,1,7}))
hull("UpperSpine_ProwBrow", [
    (-.153,.048,.366,.412),(-.085,.063,.390,.452),(.128,.068,.402,.452),
    (.214,.061,.404,.467),(.408,.053,.414,.474),(.662,.055,.411,.472),
    (.834,.061,.403,.46),(.997,.064,.394,.445),(1.058,.058,.379,.427)
], [BODY,EDGE,STEEL], bevel=.002, stripes=lambda edge,row:
    1 if edge in {3,5} and row in {2,3,4,5,6} else 2 if edge in {3,5} else 0)
keel = hull("Receiver_Keel", [
    (.231,.046,.105,.162),(.421,.071,.093,.175),(.484,.086,.063,.162),
    (.718,.085,.062,.153),(.828,.073,.097,.179),(.991,.058,.153,.21)
], [DARK,BODY], bevel=.002, stripes=lambda edge,row: int(edge in {2,6}))
magwell = loft("Tool_MagazineSeat",
               [[(.603+x,y,z) for x,y in octagon(half,width,.22)]
                for z,half,width in [(.021,.184,.074),(.08,.173,.073),(.229,.167,.073)]],
               [DARK],CHASSIS)
magwell.hide_render=True
magwell.hide_set(True)
magwell.display_type="WIRE"
for host in (receiver,keel):
    slot=host.modifiers.new("Recessed magazine seat","BOOLEAN")
    slot.operation="DIFFERENCE"
    slot.solver="EXACT"
    slot.object=magwell
shroud = hull("Shroud_OctagonalForging", [
    (1.023,.075,.164,.376),(1.069,.093,.168,.413),(1.128,.096,.165,.413),
    (1.31,.094,.169,.405),(1.457,.091,.17,.397),(1.569,.086,.178,.391),
    (1.626,.075,.201,.373),(1.683,.055,.225,.343),(1.716,.047,.239,.33)
], [BODY,DARK,STEEL], bevel=.003, stripes=lambda edge,row: 2 if edge in {3,5} else int(edge in {0,1,7}))
hull("Shroud_DorsalBlade", [
    (1.001,.058,.382,.434),(1.094,.063,.384,.454),(1.246,.055,.383,.452),
    (1.391,.052,.368,.436),(1.534,.042,.356,.416),(1.608,.032,.338,.396),
    (1.688,.022,.317,.378),(1.740,.016,.316,.343)
], [BODY,EDGE,STEEL], bevel=.0018, stripes=lambda edge,row:
    1 if edge in {3,5} and row in {1,2,3,4} else 2 if edge in {3,5} else 0)
hull("Shroud_SupportSaddle", [
    (1.069,.035,.169,.181),(1.154,.066,.165,.186),(1.39,.061,.1705,.196),
    (1.462,.05,.147,.181),(1.501,.047,.130,.175),(1.556,.035,.154,.183),
    (1.573,.028,.174,.194)
], [RUBBER], bevel=.002)

for side in (1, -1):
    label = "Player" if side == 1 else "Far"
    # The upper breaks share a datum across the receiver/handguard junction.
    beds = [
        ("Rear", [(-.124,.301),(-.089,.402),(.07,.424),(.282,.394),(.769,.372),
                  (.94,.361),(1.023,.324),(.917,.308),(.348,.320),(.137,.299),(-.049,.286)],
         [(-.101,.32),(-.077,.389),(.071,.411),(.28,.382),(.769,.359),(.932,.348),
          (.986,.325),(.907,.322),(.350,.333),(.139,.313),(-.044,.302)], .094, (.224,side*.106,.369)),
        ("Fore", [(1.014,.320),(1.085,.367),(1.217,.357),(1.363,.335),(1.576,.315),(1.658,.285),
                  (1.614,.269),(1.457,.271),(1.252,.288),(1.089,.294)],
         [(1.061,.325),(1.091,.352),(1.216,.345),(1.359,.323),(1.57,.303),(1.632,.285),
          (1.606,.282),(1.454,.284),(1.252,.301),(1.093,.308)], .097, (1.38,side*.103,.323)),
    ]
    for name, bed, profile, width, pos in beds:
        slide = empty(f"CTRL_Plate{name}_{label}", pos, BODY_CTRL)
        slide["travel_x"] = .029 if name == "Fore" else .031
        def flank(x, offset):
            taper = max(0, (x-1.42)*.091) if name == "Fore" else 0
            return side*(width + offset - taper)
        slab(f"{name}_DovetailBed_{label}",bed,
             [([flank(x,-.022) for x,z in bed],None),([flank(x,.004) for x,z in bed],None)],
             [DARK],bevel=.0017)
        cx=sum(x for x,z in profile)/len(profile)
        cz=sum(z for x,z in profile)/len(profile)
        facet=[(x+(cx-x)*.019,z+(cz-z)*.30+.002) for x,z in profile]
        shoulder=.017 if name=="Fore" else .020
        rings=[[(x,flank(x,offset),z) for x,z in outline] for offset,outline in
               [(.008,profile),(.012,profile),(shoulder,facet)]]
        loft(f"{name}_SilverPlate_{label}",rings,[PANEL,EDGE,STEEL],CHASSIS,slide,bevel=.0018,
             stripe=lambda edge,row: 1 if row==1 and edge<6 else 2 if row==0 else 0)
    for index in range(3):
        x=1.182+index*.156
        z=.382-index*.013
        rim=[(x-.051,z-.008),(x-.037,z+.008),(x+.052,z+.005),(x+.032,z-.011)]
        floor=[(x+.83*(u-x),z+.76*(w-z)) for u,w in rim]
        cut=slab(f"Tool_VentPocket_{label}_{index}",rim,[(side*.049,floor),(side*.126,None)],
                 [DARK],bevel=0)
        cut.display_type="WIRE"
        cut.hide_render=True
        cut.hide_set(True)
        boolean=shroud.modifiers.new(f"Recess {label} {index+1}","BOOLEAN")
        boolean.operation="DIFFERENCE"
        boolean.solver="EXACT"
        boolean.object=cut
        liner=[(x+.9*(u-x),z+.91*(w-z)) for u,w in floor]
        slab(f"Shroud_VentFloor_{label}_{index}",liner,[(side*.049,None),(side*.052,None)],[DARK],bevel=0)
    scarf=[(.978,.166),(1.001,.209),(1.047,.221),(1.098,.210),(1.055,.184),(1.022,.171)]
    slab(f"Receiver_ScarfJoint_{label}",scarf,[(side*.073,None),(side*.096,None)],[STEEL],bevel=.0018)
    groove=[(.075,.225),(.126,.245),(.447,.248),(.555,.262),(.848,.252),
            (.899,.235),(.826,.231),(.552,.237),(.429,.223),(.106,.215)]
    slab(f"Receiver_EnamelSeat_{label}",groove,[(side*.088,None),(side*.096,None)],[DARK],bevel=.0015)
    inlay=[(.106,.225),(.135,.236),(.450,.239),(.549,.252),(.834,.244),
           (.867,.237),(.552,.245),(.438,.230),(.134,.225)]
    slab(f"Receiver_StormBlueInlay_{label}",inlay,[(side*.095,None),(side*.098,None)],[BLUE],bevel=0)
    plaque=[(.168,.178),(.204,.196),(.356,.198),(.383,.184),(.353,.172),(.205,.171)]
    slab(f"Receiver_InlaidBadge_{label}",plaque,[(side*.091,None),(side*.097,None)],[DARK],bevel=.001)
    for i in range(3):
        x=.220+i*.033
        p=[(x,.177),(x+.011,.188),(x+.022,.188),(x+.012,.177)]
        slab(f"Mark_Tide_{label}_{i}",p,[(side*.096,None),(side*.099,None)],[STEEL],bevel=0)
    for x,z in [(-.102,.246),(.433,.196),(1.591,.244)]:
        y=side*(.091 if x<1.0 else .076)
        points=[(x+.009*math.cos(i*math.tau/6),z+.009*math.sin(i*math.tau/6)) for i in range(6)]
        slab(f"Rivet_{label}_{x}",points,[(y,None),(y+side*.009,None)],[STEEL],bevel=.001)

# Independently colored chamber liner and a compact moving shutter.
port = [(.344,.278),(.39,.349),(.617,.347),(.667,.312),(.614,.27),(.395,.267)]
slab("Ejection_Countersink",port,[(-.089,None),(-.102,None)],[STEEL])
inner = [(.369,.282),(.399,.333),(.607,.334),(.643,.311),(.606,.283),(.394,.277)]
slab("Ejection_IndigoRecess",inner,[(-.101,None),(-.105,None)],[DARK],bevel=0)
p = [(.407,.293),(.43,.325),(.592,.326),(.623,.307),(.587,.29)]
slab("Bolt_WaveShutter",p,[(-.104,None),(-.109,None)],[BODY],parent=BOLT,bevel=0)
charge = [(.635,.288),(.664,.324),(.79,.324),(.831,.3),(.784,.276),(.662,.275)]
slab("Charge_ActionPaddle",charge,[(.092,None),(.123,None)],[BODY],GRIP,CHARGE)
slab("Charge_NickelEnd",[(.763,.283),(.791,.316),(.813,.311),(.823,.299),(.785,.281)],
     [(.123,None),(.128,None)],[STEEL],GRIP,CHARGE,0)

# True holes in the muzzle cage: continuous rings at the bridge sections,
# radial windows between them, and closed reveal faces down into the dark cup.
pipe("Barrel_ExposedBluedStem",[(1.602,.041),(1.689,.041),(1.722,.038),(2.344,.038),
       (2.412,.043),(2.448,.038),(2.448,.026),(1.602,.026)],BODY,CHASSIS,count=12)
pipe("Barrel_ShroudFerrule",[(1.615,.044),(1.642,.055),(1.686,.052),(1.714,.047),
       (1.728,.043),(1.728,.037),(1.615,.037)],STEEL,CHASSIS)
pipe("Muzzle_BlueAdapter",[(2.367,.041),(2.393,.052),(2.454,.054),(2.472,.046),
                          (2.472,.037),(2.367,.037)],BODY,CHASSIS)
pipe("Muzzle_NickelKeeper",[(2.408,.051),(2.419,.053),(2.43,.051),(2.43,.043),(2.408,.043)],
     STEEL,CHASSIS)
def muzzle_cage():
    xs = [2.455,2.477,2.496,2.515,2.548,2.571,2.626,2.647]
    radii = [.043,.052,.052,.056,.056,.057,.059,.053]
    n = 12
    angle = [(j+.5)*math.tau/n for j in range(n)]
    verts = [(x+(0.009*math.sin(a) if 1<row<6 else 0),r*math.cos(a),.285+r*math.sin(a))
             for inner in [False,True] for row,(x,R) in enumerate(zip(xs,radii)) for r in [.033 if inner else R] for a in angle]
    faces, indices = [], []
    half = n*len(xs)
    def cell(row,j):
        return 0<=row<len(xs)-1 and not (row in {2,4} and j%3 in {0,1})
    for row in range(len(xs)-1):
        for j in range(n):
            if not cell(row,j):
                continue
            k=(j+1)%n
            a,b,c,d=row*n+j,row*n+k,(row+1)*n+k,(row+1)*n+j
            faces.extend([(a,b,c,d),(a+half,d+half,c+half,b+half)])
            indices.extend([0,1])
            for i,(first,second) in enumerate([(a,b),(b,c),(c,d),(d,a)]):
                neighbor = [(row-1,j),(row,k),(row+1,j),(row,(j-1)%n)][i]
                if not cell(*neighbor):
                    faces.append((second,first,first+half,second+half))
                    indices.append(2 if row in {0,6} else 1)
    return mesh("Muzzle_FourVentCage",verts,faces,[BODY,DARK,STEEL],CHASSIS,bevel=.002,roles=indices)
muzzle_cage()

# Preserve the real Vandal's short neck, high cheek and aft-only triangular opening.
hull("Stock_ShortReceiverNeck",[(-.467,.048,.221,.356),(-.396,.050,.218,.363),
       (-.245,.050,.221,.374),(-.174,.045,.232,.369)],[BODY,STEEL],STOCK,bevel=.003)
hull("Stock_SweptCheek",[
    (-1.122,.063,.225,.387),(-1.085,.066,.193,.415),(-.914,.067,.192,.418),
    (-.751,.066,.193,.416),(-.541,.060,.201,.410),(-.431,.054,.222,.393),
    (-.350,.048,.275,.364),(-.346,.044,.292,.34)
],[BODY,STEEL],STOCK,bevel=.004,stripes=lambda edge,row:int(edge in {1,7} and row in {1,2,3,4}))
strut=[(-1.105,-.152),(-1.069,-.149),(-1.028,-.121),(-.742,.172),(-.722,.206),
       (-.793,.219),(-.83,.178),(-1.091,-.081)]
slab("Stock_AftDiagonalStrut",strut,[(-.053,None),(.053,None)],[BODY],STOCK,bevel=.004)
heel=[(-1.247,-.157),(-1.202,-.176),(-1.117,-.151),(-1.099,-.112),(-1.11,.218),
      (-1.1,.371),(-1.116,.407),(-1.162,.418),(-1.247,.395),(-1.252,.358)]
slab("Stock_HeelForging",heel,[(-.072,None),(.072,None)],[BODY],STOCK,bevel=.004)
pad=[(-1.251,-.149),(-1.235,-.164),(-1.209,-.151),(-1.214,.366),
     (-1.228,.397),(-1.247,.387),(-1.252,.358)]
slab("Stock_ButtPad",pad,[(-.078,None),(.078,None)],[RUBBER],STOCK,bevel=.002)
for side in (1,-1):
    p=[(-1.093,.357),(-1.048,.390),(-.883,.391),(-.747,.375),(-.548,.374),
       (-.402,.346),(-.486,.308),(-.564,.285),(-.844,.266),(-1.072,.275)]
    facet=[(x+(min(-.58,max(-1.04,x))-x)*.061,z+.007+(z-.34)*-.19) for x,z in p]
    slab("Stock_CheekBlade",p,[(side*.039,None),(side*.066,None),(side*.073,facet)],
         [PANEL],STOCK,bevel=.002)
    bar=[(-1.116,-.107),(-1.077,-.111),(-.851,.135),(-.783,.184),(-.83,.181),(-1.08,-.055)]
    slab("Stock_StrutFlat",bar,[(side*.046,None),(side*.057,None)],[STEEL],STOCK,bevel=.0015)
    line=[(-1.044,.299),(-1.021,.315),(-.858,.313),(-.710,.325),
          (-.584,.320),(-.631,.300),(-.845,.292),(-1.028,.288)]
    slab("Stock_EnamelRecess",line,[(side*.072,None),(side*.075,None)],[BLUE],STOCK,bevel=.001)
    saddle=[(-.298,.236),(-.265,.256),(-.184,.269),(-.171,.319),(-.208,.361),(-.276,.336)]
    slab("Stock_ReceiverYoke",saddle,[(side*.043,None),(side*.060,None)],[STEEL],STOCK,bevel=.002)

# Samples measured from the host's grip and magazine surface loops.
GRIP_SECTIONS=[
 (.166,-.075,.125,.057),(.10,-.0857,.1275,.058),(.02,-.1331,.1261,.058),
 (-.06,-.1472,.0926,.058),(-.14,-.1614,.0731,.058),(-.22,-.1756,.0553,.058),
 (-.26,-.1826,.0326,.058),(-.29,-.166,.010,.054),(-.305,-.146,-.011,.047),
]
MAG_SECTIONS=[
 (.189,.468,.703,.052),(.135,.468,.710,.052),(.080,.478,.727,.051),
 (.020,.495,.751,.052),(-.040,.518,.777,.052),(-.100,.547,.808,.052),
 (-.160,.577,.843,.052),(-.220,.613,.883,.052),(-.280,.649,.929,.052),
 (-.335,.685,.979,.053),(-.386,.714,.984,.052)
]


def section_shape(t, sections):
    z=sections[0][0]+(sections[-1][0]-sections[0][0])*t
    for first,second in zip(sections,sections[1:]):
        if z>=second[0] or second is sections[-1]:
            alpha=(z-first[0])/(second[0]-first[0])
            lo,hi,depth=[a+(b-a)*alpha for a,b in zip(first[1:],second[1:])]
            return ((lo+hi)/2,z,(hi-lo)/2,depth)
    raise ValueError(t)


def grip_shape(t):
    return section_shape(t,GRIP_SECTIONS)


def mag_shape(t):
    return section_shape(t,MAG_SECTIONS)


def casing(name, shape, rows, materials, group, parent, rake):
    rings = []
    for t, xscale, yscale in rows:
        cx,z,hx,hy = shape(t)
        rings.append([(cx+x,y,z+rake*x) for x,y in octagon(hx*xscale,hy*yscale,.27)])
    return loft(name,rings,materials,group,parent,
                stripe=lambda edge,row:int(edge in {1,5} and len(materials)>1))


casing("Grip_AngledTang",grip_shape,[(0,.92,.9),(.1,1.06,1),(.37,1,1),(.62,1,1),
                                     (.89,1,1),(.99,.93,.88),(1,.8,.85)],
       [DARK,BODY],GRIP,BODY_CTRL,.04)
track_wrap("Grip_LeatherBind",grip_shape,[(.251,.385),(.385,.526),(.526,.682),(.681,.820),(.818,.958)],
           .12,[LEATHER,FOLD],GRIP,BODY_CTRL)
casing("Grip_HeelCollar",grip_shape,[(.94,1.02,1.09),(.98,1.03,1.07),(1.02,.82,.90)],
       [BODY,STEEL],GRIP,BODY_CTRL,.04)
guard_o = [(.111,.033),(.135,.014),(.348,.015),(.394,.040),(.423,.138),(.389,.157),(.115,.149)]
guard_i = [(.143,.057),(.172,.045),(.342,.048),(.372,.059),(.394,.120),(.372,.133),(.146,.133)]
frame("TriggerGuard_RakedLoop",guard_o,guard_i,.032,[BODY,STEEL],GRIP,.006)
slab("Trigger_Crescent",[(.194,.161),(.238,.162),(.23,.118),(.217,.081),(.203,.08),(.204,.114)],
     [(-.011,None),(.011,None)],[STEEL],GRIP)
casing("Mag_CurvedIndigoBody",mag_shape,[(0,.81,.90),(.11,.97,1),(.23,1.01,1),(.43,1,1),
        (.65,1,1),(.82,1,1),(.98,1,1),(1,.96,.96)],[BODY,DARK],MAG,MAG_CTRL,.086)
track_wrap("Mag_LeatherBind",mag_shape,[(.334,.480),(.477,.636),(.635,.789),(.788,.951)],
           .15,[LEATHER,FOLD],MAG,MAG_CTRL)
casing("Mag_HeelShockShoe",mag_shape,[(.928,1.01,1.16),(.950,1.07,1.20),
        (.992,1.04,1.18),(1.013,.96,1.10)],[BODY,DARK],MAG,MAG_CTRL,.086)
casing("Mag_UpperFeedCrown",mag_shape,[(-.061,.79,.91),(-.037,.93,1),(.024,1,1.04),
        (.117,.98,1.05),(.233,.99,1.1),(.255,.93,.95)],[BODY,BLUE],MAG,MAG_CTRL,.086)
for side in (1,-1):
    side_insert=[(.476,.094),(.526,.135),(.719,.148),(.751,.12),(.711,.071),(.496,.053)]
    slab("Magazine_FeedShoulder",side_insert,[(side*.047,None),(side*.061,None)],[BLUE],MAG,MAG_CTRL)
    for index in range(3):
        t = .962+index*.015
        cx,z,hx,hy=mag_shape(t)
        tube("Mag_HeelConduitInset",[(cx-hx*.55,side*.061,z-.007),
             (cx-hx*.23,side*.064,z),(cx+hx*.38,side*.064,z+.005)],
             .0022,[STEEL],MAG,MAG_CTRL,sides=4)

# A single metal crescent on the stock sight center. The thin highlight
# is part of the same cross-section as the dark outer arch.
hull("Sight_SaddleSeat",[(-.018,.029,.438,.453),(.013,.044,.442,.467),
      (.073,.042,.444,.473),(.126,.035,.443,.469),(.152,.024,.434,.451)],
      [BODY,STEEL],SIGHTS,bevel=.002)
hull("Sight_CrescentBridge",[(.053,.022,.465,.492),(.070,.028,.462,.500),
      (.095,.026,.463,.498),(.11,.018,.464,.485)],[DARK,STEEL],SIGHTS,bevel=.0018)
arc=[]
for i in range(33):
    angle=math.radians(127+i*(286/32))
    # The near edge taps down at the tips to frame the center with two small cuts.
    cutter=1-.058*(abs(i-16)/16)**4
    arc.append([(x,r*math.cos(angle)*cutter,.5598+r*math.sin(angle))
        for x,r in [(.065,.061),(.096,.061),(.102,.068),(.096,.077),
                    (.068,.077),(.061,.069)]])
loft("Sight_OnePieceOpenCrescent",arc,[BODY,STEEL,EDGE,SIGHT_MARK],SIGHTS,bevel=.001,
     stripe=lambda edge,row: 3 if row in {0,31} and edge==5 else 2 if edge==5
     else 1 if edge in {1,2} else 0)

# Seat the front reference on the exposed barrel at its original x station.
pipe("Sight_FrontBarrelSaddle",[(1.947,.041),(1.970,.053),(2.068,.052),
     (2.095,.042),(2.095,.037),(1.947,.037)],BODY,SIGHTS)
hull("Sight_FrontSaddleNose",[(1.948,.025,.28,.346),(1.976,.037,.282,.385),
      (2.064,.039,.281,.391),(2.092,.029,.273,.347)],[BODY,STEEL],SIGHTS,bevel=.002)
for side in (1,-1):
    fin=[(1.95,.337),(1.967,.373),(1.988,.491),(2.010,.544),
         (2.025,.534),(2.031,.441),(2.074,.357),(2.084,.331)]
    facet=[(x+(2.014-x)*.14,z+(z-.41)*-.055) for x,z in fin]
    slab("Sight_FrontWing",fin,[(side*.021,None),(side*.045,None),(side*.049,facet)],
         [BODY],SIGHTS,bevel=.0017)
slab("Sight_FrontReference",[(1.986,.361),(1.99,.539),(1.998,.550),
     (2.014,.549),(2.021,.53),(2.027,.357)],[(-.007,None),(.007,None)],[STEEL],SIGHTS,bevel=.0015)
slab("Sight_FrontCeramicReference",[(1.99,.539),(1.998,.55),(2.009,.55),(2.01,.54)],
     [(-.0038,None),(.0038,None)],[SIGHT_MARK],SIGHTS,bevel=0)

# Position-only anchors for a later runtime effects pass.
for name, position, parent in [
    ("FXSocket_ForeInlet", (1.615,.064,.34), BODY_CTRL),
    ("FXSocket_ReceiverOutlet", (.37,.105,.375), BODY_CTRL),
    ("FXSocket_StockReturn", (-1.14,.059,.26), BODY_CTRL),
    ("FXSocket_Magazine", (.67,.05,-.14), MAG_CTRL),
    ("FXSocket_InspectBalance", (.67,0,.217), BALANCE),
]:
    socket=empty(name,position,parent)
    RIG.objects.unlink(socket)
    GUIDES.objects.link(socket)
GUIDES.hide_viewport=True

# Exact stock attachment geometry. The empty loop is the only visible buddy hardware.
fixture=REF.objects["Vandal_CharmLoop"]
fixture_matrix=STOCK_TRANSFORMS[fixture.name]
source_roles=[DARK if source.name in {"Dark","Body"} else STEEL for source in fixture.data.materials]
mount=mesh("BuddyMount_StockPlateAndLoop",
           [fixture_matrix @ v.co for v in fixture.data.vertices],
           [tuple(face.vertices) for face in fixture.data.polygons],source_roles,JEWELS,
           roles=[face.material_index for face in fixture.data.polygons])
mount["source"]="Vandal_CharmLoop from stock Vandal v05; no equipped charm"

def camera(name, location, target, size, ortho=True):
    data=bpy.data.cameras.new(name)
    obj=bpy.data.objects.new(name,data)
    STAGE.objects.link(obj)
    obj.location=location
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()
    data.type="ORTHO" if ortho else "PERSP"
    if ortho:
        data.ortho_scale=size
    else:
        data.lens=size
    return obj


def lamp(name, location, target, power, size, color, length=None):
    data=bpy.data.lights.new(name,"AREA")
    obj=bpy.data.objects.new(name,data)
    STAGE.objects.link(obj)
    obj.location=location
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()
    data.energy, data.size, data.color = power,size,color
    if length:
        data.shape="RECTANGLE"
        data.size_y=length
    return obj


SCENE.world=bpy.data.worlds.new("Tempest | Neutral studio")
SCENE.world.use_nodes=True
SCENE.world.node_tree.nodes["Background"].inputs[0].default_value=(.14,.18,.23,1)
SCENE.world.node_tree.nodes["Background"].inputs[1].default_value=.36
lamp("Key | broad daylight", (1.3,2.9,4),(.55,0,0),370,4.0,(1,.94,.89),2.8)
lamp("Rim | silver planes", (1.2,-2,3.3),(.73,0,0),460,3.6,(.76,.89,1),1.5)
lamp("Fill | reflected", (1.5,2.6,-1.3),(.55,0,.13),94,3.2,(.80,.91,1),2.5)
lamp("Edge | stock", (-2.6,1.8,1.3),(-.3,0,.14),90,2,(1,.86,.73),2.3)
lamp("Softbox | far side", (2,-3,1.4),(.9,0,.09),230,3.0,(1,.97,.95),2.2)
center=(.69,0,.104)
SCENE.camera=camera("Review_Hero",(4.7,8.8,3.7),center,4.25)
camera("Review_Side",(.69,8,.104),center,4.25)
camera("Review_Opposite",(.69,-8,.104),center,4.25)
camera("Review_Top",(.69,0,9),center,4.25)
camera("Review_Underside",(.8,-2.1,-6),center,4.25)
camera("Review_Back",(-4.8,.19,.35),(.7,0,.107),1.3)
camera("Review_Front",(6.8,0,.12),(.7,0,.12),1.26)
camera("Review_RearQuarter",(-3.9,-6.9,3.3),center,4.1)
camera("Review_Mag", (1.67,2.1,-.21),(.74,0,-.19),.77)
camera("Review_Sight",(-.75,1.9,1.25),(.09,0,.51),.6)
camera("Review_Charm",(1.16,1.4,.39),(.93,.092,.184),.33)
camera("Review_Muzzle",(3.4,1.8,.67),(2.32,0,.296),.82)
camera("Review_Stock",(-1.84,2.2,.71),(-.74,0,.15),1.41)
camera("Review_Grip",(.46,2.2,-.14),(.025,0,-.066),.64)
round_group=collection("10 • Hydro-core round")
round_ctrl=empty("CTRL_HydroCoreRound",(0,0,0))
def shell(name, sections, mats):
    return loft(name,[[(x,r*math.cos(a),r*math.sin(a))
           for a in [i*math.tau/10 for i in range(10)]] for x,r in sections],
           mats,round_group,round_ctrl,stripe=lambda edge,row:int(len(mats)>1 and edge in {1,2,3}))


shell("Round_DarkSilverTaper",[(.076,.023),(.096,.023),(.117,.014),(.13,.004)], [STEEL,PANEL])
shell("Round_PressureGlass",[(-.078,.022),(-.071,.027),(.061,.027),(.076,.023)],[GLASS])
shell("Round_RearCollar",[(-.112,.018),(-.109,.028),(-.079,.029),(-.073,.026)],[BODY,PANEL])
shell("Round_FrontCollar",[(.044,.026),(.049,.03),(.074,.028),(.081,.023)],[STEEL,PANEL])
shell("Round_HydroCoreInsert",[(-.077,.011),(-.018,.015),(.041,.013),(.083,.007)],[BLUE])
camera("Review_Round",(.32,.51,.29),(.007,0,0),.32)
round_group.hide_render=True
round_group.hide_viewport=True
SCENE.render.engine="CYCLES"
SCENE.cycles.samples=24
SCENE.cycles.use_denoising=True
SCENE.view_settings.view_transform="AgX"
SCENE.render.resolution_x=1500
SCENE.render.resolution_y=740
SCENE.render.resolution_percentage=100
SCENE.render.film_transparent=True
SCENE.render.image_settings.color_mode="RGBA"
SCENE.render.fps=30
SCENE.frame_start=1
SCENE.frame_set(1)
SCENE["coordinate_contract"]="Stock Vandal, muzzle +X, player side +Y, units in studs"
SCENE["armor_ownership"]="Rigid slide controls on both flanks, magazine has its own core, wrap and deferred effect socket"
SCENE["look"]="Storm Shadow | Stock-matched form pass"


def save(version):
    target=DEST/version/f"Vandal_TempestStrike_StormShadow_{version}.blend"
    target.parent.mkdir(parents=True,exist_ok=True)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type != "VIEW_3D":
                continue
            view=area.spaces.active
            view.shading.type="SOLID"
            view.shading.color_type="MATERIAL"
            view.overlay.show_extras=False
            view.overlay.show_floor=False
            view.overlay.show_axis_x=False
            view.overlay.show_axis_y=False
            view.region_3d.view_perspective="ORTHO"
            view.region_3d.view_distance=5.3
            view.region_3d.view_location=(.65,0,.115)
            view.region_3d.view_rotation=SCENE.objects["Review_Hero"].rotation_euler.to_quaternion()
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(target), compress=True)


if __name__ == "__main__":
    save("v11")
