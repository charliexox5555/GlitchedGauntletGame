# Tempest-Strike Bucky s02 (on s01): silver raked cowl plate on the upper right side ahead of the ejection port (the
# armoured receiver's second layer, balancing the left shell carrier); the stock pin under it removed.
import bpy
GUN = "Bucky"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/Skins/TempestStrike/Bucky/s01/Bucky_TempestStrike_s01.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
purge(("TS2_",))
COWL = [(0.764, 0.270), (0.902, 0.270), (0.946, 0.300), (0.902, 0.390), (0.764, 0.390), (0.750, 0.330)]
new_obj("TS2_Cowl-1", chamfer_prism_xz(COWL, -0.0795, -0.0715, 0.0016), "Panel", bevel=0)
new_obj("TS2_CowlHydro-1", prism_xz([(0.776, 0.2465), (0.905, 0.2465), (0.918, 0.2505), (0.776, 0.2505)], -0.0745, -0.0720), "Neon", bevel=0)
pins = bpy.data.objects["TS_Pins"]
bm, _ = stock_bm(pins.name)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x > 0.9 and v.co.y < 0], context="VERTS")
write_bm(pins, bm)
# pump rear cap: its rear face shared the core's rear plane (audit: coplanar) -> stands 0.003 behind it
kill("TS_PumpCapRear")
sec = poly_offset(octo(0.080, 0.108, 0.16, cz=0.2055), 0.0024)
new_obj("TS_PumpCapRear", loft([ring_x(1.233, sec), ring_x(1.258, sec)]), "Panel", like="Bucky_Pump", bevel=0)
bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model())}
