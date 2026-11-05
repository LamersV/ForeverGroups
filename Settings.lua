--[[
	ForeverGroups: settings page (Options > AddOns > ForeverGroups).
	Controls are built the first time the page is shown.
--]]

local _, ns = ...
local L, W

local category

local function Header(parent, text, y)
	local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, y)
	title:SetText(text)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.82, 0, 0.25)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", 16, y - 22)
	line:SetPoint("RIGHT", -16, 0)
	return y - 32
end

local function Note(parent, text, y, x)
	local note = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	note:SetPoint("TOPLEFT", x or 16, y)
	note:SetPoint("RIGHT", -16, 0)
	note:SetJustifyH("LEFT")
	note:SetTextColor(0.75, 0.75, 0.75)
	note:SetText(text)
	return note
end

local function Build(page)
	L, W = ns.L, ns.Widgets
	local scroll = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -28, 4)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(600, 900)
	scroll:SetScrollChild(content)
	scroll:HookScript("OnSizeChanged", function(self, width) content:SetWidth(width) end)

	local db, char = ns.db, ns.char
	local y = -10
	local title = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 16, y)
	title:SetText(ns.title .. "  |cff888888" .. ns.version .. "|r")
	y = y - 40

	-- messages
	y = Header(content, L.SET_MESSAGES, y)
	local ask = W.Check(content, L.SET_ASK_WHISPER, function() return db.askWhisper end,
		function(value) db.askWhisper = value end, L.SET_ASK_WHISPER_TIP)
	ask:SetPoint("TOPLEFT", 16, y)
	y = y - 30
	local askBox = W.MessageBox(content, L.SET_ASK_MESSAGE, 520,
		function() return ns.Data:AskMessage() end,
		function(text)
			text = strtrim(text)
			char.askMessage = (text ~= "" and text ~= L.DEFAULT_ASK_MESSAGE) and text or nil
		end)
	askBox:SetPoint("TOPLEFT", 46, y)
	y = y - 48
	Note(content, L.SET_ASK_PLACEHOLDERS, y, 46)
	y = y - 34

	local invite = W.Check(content, L.SET_INVITE_WHISPER, function() return db.inviteWhisper end,
		function(value) db.inviteWhisper = value end, L.SET_INVITE_WHISPER_TIP)
	invite:SetPoint("TOPLEFT", 16, y)
	y = y - 30
	local inviteBox = W.MessageBox(content, L.SET_INVITE_MESSAGE, 520,
		function() return ns.Data:InviteMessage() end,
		function(text)
			text = strtrim(text)
			char.inviteMessage = (text ~= "" and text ~= L.DEFAULT_INVITE_MESSAGE) and text or nil
		end)
	inviteBox:SetPoint("TOPLEFT", 46, y)
	y = y - 48
	Note(content, L.SET_INVITE_PLACEHOLDERS, y, 46)
	y = y - 26
	Note(content, L.SET_PER_CHARACTER, y, 46)
	y = y - 30

	-- search
	y = Header(content, L.SET_SEARCH, y)
	local checks = {
		{L.SET_ALL_LEVELS, "showAllLevels", L.SET_ALL_LEVELS_TIP, "LevelsChanged"},
		{L.SET_LEVEL_RANGES, "showLevelRanges"},
		{L.SET_MARK_GUILD, "markGuild", nil, "SortChanged"},
		{L.SET_MARK_FRIENDS, "markFriends", nil, "SortChanged"},
	}
	for _, info in ipairs(checks) do
		local key, message = info[2], info[4]
		local check = W.Check(content, info[1], function() return db[key] end,
			function(value)
				db[key] = value
				if message then ns:Fire(message) end
			end, info[3])
		check:SetPoint("TOPLEFT", 16, y)
		y = y - 30
	end
	local sorts = {}
	for _, key in ipairs(ns.Data.playerOrders) do
		sorts[#sorts + 1] = {key, L["SORT_" .. key:upper()]}
	end
	local sort = W.Cycle(content, L.SET_SORT, sorts, function() return db.playerSort end,
		function(value)
			db.playerSort = value
			ns:Fire("SortChanged")
		end, 320)
	sort:SetPoint("TOPLEFT", 20, y - 4)
	y = y - 46

	-- whispers
	y = Header(content, L.WHISPERS, y)
	local size = W.Slider(content, L.SET_LOG_SIZE, 50, 1000, 50,
		function() return db.whisperLogSize end,
		function(value)
			db.whisperLogSize = value
			ns.Whispers:Trim()
		end)
	size:SetPoint("TOPLEFT", 20, y)
	y = y - 50
	local unread = W.Check(content, L.SET_UNREAD, function() return db.unreadCounter end,
		function(value)
			db.unreadCounter = value
			if ns.UpdateMinimapCount then ns.UpdateMinimapCount() end
		end)
	unread:SetPoint("TOPLEFT", 16, y)
	y = y - 40

	-- interface
	y = Header(content, L.SET_INTERFACE, y)
	local minimap = W.Check(content, L.SET_MINIMAP, function() return not db.minimap.hide end,
		function(value) ns:SetMinimapShown(value) end)
	minimap:SetPoint("TOPLEFT", 16, y)
	y = y - 34
	local reset = W.Button(content, L.SET_RESET_WINDOW, 220, function() ns:ResetWindow() end)
	reset:SetPoint("TOPLEFT", 20, y)
	y = y - 32
	Note(content, L.SET_KEYBIND, y)
	y = y - 30

	content:SetHeight(-y)
end

function ns:OpenSettings()
	if category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(category:GetID())
	end
end

ns:On("Login", function()
	local page = CreateFrame("Frame")
	page:Hide()
	page:SetScript("OnShow", function(self)
		self:SetScript("OnShow", nil)
		Build(self)
	end)
	if Settings and Settings.RegisterCanvasLayoutCategory then
		category = Settings.RegisterCanvasLayoutCategory(page, ns.name)
		Settings.RegisterAddOnCategory(category)
	end
end)
