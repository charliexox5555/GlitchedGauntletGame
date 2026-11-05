--!strict
-- Roblox's own UI around our full-screen screens, Lobby menus and the match's
-- draft (vault/01 Design/Lobby UI and Queue.md section 8, vault/01 Design/Match
-- HUD.md; LihFolk: Safe Areas and Insets, ScreenGui Fundamentals). Client only.
-- * `menuMode(on)`: while a full-screen menu is open, hide the chat window,
--   the chat bar and the player list so nothing in the menu sits under them;
--   on close, restore exactly what was showing before (Style.FLAGS switch).
-- * The HUD itself never needs this: its top row sits in Roblox's top-bar
--   strip and everything else is on the bottom dock, clear of both.

local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Style = require(script.Parent.Config.UiStyle)

local CoreUi = {}

type Saved = { playerList: boolean?, chatWindow: boolean?, chatBar: boolean? }
local saved: Saved? = nil

local function config(className: string): Instance?
	return TextChatService:FindFirstChildOfClass(className)
end

local function getEnabled(inst: Instance?): boolean?
	if not inst then
		return nil
	end
	local ok, v = pcall(function()
		return (inst :: any).Enabled
	end)
	return if ok and typeof(v) == "boolean" then v else nil
end

local function setEnabled(inst: Instance?, on: boolean?)
	if inst and on ~= nil then
		pcall(function()
			(inst :: any).Enabled = on
		end)
	end
end

function CoreUi.menuMode(on: boolean)
	if not Style.FLAGS.hideCoreUiInMenus then
		return
	end
	local window = config("ChatWindowConfiguration")
	local bar = config("ChatInputBarConfiguration")
	if on then
		if saved then
			return
		end
		local okList, list =
			pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList)
		saved = {
			playerList = if okList then list else nil,
			chatWindow = getEnabled(window),
			chatBar = getEnabled(bar),
		}
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
		setEnabled(window, false)
		setEnabled(bar, false)
	else
		local s = saved
		if not s then
			return
		end
		saved = nil
		if s.playerList ~= nil then
			pcall(
				StarterGui.SetCoreGuiEnabled,
				StarterGui,
				Enum.CoreGuiType.PlayerList,
				s.playerList
			)
		end
		setEnabled(window, s.chatWindow)
		setEnabled(bar, s.chatBar)
	end
end

return CoreUi
