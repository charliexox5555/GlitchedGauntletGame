"""Retarget the approved Shadow Mist sculpt to the Guardian's RemasterV2 rig."""

from dataclasses import dataclass
import json
from math import cos, sin, radians
from pathlib import Path
import sys

import bpy
from mathutils import Vector

import build_ruin_blighted_expansion as support
from export_ruin_blighted import GLOW, PHASE, FLOATING_PLATES


GUN = "Guardian"
LINE = "RuinBlighted"
FILES = support.ART / "Skins" / LINE
HERO = FILES / "Vandal/v05/Vandal_RuinBlighted_v05.blend"
FINISH = "Shadow Mist - "
SIGHT_CUTS = ((-3, 30), (40, 72), (81, 117), (127, 163), (173, 212), (221, 257), (264, 311), (321, 350))
# Stations measured in the two Rest rigs. The handguard stretches around the
# Guardian's support hand and the receiver widens ahead of the magazine.
DATUMS = (
    (-1.252, -1.245), (-.75, -.75), (-.36, -.294), (-.178, -.075),
    (0, 0), (.214, .257), (.461, .485), (.729, .818), (1.046, 1.123),
    (1.320, 1.6608), (1.685, 2.259), (1.980, 2.344),
)
MAG_HEIGHTS = ((-.4041, -.205), (-.34, -.164), (-.178, -.081), (.074, .084), (.2318, .258))
ADS_DISTANCE = .438  # Same projected aperture as Vandal at the Guardian's gameplay FOV.
# Outward stroke, rise, and phase per mirrored pair. Keep the spine and the
# tapered front of the receiver seated while the surrounding plates breathe.
RECEIVER_SHARDS = {
    "UpperBrow": (.071, .36, .58),
    "UpperForward": (.059, .24, 1.63),
    "LowerLedge": (.065, -.27, 2.74),
}


@dataclass(frozen=True)
class Surface:
    verts: list
    faces: list
    material_indices: list
    material_names: list
    edges: list
    bone: str


def sample_surface(obj):
    return Surface(
        [tuple(obj.matrix_world @ v.co) for v in obj.data.vertices],
        [tuple(face.vertices) for face in obj.data.polygons],
        [face.material_index for face in obj.data.polygons],
        [slot.material.name if slot.material else FINISH + "Obsidian" for slot in obj.material_slots],
        [tuple(edge.vertices) for edge in obj.data.edges],
        obj.parent_bone,
    )


def hero_blueprint():
    if Path(bpy.data.filepath).resolve() != HERO.resolve():
        bpy.ops.wm.open_mainfile(filepath=str(HERO), load_ui=False)
    bpy.context.scene.frame_set(1)
    skin = bpy.data.collections["Ruin-Blighted | Shadow Mist"]
    objects = [
        obj for obj in skin.all_objects
        if obj.type == "MESH" and not obj.hide_render
        and not obj.name.startswith(("RB_Shard_", "RB_Action_"))
    ]
    # Fit the discarded donor magazine and grip as envelopes. Their meshes
    # never enter the Guardian asset.
    objects += [bpy.data.objects[name] for name in ("Vandal_Receiver", "Vandal_Mag", "Vandal_Grip", "Vandal_FrontSight")]
    return {obj.name: sample_surface(obj) for obj in objects}


def interp(value, stations):
    before, after = stations[-2:]
    for a, b in zip(stations, stations[1:]):
        if value <= b[0]:
            before, after = a, b
            break
    t = (value - before[0]) / (after[0] - before[0])
    return before[1] + t * (after[1] - before[1])


def body_point(point):
    x, y, z = point
    y_scale = interp(x, ((-1.25, .93), (0, .98), (1.04, .95), (1.32, .90), (1.95, .96)))
    # The front has a higher barrel axis, but the underside remains seated at
    # the player's palm. Preserve the Vandal's offset ridge above the saddle.
    rise = max(0, min(1, (x - 1.06) / .68)) * .022
    return Vector((interp(x, DATUMS), y * y_scale, .282 + (z - .29) * .84 + rise))


def rear_point(point, aim, foot=False):
    x, y, z = point
    if foot:
        below = 1 - max(0, min(1, (z - .408) / .084))
        # Sink the base into the receiver's lower spine.
        z -= .5598 - aim.z - .032 * below
    else:
        z += aim.z - .5598
    return Vector((x + aim.x - .0775, y, z))


def cross_section(surface, z):
    floor = min(v[2] for v in surface.verts)
    ceiling = max(v[2] for v in surface.verts)
    z = min(max(z, floor + .0002), ceiling - .0002)
    values = []
    for i, j in surface.edges:
        a, b = sorted((surface.verts[i], surface.verts[j]), key=lambda p: p[2])
        if a[2] <= z < b[2]:
            t = (z - a[2]) / (b[2] - a[2])
            values.append(a[0] + t * (b[0] - a[0]))
    return min(values), max(values)


def fitted_surface(source, target, heights):
    # A separate fit for each slice keeps the Guardian's short box magazine
    # and the tape edges inside its own insertion and hand-wrap contours.
    cache = {}

    def fit(point):
        x, y, z = point
        level = round(z, 4)
        if level not in cache:
            new_z = interp(level, heights)
            cache[level] = (new_z, cross_section(source, level), cross_section(target, new_z))
        new_z, (src_lo, src_hi), (dst_lo, dst_hi) = cache[level]
        u = (x - src_lo) / max(.012, src_hi - src_lo)
        u = max(-.06, min(1.06, u))
        return Vector((dst_lo + u * (dst_hi - dst_lo), y, new_z))

    return fit


def cut_region(name):
    if name.startswith("RB_RearSight"):
        return "Sight"
    if "Magazine" in name:
        return "Mag"
    if "Handguard" in name:
        return "Fore"
    if "Stock" in name:
        return "Stock"
    return "Receiver"


def add_surface(col, name, source, fit, materials):
    verts = [fit(v) for v in source.verts]
    obj = support.mesh(col, name, verts, source.faces, materials[source.material_names[0]])
    for mat in source.material_names[1:]:
        obj.data.materials.append(materials[mat])
    for face, index in zip(obj.data.polygons, source.material_indices, strict=True):
        face.material_index = index
        # The cut-out inserts are one-sided and face the player's view.
        if name.startswith("RB_RearSight_Fragment") and FINISH + "Wrap" in source.material_names[index]:
            old_vertices = [Vector(source.verts[i]) for i in source.faces[face.index]]
            before = (old_vertices[1] - old_vertices[0]).cross(old_vertices[2] - old_vertices[0])
            if before.dot(face.normal) < 0:
                face.flip()
    obj.data.update()
    return obj


def material_bank(blueprint):
    names = {name for surface in blueprint.values() for name in surface.material_names if name.startswith(FINISH)}
    names.update(FINISH + name for name in ("Obsidian", "Slate", "Gunmetal", "Shadow", "Grip"))
    with bpy.data.libraries.load(str(HERO)) as (src, dst):
        missing = names - set(src.materials)
        if missing:
            raise RuntimeError(f"Missing approved finishes: {missing}")
        dst.materials = sorted(names)
    mats = dict(zip(sorted(names), dst.materials, strict=True))
    for key, role in {
        "Body": "Obsidian", "Dark": "Shadow", "Panel": "Gunmetal",
        "Grip": "Grip", "Metal": "Gunmetal", "Accent": "Slate", "Neon": "Teal recess",
    }.items():
        mats[key] = mats[FINISH + role]
    mats["Brass"] = bpy.data.materials["Brass"]
    return mats


def front_point(point, aim):
    x,y,z = point
    height = interp(z, ((.20,.324),(.338,.379),(.47,aim.z-.069),(.594,aim.z+.033)))
    if abs(y)<.010:
        height=min(height,aim.z-.008)
    return Vector((x+.265,y*.91,height))


def lower_receiver_hardware(col, colors):
    # Fill the measured gap between the stock grip's crown and the carved
    # receiver. Keep the tape contour and the player's palm surface intact.
    collar_outline = (
        (-.091, .157), (-.068, .191), (.107, .188), (.184, .182),
        (.186, .158), (.153, .136), (.041, .142), (-.062, .145),
    )
    collar = support.prism(col, "RB_Guardian_GripCollar", collar_outline,
                           -.068, .068, colors[FINISH+"Gunmetal"], .009)

    # The rear ear seats into the collar. The upper bridge reaches the trigger
    # pivot and the front ear stops behind the magazine's exit path.
    outer = (
        (.143, .168), (.184, .188), (.315, .186), (.422, .180),
        (.446, .151), (.423, .069), (.388, .037), (.199, .029), (.157, .056),
    )
    inner = (
        (.171, .136), (.204, .123), (.315, .121), (.398, .130),
        (.413, .112), (.399, .083), (.377, .061), (.206, .053), (.181, .079),
    )
    vertices = []
    sections = (
        (0, -.82), (.11, -1), (.89, -1), (1, -.82),
        (1, .82), (.89, 1), (.11, 1), (0, .82),
    )
    for toward_window, side in sections:
        for outside, inside in zip(outer, inner, strict=True):
            x, z = Vector(outside).lerp(Vector(inside), toward_window)
            half_width = .031 + .010 * max(0, (z - .040) / .150)
            vertices.append((x, side * half_width, z))
    n = len(outer)
    faces = []
    for ring in range(len(sections)):
        other = (ring + 1) % len(sections)
        for i in range(n):
            j = (i + 1) % n
            faces.append((ring*n+i, ring*n+j, other*n+j, other*n+i))
    guard = support.mesh(col, "RB_Guardian_FacetedTriggerGuard", vertices, faces,
                         colors[FINISH+"Obsidian"])
    guard.data.materials.append(colors[FINISH+"Slate"])
    for face in guard.data.polygons:
        ring, edge = divmod(face.index, n)
        if ring in {0, 6} and edge in {4, 5, 6, 7}:
            face.material_index = 1
    return collar, guard


def receiver_shard(name):
    if not name.startswith("RB_Receiver_"):
        return None
    return RECEIVER_SHARDS.get(name.removeprefix("RB_Receiver_").rsplit("_", 1)[0])


def energy_manifest(aim, mag_fit, movers):
    approval = json.loads((HERO.parent / "manifest_flat.json").read_text(encoding="utf-8"))
    result = []
    for spec in approval["energy"]:
        area = spec["region"]
        source = spec["point"]
        if area == "Mag":
            point = mag_fit(source)
        elif area == "Sight":
            point = rear_point(source, aim)
        else:
            point = body_point(source)
        result.append({**spec, "point": list(point)})
    by_source = {item["source"]:item["name"] for item in movers}
    for i,(start,end) in enumerate(SIGHT_CUTS,1):
        bone = by_source[f"RB_RearSight_Fragment_{i:02}"]
        for label, angle in (("Start",start+.65),("End",end-.65)):
            t = radians(angle)
            point = rear_point((.065,.078*cos(t),.5598+.078*sin(t)),aim)
            result.append({"name":"RuinSight"+label,"bone":bone,"point":list(point),"mist":False})
    return result


def finish_manifest(components, joints, colors, dest, replaced, energy, *, gun=GUN, ads_distance=ADS_DISTANCE):
    area_by_bone = {joint["name"]: joint["region"] for joint in joints}
    existing = {}
    for obj in components:
        area = area_by_bone.get(obj.parent_bone, cut_region(obj.name))
        for slot in obj.material_slots:
            role = slot.material.name.removeprefix(FINISH).split(".")[0]
            if obj.parent_bone in area_by_bone and (area != "Sight" or role not in GLOW):
                side = "Slate" if area != "Sight" and role in ("Slate", "Broken edge") else "Obsidian"
                slot.material = colors[FINISH + side]
            elif role in GLOW:
                key = (area, role)
                if key not in existing:
                    existing[key] = slot.material.copy()
                    existing[key].name = f"Ruin glow {area} {role}"
                slot.material = existing[key]
    fbx, parts = support.export_flat(components, str(dest), gun, LINE)
    if support.CROSSED_LEFT:
        raise RuntimeError(support.CROSSED_LEFT)
    installed = {}
    for name, spec in parts.items():
        role = spec["blender_material"].removeprefix(FINISH)
        part = {"b":spec["bone"],"c":spec["center"],"s":spec["size"],"col":spec["color"],
                "mat":spec["material"],"refl":spec["reflectance"],"tris":spec["triangles"]}
        if role.startswith("Ruin glow "):
            _,_,area,layer = role.split(" ",3)
            part.update(mat="Neon",col=GLOW[layer],glow=PHASE[area]+(.32 if layer=="Wrap jade" else 0),
                        glowMix={"Wrap jade":.43,"Teal inlay":.82,"Wrap crest":1.0}[layer])
        elif role.startswith("Grip "):
            part["mat"] = "Fabric"
        elif role.startswith("Magazine "):
            part["mat"] = "Slate"
        elif role.startswith("Shadow Mist cartridge - "):
            part["loadedRound"] = True
            if role == "Shadow Mist cartridge - seafoam":
                part["mat"] = "Neon"
        installed[name] = part
    data = {"line":LINE,"gun":gun,"version":dest.name,"file":Path(fbx).name,
            "parts":installed,"replaced":dict.fromkeys(replaced,True),
            "joints":joints,"energy":energy,
            "designReference":"Vandal_RuinBlighted_v05.blend","stockReference":f"{gun}_RemasterV2_v05.blend"}
    if ads_distance is not None:
        data["adsDistance"] = ads_distance
    (dest / "manifest_flat.json").write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
    return len(installed),sum(p["tris"] for p in installed.values())


def build(blueprint):
    scene = support.read_scene(GUN)
    support.setup(scene)
    rig = bpy.data.objects[GUN + "_Rig"]
    rig.data.pose_position = "REST"
    scene.view_layers[0].update()
    stock = support.stock.meshes(GUN)
    by_name = {obj.name.removeprefix(GUN + "_"):obj for obj in stock}
    aim = support.stock.locator(GUN, "AimPoint")
    cameras = support.get_views(GUN, support.points(stock))
    folder = FILES / GUN
    versions = [int(item.parent.name[1:]) for item in folder.glob("v*/manifest_flat.json")]
    dest = folder / f"v{max(versions,default=0)+1:02}"
    dest.mkdir(exist_ok=True)
    for view in ("side","held","aim"):
        support.render(scene,cameras[view],dest/"review"/f"stock_{view}.png",1,(1280,720))

    col = support.collection(scene, "Ruin-Blighted | Guardian")
    colors = material_bank(blueprint)
    mag_fit = fitted_surface(blueprint["Vandal_Mag"], sample_surface(by_name["Mag"]), MAG_HEIGHTS)
    tape_fit = fitted_surface(blueprint["Vandal_Grip"], sample_surface(by_name["Grip"]),
                              ((-.3063,-.307),(-.12,-.121),(.02,.019),(.166,.1597)))
    components = []
    moving = []
    for name, source in blueprint.items():
        if name in ("Vandal_Mag","Vandal_Grip","Vandal_FrontSight"):
            continue
        area = cut_region(name)
        if name.startswith("RB_RearSight"):
            fit = lambda p: rear_point(p,aim,"Fragment" not in name)
        elif area == "Mag":
            fit = mag_fit
        elif "PistolGrip" in name:
            fit = tape_fit
        else:
            fit = body_point
        obj = add_surface(col,name.replace("Vandal_","RB_Carved"),source,fit,colors)
        if area=="Sight" and name.startswith("RB_RearSight_Fragment"):
            center = support.position_origin(obj)
            axis = Vector((0,center.y,center.z-aim.z)).normalized()
            moving.append((obj,"Root",center,"Sight",axis,.010))
        elif receiver := receiver_shard(name):
            travel, rise, _ = receiver
            center = support.position_origin(obj)
            sign = 1 if center.y >= 0 else -1
            # Move outward from the receiver with a small stagger along the
            # seam. No component moves inward toward the sight or trigger.
            axis = Vector((.10, sign*.92, rise)).normalized()
            moving.append((obj,"Root",center,"Receiver",axis,travel))
        elif name.startswith(FLOATING_PLATES):
            center = support.position_origin(obj)
            sign = 1 if center.y >= 0 else -1
            axis = Vector((.04,sign*.85,.36 if center.z>.30 else -.29)).normalized()
            moving.append((obj,"Root",center,area,axis,.041))
        support.bind(obj,rig,source.bone)
        components.append(obj)
    # Keep the complete stock barrel profile. Fit the hero's twin front ears
    # to the Guardian bore and eye datums so the sight language matches.
    barrel = sample_surface(by_name["Barrel"])
    components.append(add_surface(col,"RB_Guardian_OriginalBarrel",barrel,Vector,colors))
    support.bind(components[-1],rig,"Root")
    front = blueprint["Vandal_FrontSight"]
    components.append(add_surface(col,"RB_Guardian_FrontSight",front,lambda p: front_point(p,aim),colors))
    support.bind(components[-1],rig,"Root")
    grip = sample_surface(by_name["Grip"])
    components.append(add_surface(col,"RB_Guardian_GripCore",grip,Vector,colors))
    support.bind(components[-1],rig,"Root")
    for hardware in lower_receiver_hardware(col, colors):
        support.bind(hardware, rig, "Root")
        components.append(hardware)

    # Keep mechanical contacts and the original trigger articulated. The
    # archived stock meshes remain available in the Blender file.
    replaced = []
    for name,obj in by_name.items():
        if name not in {"Trigger","CharmLoop"}:
            obj.hide_render = True
            obj.hide_set(True)
            replaced.append(name)

    scene.view_layers[0].update()
    checks = support.check_aim(scene,GUN,components,cameras["aim"])
    joints = support.rig_shards(rig,moving)
    for joint in joints:
        if joint["region"]=="Sight":
            serial=int(joint["source"].rsplit("_",1)[1])
            joint["phase"]=serial*.7854
        elif receiver := receiver_shard(joint["source"]):
            joint["phase"] = receiver[2] + (.47 if joint["source"].endswith("_R") else 0)
            joint["tilt"] = .048
            joint["tether"] = "UpperBrow" in joint["source"]
        else:
            joint["tether"]="Forehead" in joint["source"] or "MainCleavedPlate" in joint["source"]
    energy = energy_manifest(aim,mag_fit,joints)
    for anchor in energy:
        item = support.locator(col,anchor["name"],anchor["point"])
        support.bind(item,rig,anchor["bone"])

    # Match the Vandal's angular aperture for the skin review at the
    # Guardian's zoom, while preserving the original stock-camera render.
    eye = aim - Vector((ADS_DISTANCE,0,0))
    aim_ref = support.stock.camera(GUN,"ShadowMist_ADS",eye,aim,fov_v=58,clip=.10)
    detail = support.camera(col, "Guardian Trigger and Grip Review", (.182, 0, -.022),
                            (-.13, .97, .17), scale=.99, distance=2)
    for view,camera in {**cameras,"aim":aim_ref,"trigger_grip":detail}.items():
        support.render(scene,camera,dest/"review"/(view+".png"),1,(1280,720))
    rig.data.pose_position="POSE"
    scene.camera=cameras["hero"]
    scene.name="Ruin-Blighted Guardian | Shadow Mist"
    target=dest / f"{GUN}_{LINE}_{dest.name}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(target))
    rig.data.pose_position="REST"
    scene.view_layers[0].update()
    count,tris=finish_manifest(components,joints,colors,dest,replaced,energy)
    checks.update(reference=HERO.name,stock_source=f"{GUN}_RemasterV2_v05.blend",
                  stock_barrel_preserved=True,parts=count,triangles=tris,
                  moving_panels=len(joints)-8,sight_segments=8,ads_viewmodel_distance=ADS_DISTANCE,
                  receiver_shards=sum(j["region"]=="Receiver" for j in joints))
    (dest/"review/checks.json").write_text(json.dumps(checks,indent=2)+"\n",encoding="utf-8")
    return str(target)
