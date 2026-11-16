"""Review scenes for the rework pack. All meshes are linked to the editable props."""

import math

import bpy
from mathutils import Matrix, Vector

from mod_rework_fx import sprites
from mod_rework_kit import material


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def render_scene(name, size, destination, *, dark=False):
    scene = bpy.data.scenes.new(name)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(destination)
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new(name + " World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (.46,.55,.67,1) if dark else (.64,.69,.76,1)
    bg.inputs["Strength"].default_value = .32 if dark else .45
    scene.world = world
    return scene


def camera(scene, position, look, width):
    data = bpy.data.cameras.new(scene.name + " Camera")
    data.type = "ORTHO"
    data.ortho_scale = width
    obj = bpy.data.objects.new(data.name, data)
    scene.collection.objects.link(obj)
    obj.location = position
    aim(obj, look)
    scene.camera = obj
    return obj


def panel(scene, name, pos, amount, size, tint):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = amount
    data.size = size
    data.color = tint
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = pos
    aim(obj, (0,0,0))


def lighting(scene):
    panel(scene,"Soft key",(-2.15,-2.2,3.65),296,3.6,(1.,.94,.88))
    panel(scene,"Cool fill",(2.88,-1.62,2.48),192,3.3,(.84,.92,1.))
    panel(scene,"Rim",(.57,1.97,2.93),190,2.6,(1.,.98,.91))


def floor(scene, color, z):
    data = bpy.data.meshes.new(scene.name + " Sweep")
    data.from_pydata([(-70,-70,z),(70,-70,z),(70,70,z),(-70,70,z)],[],[(0,1,2,3)])
    data.materials.append(material(scene.name + " Sweep",color))
    obj = bpy.data.objects.new(data.name,data)
    scene.collection.objects.link(obj)


def clone(scene, original, transform):
    copy=original.copy()
    scene.collection.objects.link(copy)
    copy.matrix_world=transform @ original.matrix_basis
    return copy


def position(at, angle=0, scale=1):
    return Matrix.Translation(at) @ Matrix.Rotation(math.radians(angle),4,"Z") @ Matrix.Scale(scale,4)


def prop(scene, name, transform):
    return {o.name.removeprefix(name+"_"):clone(scene,o,transform)
            for o in bpy.data.collections[name].objects if o.type=="MESH"}


def label(scene, text, pos, size, ink, orientation):
    data=bpy.data.curves.new(text,"FONT")
    data.body=text
    data.size=size
    data.align_x="CENTER"
    data.align_y="CENTER"
    data.space_character=1.16
    data.materials.append(ink)
    obj=bpy.data.objects.new(text,data)
    scene.collection.objects.link(obj)
    obj.location=pos
    obj.rotation_euler=orientation


def molly_review(path):
    scene=render_scene("Molly Moving Parts",(1700,800),path)
    cam=camera(scene,(.12,-3.85,1.85),(0,0,.255),2.16)
    lighting(scene)
    floor(scene,"BBB9B3",-.002)
    ink=material("Review Ink","272C36")
    molly=bpy.data.collections["Molly"]
    moves={o.name.removeprefix("Molly_"):o.location for o in molly.objects if o.type=="EMPTY"}
    for label_text,x,state in [("READY",-.69,0),("PIN PULL",0,1),("LATCH OPEN",.69,2)]:
        transform=position((x,0,.250))
        objs=prop(scene,"Molly",transform)
        if state:
            offset=moves["PinPull"]-moves["PinPivot"]
            objs["Pin"].location += offset
            objs["PrimePad"].location += moves["PrimePadPressed"]-moves["PrimePadPivot"]
        if state==2:
            objs["Lever"].rotation_euler.rotate_axis("Y",math.radians(-43))
        label(scene,label_text,(x,-.57,.024),.045,ink,cam.rotation_euler)


def prop_review(path):
    scene=render_scene("Prop Review",(1850,880),path)
    cam=camera(scene,(.20,-5.7,2.49),(0,.05,.405),4.71)
    lighting(scene)
    floor(scene,"B6B8B9",-.002)
    ink=material("Props Ink","282E38")
    items=[("Molly",-1.70,.296,-9,1.18),("Frost",-.91,.326,-10,1.19),
           ("Recon",-.11,.614,-22,1.),("Stim",.947,0,-8,.79),("Recall",1.75,0,-8,.88)]
    for name,x,z,a,scale in items:
        prop(scene,name,position((x,0,z),a,scale))
        label(scene,name.upper(),(x,-.72,.024),.067,ink,cam.rotation_euler)
    # Match the nocked prop origin to the authored tip locator.
    bow=bpy.data.objects["Recon_BoltTipHeld"]
    bolt_transform=position((-.11,0,.614),-22) @ Matrix.Translation(bow.location)
    prop(scene,"ReconDart",bolt_transform)


def fx_review(path):
    scene=render_scene("VFX Review",(1770,1020),path,dark=True)
    camera(scene,(0,0,10),(0,0,0),9.9)
    lighting(scene)
    floor(scene,"242C3A",-2)
    ink=material("VFX headings","B7CCD7",emission=.22)
    names={obj.name.removeprefix("ReworkVFX_"):obj for obj in bpy.data.collections["ReworkVFX"].objects}
    views=[
        ("WIND",(-3.68,1.5),[
            ("WindSwipe_Energy",(-.10,.12,0),1.65,0,13),
            ("GhostSkim_Energy",(.38,-.32,0),1.18,0,13)]),
        ("CRASH DOWN",(-1.23,1.43),[
            ("CrashPressureRing_Energy",(0,.04,0),.70,53,0),
            ("CrashDustPetal_Energy",(-.38,.09,.28),.92,90,19),
            ("CrashChip",(.26,.20,.29),.75,42,-27),("CrashChip",(.44,-.12,.26),.62,58,29)]),
        ("MOLLY / FIREWALL",(1.24,1.45),[
            ("FlameWallSegment",(.25,-.50,0),.92,-76,0),
            ("FlameWallCrest_Energy",(.25,-.50,0),.92,-76,0),
            ("FlameOuter_Energy",(-.57,-.46,.05),.83,-76,-13),
            ("FlameCore_Energy",(-.57,-.46,.05),.83,-76,-13),
            ("Ember_Energy",(-.83,.32,.19),.73,54,0)]),
        ("FROST / FREEZE",(3.70,1.46),[
            ("FrostWallPlate",(.28,-.50,0),.92,-73,0),
            ("FreezeShell",(-.53,-.43,.07),.89,-73,0),
            ("FrostChip",(-.89,-.25,.21),.73,-65,36),
            ("FrostBurstRim_Energy",(-.02,-.41,0),.68,54,0)]),
        ("RECON SCAN",(-3.68,-1.03),[
            ("ReconEquator_Energy",(0,0,0),.76,58,11),
            ("ReconUpper_Energy",(0,0,0),.76,58,11),
            ("ReconLower_Energy",(0,0,0),.76,58,11)]),
        ("HEAL",(-1.23,-1.04),[
            ("HealZonePulse_Energy",(0,-.28,0),.75,48,0),
            ("HealRibbon_Energy",(0,.30,.05),1.13,0,15),
            ("HealMote_Energy",(-.28,.39,.08),.92,61,0),
            ("HealMote_Energy",(.45,.41,.11),.76,61,0)]),
        ("BARRIER",(1.24,-1.04),[
            ("BarrierHexTile_Energy",(0,.31,.01),.85,0,0),
            ("BarrierHexTile_Energy",(-.37,-.30,0),.85,0,0),
            ("BarrierHexTile_Energy",(.37,-.30,0),.85,0,0)]),
        ("RECALL",(3.70,-1.03),[
            ("RecallPhaseRim_Energy",(0,-.19,0),.73,51,0),
            ("RecallPhaseStreak_Energy",(0,.18,.10),1.22,0,24)]),
    ]
    for title,(x,y),pieces in views:
        for name,(dx,dy,z),scale,tilt,turn in pieces:
            transform=position((x+dx,y+dy,z),turn,scale) @ Matrix.Rotation(math.radians(tilt),4,"X")
            clone(scene,names[name],transform)
        label(scene,title,(x,y-.955,.35),.165,ink,(0,0,0))


def reviews(out, previews):
    molly_review(previews/"Molly Moving Parts.png")
    prop_review(previews/"Ability Props v01.png")
    fx_review(previews/"Ability VFX v01.png")
    sprites(out/"Textures")


def frame_viewport():
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                space=area.spaces.active
                space.shading.type="SOLID"
                space.shading.color_type="MATERIAL"
                space.overlay.show_overlays=False
                space.clip_start=.001
                space.region_3d.view_perspective="ORTHO"
                space.region_3d.view_location=(0,0,0)
                space.region_3d.view_distance=1.17
                space.region_3d.view_rotation=Vector((-.58,1.80,-.72)).to_track_quat("-Z","Y")
