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

local RunService = game:GetService("RunService")

local TextFit = {}

type TextThing = TextLabel | TextButton

local MAX_NUDGES = 3
local NUDGE_COOLDOWN = 0.5
local hooked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local watchedRoots: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isShown(o: TextThing): boolean
	if not o.Visible or not o.Parent then
		return false
	end
	local p = o.Parent
	while p and not p:IsA("LayerCollector") do
		if p:IsA("GuiObject") and not p.Visible then
			return false
		end
		p = p.Parent
	end
	return p == nil or not p:IsA("ScreenGui") or p.Enabled
end

local function hook(o: TextThing)
	if hooked[o] then
		return
	end
	hooked[o] = true
	local lastText = o.Text
	local lastBounds = o.TextBounds
	local busy = false
	local nudges = 0
	local lastNudge = 0
	local conn: RBXScriptConnection
	conn = o:GetPropertyChangedSignal("TextBounds"):Connect(function()
		if busy or nudges >= MAX_NUDGES or o.AutomaticSize == Enum.AutomaticSize.None then
			return
		end
		if not isShown(o) then
			lastBounds = o.TextBounds
			return
		end
		local words = o.Text
		local b = o.TextBounds
		if words ~= lastText then
			-- the code changed the words: Roblox measured them itself
			lastText, lastBounds = words, b
			return
		end
		if words == "" or string.sub(words, -1) == " " then
			lastBounds = b
			return
		end
		if math.abs(b.X - lastBounds.X) < 1 and math.abs(b.Y - lastBounds.Y) < 1 then
			return
		end
		local now = os.clock()
		if now - lastNudge < NUDGE_COOLDOWN then
			lastBounds = b
			return
		end
		-- Defer out of the property-changed callback so AutomaticSize re-layout cannot re-enter TextBounds.
		busy = true
		lastNudge = now
		task.defer(function()
			if not o.Parent or o.Text ~= words or o.AutomaticSize == Enum.AutomaticSize.None then
				busy = false
				return
			end
			o.Text = words .. " "
			RunService.Heartbeat:Wait()
			if o.Parent and o.Text == words .. " " then
				o.Text = words
			end
			RunService.Heartbeat:Wait()
			if o.Parent then
				lastText, lastBounds = o.Text, o.TextBounds
			end
			nudges += 1
			busy = false
			if nudges >= MAX_NUDGES and conn.Connected then
				conn:Disconnect()
			end
		end)
	end)
end

local function maybe(d: Instance)
	if
		(d:IsA("TextLabel") or d:IsA("TextButton"))
		and d.AutomaticSize ~= Enum.AutomaticSize.None
	then
		hook(d :: TextThing)
	end
end

function TextFit.watch(root: Instance)
	if watchedRoots[root] then
		return
	end
	watchedRoots[root] = true
	for _, d in root:GetDescendants() do
		maybe(d)
	end
	root.DescendantAdded:Connect(maybe)
end

return TextFit
