"""Build the stock-fitted Storm Shadow hero in separately inspectable passes."""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "art-source/weapons/Skins/TempestStrike/Vandal"
STOCK_FILE = ROOT / "art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend"
SceneName = "Tempest-Strike | Storm Shadow"


def stock_scene():
    stock = bpy.data.scenes.get("Stock Vandal | Reference")
    if stock:
        return stock
    with bpy.data.libraries.load(str(STOCK_FILE), link=False) as (source, copied):
        copied.scenes = source.scenes
    stock = next(scene for scene in copied.scenes if "Vandal_Rig" in scene.objects)
    stock.name = "Stock Vandal | Reference"
    return stock


def color(hex_code):
    channels = [int(hex_code[i:i + 2], 16) / 255 for i in range(0, 6, 2)]
    return tuple(x / 12.92 if x < .04045 else ((x + .055) / 1.055) ** 2.4 for x in channels)


class Workshop:
    def __init__(self):
        self.stock = stock_scene()
        bpy.context.window.scene = self.stock
        bpy.context.view_layer.update()
        self.stock_matrices = {o.name: o.matrix_world.copy() for o in self.stock.objects}
        self.scene = bpy.data.scenes.new(SceneName)
        bpy.context.window.scene = self.scene
        self.rig = self.group("01 • Rig and stock locators")
        self.chassis = self.group("02 • Receiver and shroud")
        self.stock_group = self.group("03 • Stock")
        self.grip = self.group("04 • Grip and controls")
        self.magazine = self.group("05 • Magazine")
        self.sights = self.group("06 • Sights")
        self.sockets = self.group("07 • Position guides")
        self.mount = self.group("08 • Empty buddy mount")
        self.stage = self.group("09 • Review stage")
        self.round = self.group("10 • Round")
        self.origin = self.empty("CTRL_Action", (0, 0, 0))
        self.balance = self.empty("CTRL_InspectBalance", (.67, 0, .217), self.origin)
        self.body = self.empty("CTRL_Chassis", (0, 0, 0), self.balance)
        self.mag = self.empty("CTRL_Magazine", (.5828, 0, .155), self.body)
        self.charge = self.empty("CTRL_Charge", (.6572, .08, .3069), self.body)
        self.bolt = self.empty("CTRL_Bolt", (.4898, -.06, .3162), self.body)
        self.coal = self.material("Body · carbon-black ceramic", "252E3B", .24, .44, .31)
        self.well = self.material("Dark · recessed graphite", "121824", .16, .51, .05)
        self.ceramic = self.material("Panel · slate ceramic", "5A6C81", .28, .37, .34)
        self.silver = self.material("PanelEdge · polished edge", "A8BED0", .72, .30, .24)
        self.steel = self.material("Metal · blued steel", "454F60", .70, .35, .15)
        self.blue = self.material("Accent · cobalt ceramic", "17588F", .32, .32, .38)
        self.bright_blue = self.material("AccentEdge · cobalt facet", "377FBE", .37, .275, .31)
        self.leather = self.material("Grip · smoked leather", "342825", 0, .64, .025, grain=True)
        self.raw_edge = self.material("GripEdge · pressed seam", "241B1B", 0, .68, .018, grain=True)
        self.rubber = self.material("Rubber · contact pads", "252832", .03, .70, .03)
        self.mark = self.material("SightMark · cool ceramic", "A2CBD1", .15, .45, .04)
        self._transfer_stock()

    @classmethod
    def resume(cls):
        work = cls.__new__(cls)
        work.scene = bpy.data.scenes[SceneName]
        work.stock = stock_scene()
        bpy.context.window.scene = work.stock
        bpy.context.view_layer.update()
        work.stock_matrices = {o.name:o.matrix_world.copy() for o in work.stock.objects}
        bpy.context.window.scene = work.scene
        names = ("rig","chassis","stock_group","grip","magazine","sights","sockets","mount","stage","round")
        for i,name in enumerate(names,1):
            group = next(c for c in work.scene.collection.children if c.name.startswith(f"{i:02}"))
            setattr(work,name,group)
        for key, name in [
            ("origin","Action"),("balance","InspectBalance"),("body","Chassis"),
            ("mag","Magazine"),("charge","Charge"),("bolt","Bolt"),
        ]:
            setattr(work,key,work.scene.objects["CTRL_" + name])
        roles = [("coal","Body"),("well","Dark"),("ceramic","Panel"),("silver","PanelEdge"),
                 ("steel","Metal"),("blue","Accent"),("bright_blue","AccentEdge"),("leather","Grip"),
                 ("raw_edge","GripEdge"),("rubber","Rubber"),("mark","SightMark")]
        for attr,role in roles:
            mat = next(m for m in bpy.data.materials if m.name.startswith(f"TS_{role} ·"))
            setattr(work,attr,mat)
        return work

    def group(self, name):
        group = bpy.data.collections.new(name)
        self.scene.collection.children.link(group)
        return group

    def material(self, role, hex_code, metal, rough, coat, grain=False):
        mat = bpy.data.materials.new("TS_" + role)
        mat.use_fake_user = True
        mat.use_nodes = True
        mat.diffuse_color = (*color(hex_code), 1)
        mat["role"], mat["srgb"] = role, hex_code
        node = mat.node_tree.nodes.get("Principled BSDF")
        node.inputs["Base Color"].default_value = mat.diffuse_color
        node.inputs["Metallic"].default_value = metal
        node.inputs["Roughness"].default_value = rough
        node.inputs["Coat Weight"].default_value = coat
        node.inputs["Coat Roughness"].default_value = .32
        if grain:
            nodes, links = mat.node_tree.nodes, mat.node_tree.links
            noise = nodes.new("ShaderNodeTexNoise")
            noise.inputs["Scale"].default_value = 174
            noise.inputs["Detail"].default_value = 2.2
            tex = nodes.new("ShaderNodeTexCoord")
            bump = nodes.new("ShaderNodeBump")
            bump.inputs["Strength"].default_value = .23
            bump.inputs["Distance"].default_value = .0033
            links.new(tex.outputs["Object"], noise.inputs["Vector"])
            links.new(noise.outputs["Fac"], bump.inputs["Height"])
            links.new(bump.outputs["Normal"], node.inputs["Normal"])
        return mat

    def empty(self, name, anchor, parent=None, group=None):
        obj = bpy.data.objects.new(name, None)
        (group or self.rig).objects.link(obj)
        obj.empty_display_type = "PLAIN_AXES"
        obj.empty_display_size = .037
        obj.parent = parent
        bpy.context.view_layer.update()
        obj.location = parent.matrix_world.inverted() @ Vector(anchor) if parent else anchor
        return obj

    def _transfer_stock(self):
        original = self.stock.objects["Vandal_Rig"]
        rig = original.copy()
        rig.data = original.data.copy()
        rig.name = "Vandal_StockRig"
        self.rig.objects.link(rig)
        rig.parent = self.body
        for src in self.stock.objects:
            is_locator = src.type == "EMPTY"
            is_camera = src.name in {"Vandal_Cam_Hip", "Vandal_Cam_ADS", "Vandal_FP_ADS"}
            if not (is_locator or is_camera):
                continue
            obj = src.copy()
            (self.rig if is_locator else self.stage).objects.link(obj)
            obj.name = "TS_" + src.name
            if is_locator:
                obj.parent = rig
                obj.empty_display_size = .027

    def mesh(self, name, vertices, faces, materials, group=None, parent=None, roles=None):
        group = self.chassis if group is None else group
        parent = self.body if parent is None else parent
        points = [Vector(v) for v in vertices]
        pivot = sum(points, Vector()) / len(points)
        data = bpy.data.meshes.new(name)
        data.from_pydata([p - pivot for p in points], [], faces)
        data.update()
        for mat in materials:
            data.materials.append(mat)
        if roles:
            for face, role in zip(data.polygons, roles):
                face.material_index = role
        edit = bmesh.new()
        edit.from_mesh(data)
        bmesh.ops.recalc_face_normals(edit, faces=list(edit.faces))
        edit.to_mesh(data)
        edit.free()
        obj = bpy.data.objects.new(name, data)
        group.objects.link(obj)
        obj.parent = parent
        bpy.context.view_layer.update()
        obj.location = parent.matrix_world.inverted() @ pivot
        return obj

    def loft(self, name, rings, materials, group=None, parent=None, face_role=None, loop=False):
        n = len(rings[0])
        points = [v for ring in rings for v in ring]
        faces, roles = [], []
        for row in range(len(rings) if loop else len(rings) - 1):
            a, b = row * n, ((row + 1) % len(rings)) * n
            for j in range(n):
                k = (j + 1) % n
                faces.append((a + j, a + k, b + k, b + j))
                roles.append(face_role(j, row) if face_role else 0)
        if not loop:
            faces.extend((tuple(reversed(range(n))), tuple(range(len(points) - n, len(points)))))
            roles.extend((0, 0))
        return self.mesh(name, points, faces, materials, group, parent, roles)

    def slab(self, name, outline, layers, materials, group=None, parent=None, face_role=None):
        rings = [[(x, y, z) for x, z in (shape or outline)] for y, shape in layers]
        return self.loft(name, rings, materials, group, parent, face_role)

    def hull(self, name, stations, materials, group=None, parent=None, face_role=None):
        """Six intentionally flat surfaces per flank, with an optional cut angle at the ends."""
        rings = []
        side = [(.56, 0), (.82, .055), (1., .24), (.99, .66), (.83, .85), (.58, 1)]
        for x, width, floor, top, rake in stations:
            prof = [(s * width, floor + v * (top - floor)) for s, v in side]
            yz = prof + [(-y, z) for y, z in reversed(prof)]
            rings.append([(x + rake * (z - .29), y, z) for y, z in yz])
        return self.loft(name, rings, materials, group, parent, face_role)

    def cut(self, obj, tool, label):
        tool.hide_set(True)
        tool.hide_render = True
        tool.display_type = "WIRE"
        mod = obj.modifiers.new(label, "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.object = tool

    def facet(self, name, hand, stations, materials, group=None, parent=None, face_role=None):
        """Split each plate into wide ceramic faces and deliberately narrow blade edges."""
        rings = []
        for x, inset, crest, low, ridge, top, rake in stations:
            edge = min(.010, (top - low) * .16)
            section = [(inset, low), (crest - edge, low + edge*.51), (crest, ridge),
                       (crest - edge*.75, top - edge*.37), (inset, top)]
            rings.append([(x + rake*(z - .33), hand*y, z) for y,z in section])
        return self.loft(name, rings, materials, group, parent, face_role)

    def recessed_inlay(self, label, host, side, opening, bed, face, back, front, group=None, parent=None):
        tool = self.slab("Tool_" + label, opening, [(side*back, bed), (side*front, opening)],
                         [self.well], group, parent)
        self.cut(host, tool, label)
        self.slab(label, face, [(side*(back-.0015), face), (side*(back+.0013), face)],
                  [self.blue], group, parent)

    def camera(self, name, point, target, width):
        data = bpy.data.cameras.new(name)
        o = bpy.data.objects.new(name, data)
        self.stage.objects.link(o)
        o.location = point
        o.rotation_euler = (Vector(target) - o.location).to_track_quat("-Z", "Y").to_euler()
        data.type, data.ortho_scale = "ORTHO", width
        return o

    def lamp(self, name, point, target, energy, size, length, tint):
        data = bpy.data.lights.new(name, "AREA")
        o = bpy.data.objects.new(name, data)
        self.stage.objects.link(o)
        o.location = point
        o.rotation_euler = (Vector(target) - o.location).to_track_quat("-Z", "Y").to_euler()
        data.shape, data.energy, data.size, data.size_y, data.color = "RECTANGLE", energy, size, length, tint

    def light_and_frame(self):
        scene = self.scene
        scene.world = bpy.data.worlds.new("Storm Shadow | neutral")
        scene.world.use_nodes = True
        scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.13,.17,.22,1)
        scene.world.node_tree.nodes["Background"].inputs[1].default_value = .29
        self.lamp("Key | long softbox",(1.07,3.1,3.7),(.60,0,.08),315,4.7,2.4,(1,.957,.922))
        self.lamp("Rim | silver shoulders",(.9,-2.2,2.8),(.79,0,.12),330,4.4,1.7,(.81,.90,1))
        self.lamp("Fill | undercut",(.96,2.6,-1.25),(.60,0,.08),56,2.9,2.7,(.81,.92,1))
        self.lamp("Bounce | far side",(.62,-3.1,.85),(.64,0,.16),195,3.8,2.5,(.97,.98,1))
        self.lamp("Front | shroud", (3.0,1.2,1.57),(1.64,0,.27),75,1.6,1.5,(.92,.97,1))
        center = (.69,0,.104)
        scene.camera = self.camera("Review_Hero",(4.7,8.8,3.7),center,4.25)
        self.camera("Review_Side",(.69,8,.104),center,4.25)
        self.camera("Review_Opposite",(.69,-8,.104),center,4.25)
        self.camera("Review_Top",(.69,0,9),center,4.25)
        self.camera("Review_Underside",(.8,-2.1,-6),center,4.25)
        self.camera("Review_Back",(-4.8,.19,.35),(.7,0,.107),1.3)
        self.camera("Review_Front",(6.8,0,.12),(.7,0,.12),1.26)
        self.camera("Review_RearQuarter",(-3.9,-6.9,3.3),center,4.1)
        self.camera("Review_Mag",(1.67,2.1,-.21),(.74,0,-.19),.77)
        self.camera("Review_Sight",(-.75,1.9,1.25),(.09,0,.51),.6)
        self.camera("Review_Charm",(1.16,1.4,.39),(.93,.092,.184),.33)
        self.camera("Review_Muzzle",(3.4,1.8,.67),(2.32,0,.296),.82)
        self.camera("Review_Stock",(-1.84,2.2,.71),(-.74,0,.15),1.41)
        self.camera("Review_Grip",(.46,2.2,-.14),(.025,0,-.066),.64)
        self.camera("Review_Receiver",(.80,3.15,1.23),(.57,0,.28),1.96)
        self.camera("Review_Shroud",(2.46,2.2,.88),(1.60,0,.34),1.38)
        self.camera("Review_Round",(.32,.51,.29),(.007,0,0),.32)
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 24
        scene.cycles.use_denoising = True
        scene.view_settings.view_transform = "AgX"
        scene.render.resolution_x, scene.render.resolution_y = (1500,740)
        scene.render.film_transparent = True
        scene.render.image_settings.color_mode = "RGBA"
        scene.render.fps = 30
        scene.frame_start = 1
        scene.frame_set(1)
        scene["reference"] = "Remaster V2 Vandal v05. Muzzle +X. One unit equals one stud."

    def save(self, version, label):
        self.scene["build_pass"] = label
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type == "VIEW_3D":
                    view = area.spaces.active
                    view.shading.type = "SOLID"
                    view.shading.color_type = "MATERIAL"
                    view.overlay.show_extras = False
                    view.overlay.show_floor = False
                    view.overlay.show_axis_x = False
                    view.overlay.show_axis_y = False
                    view.region_3d.view_perspective = "ORTHO"
                    view.region_3d.view_distance = 5.3
                    view.region_3d.view_location = (.65,0,.115)
                    view.region_3d.view_rotation = self.scene.objects["Review_Hero"].rotation_euler.to_quaternion()
        folder = DEST/version
        folder.mkdir(parents=True, exist_ok=True)
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(folder/f"Vandal_TempestStrike_StormShadow_{version}.blend"),compress=True)


def receiver_and_shroud(w):
    column = w.hull("Receiver_IndigoForging",[
        (-.178,.060,.132,.357,-.12),(-.144,.087,.091,.421,-.08),(-.026,.092,.082,.425,0),
        (.325,.092,.082,.428,0),(.430,.092,.070,.428,0),(.719,.092,.075,.426,0),
        (.893,.092,.095,.428,0),(1.040,.089,.148,.422,.24),
    ],[w.coal,w.well,w.steel],face_role=lambda edge,row: 1 if edge in {0,10,11} else 2 if edge in {1,9} else 0)
    keel = w.hull("Receiver_Keel",[
        (.225,.043,.111,.174,0),(.422,.074,.095,.173,-.12),(.481,.082,.062,.155,-.20),
        (.718,.079,.062,.159,.13),(.844,.065,.104,.176,.18),(.948,.057,.143,.204,.24),
    ],[w.coal,w.well,w.steel],face_role=lambda edge,row: 2 if edge in {1,9} else 1 if edge in {0,10,11} else 0)
    slot = w.loft("Tool_MagazineSeat",[
        [(.597+a*half,b*width,z) for a,b in
         [(.78,-1),(-.78,-1),(-1,-.75),(-1,.75),(-.78,1),(.78,1),(1,.75),(1,-.75)]]
        for z,half,width in [(.018,.199,.076),(.086,.183,.075),(.235,.169,.075)]
    ],[w.well])
    for obj in (column,keel):
        w.cut(obj,slot,"Magazine feed relief")
    fore = w.hull("Shroud_OctagonalForging",[
        (1.039,.087,.154,.424,.24),(1.082,.094,.165,.432,.24),(1.155,.095,.162,.430,.10),
        (1.431,.093,.164,.414,0),(1.581,.085,.182,.401,-.10),
        (1.696,.073,.209,.369,-.21),(1.753,.046,.242,.321,-.28),
    ],[w.coal,w.well,w.steel],face_role=lambda edge,row: 1 if edge in {0,10,11} else 2 if edge in {3,7} else 0)
    w.hull("UpperSpine_ProwBrow",[
        (-.164,.044,.388,.423,-.12),(-.104,.059,.410,.451,0),(.114,.059,.416,.453,0),
        (.238,.060,.421,.469,.18),(.694,.058,.419,.466,.18),
        (.883,.068,.406,.454,.24),(1.075,.055,.395,.435,.24),
    ],[w.coal,w.ceramic,w.silver],face_role=lambda edge,row: 2 if edge in {4,6} else 1 if edge in {3,5,7} else 0)
    w.hull("Shroud_DorsalBlade",[
        (1.065,.055,.404,.435,.24),(1.122,.060,.407,.451,.15),
        (1.438,.049,.401,.435,0),(1.656,.037,.355,.399,-.21),(1.764,.022,.315,.367,-.28),
    ],[w.coal,w.ceramic,w.silver],face_role=lambda edge,row: 2 if edge in {4,6} else 1 if edge in {3,5,7} else 0)
    w.hull("Shroud_SupportSaddle",[
        (1.095,.045,.168,.180,0),(1.175,.064,.1705,.184,0),(1.419,.064,.1705,.179,0),
        (1.469,.054,.149,.185,-.09),(1.501,.042,.132,.176,0),(1.551,.032,.157,.180,0),
    ],[w.rubber])
    for side,label in [(1,"Player"),(-1,"Far")]:
        rear=w.empty("CTRL_PlateRear_"+label,(.32,side*.105,.38),w.body)
        forward=w.empty("CTRL_PlateFore_"+label,(1.39,side*.103,.33),w.body)
        rear["travel_x"],forward["travel_x"]=.032,.030
        w.facet("Rear_SilverPlate_"+label,side,[
            (-.156,.096,.105,.353,.366,.377,-.16),
            (-.091,.096,.111,.320,.397,.429,-.09),
            (.264,.096,.112,.314,.387,.424,0),
            (.718,.096,.109,.314,.382,.408,0),
            (.904,.096,.106,.304,.367,.401,.20),
            (1.021,.094,.103,.315,.339,.384,.24),
        ],[w.ceramic,w.silver,w.steel],parent=rear,
          face_role=lambda edge,row: [2,0,1,2,0][edge])
        w.facet("Fore_SilverPlate_"+label,side,[
            (1.068,.098,.106,.286,.323,.375,.25),
            (1.160,.098,.113,.255,.330,.375,.14),
            (1.425,.097,.112,.264,.318,.365,0),
            (1.594,.089,.105,.277,.307,.343,-.17),
            (1.705,.064,.079,.274,.289,.311,-.25),
        ],[w.ceramic,w.silver,w.steel],parent=forward,
          face_role=lambda edge,row: [2,0,1,2,0][edge])
        lip=[(.014,.251),(.066,.287),(.463,.281),(.553,.296),
             (.835,.283),(.873,.266),(.795,.251),(.505,.258),(.411,.246),(.063,.241)]
        bed=[(.051,.256),(.083,.278),(.460,.274),(.551,.286),(.818,.276),
             (.842,.268),(.788,.260),(.503,.268),(.416,.253),(.086,.249)]
        inset=[(.069,.258),(.096,.275),(.460,.271),(.551,.284),(.806,.274),
               (.823,.269),(.787,.263),(.503,.271),(.417,.256),(.102,.252)]
        w.recessed_inlay("Receiver_Cobalt_"+label,column,side,lip,bed,inset,.075,.124)
        for i in range(3):
            x=1.181+.144*i
            z=.387-.009*i
            opening=[(x-.045,z-.007),(x-.030,z+.012),(x+.052,z+.008),(x+.034,z-.010)]
            inset=[(x+(u-x)*.79,z+(v-z)*.70) for u,v in opening]
            cut=w.slab("Tool_Vent_"+label+str(i),opening,[(side*.048,inset),(side*.124,opening)],[w.well])
            w.cut(fore,cut,"Raked exhaust "+label+" "+str(i+1))
        end=[(1.026,.175),(1.061,.218),(1.137,.224),(1.163,.206),(1.115,.177),(1.073,.160)]
        w.slab("Shroud_RootKey_"+label,end,[(side*.061,end),(side*.091,end)],[w.steel])
    return column,fore


def start(version="v13"):
    workshop = Workshop()
    receiver_and_shroud(workshop)
    workshop.light_and_frame()
    workshop.save(version,"Receiver and fore-end construction")
    return workshop


GRIP_SECTIONS = [
    (.166,-.075,.125,.055), (.10,-.0857,.1275,.056), (.02,-.1331,.1261,.056),
    (-.06,-.1472,.0926,.056), (-.14,-.1614,.0731,.055), (-.22,-.1756,.0553,.056),
    (-.26,-.1826,.0326,.056), (-.29,-.166,.010,.052), (-.305,-.146,-.011,.046),
]
MAG_SECTIONS = [
    (.191,.468,.703,.052), (.135,.468,.710,.052), (.080,.478,.727,.052),
    (.020,.495,.751,.051), (-.040,.518,.777,.051), (-.100,.547,.808,.050),
    (-.160,.577,.843,.050), (-.220,.613,.883,.051), (-.280,.649,.929,.051),
    (-.335,.685,.979,.052), (-.386,.714,.984,.052),
]


def fitted_profile(sections,z):
    for index,(upper,lower) in enumerate(zip(sections,sections[1:])):
        if z>=lower[0] or index==len(sections)-2:
            t=max(-.35,min(1.20,(z-upper[0])/(lower[0]-upper[0])))
            return [a+(b-a)*t for a,b in zip(upper[1:],lower[1:])]
    raise ValueError(z)


def contour(xmin,xmax,depth,chamfer=.28):
    cut=(xmax-xmin)*.5*chamfer
    return [(xmin+cut,depth),(xmax-cut,depth),(xmax,depth*(1-chamfer)),(xmax,-depth*(1-chamfer)),
            (xmax-cut,-depth),(xmin+cut,-depth),(xmin,-depth*(1-chamfer)),(xmin,depth*(1-chamfer))]


def sculpted_skin(w,name,sections,rows,group,parent,mats,rake):
    rings=[]
    for z,shrunk,depth_scale in rows:
        lo,hi,depth=fitted_profile(sections,z)
        middle=(lo+hi)*.5
        rings.append([(x,y,z+rake*(x-middle)) for x,y in
                      contour(lo+shrunk,hi-shrunk,depth*depth_scale)])
    return w.loft(name,rings,mats,group,parent,
                  face_role=lambda edge,row: 1 if edge in {1,3,5,7} and len(mats)>1 else 0)


def bind_leather(w,name,sections,spans,group,parent,lean):
    # Each binding is closed. The broad faces carry different tension and
    # the rollover pinches where the strip crosses the front and back rails.
    for strip,(top,bottom) in enumerate(spans):
        rings=[]
        for beat,lift,crown in [(0,-.001,.0),(.10,.002,.42),(.27,.007,.92),(.52,.006,1.0),
                                (.73,.004,.65),(.90,.005,.42),(1,-.001,.0)]:
            z=top+(bottom-top)*beat
            lo,hi,depth=fitted_profile(sections,z)
            mid=(lo+hi)*.5
            corners=contour(lo-lift*.60,hi+lift*.60,depth+lift,.28)
            ring=[]
            for j,(a,b) in enumerate(corners):
                next_x,next_y=corners[(j+1)%len(corners)]
                divisions=(0,.22,.48,.73) if j in {0,4} else (0,.48)
                for i,t in enumerate(divisions):
                    x,y=a+(next_x-a)*t,b+(next_y-b)*t
                    fold=lean*(x-mid) + (.008 if j<4 else -.007)*math.sin(t*math.pi)*(1 if strip%2 else -.6)
                    lip=.0023*math.sin(i*1.7+j*.85+strip*.62)*crown
                    y+=math.copysign(lip,y)
                    ring.append((x,y,z+fold))
            rings.append(ring)
        w.loft(f"{name}_{strip+1}",rings,[w.leather,w.raw_edge],group,parent,loop=True,
               face_role=lambda edge,row:int(row in {0,5,6} or (row==1 and edge%7==5)))


def build_furniture(w):
    stock=w.stock_group
    w.hull("Stock_ShortMountingNeck",[
        (-.466,.046,.220,.360,-.13),(-.399,.049,.217,.362,.12),
        (-.239,.051,.224,.371,.11),(-.169,.044,.236,.368,-.04)
    ],[w.coal,w.steel],stock,face_role=lambda edge,row:int(edge in {2,3,7,8}))
    cheek=w.hull("Stock_AftCheekHousing",[
        (-1.187,.052,.263,.394,-.21),(-1.114,.067,.208,.414,-.18),
        (-.922,.068,.190,.417,0),(-.756,.064,.196,.416,0),(-.566,.060,.212,.410,0),
        (-.427,.055,.258,.399,-.22),(-.353,.050,.296,.365,-.24)
    ],[w.coal,w.steel,w.ceramic],stock,face_role=lambda edge,row:2 if edge in {3,7} else 1 if edge in {4,6} else 0)
    for side in (1,-1):
        w.facet("Stock_CheekBlade",side,[
            (-1.146,.053,.064,.332,.365,.387,-.18),
            (-1.100,.059,.073,.252,.338,.403,-.18),
            (-.940,.063,.074,.234,.319,.401,0),
            (-.687,.060,.071,.243,.313,.399,0),
            (-.461,.050,.063,.305,.337,.384,-.23),
        ],[w.ceramic,w.silver,w.steel],stock,face_role=lambda edge,row:[2,0,1,2,0][edge])
        inner=[(-1.069,.229),(-1.043,.255),(-.905,.249),(-.803,.264),(-.681,.281),
               (-.707,.265),(-.804,.244),(-.903,.232)]
        floor=[(-1.052,.236),(-1.036,.249),(-.905,.242),(-.803,.255),(-.697,.273),
               (-.718,.264),(-.806,.247),(-.902,.235)]
        enamel=[((x+.875)*.90-.875,(z-.251)*.69+.251) for x,z in floor]
        w.recessed_inlay("Stock_CobaltSeat",cheek,side,inner,floor,enamel,.056,.090,stock)
    strut=[(-1.167,-.157),(-1.084,-.150),(-1.037,-.114),(-.746,.178),
           (-.738,.217),(-.803,.230),(-.843,.173),(-1.146,-.084)]
    level=[(-1.147,-.142),(-1.088,-.138),(-1.052,-.107),(-.773,.175),
           (-.775,.195),(-.809,.207),(-.833,.161),(-1.128,-.086)]
    for side in (1,-1):
        w.slab("Stock_DiagonalWeb",strut,[(side*.013,None),(side*.047,None),(side*.055,level)],
               [w.coal,w.steel],stock,face_role=lambda edge,row:int(row==1 and edge in {1,2,3}))
    heel=[(-1.248,-.140),(-1.204,-.174),(-1.137,-.154),(-1.092,-.110),(-1.108,.173),
          (-1.088,.316),(-1.117,.373),(-1.168,.421),(-1.224,.402),(-1.252,.353)]
    heel_face=[(-1.229,-.134),(-1.199,-.159),(-1.146,-.144),(-1.111,-.108),(-1.145,.173),
               (-1.122,.303),(-1.144,.363),(-1.174,.405),(-1.212,.386),(-1.234,.344)]
    for side in (1,-1):
        w.slab("Stock_HeelShell",heel,[(side*.006,None),(side*.058,None),(side*.072,heel_face)],
               [w.coal,w.steel,w.ceramic],stock,face_role=lambda edge,row:2 if row==1 and edge in {3,4,5} else int(row==1))
    pad=[(-1.224,-.146),(-1.212,-.158),(-1.193,-.151),(-1.202,.330),
         (-1.220,.372),(-1.239,.365),(-1.242,.319)]
    w.slab("Stock_ShoulderContact",pad,[(-.078,None),(.078,None)],[w.rubber],stock)

    grip=w.grip
    sculpted_skin(w,"Grip_FittedTang",GRIP_SECTIONS,[
        (.163,.013,.91),(.112,.010,1),(.017,.005,1),(-.073,.002,1),
        (-.145,.002,1),(-.228,.002,1),(-.276,.004,1),(-.303,.008,.90)
    ],grip,w.body,[w.coal,w.steel],.028)
    bind_leather(w,"Grip_CompressedLeather",GRIP_SECTIONS,
                 [(.010,-.051),(-.048,-.111),(-.107,-.168),(-.163,-.224),(-.216,-.278)],
                 grip,w.body,.265)
    for side in (1,-1):
        border=[(.113,.099),(.097,.024),(.067,-.092),(.047,-.194),(.025,-.263),
                (-.008,-.290),(-.044,-.285),(-.012,-.255),(.011,-.206),(.041,-.087),(.061,.013)]
        surface=[(x-.006,z) for x,z in border]
        w.slab("Grip_CeramicForeRail",border,[(side*.043,None),(side*.064,surface)],
               [w.ceramic,w.steel],grip,face_role=lambda edge,row:int(edge in {1,2,3,8}))
    sculpted_skin(w,"Grip_HeelKey",GRIP_SECTIONS,[(-.270,-.002,1.08),(-.281,-.009,1.08),
        (-.294,-.006,1.08),(-.308,.011,.93)],grip,w.body,[w.coal,w.silver],.025)
    guard=[(.107,.054),(.126,.024),(.170,.014),(.349,.015),(.395,.036),(.422,.132),(.388,.156),(.116,.150)]
    hollow=[(.153,.067),(.167,.056),(.185,.047),(.335,.050),(.366,.069),(.383,.119),(.369,.135),(.150,.131)]
    w.loft("TriggerGuard_RakedLoop",[
        [(x,y,z) for x,z in shape] for y,shape in
        [(-.033,guard),(.033,guard),(.033,hollow),(-.033,hollow)]
    ],[w.coal,w.steel],grip,loop=True,face_role=lambda edge,row:int(row==1 and edge in {0,1,2,3,4}))
    trigger=[(.193,.158),(.234,.163),(.235,.121),(.216,.083),(.201,.076),(.203,.115)]
    w.slab("Trigger_CutLever",trigger,[(-.010,None),(.010,None)],[w.steel],grip)

    mag=w.magazine
    shell=sculpted_skin(w,"Mag_CurvedShell",MAG_SECTIONS,[
        (.184,.012,.88),(.120,.003,.98),(.052,.001,1),(-.038,0,1),(-.128,0,1),
        (-.231,.001,1),(-.316,.003,1),(-.380,.007,.93)
    ],mag,w.mag,[w.coal,w.steel],.084)
    sculpted_skin(w,"Mag_FeedCrown",MAG_SECTIONS,[(.227,.016,.85),(.211,.005,.97),
          (.156,.004,1),(.108,.002,1)],mag,w.mag,[w.coal,w.steel],.028)
    for side in (1,-1):
        window=[(.548,.052),(.590,.100),(.695,.108),(.728,.063),(.757,-.029),(.741,-.077),(.697,-.086),(.603,-.047)]
        floor=[(.561,.052),(.600,.092),(.686,.098),(.718,.058),(.744,-.026),(.731,-.068),(.696,-.076),(.612,-.040)]
        enamel=[((x-.658)*.90+.658,(z-.009)*.88+.009) for x,z in floor]
        w.recessed_inlay("Mag_CobaltInsert",shell,side,window,floor,enamel,.043,.073,mag,w.mag)
    bind_leather(w,"Mag_CompressedLeather",MAG_SECTIONS,
                 [(-.089,-.153),(-.15,-.218),(-.214,-.278),(-.270,-.335)],
                 mag,w.mag,.24)
    sculpted_skin(w,"Mag_CutHeel",MAG_SECTIONS,[
        (-.334,.00,1.05),(-.351,-.006,1.16),(-.375,-.008,1.22),(-.392,.004,1.09)
    ],mag,w.mag,[w.ceramic,w.steel],.083)


def furniture(version="v14"):
    workshop=Workshop.resume()
    build_furniture(workshop)
    workshop.save(version,"Stock, grip and magazine construction")
    return workshop


if __name__ == "__main__":
    start()
