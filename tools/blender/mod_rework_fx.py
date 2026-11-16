"""Reusable mesh effects with defined pivots and native Blender sprite sources."""

import math

import bpy
from mathutils import Vector

from mod_rework_kit import Parts, material


def ribbon(parts, name, mat, path, *, thickness=.014):
    """Extruded XY ribbon with editorially shaped tips and a fixed center pivot."""
    stations = [Vector((x,y,0)) for x,y,_ in path]
    left, right = [], []
    for index, point in enumerate(stations):
        tangent = stations[min(index+1,len(stations)-1)]-stations[max(0,index-1)]
        perpendicular = Vector((-tangent.y,tangent.x,0)).normalized()
        half_width = path[index][2]/2
        left.append(point-perpendicular*half_width)
        right.append(point+perpendicular*half_width)
    outline=left+list(reversed(right))
    return parts.loft(name,[[p+Vector((0,0,z)) for p in outline]
                            for z in (-thickness/2,thickness/2)],mat)


def wave_band(p,name,mat,latitude,width):
    """Thin 3D sensing wave. Band vertices follow the unit sphere."""
    outer=[]
    for t,r in [(latitude-width/2,.986),(latitude-width/2,1.0),
                (latitude+width/2,1.0),(latitude+width/2,.986)]:
        outer.append((math.cos(t)*r,math.sin(t)*r))
    return p.ring(name,outer,mat,sides=32)


def visual_effects(p):
    wind=material("Wind | chalk blue","C2EAF5",emission=.35,alpha=.69)
    dust=material("Crash | pale dust","F1BB7C",emission=.12,alpha=.50)
    rock=material("Crash | rock","857269")
    heat=material("Molly | hot edge","F97027",emission=.68)
    hot=material("Molly | warm core","FFBE4B",emission=.56)
    ice=material("Frost | ice blue","70B9D6",alpha=.76)
    ice_edge=material("Frost | inner white","CDEBFF",emission=.20,alpha=.84)
    scan=material("Recon | pulse edge","77DEFF",emission=.7,alpha=.74)
    heal=material("Heal | sea mint","8AF4C2",emission=.38,alpha=.76)
    phase=material("Recall | cool phase","7FE4DA",emission=.40,alpha=.74)
    shield=material("Barrier | pale honey","FFD494",emission=.24,alpha=.58)

    ribbon(p,"WindSwipe_Energy",wind,[(-.52,-.04,.016),(-.28,-.08,.112),
        (-.04,-.073,.142),(.22,-.02,.09),(.46,.10,.026),(.57,.18,.006)])
    ribbon(p,"GhostSkim_Energy",wind,[(-.47,0,.01),(-.24,-.09,.030),(0,-.107,.05),
        (.23,-.054,.036),(.47,.099,.006)])
    p.ring("CrashPressureRing_Energy",[(.67,.016),(.78,.06),(.91,.03),(1,0),
           (.86,-.014),(.72,-.003)],dust,sides=22)
    p.silhouette("CrashDustPetal_Energy",[(-.51,0),(-.34,.15),(-.10,.32),(.18,.27),
        (.32,.14),(.48,.089),(.27,.044),(-.28,.012)],-.026,.026,dust)
    p.loft("CrashChip",[[(-.19,-.09,0),(.117,-.13,0),(.24,.02,.031),(.12,.137,.027),(-.14,.10,.004)],
            [(-.101,-.063,.094),(.082,-.057,.166),(.125,.00,.104),(.037,.074,.099),
             (-.11,.057,.11)]],rock)

    tongue=[(-.35,0),(-.39,.241),(-.217,.46),(-.184,.706),(-.065,.582),
            (-.014,.790),(-.135,1.019),(.074,.902),(.217,.674),(.208,.458),
            (.309,.567),(.383,.351),(.34,.106),(.23,0)]
    p.silhouette("FlameOuter_Energy",tongue,-.029,.029,heat)
    p.silhouette("FlameCore_Energy",[(-.18,0),(-.173,.23),(-.032,.466),(.014,.706),
        (.137,.514),(.107,.361),(.189,.269),(.166,0)],-.047,-.030,hot)
    p.silhouette("FlameWallSegment",[
        (-.50,0),(-.50,.66),(-.36,.90),(-.39,1.14),(-.14,.96),(-.065,.741),
        (.08,.964),(.076,1.206),(.26,1.035),(.32,.782),
        (.44,.961),(.51,.793),(.51,0)
    ],-.075,.075,heat)
    p.silhouette("FlameWallCrest_Energy",[
        (-.49,.55),(-.48,.69),(-.33,.94),(-.38,1.13),(-.16,.97),(-.079,.787),
        (.094,.995),(.08,1.202),(.253,1.026),(.323,.793),(.437,.948),(.487,.795),
        (.341,.692),(.236,.775),(.153,.909),(.085,.68),(-.082,.65),(-.28,.85),
        (-.32,.60)
    ],-.085,-.066,hot)
    p.radial("Ember_Energy",[(0,0,0,.034),(.076,.016,0,.062),(.196,.056,0,.022)],
             hot,sides=5)

    p.radial("FrostChip",[(0,0,0,.095),(.08,0,0,.142),(.19,.044,.028,.097),
                        (.40,.111,.042,.027)],ice_edge,sides=5)
    p.loft("FrostWallPlate",[
        [(-.43,-.08,0),(.41,-.13,0),(.51,.014,0),(.33,.165,0),(-.37,.12,0),(-.51,.033,0)],
        [(-.36,-.11,.78),(.40,-.11,.88),(.44,.014,.75),(.29,.13,.85),(-.32,.09,.97),(-.40,.02,.87)],
        [(-.28,-.064,1.15),(.19,-.053,1.02),(.26,.007,1.04),(.16,.096,1.07),
         (-.19,.073,1.25),(-.312,.022,1.24)]
    ],ice)
    p.ring("FrostBurstRim_Energy",[(.67,0),(.80,.031),(.92,.038),(1,.015),
        (.91,.003),(.79,-.010)],ice_edge,sides=16)
    p.radial("FreezeShell",[(0,0,0,.38),(.075,0,0,.55),(.31,.018,0,.60),
        (.79,0,0,.47),(.99,0,0,.24),(1.06,0,0,.13)],ice,sides=8)
    p.silhouette("FreezeCrack_Energy",[(.047,1.0),(.021,.68),(-.053,.564),(-.010,.424),
        (-.08,.290),(-.050,.084),(-.085,.28),(-.047,.447),(-.082,.586),(-.006,.708)],
        -.008,.008,ice_edge)

    for name,level,width in [("ReconEquator_Energy",0,.063),
                             ("ReconUpper_Energy",.53,.033),("ReconLower_Energy",-.53,.033),
                             ("ReconSpike_Energy",.22,.114)]:
        wave_band(p,name,scan,level,width)
    ribbon(p,"HealRibbon_Energy",heal,[(-.55,.07,.018),(-.31,-.079,.074),(-.10,-.131,.10),
        (.115,-.095,.096),(.33,.039,.042),(.51,.14,.012)])
    p.ring("HealZonePulse_Energy",[(.75,0),(.84,.048),(.93,.040),(1,0),(.83,-.011)],
           heal,sides=16)
    p.radial("HealMote_Energy",[(0,0,0,.014),(.075,0,0,.039),(.155,.016,0,.012)],heal,sides=5)
    p.ring("BarrierHexTile_Energy",[(.374,-.024),(.420,-.018),(.46,0),(.427,.023),
           (.376,.018)],shield,sides=6,phase=math.pi/6)
    ribbon(p,"RecallPhaseStreak_Energy",phase,[(-.57,.06,.016),(-.35,-.073,.056),(.01,-.13,.117),
        (.222,-.09,.097),(.40,.06,.063),(.55,.17,.011)])
    p.ring("RecallPhaseRim_Energy",[(.76,0),(.82,.049),(.96,.034),(1,.004),(.91,-.017)],
           phase,sides=10)


def sprite_scene(name, strokes, output):
    """Make a transparent white tint mask in a Blender scene for GUI use."""
    scene=bpy.data.scenes.new(name)
    parts=Parts(name)
    scene.collection.children.link(parts.collection)
    white=bpy.data.materials.new(name+" white")
    white.use_nodes=True
    nodes=white.node_tree.nodes
    nodes.clear()
    shader=nodes.new("ShaderNodeEmission")
    shader.inputs["Color"].default_value=(1,1,1,1)
    out=nodes.new("ShaderNodeOutputMaterial")
    white.node_tree.links.new(shader.outputs[0],out.inputs[0])
    for i,path in enumerate(strokes):
        ribbon(parts,str(i+1),white,path)
    data=bpy.data.cameras.new(name+" camera")
    camera=bpy.data.objects.new(data.name,data)
    camera.location=(0,0,5)
    parts.collection.objects.link(camera)
    data.type="ORTHO"
    data.ortho_scale=2
    scene.camera=camera
    scene.render.engine="CYCLES"
    scene.cycles.samples=4
    scene.render.film_transparent=True
    scene.render.resolution_x=512
    scene.render.resolution_y=512
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.filepath=str(output)
    scene.view_settings.view_transform="Standard"
    return scene


def sprites(directory):
    dash=[
        [(-.988,.83,.006),(-.825,.692,.065),(-.647,.577,.061),(-.446,.491,.009)],
        [(-1,.61,.004),(-.877,.525,.034),(-.775,.474,.02),(-.619,.420,.004)],
        [(-.985,-.873,.008),(-.793,-.722,.076),(-.633,-.602,.06),(-.443,-.510,.008)],
        [(-.995,-.45,.005),(-.876,-.398,.025),(-.715,-.340,.029),(-.553,-.317,.004)],
    ]
    dash += [[(-x,y,w) for x,y,w in path] for path in dash]
    lift=[
        [(-.92,-.961,.014),(-.815,-.644,.105),(-.785,-.414,.074),(-.807,-.08,.006)],
        [(-.515,-.999,.006),(-.477,-.795,.063),(-.470,-.655,.047),(-.492,-.394,.007)],
        [(-.951,-.510,.01),(-.912,-.390,.04),(-.905,-.254,.043),(-.913,-.138,.005)],
    ]
    lift += [[(-x,y,w) for x,y,w in path] for path in lift]
    sprite_scene("Dash Edge Mask",dash,directory/"Dash_Edge.png")
    sprite_scene("Updraft Edge Mask",lift,directory/"Updraft_Edge.png")
