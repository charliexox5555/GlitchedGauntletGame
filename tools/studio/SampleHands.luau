--!strict
-- Dev tool, not shipped. Samples the first-person arm blocks against the gun
-- in hand for tools/blender/check_hand_clipping.py (the exact mesh test).
--
-- Clients can't make HTTP requests, so the samples go through a playtest-only
-- relay. Setup (Studio, Edit mode; remove both before saving the place):
--   1. Run tools/studio/receive_server.py (it writes the JSON into the repo).
--   2. A Script in ServerScriptService named DevHandSinkScript with SINK below.
--   3. This file as a ModuleScript ReplicatedStorage.DevHandTools.
-- Then, in a playtest's Client (MCP execute_luau):
--   local T = require(game.ReplicatedStorage.DevHandTools)
--   T.pick("Vandal")                         -- the weapon picker's remote
--   T.run("hold")                            -- one sample of the hold
--   T.run("inspect", 3, 1/40, "inspect")     -- sample 3 s of the inspect
--   T.run("draw", 1, 1/60, "draw")           -- the first draw (rack)
--   T.run("reload", 2.7, 1/40, "reload")     -- after firing a round
-- Actions go through the Studio-only Workspace attribute DevAction
-- (WeaponController). Output: art-source/viewmodel/checks/<Id>_<mode>.json;
-- check with: blender --background --factory-startup --python
--   tools/blender/check_hand_clipping.py -- art-source/viewmodel/checks/*.json
--
-- Each sample stores, per arm and per gun joint, the arm block in that
-- joint's REST frame (handle space, model scale), so each mesh part can be
-- tested at rest in Blender.
--
-- SINK (the DevHandSinkScript source):
--[[
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
if not game:GetService("RunService"):IsStudio() then return end
local ev = Instance.new("RemoteEvent"); ev.Name = "DevHandSink"; ev.Parent = RS
local status = Instance.new("StringValue"); status.Name = "DevHandStatus"; status.Parent = RS
ev.OnServerEvent:Connect(function(player, path, body)
	if typeof(path) ~= "string" or typeof(body) ~= "string" then return end
	local ok, res = pcall(function()
		return Http:RequestAsync({ Url = "http://127.0.0.1:34999/save?path=" .. path, Method = "POST", Body = body }).Body
	end)
	status.Value = tostring(res)
end)
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local T = {}
local function rows(cf)
	local out = {}
	for _, v in { cf:GetComponents() } do table.insert(out, math.round(v * 100000) / 100000) end
	return out
end
local function setup()
	local cam = workspace.CurrentCamera
	local vm = cam:FindFirstChild("Viewmodel")
	local id = Players.LocalPlayer:GetAttribute("WeaponId")
	local orig = ReplicatedStorage.Weapons:FindFirstChild(id)
	local handle = vm:FindFirstChild("Handle")
	local scale = 1
	for _, p in vm:GetChildren() do
		if p:IsA("MeshPart") then
			local o = orig:FindFirstChild(p.Name)
			if o then scale = p.Size.X / o.Size.X; break end
		end
	end
	local rest = { [handle] = CFrame.identity }
	local joints = {}
	local pending = vm.Rig.Motors:GetChildren()
	while #pending > 0 do
		local progressed = false
		for i = #pending, 1, -1 do
			local m = pending[i]
			local base = m.Part0 and rest[m.Part0]
			if base and m.Part1 then
				rest[m.Part1] = base * m.C0; joints[m.Name] = m.Part1
				table.remove(pending, i); progressed = true
			end
		end
		if not progressed then break end
	end
	return { cam = cam, vm = vm, id = id, handle = handle, scale = scale, rest = rest, joints = joints }
end
local function sample(label, ctx)
	local arms = ctx.cam:FindFirstChild("ViewmodelArms")
	local frame = { label = label, arms = {} }
	for _, side in { "Right", "Left" } do
		local arm = arms and arms:FindFirstChild(side .. "Arm")
		if arm and arm.LocalTransparencyModifier < 1 then
			local a = ctx.handle.CFrame:ToObjectSpace(arm.CFrame)
			local per = {}
			for name, part in ctx.joints do
				local now = ctx.handle.CFrame:ToObjectSpace(part.CFrame)
				local rel = ctx.rest[part] * now:Inverse() * a
				per[name] = rows(rel - rel.Position + rel.Position / ctx.scale)
			end
			frame.arms[side] = per
		end
	end
	return frame
end
function T.run(mode, duration, step, action)
	if action == "draw" then
		-- the draw rebuilds the viewmodel: start it, then read the new one
		workspace:SetAttribute("DevAction", action)
		action = nil
		task.wait()
	end
	local ctx = setup()
	local frames = {}
	if mode == "hold" then
		table.insert(frames, sample("hold", ctx))
	else
		if action then workspace:SetAttribute("DevAction", action) end
		local t0 = os.clock()
		while os.clock() - t0 < (duration or 3) do
			table.insert(frames, sample(string.format("%s %.2f", mode, os.clock() - t0), ctx))
			task.wait(step or 1 / 30)
		end
	end
	local body = HttpService:JSONEncode({ id = ctx.id, mode = mode, scale = ctx.scale, half = { 0.25 / ctx.scale, 1.25 / ctx.scale, 0.25 / ctx.scale }, frames = frames })
	local status = ReplicatedStorage:WaitForChild("DevHandStatus")
	status.Value = ""
	ReplicatedStorage.DevHandSink:FireServer("art-source/viewmodel/checks/" .. ctx.id .. "_" .. mode .. ".json", body)
	local t = os.clock()
	while status.Value == "" and os.clock() - t < 5 do task.wait() end
	return string.format("%s %s: %d frames, %s", ctx.id, mode, #frames, status.Value)
end
function T.pick(id, wait)
	require(ReplicatedStorage.Shared.Net).event("PickWeapon"):FireServer(id)
	task.wait(wait or 2.3)
end
return T
