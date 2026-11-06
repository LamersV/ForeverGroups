--[[
	ForeverGroups: results list (left side of the window)

	Rows are Blizzard's own search entries (LFGBrowseSearchEntryTemplate) so a
	listing looks the same as in the default finder, with Blizzard's role/member
	display and tooltip. Their own scripts are replaced: the default ones talk
	to Blizzard's browse panel, which is not ours.

	Nothing is rebuilt while the window is closed: a finished search, a changed
	sort or a reported listing only marks the list as stale.
--]]

local _, ns = ...
local L, W, Data
local Readable, canaccess = ns.Readable, ns.canaccess

local List = {}
ns.List = List

local ROW_TEMPLATE = "LFGBrowseSearchEntryTemplate"
local DIVIDER_TEMPLATE = "LFGBrowseSearchEntryGroupingTemplate"
local INVITE_ATLAS = "common-button-list-plus"
local ASK_ATLAS = "transmog-icon-chat"
local RELATION_ATLAS = {guild = "friends-icon-tab-guildmates", friend = "friends-icon-tab-friends"}
local GRAY = {r = 0.3, g = 0.3, b = 0.3}


--[[ Row contents ]]--

local function CanAct(row, info)
	return not row.isDelisted and not row.hasSelf and canaccess(info.leaderName)
end

local function UpdateButtons(row, info, isSolo)
	local invite, ask = row.FGInvite, row.FGAsk
	invite.action, ask.action = nil, nil
	ns.PaintActionButton(invite)
	ns.PaintActionButton(ask)
	if not CanAct(row, info) then
		invite:Hide()
		ask:Hide()
		row.DataDisplay:SetPoint("RIGHT", row, "RIGHT", -4, -1)
		return
	end
	local leader = info.leaderName

	-- Blizzard decides what "invite" means here (invite a player, or ask the group's leader)
	local _, inviteFunc = LFGBrowseUtil_GetInviteActionForResult(row.resultID)
	if inviteFunc then
		invite.action = function()
			inviteFunc()
			ns.Whisper(leader, Data:BuildInviteMessage(leader))
		end
	end
	invite:SetShown(inviteFunc ~= nil)

	-- groups only: whisper the leader the "ask to join" message (or open a whisper)
	if isSolo then
		ask:Hide()
	else
		ask.action = function()
			local message = Data:BuildAskMessage(leader)
			if not message then
				ChatFrameUtil.SendTell(leader)
				return false
			end
			ns.Whisper(leader, message)
		end
		ask:Show()
	end
	-- right to left: invite, ask, then Blizzard's role/member display
	ask:ClearAllPoints()
	if invite:IsShown() then
		ask:SetPoint("RIGHT", invite, "LEFT", -2, 0)
	else
		ask:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	end
	local last = ask:IsShown() and ask or invite:IsShown() and invite
	if last then
		row.DataDisplay:SetPoint("RIGHT", last, "LEFT", -2, -1)
	else
		row.DataDisplay:SetPoint("RIGHT", row, "RIGHT", -4, -1)
	end
end

local function LayOutName(row, isSolo, member, relation)
	row.PartyIcon:SetShown(not isSolo)
	local icon = row.FGRelation
	local atlas = relation and RELATION_ATLAS[relation]
	local anchor, x, y
	if isSolo then
		anchor, x, y = "TOPLEFT", row.NameSoloOffsetX or 0, row.NameSoloOffsetY or 0
	else
		anchor, x, y = "TOPRIGHT", row.NameGroupOffsetX or 0, row.NameGroupOffsetY or 0
	end
	row.Name:ClearAllPoints()
	if atlas then
		icon.Icon:SetAtlas(atlas)
		icon.relation = relation
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", row.PartyIcon, anchor, x, y)
		icon:Show()
		row.Name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 2, 0)
	else
		icon:Hide()
		row.Name:SetPoint("TOPLEFT", row.PartyIcon, anchor, x, y)
	end

	if not isSolo then
		row.ClassIcon:Hide()
		row.Level:Hide()
		row.NewPlayerFriendlyIcon:SetPoint("LEFT", row.Name, "RIGHT", 2, 0)
		return atlas and 18 or 0
	end
	row.NewPlayerFriendlyIcon:SetPoint("LEFT", row.ClassIcon, "RIGHT", 2, 0)
	local classAtlas = member and ns.ClassAtlas(member.classFilename)
	local level = member and member.level
	if not classAtlas or level == nil then
		row.ClassIcon:Hide()
		row.Level:Hide()
	else
		row.ClassIcon:SetAtlas(classAtlas, false)
		row.ClassIcon:Show()
		if canaccess(level) then
			row.Level:SetFormattedText("%s %s", L.LEVEL_ABBR, level)
		else
			row.Level:SetText(level)
		end
		row.Level:Show()
	end
	return atlas and 18 or 0
end

-- "|| Zone || Playstyle" after the activity name.
local function UpdateExtras(row, info, isSolo, member)
	local zone, style = row.FGZone, row.FGStyle
	local area = isSolo and member and member.areaName
	if area and (not canaccess(area) or area ~= "") then
		zone:SetText(canaccess(area) and ("|| " .. area) or area)
		zone:Show()
	else
		zone:Hide()
	end
	style:ClearAllPoints()
	style:SetPoint("BOTTOMLEFT", zone:IsShown() and zone or row.ActivityName, "BOTTOMRIGHT", 4, 0)
	local word = Data:PlaystyleName(Readable(info.generalPlaystyle, nil))
	if word ~= "" then
		style:SetText("|| " .. word)
		style:Show()
	else
		style:Hide()
	end
end

local function Colorize(row, info, isDelisted)
	local leader = C_LFGList.GetSearchResultLeaderInfo and C_LFGList.GetSearchResultLeaderInfo(row.resultID)
	local name = leader and ns.ClassColor(leader.classFilename) or NORMAL_FONT_COLOR
	local dim = GRAY_FONT_COLOR
	if isDelisted then
		name, dim = GRAY, GRAY
	end
	row.Name:SetTextColor(name.r, name.g, name.b)
	for _, region in ipairs({row.Level, row.ActivityName, row.FGZone, row.FGStyle}) do
		region:SetTextColor(dim.r, dim.g, dim.b)
	end
	row.ClassIcon:SetDesaturated(isDelisted)
	row.NewPlayerFriendlyIcon:SetDesaturated(isDelisted)
end

local function UpdateRow(row, node)
	local info = C_LFGList.GetSearchResultInfo(node.resultID)
	if not info then
		row:Hide()
		return
	end
	row:Show()
	row.resultID = node.resultID
	row.isDelisted = Readable(info.isDelisted, false) == true
	row.hasSelf = Readable(info.hasSelf, false) == true
	local members = Readable(info.numMembers, nil)
	local isSolo = members ~= nil and members <= 1
	local member = isSolo and C_LFGList.GetSearchResultPlayerInfo(node.resultID, 1) or nil

	local relationWidth = LayOutName(row, isSolo, member, node.relation)
	row.Name:SetWidth(0)
	row.Name:SetText(info.leaderName)
	local maxWidth = (row.NameMaxWidth or 150) - relationWidth
	local width = row.Name:GetWidth()
	if not canaccess(width) or width > maxWidth then
		row.Name:SetWidth(maxWidth)
	end

	local activityIDs = Readable(info.activityIDs, nil) or {}
	if #activityIDs == 1 then
		row.ActivityName:SetText(Data:ActivityName(C_LFGList.GetActivityInfoTable(activityIDs[1])))
	else
		row.ActivityName:SetFormattedText(L.ACTIVITY_COUNT, #activityIDs)
	end
	row.NewPlayerFriendlyIcon:SetShown(Readable(info.newPlayerFriendly, false) == true)
	UpdateExtras(row, info, isSolo, member)
	Colorize(row, info, row.isDelisted)
	UpdateButtons(row, info, isSolo)

	local displayType, maxPlayers = LFGBrowseUtil_GetBestDisplayTypeForActivityIDs(activityIDs)
	LFGBrowseGroupDataDisplay_Update(row.DataDisplay, displayType, maxPlayers,
		C_LFGList.GetSearchResultMemberCounts(node.resultID), row.isDelisted, isSolo,
		member and Readable(member.lfgRoles, nil) or nil, info.comment, row.hasSelf)
end


--[[ Row setup (once per recycled frame) ]]--

local function HideTooltips()
	if LFGBrowseSearchEntryTooltip then LFGBrowseSearchEntryTooltip:Hide() end
	GameTooltip:Hide()
end

local function ShowRowTooltip(row)
	local info = row.resultID and C_LFGList.GetSearchResultInfo(row.resultID)
	if not info then return end
	-- Blizzard's tooltip reads the comment with no guard; it errors when the comment is secret
	if LFGBrowseSearchEntryTooltip and canaccess(info.comment) then
		LFGBrowseSearchEntryTooltip_UpdateAndShow(LFGBrowseSearchEntryTooltip, row.resultID)
		LFGBrowseSearchEntryTooltip:ClearAllPoints()
		LFGBrowseSearchEntryTooltip:SetPoint("TOPLEFT", row, "TOPRIGHT", 8, 38)
	elseif info.leaderName ~= nil then
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		GameTooltip:SetText(info.leaderName)
		GameTooltip:Show()
	end
end

local function SetUpRow(row)
	if row.FGReady then return end
	row.FGReady = true
	row:UnregisterAllEvents()
	row:SetScript("OnEvent", nil)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", function(self, button)
		if self.isDelisted or self.hasSelf then return end
		ns.PlayClick()
		if button == "RightButton" then
			if LFGBrowseFrame and LFGBrowseFrame.CreateSearchEntryMenu then
				LFGBrowseFrame:CreateSearchEntryMenu(self) -- Blizzard's menu: whisper, report...
			end
		elseif IsShiftKeyDown() then
			local info = C_LFGList.GetSearchResultInfo(self.resultID)
			if info and canaccess(info.leaderName) then
				ChatFrameUtil.SendTell(info.leaderName)
			end
		end
	end)
	row:SetScript("OnEnter", function(self)
		if not (self.Selected and self.Selected:IsShown()) then self.Highlight:Show() end
		ShowRowTooltip(self)
	end)
	row:SetScript("OnLeave", function(self)
		self.Highlight:Hide()
		HideTooltips()
	end)

	row.FGInvite = W.ActionButton(row, INVITE_ATLAS, L.INVITE)
	row.FGInvite:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.FGAsk = W.ActionButton(row, ASK_ATLAS, L.ASK_TO_JOIN)

	local relation = CreateFrame("Frame", nil, row)
	relation:SetSize(16, 16)
	relation.Icon = relation:CreateTexture(nil, "ARTWORK")
	relation.Icon:SetAllPoints()
	relation:SetScript("OnEnter", function(self)
		ns.ShowTooltip(self, self.relation == "guild" and L.RELATION_GUILD or L.RELATION_FRIEND)
	end)
	relation:SetScript("OnLeave", GameTooltip_Hide)
	relation:Hide()
	row.FGRelation = relation

	for _, key in ipairs({"FGZone", "FGStyle"}) do
		local text = row:CreateFontString(nil, "ARTWORK", "GameFontDisableLeft")
		text:SetHeight(15)
		text:SetWordWrap(false)
		text:SetMaxLines(1)
		row[key] = text
	end
	row.FGZone:SetPoint("BOTTOMLEFT", row.ActivityName, "BOTTOMRIGHT", 4, 0)
	row.FGZone:SetWidth(180)
end


--[[ Panel ]]--

local panel, provider
local collapsed = {group = false, solo = false}
local stale, query, lastSearch = true, nil, nil

local function SetNotice(text)
	panel.Notice:SetText(text or "")
	panel.Notice:SetShown(text ~= nil)
end

local function Footer(result)
	if not panel.Footer then return end
	local text = L.FOOTER_COUNTS:format(#result.groups, #result.solos)
	if lastSearch then
		text = text .. "  ·  " .. L.FOOTER_TIME:format(date("%H:%M", lastSearch))
	end
	panel.Footer:SetText(text)
end

function List:Refresh()
	if not panel or not panel:IsVisible() then
		stale = true
		return
	end
	stale = false
	if Data.searching then return end
	if not Data:EnsureFinder() then
		SetNotice(L.FINDER_COMBAT)
		return
	end

	local result = Data:Build(Data.filters, query)
	provider = CreateTreeDataProvider()
	local function AddDivider(kind, nodes)
		if #nodes == 0 then return end
		local tree = provider:Insert({divider = kind})
		for _, node in ipairs(nodes) do tree:Insert(node) end
		tree:SetCollapsed(collapsed[kind], TreeDataProviderConstants.RetainChildCollapse,
			TreeDataProviderConstants.SkipInvalidation)
	end
	AddDivider("group", result.groups)
	AddDivider("solo", result.solos)
	for _, node in ipairs(result.unknown) do provider:Insert(node) end

	panel.ScrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
	if provider:IsEmpty() then
		SetNotice(Data.searchFailed and L.SEARCH_FAILED or (lastSearch and L.NO_RESULTS or L.NO_SEARCH_YET))
	else
		SetNotice(nil)
	end
	Footer(result)
end

-- Redraw one listing in place (a late leader name, a delisting). The event comes once per
-- result after each search: the visitor is made once, not a closure per event.
local wantedResult
local function VisitRow(frame, elementData)
	local node = elementData and elementData.data
	if node and node.resultID == wantedResult then
		UpdateRow(frame, node)
		return true
	end
end

local function UpdateResult(resultID)
	if not panel or not panel:IsVisible() or not panel.ScrollBox:GetDataProvider() then return end
	wantedResult = resultID
	panel.ScrollBox:ForEachFrame(VisitRow)
	wantedResult = nil
end

function List:SetQuery(text)
	query = text
	ns:Defer("list-query", function() List:Refresh() end, 0.15)
end

function List:Create(parent)
	L, W, Data = ns.L, ns.Widgets, ns.Data
	panel = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	local box, bar, notice = W.ScrollList(panel)
	panel.ScrollBox, panel.ScrollBar, panel.Notice = box, bar, notice

	local spinner = CreateFrame("Frame", nil, panel, "LoadingSpinnerTemplate")
	spinner:SetPoint("CENTER")
	spinner:Hide()
	local label = spinner:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	label:SetPoint("BOTTOM", spinner, "TOP")
	label:SetText(L.SEARCHING)
	panel.Spinner = spinner

	local view = CreateScrollBoxListTreeListView(0, 0, 0, 0, 0, 0)
	view:SetElementFactory(function(factory, elementData)
		local data = elementData.data
		if data.divider then
			factory(DIVIDER_TEMPLATE, function(frame, node)
				frame.CategoryLabel:SetText(data.divider == "solo" and L.PLAYERS or L.GROUPS)
				frame.CategoryLabel:Show()
				frame.ExpandIcon:SetShown(node:IsCollapsed())
				frame.CollapseIcon:SetShown(not node:IsCollapsed())
				frame:SetScript("OnClick", function()
					ns.PlayClick()
					collapsed[data.divider] = node:ToggleCollapsed()
					panel.ScrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
				end)
			end)
		else
			factory(ROW_TEMPLATE, function(frame)
				SetUpRow(frame)
				UpdateRow(frame, data)
			end)
		end
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)

	panel:HookScript("OnShow", function()
		if Data.searching then return end
		if stale then
			List:Refresh()
		elseif provider then
			-- rows were not redrawn while hidden
			panel.ScrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
		end
	end)

	ns:On("SearchStarted", function()
		SetNotice(nil)
		spinner:Show()
		provider = nil
		panel.ScrollBox:SetDataProvider(CreateTreeDataProvider())
	end)
	ns:On("SearchFinished", function(failed)
		spinner:Hide()
		if not failed then lastSearch = time() end
		List:Refresh()
	end)
	ns:On("ResultUpdated", UpdateResult)
	ns:On("ResultsChanged", function() List:Refresh() end)
	ns:On("SortChanged", function() List:Refresh() end)

	SetNotice(L.NO_SEARCH_YET)
	return panel
end
