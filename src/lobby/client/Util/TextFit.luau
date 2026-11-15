--!strict
-- Text that sizes itself to its words (AutomaticSize) is measured when the
-- ScreenGui is copied into PlayerGui, often before its font (Builder
-- Extended, Sarpanch...) has downloaded, so the box takes the fallback
-- font's width and Roblox doesn't measure it again when the real font lands:
-- the Season Pass title was a 288 px box for 361 px of text (centred, so it
-- spilled out both sides), and tags sized to it clipped their words
-- (2026-11-16, vault/02 Art/UI Shop.md → Plate look pass 3).
-- settle(root): wait for the fonts under `root` to load, then make every
-- self-sizing text measure itself again (a one-frame trailing space).

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local TextFit = {}

type TextThing = TextLabel | TextButton

local function isText(d: Instance): boolean
	return d:IsA("TextLabel") or d:IsA("TextButton")
end

function TextFit.refresh(root: Instance)
	local touched: { { o: TextThing, text: string } } = {}
	for _, d in root:GetDescendants() do
		if isText(d) then
			local o = d :: TextThing
			if o.AutomaticSize ~= Enum.AutomaticSize.None and o.Text ~= "" then
				table.insert(touched, { o = o, text = o.Text })
				o.Text = o.Text .. " "
			end
		end
	end
	RunService.Heartbeat:Wait()
	for _, t in touched do
		-- put the words back unless code changed them in between
		if t.o.Parent and t.o.Text == t.text .. " " then
			t.o.Text = t.text
		end
	end
end

function TextFit.settle(root: Instance)
	task.spawn(function()
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ root })
		end)
		if not ok then
			task.wait(3)
		end
		TextFit.refresh(root)
	end)
end

return TextFit
