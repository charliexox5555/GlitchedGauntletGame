# Horizontal (z) or vertical (x) section extents of stock parts: {part: {z: [xmin, xmax, ymin, ymax]}}
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
Z = globals().get("Z", {}); X = globals().get("X", {})
def ext(name, co, no, xr=None):
	name = name.strip()
	o = bpy.data.objects[name]
	bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
	r = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=no)
	vs = [v.co.copy() for v in r["geom_cut"] if isinstance(v, bmesh.types.BMVert)]
	bm.free()
	if xr:
		vs = [v for v in vs if xr[0] <= v.x <= xr[1]]
	if not vs:
		return None
	return [round(min(v.x for v in vs), 4), round(max(v.x for v in vs), 4), round(min(v.y for v in vs), 4), round(max(v.y for v in vs), 4), round(min(v.z for v in vs), 4), round(max(v.z for v in vs), 4)]
out = {}
for n, (zs, xr) in Z.items():
	out[n + "@z"] = {z: ext(n, (0, 0, z), (0, 0, 1), xr) for z in zs}
for n, (xs, xr) in X.items():
	out[n + "@x"] = {x: ext(n, (x, 0, 0), (1, 0, 0), xr) for x in xs}
result = out
