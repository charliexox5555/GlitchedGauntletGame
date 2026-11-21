--!strict
-- Arena / Big Arena v3: more levels (owner playtest 2026-11-21: "it needs more levels to it, like high ground").
-- Swaps cover blocks for +7 platforms with a parapet on the enemy side and a +3.5 step on your own side, in the
-- maps' own v2 style: each new part is a clone of an existing part (same colour, SmoothPlastic, the 5-stud Grid
-- Textures), resized and placed on the 5-stud grid so the grid lines run on. Plans and checks:
-- tools/maps/arena_layout.py (ARENA / BIGARENA, v3 rows). Match place, edit mode; safe to run again.
-- Run: require(<a clone of this module>)() → summary.

type Piece = { name: string, folder: string, template: string, c: Vector3, size: Vector3 }

local PLANS: { [string]: { remove: { string }, pieces: { Piece } } } = {
	Arena = {
		remove = { "Side block" },
		pieces = {
			{
				name = "Side platform",
				folder = "Heights",
				template = "Corner deck",
				c = Vector3.new(30, 3.5, 10),
				size = Vector3.new(10, 7, 10),
			},
			{
				name = "Side parapet",
				folder = "Cover",
				template = "Side block",
				c = Vector3.new(30, 5, 2.5),
				size = Vector3.new(10, 10, 5),
			},
			{
				name = "Side step",
				folder = "Heights",
				template = "Corner deck",
				c = Vector3.new(30, 1.75, 17.5),
				size = Vector3.new(5, 3.5, 5),
			},
		},
	},
	BigArena = {
		remove = { "Left block", "Right block" },
		pieces = {
			{
				name = "Left platform",
				folder = "Heights",
				template = "Side deck",
				c = Vector3.new(-50, 3.5, -30),
				size = Vector3.new(10, 7, 10),
			},
			{
				name = "Left parapet",
				folder = "Cover",
				template = "Left block",
				c = Vector3.new(-50, 5, -37.5),
				size = Vector3.new(10, 10, 5),
			},
			{
				name = "Left step",
				folder = "Heights",
				template = "Side deck",
				c = Vector3.new(-50, 1.75, -22.5),
				size = Vector3.new(5, 3.5, 5),
			},
			{
				name = "Right platform",
				folder = "Heights",
				template = "Side deck",
				c = Vector3.new(60, 3.5, 10),
				size = Vector3.new(10, 7, 10),
			},
			{
				name = "Right parapet",
				folder = "Cover",
				template = "Right block",
				c = Vector3.new(60, 5, 2.5),
				size = Vector3.new(10, 10, 5),
			},
			{
				name = "Right step",
				folder = "Heights",
				template = "Side deck",
				c = Vector3.new(60, 1.75, 17.5),
				size = Vector3.new(5, 3.5, 5),
			},
		},
	},
}

local function find(map: Model, name: string): BasePart?
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name then
			return d
		end
	end
	return nil
end

return function(): string
	assert(game.PlaceId == 133387545285290, "HighGround: not the match place")
	local out = {}
	for id, plan in PLANS do
		local map = workspace:FindFirstChild(id) :: Model?
		assert(map, "no map " .. id)
		local found = map:FindFirstChild("Greybox")
		assert(found and found:IsA("Folder"), id .. ": no Greybox folder")
		local greybox: Folder = found
		local O = map:GetPivot()
		-- templates first (some are among the parts removed)
		local templates: { [string]: BasePart } = {}
		for _, pc in plan.pieces do
			if not templates[pc.template] then
				local t = find(map, pc.template)
				if not t then
					-- already converted: the platform pieces themselves serve as templates on a re-run
					t = find(map, pc.name)
				end
				assert(t, id .. ": no template " .. pc.template)
				templates[pc.template] = (t :: BasePart):Clone()
			end
		end
		-- clear old blocks and earlier platform pieces
		local removed = 0
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") then
				local base = string.gsub(d.Name, "'$", "")
				local kill = table.find(plan.remove, base) ~= nil
				for _, pc in plan.pieces do
					if base == pc.name then
						kill = true
					end
				end
				if kill then
					d:Destroy()
					removed += 1
				end
			end
		end
		local made = 0
		for i, sign in { 1, -1 } do
			for _, pc in plan.pieces do
				local p = templates[pc.template]:Clone()
				p.Name = pc.name .. (if i == 2 then "'" else "")
				p.Size = pc.size
				p.CFrame = O * CFrame.new(pc.c.X * sign, pc.c.Y, pc.c.Z * sign)
				local folder = greybox:FindFirstChild(pc.folder) or greybox
				p.Parent = folder
				made += 1
			end
		end
		for _, t in templates do
			t:Destroy()
		end
		table.insert(out, string.format("%s: removed %d, added %d", id, removed, made))
	end
	return table.concat(out, "\n")
end
