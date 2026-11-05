--[[
	ForeverGroups: whisper log (the "Whispers" tab)

	One row per whisper: name, level and class icon, the message, and an action
	line (Reply · Where · Invite · Remove). Every field may be secret in
	instances, so each goes into its own FontString with a single SetText and is
	never combined with other text.
--]]

local _, ns = ...
local L, W, Data
local Readable = ns.Readable

local WhisperLog = {}
ns.WhisperLog = WhisperLog

local ROW_HEIGHT, ACTION_HEIGHT = 26, 16
local MENU_MARKER = "foreverGroupsWhisper"

-- Copying a name from an addon-opened menu is blocked by the game; grey it out.
local menuModified = false
local function ModifyMenu()
	if menuModified or not (Menu and Menu.ModifyMenu) then return end
	menuModified = true
	Menu.ModifyMenu("MENU_UNIT_FRIEND", function(_, root, context)
		if not (context and context[MENU_MARKER]) or not COPY_CHARACTER_NAME then return end
		for _, element in root:EnumerateElementDescriptions() do
			if MenuUtil.GetElementText(element) == COPY_CHARACTER_NAME then
				element:SetEnabled(false)
				return
			end
		end
	end)
end

local function OpenMenu(row)
	local entry = row.entry
	local name = entry and entry.actionName
	if not name or not UnitPopup_OpenMenu then return end
	UnitPopup_OpenMenu("FRIEND", {
		name = name,
		chatType = "WHISPER",
		chatTarget = name,
		chatFrame = DEFAULT_CHAT_FRAME,
		lineID = Readable(entry.lineID, nil),
		guid = Readable(entry.guid, nil),
		ownerFrame = row,
		[MENU_MARKER] = true,
	})
end

local function WhoListAvailable()
	if not WhoFrameEditBox then return false end
	if C_GameRules and C_GameRules.IsGameRuleActive and Enum.GameRule and Enum.GameRule.IngameWhoListDisabled then
		return not C_GameRules.IsGameRuleActive(Enum.GameRule.IngameWhoListDisabled)
	end
	return true
end

local function BuildRow(row)
	local bg = row:CreateTexture(nil, "BACKGROUND")
	bg:SetColorTexture(1, 1, 1, 0.04)
	bg:SetPoint("TOPLEFT", 3, -2)
	bg:SetPoint("BOTTOMRIGHT", -3, 0)
	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAtlas("groupfinder-highlightbar-blue")
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints(bg)

	row.Relation = row:CreateTexture(nil, "ARTWORK")
	row.Relation:SetSize(16, 16)
	row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
	row.Name:SetWordWrap(false)
	row.Level = row:CreateFontString(nil, "ARTWORK", "GameFontDisableLeft")
	row.Level:SetPoint("LEFT", row.Name, "RIGHT", 4, 0)
	row.ClassIcon = row:CreateTexture(nil, "ARTWORK")
	row.ClassIcon:SetSize(20, 20)
	row.ClassIcon:SetPoint("LEFT", row.Level, "RIGHT", 3, 0)
	row.Message = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
	row.Message:SetWordWrap(false)
	row.Time = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	row.Time:SetPoint("BOTTOMLEFT", 8, 4)

	local actions = CreateFrame("Frame", nil, row)
	actions:SetPoint("BOTTOMLEFT", 8, 2)
	actions:SetPoint("BOTTOMRIGHT", -8, 2)
	actions:SetHeight(ACTION_HEIGHT)
	row.Remove = W.Link(actions, L.REMOVE, function()
		if row.entry then ns.Whispers:Remove(row.entry) end
	end)
	row.Reply = W.Link(actions, L.REPLY, function()
		if row.entry and row.entry.actionName then ChatFrameUtil.SendTell(row.entry.actionName) end
	end)
	row.Where = W.ActionLink(actions, L.WHERE)
	row.Invite = W.ActionLink(actions, L.INVITE)
	row.Separators = {W.Separator(actions), W.Separator(actions), W.Separator(actions)}

	row:RegisterForClicks("RightButtonUp")
	row:SetScript("OnClick", function(self)
		ns.PlayClick()
		OpenMenu(self)
	end)
	row:SetScript("OnEnter", function(self)
		if not self.entry or self.entry.text == nil then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.entry.text, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
end

local function LayOutActions(row, links)
	for _, link in ipairs({row.Remove, row.Reply, row.Where, row.Invite}) do link:Hide() end
	for _, separator in ipairs(row.Separators) do separator:Hide() end
	local right
	for index = #links, 1, -1 do
		local link = links[index]
		link:ClearAllPoints()
		if right then
			local separator = row.Separators[#links - index]
			separator:ClearAllPoints()
			separator:SetPoint("RIGHT", right, "LEFT", -4, 0)
			separator:Show()
			link:SetPoint("RIGHT", separator, "LEFT", -4, 0)
		else
			link:SetPoint("RIGHT")
		end
		link:Show()
		right = link
	end
end

local function FillRow(row, entry)
	if not row.Name then BuildRow(row) end
	row.entry = entry

	local relation = Data:RelationByGUID(entry.guid)
	row.Name:ClearAllPoints()
	if relation then
		row.Relation:SetAtlas(relation == "guild" and "friends-icon-tab-guildmates" or "friends-icon-tab-friends")
		row.Relation:SetPoint("LEFT", row, "TOPLEFT", 8, -ROW_HEIGHT / 2)
		row.Relation:Show()
		row.Name:SetPoint("LEFT", row.Relation, "RIGHT", 2, 0)
	else
		row.Relation:Hide()
		row.Name:SetPoint("LEFT", row, "TOPLEFT", 8, -ROW_HEIGHT / 2)
	end
	row.Name:SetWidth(0)
	row.Name:SetText(entry.name)
	local width = row.Name:GetWidth()
	if not ns.canaccess(width) or width > 140 then row.Name:SetWidth(140) end
	local color = ns.ClassColor(entry.class) or NORMAL_FONT_COLOR
	row.Name:SetTextColor(color.r, color.g, color.b)

	local atlas = ns.ClassAtlas(entry.class)
	local decorated = atlas ~= nil and entry.level ~= nil
	if decorated then
		row.ClassIcon:SetAtlas(atlas, false)
		row.Level:SetFormattedText("%s %s", L.LEVEL_ABBR, entry.level)
	end
	row.ClassIcon:SetShown(decorated)
	row.Level:SetShown(decorated)

	row.Message:ClearAllPoints()
	row.Message:SetPoint("LEFT", decorated and row.ClassIcon or row.Name, "RIGHT", 4, 0)
	row.Message:SetPoint("RIGHT", row, "TOPRIGHT", -8, -ROW_HEIGHT / 2)
	row.Message:SetText(entry.text)
	row.Time:SetText(date("%H:%M", entry.time))

	local links = {}
	local name = entry.actionName
	row.Where.action, row.Invite.action = nil, nil
	if name then
		links[#links + 1] = row.Reply
		if WhoListAvailable() then
			row.Where.action = function() ChatFrameUtil.OpenChat('/who "' .. name .. '"') end
			links[#links + 1] = row.Where
		end
		row.Invite.action = function() C_PartyInfo.InviteUnit(name) end
		links[#links + 1] = row.Invite
	end
	links[#links + 1] = row.Remove
	ns.PaintActionButton(row.Where)
	ns.PaintActionButton(row.Invite)
	LayOutActions(row, links)
end

local log, provider

-- The provider is rebuilt from ns.Whispers only while the tab is visible.
function WhisperLog:Refresh()
	if not log or not log:IsVisible() then
		self.stale = true
		return
	end
	self.stale = false
	provider = CreateDataProvider(ns.Whispers.entries)
	log.ScrollBox:SetDataProvider(provider)
	log.ScrollBox:ScrollToEnd()
	log.Notice:SetShown(#ns.Whispers.entries == 0)
	ns.Whispers:MarkRead()
end

function WhisperLog:Create(parent)
	L, W, Data = ns.L, ns.Widgets, ns.Data
	ModifyMenu()
	log = CreateFrame("Frame", nil, parent)
	local box, bar, notice = W.ScrollList(log)
	log.ScrollBox, log.Notice = box, notice
	notice:SetText(L.NO_WHISPERS)

	local view = CreateScrollBoxListLinearView(0, 0, 0, 0, 0)
	view:SetElementExtent(ROW_HEIGHT + ACTION_HEIGHT + 2)
	view:SetElementInitializer("Button", FillRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)

	log:SetScript("OnShow", function() WhisperLog:Refresh() end)
	ns:On("WhisperReceived", function() WhisperLog:Refresh() end)
	ns:On("WhispersChanged", function() WhisperLog:Refresh() end)
	self.stale = true
	return log
end
