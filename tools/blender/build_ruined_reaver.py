"""Rebuild the Ruined Reaver silhouette against the owner turnarounds."""

import json
from math import cos, sin, tau

import bpy
from mathutils import Vector

import build_ruin_blighted_expansion as art


# Meshy's tighter silhouette informs the shoulder, bevel and keyed fracture
# lines. Moving stone remains separate around an almost continuous edge.
PLATES = {
    "Heel": ((.58,-.055),(.77,-.126),(.95,-.153),(1.10,-.239),(1.36,-.222),
             (1.60,-.211),(1.51,-.108),(1.63,-.043),(1.54,.046),(1.65,.160),
             (1.57,.239),(1.29,.232),(1.10,.277),(.92,.169),(.77,.149),(.61,.061)),
    "Edge": ((1.63,-.219),(1.55,-.113),(1.69,-.052),(1.77,-.074),
             (1.84,-.127),(2.13,-.104),(2.24,-.129),(2.45,-.118),(2.57,-.143),
             (2.43,-.193),(2.44,-.220),(2.24,-.238),(2.04,-.208),(1.83,-.227)),
    "Shoulder": ((1.58,.056),(1.69,.159),(1.61,.241),(1.80,.264),(2.05,.238),
                 (2.27,.257),(2.60,.221),(2.49,.172),(2.54,.123),(2.30,.096),
                 (2.09,.135),(1.94,.092),(1.74,.082),(1.65,.045)),
    "Keystone": ((1.63,.030),(1.76,.054),(1.95,.058),(2.08,.109),(2.30,.068),
                 (2.55,.099),(2.67,.043),(2.50,-.017),(2.53,-.082),(2.29,-.104),
                 (2.12,-.077),(1.85,-.097),(1.72,-.021)),
    "Point": ((2.63,-.159),(2.48,-.197),(2.73,-.172),(3.05,-.117),(3.29,-.048),
              (3.66,.065),(3.27,.183),(2.97,.227),(2.65,.222),(2.53,.164),
              (2.60,.107),(2.72,.040),(2.55,-.032),(2.58,-.085)),
    "SpineChip": ((1.48,.286),(1.58,.307),(1.73,.305),(1.66,.273),(1.55,.268)),
    "EdgeChip": ((1.94,-.270),(2.06,-.281),(2.19,-.266),(2.10,-.314),(1.99,-.309)),
    "TipChip": ((2.66,.256),(2.77,.275),(2.87,.265),(2.82,.241),(2.70,.238)),
}

# Each face has a central vein and short branches, placed at the bevel plane
# rather than floating over the stone. The exposed seams have their own joints.
ETCH = {
    "Heel": (((.72,.009),(.94,-.021),(1.05,.035),(1.26,.017),(1.44,.049),(1.57,-.021)),
             ((1.05,.035),(1.12,.103),(1.11,.171),(1.23,.187)),
             ((1.26,.017),(1.21,-.074),(1.33,-.102),(1.39,-.159))),
    "Edge": (((1.64,-.112),(1.79,-.167),(1.96,-.156),(2.04,-.174),(2.19,-.151),(2.35,-.164)),),
    "Shoulder": (((1.72,.133),(1.89,.161),(2.02,.152),(2.23,.207),(2.41,.192),(2.50,.146)),),
    "Keystone": (((1.72,.010),(1.88,-.027),(2.01,-.014),(2.12,.032),
                  (2.27,.003),(2.40,.042),(2.59,.038)),
                 ((2.12,.032),(2.16,.061),(2.26,.049))),
    "Point": (((2.62,-.055),(2.78,.027),(2.91,.041),(3.02,.096),(3.23,.092),(3.45,.070)),
              ((2.91,.041),(2.96,-.017),(3.07,-.054),(3.18,-.039))),
}

GUARD = ((.357,-.045),(.398,.116),(.347,.253),(.369,.406),(.442,.500),
         (.597,.583),(.812,.605),(.719,.553),(.619,.497),(.548,.402),
         (.525,.318),(.554,.229),(.643,.195),(.703,.232),(.820,.310),
         (.813,.243),(.728,.131),(.608,.089),(.592,-.034))


def engrave(col, name, path, y, width, role):
    points = [Vector(p) for p in path]
    top, bottom = [], []
    for i, point in enumerate(points):
        tangent = (points[min(i+1,len(points)-1)] - points[max(0,i-1)]).normalized()
        normal = Vector((-tangent.y, tangent.x))
        half = width * (.18 if i in (0,len(points)-1) else .50 if i % 2 else .34)
        top.append(tuple(point + normal * half))
        bottom.append(tuple(point - normal * half))
    inside = y - (.004 if y > 0 else -.004)
    return art.trim(col,name,top + bottom[::-1],inside,y,role,0)


def blade(col, name, profile):
    middle = sum((Vector(p) for p in profile), Vector((0, 0))) / len(profile)
    depth = .039 if name in ETCH else .017
    cut = [Vector(p).lerp(middle, .23 if name in ETCH else .27) for p in profile]
    n = len(profile)
    verts = [(x, 0, z) for x, z in profile]
    faces = []
    slots = []
    for sign in (-1, 1):
        start = len(verts)
        verts.extend((p.x, sign * depth, p.y) for p in cut)
        for i in range(n):
            j = (i + 1) % n
            a, b, c, d = i, j, start+j, start+i
            faces.extend(((a,b,d), (b,c,d)))
            slots.extend((1 if i % 4 != 1 else 2, 2 if i % 3 == 1 else 1))
        faces.append(tuple(range(start,start+n)))
        slots.append(0)
    obj = art.mesh(col, "RB_Reaver_" + name, verts, faces, art.PAL["Obsidian"])
    for role in ("Slate", "Ridge"):
        obj.data.materials.append(art.PAL[role])
    for face, slot in zip(obj.data.polygons, slots, strict=True):
        face.material_index = slot
    pieces = [obj]
    for sign in (-1,1):
        for index, path in enumerate(ETCH.get(name, ())):
            width = .019 if index == 0 else .008
            if index == 0:
                pieces.append(engrave(col, f"RB_Reaver_{name}_RiftShadow_{sign}", path,
                                      sign*(depth+.0009), width*4.5, "Deep seam"))
            pieces.append(engrave(col, f"RB_Reaver_{name}_Light_{sign}_{index}", path,
                                  sign*(depth+.002), width*.69, "Seafoam"))
    return pieces, Vector((middle.x, 0, middle.y))


def hilt(col):
    parts = [art.beam(col, "RB_Reaver_Tang", (-.57,0,0), (.83,0,0), .052, art.PAL["Metal"], 10),
             art.beam(col, "RB_Reaver_Grip", (-.57,0,0), (.42,0,0), .068, art.PAL["Fabric"], 10)]
    for i in range(13):
        # Offset the overlapped cloth edge around the grip, with scalloped
        # material at the raised fold and extra thickness toward the ends.
        x = -.552 + i * .075
        radius = .074 + .005 * cos(i * tau / 12)
        facets = 12
        verts = []
        for dx, r in ((-.046, .068), (-.031, radius), (.024, radius-.001), (.046, .068)):
            for j in range(facets):
                theta = j*tau/facets
                verts.append((x+dx+.041*cos(theta)+.003*sin(j*2.3+i), r*cos(theta), r*sin(theta)))
        faces = [tuple(range(facets)), tuple(range(3*facets,4*facets))]
        for k in range(3):
            for j in range(facets):
                a, b = k*facets, (k+1)*facets
                nxt = (j+1)%facets
                faces.append((a+j,a+nxt,b+nxt,b+j))
        strip = art.mesh(col, f"RB_Reaver_Wrap_{i:02}", verts, faces, art.PAL["Fabric"])
        strip.data.materials.append(art.PAL["Fabric edge"])
        for face in strip.data.polygons[2:facets+2]:
            face.material_index = 1
        parts.append(strip)
    for x in (-.574,.388):
        parts.append(art.beam(col,"RB_Reaver_GripCollar",(x-.021,0,0),(x+.021,0,0),
                             .079,art.PAL["Bronze edge"],10))
    for i,(x,y,l) in enumerate(((.145,.062,.242),(.086,-.063,.174))):
        parts.append(art.trim(col, f"RB_Reaver_WrapTail_{i}",
            [(x-.045,-.047),(x+.029,-.075),(x-.003,-.119),(x-.072,-l),
             (x-.047,-l*.80),(x-.075,-l*.87),(x-.055,-.105)], y*.82,y,"Fabric",.004))
    for sign in (1,-1):
        # The two guard horns are thick at the quillon and taper to the
        # pointed ends, with an incised profile on the front and back.
        flip = lambda path: [(x+(0 if sign>0 else .025), z*sign*(1 if sign>0 else .88)) for x,z in path]
        horn = art.trim(col,f"RB_Reaver_Quillon_{sign}",flip(GUARD),-.059,.059,"Bronze",.015)
        parts.append(horn)
        for face in (-1,1):
            for i,(path, width, role) in enumerate((
                (((.412,.137),(.390,.280),(.418,.430),(.493,.513),(.652,.568),(.746,.583)), .019,"Bronze edge"),
                (((.443,.116),(.424,.275),(.452,.397),(.521,.486),(.617,.531)), .037,"Patina"),
                (((.475,.093),(.507,.189),(.459,.284),(.489,.381),(.535,.452)), .012,"Bronze edge"),
                (((.489,.095),(.568,.128),(.643,.123),(.714,.175),(.754,.225)), .015,"Bronze edge"),
                (((.513,.138),(.575,.156),(.630,.157),(.678,.188)), .009,"Patina"),
            )):
                parts.append(engrave(col,f"RB_Reaver_Chisel_{sign}_{face}_{i}",flip(path),face*.061,width,role))
    for face in (-1,1):
        boss = ((.317,0),(.389,-.078),(.510,-.133),(.614,-.099),(.719,-.097),(.877,0),
                (.717,.092),(.606,.095),(.510,.139),(.385,.086))
        parts.append(art.trim(col,f"RB_Reaver_GuardSeat_{face}",boss,face*.045,face*.081,"Bronze",.013))
        inner = ((.369,0),(.463,-.056),(.508,-.092),(.610,-.056),(.782,0),
                 (.610,.055),(.506,.092),(.461,.056))
        parts.append(art.trim(col,f"RB_Reaver_GuardRecess_{face}",inner,
                              face*.079,face*.084,"Patina",.0024))
        parts.append(engrave(col,f"RB_Reaver_GuardInlay_{face}",
            ((.411,.001),(.511,.063),(.570,.037),(.663,.030),(.753,0)),
            face*.086,.012,"Bronze edge"))
        parts.append(engrave(col,f"RB_Reaver_GuardFissure_{face}",
            ((.511,-.034),(.550,0),(.522,.040)),face*.086,.013,"Seafoam"))
    for face in (-1,1):
        for i, outline in enumerate((
            ((-.765,.012),(-.738,.070),(-.687,.101),(-.596,.066),(-.596,.014),(-.669,.028)),
            ((-.783,-.005),(-.717,-.089),(-.663,-.100),(-.599,-.054),(-.598,-.008),(-.676,.007)),
        )):
            parts.append(art.trim(col,f"RB_Reaver_PommelCut_{face}_{i}",outline,0,face*.068,
                                  "Obsidian",.010))
        path = ((-.767,.004),(-.717,-.011),(-.675,.014),(-.647,-.001),(-.596,.013))
        parts.append(engrave(col,f"RB_Reaver_PommelFissure_{face}",path,face*.066,.010,"Seafoam"))
    return parts


LINKS = (
    ("Heel","Shoulder",(1.55,.033,.128),(1.73,.033,.133)),
    ("Heel","Edge",(1.48,.033,-.092),(1.66,.034,-.125)),
    ("Shoulder","Point",(2.48,.034,.155),(2.74,.033,.151)),
    ("Keystone","Point",(2.52,.038,.035),(2.70,.036,-.026)),
)


def build(dest=None):
    if dest is None:
        dest = art.next_version("RuinedReaver")
    scene = art.read_scene("Knife")
    art.setup(scene)
    scene.render.fps = 30
    art.palette()
    # Darker body and a brighter exposed frost vein match the owner sheet.
    for role,(hex_color,metal,rough,emit) in {
        "Obsidian":("15232C",.16,.52,0), "Slate":("2B3C46",.25,.51,0),
        "Ridge":("405562",.28,.48,0), "Bronze":("65553B",.55,.48,0),
        "Deep seam":("276A60",.12,.43,.21), "Seafoam":("72EFCF",.08,.42,.85),
    }.items():
        art.PAL[role] = art.material(f"Ruin-Blighted / {role}",hex_color,metal,rough,emission=emit)
    base = art.stock.meshes("Knife")
    for obj in base:
        obj.hide_render = True
        obj.hide_set(True)
    col = art.collection(scene,"Ruined Reaver | Model")
    cameras = art.collection(scene,"Ruined Reaver | Review cameras")
    grip = hilt(col)
    blade_parts, pivots = {}, {}
    for name, outline in PLATES.items():
        blade_parts[name], pivots[name] = blade(col,name,outline)
    layout = [("Root",(0,0,0),None),("RightHand",(-.20,0,0),"Root"),("LeftHand",(-.54,0,0),"Root")]
    layout.extend((name,pivot,"Root") for name,pivot in pivots.items())
    rig = art.armature(col, "Ruined Reaver | Motion rig", layout)
    for obj in grip:
        art.bind(obj,rig,"Root")
    for name, pieces in blade_parts.items():
        for obj in pieces:
            art.bind(obj,rig,name)
    for name, p, bone in (("RightGrip",(-.20,0,0),"RightHand"),("LeftGrip",(-.54,0,0),"LeftHand"),
                          ("TrailRoot",(.72,0,0),"Root"),("TrailTip",(3.64,0,.061),"Point")):
        art.bind(art.locator(col,"Reaver_"+name,p),rig,bone)
    objects = grip + [obj for pieces in blade_parts.values() for obj in pieces]
    coords = art.points(objects)
    for name, angle in (("hero",(-.24,.89,.27)),("profile",(0,1,0)),("edge",(0,0,1))):
        camera = art.framed_camera(cameras,f"Reaver {name}",coords,angle,1.8,1.16)
        art.render(scene,camera,dest/"review"/f"{name}.png",1,(1440,800))
        if name == "hero":
            hero = camera
    art.sword_actions(rig,pivots)
    scene.camera = hero
    scene.frame_set(1)
    output = dest / f"RuinedReaver_{art.LINE}_{dest.name}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(output))

    # The uploaded variant follows the current Knife rig and support hand.
    stock = bpy.data.objects["Knife_Rig"]
    stock.data.pose_position = "REST"
    movers = [(pieces[0],"Root",pivots[name],"Receiver",Vector((.1,.8,.2)),.035)
              for name,pieces in blade_parts.items()]
    for obj in objects:
        world = obj.matrix_world.copy()
        art.bind(obj,stock,"Root")
        obj.matrix_world = world
    scene.view_layers[0].update()
    joints = art.rig_shards(stock,movers)
    joint_by_piece = {piece:j["name"] for piece,j in zip(PLATES,joints,strict=True)}
    for name,pieces in blade_parts.items():
        for obj in pieces[1:]:
            world = obj.matrix_world.copy()
            obj.parent_bone = joint_by_piece[name]
            scene.view_layers[0].update()
            obj.matrix_world = world
    energy = []
    for i,(a,b,p,q) in enumerate(LINKS,1):
        for suffix,piece,point in (("A",a,p),("B",b,q)):
            energy.append({"name":f"RuinBladeLink{i}{suffix}","bone":joint_by_piece[piece],
                           "point":point,"mist":False,"phase":i*.27})
    scene.view_layers[0].update()
    parts, tris = art.export_variant("RuinedReaver",dest,stock,objects,
        [o.name.removeprefix("Knife_") for o in base],movers,energy,skin_item="RuinedReaver",joints=joints)
    manifest_path = dest/"manifest_flat.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    tones = {"213039":"15232C","354D57":"2B3C46","55707A":"405562","544831":"65553B","73EDCE":"72EFCF"}
    for part in manifest["parts"].values():
        part["col"] = tones.get(part["col"],part["col"])
    manifest_path.write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    (dest/"review/checks.json").write_text(json.dumps({
        "length": round(max(p.x for p in coords)-min(p.x for p in coords), 3),
        "bladeDepth": .078, "castPieces": len(blade_parts), "parts": parts, "triangles": tris,
    },indent=2)+"\n",encoding="utf-8")
    return str(output)
