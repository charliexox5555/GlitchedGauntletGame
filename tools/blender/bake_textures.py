# bake_textures.py: bakes one shared PBR texture set for a gun (Roblox SurfaceAppearance maps).
#
#   Run inside Blender with the gun's .blend open (Blender MCP or Text Editor):
#     g = {"__name__": "bake"}; exec(compile(open(path).read(), path, "exec"), g); g["bake"]("Vandal")
#
# The gun's parts must share one UV atlas (tools/blender/build_vandal.py packs them).
# Writes art-source/weapons/Textures/<Id>_{Color,Normal,Roughness,Metalness}.png (1024², Roblox's max):
#   Color      the material colour, ambient occlusion in slots and joins, subtly lighter worn edges
#   Normal     tangent space, OpenGL (+Y), as Roblox expects: polymer grain + rounded-edge shading
#   Roughness  per material, edges a touch smoother
#   Metalness  per material, panel edges a touch more metallic (worn anodising)
# Each material also gets a "PBR preview" output so EEVEE renders can show exactly the baked result
# (preview(gun, True/False) switches it).

import bpy, os

RES = 1024
MAPS = ("Color", "Normal", "Roughness", "Metalness")
EDGE_RADIUS = 0.006  # studs; matches the model's bevels
AO_DISTANCE = 0.06
AO_STRENGTH = 0.65  # 0 = no AO in the colour map
EDGE_LIGHTEN = 0.45  # how much lighter worn edges get


def out_dir():
	root = os.path.abspath(os.path.join(os.path.dirname(bpy.data.filepath), "..", ".."))
	d = os.path.join(root, "art-source", "weapons", "Textures")
	os.makedirs(d, exist_ok=True)
	return d


def gun_meshes(gun):
	return [o for o in bpy.data.collections[gun].all_objects if o.type == "MESH"]


def gun_materials(gun):
	mats = []
	for o in gun_meshes(gun):
		for s in o.material_slots:
			if s.material and s.material not in mats:
				mats.append(s.material)
	return mats


def source(nt, sock):
	# Output socket feeding `sock`, or None if it's a constant.
	return sock.links[0].from_socket if sock.is_linked else None


def setup_bake_nodes(m):
	# Adds the bake helpers once: edge mask, AO, and per-map emission values.
	nt = m.node_tree
	N = nt.nodes
	if N.get("BK_Emit"):
		return
	bsdf = next(n for n in N if n.bl_idname == "ShaderNodeBsdfPrincipled")
	out = next(n for n in N if n.bl_idname == "ShaderNodeOutputMaterial" and n.name != "BK_Out" and n.name != "PV_Out")
	out.name = "Shader_Out"

	def node(kind, name, **inputs):
		n = N.new(kind)
		n.name = name
		n.label = name
		for k, v in inputs.items():
			n.inputs[k].default_value = v
		return n

	geo = node("ShaderNodeNewGeometry", "BK_Geo")
	bev = node("ShaderNodeBevel", "BK_Bevel", Radius=EDGE_RADIUS)
	bev.samples = 16
	dot = node("ShaderNodeVectorMath", "BK_Dot")
	dot.operation = "DOT_PRODUCT"
	nt.links.new(bev.outputs["Normal"], dot.inputs[0])
	nt.links.new(geo.outputs["Normal"], dot.inputs[1])
	edge = node("ShaderNodeMapRange", "BK_Edge")
	edge.inputs["From Min"].default_value = 0.995
	edge.inputs["From Max"].default_value = 0.93
	edge.inputs["To Min"].default_value = 0
	edge.inputs["To Max"].default_value = 1
	edge.clamp = True
	nt.links.new(dot.outputs["Value"], edge.inputs["Value"])

	ao = node("ShaderNodeAmbientOcclusion", "BK_AO", Distance=AO_DISTANCE)
	ao.samples = 32
	ao_mix = node("ShaderNodeMapRange", "BK_AOMix")
	ao_mix.inputs["To Min"].default_value = 1 - AO_STRENGTH
	ao_mix.inputs["To Max"].default_value = 1
	nt.links.new(ao.outputs["AO"], ao_mix.inputs["Value"])

	# Colour: base * AO, lightened on edges.
	base_src = source(nt, bsdf.inputs["Base Color"])
	emis_src = source(nt, bsdf.inputs["Emission Color"])
	strength = bsdf.inputs["Emission Strength"].default_value
	base = node("ShaderNodeMix", "BK_Base")
	base.data_type = "RGBA"
	base.blend_type = "MIX"
	base.inputs[0].default_value = 0
	if strength > 0:
		# Neon: bake its glow colour (those parts use the Neon material in Roblox anyway).
		base.inputs[6].default_value = bsdf.inputs["Emission Color"].default_value
		if emis_src:
			nt.links.new(emis_src, base.inputs[6])
	elif base_src:
		nt.links.new(base_src, base.inputs[6])
	else:
		base.inputs[6].default_value = bsdf.inputs["Base Color"].default_value
	light = node("ShaderNodeMix", "BK_Edgelight")
	light.data_type = "RGBA"
	light.blend_type = "SCREEN"
	nt.links.new(base.outputs[2], light.inputs[6])
	light.inputs[7].default_value = (0.16, 0.165, 0.18, 1)
	fac = node("ShaderNodeMath", "BK_EdgeFac")
	fac.operation = "MULTIPLY"
	fac.inputs[1].default_value = EDGE_LIGHTEN if strength == 0 else 0
	nt.links.new(edge.outputs["Result"], fac.inputs[0])
	nt.links.new(fac.outputs["Value"], light.inputs[0])
	shade = node("ShaderNodeMix", "BK_Color")
	shade.data_type = "RGBA"
	shade.blend_type = "MULTIPLY"
	shade.inputs[0].default_value = 1 if strength == 0 else 0
	nt.links.new(light.outputs[2], shade.inputs[6])
	nt.links.new(ao_mix.outputs["Result"], shade.inputs[7])

	# Roughness: material value, edges smoother.
	rough_src = source(nt, bsdf.inputs["Roughness"])
	rough = node("ShaderNodeMath", "BK_Rough")
	rough.operation = "MULTIPLY_ADD"
	rough.use_clamp = True
	nt.links.new(edge.outputs["Result"], rough.inputs[0])
	rough.inputs[1].default_value = -0.12
	if rough_src:
		nt.links.new(rough_src, rough.inputs[2])
	else:
		rough.inputs[2].default_value = bsdf.inputs["Roughness"].default_value

	# Metalness: material value, edges of painted panels a touch more metallic.
	metal = node("ShaderNodeMath", "BK_Metal")
	metal.operation = "MULTIPLY_ADD"
	metal.use_clamp = True
	mv = bsdf.inputs["Metallic"].default_value
	nt.links.new(edge.outputs["Result"], metal.inputs[0])
	metal.inputs[1].default_value = 0.2 if 0.05 < mv < 0.6 else 0
	metal.inputs[2].default_value = mv

	# Normal: the existing bump (if any) on top of the rounded-edge normal.
	bump = next((n for n in N if n.bl_idname == "ShaderNodeBump"), None)
	if bump:
		nt.links.new(bev.outputs["Normal"], bump.inputs["Normal"])
	else:
		nt.links.new(bev.outputs["Normal"], bsdf.inputs["Normal"])

	emit = node("ShaderNodeEmission", "BK_Emit", Strength=1.0)
	bk_out = N.new("ShaderNodeOutputMaterial")
	bk_out.name = "BK_Out"
	nt.links.new(emit.outputs["Emission"], bk_out.inputs["Surface"])

	for name in MAPS:
		img = N.new("ShaderNodeTexImage")
		img.name = "BK_Img_" + name


def images(gun):
	out = {}
	for name in MAPS:
		key = f"{gun}_{name}"
		img = bpy.data.images.get(key)
		if img and (img.size[0] != RES):
			bpy.data.images.remove(img)
			img = None
		if not img:
			img = bpy.data.images.new(key, RES, RES, alpha=False, float_buffer=name == "Normal")
		img.colorspace_settings.name = "sRGB" if name == "Color" else "Non-Color"
		img.filepath_raw = os.path.join(out_dir(), key + ".png")
		img.file_format = "PNG"
		out[name] = img
	return out


def set_active_output(m, which):
	for n in m.node_tree.nodes:
		if n.bl_idname == "ShaderNodeOutputMaterial":
			n.is_active_output = n.name == which


def bake(gun="Vandal"):
	scene = bpy.context.scene
	prev_engine = scene.render.engine
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.use_denoising = False
	imgs = images(gun)
	mats = gun_materials(gun)
	for m in mats:
		setup_bake_nodes(m)

	objs = gun_meshes(gun)
	if bpy.context.object and bpy.context.object.mode != "OBJECT":
		bpy.ops.object.mode_set(mode="OBJECT")
	for o in bpy.context.view_layer.objects:
		o.select_set(False)
	for o in objs:
		o.hide_set(False)
		o.hide_render = False
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]

	feeds = {"Color": ("BK_Color", 2), "Roughness": ("BK_Rough", 0), "Metalness": ("BK_Metal", 0)}
	report = {}
	for name in MAPS:
		for m in mats:
			nt = m.node_tree
			img_node = nt.nodes["BK_Img_" + name]
			img_node.image = imgs[name]
			nt.nodes.active = img_node
			if name == "Normal":
				set_active_output(m, "Shader_Out")
			else:
				node, idx = feeds[name]
				nt.links.new(nt.nodes[node].outputs[idx], nt.nodes["BK_Emit"].inputs["Color"])
				set_active_output(m, "BK_Out")
		scene.cycles.samples = 64 if name == "Color" else 16
		bt = scene.render.bake
		bt.margin = 6
		bt.use_clear = True
		if name == "Normal":
			bt.normal_space = "TANGENT"
			bt.normal_r, bt.normal_g, bt.normal_b = "POS_X", "POS_Y", "POS_Z"
			bpy.ops.object.bake(type="NORMAL", margin=6, use_clear=True)
		else:
			bpy.ops.object.bake(type="EMIT", margin=6, use_clear=True)
		img = imgs[name]
		img.save(filepath=img.filepath_raw)  # the float normal bake is written as an 8-bit PNG
		report[name] = img.filepath_raw

	for m in mats:
		set_active_output(m, "Shader_Out")
	for o in objs:
		o.select_set(False)
	scene.render.engine = prev_engine
	preview_nodes(gun)
	return report


def preview_nodes(gun):
	# A second output per material that shows the baked maps (for EEVEE check renders).
	imgs = {name: bpy.data.images.get(f"{gun}_{name}") for name in MAPS}
	for m in gun_materials(gun):
		nt = m.node_tree
		N = nt.nodes
		if N.get("PV_Out"):
			continue
		emissive = next(n for n in N if n.bl_idname == "ShaderNodeBsdfPrincipled").inputs["Emission Strength"].default_value > 0
		if emissive:
			continue
		uv = N.new("ShaderNodeUVMap")
		bsdf = N.new("ShaderNodeBsdfPrincipled")
		bsdf.name = "PV_BSDF"
		out = N.new("ShaderNodeOutputMaterial")
		out.name = "PV_Out"
		nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
		for name, sock in (("Color", "Base Color"), ("Roughness", "Roughness"), ("Metalness", "Metallic"), ("Normal", None)):
			t = N.new("ShaderNodeTexImage")
			t.name = "PV_" + name
			t.image = imgs[name]
			nt.links.new(uv.outputs["UV"], t.inputs["Vector"])
			if sock:
				nt.links.new(t.outputs["Color"], bsdf.inputs[sock])
			else:
				nm = N.new("ShaderNodeNormalMap")
				nt.links.new(t.outputs["Color"], nm.inputs["Color"])
				nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])


def preview(gun="Vandal", on=True):
	for m in gun_materials(gun):
		if m.node_tree.nodes.get("PV_Out"):
			set_active_output(m, "PV_Out" if on else "Shader_Out")
