--[[
	ForeverGroups: core

	One event frame for the whole addon, a tiny message bus between the files,
	the saved settings and the helpers every file shares.

	Secret values: in dungeons, raids and encounters most search-result and chat
	fields come back "secret". They can be shown (SetText) but never compared,
	concatenated or used as table keys. Readable() turns them into a fallback so
	every filter and sort fails open instead of erroring.
--]]

local ADDON, ns = ...

ns.name = "ForeverGroups"
ns.title = "|cff4fc3f7Forever|rGroups"
ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
-- our painted icon (a dungeon portal); ForeverMap's tools\import_icon_sheets.py makes it
ns.icon = "Interface\\AddOns\\ForeverGroups\\Media\\icon"


--[[ Secret values ]]--

local canaccessvalue = canaccessvalue or function() return true end
ns.canaccess = canaccessvalue

function ns.Readable(value, fallback)
	if value == nil or not canaccessvalue(value) then
		return fallback
	end
	return value
end


--[[ Game events ]]--

local frame = CreateFrame("Frame")
local handlers = {}

frame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	for i = 1, #list do
		list[i](event, ...)
	end
end)

function ns:RegisterEvent(event, func)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
		frame:RegisterEvent(event)
	end
	list[#list + 1] = func
end


--[[ Messages between files ]]--

local listeners = {}

function ns:On(message, func)
	listeners[message] = listeners[message] or {}
	table.insert(listeners[message], func)
end

function ns:Fire(message, ...)
	local list = listeners[message]
	if not list then return end
	for i = 1, #list do
		list[i](...)
	end
end


--[[ Saved settings ]]--

ns.defaults = {
	account = {
		askWhisper = true, -- "ask to join" sends the message
		inviteWhisper = true, -- "invite" also whispers the message
		whisperLogSize = 200,
		unreadCounter = true, -- unread whispers on the minimap button
		showAllLevels = false, -- activities outside the player's level too
		showLevelRanges = true, -- "(17 - 24)" after each activity
		markGuild = true,
		markFriends = true,
		playerSort = "newest",
		minimap = {hide = false, angle = 225},
		window = {},
		filters = nil, -- the Filters tab as last searched (see Data.lua)
		category = nil, -- last searched category
		myFilters = {}, -- {name = ..., filters = {...}} in save order
		collapsed = {}, -- filter sections the player folded
	},
	char = {
		messages = {}, -- [language] = {ask = ..., invite = ...}; missing: the default message
		messageLanguage = nil, -- nil: the game's language
	},
}

local function Merge(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			Merge(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

ns:RegisterEvent("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	ForeverGroupsDB = type(ForeverGroupsDB) == "table" and ForeverGroupsDB or {}
	ForeverGroupsCharDB = type(ForeverGroupsCharDB) == "table" and ForeverGroupsCharDB or {}
	Merge(ForeverGroupsDB, ns.defaults.account)
	Merge(ForeverGroupsCharDB, ns.defaults.char)
	ns.db, ns.char = ForeverGroupsDB, ForeverGroupsCharDB
	ns:Fire("Loaded")
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
	ns:Fire("Login")
end)


--[[ Helpers ]]--

function ns:Print(...)
	print(ns.title .. ":", ...)
end

function ns.PlayClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

ns.classes = CLASS_SORT_ORDER or {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}

function ns.ClassAtlas(class)
	class = ns.Readable(class, nil)
	return class and "groupfinder-icon-class-" .. class:lower() or nil
end

function ns.ClassColor(class)
	class = ns.Readable(class, nil)
	return class and RAID_CLASS_COLORS[class] or nil
end

function ns.ClassName(class)
	return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
end

-- Runs func once after delay seconds; asking again with the same key restarts the wait.
local timers = {}
function ns:Defer(key, func, delay)
	if timers[key] then timers[key]:Cancel() end
	timers[key] = C_Timer.NewTimer(delay or 0, function()
		timers[key] = nil
		func()
	end)
end

function ns.Whisper(name, text)
	if not name or not canaccessvalue(name) or not text then return false end
	C_ChatInfo.SendChatMessage(text, "WHISPER", nil, name)
	return true
end

function ns.ShowTooltip(owner, title, text, anchor)
	GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
	GameTooltip:SetText(title, 1, 1, 1, 1, true)
	if text then
		GameTooltip:AddLine(text, nil, nil, nil, true)
	end
	GameTooltip:Show()
end


--[[
	Row actions (invite, ask to join, whisper-log invite) share one short
	cooldown, so a double click never sends two invites or two whispers.
--]]

local ACTION_COOLDOWN = 2
local actionButtons = {}
local locked = false

local function PaintLock(button)
	button:SetEnabled(not locked)
	if button.Icon then
		button.Icon:SetDesaturated(locked)
		button.Icon:SetAlpha(locked and 0.5 or 1)
	end
end

function ns.RegisterActionButton(button)
	actionButtons[#actionButtons + 1] = button
	PaintLock(button)
end

function ns.PaintActionButton(button)
	PaintLock(button)
end

-- func returns false when nothing was sent, which skips the cooldown.
function ns.RunAction(func)
	if locked or not func then return end
	ns.PlayClick()
	if func() == false then return end
	locked = true
	for i = 1, #actionButtons do PaintLock(actionButtons[i]) end
	C_Timer.After(ACTION_COOLDOWN, function()
		locked = false
		for i = 1, #actionButtons do PaintLock(actionButtons[i]) end
	end)
end


--[[ Slash command, key binding and the AddOns menu ]]--

BINDING_HEADER_FOREVERGROUPS = "ForeverGroups"

function ForeverGroups_Toggle()
	ns:ToggleWindow()
end

SLASH_FOREVERGROUPS1 = "/fg"
SLASH_FOREVERGROUPS2 = "/forevergroups"
SlashCmdList.FOREVERGROUPS = function(message)
	local command = (message or ""):lower():match("^%s*(%S*)")
	if command == "config" or command == "options" then
		ns:OpenSettings()
	elseif command == "reset" then
		ns:ResetWindow()
	elseif command == "help" then
		ns:Print(ns.L.SLASH_HELP)
	else
		ns:ToggleWindow()
	end
end

function ForeverGroups_OnCompartmentClick(_, button)
	if button == "RightButton" then
		ns:OpenSettings()
	else
		ns:ToggleWindow()
	end
end

function ForeverGroups_OnCompartmentEnter(_, owner)
	ns.ShowTooltip(owner, ns.title, ns.L.MINIMAP_HINT, "ANCHOR_LEFT")
end

function ForeverGroups_OnCompartmentLeave()
	GameTooltip:Hide()
end
