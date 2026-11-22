--!strict
-- The Locker's display tables and gun wall show YOUR skins (owner 2026-11-16, like RIVALS' weapons room: "each one
-- ... will be the skin of the gun you've selected"). Anchors tagged `LobbyGunDisplay` (tools/studio/lobby_v4/
-- Build_V4.luau from v4_core.gun_display) carry: Gun, Mount (Lay = on a table, Wall = on the pegboard, Stand =
-- centred and turning), the barrel BX/BY/BZ and the side that looks out FX/FY/FZ (Blender axes), Scale and Spin
-- (degrees a second). This client lays a copy of its own equipped skin of that gun there (Shared/Locker.skinModel,
-- from the LockerSkins value LobbyServer's LockerService sets) and swaps it when the loadout changes.
-- Client only: nothing is sent to the server. Copies live in a local folder, so StreamingEnabled never takes them;
-- when an anchor streams out its copy goes with it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")

local Locker = require(ReplicatedStorage.Shared.Locker)

local LobbyGunDisplays = {}

local TAG = "LobbyGunDisplay"
local SPIN_RANGE = 160 -- studs: a turning gun further than this from the camera holds still
local BOB = 0.15 -- studs up and down on a turning gun

type Shown = {
	model: Model?,
	line: string?,
	gun: string,
	spin: number,
	centre: Vector3?,
	base: CFrame?,
}

local shown: { [BasePart]: Shown } = {}
local folder: Folder? = nil

local function holder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "LobbyGunDisplays"
	f.Parent = workspace
	folder = f
	return f
end

local function num(p: Instance, key: string, default: number): number
	local v = StateValues.get(p, key)
	return if typeof(v) == "number" and v == v and math.abs(v) < 1e6 then v else default
end

-- Blender (x, y, z) is Roblox (x, z, -y), as the lobby builder exports it.
local function dir(p: Instance, kx: string, ky: string, kz: string, default: Vector3): Vector3
	local v = Vector3.new(num(p, kx, 0), num(p, kz, 0), -num(p, ky, 0))
	return if v.Magnitude > 1e-3 then v.Unit else default
end

local function lineFor(gun: string): string
	return Locker.equipped(Players.LocalPlayer)[gun] or "Stock"
end

local function strip(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif
			d:IsA("BaseScript")
			or d:IsA("Sound")
			or d:IsA("ProximityPrompt")
			or d:IsA("ParticleEmitter")
		then
			d:Destroy()
		end
	end
end

local function clear(s: Shown)
	if s.model then
		s.model:Destroy()
		s.model = nil
	end
	s.line = nil
	s.centre = nil
	s.base = nil
end

-- Lays (or hangs, or stands) the player's skin of the anchor's gun at the anchor.
local function place(anchor: BasePart, s: Shown)
	local line = lineFor(s.gun)
	if s.model and s.line == line then
		return
	end
	clear(s)
	local src = Locker.skinModel(s.gun, line) or Locker.gunModel(s.gun)
	if not src then
		return
	end
	local m = src:Clone()
	strip(m)
	m.PrimaryPart = nil
	m:PivotTo(CFrame.new())
	local scale = num(anchor, "Scale", 1)
	local fill = num(anchor, "Fill", 0)
	if fill > 0 then -- aim for a length, never past Scale (a pistol stays a pistol)
		local _, raw = m:GetBoundingBox()
		local long = math.max(raw.X, raw.Y, raw.Z)
		if long > 0.1 then
			scale = math.min(scale, fill / long)
		end
	end
	if scale > 0 and scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	local barrel = dir(anchor, "BX", "BY", "BZ", Vector3.xAxis)
	local face = dir(anchor, "FX", "FY", "FZ", Vector3.yAxis)
	if math.abs(barrel:Dot(face)) > 0.99 then
		return
	end
	face = (face - barrel * barrel:Dot(face)).Unit
	-- The gun's own axes from its shape, not its pivot (stock guns point the barrel along -Z, skin models often
	-- along X): the longest box side is the barrel (its sign from the Muzzle attachment), the middle one is up, the
	-- thinnest is the side that faces out.
	local box0, size0 = m:GetBoundingBox()
	local axes =
		{ { Vector3.xAxis, size0.X }, { Vector3.yAxis, size0.Y }, { Vector3.zAxis, size0.Z } }
	table.sort(axes, function(a, b)
		return a[2] > b[2]
	end)
	local bLocal: Vector3 = axes[1][1]
	local muzzle = m:FindFirstChild("Muzzle", true)
	local tip = if muzzle and muzzle:IsA("Attachment") then muzzle.WorldPosition else nil
	if tip then
		if (tip - box0.Position):Dot(bLocal) < 0 then
			bLocal = -bLocal
		end
	elseif bLocal == Vector3.zAxis then
		bLocal = -bLocal -- our convention: barrel along -Z
	end
	local uLocal: Vector3 = axes[2][1]
	if uLocal:Dot(Vector3.yAxis) < 0 then
		uLocal = -uLocal
	end
	-- Up from the sights where the gun has them (they sit on top, and the raw model's Y is not a reliable up:
	-- the guns were showing upside down on the displays). Sightless guns keep the rule above.
	local sightSum, sightCount = Vector3.zero, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "Sight") then
			sightSum += d.Position - box0.Position
			sightCount += 1
		end
	end
	-- Sightless guns: the bore (Muzzle) sits above the middle of the box, since the grip and mag hang below
	-- (measured on all 226 gun/line models 2026-11-22; skin copies are stored on their side, up along -Z).
	local upHint = if sightCount > 0
		then sightSum / sightCount
		elseif tip then tip - box0.Position
		else Vector3.zero
	if upHint:Dot(uLocal) < 0 then
		uLocal = -uLocal
	end
	local sLocal = bLocal:Cross(uLocal) -- the gun's right side
	local fromGun = CFrame.fromMatrix(Vector3.zero, sLocal, uLocal, -bLocal)
	-- its right side looks out along `face`, its barrel along `barrel`
	local toWorld = CFrame.fromMatrix(Vector3.zero, face, (-barrel):Cross(face), -barrel)
	local rot = toWorld * fromGun:Inverse()
	m:PivotTo(rot)
	local cf, size = m:GetBoundingBox()
	local pos = anchor.Position
	local centre = cf.Position
	local offset: Vector3
	if StateValues.get(anchor, "Mount") == "Stand" then
		offset = pos - centre
	else
		-- its back rests on the anchor's plane, centred on the anchor across it
		local lo = math.huge
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = cf:PointToWorldSpace(size * 0.5 * Vector3.new(sx, sy, sz))
					lo = math.min(lo, corner:Dot(face))
				end
			end
		end
		local d = pos - centre
		offset = (d - face * d:Dot(face)) + face * (pos:Dot(face) + 0.02 - lo)
	end
	m:PivotTo(rot + offset)
	m.Name = s.gun
	m.Parent = holder()
	s.model = m
	s.line = line
	s.centre = centre + offset
	s.base = m:GetPivot()
end

local function track(inst: Instance)
	if not inst:IsA("BasePart") or shown[inst] then
		return
	end
	local gun = StateValues.get(inst, "Gun")
	if typeof(gun) ~= "string" then
		return
	end
	local s: Shown = { gun = gun, spin = num(inst, "Spin", 0) }
	shown[inst] = s
	place(inst, s)
end

local function untrack(inst: Instance)
	local s = inst:IsA("BasePart") and shown[inst :: BasePart]
	if s then
		clear(s)
		shown[inst :: BasePart] = nil
	end
end

-- Turning guns (Spin): about the world up axis through their centre, with a small bob.
local function step()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local t = os.clock()
	for _, s in shown do
		local rate = s.spin
		local m, c, base = s.model, s.centre, s.base
		if rate ~= 0 and m and c and base then
			if (cam.CFrame.Position - c).Magnitude > SPIN_RANGE then
				continue
			end
			local turn = CFrame.new(c) * CFrame.Angles(0, math.rad(rate * t), 0) * CFrame.new(-c)
			m:PivotTo((turn * base) + Vector3.new(0, math.sin(t * 1.4) * BOB, 0))
		end
	end
end

function LobbyGunDisplays.start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)
	for _, a in CollectionService:GetTagged(TAG) do
		track(a)
	end
	Locker.observe(Players.LocalPlayer, function()
		for anchor, s in shown do
			place(anchor, s)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return LobbyGunDisplays
