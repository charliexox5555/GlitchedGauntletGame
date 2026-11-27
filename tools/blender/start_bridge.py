"""Start the Blender MCP bridge of a NEW Blender window on its own port, so another open Blender (another project's
file holding 127.0.0.1:9876) is never touched (memory: blender-mcp-two-instances). The saved add-on preferences
are not changed.

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --python tools/blender/start_bridge.py -- 9877

Then drive it with: python tools/blender/lobby_v4/send.py <file.py> --port 9877 --pid <pid>
"""
import importlib
import sys

import bpy

PORT = 9877
if "--" in sys.argv:
	args = sys.argv[sys.argv.index("--") + 1 :]
	if args:
		PORT = int(args[0])


def _go():
	srv = importlib.import_module("bl_ext.user_default.mcp.mcp_to_blender_server")
	ei = importlib.import_module("bl_ext.user_default.mcp.execute_interactive")
	if srv.is_running():
		srv.stop()
	srv.timer_internal_vars_calc(active=0.02, idle=0.25, idle_delay=10.0)
	srv.start("localhost", PORT)
	if not bpy.app.timers.is_registered(ei.run):
		bpy.app.timers.register(ei.run, first_interval=0.05, persistent=True)
	print(f"[start_bridge] MCP bridge on localhost:{PORT}")
	return None


bpy.app.timers.register(_go, first_interval=4.0)
