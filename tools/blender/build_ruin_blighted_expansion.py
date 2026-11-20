"""Build isolated Ruin-Blighted Blender sources, renders and flat exports."""

import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ART = ROOT / "art-source/weapons"
sys.path[:0] = [str(ART / "RemasterV2/_Library"), str(HERE / "exotic_concepts"), str(HERE)]
import final_pass as stock
import model_sheet
from export_roblox_flat import CROSSED_LEFT, export_flat
from export_ruin_blighted import GLOW as VANDAL_GLOW, PHASE as VANDAL_PHASE
from scene import armature, beam, bind, camera, collection, framed_camera, glove, locator, loft, marker, material, mesh, points, pose, prism, render, setup

LINE = "RuinBlighted"
COLORS = {"Obsidian":"213039", "Slate":"354D57", "Ridge":"55707A", "Metal":"263439",
          "Fabric":"222725", "Fabric edge":"353F39", "Bronze":"544831", "Bronze edge":"847354",
          "Patina":"364237", "Deep seam":"276A60",
          "Seafoam":"73EDCE"}
PHASE = {"Fore":0, "Receiver":.9, "Stock":2.35, "Mag":1.65, "Sight":.51}
PAL = {}
BOUNDS = {
    # (x heel, x nose, lower z, upper z, shell half-width) for each armor region.
    "Guardian": {"Fore":(1.27,2.32,.245,.421,.091), "Receiver":(-.025,.89,.265,.427,.098),
                 "Stock":(-1.23,-.41,.215,.417,.080), "Mag":(.51,.784,-.191,.17,.063)},
    "Spectre": {"Fore":(.77,1.135,.28,.451,.094), "Receiver":(-.31,.55,.263,.421,.083),
                 "Stock":(-1.055,-.46,.205,.391,.076), "Mag":(.45,.83,-.555,.080,.060)},
    "Operator": {"Fore":(1.22,2.23,.23,.438,.087), "Receiver":(.10,.98,.265,.431,.092),
                  "Stock":(-1.303,-.46,.165,.405,.084), "Mag":(.457,.795,-.08,.157,.061)},
    "Ghost": {"Fore":(1.26,2.02,.239,.373,.096), "Receiver":(-.19,.51,.269,.400,.066),
              "Mag":(-.24,.089,-.449,-.379,.061)},
}
SHAPES = {
    "Guardian":[[(.015,.43),(.23,.88),(.61,1),(.48,.58),(.28,.26)],[(.38,.14),(.63,.60),(.99,.88),(.89,.42),(.69,.04)]],
    "Spectre":[[(.01,.33),(.19,.76),(.54,.93),(.43,.50),(.21,.17)],[(.40,.10),(.72,.68),(.99,.8),(.85,.29),(.65,.04)]],
    "Operator":[[(.01,.36),(.10,.72),(.58,.96),(.48,.61),(.26,.24)],[(.37,.16),(.71,.69),(.99,.79),(.93,.46),(.64,.09)]],
    "Ghost":[[(.01,.20),(.17,.72),(.57,.94),(.48,.48),(.28,.25)],[(.41,.05),(.68,.48),(.99,.76),(.86,.29),(.60,.025)]],
}
# Fore-aft stations: X, lower and upper Z, and shoulder half-width.
CHASSIS = {
    "Guardian": {
        "Receiver": ((-.108,.190,.355,.056),(.012,.143,.391,.076),(.29,.120,.411,.091),
                     (.66,.148,.423,.090),(1.04,.182,.397,.078),(1.19,.239,.356,.064)),
        "Fore": ((1.07,.229,.352,.064),(1.24,.196,.402,.087),(1.65,.176,.423,.090),
                 (1.94,.197,.421,.078),(2.18,.225,.395,.067),(2.37,.299,.390,.045)),
        "Stock": ((-1.245,-.162,.332,.052),(-1.17,-.139,.407,.070),
                  (-.94,-.033,.369,.064),(-.67,.166,.318,.057),(-.42,.231,.349,.066),
                  (-.116,.239,.348,.051)),
        "Barrel": (2.24,.045,.034,.062),
        "Front": (2.24,.4984),
        "Guard": (.084,.569,.154,.059),
    },
    "Spectre": {
        "Receiver": ((-.354,.215,.373,.048),(-.217,.146,.420,.076),(.03,.131,.440,.089),
                     (.34,.150,.426,.082),(.56,.192,.421,.069),(.77,.258,.398,.064)),
        "Fore": ((.65,.247,.389,.065),(.78,.218,.464,.074),(.958,.218,.467,.085),
                 (1.083,.236,.439,.077),(1.205,.282,.402,.061)),
        "Stock": ((-1.061,-.079,.287,.054),(-1.005,-.108,.356,.068),
                  (-.84,-.038,.339,.062),(-.64,.158,.303,.048),(-.495,.227,.326,.060),
                  (-.325,.239,.345,.052)),
        "Barrel": (1.105,.075,.064,.089),
        "Front": (1.015,.5236),
        "Guard": (.047,.496,.151,.051),
    },
    "Operator": {
        "Receiver": ((-.059,.145,.376,.065),(.091,.089,.432,.081),(.33,.101,.442,.101),
                     (.66,.142,.454,.096),(.99,.164,.428,.083),(1.12,.251,.421,.071)),
        "Fore": ((1.015,.238,.434,.071),(1.181,.186,.437,.086),(1.64,.167,.433,.091),
                 (1.94,.182,.424,.088),(2.11,.228,.447,.064),(2.26,.312,.421,.049)),
        "Stock": ((-1.318,-.204,.325,.052),(-1.237,-.181,.403,.076),
                  (-1.01,-.082,.378,.072),(-.735,.041,.342,.064),(-.44,.192,.367,.069),
                  (-.027,.221,.366,.058)),
        "Barrel": (2.195,.052,.044,.081),
        "Guard": (.068,.538,.154,.049),
    },
    "Ghost": {
        "Receiver": ((-.243,.112,.213,.048),(-.085,.096,.232,.063),(.15,.116,.227,.068),
                     (.37,.152,.232,.069),(.65,.168,.234,.064),(.95,.182,.228,.055),(1.103,.193,.222,.040)),
        "Slide": ((-.23,.235,.369,.047),(-.14,.219,.410,.060),(.18,.224,.410,.070),
                  (.49,.239,.391,.068),(.79,.228,.369,.061),(1.117,.238,.341,.047)),
        "Barrel": (1.02,.076,.063,.091),
        "Front": (1.067,.407),
        "Guard": (.191,.691,.172,.031),
    },
}
SIGHT_RADII = {"Guardian": .073, "Spectre": .076}
SIGHT_CUTS = ((-3,30),(40,72),(81,117),(127,163),(173,212),(221,257),(264,311),(321,350))
VANDAL_MASTER = ART / "Skins" / LINE / "Vandal/v05/Vandal_RuinBlighted_v05.blend"
VANDAL_MATERIALS = {
    "Obsidian": "Obsidian", "Slate": "Slate", "Ridge": "Slate", "Metal": "Gunmetal",
    "Fabric": "Grip fabric", "Fabric edge": "Grip folded edge", "Fabric seam": "Grip seam",
    "Deep seam": "Teal recess", "Seafoam": "Teal inlay", "Jade": "Wrap jade",
    "Crest": "Wrap crest", "Mag shell": "Magazine obsidian", "Mag toe": "Magazine fractured toe",
}


def palette(*, guns=False):
    PAL.clear()
    if guns:
        # Bring in the approved shader datablocks, including their viewport finish.
        names = {f"Shadow Mist - {role}" for role in VANDAL_MATERIALS.values()}
        with bpy.data.libraries.load(str(VANDAL_MASTER)) as (reference, working):
            if names - set(reference.materials):
                raise RuntimeError(f"Incomplete Shadow Mist palette: {names - set(reference.materials)}")
            working.materials = sorted(names)
        materials = {name: mat for name,mat in zip(sorted(names), working.materials, strict=True)}
        PAL.update({role: materials[f"Shadow Mist - {name}"] for role,name in VANDAL_MATERIALS.items()})
        return
    for role, color in COLORS.items():
        metal = .5 if role in {"Metal", "Bronze", "Bronze edge"} else .08
        rough = .73 if role.startswith("Fabric") else .53
        PAL[role] = material("Ruin-Blighted / "+role, color, metal, rough,
                             emission=.46 if role=="Seafoam" else 0)


def next_version(item):
    folder = ART / "Skins" / LINE / item
    version = 1
    while (folder / f"v{version:02}").exists():
        version += 1
    dest = folder / f"v{version:02}"
    dest.mkdir(parents=True)
    return dest


def trim(col, name, outline, inner, outer, role, bevel):
    obj = prism(col, name, outline, inner, outer, PAL[role], bevel)
    if role in {"Obsidian", "Slate"}:
        obj.data.materials.append(PAL["Ridge"])
        for f in obj.data.polygons:
            if .20 < f.normal.z < .88 and f.index % 3 == 0:
                f.material_index = 1
    return obj


def position_origin(obj):
    center = sum((v.co for v in obj.data.vertices), Vector()) / len(obj.data.vertices)
    for vertex in obj.data.vertices:
        vertex.co -= center
    obj.location = center
    return center


def magazine_outline(obj, z):
    coords = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    intersections = []
    for edge in obj.data.edges:
        a, b = (coords[index] for index in edge.vertices)
        low, high = sorted((a, b), key=lambda point:point.z)
        if low.z <= z < high.z:
            intersections.append(low.x+(high.x-low.x)*(z-low.z)/(high.z-low.z))
    return min(intersections), max(intersections)


def stone(col, name, outline, inner, outer, role, ridge, *, etched=False):
    """A closed carved plate with a broad ridge and shaded triangular fracture faces."""
    count = len(outline)
    center = sum((Vector(p) for p in outline), Vector((0,0))) / count
    ring = [Vector(p).lerp(center,.11 if index%3 else .22) for index,p in enumerate(outline)]
    peak = center.lerp(ring[ridge % count],.36)
    verts = [(x,inner,z) for x,z in outline]
    verts += [(x,outer,z) for x,z in ring]
    verts += [(peak.x,outer+(outer-inner)*.41,peak.y)]
    faces = [tuple(reversed(range(count)))]
    for index in range(count):
        other = (index+1)%count
        faces += [(index,other,other+count,index+count),(index+count,other+count,2*count)]
    if etched:
        include_rift(verts,faces,count,ridge,outer-inner)
    obj = mesh(col,name,verts,faces,PAL[role])
    for facet in ("Slate","Ridge","Obsidian","Seafoam"):
        obj.data.materials.append(PAL[facet])
    for face in list(obj.data.polygons)[1:]:
        direction = face.normal.z
        face.material_index = (4 if face.index>2*count else 2 if direction>.49
                               else 1 if direction>-.33 and face.index%6<3 else 3 if direction<-.46 else 0)
    return obj


def include_rift(verts, faces, count, ridge, depth):
    """Follow two adjacent stone faces so the luminous seam stays on the moving plate."""
    origin = Vector(verts[2*count])
    joint = Vector(verts[count+ridge%count])
    left = Vector(verts[count+(ridge-1)%count])
    right = Vector(verts[count+(ridge+1)%count])
    stations = (left*.62 + joint*.13 + origin*.25, joint.lerp(origin,.63),
                right*.63 + joint*.10 + origin*.27)
    for i,(a,b,corner) in enumerate(zip(stations,stations[1:],(left,right))):
        face_offset=Vector((0,math.copysign(.0028,depth),0))
        k=len(verts)
        verts.extend((a+face_offset,b+face_offset,
                      b.lerp(corner,.039 if i==0 else .018)+face_offset,
                      a.lerp(corner,.015 if i==0 else .034)+face_offset))
        faces.append((k,k+1,k+2,k+3))


def vein(col, name, path, y, width, role="Seafoam"):
    upper = [(x,z+width*(.24 if i in (0,len(path)-1) else (1 if i%2 else .65)))
             for i,(x,z) in enumerate(path)]
    lower = [(x,z-width*(.24 if i in (0,len(path)-1) else .62))
             for i,(x,z) in enumerate(path)]
    return trim(col,name,upper+lower[::-1],y-math.copysign(.005,y),y,role,0)


def carved_hardware(gun, rig, col, movers, energy):
    checks={}
    if gun=="Operator":
        for side in (-1,1):
            for index,outline in enumerate((
                [(1.14,.588),(1.30,.707),(1.49,.733),(1.573,.657),(1.47,.587)],
                [(-.069,.582),(-.032,.703),(.111,.731),(.217,.648),(.122,.574)],
            )):
                shell=stone(col,f"RB_OpticCarapace_{side}_{index}",outline,side*.119,side*.153,
                            "Obsidian",2,etched=True)
                bind(shell,rig,"Root")
                center=position_origin(shell)
                movers.append((shell,"Root",center,"Receiver",Vector((.05,side,.42)).normalized(),.027))
                center_x=1.36 if index==0 else .051
                energy.append({"name":f"RuinOpticShoulder{side}_{index}","bone":"Root",
                               "point":(center_x,side*.14,.648),"mist":False,"phase":3.15+index*.26})
    if gun in SIGHT_RADII:
        aim=stock.locator(gun,"AimPoint")
        sx,_,sz=aim
        radius=SIGHT_RADII[gun]
        base=trim(col,"RB_RearSightFoot",[(sx-.045,sz-.099),(sx+.037,sz-.099),
                                           (sx+.029,sz-.068),(sx-.025,sz-.061)],-.036,.036,"Metal",.008)
        bind(base,rig,"Root")
        energy.append({"name":"RuinApertureGlow","bone":"Root","point":(sx-.012,0,sz-radius-.009),
                       "region":"Sight","mist":False,"phase":VANDAL_PHASE["Sight"]})

        def radial(r, angle, x):
            theta=math.radians(angle)
            return (x,r*math.cos(theta),sz+r*math.sin(theta))

        for index,(a,b) in enumerate(SIGHT_CUTS):
            mid=(a+b)/2
            inner=radius*.76
            outer=radius*(1.10 if index%3==1 else 1.03)
            section=((outer*.95,a),(outer,mid-3),(outer*.91,b),(inner,b-2),
                     (inner*.97,mid+2),(inner,a+2))
            corners=[radial(r,angle,sx+depth) for depth in (-.010,.012) for r,angle in section]
            n=len(section)
            faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
            faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
            glow_faces=[]
            # Recessed teal rails on the face aimed at the eye. Stay outside the aperture.
            for role,r0,r1,aa,bb in (("Jade",inner*.986,inner*1.094,a+2,b-2),
                                      ("Crest",inner*.995,inner*1.046,a+4,b-3)):
                i=len(corners)
                stations=[(r0,aa),(r0,mid),(r0,bb),(r1,bb-2),(r1,mid+1),(r1,aa+2)]
                corners.extend(radial(r,angle,sx-(.0115 if role=="Jade" else .0123)) for r,angle in stations)
                faces.extend(((i,i+1,i+4,i+5),(i+1,i+2,i+3,i+4)))
                glow_faces.extend((role,role))
            segment=mesh(col,f"RB_RearSight_Fragment_{index+1:02}",corners,faces,PAL["Obsidian"])
            segment.data.materials.append(PAL["Jade"])
            segment.data.materials.append(PAL["Crest"])
            for face,role in zip(list(segment.data.polygons)[n+2:],glow_faces,strict=True):
                face.material_index=1 if role=="Jade" else 2
                if face.normal.x > 0:
                    face.flip()
            segment.data.update()
            center=position_origin(segment)
            t=math.radians(mid)
            movers.append((segment,"Root",center,"Sight",Vector((0,math.cos(t),math.sin(t))),.010))
            bind(segment,rig,"Root")
            checks.setdefault("sight_edges",[]).append(
                (segment.name,radial(inner*1.12,a+.8,sx-.012),radial(inner*1.12,b-.8,sx-.012))
            )
    return checks


def gun_armor(gun, rig, col, original):
    movers = []
    energy = []
    magazine=next(o for o in original if o.parent_bone=="Mag")
    for region, (x0,x1,z0,z1,y0) in BOUNDS[gun].items():
        length,height = x1-x0,z1-z0
        bone = "Mag" if region == "Mag" else "Slide" if gun=="Ghost" and region=="Receiver" else "Root"

        def point(u, v):
            z=z0+v*height
            if region=="Mag":
                z=z0+v*height*.80
                heel,nose=magazine_outline(magazine,z)
                return (heel+(nose-heel)*(.06+.88*u),z)
            return (x0+u*length,z)

        for side in (1,-1):
            suffix = "L" if side==1 else "R"
            if region == "Mag":
                panels = ([ (.02,.04),(.17,.69),(.41,.91),(.50,.51),(.32,.12)],
                          [(.38,.07),(.56,.56),(.96,.90),(.86,.49),(.70,.05)])
                fractures = (((.04,.37),(.24,.34),(.39,.44),(.54,.28),(.91,.35)),
                             ((.09,.60),(.33,.57),(.51,.67),(.64,.53),(.89,.61)))
            else:
                panels = (*SHAPES[gun], [(.05,-.22),(.21,.23),(.45,.20),(.39,-.33),(.22,-.46)])
                fractures = (((.04,.36),(.24,.47),(.46,.39),(.55,.56),(.74,.57),(.93,.76)),
                             ((.24,.09),(.43,.22),(.50,.13),(.68,.24),(.87,.23)))
            for idx,path in enumerate(fractures):
                if gun=="Ghost" and region=="Mag" and idx==1:
                    continue
                trace=[point(u,v) for u,v in path]
                width=max(.003,min(.011,height*.034))
                tag=f"RB_{region}_Rift_{suffix}{idx}"
                if region=="Mag" or (idx==0 and region in {"Fore","Stock"}):
                    sash=vein(col,tag+"_Shadow",trace,side*(y0+.028),width*1.40,"Deep seam")
                    jade=vein(col,tag+"_Jade",trace,side*(y0+.030),width*.92,"Jade")
                    crest=vein(col,tag+"_Crest",trace,side*(y0+.0317),width*.44,"Crest")
                    for layer in (sash,jade,crest):
                        bind(layer,rig,bone)
                elif idx == 0:
                    crack=vein(col,tag,trace,side*(y0+.028),width,"Seafoam")
                    bind(crack,rig,bone)
                else:
                    crack=vein(col,tag,trace,side*(y0+.025),width*.66,"Deep seam")
                    bind(crack,rig,bone)
            for idx,coords in enumerate(panels):
                # The side aimed toward the player gets a differently broken silhouette.
                if gun=="Operator" and region=="Receiver" and side==-1 and idx==0:
                    continue
                xy = [point(u if side==1 else 1-u*.94-.035, v if side==1 else .03+v*.93)
                      for u,v in coords]
                if gun=="Ghost" and region=="Receiver" and idx==2:
                    xy = [point(.56+.39*u, .02+v*.46) for u,v in coords]
                y_inner = y0+(.014 if region=="Mag" else .005+.008*idx)
                y_outer = y0+(.028 if region=="Mag" else .044+.006*idx)
                obj = stone(col,f"RB_{region}_Stone_{suffix}{idx}",xy,side*y_inner,side*y_outer,
                            ("Mag toe" if idx==0 else "Mag shell") if region=="Mag" else "Obsidian",
                            idx+side,etched=idx==1 or idx==0 and region=="Fore")
                center = position_origin(obj)
                if region!="Mag":
                    axis=Vector((.15*(idx-1),side,-.38 if idx==2 else .26)).normalized()
                    travel=(.052,.060,.082)[idx]*(.79 if gun=="Ghost" else 1)
                    movers.append((obj,bone,center,region,axis,travel))
                bind(obj,rig,bone)
            if region!="Mag":
                u = .71 if side==1 else .41
                gap = .13 if length>.7 else .10
                outline = [point(u+a,b) for a,b in [(-gap,.94),(.01,1.16),(gap,1.08),(.044,.84)]]
                obj=stone(col,f"RB_{region}_Chips_{suffix}",outline,side*(y0+.020),side*(y0+.048),"Obsidian",1)
                center=position_origin(obj)
                movers.append((obj,bone,center,region,Vector((.36,side,.59)).normalized(),.087 if gun!='Ghost' else .066))
                bind(obj,rig,bone)
        x,z=point(.68,.57)
        pos = (x,y0+.057,z)
        name = {"Fore":"RuinMistFore","Receiver":"RuinReceiverGlow","Mag":"RuinMagGlow","Stock":"RuinMistHeel"}[region]
        energy.append({"name":name,"bone":bone,"point":pos,"region":region,
                       "mist":True,"phase":VANDAL_PHASE[region]})
        if region!="Mag":
            for side,suffix in ((1,"L"),(-1,"R")):
                origin={"Fore":"LowerFore","Receiver":"Cowl","Stock":"Heel"}[region]
                ax,az=point(.45 if region=="Receiver" else .75,.25)
                energy.append({"name":f"Ruin{origin}{suffix}","bone":bone,
                               "point":(ax,side*(y0+.042),az),"region":region,"mist":False,
                               "phase":VANDAL_PHASE[region]+.27})
                if region=="Stock":
                    cx,cz=point(.86,.75)
                    energy.append({"name":f"RuinCollar{suffix}","bone":bone,
                                   "point":(cx,side*(y0+.009),cz),"region":region,
                                   "mist":True,"phase":VANDAL_PHASE[region]+.49})
    if gun=="Ghost":
        energy.append({"name":"RuinMistHeel","bone":"Slide","point":(-.105,.094,.31),
                       "region":"Stock","mist":True,"phase":PHASE["Stock"]})
    # Tapered fabric banding stays close to the contact envelope.
    grip=next(obj for obj in original if obj.name.endswith("_Grip"))
    corners=[grip.matrix_world@Vector(v) for v in grip.bound_box]
    z0=min(p.z for p in corners)
    for i in range(5):
        z=z0+.048+i*(.049 if gun=="Ghost" else .042)
        heel,nose=magazine_outline(grip,z)
        for side in (-1,1):
            outline=[(heel+.013,z),(nose-.013,z+.025),(nose-.018,z+.050),(heel+.018,z+.023)]
            wrap=trim(col,f"RB_GripWrap_{side}_{i}",outline,side*.055,side*.067,"Fabric",.005)
            bind(wrap,rig,"Root")
            edge=vein(col,f"RB_GripFold_{side}_{i}",[(heel+.022,z+.008),(heel+(nose-heel)*.46,z+.013),
                       (nose-.025,z+.032)],side*.0688,.0029,"Fabric edge")
            bind(edge,rig,"Root")
            if i in {1,3}:
                stitch=vein(col,f"RB_GripSeam_{side}_{i}",[(heel+.038,z+.025),(nose-.029,z+.044)],
                            side*.0686,.0019,"Fabric seam")
                bind(stitch,rig,"Root")
    return movers, energy


def read_scene(gun):
    model_sheet.bind(vars(stock))
    stock.load(gun,5)
    sc=stock.scene(gun)
    bpy.context.window.scene=sc
    stock.rest(gun)
    return sc


def carapace(col, rig, name, stations, bone):
    # Split longitudinal faces into flat facets. The ridge shifts at each step
    # along the shell, leaving narrower shoulders where the armor breaks away.
    section=((.00,1),(.64,.91),(1,.66),(.95,.35),(.58,.10),(.15,0),
             (-.54,.07),(-.97,.29),(-1,.61),(-.62,.90))
    n=len(section)
    vertices=[(x,y*width,low+z*(high-low))
              for x,low,high,width in stations for y,z in section]
    faces=[tuple(reversed(range(n))),tuple(range(len(vertices)-n,len(vertices)))]
    edges=[]
    for k in range(len(stations)-1):
        for i in range(n):
            j=(i+1)%n
            a,b=k*n+i,k*n+j
            c,d=a+n,b+n
            if i in {1,2,7,8}:
                edges.append(len(faces))
                faces.extend(((a,b,d),(a,d,c)))
            else:
                faces.append((a,b,d,c))
    shell=mesh(col,name,vertices,faces,PAL["Obsidian"])
    shell.data.materials.append(PAL["Slate"])
    shell.data.materials.append(PAL["Metal"])
    for i in edges:
        shell.data.polygons[i].material_index=1
    for face in shell.data.polygons:
        if face.index>1 and face.normal.z<-.45:
            face.material_index=2
    bind(shell,rig,bone)
    return shell


def bored_tube(col, rig, name, z, rows, bore, roles, facets=10):
    # A real open faceted shell, with its accent ring built into the surface.
    exterior=[(x,r) for x,r in rows]
    inside=[(rows[-1][0],bore),(rows[0][0],bore)]
    bends=exterior+inside
    verts=[(x,r*math.cos(math.tau*i/facets),z+r*math.sin(math.tau*i/facets))
           for x,r in bends for i in range(facets)]
    faces=[]
    for row in range(len(bends)):
        nxt=(row+1)%len(bends)
        for i in range(facets):
            j=(i+1)%facets
            faces.append((row*facets+i,row*facets+j,nxt*facets+j,nxt*facets+i))
    obj=mesh(col,name,verts,faces,PAL["Obsidian"])
    for role in roles:
        obj.data.materials.append(PAL[role])
    for face in obj.data.polygons:
        layer=face.index//facets
        if layer<len(rows)-1 and layer in roles.values():
            face.material_index=list(roles.values()).index(layer)+1
    bind(obj,rig,"Root")
    return obj


def fitted_handle(col, rig, source, role, name, bookends):
    corners=[source.matrix_world@Vector(v) for v in source.bound_box]
    bottom=min(v.z for v in corners)
    top=max(v.z for v in corners)
    width=max(abs(v.y) for v in corners)
    rings=[]
    for ratio,edge in bookends:
        z=bottom+(top-bottom)*ratio
        lo,hi=magazine_outline(source,z)
        rings.append(((lo+hi)/2,0,z,max(.013,(hi-lo)/2*edge),width*(.65+.35*edge)))
    obj=loft(col,name,rings,8,PAL[role])
    bind(obj,rig,source.parent_bone)
    return obj


def redesign_chassis(gun, rig, col, original, energy):
    kit=CHASSIS[gun]
    source={obj.name.removeprefix(gun+"_"):obj for obj in original}
    for region in ("Receiver","Fore","Stock","Slide"):
        if region in kit:
            carapace(col,rig,"RB_Carved"+region,kit[region],"Slide" if region=="Slide" else "Root")
    grip=source["Grip"]
    clips=((.012,.92),(.10,1),(.39,1),(.66,1),(.88,1),(.98,.88))
    fitted_handle(col,rig,grip,"Fabric","RB_StructuralGrip",clips)
    magazine=next(obj for obj in original if obj.parent_bone=="Mag")
    fitted_handle(col,rig,magazine,"Mag shell","RB_Mag_ChiseledBody",clips)
    # A hollow lower guard runs around the original animated trigger. The
    # attached magazine and the grip reveal the pistol and rifle proportions.
    heel,nose,top,floor=kit["Guard"]
    middle=heel+(nose-heel)*.57
    for name,path in (
        ("Heel",[(heel,top),(heel+.058,top-.017),(heel+.08,floor+.036),
                 (middle,floor+.011),(middle-.019,floor-.008),(heel+.035,floor+.013)]),
        ("Nose",[(middle-.019,floor-.008),(middle,floor+.011),(nose-.071,floor+.030),
                 (nose-.022,top),(nose+.026,top+.021),(nose-.031,floor+.015)]),
    ):
        guard=trim(col,"RB_TriggerBail"+name,path,-.033,.033,"Metal",.006)
        bind(guard,rig,"Root")
    start,collar,neck,crown=kit["Barrel"]
    muzzle=stock.locator(gun,"Muzzle")
    x=muzzle.x
    span=x-start
    rows=[(start,collar*.82),(start+span*.12,collar),(start+span*.23,collar*.98),
          (start+span*.29,neck),(start+span*.66,neck*.89),(start+span*.71,crown*.86),
          (start+span*.775,crown),(start+span*.91,crown),(x-.009,crown*.76),(x,crown*.71)]
    bored_tube(col,rig,"RB_HollowBarrelHousing",muzzle.z,rows,neck*.57,
               {"Metal":0,"Jade":2,"Crest":5,"Slate":7},facets=8)
    energy.append({"name":"RuinMuzzleCollar","bone":"Root","point":(start+span*.71,collar*.88,muzzle.z),
                   "mist":False,"phase":VANDAL_PHASE["Fore"]+.28})
    if "Front" in kit:
        fx,fz=kit["Front"]
        base=muzzle.z+neck*.74 if gun!="Ghost" else .33
        for sign in (-1,1):
            peak=trim(col,f"RB_FrontSightBlade_{sign}",
                      [(fx-.038,base),(fx+.086,base+.012),(fx+.022,fz-.031),
                       (fx-.002,fz+.006),(fx-.021,fz-.026)],
                      sign*.020,sign*.041,"Obsidian",.003)
            bind(peak,rig,"Root")
    if gun=="Operator":
        scope_z=stock.locator(gun,"AimPoint").z
        rows=[(-.086,.128),(-.035,.138),(.145,.136),(.25,.093),(.45,.089),(.56,.118),
              (.672,.12),(.755,.096),(1.05,.098),(1.16,.127),(1.29,.153),(1.51,.152),(1.598,.131)]
        bored_tube(col,rig,"RB_OpticFracturedHousing",scope_z,rows,.073,{"Slate":0,"Jade":4,"Metal":10})
        for x0 in (.21,.92):
            mount=trim(col,"RB_OpticPlinth",[(x0-.067,.403),(x0+.077,.403),(x0+.070,.517),
                        (x0-.047,.539)],-.059,.059,"Metal",.009)
            bind(mount,rig,"Root")
    # The archive keeps the complete stock meshes for direct comparison.
    # Only functional geometry visible in either skin is retained.
    retained={"ScopeLens","CharmLoop","Trigger"}
    for name,obj in source.items():
        if name not in retained:
            obj.hide_set(True)
            obj.hide_render=True
    return [name for name in source if name not in retained]


def get_views(gun, coord):
    views = {}
    for name, direction, up in (
        ("hero",(.55,.78,.34),(0,0,1)), ("side",(0,1,0),(0,0,1)),
        ("opposite",(-.25,-1,-.31),(0,0,1)), ("held",(-.85,.34,.30),(0,0,1)),
        ("top",(0,0,1),(0,-1,0)),
    ):
        cam,_,_ = model_sheet._cam(gun,"Ruin_"+name,coord,direction,up_hint=up,ortho=name in {"side","top"},margin=1.1)
        views[name]=cam
    if gun in stock.ADS:
        views["aim"]=stock.ads_cam(gun)
    elif gun=="Operator":
        a=stock.locator(gun,"AimPoint")
        eye=a-Vector((.3,0,0))
        views["aim"]=stock.camera(gun,"ScopeEntry",eye,a,fov_v=58,clip=.08)
    return views


def check_aim(scene, gun, addon, aim_camera):
    aim = stock.locator(gun,"AimPoint")
    if aim is None or aim_camera is None:
        return {"stock_aim":False}
    eye=aim_camera.matrix_world.translation
    direction=aim-eye
    limit=max(direction.length, .15)
    direct=direction.normalized()
    forward=Vector((1,0,0)) if direct.x>=0 else Vector((-1,0,0))
    touched=[]
    for obj in addon:
        verts=[obj.matrix_world@v.co for v in obj.data.vertices]
        tree=BVHTree.FromPolygons(verts,[tuple(p.vertices) for p in obj.data.polygons])
        if (tree.ray_cast(eye,direct,limit)[0] is not None
            or tree.ray_cast(aim,forward,stock.locator(gun,"Muzzle").x-aim.x)[0] is not None):
            touched.append(obj.name)
    if touched:
        raise RuntimeError(f"{gun} center sight ray hit {touched}")
    return {"stock_aim":gun in stock.ADS,"center_ray_new_hits":touched,"camera":aim_camera.name,
            "scope_axis_fixture":gun=="Operator"}


def rig_shards(rig, movers):
    joints = []
    poses = [obj.matrix_world.copy() for obj,*_ in movers]
    if movers:
        bpy.context.view_layer.objects.active=rig
        rig.hide_set(False)
        rig.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bones=rig.data.edit_bones
        names = [f"Ruin{'Sight' if area=='Sight' else 'Shard'}_{i:02}"
                 for i,(_,_,_,area,_,_) in enumerate(movers,1)]
        for name,(_,parent,center,_,_,_) in zip(names,movers):
            joint=bones.new(name)
            joint.parent=bones[parent]
            matrix=joint.parent.matrix.copy()
            matrix.translation=rig.matrix_world.inverted()@center
            joint.matrix=matrix
            joint.length=.08
        bpy.ops.object.mode_set(mode="OBJECT")
        for i, (name,(obj,parent,center,area,axis,travel),world) in enumerate(zip(names,movers,poses),1):
            obj.parent_bone=name
            bpy.context.view_layer.update()
            obj.matrix_world=world
            basis=rig.data.bones[parent].matrix_local
            pivot=(rig.matrix_world@basis).inverted()@center
            local_axis=(rig.matrix_world@basis).inverted().to_3x3()@axis
            sight=area=="Sight"
            chip="Chips" in obj.name
            joints.append({"name":name,"parent":parent,"c0":[*pivot,1,0,0,0,1,0,0,0,1],
                          "axis":list(local_axis.normalized()),"phase":VANDAL_PHASE.get(area,0)+
                          (int(obj.name.rsplit("_",1)[1])*.7854 if sight else i*.31),
                          "travel":travel,"tilt":.023 if sight else .11 if chip else .05,
                          "tether":area in {"Fore","Receiver","Stock"} and
                          ("_Stone_" in obj.name and obj.name.endswith("0") or "_StockHeel_" in obj.name and obj.name.endswith("_1")),
                          "region":area,"source":obj.name})
    bpy.context.view_layer.update()
    return joints


def export_variant(item, dest, rig, objects, replaced, movers, energy, *, skin_item=None, joints=None):
    if joints is None:
        joints=rig_shards(rig,movers)
    if not skin_item:
        moving_roles={joint["name"]:joint["region"] for joint in joints}
        scoped_materials={}
        for obj in objects:
            area=moving_roles.get(obj.parent_bone)
            if not area:
                area=next((key for key in ("Fore","Stock","Mag") if obj.name.startswith("RB_"+key)),None)
                area=area or ("Sight" if obj.name.startswith("RB_Optic") else "Receiver")
            for slot in obj.material_slots:
                if not slot.material:
                    continue
                role=slot.material.name.removeprefix("Shadow Mist - ").split(".")[0]
                if role in VANDAL_GLOW:
                    key=(area,role)
                    if key not in scoped_materials:
                        copy=slot.material.copy()
                        copy.name=f"Ruin glow {area} {role}"
                        scoped_materials[key]=copy
                    slot.material=scoped_materials[key]
    fbx,parts=export_flat(objects,str(dest),"Knife" if skin_item else item,LINE)
    if CROSSED_LEFT:
        raise RuntimeError(CROSSED_LEFT)
    result={}
    for name,spec in parts.items():
        material_name=spec["blender_material"]
        role=material_name.removeprefix("Ruin-Blighted / " if skin_item else "Shadow Mist - ").split(".")[0]
        part={"b":spec["bone"],"c":spec["center"],"s":spec["size"],
              "col":spec["color"],"mat":spec["material"],"refl":spec["reflectance"],"tris":spec["triangles"]}
        if skin_item:
            part["col"]=COLORS.get(role,spec["color"])
            if role=="Seafoam":
                part.update(mat="Neon",glow=.65,glowMix=.7)
            elif role in {"Obsidian","Slate"}:
                part["mat"]="Slate"
            elif role.startswith("Fabric"):
                part["mat"]="Fabric"
        elif material_name.startswith("Ruin glow "):
            _,_,area,role=material_name.split(" ",3)
            part.update(col=VANDAL_GLOW[role],mat="Neon",
                        glow=VANDAL_PHASE[area]+(.32 if role=="Wrap jade" else 0),
                        glowMix={"Wrap jade":.43,"Teal inlay":.82,"Wrap crest":1.0}[role])
        elif role.startswith("Grip "):
            part["mat"]="Fabric"
        elif role.startswith("Magazine "):
            part["mat"]="Slate"
        result[name]=part
    data={"line":LINE,"gun":"Knife" if skin_item else item,"version":dest.name,
          "file":Path(fbx).name,"parts":result,"replaced":dict.fromkeys(replaced,True),
          "joints":joints,"energy":energy}
    if skin_item:
        data["skinItem"] = skin_item
    (dest/"manifest_flat.json").write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
    return len(result),sum(v["tris"] for v in result.values())


def build_gun(gun):
    dest=next_version(gun)
    sc=read_scene(gun)
    setup(sc)
    palette(guns=True)
    rig=bpy.data.objects[gun+"_Rig"]
    rig.data.pose_position="REST"
    sc.view_layers[0].update()
    original=stock.meshes(gun)
    coord=points(original)
    views=get_views(gun,coord)
    render(sc,views["side"],dest/"review/stock_side.png",1,(1120,580))
    render(sc,views["held"],dest/"review/stock_held.png",1,(1120,650))
    if "aim" in views:
        render(sc,views["aim"],dest/"review/stock_aim.png",1,(900,506))
    col=collection(sc,"Ruin-Blighted | Shadow Mist")
    movers,energy=gun_armor(gun,rig,col,original)
    replaced=redesign_chassis(gun,rig,col,original,energy)
    hardware=carved_hardware(gun,rig,col,movers,energy)
    addon=list(col.objects)
    sc.view_layers[0].update()
    checks=check_aim(sc,gun,addon,views.get("aim"))
    checks.update(hardware)
    joints=rig_shards(rig,movers)
    by_source={j["source"]:j["name"] for j in joints}
    for name,first,last in checks.pop("sight_edges",[]):
        for edge,point in (("RuinSightStart",first),("RuinSightEnd",last)):
            energy.append({"name":edge,"bone":by_source[name],"point":point,"mist":False})
    for spec in energy:
        socket=locator(col,spec["name"],spec["point"])
        bind(socket,rig,spec["bone"])
    for view,cam in views.items():
        render(sc,cam,dest/"review"/(view+".png"),1,(1120,630))
    sc.camera=views["hero"]
    rig.data.pose_position="POSE"
    sc.name="Ruin-Blighted "+gun
    bpy.ops.wm.save_as_mainfile(filepath=str(dest/f"{gun}_{LINE}_{dest.name}.blend"))
    rig.data.pose_position="REST"
    sc.view_layers[0].update()
    count,tris=export_variant(gun,dest,rig,addon,replaced,movers,energy,joints=joints)
    checks.update(parts=count,triangles=tris,shards=len(movers),
                  stock_source=gun+"_RemasterV2_v05.blend", stock_shell_meshes_replaced=replaced)
    (dest/"review/checks.json").write_text(json.dumps(checks,indent=2)+"\n",encoding="utf-8")
    print("RUIN_GUN_READY",gun,str(dest),flush=True)


SWORD_PIECES = (
    ("Heel",[(.71,-.105),(1.08,-.203),(1.60,-.253),(1.88,-.243),(1.76,-.154),
             (1.94,-.075),(1.72,.027),(1.85,.105),(1.63,.209),(1.12,.205),(.74,.101)]),
    ("Edge",[(1.92,-.245),(2.26,-.25),(2.57,-.212),(2.69,-.179),(2.58,-.105),
             (2.36,-.133),(2.27,-.06),(2.02,-.051),(1.80,-.157)]),
    ("Spine",[(1.69,.222),(2.10,.263),(2.49,.232),(2.81,.18),(2.62,.107),
              (2.43,.099),(2.29,.047),(2.06,.071),(1.89,.127)]),
    ("Point",[(2.72,-.199),(3.06,-.175),(3.52,-.106),(3.94,.035),(3.55,.122),
              (3.10,.172),(2.87,.18),(2.69,.101),(2.80,.052),(2.59,-.019),(2.78,-.087)]),
    ("SplinterTop",[(1.59,.29),(1.79,.361),(1.94,.327),(1.80,.281)]),
    ("SplinterLow",[(2.01,-.293),(2.23,-.351),(2.39,-.312),(2.21,-.286)]),
    ("SplinterNose",[(2.82,.219),(3.00,.279),(3.13,.243),(2.99,.21)]),
    ("Keystone",[(1.98,-.032),(2.21,-.043),(2.34,-.097),(2.49,-.036),(2.55,.034),
                 (2.33,.029),(2.10,.045)]),
)

REAVER_RIFT = ((1.40,-.025),(1.69,-.038),(1.86,-.018),(1.96,-.054),
               (2.16,-.015),(2.28,-.084),(2.41,-.061),(2.54,-.034),
               (2.66,.019),(2.77,.012),(2.91,.054))


def blade_piece(col, piece, outline, index):
    center = sum((Vector(point) for point in outline), Vector((0,0))) / len(outline)
    inset = [Vector(point).lerp(center, .15) for point in outline]
    span = len(outline)
    heel = min(x for x,_ in outline)
    nose = max(x for x,_ in outline)
    depth = .052 if index<4 else .024 if piece=="Keystone" else .018

    def face_depth(x):
        travel = (x - heel) / (nose - heel)
        return depth * (1 - travel * (.64 if piece == "Point" else .17))

    verts = [(x,0,z) for x,z in outline]
    faces = []
    plates = []
    etch = []
    for sign in (-1,1):
        start = len(verts)
        verts.extend((v.x, sign * face_depth(v.x), v.y) for v in inset)
        for i in range(span):
            j=(i+1)%span
            faces.append((i,j,start+j,start+i))
        plates.append(len(faces))
        faces.append(tuple(range(start, start + span)))
        if piece in {"Heel","Edge","Spine","Point"}:
            teeth={"Heel":(4,5,6), "Edge":(4,5,6), "Spine":(4,5,6), "Point":(7,8,9)}[piece]
            trace=[inset[i].lerp(center, blend) for i,blend in zip(teeth,(.21,.31,.13))]
            for i,(p,q) in enumerate(zip(trace, trace[1:])):
                taper=.0035 if i==0 else .0065
                k=len(verts)
                verts.extend((v.x,sign*(face_depth(v.x)+.0017),v.y+w)
                             for v,w in ((p,0),(q,0),(q,taper),(p,taper*.5)))
                etch.append((k,k+1,k+2,k+3))
    face_count=len(faces)
    faces.extend(etch)
    obj=mesh(col,"RB_Reaver_"+piece,verts,faces,PAL["Obsidian"])
    for tone in ("Slate","Ridge","Seafoam"):
        obj.data.materials.append(PAL[tone])
    for face in obj.data.polygons:
        if face.index>=face_count:
            face.material_index=3
        elif face.index not in plates:
            face.material_index=2 if face.normal.z>.58 else 1
    return obj, (center.x,0,center.y)


def reaver_guard(col, shade):
    hook=[(.48,.026),(.49,.152),(.45,.244),(.47,.32),(.55,.386),(.69,.43),
          (.91,.455),(.773,.373),(.66,.313),(.618,.248),(.649,.188),(.78,.131),
          (.85,.063),(.735,.024)]
    if shade<0:
        hook=[(x+.028,z*-.91) for x,z in reversed(hook)]
    name = "Upper" if shade>0 else "Lower"
    guard=trim(col,"RB_Reaver_BronzeGuard_"+name,hook,-.071,.071,"Bronze",.016)
    paths = [
        ("OuterLip",[(.519,.097),(.553,.202),(.517,.281),(.591,.355),(.700,.396),(.812,.429)],.0047,"Bronze edge"),
        ("InnerCut",[(.568,.118),(.589,.197),(.566,.274),(.608,.318),(.688,.357),(.757,.389)],.0060,"Patina"),
        ("RootRib",[(.552,.107),(.607,.139),(.651,.139),(.716,.102),(.757,.072)],.0055,"Bronze edge"),
        ("CarvedNotch",[(.618,.235),(.589,.246),(.566,.231),(.574,.204),(.610,.186),(.637,.185)],.0040,"Bronze edge"),
    ]
    detail = []
    for label, path, width, role in paths:
        if shade < 0:
            path = [(x+.028,z*-.91) for x,z in path]
        for face in (-1,1):
            detail.append(vein(col,f"RB_Reaver_{label}_{name}_{face}",path,face*.074,width,role))
    return [guard,*detail]

SWORD_MOTION = {
    "Draw": [(0,(-.40,0,-.50),(0,36,-15),1),(.33,(-.15,0,-.12),(8,-25,20),.88),(.68,(0,0,.03),(2,5,-7),0),(1.05,(0,0,0),(0,0,0),0)],
    "Idle": [(0,(0,0,0),(0,0,0),.035),(1.28,(0,0,.032),(0,2,-1),.10),(2.6,(0,0,0),(0,0,0),.035)],
    "Carry": [(0,(0,0,0),(0,0,0),0),(.24,(-.07,0,-.22),(-3,20,5),.03),(.60,(-.15,0,-.26),(-4,22,8),.02)],
    "TipPlant": [(0,(0,0,0),(0,0,0),.025),(.38,(0,0,.18),(4,49,-12),.12),(.68,(.05,0,-.27),(6,64,-12),.24),(1.23,(0,0,-.12),(6,55,-12),.1),(1.9,(0,0,0),(0,0,0),.025)],
    "Light1": [(0,(0,0,0),(0,0,0),0),(.09,(-.12,.15,.04),(-10,-13,42),.11),(.168,(.15,0,.03),(3,-6,-20),.16),(.31,(.03,-.25,-.04),(10,-3,-53),.12),(.55,(0,0,0),(0,0,0),0)],
    "Light2": [(0,(0,0,0),(0,0,0),0),(.11,(-.08,-.17,.08),(8,-14,-43),.09),(.231,(.17,0,.04),(-4,2,23),.17),(.32,(.04,.18,.03),(-10,7,55),.12),(.51,(0,0,0),(0,0,0),0)],
    "Light3": [(0,(0,0,0),(0,0,0),0),(.16,(-.13,0,.30),(0,-54,3),.12),(.29,(.18,0,.16),(0,12,1),.24),(.39,(.26,0,-.24),(1,35,0),.29),(.73,(0,0,0),(0,0,0),0)],
    "Heavy": [(0,(0,0,0),(0,0,0),0),(.17,(-.59,0,.22),(-4,-10,5),.60),(.30,(.99,0,.03),(0,0,0),.54),(.42,(.43,0,.02),(0,2,0),.22),(.88,(0,0,0),(0,0,0),0)],
    "Inspect": [(0,(0,0,0),(0,0,0),0),(.55,(-.38,.15,.20),(10,-18,58),.07),(1.28,(-.52,.13,.30),(15,-7,66),1),(2.76,(-.45,.16,.24),(7,-11,61),1),(3.25,(-.37,.12,.19),(7,-18,53),0),(3.82,(0,0,0),(0,0,0),0)],
    "Cancel": [(0,(-.37,.12,.19),(7,-18,53),.70),(.26,(0,0,0),(0,0,0),0)],
}


def sword_actions(rig, pieces):
    sc=bpy.context.scene
    axes = {}
    for i,name in enumerate(pieces):
        axes[name]=Vector((.17 if name in {"Point","Spine"} else -.15, .85*(-1 if i%2 else 1), .44*(-1 if "Low" in name or name=="Edge" else 1))).normalized()
    for name, keys in SWORD_MOTION.items():
        rig.animation_data_create().action=None
        for moment,offset,angles,amount in keys:
            frame=1+round(moment*30)
            pose(rig.pose.bones["Root"],frame,xyz=offset,angles=angles)
            for i,(piece,axis) in enumerate(axes.items()):
                spread=.30*amount
                if name=="Draw" and moment<.7:
                    spread+=.38*amount
                pulse=axis*spread
                if name=="Heavy" and .27<moment<.47:
                    pulse.x+=.64*amount*(.5+i*.085)
                pose(rig.pose.bones[piece],frame,xyz=pulse,
                     angles=(amount*(i%3-1)*9,amount*(i%2)*12,amount*(2-i%4)*7))
        action=rig.animation_data.action
        action.name="RuinedReaver_"+name
        action.use_fake_user=True
        rig.animation_data.action=None
    for name, seconds in (("Draw lock",.68),("Light1 contact",.168),("Light2 contact",.231),("Light3 contact",.29),
                          ("Heavy charge completes",.17),("Heavy contact",.30),("Heavy ready",.88),
                          ("Inspect maximum spread",1.28),("Inspect lock",3.25)):
        marker(sc,name,1+round(seconds*30))


def build_sword():
    dest=next_version("RuinedReaver")
    sc=read_scene("Knife")
    setup(sc)
    sc.render.fps=30
    palette()
    base=stock.meshes("Knife")
    for obj in base:
        obj.hide_render=True
    hide=[obj.name.removeprefix("Knife_") for obj in base]
    col=collection(sc,"Ruined Reaver | Model")
    cams=collection(sc,"Ruined Reaver | Review cameras")

    hilt=[
        beam(col,"RB_Reaver_WrappedGrip",(-.68,0,0),(.59,0,0),.064,PAL["Fabric"],8,taper=.98),
        beam(col,"RB_Reaver_Tang",(-.66,0,0),(.98,0,0),.048,PAL["Metal"],8),
        trim(col,"RB_Reaver_PommelSeat",[(-.731,-.069),(-.654,-.085),(-.597,-.057),
                                        (-.597,.059),(-.654,.086),(-.731,.070)],-.069,.069,"Bronze",.010),
    ]
    for side in (-1,1):
        upper=[(-.87,.006),(-.822,.101),(-.727,.121),(-.653,.069),(-.672,.019),(-.757,.032)]
        lower=[(-.875,-.012),(-.829,-.089),(-.744,-.116),(-.671,-.071),(-.689,-.015),(-.763,-.034)]
        hilt.extend((trim(col,f"RB_Reaver_PommelUpper_{side}",upper,0,side*.077,"Obsidian",.011),
                     trim(col,f"RB_Reaver_PommelLower_{side}",lower,0,side*.074,"Obsidian",.010),
                     trim(col,f"RB_Reaver_PommelFacet_{side}",[(-.839,-.054),(-.799,-.081),
                          (-.746,-.094),(-.763,-.059),(-.796,-.035)],side*.067,side*.079,"Slate",.005),
                     vein(col,f"RB_Reaver_PommelRift_{side}",[(-.865,-.003),(-.795,-.018),
                          (-.768,-.011),(-.735,.019),(-.695,.009)],side*.070,.0065),
                     vein(col,f"RB_Reaver_PommelRiftFork_{side}",[(-.768,-.011),(-.749,-.042),
                          (-.727,-.056)],side*.076,.0035)))
    for x in (-.568,.507):
        hilt.append(beam(col,"RB_Reaver_OxidizedCollar",(x-.016,0,0),(x+.016,0,0),.076,PAL["Patina"],10))
    for index in range(15):
        x=-.585+index*.075
        sides=10
        width=.039 + .003*math.sin(index*2.1)
        radius=.073 + .003*math.cos(index*.85)
        coords=[]
        for end,rim in ((-width,.069),(-width*.63,radius),(width*.75,radius-.001),(width,.068)):
            for i in range(sides):
                angle=math.tau*i/sides
                coords.append((x+end+.025*math.cos(angle),rim*math.sin(angle),rim*math.cos(angle)))
        faces=[(row*sides+i,row*sides+(i+1)%sides,(row+1)*sides+(i+1)%sides,(row+1)*sides+i)
               for row in range(3) for i in range(sides)]
        wrap=mesh(col,f"RB_Reaver_GripBand_{index:02}",coords,faces,PAL["Fabric"])
        wrap.data.materials.append(PAL["Fabric edge"])
        for face in wrap.data.polygons:
            if face.index < sides:
                face.material_index=1
        hilt.append(wrap)
    for index,(x,y,span) in enumerate(((.36,.046,.196),(.28,-.048,.151))):
        outline=[(x-.037,-.047),(x+.031,-.059),(x+.014,-.115),(x-.028,-span),
                 (x-.034,-span*.74),(x-.054,-span*.90),(x-.031,-.107)]
        hilt.append(trim(col,f"RB_Reaver_FrayedWrap_{index}",outline,y*.93,y,"Fabric",.006))
    hilt.extend(reaver_guard(col,1))
    hilt.extend(reaver_guard(col,-1))
    for side in (-1,1):
        hilt.append(trim(col,f"RB_Reaver_ObsidianSeat_{side}",[(.45,-.061),(.632,-.119),(.86,-.096),
                         (1.02,0),(.86,.092),(.634,.116),(.45,.061)],side*.034,side*.068,"Obsidian",.012))
        hilt.append(vein(col,f"RB_Reaver_SeatSeal_{side}",[(.505,-.022),(.655,-.057),(.748,-.029),
                          (.838,-.039),(.94,-.012)],side*.071,.005,"Bronze edge"))
        hilt.append(vein(col,f"RB_Reaver_FerruleDetail_{side}",[(.581,.019),(.665,.052),(.748,.050),
                          (.787,.012),(.829,.027),(.894,.012)],side*.071,.004,"Bronze edge"))
        hilt.append(vein(col,f"RB_Reaver_FerruleSeam_{side}",[(.764,.006),(.806,-.015),(.846,-.006),
                          (.895,-.018),(.939,-.007)],side*.072,.004,"Deep seam"))
    meshes_by_piece={}
    origins={}
    for i,(piece,outline) in enumerate(SWORD_PIECES):
        plate,origins[piece]=blade_piece(col,piece,outline,i)
        meshes_by_piece[piece]=[plate]
    bridges=[]
    branches=[((1.73,-.033),(1.78,-.086),(1.84,-.131),(1.93,-.174)),
              ((1.91,-.046),(1.85,.021),(1.94,.079),(2.04,.147)),
              ((2.37,-.067),(2.48,-.115),(2.58,-.145),(2.68,-.143)),
              ((2.64,.01),(2.65,.069),(2.76,.102),(2.86,.142))]
    for side in (-1,1):
        bridges.extend((vein(col,f"RB_Reaver_RiftBase_{side}",REAVER_RIFT,side*.018,.021,"Deep seam"),
                       vein(col,f"RB_Reaver_RiftCore_{side}",REAVER_RIFT,side*.022,.0085)))
        for i,path in enumerate(branches):
            bridges.append(vein(col,f"RB_Reaver_RiftBranch_{side}_{i}",path,side*.025,.0055))
    for name,position in (("RightGrip",(.22,0,0)),("LeftGrip",(-.34,0,0)),("TrailBase",(.91,0,0)),("TrailTip",(3.82,0,.01)),
                          ("MistHilt",(.66,0,.14)),("BladeImpact",(3.76,0,.018))):
        locator(col,"Reaver_"+name,position)
    layout=[("Root",(0,0,0),None),("RightHand",(.22,0,0),"Root"),("LeftHand",(-.34,0,0),"Root")]
    layout += [(name,origin,"Root") for name,origin in origins.items()]
    rig=armature(col,"Ruined Reaver | Motion rig",layout)
    for obj in hilt+bridges:
        bind(obj,rig,"Root")
    for name,parts in meshes_by_piece.items():
        for obj in parts:
            bind(obj,rig,name)
    for obj in list(col.objects):
        if obj.type=="EMPTY":
            bind(obj,rig,"Root")
    sc.view_layers[0].update()
    authored=hilt+bridges+[o for parts in meshes_by_piece.values() for o in parts]
    sword_points=points(authored)
    blade_points=points([o for parts in meshes_by_piece.values() for o in parts])
    blade_depth=max(p.y for p in blade_points)-min(p.y for p in blade_points)
    blade_span=max(p.z for p in blade_points)-min(p.z for p in blade_points)
    length=max(p.x for p in sword_points)-min(p.x for p in sword_points)
    if not 4.5<=length<=5:
        raise RuntimeError(f"Reaver length {length}")
    camera_views={
        "hero":framed_camera(cams,"Reaver hero",sword_points,(.35,.80,.28),1.78,1.12),
        "side":framed_camera(cams,"Reaver side",sword_points,(0,1,0),1.78,1.12),
        "opposite":framed_camera(cams,"Reaver reverse",sword_points,(-.20,-.83,.32),1.78,1.12),
        "edge":camera(cams,"Reaver edge",(min(p.x for p in sword_points)+length/2,0,0),
                      (0,0,1),scale=length*1.15),
        "held":camera(cams,"Reaver held camera",(.78,.09,.13),(-.85,.45,.29),distance=2.73,lens=19,clip=.10),
    }
    camera_views["edge"].rotation_euler=(0,0,0)
    sword_actions(rig,origins)
    render(sc,camera_views["hero"],dest/"review/hero.png",1,(1440,810))
    render(sc,camera_views["side"],dest/"review/side.png",1,(1440,600))
    render(sc,camera_views["opposite"],dest/"review/opposite.png",1,(1200,675))
    render(sc,camera_views["edge"],dest/"review/edge.png",1,(1440,515))
    hands=collection(sc,"Ruined Reaver | R15-scale grip proxies")
    for hand,xyz,side in (("Primary",(.22,0,0),1),("Support",(-.34,0,0),-1)):
        for obj in glove(hands,hand,xyz,left=side==-1,size=.82):
            bind(obj,rig,"RightHand" if hand=="Primary" else "LeftHand")
    for name,idx in (("Draw",1),("Idle",0),("TipPlant",2),("Light1",2),("Light2",2),("Light3",3),("Heavy",2),("Inspect",2),("Cancel",1)):
        rig.animation_data.action=bpy.data.actions["RuinedReaver_"+name]
        f=1+round(SWORD_MOTION[name][idx][0]*30)
        render(sc,camera_views["held"],dest/f"review/{name}.png",f,(960,540))
    rig.animation_data.action=None
    sc.frame_set(1)
    sc.camera=camera_views["hero"]
    hands.hide_render=True
    bpy.ops.wm.save_as_mainfile(filepath=str(dest/f"RuinedReaver_{LINE}_{dest.name}.blend"))
    # Use the stock Knife root axes when preparing the install manifest.
    base_rig=bpy.data.objects["Knife_Rig"]
    base_rig.data.pose_position="REST"
    moving=[]
    for obj in authored:
        world=obj.matrix_world.copy()
        bone=obj.parent_bone
        bind(obj,base_rig,"Root")
        obj.matrix_world=world
        if bone in origins and obj.name=="RB_Reaver_"+bone:
            moving.append((obj,"Root",Vector(origins[bone]),"Receiver",Vector((.2,.8,0)),.035))
    links=[("Heel","Edge",(1.78,.015,-.147),(1.93,.014,-.175)),
           ("Heel","Spine",(1.79,.014,.107),(2.01,.013,.120)),
           ("Spine","Point",(2.65,.014,.118),(2.86,.012,.118)),
           ("Edge","Point",(2.58,.014,-.133),(2.81,.013,-.118))]
    bone_by_piece={name:f"RuinShard_{i:02}" for i,(name,_) in enumerate(SWORD_PIECES,1)}
    energy=[]
    for index,(a,b,first,second) in enumerate(links,1):
        for suffix,piece,point in (("A",a,first),("B",b,second)):
            energy.append({"name":f"RuinBladeLink{index}{suffix}","bone":bone_by_piece[piece],
                           "point":point,"mist":False,"phase":index*.27})
    count,tris=export_variant("RuinedReaver",dest,base_rig,authored,hide,moving,energy,skin_item="RuinedReaver")
    metadata={"length_studs":round(length,3),"blade_depth":round(blade_depth,3),
              "blade_span":round(blade_span,3),"parts":count,"triangles":tris,
              "includes_pose_proxies":True,"actions":SWORD_MOTION,
              "note":"Blender weapon actions and grip proxies. R15 animation and integration require a Studio check."}
    (dest/"review/checks.json").write_text(json.dumps(metadata,indent=2)+"\n",encoding="utf-8")
    print("RUIN_REAVER_READY",str(dest),flush=True)


def build_ammo():
    dest=next_version("AmmoStudy")
    sc=bpy.context.scene
    for obj in list(sc.objects):
        bpy.data.objects.remove(obj,do_unlink=True)
    setup(sc)
    palette()
    col=collection(sc,"Ruin-Blighted | Cosmetic ammunition study")
    cams=collection(sc,"Ammunition | Review cameras")
    for x,label,height in ((0,"Ghost",.65),(.9,"Spectre",.83),(1.8,"Vandal",1.03),(2.7,"Guardian",1.21),(3.6,"Operator",1.39)):
        # Visual proportions for an enlarged game concept render.
        shell=[(x,0,height*t,r,r) for t,r in [(0,.145),(.055,.172),(.14,.169),(.58,.146),(.74,.092),(.79,.079)]]
        tip=[(x,0,height*t,r,r) for t,r in [(.737,.091),(.83,.088),(.92,.061),(1,.018)]]
        seam=[(x,0,height*t,r,r) for t,r in [(.124,.172),(.155,.172),(.196,.165)]]
        loft(col,label+" / obsidian cartridge body",shell,8,PAL["Obsidian"])
        loft(col,label+" / faceted tip",tip,8,PAL["Slate"])
        loft(col,label+" / seafoam heel band",seam,8,PAL["Seafoam"])
        for phase in (0,2,4,6):
            angle=(phase+.5)*math.tau/8
            side_x,side_y=math.cos(angle),math.sin(angle)
            a=Vector((x+side_x*.151,side_y*.151,height*.42))
            b=Vector((x+side_x*.146,side_y*.146,height*.56))
            beam(col,label+f" / narrow vein {phase}",a,b,.010,PAL["Deep seam"],5)
    coord=points(col.objects)
    for name,direction in (("hero",(.13,-.80,.38)),("side",(0,-1,0))):
        cam=framed_camera(cams,"Cartridges "+name,coord,direction,2.5,1.10)
        render(sc,cam,dest/f"review/{name}.png",1,(1500,600))
    bpy.ops.wm.save_as_mainfile(filepath=str(dest/f"AmmoStudy_{LINE}_{dest.name}.blend"))
    print("RUIN_AMMO_READY",str(dest),flush=True)


def main():
    job=sys.argv[sys.argv.index("--")+1]
    if job in BOUNDS:
        build_gun(job)
    elif job=="RuinedReaver":
        build_sword()
    elif job=="AmmoStudy":
        build_ammo()
    else:
        raise SystemExit("Unknown item: "+job)


if __name__=="__main__":
    main()
