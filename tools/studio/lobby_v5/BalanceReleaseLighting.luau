--!strict
-- Draft Duels / Edit. Balance the public routes at player height.
assert(game.PlaceId == 71551303511506 and not game:GetService("RunService"):IsRunning())

local shell = workspace.LobbyV5.Shell
local previous = shell:FindFirstChild("ReleaseRouteLighting")
if previous then
	previous:Destroy()
end
local rig = Instance.new("Folder")
rig.Name = "ReleaseRouteLighting"
rig.Parent = shell

local function wash(name: string, from: Vector3, toward: Vector3, brightness: number, range: number)
	local mount = Instance.new("Part")
	mount.Name = name
	mount.Anchored = true
	mount.CanCollide = false
	mount.CanTouch = false
	mount.CanQuery = false
	mount.CastShadow = false
	mount.Transparency = 1
	mount.Size = Vector3.new(3, 0.1, 1)
	mount.CFrame = CFrame.lookAt(from, toward)
	mount.Parent = rig
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Color = Color3.fromRGB(237, 231, 220)
	light.Angle = 126
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = mount
end

local V = Vector3.new
wash("ShopEntry", V(-64, 13, -1600), V(-70, 0, -1600), 0.85, 20)
wash("ShopAisle", V(-85, 14, -1600), V(-87, 0, -1600), 1.10, 24)
wash("ShopFeature", V(-108, 13, -1600), V(-115, 2, -1600), 0.9, 23)
wash("DuelsThreshold", V(0, 9.5, -1653), V(0, 1, -1663), 0.9, 22)
wash("DuelsDeck", V(0, 12, -1676), V(0, 0, -1682), 1.2, 28)
for _, x in { -24, 24 } do
	wash("DuelsPadFill", V(x, 12, -1701), V(x * 0.65, 2, -1707), 0.92, 26)
end

-- Trim the stacked Locker ceiling lamps so white stands and pegboard retain detail.
for _, light in shell.Locker.Room:GetDescendants() do
	if light:IsA("Light") then
		local base = light:GetAttribute("ReleaseBaseBrightness")
		if typeof(base) ~= "number" then
			base = light.Brightness
			light:SetAttribute("ReleaseBaseBrightness", base)
		end
		light.Brightness = base * 0.73
	end
end

return { routeFills = #rig:GetChildren(), lockerTrim = true }
