--!strict
-- Shell casings, split out of Controllers/EffectsController (which forwards
-- EffectsController.ejectShell here and calls step() every frame). Owns the
-- shell pool: anchored parts flown by hand (no physics), with one bounce, and
-- the raycast filter that keeps them off our own character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)

local Kit = require(script.Parent.ShotFxKit)

type WeaponConfig = Types.WeaponConfig

local ShellFx = {}

local player = Players.LocalPlayer

local BRASS = Color3.fromHex("8F7A47") -- reads as brass in direct sun
local SHELL_POOL = 32
local SHELL_LIFE = 1.6
local SHELL_GRAVITY = Vector3.new(0, -70, 0)

type Shell = {
	part: Part,
	position: Vector3,
	velocity: Vector3,
	rotation: CFrame,
	axis: Vector3,
	spin: number,
	age: number,
	bounced: boolean,
	resting: boolean,
	active: boolean,
}

local shells: { Shell } = {}
local nextShell = 1
local activeShells = 0
local shellParams = RaycastParams.new()
shellParams.FilterType = Enum.RaycastFilterType.Exclude
local shellFilterCharacter: Model? = nil
local shellFilterReady = false

-- Shells land on the world, not on our own character. Call before eject().
function ShellFx.updateFilter()
	local character = player.Character
	if character ~= shellFilterCharacter or not shellFilterReady then
		shellFilterReady = true
		shellFilterCharacter = character
		shellParams.FilterDescendantsInstances = if character
			then { Kit.effectsFolder(), character }
			else { Kit.effectsFolder() }
	end
end

local function shellSize(config: WeaponConfig): Vector3
	local class = config.class
	if class == "Shotgun" then
		return Vector3.new(0.3, 0.16, 0.16)
	elseif class == "Sniper" then
		return Vector3.new(0.3, 0.09, 0.09)
	elseif class == "Rifle" or class == "MachineGun" then
		return Vector3.new(0.16, 0.05, 0.05)
	end
	return Vector3.new(0.13, 0.06, 0.06)
end

local function spawnShell(eject: Attachment, config: WeaponConfig, scale: number, inherit: Vector3)
	if #shells < SHELL_POOL then
		local p = Kit.fxPart(Vector3.one, CFrame.identity, BRASS)
		p.Name = "Shell"
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Metal
		p.Reflectance = 0.05
		table.insert(shells, {
			part = p,
			position = Vector3.zero,
			velocity = Vector3.zero,
			rotation = CFrame.identity,
			axis = Vector3.xAxis,
			spin = 0,
			age = 0,
			bounced = false,
			resting = false,
			active = false,
		})
	end
	local shell = shells[nextShell] or shells[1]
	nextShell = nextShell % SHELL_POOL + 1
	if not shell.active then
		activeShells += 1
	end
	local cf = eject.WorldCFrame
	local p = shell.part
	p.Size = shellSize(config) * scale
	p.Color = if config.class == "Shotgun" then Color3.fromHex("A8333F") else BRASS
	p.Transparency = 0
	shell.position = cf.Position
	shell.rotation = cf.Rotation * CFrame.Angles(0, math.pi / 2, 0) -- axis across the gun
	-- Out to the side and up, a little forward, with some scatter.
	local out = cf.LookVector * (8 + math.random() * 4) + cf.UpVector * (5 + math.random() * 3)
	shell.velocity = (out - cf.RightVector * (math.random() - 0.3) * 2) * math.sqrt(scale) + inherit
	shell.axis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
	shell.spin = 20 + math.random() * 18
	shell.age = 0
	shell.bounced = false
	shell.resting = false
	shell.active = true
	p.CFrame = CFrame.new(shell.position) * shell.rotation
end

-- Every frame, with `dt` already scaled by the effects time scale.
function ShellFx.step(dt: number)
	if activeShells == 0 then
		return
	end
	for _, s in shells do
		if not s.active then
			continue
		end
		s.age += dt
		local p = s.part
		if s.age >= SHELL_LIFE then
			s.active = false
			activeShells -= 1
			p.Transparency = 1
			continue
		end
		if not s.resting then
			local v = s.velocity + SHELL_GRAVITY * dt
			local move = v * dt
			local hit = Workspace:Raycast(s.position, move, shellParams)
			if hit then
				local n = hit.Normal
				if s.bounced or v.Magnitude < 6 then
					s.resting = true
					s.position = hit.Position + n * (p.Size.Y / 2)
					-- Lie flat on the ground.
					s.rotation = CFrame.fromMatrix(Vector3.zero, s.rotation.RightVector, n)
						* CFrame.Angles(0, 0, math.pi / 2)
				else
					v = (v - 2 * v:Dot(n) * n) * 0.32
					s.position = hit.Position + n * 0.03
					s.bounced = true
					s.spin *= 0.5
				end
			else
				s.position += move
			end
			s.velocity = v
			if not s.resting then
				s.rotation = CFrame.fromAxisAngle(s.axis, s.spin * dt) * s.rotation
			end
			p.CFrame = CFrame.new(s.position) * s.rotation
		end
		local fade = (s.age - (SHELL_LIFE - 0.3)) / 0.3
		if fade > 0 then
			p.Transparency = fade
		end
	end
end

-- Throws a casing from `eject`. Pump and bolt guns throw it when they cycle,
-- a moment after the shot. Melee weapons throw nothing.
function ShellFx.eject(eject: Attachment, config: WeaponConfig, scale: number, inherit: Vector3?)
	if config.melee then
		return
	end
	if config.fireMode == "Pump" or config.fireMode == "Bolt" then
		task.delay(0.3, function()
			if eject.Parent then
				spawnShell(eject, config, scale, inherit or Vector3.zero)
			end
		end)
	else
		spawnShell(eject, config, scale, inherit or Vector3.zero)
	end
end

return ShellFx
