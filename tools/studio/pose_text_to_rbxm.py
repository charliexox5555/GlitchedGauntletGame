"""Turn pose text printed by a Studio Make*Animations tool into KeyframeSequence
.rbxm files in art-source/animations/ (built with Rojo), ready for
tools/opencloud/upload_asset.py.

    python tools/studio/pose_text_to_rbxm.py poses.txt

Why: since 2026-11-04 the Studio assistant's HTTP allowlist blocks the
localhost receiver (receive_server.py), so the tools print compact text
instead of posting serialized clips.

One clip per line:
    Name|Priority|Loop|Length|t0>Joint:pitch,yaw,roll[,x,y,z];Joint:...|t1>...
Angles in degrees, CFrame.fromEulerAnglesYXZ (the Make*Animations
convention), offsets in studs. A line with no Loop / Length fields
(Name|Priority|Joint:...;...) is a held pose: looped, one second, the same
pose at 0 and 1. Keyframes ease linearly unless a joint entry ends in
"@style/direction" (e.g. "@Cubic/Out").
"""

import json
import math
import os
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "animations")

PARENT = {
	"LowerTorso": "HumanoidRootPart",
	"UpperTorso": "LowerTorso",
	"Head": "UpperTorso",
	"RightUpperArm": "UpperTorso",
	"RightLowerArm": "RightUpperArm",
	"RightHand": "RightLowerArm",
	"LeftUpperArm": "UpperTorso",
	"LeftLowerArm": "LeftUpperArm",
	"LeftHand": "LeftLowerArm",
	"RightUpperLeg": "LowerTorso",
	"RightLowerLeg": "RightUpperLeg",
	"RightFoot": "RightLowerLeg",
	"LeftUpperLeg": "LowerTorso",
	"LeftLowerLeg": "LeftUpperLeg",
	"LeftFoot": "LeftLowerLeg",
}


def matmul(a, b):
	return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def yxz(pitch, yaw, roll):
	x, y, z = (math.radians(v) for v in (pitch, yaw, roll))
	rx = [[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]]
	ry = [[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]]
	rz = [[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]]
	return matmul(matmul(ry, rx), rz)


def cframe(values):
	pitch, yaw, roll = values[0], values[1], values[2]
	pos = values[3:6] if len(values) >= 6 else [0, 0, 0]
	m = yxz(pitch, yaw, roll)
	value = {"position": [round(p, 5) for p in pos], "orientation": [[round(v, 6) for v in row] for row in m]}
	return {"CFrame": {"CFrame": value}}


def parse_joints(text):
	joints = {}
	for entry in filter(None, text.split(";")):
		name, rest = entry.split(":")
		style = None
		if "@" in rest:
			rest, style = rest.split("@")
		joints[name] = ([float(v) for v in rest.split(",")], style)
	return joints


def keyframe(time, joints):
	nodes = {}

	def node(name):
		if name in nodes:
			return nodes[name]
		n = {"name": name, "className": "Pose", "properties": {"Weight": 0.0, **cframe([0, 0, 0])}, "children": []}
		nodes[name] = n
		parent = PARENT.get(name)
		if parent:
			node(parent)["children"].append(n)
		return n

	for name, (values, style) in joints.items():
		n = node(name)
		n["properties"].update({"Weight": 1.0, **cframe(values)})
		if style:
			easing, direction = style.split("/")
			n["properties"]["EasingStyle"] = {"Enum": EASING[easing]}
			n["properties"]["EasingDirection"] = {"Enum": DIRECTION[direction]}
	children = [nodes["HumanoidRootPart"]] if "HumanoidRootPart" in nodes else []
	return {"name": "Keyframe", "className": "Keyframe", "properties": {"Time": time}, "children": children}


# Enum.PoseEasingStyle / Enum.PoseEasingDirection values.
EASING = {"Linear": 0, "Constant": 1, "Elastic": 2, "Cubic": 3, "Bounce": 4, "CubicV2": 5}
DIRECTION = {"In": 0, "Out": 1, "InOut": 2}
PRIORITY = {"Idle": 0, "Movement": 1, "Action": 2, "Core": 1000, "Action2": 3, "Action3": 4, "Action4": 5}


def build(line, tmp):
	fields = line.strip().split("|")
	name, priority = fields[0], fields[1]
	if len(fields) == 3:
		loop, frames = True, [(0.0, parse_joints(fields[2])), (1.0, parse_joints(fields[2]))]
	else:
		loop = fields[2] == "1"
		frames = []
		for part in fields[4:]:
			t, joints = part.split(">")
			frames.append((float(t), parse_joints(joints)))
	model = {
		"className": "KeyframeSequence",
		"properties": {"Loop": loop, "Priority": {"Enum": PRIORITY[priority]}},
		"children": [keyframe(t, j) for t, j in frames],
	}
	model_path = os.path.join(tmp, name + ".model.json")
	with open(model_path, "w") as f:
		json.dump(model, f)
	project_path = os.path.join(tmp, name + ".project.json")
	with open(project_path, "w") as f:
		json.dump({"name": name, "tree": {"$path": name + ".model.json"}}, f)
	out = os.path.join(OUT, name + ".rbxm")
	subprocess.run(["rojo", "build", project_path, "-o", out], check=True, capture_output=True)
	return out


def main():
	with open(sys.argv[1]) as f:
		lines = [line for line in f if line.strip() and not line.startswith("#")]
	with tempfile.TemporaryDirectory() as tmp:
		for line in lines:
			print(build(line, tmp))


if __name__ == "__main__":
	main()
