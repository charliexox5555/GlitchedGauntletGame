# Tempest-Strike Vandal s03, stage D: layered blade fins on the handguard front, kashira grip cap,
# magazine hydro ring. Run after stages A, B, C. Idempotent for TSD_ parts.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_vandal/tv_s_lib.py").read())
purge(("TSD_",))

# ---------- layered fins: two stacked silver blades on the handguard's upper band, pointing forward ----------
for s in (1, -1):
	surface_plate("Vandal_Handguard", "TSD_Fin1%+d" % s,
		[(1.300, 0.398), (1.640, 0.398), (1.684, 0.372), (1.630, 0.346), (1.360, 0.356)], s, lift=0.0008, thick=0.005)
	surface_plate("Vandal_Handguard", "TSD_Fin2%+d" % s,
		[(1.440, 0.392), (1.615, 0.392), (1.650, 0.374), (1.600, 0.358), (1.470, 0.364)], s, lift=0.0062, thick=0.0045)
	surface_plate("Vandal_Handguard", "TSD_FinLine%+d" % s,
		[(1.320, 0.3505), (1.600, 0.3445), (1.604, 0.3475), (1.320, 0.3535)], s, lift=0.0004, thick=0.0016, mat="Neon")

# ---------- kashira grip cap: faceted silver pommel with a pointed heel ----------
def zb(x):            # stock grip bottom face is a slope from (-0.149, -0.301) to (-0.009, -0.306)
	return -0.301 + (x + 0.149) / 0.140 * (-0.005)
def hexring(xf, xr, xp, hw, dz, sc=1.0):
	pts = [(xf, hw), (xr, hw), (xp, 0.0), (xr, -hw), (xf, -hw), (xf + 0.010, 0.0)]
	return [(x, y * sc, zb(x) + dz) for x, y in pts]
bm = loft([hexring(-0.004, -0.146, -0.166, 0.051, 0.004), hexring(-0.002, -0.150, -0.172, 0.053, -0.006),
	hexring(-0.010, -0.142, -0.178, 0.046, -0.020), hexring(-0.022, -0.132, -0.170, 0.036, -0.026)])
new_obj("TSD_GripCap", bm, "Panel", like="Vandal_Grip")
bm = loft([hexring(-0.003, -0.148, -0.169, 0.0525, -0.0005), hexring(-0.003, -0.148, -0.169, 0.0525, -0.0035)])
new_obj("TSD_GripCapLine", bm, "Neon", like="Vandal_Grip", bevel=0)

# ---------- magazine: hydro ring just above the baseplate (rides the Mag bone) ----------
mag = bpy.data.objects["Vandal_Mag"]
ax = Vector((0.30, 0, -0.954)).normalized()
mw = mag.matrix_world; mi = mw.inverted()
bm = bmesh.new(); bm.from_mesh(mag.data); bm.transform(mw)
for d in (0.574, 0.586):
	bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=ax * d, plane_no=ax)
keep = {f for f in bm.faces if 0.574 < f.calc_center_median().dot(ax) < 0.586 and abs(f.normal.dot(ax)) < 0.75}
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context="FACES")
bm.transform(mi)
me = bpy.data.meshes.new("TSD_MagRing"); bm.to_mesh(me); bm.free()
p = bpy.data.objects.new("TSD_MagRing", me); TS.objects.link(p)
p.parent = mag.parent; p.parent_type = mag.parent_type; p.parent_bone = mag.parent_bone
p.matrix_parent_inverse = mag.matrix_parent_inverse.copy(); p.matrix_basis = mag.matrix_basis.copy()
me.materials.append(M("Neon"))
so = p.modifiers.new("Thick", "SOLIDIFY"); so.thickness = 0.0028; so.offset = 1.0; so.use_quality_normals = True
bpy.ops.wm.save_mainfile()
result = {"made": sorted(o.name for o in TS.objects if o.name.startswith("TSD_"))}
