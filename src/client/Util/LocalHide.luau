--!strict
-- Hides or shows a part for this client together with the Textures and
-- Decals on it. A part's LocalTransparencyModifier (or Transparency) does not
-- reach its Textures, so skin parts (which carry tiled pattern Textures, see
-- tools/studio/InstallFlatSkin.luau) left their pattern floating in the air:
-- a magazine hidden during a reload, the gun hidden behind a scope (owner
-- 2026-11-14). Use this for every viewmodel part that is hidden or faded.
local LocalHide = {}

-- The faces on each part, looked up once (parts are weak keys, so destroyed
-- viewmodels drop out).
local faces: { [BasePart]: { Decal } } = setmetatable({}, { __mode = "k" }) :: any

local function facesOf(part: BasePart): { Decal }
	local list = faces[part]
	if not list then
		list = {}
		for _, child in part:GetChildren() do
			if child:IsA("Decal") then -- Texture is a Decal
				table.insert(list, child)
			end
		end
		faces[part] = list
	end
	return list
end

-- LocalTransparencyModifier for `part` and its Textures/Decals (0 shown, 1 hidden).
function LocalHide.set(part: BasePart, value: number)
	part.LocalTransparencyModifier = value
	for _, face in facesOf(part) do
		face.LocalTransparencyModifier = value
	end
end

-- The Textures/Decals on `part` (for fading a copy by Transparency).
function LocalHide.faces(part: BasePart): { Decal }
	return facesOf(part)
end

return LocalHide
