--!strict
-- Text that sizes itself to its words (AutomaticSize) is measured before its
-- font (Fredoka One) has downloaded, so the box takes the fallback font's
-- width, and Roblox doesn't measure it again when the real font lands: the
-- Season Pass title spilled out of a box too small, tags clipped their words
-- (2026-11-16, vault/02 Art/UI Shop.md → Plate look passes 3 and 5). A
-- hidden screen only loads its font when it opens, so a one-time fix at
-- start isn't enough.
-- watch(root): every self-sizing text under `root` (now and later) measures
-- itself again whenever its words' size changes without its words changing
-- (= its font just loaded): one frame with a trailing space, then back.

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local RunService = game:GetService("RunService")

local TextFit = {}

type TextThing = TextLabel | TextButton

local function hook(o: TextThing)
	if StateValues.get(o, "TextFit") == true then
		return
	end
	StateValues.set(o, "TextFit", true)
	local lastText = o.Text
	local lastBounds = o.TextBounds
	local busy = false
	o:GetPropertyChangedSignal("TextBounds"):Connect(function()
		if busy or o.AutomaticSize == Enum.AutomaticSize.None then
			return
		end
		local b = o.TextBounds
		if o.Text ~= lastText then
			-- the code changed the words: Roblox measured them itself
			lastText, lastBounds = o.Text, b
			return
		end
		if math.abs(b.X - lastBounds.X) < 1 and math.abs(b.Y - lastBounds.Y) < 1 then
			return
		end
		-- same words, new size: the font landed; measure again
		busy = true
		local words = o.Text
		o.Text = words .. " "
		task.spawn(function()
			RunService.Heartbeat:Wait()
			if o.Parent and o.Text == words .. " " then
				o.Text = words
			end
			RunService.Heartbeat:Wait()
			lastText, lastBounds = o.Text, o.TextBounds
			busy = false
		end)
	end)
end

local function maybe(d: Instance)
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		hook(d :: TextThing)
	end
end

function TextFit.watch(root: Instance)
	for _, d in root:GetDescendants() do
		maybe(d)
	end
	root.DescendantAdded:Connect(maybe)
end

return TextFit
