"""Build and export the approved Molly prep and the Gauntlet rework art pack.

Run Blender in background with --factory-startup --python this file.
Use -- --export to export the saved pack with the same Mod metadata as the game.
"""

import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from mod_rework_kit import Parts, angles, material, prepare_molly

ROOT = HERE.parents[1]
OUT = ROOT / "art-source/abilities/Rework"
MOLLY_BASE = ROOT / "art-source/abilities/Molly/Molly_Rework_v01.blend"
PREVIEWS = ROOT / "vault/02 Art/References/mods/rework"
PACK = OUT / "Gauntlet_Mod_Rework.blend"
MODULES = ("Molly", "Frost", "Recon", "ReconDart", "Stim", "Recall", "ReworkVFX")


def model_scene(name, kind):
    scene = bpy.data.scenes.new(name)
    parts = Parts(name)
    scene.collection.children.link(parts.collection)
    parts.collection["kind"] = kind
    return scene, parts


def molly():
    with bpy.data.libraries.load(str(MOLLY_BASE), link=False) as (available, picked):
        assert "Molly" in available.collections
        picked.collections = ["Molly"]
    source = picked.collections[0]
    source.name = "Approved Molly Reference"
    scene, parts = model_scene("Molly", "thrown")
    previous = list(source.objects)
    prepare_molly(parts, previous)
    for obj in previous:
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(source)
    for obj in parts.collection.objects:
        obj.name = obj.name.split(".")[0]
    return scene


def palette():
    return {
        "shell": material("Graphite", "343840"),
        "trim": material("Slate", "525B69"),
        "dark": material("Recess", "232730"),
        "steel": material("Steel", "929AA5", metal=.36),
        "chalk": material("Ceramic", "D5DADF"),
        "paint": material("Saffron", "D99B32"),
        "orange": material("Hot copper", "DF712B"),
        "ice": material("Cold glass", "80BDDB"),
        "cyan": material("Cyan signal", "45BDDB", emission=.30),
        "amber": material("Amber coil", "FFD03C", emission=.32),
        "teal": material("Phase glass", "65D3BE", emission=.27),
    }


def frost(m):
    _, p = model_scene("Frost", "thrown")
    p.prism("Body", [
        (-.272,0,0,.079,.076),(-.248,0,0,.109,.095),(-.190,-.003,0,.127,.111),
        (.075,-.005,0,.109,.103),(.128,-.014,0,.090,.091),(.165,-.014,0,.069,.071)
    ], m["shell"], cut=.31)
    p.prism("Band", [
        (.083,-.007,0,.110,.105),(.095,-.007,0,.116,.109),(.119,-.013,0,.107,.101),
        (.141,-.014,0,.091,.087)
    ], m["trim"])
    p.prism("FuseHead", [
        (.137,-.018,0,.070,.068),(.161,-.020,0,.059,.060),(.189,-.023,0,.060,.065),
        (.200,-.023,0,.086,.074),(.244,-.023,0,.086,.074),(.263,-.030,0,.070,.060)
    ], m["dark"])
    p.prism("TopPlate", [
        (.258,-.039,0,.050,.048),(.273,-.043,0,.045,.045),(.279,-.043,0,.035,.037)
    ], m["chalk"])
    for sign, side in [(-1, "Front"), (1, "Back")]:
        # Surface of the long face tapers in about .008 studs from heel to shoulder.
        def panel(name, outline, depth, mat):
            def face(z):
                return .111 - .008 * (z + .190) / .265
            p.loft(name, [[(x, sign*(face(z)+depth+d), z) for x,z in outline]
                         for d in (-.002,.004)], mat)
        panel("Shoulder_"+side, [
            (-.060,.086),(.045,.081),(.072,.057),(.059,.026),
            (-.035,-.022),(-.082,.012),(-.076,.065)
        ], .005, m["chalk"])
        panel("Heel_"+side, [
            (-.070,-.154),(.070,-.154),(.083,-.178),(.070,-.204),(-.071,-.204),
            (-.085,-.182)
        ], .005, m["chalk"])
        for i in range(3):
            y = -.039 - i*.039
            strip = [(-.060,y-.018),(.064,y-.004),(.079,y+.011),(.059,y+.018),(-.064,y+.004)]
            panel(f"Vent{side}{i+1}", strip, .004, m["ice"])
            lip = [(x,z-.012) for x,z in strip]
            panel(f"VentLip{side}{i+1}", lip, .009, m["chalk"])
    pivot = (.059,0,.224)
    p.silhouette("Lever", [
        (.041,.258),(.087,.256),(.158,.133),(.161,.037),
        (.144,.029),(.127,.052),(.113,.131),(.048,.209)
    ], -.050,.050,m["shell"],pivot=pivot)
    p.beam("Pin",(.059,-.070,.224),(.059,-.047,.224),
           [(0,.015,.015),(.22,.020,.020),(.82,.020,.020),(1,.014,.014)],m["steel"],
           pivot=(.059,-.052,.224))
    p.beam("Fuse_Energy",(-.029,-.068,.162),(-.029,-.077,.162),
           [(0,.010,.029),(1,.008,.025)],m["cyan"])
    p.point("LeverPivot", pivot)
    p.point("PinPivot", (.059,-.052,.224))
    p.point("PinPull", (.059,-.160,.224))
    p.point("Handle", (0,0,0))
    p.point("Fuse", (-.029,-.077,.162))


def recon(m):
    _, p = model_scene("Recon", "handheld")
    p.prism("Grip", [
        (-.173,-.038,0,.064,.048),(-.152,-.024,0,.080,.059),
        (-.061,-.010,0,.063,.055),(.079,.012,0,.069,.052),(.124,.026,0,.074,.056)
    ], m["dark"], cut=.34)
    riser = [(-.139,-.217),(-.137,-.147),(-.067,-.128),(-.018,-.129),
             (.051,-.093),(.069,.032),(.058,.107),(-.044,.130),
             (-.126,.177),(-.107,.264),(.036,.270),(.126,.220),
             (.170,.103),(.152,-.137),(.063,-.236),(-.043,-.258)]
    # The recessed grip and nocking space are on the rear edge of the riser.
    p.silhouette("Riser", riser, -.075,.075,m["shell"])
    for sign, side in [(-1,"Right"),(1,"Left")]:
        lo, hi = sorted((sign*.069,sign*.090))
        p.silhouette("UpperPlate_"+side, [(-.088,.179),(-.069,.250),(.025,.252),
            (.108,.206),(.141,.119),(.112,.093),(.074,.135)],lo,hi,m["chalk"])
        p.silhouette("LowerPlate_"+side, [(-.117,-.186),(-.066,-.163),(.061,-.149),
            (.104,-.113),(.133,-.131),(.050,-.219),(-.047,-.233)],lo,hi,m["chalk"])
    top_joint=(.075,0,.219)
    low_joint=(.064,0,-.211)
    top_tip=(-.177,-.084,.585)
    low_tip=(-.176,-.084,-.558)
    for is_top, joint, tip in [(True,top_joint,top_tip),(False,low_joint,low_tip)]:
        sign=1 if is_top else -1
        name="Upper" if is_top else "Lower"
        outline=[(.112,.210),(.179,.258),(.162,.350),(.077,.429),(-.028,.493),
                 (-.149,.533),(-.170,.593),(-.222,.570),(-.207,.511),
                 (-.120,.462),(-.047,.409),(.025,.347),(.057,.276),(.038,.219)]
        p.silhouette(name+"Limb",[(x,z*sign) for x,z in outline],-.047,.047,m["trim"],pivot=joint)
        p.silhouette(name+"LimbPlate",[(x,z*sign) for x,z in
            [(.149,.275),(.133,.334),(.065,.396),(-.092,.488),
             (-.152,.502),(-.134,.460),(.016,.349),(.069,.272)]],
            -.053,-.045,m["chalk"],pivot=joint)
        p.beam(name+"StringTip", (tip[0],-.092,tip[2]), (tip[0],.044,tip[2]),
               [(0,.013,.015),(.25,.018,.020),(.75,.018,.020),(1,.013,.015)],m["dark"])
        p.point("Limb"+name+"Pivot",joint)
        p.point("String"+name,tip)

    nock=(-.178,-.113,.089)
    for which,tip in [("Upper",top_tip),("Lower",low_tip)]:
        p.beam("String"+which+"Segment",nock,tip,[(0,.004,.004),(1,.004,.004)],m["steel"],pivot=nock)
    p.silhouette("Charge_Energy", [(.094,.103),(.125,.119),(.104,.183),(.077,.202),
                 (.066,.171)],-.098,-.091,m["cyan"])
    for i in range(2):
        z=-.100+i*.049
        p.beam(f"Bounce{i+1}_Energy",(.087,-.076,z),(.087,-.085,z),
               [(0,.014,.014),(1,.011,.011)],m["cyan"],cut=.46)
    p.prism("BoltRest",[(.055,.113,-.088,.027,.024),(.070,.108,-.100,.028,.031),
                        (.075,.107,-.101,.023,.026)],m["trim"])
    p.point("Handle",(0,0,0))
    p.point("LeftGrip",(0,0,0))
    p.point("StringNock",nock)
    p.point("StringNockDrawn",(-.450,-.113,.089))
    p.point("BoltTipHeld",(.662,-.113,.089))
    p.point("Muzzle",(.197,-.113,.089))

    _, dart=model_scene("ReconDart","thrown")
    dart.beam("Body",(-.808,0,0),(-.110,0,0),
              [(0,.011,.011),(.05,.016,.016),(.89,.017,.017),(1,.028,.024)],m["dark"])
    dart.beam("Tip",(-.129,0,0),(0,0,0),
              [(0,.025,.023),(.25,.044,.038),(.75,.036,.030),(1,.013,.012)],m["chalk"])
    for i,a in enumerate(angles(3)):
        rotation=Matrix.Rotation(a,4,"X")
        profile=[(-.840,.011),(-.823,.058),(-.747,.048),(-.695,.021),(-.700,.013)]
        dart.loft(f"Fin{i+1}",[[rotation@Vector((x,y,z)) for x,z in profile]
                             for y in (-.006,.006)],m["trim"])
    dart.silhouette("Light_Energy",[(-.117,-.008),(-.094,-.024),(-.025,-.015),
                    (-.015,0),(-.043,.022),(-.092,.024)],
                    -.038,-.025,m["cyan"])
    dart.point("Handle",(0,0,0))
    dart.point("Trail",(-.836,0,0))


def stim(m):
    _, p=model_scene("Stim","placed")
    p.radial("Base",[(0,0,0,.391),(.037,0,0,.454),(.095,0,0,.472),
                    (.232,0,0,.329),(.281,0,0,.276)],m["shell"],sides=6)
    p.radial("Shoulder",[(.252,0,0,.292),(.294,0,0,.302),(.344,0,0,.245)],
             m["trim"],sides=6)
    for i,a in enumerate(angles(3, math.pi/6)):
        axis=Vector((math.cos(a),math.sin(a),0))
        root=axis*.208+Vector((0,0,.201))
        p.beam(f"Foot{i+1}",root,axis*.558+Vector((0,0,.045)),
               [(0,.079,.039),(.25,.098,.063),(.86,.102,.060),(1,.067,.034)],m["dark"])
        p.beam(f"FootMark{i+1}",root+Vector((0,0,.045)),axis*.424+Vector((0,0,.162)),
               [(0,.021,.012),(.21,.039,.017),(.78,.037,.017),(1,.026,.010)],m["paint"])
    p.radial("Mast",[(.302,0,0,.133),(.361,0,0,.153),(.418,0,0,.114),
                     (.737,0,0,.080),(.773,0,0,.055)],m["dark"])
    p.ring("Coil_Yellow",[(.081,.563),(.141,.574),(.154,.614),(.142,.660),(.070,.669),(.068,.642)],
           m["amber"],sides=8,pivot=(0,0,.612))
    p.radial("Crown",[(.654,0,0,.127),(.682,0,0,.163),(.736,0,0,.149),
                      (.780,0,0,.099)],m["trim"])
    p.radial("Light_Energy",[(.751,0,0,.072),(.795,0,0,.068),(.817,0,0,.047)],m["cyan"])
    p.point("Floor",(0,0,0))
    p.point("Top",(0,0,.817))
    p.point("CoilPivot",(0,0,.612))


def recall(m):
    _, p=model_scene("Recall","placed")
    p.radial("Base",[(0,0,0,.270),(.042,0,0,.325),(.123,0,0,.337),
                    (.236,0,0,.262),(.290,0,0,.203)],m["shell"],sides=6)
    for i,a in enumerate(angles(3,0)):
        axis=Vector((math.cos(a),math.sin(a),0))
        start=axis*.190+Vector((0,0,.264))
        p.beam(f"Leg{i+1}",start,axis*.493+Vector((0,0,.066)),
               [(0,.071,.051),(.20,.103,.071),(.83,.112,.076),(1,.066,.047)],m["trim"])
        p.beam(f"LegInset{i+1}",start+Vector((0,0,.050)),axis*.423+Vector((0,0,.158)),
               [(0,.030,.009),(.24,.048,.015),(.82,.044,.015),(1,.027,.010)],m["chalk"])
    p.radial("CoreSeat",[(.232,0,0,.167),(.303,0,0,.182),(.354,0,0,.130),
                        (.412,0,0,.115)],m["dark"],sides=6)
    p.radial("Core",[(.355,0,0,.089),(.426,0,0,.105),(.602,0,0,.085),
                     (.719,0,0,.040),(.742,0,0,.022)],m["teal"],sides=6,pivot=(0,0,.54))
    # Cool phase accents remain fixed when per-team status lighting is applied.
    p.ring("PhaseRing",[(.113,.521),(.184,.535),(.204,.573),(.182,.615),
                       (.137,.608),(.109,.580)],m["trim"],sides=8,pivot=(0,0,.565))
    p.ring("PhaseInset",[(.146,.609),(.176,.615),(.180,.621),(.142,.625)],
           m["teal"],sides=8,pivot=(0,0,.565))
    for i,a in enumerate(angles(3)):
        axis=Vector((math.cos(a),math.sin(a),0))
        p.beam(f"RingSupport{i+1}",axis*.138+Vector((0,0,.323)),axis*.162+Vector((0,0,.554)),
               [(0,.036,.022),(.24,.031,.019),(.83,.023,.015),(1,.030,.019)],m["shell"])
    p.beam("Light_Energy",(.265,0,.204),(.284,0,.210),
           [(0,.035,.040),(1,.026,.034)],m["cyan"])
    p.point("Floor",(0,0,0))
    p.point("CorePivot",(0,0,.54))
    p.point("PhasePivot",(0,0,.565))
    p.point("Top",(0,0,.742))


def build():
    from mod_rework_fx import visual_effects
    from mod_rework_review import reviews
    original=bpy.context.scene
    hero=molly()
    m=palette()
    frost(m)
    recon(m)
    stim(m)
    recall(m)
    _, fx=model_scene("ReworkVFX","vfx")
    visual_effects(fx)
    reviews(OUT, PREVIEWS)
    bpy.context.window.scene=hero
    bpy.data.scenes.remove(original)
    from mod_rework_review import frame_viewport
    frame_viewport()
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(PACK),compress=True,relative_remap=False)


def export():
    from export_mods import export_collection
    bpy.ops.wm.open_mainfile(filepath=str(PACK))
    directory=OUT / "Exports"
    directory.mkdir(parents=True,exist_ok=True)
    for name in MODULES:
        bpy.context.window.scene=bpy.data.scenes[name]
        print(export_collection(name,str(directory)),flush=True)


def render(selected):
    bpy.ops.wm.open_mainfile(filepath=str(PACK))
    (OUT/"Textures").mkdir(parents=True,exist_ok=True)
    for name in selected or ("Molly Moving Parts","Prop Review","VFX Review","Dash Edge Mask","Updraft Edge Mask"):
        scene=bpy.data.scenes[name]
        scene.render.threads_mode="FIXED"
        scene.render.threads=10
        bpy.ops.render.render(scene=name,write_still=True)


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Run the art pack builder with Blender --background.")
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--export" in args:
        export()
    elif "--render" in args:
        render(args[args.index("--render")+1:])
    else:
        build()
