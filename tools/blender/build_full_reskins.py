"""Build and verify a single versioned finish in the live Blender MCP session.

Import this module from tools/blender inside Blender. Run prepare(line, gun,
version) and finish(line, gun, version) as separate MCP calls. The split gives
Blender a fresh operator context after opening the source and before baking.
Call verify(line, gun, version) to open the persisted asset and render its maps.
"""

import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Vector
import numpy as np

import build_skin_roster as roster
from build_skin_roster import Nodes, bake, framing as F, sheet as M
from export_roblox_flat import resolve_coplanar, _crosses
from full_reskin_art import PALETTES, layers, raster
from full_reskin_uv import relocate
from skin_graphics import linear


ROOT=roster.ROOT
ART=roster.ART
SKINS=ART/"Skins"
REVIEW=SKINS/"Review"/"Oilwake-Misprint-Faultline"
GUNS=[gun for gun in F.GUNS if gun!="Knife"]
M.bind(vars(F))

FIXED={
    "Bulldog": SKINS/"Shared Sources/Bulldog/BoltFix_v02/Bulldog_RemasterV2_v05_BoltFix_v02.blend",
    "Stinger": SKINS/"Shared Sources/Stinger/HandguardFix_v01/Stinger_RemasterV2_v05_HandguardFix_v01.blend",
}
APPROVED=SKINS/"Misprint/Bulldog/v03/Bulldog_Misprint_v03.blend"
CONCEPTS={
    "Oilwake": "Oilwake/out/Phantom_concept_v01.png",
    "Misprint": "Misprint/out/Bulldog_concept_v01.png",
    "Faultline": "Faultline/out/Sheriff_concept_v02.png",
}
PROTECTED={"Bolt","Crane","EjectorRod","Shell","Shells","Speedloader","SlideNeon","MagNeon"}
KEYS=("Base Color","Roughness","Metallic")
DETAILS={
    "Bulldog": ((-.34,-.077,.334),(-.24,-1,.39),.48),
    "Stinger": ((.655,-.082,.202),(.18,-1,.27),.55),
}
OIL_RAMP=((0,"254753"),(.19,"2C6265"),(.36,"408B72"),(.59,"6D995F"),(.77,"B39051"),(.94,"CF9955"))


def source(gun):
    return FIXED.get(gun, ART/"RemasterV2"/gun/f"{gun}_RemasterV2_v05.blend")


def destination(line,gun,version):
    return SKINS/line/gun/version


def open_file(path):
    bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False)
    bpy.context.view_layer.update()
    return bpy.context.scene


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream,"sha256").hexdigest()


def prepare(line,gun,version="v01"):
    assert line in PALETTES and gun in GUNS
    assert (line,gun)!=("Misprint","Bulldog")
    assert not destination(line,gun,version).exists()
    sc=open_file(source(gun))
    assert sc==roster.scene_for(gun)
    return {"source":roster.rel(source(gun)),"active_file":bpy.data.filepath}


def _image(name,data):
    height,width,_=data.shape
    im=bpy.data.images.new(name,width,height,alpha=True,float_buffer=True)
    im.colorspace_settings.name="Non-Color"
    im.alpha_mode="CHANNEL_PACKED"
    im.pixels.foreach_set(data.ravel())
    im.pack()
    return im


def _asset_art(line,gun,objs):
    descriptions=[]
    for i,(placement,draw) in enumerate(layers(line,gun)):
        art=raster(placement,draw,gun)
        color=_image(f"{line} {gun} artwork {i+1}",art.rgba)
        finish=_image(f"{line} {gun} finish {i+1}",art.finish)
        a,b,c,d=placement.bounds
        for ob in objs:
            part=ob.name.removeprefix(gun+"_")
            if part not in placement.parts:
                continue
            points=np.array([tuple(ob.matrix_world@v.co) for v in ob.data.vertices],dtype=np.float32)
            projection=ob.data.attributes.new(f"Finish projection {i+1}","FLOAT_VECTOR","POINT")
            projected=np.zeros_like(points)
            projected[:,0]=(points[:,0]-a)/(b-a)
            projected[:,1]=(points[:,2]-c)/(d-c)
            projected[:,2]=points[:,1]
            projection.data.foreach_set("vector",projected.ravel())
            for role in placement.parts[part]:
                ob[f"finish_layer_{i+1}_{role}"]=1.0
        descriptions.append((placement,color,finish))
    return descriptions


def _layer_nodes(graph,num,color,finish,role,wrap=0.0):
    pos=graph.attr(f"Finish projection {num}").outputs["Vector"]
    if wrap:
        # Evaluate the across-width term at the shading point. A stock top
        # triangle need not have vertices along its centre line.
        axes=graph.node("SeparateXYZ","Rest-space projection axes")
        graph.set(axes.inputs[0],pos)
        u,v,lateral=axes.outputs
        depth=graph.math("MAXIMUM",graph.math("SUBTRACT",v,.64),0)
        depth=graph.math("MINIMUM",depth,.6)
        across=graph.math("DIVIDE",graph.math("ABSOLUTE",lateral),.091)
        across=graph.math("MAXIMUM",graph.math("SUBTRACT",1,across),0)
        change=graph.math("MULTIPLY",graph.math("MULTIPLY",depth,across),wrap)
        corrected=graph.node("CombineXYZ","Print over the fixed shoulder")
        graph.set(corrected.inputs[0],u)
        graph.set(corrected.inputs[1],graph.math("SUBTRACT",v,change))
        pos=corrected.outputs[0]
    gate=graph.attr(f"finish_layer_{num}_{role}","OBJECT").outputs["Fac"]
    ink=graph.node("TexImage","Rest-space graphic",image=color,extension="CLIP")
    maps=graph.node("TexImage","Local roughness and metalness",image=finish,extension="CLIP")
    for node in (ink,maps):
        graph.set(node.inputs["Vector"],pos)
    channels=graph.node("SeparateXYZ","Roughness, metalness, coating")
    graph.set(channels.inputs[0],maps.outputs["Color"])
    return graph.math("MULTIPLY",gate,ink.outputs["Alpha"]),ink.outputs["Color"],channels.outputs


def _preserved(gun,part):
    return part in PROTECTED or bool(roster.PROTECTED.search(part)) or (gun=="Stinger" and part=="Neon")


def author(line,gun,objs):
    descriptions=_asset_art(line,gun,objs)
    kept=[]
    for ob in objs:
        part=ob.name.removeprefix(gun+"_")
        preserve=_preserved(gun,part)
        ob["original_finish"]=float(preserve)
        if preserve:
            kept.append(ob.name)
    for mat in bake.gun_materials(gun):
        role=mat.name
        if role not in PALETTES[line]:
            continue
        g=Nodes(mat.node_tree)
        bsdf=next(n for n in g.tree.nodes if n.type=="BSDF_PRINCIPLED")
        initial=set(g.tree.nodes)
        old=roster.original_inputs(bsdf,KEYS)
        code, rough, metal=PALETTES[line][role]
        base=(*linear(code),1.0)
        actual=(base,rough,metal)
        keep=g.attr("original_finish","OBJECT").outputs["Fac"]
        mat.diffuse_color=base
        mat["rbx_color"]=code
        if role=="Neon":
            emission=bsdf.inputs["Emission Color"]
            value=tuple(emission.default_value)
            g.set(emission,g.mix(keep,base,value,True))
            # The shared emission bake reads the default when emission is linked.
            emission.default_value=value if gun=="Stinger" else base
        for i,(part,color,finish) in enumerate(descriptions):
            if not any(role in roles for roles in part.parts.values()):
                continue
            wrap=3*part.style[-1]/(part.bounds[3]-part.bounds[2]) if line=="Misprint" else 0.0
            mask,ink,maps=_layer_nodes(g,i+1,color,finish,role,wrap=wrap)
            actual=tuple(g.mix(mask,a,b,k==0) for k,(a,b) in enumerate(zip(actual,(ink,maps[0],maps[1]))))
        for k,(name,a,b) in enumerate(zip(KEYS,actual,old)):
            g.set(bsdf.inputs[name],g.mix(keep,a,b,k==0))
        roster.organize_tree(g.tree,initial,bsdf,KEYS)
    return descriptions,kept


def _add_oil_shift(gun,descriptions):
    for mat in bake.gun_materials(gun):
        if not any(mat.name in roles for part,_,_ in descriptions for roles in part.parts.values()):
            continue
        g=Nodes(mat.node_tree)
        pv=g.tree.nodes.get("PV_BSDF")
        if not pv:
            continue
        # The existing baked Color/roughness/metalness/normal chain is the
        # fallback. The authored Blender coating operates solely on the inset.
        original=bake.source(g.tree,pv.inputs["Base Color"])
        gate=0.
        for i,(part,color,finish) in enumerate(descriptions):
            if not any(mat.name in roles for roles in part.parts.values()):
                continue
            mask,_,maps=_layer_nodes(g,i+1,color,finish,mat.name)
            weight=g.math("MULTIPLY",mask,maps[2])
            gate=g.math("MAXIMUM",gate,weight)
        facing=g.node("LayerWeight","Coating viewing angle")
        facing.inputs["Blend"].default_value=.41
        colors=g.node("ValToRGB","Petrol through amber")
        ramp=colors.color_ramp
        for i,(position,code) in enumerate(OIL_RAMP):
            element=ramp.elements[i] if i<2 else ramp.elements.new(position)
            element.position=position
            element.color=(*linear(code),1)
        g.set(colors.inputs["Fac"],facing.outputs["Facing"])
        strength=g.math("MULTIPLY",gate,.92)
        strength.node.name="Oilwake angle shift strength"
        g.set(pv.inputs["Base Color"],g.mix(strength,original,colors.outputs["Color"],True))
        g.set(pv.inputs["Coat Weight"],g.math("MULTIPLY",strength,.57))
        pv.inputs["Coat Roughness"].default_value=.20


def set_oil_shift(gun,enabled):
    for mat in bake.gun_materials(gun):
        node=mat.node_tree.nodes.get("Oilwake angle shift strength")
        if node:
            node.inputs[1].default_value=.92 if enabled else 0


def _near(gun,kind):
    if kind.startswith("flag_"):
        center,toward,size=DETAILS[gun]
        if kind.endswith("grazing"):
            toward=(.94,-.21,.12 if gun=="Bulldog" else -.14)
        return Vector(center),Vector(toward),size
    placement=next(iter(layers(kind.split("_",1)[0],gun)))[0] if kind.startswith("Oilwake") else None
    lo,hi,bot,top=placement.bounds
    toward=Vector((.04,1,.23)) if kind.endswith("straight") else Vector((-.96,.20,.17))
    return Vector(((lo+hi)/2,.045,(bot+top)/2)),toward,max(.37,(hi-lo)*1.3)


def _cam(gun,view,line=None):
    points=M._pts(gun)
    specs={
        "hero":((.52,.72,.36),(0,0,1),False),
        "left":((0,1,0),(0,0,1),True),
        "right":((0,-1,0),(0,0,1),True),
        "held":((-.85,.34,.3),(0,0,1),False),
        "top":((0,0,1),(0,-1,0),True),
    }
    if view in specs:
        toward,up,ortho=specs[view]
        lens=50 if view=="held" else 60
        return M._cam(gun,"Reskin_"+view,points,toward,up,ortho=ortho,lens=lens,aspect=16/9,margin=1.10)
    if view=="aim":
        cam=bpy.data.objects.get(gun+"_Cam_ADS") or bpy.data.objects.get(gun+"_FP_ADS")
        if cam is None and gun in F.ADS:
            cam=F.ads_cam(gun)
        if cam is None:
            # This stock model sheet uses a three-quarter sight inspection.
            return M._cam(gun,"Reskin_sight_check",points,(-.35,.5,.8),lens=60,
                          aspect=16/9,margin=1.1)
        lo,hi=F.bounds(gun)
        return cam,(lo+hi)/2,(hi-lo).length/2
    if view=="detail":
        placement=next(iter(layers(line,gun)))[0]
        a,b,c,d=placement.bounds
        ctr=Vector(((a+b)/2,.065,(c+d)/2))
        vec=Vector((.15,1,.24)).normalized()
        scale=max((b-a)*1.2,(d-c)*16/9*1.34,.33)
    else:
        ctr,vec,scale=_near(gun,view)
        vec=vec.normalized()
    cam=F.camera(gun,"Reskin_"+view,ctr+vec*3,ctr,ortho=scale,clip=.05)
    return cam,ctr,1.4


def capture(gun,view,path,line=None,culled=False):
    scene=bpy.context.scene
    cam, center, rad=_cam(gun,view,line)
    size=(1280,720) if view=="hero" else (896,504)
    path.parent.mkdir(parents=True,exist_ok=True)
    if culled:
        old=scene.render.engine,scene.render.film_transparent
        scene.render.engine="BLENDER_WORKBENCH"
        scene.render.film_transparent=True
        scene.render.image_settings.color_mode="RGBA"
        shade=scene.display.shading
        shade.light="STUDIO"
        shade.color_type="MATERIAL"
        shade.show_backface_culling=True
        scene.display.render_aa="8"
        try:
            F.shot(gun,cam,str(path),res=size,rng=False)
        finally:
            scene.render.engine,scene.render.film_transparent=old
    else:
        M._lights(gun,cam,center,rad)
        M._shot(gun,cam,str(path),size,studio=True,samples=24)


def _active_preview(gun):
    return {m.name:next((n.name for n in m.node_tree.nodes if n.type=="OUTPUT_MATERIAL" and n.is_active_output),None)
            for m in bake.gun_materials(gun)}


def _source_finish(gun):
    sc=bpy.context.scene
    cam,target,r=_cam(gun,"hero")
    M._lights(gun,cam,target,r)
    bpy.data.collections[gun+"_RV2_Lights"].hide_render=True
    bpy.data.collections[gun+"_MS_Lights"].hide_render=False
    bpy.data.collections[gun+"_RV2_ADSRange"].hide_render=True
    sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value=1.6
    sc.render.film_transparent=True
    sc.render.engine="BLENDER_EEVEE"
    sc.camera=cam
    sc.render.resolution_x,sc.render.resolution_y=1280,720
    sc.render.resolution_percentage=100
    sc.render.filepath="//review/"
    sc.cycles.samples=32
    sc.cycles.use_denoising=True
    for area in bpy.context.window.screen.areas:
        if area.type=="VIEW_3D":
            area.spaces.active.region_3d.view_perspective="CAMERA"
            area.spaces.active.shading.type="MATERIAL"


def finish(line,gun,version="v01"):
    sc=bpy.context.scene
    assert Path(bpy.data.filepath).resolve()==source(gun).resolve()
    dest=destination(line,gun,version)
    assert not dest.exists(),dest
    objs=roster.mesh_objects(gun)
    baseline=roster.fingerprints(gun)
    uv=relocate(objs,APPROVED if gun=="Bulldog" else None)
    before=roster.fingerprints(gun)
    assert {k for k in before if before[k]!=baseline[k]}<=({"uv"} if uv["parts"] else set())
    descriptions,protected=author(line,gun,objs)
    dest.mkdir(parents=True)
    bake.RES=2048 if (line,gun) in {("Oilwake","Phantom"),("Faultline","Sheriff")} or gun=="Bulldog" else 1536
    with bpy.context.temp_override(object=objs[0],active_object=objs[0],selected_objects=objs,selected_editable_objects=objs):
        roster.bake_maps(gun,sc,objs,dest/"textures")
    assert roster.fingerprints(gun)==before
    for m in bake.gun_materials(gun):
        normal=m.node_tree.nodes.get("PV_Normal")
        if normal and normal.outputs["Color"].links:
            normal.outputs["Color"].links[0].to_node.uv_map=objs[0].data.uv_layers.active.name
    if line=="Oilwake":
        _add_oil_shift(gun,descriptions)
    _source_finish(gun)
    target=dest/f"{gun}_{line}_{version}.blend"
    assert bpy.ops.wm.save_as_mainfile(filepath=str(target),compress=True,relative_remap=False)=={"FINISHED"}
    report={
        "line":line,"gun":gun,"version":version,"source":roster.rel(source(gun)),
        "source_sha256":sha(source(gun)),"blend":roster.rel(target),"blend_sha256":sha(target),
        "concept":roster.rel(roster.VAULT/CONCEPTS[line]),"model_sheet":roster.rel(ART/"ModelSheets"/f"{gun}_model_sheet.png"),
        "source_fingerprints":baseline,"baked_fingerprints":before,"uv_audit":uv,"triangles":F.tris(gun),
        "finish_hosts":[{"parts":{k:sorted(v) for k,v in p.parts.items()},"bounds_xz":p.bounds} for p,_,_ in descriptions],
        "protected_parts":sorted(protected),"palette_srgb_roughness_metalness":PALETTES[line],
        "animation_actions":sorted(bpy.data.actions.keys()),"map_resolution":bake.RES,"padding_pixels":6,
        "review_state":"Bake saved, reopen pending",
    }
    if gun in FIXED:
        report["source_repair"]=roster.rel(FIXED[gun].parent/"repair.json")
    if line=="Oilwake":
        report["oilwake_preview"]="Baked PBR base with localized Blender Layer Weight coating; 4 maps contain static petrol/amber fallback."
    roster.write_json(dest/"manifest.json",report)
    return {"blend":report["blend"],"moved_uv_parts":list(uv["parts"]),"resolution":bake.RES}


def _topology(gun):
    objs=roster.mesh_objects(gun)
    zero=[]
    crossed=[]
    for ob in objs:
        for f in ob.data.polygons:
            if f.area<1e-10:
                zero.append((ob.name,f.index))
            elif len(f.vertices)>3:
                n=f.normal
                u=n.cross(Vector((1,0,0)) if abs(n.x)<.9 else Vector((0,1,0))).normalized()
                v=n.cross(u)
                if _crosses([(ob.data.vertices[i].co.dot(u),ob.data.vertices[i].co.dot(v)) for i in f.vertices]):
                    crossed.append((ob.name,f.index))
    return {"zero_area":zero,"crossed":crossed,"coplanar_candidates":resolve_coplanar(objs,dry=True)}


def _aim(gun):
    cam,_,_=_cam(gun,"aim")
    bpy.context.view_layer.update()
    kind="Model sheet three-quarter sight check" if "sight_check" in cam.name else "Stock Blender aim camera"
    return {"name":cam.name,"matrix_world":[list(row) for row in cam.matrix_world],
            "near_clip":cam.data.clip_start,"lens_mm":cam.data.lens,"view_kind":kind}


def _skin_review(line,gun,review):
    for view in ("hero","left","right","held","aim","top","detail"):
        capture(gun,view,review/(view+".png"),line)
    for view in ("left","right"):
        capture(gun,view,review/(view+"-culled.png"),line,culled=True)
    if line=="Oilwake":
        for view in ("Oilwake_straight","Oilwake_grazing"):
            capture(gun,view,review/(view+".png"),line)
        if gun=="Phantom":
            set_oil_shift(gun,False)
            try:
                capture(gun,"hero",review/"static-fallback.png",line)
            finally:
                set_oil_shift(gun,True)
    if gun in DETAILS:
        for view in ("flag_owner","flag_grazing"):
            capture(gun,view,review/(view+".png"),line)
            capture(gun,view,review/(view+"-culled.png"),line,culled=True)


def stock_review(gun):
    report_path=REVIEW/"stock"/gun/"baseline.json"
    if report_path.exists():
        return json.loads(report_path.read_text(encoding="utf-8"))
    open_file(source(gun))
    scene=bpy.context.scene
    fingerprints=roster.fingerprints(gun)
    topology=_topology(gun)
    aim=_aim(gun)
    for view in ("hero","left","right","held","aim","top"):
        capture(gun,view,report_path.parent/(view+".png"))
    if gun in DETAILS:
        for view in ("flag_owner","flag_grazing"):
            capture(gun,view,report_path.parent/(view+".png"))
    pose={"file":roster.rel(source(gun)),"fingerprints":fingerprints,"aim":aim,"topology":topology,"triangles":F.tris(gun)}
    roster.write_json(report_path,pose)
    return pose


def verify(line,gun,version="v01"):
    dest=destination(line,gun,version)
    record=dest/"manifest.json"
    manifest=json.loads(record.read_text(encoding="utf-8"))
    base=stock_review(gun)
    target=ROOT/manifest["blend"]
    open_file(target)
    assert roster.fingerprints(gun)==manifest["baked_fingerprints"]
    assert manifest["source_fingerprints"]==base["fingerprints"]
    aim=_aim(gun)
    assert {k:aim[k] for k in base["aim"]}==base["aim"]
    assert F.tris(gun)==base["triangles"]==manifest["triangles"]
    texture={}
    for name in bake.MAPS:
        im=bpy.data.images[gun+"_"+name]
        path=dest/"textures"/f"{gun}_{name}.png"
        assert im.packed_file and im.packed_file.data==path.read_bytes()
        assert tuple(im.size)==(manifest["map_resolution"],)*2
        texture[name]={"path":roster.rel(path),"sha256":sha(path),"color_space":im.colorspace_settings.name}
    topo=_topology(gun)
    assert topo==base["topology"],(topo,base["topology"])
    review=dest/"review"
    _skin_review(line,gun,review)
    manifest.update(
        maps=texture,topology_and_stock_candidates=topo,
        aim_camera=base["aim"],active_material_outputs=_active_preview(gun),
        review_renders=roster.rel(review),matched_stock_renders=roster.rel(REVIEW/"stock"/gun),
        review_state="Baked, reopened and rendered. Visual review pending",
    )
    roster.write_json(record,manifest)
    return {"variant":f"{line} {gun} {version}","triangles":manifest["triangles"],
            "stock_candidates":len(topo["coplanar_candidates"]),
            "rendered":len(list(review.glob("*.png")))}
