"""Storm Shadow artist master. Start with the stock game meshes and rebuild the finish."""
import math
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sculpt_tempest_strike import Workshop, GRIP_SECTIONS, MAG_SECTIONS, color, fitted_profile


def clean_donor(work, name, source_name, group, parent, shades, deform=None, width=.0022,
                filter_islands=None, dissolve=True):
    """Use the stock closed topology as the cage and preserve its installation envelope."""
    src = work.stock.objects[source_name]
    matrix = work.stock_matrices[source_name]
    points = [matrix @ v.co for v in src.data.vertices]
    faces = [tuple(f.vertices) for f in src.data.polygons]
    material_ids = [shades.get(src.data.materials[f.material_index].name, 0) for f in src.data.polygons]
    mats = [work.coal,work.ceramic,work.well,work.steel,work.rubber,work.silver,work.blue]
    if filter_islands:
        faces, material_ids = filter_islands(src.data, points, faces, material_ids)
    if deform:
        points = [deform(p.copy()) for p in points]
    obj = work.mesh(name,points,faces,mats,group,parent,material_ids)
    data=obj.data
    cage=bmesh.new()
    cage.from_mesh(data)
    # Rejoin the stock triangulated planes so Blender's native edge tools
    # work from real borders. Preserve material and UV transitions.
    if dissolve:
        bmesh.ops.dissolve_limit(cage,angle_limit=math.radians(1.0),
            verts=list(cage.verts),edges=list(cage.edges),delimit={"MATERIAL"})
    spare=[v for v in cage.verts if not v.link_faces]
    if spare:
        bmesh.ops.delete(cage,geom=spare,context="VERTS")
    bmesh.ops.recalc_face_normals(cage,faces=list(cage.faces))
    cage.to_mesh(data)
    cage.free()
    if width:
        chamfer(obj,width,3)
    obj["fit_source"]=source_name
    return obj


def chamfer(obj, width, segments=3, angle=37):
    for face in obj.data.polygons:
        face.use_smooth=True
    mod=obj.modifiers.new("Machined support edges","BEVEL")
    mod.width,mod.segments=width,segments
    mod.limit_method="ANGLE"
    mod.angle_limit=math.radians(angle)
    mod.harden_normals=True
    mod.face_strength_mode="FSTR_AFFECTED"
    hardened=obj.modifiers.new("Broad face normal weighting","WEIGHTED_NORMAL")
    hardened.keep_sharp=True
    hardened.use_face_influence=True


def surface(work, title, outline, side, depth, shade, group=None, parent=None, bulge=None):
    """Closed quad cage with supported edges and a broad sculpted face."""
    middle=sum((Vector((x,z)) for x,z in outline),Vector((0,0)))/len(outline)
    rows=[]
    for inset,rise in [(.91,-.008),(.996,-.004),(1,0),(.994,.003),(.962,.008),
                       (.870,.013),(.652,.015),(.352,.0158),(.15,.016)]:
        points=[]
        for index,(x,z) in enumerate(outline):
            p=middle.lerp(Vector((x,z)),inset)
            y=depth(p.x,p.y)+rise
            if bulge and rise>0:
                y+=bulge(index,p.x,p.y)*(1-inset)*1.2
            points.append((p.x,side*y,p.y))
        rows.append(points)
    n=len(outline)
    vertices=[v for row in rows for v in row]
    faces=[tuple(reversed(range(n)))]
    roles=[2]
    for i in range(len(rows)-1):
        for j in range(n):
            k=(j+1)%n
            face=(i*n+j,i*n+k,(i+1)*n+k,(i+1)*n+j)
            faces.append(face)
            roles.append(2 if i<2 else 1 if i==4 and j<11 else 0)
    conn=(len(rows)-1)*n
    center=tuple(sum(vertices[conn+j][i] for j in range(n))/n for i in range(3))
    vertices.append(center)
    for j in range(n):
        faces.append((conn+j,conn+(j+1)%n,len(vertices)-1))
        roles.append(0)
    obj=work.mesh(title,vertices,faces,shade,group,parent,roles)
    edge_crease=obj.data.attributes.new("crease_edge","FLOAT","EDGE")
    corner=obj.data.attributes.new("crease_vert","FLOAT","POINT")
    for edge in obj.data.edges:
        a,b=edge.vertices
        row_a,row_b=a//n,b//n
        if row_a==row_b and row_a in {2,4,5}:
            edge_crease.data[edge.index].value=.38 if row_a==4 else .28
        if a%n==b%n and row_a<6 and row_b<6:
            j=a%n
            u=Vector(outline[j-1])-Vector(outline[j])
            v=Vector(outline[(j+1)%n])-Vector(outline[j])
            if u.angle(v)<math.radians(148):
                edge_crease.data[edge.index].value=.76
    for row in (2,3,4):
        for j in range(n):
            u=Vector(outline[j-1])-Vector(outline[j])
            v=Vector(outline[(j+1)%n])-Vector(outline[j])
            if u.angle(v)<math.radians(130):
                corner.data[row*n+j].value=.68
    for face in obj.data.polygons:
        face.use_smooth=True
    sub=obj.modifiers.new("Sculpt surface levels","SUBSURF")
    sub.levels=2
    sub.render_levels=2
    sub.quality=5
    return obj


def stock_steel():
    return {"Body":0,"Panel":1,"Dark":2,"Metal":3,"Grip":4,"Accent":5,"Neon":6,"Brass":3}


def carrier(work):
    # This base retains the original squeeze, shoulder and action-to-forearm
    # junction, then pushes the closed shell into its new curved envelope.
    def centerbody(p):
        x,y,z=p
        high=max(0,min(1,(z-.275)/.15))
        waist=max(0,1-((x-.37)/.80)**2)
        p.y=y*(.963+.038*high*waist)
        p.z=z-.018*high*(.38+.62*waist)+.005*high*math.sin(math.pi*max(0,min(1,(x+.165)/1.18)))
        return p
    def handguard(p):
        x,y,z=p
        t=max(0,min(1,(x-1.04)/.68))
        p.y=y*(1-.11*t)
        p.z=z-.020*t*max(0,min(1,(z-.17)/.17))
        p.x=x+.032*t*t
        return p
    lower=clean_donor(work,"Receiver_IndigoForging","Vandal_Receiver",work.chassis,work.body,
                      {"Body":0,"Panel":1,"Dark":2,"Accent":3,"Metal":3},centerbody,width=.0016)
    front=clean_donor(work,"Shroud_OctagonalForging","Vandal_Handguard",work.chassis,work.body,
                      {"Body":0,"Panel":0,"Dark":2,"Accent":3,"Grip":4,"Metal":3},
                      handguard,width=.0028)
    # Hidden lower seat is sculpted from one stock geometry assembly.
    work.scene["front_break"]="Stock outer handguard; original support-seat surface retained."
    return lower,front


def torch_barrel(work):
    def filter_body(mesh,points,faces,ids):
        # Keep the mounting stem and fore extension. The exterior end has its own new skin.
        chosen=[i for i,face in enumerate(faces) if max(points[j].x for j in face) <=2.393]
        return [faces[i] for i in chosen],[ids[i] for i in chosen]
    clean_donor(work,"Barrel_StockFitStem","Vandal_Barrel",work.chassis,work.body,
                {"Body":3,"Dark":2,"Metal":3,"Accent":5},width=.0016,filter_islands=filter_body)
    y_center=0
    z_center=.285
    n=32
    xs=[2.359,2.392,2.425,2.451,2.475,2.505,2.523,2.556,2.574,2.622,2.647]
    radii=[.040,.048,.053,.055,.053,.055,.054,.057,.055,.061,.052]
    height=[0,0,.003,.004,.006,.006,.007,.006,.005,.002,0]
    angles=[(j+.5)*math.tau/n for j in range(n)]
    verts=[(x+height[q]*math.sin(a),y_center+r*math.cos(a),z_center+r*math.sin(a))
           for inset in (False,True) for q,(x,r0) in enumerate(zip(xs,radii))
           for r in (.031 if inset else r0,) for a in angles]
    faces=[]
    roles=[]
    off=n*len(xs)
    def kept(i,j):
        return 0<=i<len(xs)-1 and not(i in {3,5,7} and (j%16 in {0,1,2,3,4,5,13,14,15}))
    for row in range(len(xs)-1):
        for j in range(n):
            if not kept(row,j):
                continue
            k=(j+1)%n
            a,b,c,d=row*n+j,row*n+k,(row+1)*n+k,(row+1)*n+j
            faces.extend([(a,b,c,d),(a+off,d+off,c+off,b+off)])
            roles.extend([1 if row in {1,8} else 0,2])
            for e,(u,v) in enumerate([(a,b),(b,c),(c,d),(d,a)]):
                neighbor=[(row-1,j),(row,k),(row+1,j),(row,(j-1)%n)][e]
                if not kept(*neighbor):
                    faces.append((v,u,u+off,v+off))
                    roles.append(1 if row in {0,9} or e in {0,2} else 2)
    muzzle=work.mesh("Muzzle_FacetedPortCage",verts,faces,[work.steel,work.silver,work.well],
                     work.chassis,work.body,roles)
    chamfer(muzzle,.001,2,46)


def armor(work):
    lower,front=carrier(work)
    # Closed cuts surround real seats. The forward fin is attached at the
    # stock ferrule and follows the handguard into its exposed barrel space.
    rear_shape=[(-.171,.375),(-.123,.423),(-.046,.452),(.148,.459),(.367,.460),(.548,.455),
                (.727,.443),(.893,.431),(1.031,.416),(1.096,.381),(1.041,.349),(.856,.342),
                (.661,.350),(.463,.343),(.284,.353),(.112,.346),(-.018,.329),(-.107,.311)]
    fore_shape=[(1.094,.399),(1.178,.427),(1.306,.426),(1.478,.411),(1.61,.393),(1.736,.377),
                (1.833,.366),(1.929,.361),(2.038,.365),(2.102,.347),(2.031,.324),(1.938,.321),
                (1.804,.326),(1.701,.31),(1.625,.288),(1.572,.274),(1.473,.289),(1.326,.296),
                (1.207,.286),(1.116,.279),(1.065,.29),(1.047,.339)]
    for side,label in [(1,"Player"),(-1,"Far")]:
        rear_ctrl=work.empty("CTRL_PlateRear_"+label,(.327,side*.101,.368),work.body)
        fore_ctrl=work.empty("CTRL_PlateFore_"+label,(1.432,side*.096,.352),work.body)
        rear_ctrl["travel_x"]=.041
        fore_ctrl["travel_x"]=.035
        def rear_taper(x,z):
            return .089+.006*math.sin((x+.17)*math.pi/1.26)-.009*max(0,(z-.408)/.048)
        def fore_taper(x,z):
            return .093-.053*max(0,(x-1.61)/.53)-.008*max(0,(z-.38)/.06)
        surface(work,"Rear_SilverPlate_"+label,rear_shape,side,rear_taper,
                [work.ceramic,work.silver,work.well],parent=rear_ctrl,
                bulge=lambda i,x,z:.003*math.exp(-((x-.42)/.39)**2))
        surface(work,"Fore_SilverPlate_"+label,fore_shape,side,fore_taper,
                [work.ceramic,work.silver,work.well],parent=fore_ctrl,
                bulge=lambda i,x,z:.0019*math.sin((x-1.05)*math.pi/.95))
        # Two compact cobalt inserts follow different assembly directions.
        # Both are seated in recessed material and have no emissive shader.
        pocket=[(.048,.221),(.118,.262),(.453,.258),(.545,.278),(.704,.268),
                (.771,.234),(.683,.219),(.54,.230),(.452,.221),(.118,.214)]
        floor=[(.073,.225),(.126,.254),(.45,.251),(.545,.269),(.695,.261),
               (.751,.234),(.675,.226),(.541,.237),(.449,.227),(.127,.222)]
        plug=[((x-.43)*.96+.43,(z-.244)*.87+.244) for x,z in floor]
        work.recessed_inlay("Receiver_CobaltCeramic_"+label,lower,side,pocket,floor,plug,.073,.13)
        lower_blade=[(.279,.153),(.354,.187),(.502,.184),(.628,.178),(.771,.187),(.875,.207),
                     (.921,.194),(.858,.155),(.728,.130),(.626,.124),(.535,.105),(.412,.12),(.351,.141)]
        surface(work,"Receiver_MagwellShoulder_"+label,lower_blade,side,
                lambda x,z:.073-.018*max(0,(.145-z)/.055),
                [work.coal,work.steel,work.well])
        wing=[(1.227,.196),(1.277,.228),(1.418,.223),(1.559,.256),(1.613,.264),
              (1.649,.246),(1.583,.215),(1.489,.192),(1.356,.175),(1.265,.179)]
        surface(work,"Shroud_UndercutRail_"+label,wing,side,lambda x,z:.060+.023*(1-(x-1.23)/.419),
                [work.coal,work.steel,work.well])
    # The top crown seats the side plates into the action carrier and closes
    # the midline visible from the held camera.
    work.hull("Receiver_TransferCover",[
       (-.164,.037,.379,.424,-.09),(-.114,.055,.392,.454,-.04),
       (.067,.064,.405,.466,0),(.318,.068,.412,.471,0),
       (.65,.065,.412,.462,.06),(.90,.058,.398,.442,.19),(1.067,.050,.382,.418,.24),
    ],[work.coal,work.ceramic,work.steel],face_role=lambda edge,row: 1 if edge in {4,5,6} else 2 if edge in {3,7} else 0)
    work.hull("Shroud_UpperSeat",[
       (1.053,.044,.382,.415,.24),(1.158,.053,.387,.438,.18),
       (1.36,.052,.385,.435,.04),(1.577,.045,.368,.411,-.20),
       (1.754,.034,.350,.384,-.26),(1.991,.023,.324,.364,-.17),
       (2.081,.019,.324,.350,-.14),
    ],[work.coal,work.ceramic,work.steel],face_role=lambda edge,row: 1 if edge in {4,5,6} else 2 if edge in {3,7} else 0)
    torch_barrel(work)


def configure_stage(work):
    work.light_and_frame()
    work.scene.cycles.samples=36
    work.scene.view_settings.look="AgX - Medium High Contrast"
    # Keep hand-held framing and both ADS fixtures from the stock source.
    work.camera("Review_Forging",(1.18,2.2,.74),(.99,0,.30),2.32)
    work.scene["look"]="Storm Shadow | high detail ceramic and blued metal"


def first_pass(version="v16"):
    work=Workshop()
    armor(work)
    configure_stage(work)
    work.save(version,"Stock-fitted receiver, fore-end and muzzle")
    return work


def leather_sculpt(work,name,profile,spans,group,parent,skew):
    """Sculpt tension breaks into a dense closed wrap cage following the stock cross section."""
    for band,(top,bottom) in enumerate(spans):
        rings=[]
        for t,raised in [(0,-.002),(.06,.0005),(.13,.0032),(.23,.0065),(.40,.0067),
                         (.62,.0051),(.78,.0045),(.89,.0058),(.96,.0029),(1,-.0016)]:
            z=top+t*(bottom-top)
            lo,hi,thickness=fitted_profile(profile,z)
            half=(hi-lo)*.5
            middle=(hi+lo)*.5
            points=[]
            for i in range(64):
                turn=math.tau*i/64
                sn,cs=math.sin(turn),math.cos(turn)
                dx=math.copysign(abs(cs)**.43,cs)*half
                dy=math.copysign(abs(sn)**.43,sn)*thickness
                # Pinned corner rolls and one broad compressed fold on each exposed face.
                crease=math.exp(-((t-.68-.12*cs)/.115)**2)*math.sin((band+1)*.62+turn*1.8)
                closing=math.cos(3*turn+band*.72)*.0017*math.sin(t*math.pi)
                seam=.0043*math.sin(turn*2.1+band*.70)+.0046*math.sin(turn)*math.cos(turn)
                rise=raised-closing-.0023*crease
                points.append((middle+dx+cs*rise*.62,dy+sn*rise,z+skew*dx+seam))
            rings.append(points)
        obj=work.loft(f"{name}_{band+1}",rings,[work.leather,work.raw_edge],group,parent,loop=True,
                      face_role=lambda edge,row:int(row in {0,8,9}))
        for p in obj.data.polygons:
            p.use_smooth=True
        sc=obj.modifiers.new("Editable leather sculpt subdivisions","MULTIRES")
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.multires_subdivide(modifier=sc.name,mode="CATMULL_CLARK")
        sc.levels,sc.sculpt_levels,sc.render_levels=1,1,1
        obj["sculpt_notes"]="Measured contact envelope, folded seam and asymmetric compression."


def furniture_detail(work):
    def stock_shape(p):
        x,y,z=p
        cheek=max(0,min(1,(z-.185)/.22)) * max(0, 1-((x+.82)/.49)**2)
        p.y=y*(1-.12*cheek)
        p.z=z+.013*cheek*(x+.8)
        return p
    stock=clean_donor(work,"Stock_FittedChassis","Vandal_Stock",work.stock_group,work.body,
               {"Body":0,"Panel":0,"Dark":2,"Metal":3,"Grip":4,"Accent":3},stock_shape,width=.0026)
    cap=[(-1.147,.368),(-1.089,.401),(-.98,.413),(-.844,.413),(-.692,.405),(-.542,.391),
         (-.424,.377),(-.370,.340),(-.406,.293),(-.536,.281),(-.672,.262),(-.833,.247),
         (-.991,.252),(-1.108,.262)]
    for side,key in [(1,"Player"),(-1,"Far")]:
        surface(work,"Stock_CeramicCheek_"+key,cap,side,
                lambda x,z:.059-.015*max(0,(x+.64)/.3)-.008*max(0,(z-.376)/.046),
                [work.ceramic,work.silver,work.well],work.stock_group,
                bulge=lambda index,x,z:.0022*math.cos((x+.83)*2.7))
        p=[(-1.125,-.119),(-1.078,-.119),(-.993,-.019),(-.908,.074),(-.829,.166),
           (-.787,.181),(-.788,.151),(-.887,.045),(-.992,-.063),(-1.062,-.137)]
        surface(work,"Stock_DiagonalEdge_"+key,p,side,
                lambda x,z:.043+.005*math.cos(x*.9),[work.steel,work.ceramic,work.well],work.stock_group)
    grip=clean_donor(work,"Grip_ShapedFactoryTang","Vandal_Grip",work.grip,work.body,
                     {"Body":0,"Panel":0,"Dark":2,"Metal":3,"Grip":4},width=.0019)
    mag=clean_donor(work,"Mag_ContinuousCurvedShell","Vandal_Mag",work.magazine,work.mag,
                    {"Body":0,"Panel":3,"Dark":2,"Metal":3,"Grip":4,"Accent":3,"Brass":1},width=.0017)
    for side,key in [(1,"Player"),(-1,"Far")]:
        p=[(-.073,.082),(-.037,.105),(.067,.103),(.104,.074),(.094,.047),(.066,.044),(.014,.058),(-.049,.041)]
        surface(work,"Grip_CarvedShoulder_"+key,p,side,lambda x,z:.046,
                [work.coal,work.steel,work.well],work.grip)
        window=[(.526,.039),(.559,.084),(.637,.099),(.702,.068),(.730,.019),(.727,-.040),
                (.706,-.076),(.649,-.067),(.606,-.042),(.571,.006)]
        bed=[(.541,.034),(.571,.073),(.638,.087),(.694,.062),(.718,.020),(.718,-.032),
             (.700,-.065),(.656,-.061),(.612,-.037),(.579,.007)]
        enamel=[((x-.63)*.92+.63,(z-.016)*.89+.016) for x,z in bed]
        work.recessed_inlay("Mag_BlueCeramic_"+key,mag,side,window,bed,enamel,.047,.080,work.magazine,work.mag)
    narrower_grip=[(z,lo+.004,hi-.003,min(depth,.055)) for z,lo,hi,depth in GRIP_SECTIONS]
    narrower_mag=[(z,lo+.002,hi-.001,.054) for z,lo,hi,depth in MAG_SECTIONS]
    leather_sculpt(work,"Grip_HandWrappedLeather",narrower_grip,
        [(.024,-.041),(-.039,-.109),(-.104,-.177),(-.172,-.240),(-.226,-.281)],
        work.grip,work.body,.15)
    leather_sculpt(work,"Mag_TensionedLeather",narrower_mag,
        [(-.097,-.161),(-.155,-.232),(-.221,-.288),(-.272,-.344)],
        work.magazine,work.mag,.20)


def second_pass(version="v17"):
    work=Workshop.resume()
    # Keep the full-detail mesh and pull the rounded highlights back into the
    # supported shoulder edges after the grazing-light review.
    for mat, hex_code, metal, rough in [
        (work.coal,"1B2531",.46,.39),(work.ceramic,"394C62",.61,.29),
        (work.silver,"9CB3C7",.79,.24),(work.blue,"104D84",.40,.28),
    ]:
        mat["srgb"]=hex_code
        mat.diffuse_color=(*color(hex_code),1)
        shader=mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value=mat.diffuse_color
        shader.inputs["Metallic"].default_value=metal
        shader.inputs["Roughness"].default_value=rough
    for obj in work.chassis.objects:
        if not obj.name.startswith(("Rear_SilverPlate","Fore_SilverPlate")):
            continue
        for vert in obj.data.vertices:
            vert.co.y *= .72
        crease=obj.data.attributes["crease_edge"]
        for edge in obj.data.edges:
            if crease.data[edge.index].value >= .70:
                crease.data[edge.index].value=.91
    shell=[(-.112,.237),(-.053,.273),(.061,.268),(.210,.229),(.366,.208),(.514,.215),
           (.657,.217),(.80,.203),(.882,.182),(.820,.156),(.687,.144),(.514,.139),
           (.424,.123),(.269,.122),(.168,.127),(.073,.139),(-.025,.147),(-.101,.171)]
    for side,key in [(1,"Player"),(-1,"Far")]:
        surface(work,"Receiver_LowerCeramicShell_"+key,shell,side,
                lambda x,z:.080-.011*max(0,(.16-z)/.048),
                [work.coal,work.steel,work.well],
                bulge=lambda i,x,z:-.006*math.sin(math.pi*max(0,min(1,(x+.11)/.99))))
    furniture_detail(work)
    work.save(version,"Sculpted stock, grip and curved magazine")
    return work


def fit_hardware(work):
    sight=work.sights
    # The original support and front post determine the actual sight line.
    # Re-taper the upper ears towards that line and preserve the mount base.
    def front_profile(p):
        t=max(0,min(1,(p.z-.356)/.237))
        p.y*=1-.20*t
        p.x=2.023+(p.x-2.023)*(1-.20*t)-.015*t
        p.z-=.031*t*t
        return p
    clean_donor(work,"Sight_StockAxisFront","Vandal_FrontSight",sight,work.body,
                {"Body":0,"Panel":0,"Dark":2,"Metal":3,"Accent":5,"Neon":6},
                front_profile,width=.0015)
    work.hull("Sight_CeramicDovetail",[
        (-.036,.028,.425,.451,-.11),(.012,.039,.432,.475,0),
        (.093,.038,.439,.478,.11),(.150,.022,.432,.456,.15),
    ],[work.coal,work.steel,work.ceramic],sight,
      face_role=lambda edge,row: 2 if edge in {4,5,6} else 1 if edge in {3,7} else 0)
    work.hull("Sight_ReceiverTenon",[(.041,.019,.461,.494,0),(.062,.025,.461,.503,0),
        (.102,.023,.462,.502,.11),(.121,.016,.461,.489,.11)],[work.well,work.steel],sight,
        face_role=lambda edge,row:int(edge in {3,4,5,6,7}))
    points=[]
    for i in range(43):
        a=math.radians(132+i*276/42)
        y,z=math.cos(a),math.sin(a)
        squareness=1/(abs(y)**3.1+abs(z)**3.1)**(1/3.1)
        outer=.0755*squareness
        drop=.005*abs((i-21)/21)**5
        row=[(.056,.0588),(.062,.0588),(.093,.0591),(.099,.0652),(.096,outer-.002),
             (.091,outer),(.068,outer),(.058,outer-.003),(.054,.064)]
        points.append([(x,r*y,.5598+r*z-drop) for x,r in row])
    aperture=work.loft("Sight_OpenCeramicAperture",points,[work.coal,work.steel,work.silver,work.mark],sight,
              face_role=lambda edge,row: 3 if edge==7 and row in {0,41} else 2 if edge==7
                 else 1 if edge in {2,3,4} else 0)
    for f in aperture.data.polygons:
        f.use_smooth=len(f.vertices)==4
    chamfer(aperture,.00085,3,52)

    clean_donor(work,"Charge_ReceiverSweep","Vandal_ChargingHandle",work.grip,work.charge,
                {"Body":0,"Metal":3,"Accent":5},width=.0019)
    clean_donor(work,"Bolt_RecessShutter","Vandal_Bolt",work.grip,work.bolt,
                {"Body":0,"Dark":2,"Metal":3},width=.0008)
    clean_donor(work,"Grip_Trigger","Vandal_Trigger",work.grip,work.body,
                {"Body":0,"Metal":3,"Accent":3},width=.0009)
    clean_donor(work,"Grip_Selector","Vandal_FireSelector",work.grip,work.body,
                {"Body":0,"Metal":3,"Accent":5},width=.0010)
    clean_donor(work,"BuddyMount_StockPlateAndLoop","Vandal_CharmLoop",work.mount,work.body,
                {"Body":0,"Dark":2,"Metal":3,"Accent":5},width=0,dissolve=False)
    for name,point,parent in [
        ("FXSocket_ForeInlet",(1.65,.070,.374),work.body),
        ("FXSocket_ReceiverOutlet",(.40,.10,.406),work.body),
        ("FXSocket_StockReturn",(-1.126,.060,.283),work.body),
        ("FXSocket_Magazine",(.68,.058,-.124),work.mag),
        ("FXSocket_InspectBalance",(.67,0,.217),work.balance),
    ]:
        work.empty(name,point,parent,work.sockets)
    work.sockets.hide_viewport=True


def round_study(work):
    """Independent cosmetic prop. No active effect material or light."""
    glass=work.material("Glass · pale cobalt glass","39769A",.16,.23,.37)
    glass.node_tree.nodes["Principled BSDF"].inputs["Transmission Weight"].default_value=.28
    parts=[
        ("Round_DarkSilverTip",[(.069,.021),(.086,.021),(.111,.013),(.121,.005)],work.steel),
        ("Round_CeramicCore",[(-.081,.012),(-.020,.015),(.046,.013),(.064,.008)],work.blue),
        ("Round_PressureGlass",[(-.082,.018),(-.077,.025),(.055,.025),(.069,.021)],glass),
        ("Round_HeelCollar",[(-.111,.020),(-.106,.027),(-.084,.029),(-.075,.024)],work.steel),
        ("Round_FaceCollar",[(.051,.024),(.054,.027),(.071,.027),(.081,.023)],work.silver),
    ]
    for title,sections,mat in parts:
        ring=[[(x,r*math.cos(i*math.tau/24),r*math.sin(i*math.tau/24)) for i in range(24)] for x,r in sections]
        obj=work.loft(title,ring,[mat],work.round)
        chamfer(obj,.00075,2)
    work.round.hide_render=True
    work.round.hide_viewport=True


def sink_wrap_cores(work):
    def ramp(t):
        t=max(0,min(1,t))
        return t*t*(3-2*t)

    bpy.context.view_layer.update()
    for name, profiles, top, bottom in [
        ("Grip_ShapedFactoryTang",GRIP_SECTIONS,.042,-.293),
        ("Mag_ContinuousCurvedShell",MAG_SECTIONS,-.082,-.366),
    ]:
        obj=work.scene.objects[name]
        world=obj.matrix_world.copy()
        local=world.inverted()
        patch=bmesh.new()
        patch.from_mesh(obj.data)
        bmesh.ops.triangulate(patch,faces=list(patch.faces))
        bmesh.ops.subdivide_edges(patch,edges=list(patch.edges),cuts=4,use_grid_fill=True)
        for vertex in patch.verts:
            p=world @ vertex.co
            if not bottom<p.z<top:
                continue
            lo,hi,_=fitted_profile(profiles,p.z)
            if not lo-.015<=p.x<=hi+.014:
                continue
            wrap=ramp((top-p.z)/.030)*ramp((p.z-bottom)/.021)
            mid=(lo+hi)*.5
            p.x=mid+(p.x-mid)*(1-.065*wrap)
            p.y*=1-.31*wrap
            vertex.co=local @ p
        bmesh.ops.recalc_face_normals(patch,faces=list(patch.faces))
        patch.to_mesh(obj.data)
        patch.free()
        obj.data.update()
        obj["wrap_seat"]="Stock tang and shell reduced under the leather, within the stock outer hand envelope."


def third_pass(version="v18"):
    work=Workshop.resume()
    sink_wrap_cores(work)
    fit_hardware(work)
    round_study(work)
    work.scene["look"]="Storm Shadow | Stock-fitted ceramic master"
    work.save(version,"Joints, sight, mount and round")
    return work


def restore_closed_cage(obj):
    # Some stock meshes join separately triangulated subassemblies. Weld the
    # coincident borders, then close the remaining source openings internally.
    m=bmesh.new()
    m.from_mesh(obj.data)
    bmesh.ops.remove_doubles(m,verts=list(m.verts),dist=.000008)
    bmesh.ops.dissolve_degenerate(m,edges=list(m.edges),dist=.0000012)
    boundary=[e for e in m.edges if e.is_boundary]
    if boundary:
        patched=bmesh.ops.holes_fill(m,edges=boundary,sides=0)["faces"]
        for face in patched:
            face.material_index=2 if len(obj.data.materials)>2 else 0
    bmesh.ops.recalc_face_normals(m,faces=list(m.faces))
    result=sum(not e.is_manifold for e in m.edges)
    m.to_mesh(obj.data)
    m.free()
    return result


def fourth_pass(version="v19"):
    work=Workshop.resume()
    body=work.scene.objects["Mag_ContinuousCurvedShell"]
    for modifier in list(body.modifiers):
        if modifier.type=="BOOLEAN":
            body.modifiers.remove(modifier)
    for obj in list(work.magazine.objects):
        if obj.name.startswith(("Tool_Mag_BlueCeramic","Mag_BlueCeramic")):
            bpy.data.objects.remove(obj,do_unlink=True)
    for side,label in [(1,"Player"),(-1,"Far")]:
        # This fitted liner has a shoulder under the lip and ends above the leather.
        edge=[(.539,.047),(.558,.069),(.616,.083),(.662,.079),(.699,.053),(.718,.012),
              (.717,-.028),(.696,-.071),(.659,-.069),(.624,-.046),(.582,-.029),(.552,.008)]
        shoulder=[((x-.631)*.92+.631,(z-.01)*.92+.01) for x,z in edge]
        w=work.slab("Mag_CobaltCeramicLiner_"+label,edge,
                    [(side*.055,edge),(side*.058,edge),(side*.062,shoulder)],
                    [work.blue,work.bright_blue],work.magazine,work.mag,
                    face_role=lambda edge,row: int(row==1 and edge in {1,2,3,4}))
        chamfer(w,.0011,2)
    plugs={}
    for name in [
        "Receiver_IndigoForging","Shroud_OctagonalForging","Barrel_StockFitStem","Stock_FittedChassis",
        "Grip_ShapedFactoryTang","Grip_Selector","Sight_StockAxisFront","Mag_ContinuousCurvedShell",
    ]:
        obj=work.scene.objects[name]
        plugs[name]=restore_closed_cage(obj)
        if name in {"Shroud_OctagonalForging","Sight_StockAxisFront"}:
            for mod in list(obj.modifiers):
                if mod.type in {"BEVEL","WEIGHTED_NORMAL"}:
                    obj.modifiers.remove(mod)
            for f in obj.data.polygons:
                f.use_smooth=False
    for mod in list(work.scene.objects["Bolt_RecessShutter"].modifiers):
        work.scene.objects["Bolt_RecessShutter"].modifiers.remove(mod)
    marker=[(1.978,.398),(1.989,.504),(1.998,.550),(2.014,.550),(2.022,.526),(2.026,.399)]
    work.slab("Sight_FrontPostReference",marker,[(-.007,None),(.007,None)],
              [work.steel],work.sights)
    tip=[(1.993,.542),(1.998,.549),(2.011,.549),(2.013,.541)]
    work.slab("Sight_FrontCeramicReference",tip,[(-.004,None),(.004,None)],
              [work.mark],work.sights)
    work.scene["boundary_repair_residuals"]=str(plugs)
    work.save(version,"Closed geometry and surface fit")
    return work


def fifth_pass(version="v20"):
    work=Workshop.resume()
    receiver=work.scene.objects["Receiver_IndigoForging"]
    grip=work.scene.objects["Grip_ShapedFactoryTang"]
    for obj in (receiver,grip):
        for mod in list(obj.modifiers):
            if mod.type=="BEVEL":
                obj.modifiers.remove(mod)
    mesh=bmesh.new()
    mesh.from_mesh(grip.data)
    rim=[e for e in mesh.edges if e.is_boundary]
    if rim:
        vertices=set(v for edge in rim for v in edge.verts)
        cap=mesh.verts.new(sum((v.co for v in vertices),Vector())/len(vertices))
        for edge in rim:
            face=mesh.faces.new((*edge.verts,cap))
            face.material_index=2
        bmesh.ops.recalc_face_normals(mesh,faces=list(mesh.faces))
    mesh.to_mesh(grip.data)
    mesh.free()

    # The fixed rail is the actual seat beneath the two moving side plates.
    # Closing that pocket matters most from the matched first-person camera.
    guide=work.hull("Receiver_SlideDovetailBed",[
        (-.174,.062,.361,.417,-.10),(-.122,.082,.358,.432,-.12),
        (.008,.087,.365,.441,0),(.300,.089,.375,.446,.03),
        (.599,.087,.371,.442,.07),(.876,.084,.353,.424,.18),
        (1.059,.080,.344,.401,.21),
    ],[work.coal,work.steel,work.well],face_role=lambda edge,row:
        1 if edge in {3,7} else 2 if edge in {4,6} else 0)
    chamfer(guide,.0011,2,48)
    fore=work.hull("Shroud_FerruleGuideBed",[
        (1.047,.077,.321,.398,.21),(1.12,.088,.323,.411,.14),
        (1.339,.088,.326,.410,0),(1.559,.070,.307,.384,-.20),
        (1.732,.057,.293,.356,-.25),(1.932,.043,.304,.342,-.14),
        (2.057,.042,.311,.342,-.11),
    ],[work.coal,work.steel,work.well],face_role=lambda edge,row:
        1 if edge in {3,7} else 2 if edge in {4,6} else 0)
    chamfer(fore,.001,2,50)
    for obj in work.chassis.objects:
        if not obj.name.startswith("Rear_SilverPlate"):
            continue
        matrix=obj.matrix_world.copy()
        local=matrix.inverted()
        for v in obj.data.vertices:
            p=matrix @ v.co
            upper=max(0,min(1,(p.z-.412)/.047))
            p.y*=1-.08*upper
            p.z-=.005*upper
            v.co=local @ p
    for obj in list(work.magazine.objects):
        if obj.name.startswith("Mag_CobaltCeramicLiner"):
            bpy.data.objects.remove(obj,do_unlink=True)
    connector=[(.556,.031),(.548,.053),(.564,.079),(.584,.085),(.608,.063),(.652,.028),
               (.713,-.032),(.722,-.055),(.694,-.071),(.653,-.048),(.621,-.018),(.584,.018)]
    inner=[((x-.635)*.97+.635,(z-.01)*.90+.01) for x,z in connector]
    for side,label in [(1,"Player"),(-1,"Far")]:
        piece=work.slab("Mag_CobaltCeramicFlute_"+label,connector,
                        [(side*.054,None),(side*.058,None),(side*.060,inner)],
                        [work.blue,work.bright_blue],work.magazine,work.mag,
                        face_role=lambda edge,row:int(row==1 and edge in {1,2,3}))
        chamfer(piece,.00116,3,42)
    work.save(version,"Final render and fit correction")
    return work


def mechanical_pass(version="v21"):
    from animate_tempest_strike import author

    work=Workshop.resume()
    def unparent(obj,parent):
        if parent is None:
            bpy.context.view_layer.update()
            world=obj.matrix_world.copy()
            obj.parent=None
            obj.matrix_world=world
        return obj

    def proxy_mesh(name,verts,faces,mats,group,parent=None,bevel=0):
        obj=work.mesh(name,verts,faces,mats,group,parent)
        if bevel:
            chamfer(obj,bevel,2)
        return unparent(obj,parent)

    def proxy_loft(name,rings,mats,group,parent=None,stripe=None,loop=False):
        obj=work.loft(name,rings,mats,group,parent,stripe,loop)
        return unparent(obj,parent)

    def octagon(w,h,cut):
        return [(w*(1-cut),-h),(-w*(1-cut),-h),(-w,-h*(1-cut)),(-w,h*(1-cut)),
                (-w*(1-cut),h),(w*(1-cut),h),(w,h*(1-cut)),(w,-h*(1-cut))]

    author({
        "SCENE":work.scene,"RIG":work.rig,"ACTION":work.origin,"BALANCE":work.balance,
        "BODY_CTRL":work.body,"MAG_CTRL":work.mag,"CHARGE":work.charge,"BOLT":work.bolt,
        "STAGE":work.stage,"MAG":work.magazine,"mesh":proxy_mesh,"loft":proxy_loft,
        "hull":work.hull,"empty":work.empty,"camera":work.camera,"collection":work.group,
        "octagon":octagon,"tube":None,
        "material":lambda role,shade,metal,rough:work.material(role,shade,metal,rough,.06),
        "DEST":Path(__file__).resolve().parents[2]/"art-source/weapons/Skins/TempestStrike/Vandal",
        "save":lambda revision:work.save(revision,"Mechanical draw, reload and inspect rehearsal"),
    },version)
    return work


if __name__ == "__main__":
    first_pass()
