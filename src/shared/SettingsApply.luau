--!strict
-- The one place each client applies the player's saved settings
-- (vault/02 Art/UI Settings.md → Wiring the settings; numbers in
-- Config/SettingsApply). The lobby client starts it in lobby servers, the
-- match client in match servers (start() is safe to call twice). It reads the
-- server-published "Settings" StringValue (Shared/PlayerSettings) and:
--   * applies the world-wide rows itself: optimized lighting and textures,
--     hide HUD / side tasks (named ScreenGuis), the lobby camera's sensitivity;
--   * answers the rest for the systems that own them: get(id), onChanged(fn),
--     lowVfx() / vfxCount(n), scaleTurn() (CameraController), palette() and
--     hitColors() (colourblind + damage highlight).
-- The lobby SettingsController previews edits at once with preview(values);
-- the server's publish then confirms them.

local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("SettingsApply") :: ModuleScript)
local Settings = require(Shared:WaitForChild("Config"):WaitForChild("Settings") :: ModuleScript)
local PlayerSettings = require(Shared:WaitForChild("PlayerSettings") :: ModuleScript)

type Values = PlayerSettings.Values
export type TurnMode = "hip" | "aim" | "scope"

local SettingsApply = {}

local player = Players.LocalPlayer
local values: Values = PlayerSettings.defaults()
local changedEvent = Instance.new("BindableEvent")
-- Connections made through onChanged belong to the script that made them, so a
-- destroyed match-client copy drops its own (a BindableEvent, not a Lua list).
SettingsApply.changed = changedEvent.Event
local started = false

function SettingsApply.get(id: string): any
	local v = values[id]
	if v == nil then
		return PlayerSettings.default(id)
	end
	return v
end

local function on(id: string): boolean
	return SettingsApply.get(id) == true
end

local function num(id: string): number
	local v = SettingsApply.get(id)
	return if typeof(v) == "number" then v else 0
end

-- `fn` now and after every change.
function SettingsApply.onChanged(fn: () -> ()): RBXScriptConnection
	local c = SettingsApply.changed:Connect(fn)
	task.spawn(fn)
	return c
end

-- VFX ------------------------------------------------------------------------------

function SettingsApply.lowVfx(): boolean
	return on("optimizedVfx")
end

-- A decorative particle count (dust, chips, embers, smoke) under Optimized VFX.
function SettingsApply.vfxCount(n: number): number
	if not on("optimizedVfx") then
		return n
	end
	return math.floor(n * Config.VFX_EMIT_SCALE)
end

-- CAMERA ---------------------------------------------------------------------------

-- Horizontal and vertical multipliers (sign = inverted) for a turn mode.
function SettingsApply.turnScale(mode: TurnMode): (number, number)
	local base = num("sensitivity") / Config.SENS_NEUTRAL
	if mode == "aim" then
		base *= num("sensAiming") / 100
	elseif mode == "scope" then
		base *= num("sensScoped") / 100
	end
	local x = base * num("sensHorizontal") / 100
	local y = base * num("sensVertical") / 100
	if on("invertX") then
		x = -x
	end
	if on("invertY") then
		y = -y
	end
	return x, y
end

local function yawPitch(look: Vector3): (number, number)
	return math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
end

local function wrap(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- The camera module turned the view from `lastLook` by this frame's input
-- (mouse, stick or touch): rescale that turn by the player's sensitivity.
-- Rotates about Camera.Focus, so a third-person orbit stays on its subject.
function SettingsApply.scaleTurn(cam: Camera, lastLook: Vector3, mode: TurnMode)
	local sx, sy = SettingsApply.turnScale(mode)
	if sx == 1 and sy == 1 then
		return
	end
	local cf = cam.CFrame
	local y0, p0 = yawPitch(lastLook)
	local y1, p1 = yawPitch(cf.LookVector)
	local dy, dp = wrap(y1 - y0), p1 - p0
	if math.abs(dy) < Config.TURN_EPSILON and math.abs(dp) < Config.TURN_EPSILON then
		return
	end
	if math.abs(dy) > Config.TURN_RESET or math.abs(dp) > Config.TURN_RESET then
		return -- a camera reset (a menu handed it back), not a turn
	end
	local limit = Config.PITCH_LIMIT
	local pitch = math.clamp(p0 + dp * sy, math.min(-limit, p1), math.max(limit, p1))
	local rot = CFrame.fromOrientation(pitch, y0 + dy * sx, 0)
	local pivot = cam.Focus.Position
	local dist = (cf.Position - pivot).Magnitude
	local pos = if dist > Config.ORBIT_MIN then pivot - rot.LookVector * dist else cf.Position
	cam.CFrame = CFrame.new(pos) * rot
end

-- The match CameraController scales its own turns while `owner` exists (its
-- screen, destroyed with the match client); the lobby camera step stands down.
local cameraOwner: Instance? = nil
function SettingsApply.claimCamera(owner: Instance)
	cameraOwner = owner
end

local function cameraClaimed(): boolean
	local o = cameraOwner
	return o ~= nil and o.Parent ~= nil
end

local lobbyLast: Vector3? = nil
local function lobbyCameraStep()
	local cam = Workspace.CurrentCamera
	if not cam or cameraClaimed() or cam.CameraType ~= Enum.CameraType.Custom then
		lobbyLast = nil
		return
	end
	local last = lobbyLast
	if last then
		SettingsApply.scaleTurn(cam, last, "hip")
	end
end

local function lobbyCameraRecord()
	local cam = Workspace.CurrentCamera
	if cam and not cameraClaimed() and cam.CameraType == Enum.CameraType.Custom then
		lobbyLast = cam.CFrame.LookVector
	end
end

-- COLOURBLIND + DAMAGE HIGHLIGHT ---------------------------------------------------

function SettingsApply.palette(): Config.Palette
	local mode = SettingsApply.get("colorblind")
	return (Config.PALETTES :: any)[mode] or Config.PALETTES.Off
end

-- The hit highlight's colours, or nil = keep the tuned per-hit colour (the
-- player left the row at its default and no colourblind swap applies).
function SettingsApply.hitColors(): (Color3?, Color3?)
	local flash: Color3? = nil
	local base: Color3? = nil
	if SettingsApply.get("highlightFlash") ~= PlayerSettings.default("highlightFlash") then
		flash = PlayerSettings.color(values, "highlightFlash")
	end
	if SettingsApply.get("highlightBase") ~= PlayerSettings.default("highlightBase") then
		base = PlayerSettings.color(values, "highlightBase")
	else
		base = SettingsApply.palette().hitBase
	end
	return flash, base
end

-- LIGHTING -------------------------------------------------------------------------

local lowLight = false
local lightSaved: { [Instance]: boolean } = {} -- light / effect -> its own Shadows / Enabled
local shadowsWanted = Lighting.GlobalShadows
local lightConns: { RBXScriptConnection } = {}

local function dimOne(inst: Instance)
	if lightSaved[inst] ~= nil then
		return
	end
	if inst:IsA("Light") and Config.LIGHT_CLASSES[inst.ClassName] then
		lightSaved[inst] = inst.Shadows
		inst.Shadows = false
	elseif Config.LOW_LIGHT_FX[inst.ClassName] and inst:IsA("PostEffect") then
		lightSaved[inst] = inst.Enabled
		inst.Enabled = false
	end
end

local function setLowLight(want: boolean)
	if want == lowLight then
		return
	end
	lowLight = want
	if want then
		shadowsWanted = Lighting.GlobalShadows
		Lighting.GlobalShadows = false
		table.insert(
			lightConns,
			Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
				if Lighting.GlobalShadows then -- the server or a map set it
					shadowsWanted = true
					Lighting.GlobalShadows = false
				end
			end)
		)
		for _, root in { Lighting, Workspace } do
			for _, d in root:GetDescendants() do
				dimOne(d)
			end
			table.insert(lightConns, root.DescendantAdded:Connect(dimOne))
		end
	else
		for _, c in lightConns do
			c:Disconnect()
		end
		table.clear(lightConns)
		for inst, was in lightSaved do
			if inst.Parent then
				if inst:IsA("Light") then
					inst.Shadows = was
				elseif inst:IsA("PostEffect") then
					inst.Enabled = was
				end
			end
		end
		table.clear(lightSaved)
		Lighting.GlobalShadows = shadowsWanted
	end
end

-- TEXTURES -------------------------------------------------------------------------

local lowTex = false
local texHeld: { { variant: Instance, parent: Instance } } = {}
local texConn: RBXScriptConnection? = nil

local function holdVariant(d: Instance)
	if d:IsA("MaterialVariant") and d.Parent then
		table.insert(texHeld, { variant = d, parent = d.Parent :: Instance })
		d.Parent = nil -- parts fall back to the plain material on this client
	end
end

local function setLowTex(want: boolean)
	if want == lowTex then
		return
	end
	lowTex = want
	if want then
		for _, d in MaterialService:GetDescendants() do
			holdVariant(d)
		end
		texConn = MaterialService.DescendantAdded:Connect(function(d)
			task.defer(holdVariant, d)
		end)
	else
		if texConn then
			texConn:Disconnect()
			texConn = nil
		end
		for _, h in texHeld do
			if h.parent:IsDescendantOf(game) then
				h.variant.Parent = h.parent
			end
		end
		table.clear(texHeld)
	end
end

-- HUD ------------------------------------------------------------------------------

type HiddenGui = { wanted: boolean, conn: RBXScriptConnection }
local hiddenGuis: { [ScreenGui]: HiddenGui } = {}

local function guiHiddenBy(name: string): boolean
	if on("hideHud") then
		if table.find(Config.MATCH_HUD_GUIS, name) or table.find(Config.LOBBY_HUD_GUIS, name) then
			return true
		end
	end
	return table.find(Config.SIDE_TASK_GUIS, name) ~= nil and (on("hideSideTasks") or on("hideHud"))
end

local function hideGui(gui: ScreenGui, hide: boolean)
	local h = hiddenGuis[gui]
	if hide and not h then
		local entry: HiddenGui = {
			wanted = gui.Enabled,
			conn = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
				if gui.Enabled then -- its owner showed it: remember, keep it hidden
					local e = hiddenGuis[gui]
					if e then
						e.wanted = true
					end
					gui.Enabled = false
				end
			end),
		}
		hiddenGuis[gui] = entry
		gui.Enabled = false
	elseif not hide and h then
		h.conn:Disconnect()
		hiddenGuis[gui] = nil
		gui.Enabled = h.wanted
	end
end

local function applyGuis()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") then
			hideGui(g, guiHiddenBy(g.Name))
		end
	end
	for g, h in hiddenGuis do
		if not g.Parent then
			h.conn:Disconnect()
			hiddenGuis[g] = nil
		end
	end
end

-- VALUES ---------------------------------------------------------------------------

local function applyAll()
	setLowLight(on("optimizedLighting"))
	setLowTex(on("optimizedTextures"))
	applyGuis()
	changedEvent:Fire()
end

-- The lobby Settings screen's live edit (before the server's publish lands).
function SettingsApply.preview(v: Values)
	values = PlayerSettings.clean(v)
	applyAll()
end

local function fromReplica(sv: StringValue)
	if sv.Value == "" then
		return
	end
	local decoded = PlayerSettings.decode(sv.Value)
	if decoded then
		values = decoded
		applyAll()
	end
end

function SettingsApply.start()
	if started then
		return
	end
	started = true
	RunService:BindToRenderStep(
		"GGSettingsCam",
		Enum.RenderPriority.Camera.Value + 1,
		lobbyCameraStep
	)
	RunService:BindToRenderStep(
		"GGSettingsCamLast",
		Enum.RenderPriority.Last.Value,
		lobbyCameraRecord
	)
	task.spawn(function()
		local playerGui = player:WaitForChild("PlayerGui")
		playerGui.ChildAdded:Connect(function(g)
			if g:IsA("ScreenGui") then
				task.defer(function()
					hideGui(g, guiHiddenBy(g.Name))
				end)
			end
		end)
		local sv = player:WaitForChild(Settings.REPLICA, 60)
		if sv and sv:IsA("StringValue") then
			sv.Changed:Connect(function()
				fromReplica(sv)
			end)
			fromReplica(sv)
		end
		applyAll()
	end)
end

return SettingsApply
