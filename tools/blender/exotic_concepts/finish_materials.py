"""Bundle materials and side graphics for the offline Blender model pass."""

import bpy

from designs import LINES


# Roughness range, metalness and surface-grain scale for each material role.
SURFACES = {
    "Spindrift": {
        "Shell": (.46, .62, .27, 70), "Face plates": (.22, .37, .68, 130),
        "Active insert": (.14, .24, .18, 92), "Accent": (.42, .56, .32, 105),
        "Smoked seat": (.27, .43, .36, 92),
    },
    "Kilnlock": {
        "Shell": (.52, .67, .48, 82), "Face plates": (.54, .73, .08, 110),
        "Active insert": (.23, .36, .16, 92), "Accent": (.34, .51, .68, 112),
        "Smoked seat": (.43, .57, .4, 94),
    },
    "Stacklight": {
        "Shell": (.40, .54, .18, 125), "Face plates": (.29, .41, .12, 150),
        "Active insert": (.19, .25, .18, 130), "Accent": (.33, .46, .25, 155),
        "Smoked seat": (.26, .39, .16, 155),
    },
}


PARTS = {
    "Vandal": ("Receiver", "Handguard", "Stock"), "Odin": ("Receiver", "Stock", "AmmoBox"),
    "Phantom": ("Receiver", "Handguard", "Stock"), "Spectre": ("Receiver", "Handguard", "Stock"),
    "Ghost": ("Frame", "Slide"), "Marshal": ("Receiver", "ForeEnd", "Stock"),
    "Guardian": ("Receiver", "Handguard", "Stock"), "Bucky": ("Receiver", "Pump", "Stock"),
    "Bulldog": ("Receiver", "Handguard", "Stock"), "Shorty": ("Frame", "Barrels"),
    "Sheriff": ("Frame", "Barrel"), "Judge": ("Receiver", "Handguard", "Stock"),
    "Stinger": ("Receiver", "Stock"), "Classic": ("Frame", "Slide"),
    "Outlaw": ("Receiver", "ForeEnd", "Stock"), "Ares": ("Receiver", "Handguard", "Stock"),
    "Operator": ("Receiver", "Handguard", "Stock"),
}


def linear(code):
    values=[int(code[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in values)+(1,)


def finish_surface(mat,line):
    if not mat.use_nodes or mat.get("Exotic finish"):
        return
    role=mat.name.split(" / ")[-1].split(".")[0]
    if role not in SURFACES[line] and not any(k in mat.name.lower() for k in (
            "acrylic","glazed","shuttle","status ring","elastomer","protected hard surface","pose proxy")):
        return
    knobs=SURFACES[line].get(role,(.24,.43,.18,125))
    lo,hi,metal,scale=knobs
    if role=="Elastomer" or mat.name.startswith("Pose proxy"):
        lo,hi,metal,scale=.62,.82,0,160
    if role=="Protected hard surface":
        lo,hi,metal,scale=.41,.58,.55,105
    tree=mat.node_tree
    shader=tree.nodes.get("Principled BSDF")
    if shader is None:
        return
    shader.location=(540,160)
    output=tree.nodes.get("Material Output")
    output.location=(880,160)
    tex=tree.nodes.new("ShaderNodeTexCoord")
    tex.label="Local material coordinates"
    tex.location=(-670,110)
    noise=tree.nodes.new("ShaderNodeTexNoise")
    noise.label="Fine surface grain"
    noise.location=(-450,100)
    noise.inputs["Scale"].default_value=scale
    noise.inputs["Detail"].default_value=2
    tree.links.new(tex.outputs["Object"],noise.inputs["Vector"])
    rough=tree.nodes.new("ShaderNodeMapRange")
    rough.label="Finish roughness"
    rough.location=(-200,120)
    rough.inputs["To Min"].default_value=lo
    rough.inputs["To Max"].default_value=hi
    tree.links.new(noise.outputs["Fac"],rough.inputs["Value"])
    tree.links.new(rough.outputs[0],shader.inputs["Roughness"])
    bump=tree.nodes.new("ShaderNodeBump")
    bump.label="Subtle cast and tool marks"
    bump.location=(230,-45)
    bump.inputs["Strength"].default_value=.10 if role not in ("Active insert","Smoked seat") else .025
    bump.inputs["Distance"].default_value=.008
    tree.links.new(noise.outputs["Fac"],bump.inputs["Height"])
    tree.links.new(bump.outputs["Normal"],shader.inputs["Normal"])
    shader.inputs["Metallic"].default_value=metal
    if role=="Face plates" and line=="Spindrift":
        anisotropy=shader.inputs.get("Anisotropic")
        if anisotropy:
            anisotropy.default_value=.27
    if line=="Stacklight" and any(k in mat.name.lower() for k in ("acrylic","shuttle","glazed")):
        shader.inputs["Coat Weight"].default_value=.42
        shader.inputs["Coat Roughness"].default_value=.22
    if role=="Active insert":
        shader.inputs["Coat Weight"].default_value=.38
        if not shader.inputs["Emission Strength"].is_linked:
            shader.inputs["Emission Strength"].default_value=.72 if line=="Kilnlock" else .52
    mat["Exotic finish"]=line


def math_node(tree,operation,a,b=None):
    n=tree.nodes.new("ShaderNodeMath")
    n.operation=operation
    for i,value in enumerate((a,b)):
        if value is None:
            continue
        if isinstance(value,(int,float)):
            n.inputs[i].default_value=value
        else:
            tree.links.new(value,n.inputs[i])
    return n.outputs[0]


def band(tree,value,a,b):
    return math_node(tree,"MULTIPLY",math_node(tree,"GREATER_THAN",value,a),math_node(tree,"LESS_THAN",value,b))


def side_graphic(source,line,gun,part):
    mat=source.copy()
    mat.name=f"{line} / {gun} {part} finish"
    nodes=mat.node_tree
    shader=nodes.nodes["Principled BSDF"]
    # Generated bounds keep the stencil on this stock component. Its orientation
    # mask uses the local face normal, so it follows isolated animation channels.
    tex=next(n for n in nodes.nodes if n.type=="TEX_COORD")
    axes=nodes.nodes.new("ShaderNodeSeparateXYZ")
    normal=nodes.nodes.new("ShaderNodeNewGeometry")
    local=nodes.nodes.new("ShaderNodeVectorTransform")
    local.vector_type="NORMAL"
    local.convert_from,local.convert_to="WORLD","OBJECT"
    side=nodes.nodes.new("ShaderNodeSeparateXYZ")
    nodes.links.new(tex.outputs["Generated"],axes.inputs[0])
    nodes.links.new(normal.outputs["True Normal"],local.inputs[0])
    nodes.links.new(local.outputs[0],side.inputs[0])
    x,_,z=axes.outputs
    angle={"Spindrift":.23,"Kilnlock":.08,"Stacklight":.13}[line]
    z=math_node(nodes,"ADD",z,math_node(nodes,"MULTIPLY",x,angle))
    span=(.19,.78) if part not in ("Stock","Pump") else (.24,.72)
    limits={"Spindrift":(.63,.75),"Kilnlock":(.51,.79),"Stacklight":(.51,.77)}[line]
    if part in ("Frame","Slide","Barrels","Barrel"):
        limits=(.60,.75)
        span=(.24,.73)
    facing=math_node(nodes,"GREATER_THAN",math_node(nodes,"ABSOLUTE",side.outputs[1]),.69)
    surface=math_node(nodes,"MULTIPLY",facing,band(nodes,x,*span))
    color_mask=math_node(nodes,"MULTIPLY",surface,band(nodes,z,*limits))
    edge_mask=math_node(nodes,"MULTIPLY",surface,band(nodes,z,limits[1]+.020,limits[1]+.044))
    blend=nodes.nodes.new("ShaderNodeMixRGB")
    blend.label="Bundle face graphic"
    blend.inputs[1].default_value=shader.inputs["Base Color"].default_value
    dim,pale,lit,accent,smoked=LINES[line]
    fill=smoked if line=="Spindrift" else pale
    if part in ("Stock","Pump","Barrels","Barrel"):
        fill=smoked
    blend.inputs[2].default_value=linear(fill)
    nodes.links.new(color_mask,blend.inputs[0])
    edge=nodes.nodes.new("ShaderNodeMixRGB")
    edge.label="Machined registration stripe"
    edge.inputs[2].default_value=linear(pale if line=="Spindrift" else accent)
    nodes.links.new(edge_mask,edge.inputs[0])
    nodes.links.new(blend.outputs[0],edge.inputs[1])
    nodes.links.new(edge.outputs[0],shader.inputs["Base Color"])
    mat["Stencil part"]=part
    return mat


def finish_materials(line,item,stock=()):
    for mat in list(bpy.data.materials):
        finish_surface(mat,line)
    for ob in stock:
        part=ob.name.removeprefix(item+"_")
        if part not in PARTS.get(item,()):
            continue
        for slot in ob.material_slots:
            mat=slot.material
            if mat and mat.name.split(".")[0] in (f"{line} / Shell",f"{line} / Smoked seat"):
                slot.material=side_graphic(mat,line,item,part)
