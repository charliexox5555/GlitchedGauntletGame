"""Fit the approved Spindrift hero to the stock game Vandal in the live session."""

import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import spindrift_hero as h
from scene import bind, render


OUT = h.OUT.with_name("v02")
FILE = OUT / "Vandal_Spindrift_GameFit_v02.blend"
ART = h.PREFIX + "01 Sculpted exterior"
FX = h.PREFIX + "02 Tidal surface and motion"
STAGE = h.PREFIX + "03 Review stage"

# Stock blade envelope retained at the tip. The shoulder and handguard carry
# wider planar surfaces on the stock receiver and handguard height bands.
UPPER = [
    (-.325,.284,.335,.045), (-.177,.274,.404,.096), (-.060,.274,.420,.102),
    (.247,.272,.420,.103), (.530,.264,.415,.101), (.765,.268,.413,.101),
    (1.014,.276,.413,.099), (1.075,.272,.402,.101), (1.412,.252,.402,.098),
    (1.637,.255,.388,.096), (1.708,.257,.366,.086), (1.914,.262,.336,.075),
    (2.125,.262,.332,.072), (2.322,.258,.311,.060), (2.486,.271,.292,.035),
    (2.642,.278,.282,.003),
]
LOWER = [
    (-.323,.237,.291,.043), (-.177,.203,.285,.090), (-.074,.163,.271,.104),
    (.076,.128,.248,.100), (.268,.126,.245,.097), (.403,.108,.218,.102),
    (.490,.087,.203,.104), (.750,.087,.232,.103), (1.032,.114,.238,.101),
    (1.109,.129,.230,.100), (1.399,.130,.211,.101), (1.641,.129,.215,.096),
    (1.735,.139,.220,.092), (2.064,.157,.212,.077), (2.322,.155,.196,.060),
    (2.486,.148,.174,.035), (2.646,.133,.137,.003),
]

# X rear/front and half-width at each Z. These are measured contact sections
# of the stock parts, with small end treatments outside the gripping band.
GRIP = [
    (-.304,-.152,.010,.049), (-.290,-.174,.015,.060),
    (-.240,-.179,.049,.063), (-.180,-.168,.057,.062),
    (-.120,-.158,.071,.063), (-.060,-.147,.093,.063),
    ( .000,-.137,.109,.063), ( .060,-.109,.124,.063),
    ( .122,-.086,.116,.062), ( .164,-.080,.105,.055),
]
MAG = [
    (-.399,.764,.860,.048), (-.389,.705,.878,.061),
    (-.320,.675,.961,.057), (-.250,.630,.902,.057),
    (-.150,.572,.835,.057), (-.050,.522,.780,.057),
    ( .030,.491,.745,.057), ( .130,.468,.709,.057),
    ( .200,.484,.685,.045), ( .229,.505,.674,.040),
]


def fit_section(rows, axis):
    for a, b in zip(rows, rows[1:]):
        if a[0] <= axis <= b[0]:
            u = (axis-a[0]) / (b[0]-a[0])
            return tuple(p*(1-u) + q*u for p, q in zip(a[1:], b[1:]))
    raise ValueError(f"Section coordinate outside profile: {axis}")


def rect_shell(col, name, sections, slots, crown):
    # One long side face with a narrower facet at each change of plane.
    section = [
        (.57,.00), (.84,.02), (1,.18), (1,.71), (.88,.88),
        (.62,1), (-.62,1), (-.88,.88), (-1,.71), (-1,.18),
        (-.84,.02), (-.57,.00),
    ]
    rings = [[(x,y*w,low+(t if crown else 1-t)*(high-low)) for y,t in section]
             for x,low,high,w in sections]
    return h.skin(col,name,rings,slots,[1,1,0,0,3,0,3,0,0,1,1,1],smooth=False)


def grip_shell(col, name, rows, slots, strips):
    # Broad near/far faces, with two narrow flats cut around the grip edges.
    section = [
        (1,-.63), (.87,-.87), (.71,-1), (-.69,-1), (-.88,-.84), (-1,-.59),
        (-1,.59), (-.88,.84), (-.69,1), (.71,1), (.87,.87), (1,.63),
    ]
    rings = [[((rear+fore)/2 + x*(fore-rear)/2,y*w,z) for x,y in section]
             for z,rear,fore,w in rows]
    return h.skin(col,name,rings,slots,strips,smooth=False)


def discard(ob):
    data = ob.data
    kind = ob.type
    bpy.data.objects.remove(ob, do_unlink=True)
    if data and not data.users:
        (bpy.data.meshes if kind == "MESH" else bpy.data.curves).remove(data)


def set_face_hard(ob):
    for face in ob.data.polygons:
        face.use_smooth = False
    for mod in ob.modifiers:
        if mod.type == "BEVEL":
            mod.segments = 1
            mod.width = min(mod.width,.0022)


def finned_crown(col, slots):
    for i,(x,span,width,lift) in enumerate([
        (1.732,.194,.086,.032), (1.529,.244,.098,.035),
        (1.295,.270,.100,.048), (1.056,.269,.106,.054),
        (.806,.261,.109,.065), (.512,.229,.108,.079),
    ],1):
        z = fit_section(UPPER,max(.20,x-.16))[1]-.012
        rings = []
        for a in (-1,-.78,-.48,-.22,0,.22,.48,.78,1):
            s = abs(a)
            y = a*width
            # The crest is straight across the hottest face near the center,
            # then takes two deliberate folds down to the receiver.
            rise = lift * (1-min(1,s*.91))
            base = z - .048*s
            seat = x + span*.62*s
            end = x - span*(1-.57*s)
            rings.append([
                (seat,y*.90,base-.027), (seat+.010,y*.95,base-.004),
                (seat-span*.12,y,base+.007+rise*.24),
                (end+.041,y*.99,base+.012+rise*.89),
                (end,y*.98,base+.012+rise), (end+.021,y*.93,base-.003+rise*.71),
                (end+.074,y*.89,base-.024+rise*.34),
            ])
        h.skin(col,f"04.{i} | Folded nacre crest",rings,slots,
               [1,0,2 if i>=3 else 3,2,3,1,1],smooth=False)


def plate(col, name, outline, side, slots, height=.006):
    """Planar outside, keyed underside and one real chamfer around the outline."""
    mid_x = sum(x for x,z,y in outline)/len(outline)
    mid_z = sum(z for x,z,y in outline)/len(outline)
    count = len(outline)
    base = [(x,side*(y-.011),z) for x,z,y in outline]
    shoulder = [(x,side*(y+height*.35),z) for x,z,y in outline]
    face = [(x*.94+mid_x*.06,side*(y+height),z*.94+mid_z*.06) for x,z,y in outline]
    faces = [tuple(range(count-1,-1,-1)), tuple(range(count*2,count*3))]
    roles = [1,0]
    for layer,mat in ((0,1),(1,2)):
        for j in range(count):
            k=(j+1)%count
            faces.append((layer*count+j,layer*count+k,(layer+1)*count+k,(layer+1)*count+j))
            roles.append(mat)
    return h.finish(col,name,base+shoulder+face,faces,slots,roles,smooth=False)


def side_panels(col, slots):
    trim = [slots[0],slots[1],slots[3]]
    for side in (-1,1):
        plate(col,f"05 | Receiver shoulder {side:+}",[
            (-.245,.300,.065), (-.151,.381,.095), (-.071,.404,.104), (.209,.400,.104),
            (.298,.369,.104), (.206,.330,.104), (-.049,.282,.103), (-.170,.280,.093),
        ],side,trim,.006)
        plate(col,f"06 | Long receiver face {side:+}",[
            (.244,.328,.102), (.415,.390,.102), (.924,.390,.102),
            (1.016,.373,.102), (.945,.331,.102), (.779,.298,.102), (.403,.293,.102),
        ],side,trim,.007)
        plate(col,f"07 | Underbody and magazine throat {side:+}",[
            (.386,.127,.098), (.477,.174,.101), (.711,.215,.102), (.957,.207,.100),
            (1.033,.169,.100), (.893,.136,.102), (.752,.097,.103), (.517,.083,.103),
        ],side,trim,.006)
        plate(col,f"08 | Handguard side plate {side:+}",[
            (1.081,.322,.100), (1.180,.384,.099), (1.556,.374,.097),
            (1.672,.348,.092), (1.614,.297,.098), (1.385,.269,.100), (1.155,.273,.101),
        ],side,trim,.006)
        for i in range(3):
            x = 1.214+i*.109
            plate(col,f"08.{i+1} | Cold cut handguard detail {side:+}",[
                (x,.330,.105), (x+.019,.346,.105), (x+.067,.346,.105),
                (x+.050,.331,.105), (x+.038,.324,.105),
            ],side,[slots[1],slots[1],slots[0]],.0016)


def furniture(col, slots, leather, rig):
    stock_outer = [
        (-.181,.360,.084), (-.355,.378,.078), (-.574,.370,.069),
        (-.904,.386,.070), (-1.180,.418,.073), (-1.249,.392,.078),
        (-1.249,.045,.078), (-1.221,-.112,.080), (-1.154,-.118,.076),
        (-.953,-.016,.071), (-.717,.109,.068), (-.473,.196,.073), (-.217,.232,.083),
    ]
    stock_inner = [
        (-.381,.290,.058), (-.478,.324,.064), (-.644,.327,.059),
        (-.908,.337,.056), (-1.107,.359,.054), (-1.164,.343,.056),
        (-1.166,.140,.058), (-1.156,.039,.057), (-1.117,.019,.056),
        (-.972,.064,.054), (-.749,.161,.054), (-.528,.241,.057), (-.411,.267,.058),
    ]
    h.frame(col,"10 | Pierced crescent stock",stock_outer,stock_inner,slots,{3,4,5,7,8})
    rect_shell(col,"10 | Receiver tongue and comb",[
        (-.454,.247,.342,.053), (-.363,.231,.370,.075),
        (-.247,.236,.370,.081), (-.159,.247,.385,.084), (-.105,.258,.366,.080),
    ],slots,True)
    grip_shell(col,"11 | Cut and wrapped pistol grip",GRIP,
               [slots[0],leather,slots[1]],[2,2,1,1,1,2,2,1,1,1,2,2])
    grip_shell(col,"12 | Shelled grip heel",[
        (-.305,-.151,.011,.049), (-.295,-.174,.018,.061), (-.281,-.174,.025,.061),
    ],slots,[1,3,2,0,0,1,1,0,0,2,3,1])
    for side in (-1,1):
        for i,z in enumerate((-.238,-.191,-.145,-.099,-.054)):
            rear,fore,w = fit_section(GRIP,z)
            plate(col,f"13.{i+1} | Stormcloth seam {side:+}",[
                (rear+.046,z-.006,w-.001),(fore-.043,z+.001,w-.001),
                (fore-.036,z+.010,w-.001),(rear+.057,z+.003,w-.001),
            ],side,[slots[1],slots[1],slots[0]],.0021)
    mag = grip_shell(col,"15 | Stock-fit tidal magazine",MAG,slots,
                     [1,3,3,0,0,1,1,0,0,3,3,1])
    shoe = grip_shell(col,"16 | Chiseled magazine heel",[
        (-.405,.753,.877,.049), (-.394,.712,.895,.064),
        (-.373,.703,.902,.063), (-.362,.700,.899,.054),
    ],slots,[1,3,2,0,0,1,1,0,0,2,3,1])
    for ob in (mag,shoe):
        bind(ob,rig,"Mag")


def new_sight(col, slots,glint):
    rect_shell(col,"20 | Crest sight bed",[
        (-.071,.399,.435,.035), (-.027,.395,.466,.075),
        (.107,.397,.466,.074), (.189,.406,.442,.056), (.239,.411,.428,.033),
    ],slots,True)
    for side in (-1,1):
        rings=[]
        for u in (0,.13,.27,.40,.56,.70,.83,.93,1):
            angle=math.radians(-69+139*u)
            y=.071*math.cos(angle)
            z=.554+.087*math.sin(angle)
            thick=.014*(1-u)**.61+.0022
            x=.085-.063*u
            rings.append([(x+math.cos(j*math.tau/8)*thick,
                           side*(y+math.sin(j*math.tau/8)*thick*math.cos(angle)),
                           z+math.sin(j*math.tau/8)*thick*math.sin(angle))
                          for j in range(8)])
        h.skin(col,f"21 | Faceted split sight {side:+}",rings,slots,
               [2,2,3,0,1,1,0,3],smooth=False)
    front = [
        (1.786,.316,.343,.024), (1.844,.321,.401,.025),
        (1.947,.337,.476,.018), (2.031,.385,.526,.013),
        (2.054,.459,.544,.007), (2.064,.494,.545,.005),
    ]
    rect_shell(col,"23 | Tapered forward sight",front,slots,True)
    rect_shell(col,"24 | Cyan sight inlay",[
        (2.047,.539,.544,.003),(2.055,.540,.550,.005),(2.064,.540,.550,.004),
        (2.071,.541,.546,.001),
    ],[glint,slots[1],slots[2],slots[3]],True)


def stock_details(sc, col, slots):
    # Reuse the game's animated display parts, including their original seats.
    for suffix in ("Trigger","CharmLoop","ChargingHandle"):
        ob=sc.objects["Vandal_"+suffix]
        ob.hide_render=False
        ob.hide_set(False)
    # Keep the stock handle's parent and action. Its dark and pearl faces
    # mark the stock hand location during the game's reload.
    handle=sc.objects["Vandal_ChargingHandle"]
    handle.data=handle.data.copy()
    for i,mat in enumerate(handle.data.materials):
        handle.data.materials[i] = slots[3] if "Metal" in mat.name else slots[1]
    for side in (-1,1):
        plate(col,f"32 | Cinnabar seal panel {side:+}",[
            (-.137,.333,.109), (-.108,.353,.109), (.024,.353,.108),
            (-.004,.328,.109), (-.111,.328,.109),
        ],side,[slots[1],slots[1],slots[3]],.003)


def materials(slots, leather):
    for mat, lo, hi in [(slots[0],.36,.46),(slots[1],.41,.49),
                         (slots[2],.32,.39),(slots[3],.34,.43)]:
        shader=mat.node_tree.nodes.get("Principled BSDF")
        rough=shader.inputs["Roughness"].links[0].from_node
        rough.inputs["To Min"].default_value=lo
        rough.inputs["To Max"].default_value=hi
        mat.roughness=(lo+hi)*.5
    for mat in (slots[0],slots[1],leather):
        shader=mat.node_tree.nodes.get("Principled BSDF")
        bump=shader.inputs["Normal"].links[0].from_node
        bump.inputs["Strength"].default_value=.15


def replace_hull(sc):
    assert not bpy.app.background and sc.get("Spindrift workshop")=="Live art working scene"
    col=bpy.data.collections[ART]
    current=bpy.data.collections[FX]
    rig=sc.objects["Vandal_Rig"]
    slots=list(col.objects["01 | Lacquer crown and upper prow"].data.materials)
    leather=col.objects["11 | Carved palm and wrapped grip"].data.materials[1]
    glint=next(ob for ob in current.objects if "Water caustic" in ob.name).data.materials[0]
    for ob in list(col.objects):
        keep = ob.name.startswith(("03 |","09 |","14 |"))
        if not keep:
            discard(ob)
        else:
            set_face_hard(ob)
    rect_shell(col,"01 | Lacquer crown and upper prow",UPPER,slots,True)
    rect_shell(col,"02 | Undercut keel and lower prow",LOWER,slots,False)
    finned_crown(col,slots)
    side_panels(col,slots)
    furniture(col,slots,leather,rig)
    new_sight(col,slots,glint)
    stock_details(sc,col,slots)
    materials(slots,leather)
    for ob in col.objects:
        if ob.data.shape_keys:
            ob.shape_key_clear()
        if ob.parent_bone != "Mag":
            bind(ob,rig,"Root")
    h.flex_prow(col)
    for ob in current.objects:
        if ob.type != "EMPTY" and ob.parent == rig:
            bind(ob,rig,"Root")
    effect=current.objects["CTRL | Tide release"]
    # Retain the animation channels when changing its parent space.
    basis=effect.matrix_basis.copy()
    world=effect.matrix_world.copy()
    bind(effect,rig,"Root")
    effect.matrix_parent_inverse=effect.matrix_parent_inverse@world@basis.inverted_safe()
    effect.matrix_basis=basis
    seal=[o for o in current.objects if "Engraved wave hallmark" in o.name]
    for ob in seal:
        for point in ob.data.splines[0].bezier_points:
            point.co.y = math.copysign(.114, point.co.y)
            point.co.z -= .013
    sc.name="Spindrift Vandal | Game fit"
    sc.frame_set(1)
    bpy.context.view_layer.update()
    return col


def reference_vertices(ob):
    return [ob.matrix_world@v.co for v in ob.data.vertices]


def planes(ob, coords):
    verts=reference_vertices(ob)
    results=[]
    for z in coords:
        hits=[]
        for edge in ob.data.edges:
            a,b=[verts[i] for i in edge.vertices]
            if min(a.z,b.z)<=z<max(a.z,b.z):
                hits.append(a.lerp(b,(z-a.z)/(b.z-a.z)))
        results.append([min(v.x for v in hits),max(v.x for v in hits),max(abs(v.y) for v in hits)])
    return results


def mesh_tree(ob, depsgraph):
    evaluated=ob.evaluated_get(depsgraph)
    return BVHTree.FromPolygons(reference_vertices(evaluated),
                               [tuple(p.vertices) for p in evaluated.data.polygons])


def archived_hands(stock_meshes, skin_meshes):
    sys.path.insert(0,str(h.ART.parents[1]/"tools/blender"))
    from check_hand_clipping import box_from, depth_inside

    depsgraph=bpy.context.evaluated_depsgraph_get()
    def extent(pts):
        return tuple((min(p[i] for p in pts),max(p[i] for p in pts)) for i in range(3))

    groups=[]
    for group in (stock_meshes,skin_meshes):
        meshes=[]
        for ob in group:
            verts=reference_vertices(ob.evaluated_get(depsgraph))
            meshes.append((ob.name,ob.parent_bone,verts,mesh_tree(ob,depsgraph),extent(verts)))
        groups.append(meshes)
    modes={}
    for mode in ("hold","draw","inspect","reload","reloadempty"):
        path=h.ART.parent/f"viewmodel/checks/Vandal_{mode}.json"
        capture=json.loads(path.read_text(encoding="utf-8"))
        half=capture["half"]
        row={"frames":len(capture["frames"]),"max_added_depth":0.0,
             "max_stock_depth":0.0,"max_skin_depth":0.0,"worst":None}
        for frame in capture["frames"]:
            for side,joints in frame["arms"].items():
                boxes={}
                for joint,matrix in joints.items():
                    center,axes,corners,tree=box_from(matrix,half)
                    boxes[joint]=(center,axes,tree,extent(corners))
                dominant=[]
                for meshes in groups:
                    contacts=[]
                    for name,bone,verts,tree,bounds in meshes:
                        center,axes,box,arm_bounds=boxes.get(bone,boxes["Root"])
                        if any(a_max<b_min or b_max<a_min for ((a_min,a_max),(b_min,b_max))
                               in zip(arm_bounds,bounds)):
                            continue
                        depth=max(depth_inside(v,center,axes,half) for v in verts)
                        if depth or box.overlap(tree):
                            contacts.append((depth,name))
                    dominant.append(max(contacts,default=(0.0,None)))
                (stock,name_a),(skin,name_b)=dominant
                row["max_stock_depth"]=round(max(stock,row["max_stock_depth"]),4)
                row["max_skin_depth"]=round(max(skin,row["max_skin_depth"]),4)
                extra=round(skin-stock,4)
                if extra>row["max_added_depth"]:
                    row["max_added_depth"]=extra
                    row["worst"]={"frame":frame["label"],"hand":side,"stock":name_a,"skin":name_b,
                                  "stock_depth":round(stock,4),"skin_depth":round(skin,4)}
        modes[mode]=row
    return modes


def fit_report(sc):
    col=bpy.data.collections[ART]
    stock=bpy.data.collections["Vandal"]
    rig=sc.objects["Vandal_Rig"]
    sc.frame_set(1)
    dg=bpy.context.evaluated_depsgraph_get()
    candidates=[o for o in col.objects if o.type=="MESH"]
    errors=[]
    count=0
    locations=[]
    for ob in candidates:
        bm=bmesh.new()
        bm.from_mesh(ob.data)
        if (any(not e.is_manifold for e in bm.edges) or
                any(p.calc_area()<1e-10 for p in bm.faces) or bm.calc_volume(signed=True)<=0):
            errors.append(ob.name)
        bm.free()
        ev=ob.evaluated_get(dg)
        count+=sum(len(p.vertices)-2 for p in ev.data.polygons)
        locations.extend(reference_vertices(ob))
    count+=sum(len(p.vertices)-2 for o in stock.objects
               if o.type=="MESH" and not o.hide_render for p in o.data.polygons)
    fit={}
    for name,mesh_name,sections in [
        ("Grip","11 | Cut and wrapped pistol grip",[-.29,-.24,-.18,-.12,-.06,0]),
        ("Mag","15 | Stock-fit tidal magazine",[-.389,-.32,-.25,-.15,-.05,.03,.13,.20]),
    ]:
        a=planes(sc.objects["Vandal_"+name],sections)
        b=planes(col.objects[mesh_name],sections)
        fit[name]=[{"z":z,"stock":[round(v,4) for v in x],"skin":[round(v,4) for v in y],
                    "max_delta":round(max(abs(p-q) for p,q in zip(x,y)),4)}
                   for z,x,y in zip(sections,a,b)]
    aim=sc.objects["Vandal_AimPoint"].matrix_world.translation
    rays={}
    for y,z in [(0,0),(.004,0),(-.004,0),(0,.004),(0,-.004)]:
        origin=Vector((-.47,aim.y+y,aim.z+z))
        ray=sc.ray_cast(dg,origin,Vector((1,0,0)),distance=3.5)
        rays[f"{y}:{z}"]=ray[4].name if ray[0] else None
    mag=col.objects["15 | Stock-fit tidal magazine"]
    plate_heel=col.objects["16 | Chiseled magazine heel"]
    body=[o for o in candidates if o.name.startswith(("01 |","02 |","03 |","07 |"))]
    stock_mag=sc.objects["Vandal_Mag"]
    reload_motion={}
    rig.animation_data.action=bpy.data.actions["Vandal_Reload"]
    try:
        for f in (1,8,15,23,30,37,48,66,97):
            sc.frame_set(f)
            graph=bpy.context.evaluated_depsgraph_get()
            magtree=mesh_tree(mag,graph)
            count_by_body={fixed.name:len(magtree.overlap(mesh_tree(fixed,graph))) for fixed in body}
            reload_motion[f] = {
                "stock_relative_drift":round((mag.matrix_world.translation
                     -stock_mag.matrix_world.translation).length,5),
                "overlap_tri_pairs_at_mag_well":sum(count_by_body.values()),
                "heel_seat_follows_mag":mag.parent_bone==plate_heel.parent_bone=="Mag",
            }
    finally:
        rig.animation_data.action=None
        for bone in rig.pose.bones:
            bone.matrix_basis.identity()
        sc.frame_set(1)
    stock_count=sum(len(p.vertices)-2 for o in stock.objects if o.type=="MESH"
                    for p in o.data.polygons)
    stock_meshes=[o for o in stock.objects if o.type=="MESH"]
    skin_meshes=candidates+[o for o in stock_meshes if not o.hide_render]
    return {
        "mesh_errors":errors,
        "evaluated_model_triangles_excluding_water_fx":count,
        "stock_model_triangles":stock_count,
        "body_bounds":[[round(fun(v[i] for v in locations),4) for i in range(3)]
                       for fun in (min,max)],
        "cross_sections_x_min_x_max_y_half_width":fit,
        "stock_sight_rays_hit":rays,
        "stock_reload_sample_frames":reload_motion,
        "archived_hand_block_comparison":archived_hands(stock_meshes,skin_meshes),
    }


def save(sc):
    sc.camera=sc.objects[h.PREFIX+"Hero"]
    sc.frame_set(1)
    sc.render.resolution_x,sc.render.resolution_y=1450,780
    sc.render.filepath=str(OUT/"Spindrift_Hero.png")
    for area in bpy.context.window.screen.areas:
        if area.type=="VIEW_3D":
            area.spaces.active.region_3d.view_perspective="CAMERA"
    bpy.ops.wm.save_as_mainfile(filepath=str(FILE))


def build():
    sc=bpy.context.scene
    origin=Path(bpy.data.filepath).name
    assert origin in {FILE.name,"Vandal_Spindrift_Hero_v01.blend"}, origin
    assert not bpy.app.background
    if origin==FILE.name:
        h.build()
    replace_hull(sc)
    OUT.mkdir(parents=True,exist_ok=True)
    report=fit_report(sc)
    (OUT/"fit-check.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    save(sc)
    return {"file":str(FILE),"triangles":report["evaluated_model_triangles_excluding_water_fx"],
            "errors":report["mesh_errors"],"aim":report["stock_sight_rays_hit"]}


def previews(scratch):
    sc=bpy.context.scene
    assert Path(bpy.data.filepath).name==FILE.name and not bpy.app.background
    floor=bpy.data.collections[STAGE].objects["Sweep floor"]
    sc.cycles.samples=22
    render(sc,sc.objects[h.PREFIX+"Hero"],OUT/"Spindrift_Hero.png",1,(1450,780))
    render(sc,sc.objects[h.PREFIX+"Prow"],OUT/"Spindrift_Crest.png",49,(1000,690))
    try:
        floor.hide_render=True
        sc.cycles.samples=16
        for view in ("Side","Hip","ADS"):
            name="Vandal_Cam_"+view
            render(sc,sc.objects[name],scratch/f"fitted_{name}.png",1,(900,506))
    finally:
        floor.hide_render=False
        sc.cycles.samples=24
    save(sc)
