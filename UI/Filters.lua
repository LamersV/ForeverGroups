--[[
	ForeverGroups: filter panel (right side of the window)

	Top: category, activities, Search; text filter, Role Check, settings.
	Tabs: "Filters" (groups, players, classes, more) and "Whispers".

	Ticking a box changes nothing until Search, except the text box, which
	narrows the current list as you type. The filters of the last search are
	saved and restored next session.
--]]

local _, ns = ...
local L, W, Data

local Filters = {}
ns.Filters = Filters

local PADDING = 12
local PANEL_WIDTH = 440
local COLUMN = 138
local ROW = 26

local ROLE_ATLAS = {
	tank = "groupfinder-icon-role-large-tank",
	healer = "groupfinder-icon-role-large-heal",
	dps = "groupfinder-icon-role-large-dps",
}

local panel


--[[ Activities ]]--

local function UpdateActivityText()
	local selected = panel.activities
	local text
	if #selected == 0 then
		text = L.ALL_ACTIVITIES
	elseif #selected == 1 then
		text = Data:ActivityName(C_LFGList.GetActivityInfoTable(selected[1]))
	else
		text = L.ACTIVITIES_SELECTED:format(#selected)
	end
	panel.Activity:OverrideText(text)
end

local function ToggleActivity(id)
	local index = tIndexOf(panel.activities, id)
	if index then
		table.remove(panel.activities, index)
	else
		table.insert(panel.activities, id)
	end
	UpdateActivityText()
end

local function AnyInGroup(group)
	for _, id in ipairs(Data:Activities(panel.category, group)) do
		if tContains(panel.activities, id) then return true end
	end
	return false
end

local function SetGroup(group, selected)
	for _, id in ipairs(Data:Activities(panel.category, group)) do
		local index = tIndexOf(panel.activities, id)
		if selected and not index then
			table.insert(panel.activities, id)
		elseif not selected and index then
			table.remove(panel.activities, index)
		end
	end
	UpdateActivityText()
end

local function SetupActivityMenu()
	panel.Activity:SetupMenu(function(dropdown, root)
		root:SetTag("MENU_FOREVERGROUPS_ACTIVITY")
		if (panel.category or 0) <= 0 then
			dropdown:SetEnabled(false)
			return
		end
		dropdown:SetEnabled(true)
		local function IsSelected(id) return tContains(panel.activities, id) end
		local activities = Data:Activities(panel.category)
		if #activities == 0 then return end
		local organized, infos, groups = Data:OrganizeActivities(activities)
		for _, group in ipairs(groups) do
			local ids = organized[group]
			if group == 0 then
				for _, id in ipairs(ids) do
					root:CreateCheckbox(Data:ActivityMenuText(infos[id]), IsSelected, ToggleActivity, id)
				end
			else
				local parent = root:CreateCheckbox(C_LFGList.GetActivityGroupInfo(group) or "?",
					function() return AnyInGroup(group) end,
					function() SetGroup(group, not AnyInGroup(group)) end, group)
				local nest = #groups > 1
				for _, id in ipairs(ids) do
					local text = Data:ActivityMenuText(infos[id])
					if nest then
						parent:CreateCheckbox(text, IsSelected, ToggleActivity, id)
					else
						root:CreateCheckbox("   " .. text, IsSelected, ToggleActivity, id)
					end
				end
			end
		end
	end)
	UpdateActivityText()
end


--[[ Categories ]]--

local SelectCategory

local function SetupCategoryMenu()
	panel.Category:SetupMenu(function(_, root)
		root:SetTag("MENU_FOREVERGROUPS_CATEGORY")
		local categories = Data:Categories()
		if #categories == 0 then
			root:CreateTitle(L.NO_CATEGORIES)
			return
		end
		for _, category in ipairs(categories) do
			root:CreateRadio(category.name, function(id) return panel.category == id end, SelectCategory, category.id)
		end
	end)
end

function SelectCategory(id)
	if panel.category ~= id then
		panel.activities = {}
	end
	panel.category = id
	SetupCategoryMenu()
	SetupActivityMenu()
	Filters:UpdateSearchButton()
end

-- Picks the saved (or first) category so the first click can already be Search.
local function SelectDefaultCategory()
	local categories = Data:Categories()
	local wanted = panel.category or ns.db.category
	for _, category in ipairs(categories) do
		if category.id == wanted then
			return SelectCategory(wanted)
		end
	end
	SelectCategory(categories[1] and categories[1].id or 0)
end


--[[ Reading and writing the boxes ]]--

local function Snapshot()
	local filters = Data:DefaultFilters()
	for key, check in pairs(panel.groupChecks) do filters.group[key] = check:GetChecked() or nil end
	for key, check in pairs(panel.roleChecks) do filters.roles[key] = check:GetChecked() and true or false end
	for class, check in pairs(panel.classChecks) do filters.classes[class] = check:GetChecked() and true or false end
	filters.hideClasses = CopyTable(panel.hideClasses)
	filters.playstyles = CopyTable(panel.playstyles)
	filters.languages = CopyTable(panel.languages)
	panel.Level:FixLevelRange()
	local low, high = panel.Level:GetLevelRange()
	filters.levelMin, filters.levelMax = low or 0, high or 0
	return filters
end

local function SetLevelBox(box, value)
	if value and value > 0 then box:SetNumber(value) else box:SetText("") end
end

local UpdateDropdownTexts, RefreshSections

local function Apply(filters)
	filters = Data:CleanFilters(filters)
	for key, check in pairs(panel.groupChecks) do check:SetChecked(filters.group[key] == true) end
	for key, check in pairs(panel.roleChecks) do check:SetChecked(filters.roles[key] == true) end
	for class, check in pairs(panel.classChecks) do check:SetChecked(filters.classes[class] == true) end
	panel.hideClasses = filters.hideClasses
	panel.playstyles = filters.playstyles
	panel.languages = filters.languages
	SetLevelBox(panel.Level.MinLevel, filters.levelMin)
	SetLevelBox(panel.Level.MaxLevel, filters.levelMax)
	UpdateDropdownTexts()
	RefreshSections()
end

function Filters:Reset()
	Apply(nil)
end


--[[ Multi-choice dropdowns: hidden classes, playstyles, languages ]]--

local function CountSet(set)
	local count, last = 0, nil
	for key, value in pairs(set) do
		if value then count, last = count + 1, key end
	end
	return count, last
end

function UpdateDropdownTexts()
	local count, only = CountSet(panel.hideClasses)
	if count == 0 or count == #ns.classes then
		panel.HideClasses:OverrideText(L.NONE)
	elseif count == 1 then
		panel.HideClasses:OverrideText(ns.ClassName(only))
	else
		panel.HideClasses:OverrideText(L.CLASSES_SELECTED:format(count))
	end

	count, only = CountSet(panel.playstyles)
	if count == 0 or count == #Data.playstyles then
		panel.Playstyle:OverrideText(L.ALL)
	elseif count == 1 then
		for _, style in ipairs(Data.playstyles) do
			if style.key == only then panel.Playstyle:OverrideText(Data:PlaystyleName(style.value)) end
		end
	else
		panel.Playstyle:OverrideText(L.SELECTED_COUNT:format(count))
	end

	local offered, locked = Data:Languages()
	local names = {}
	for _, code in ipairs(offered) do
		if locked[code] or panel.languages[code] then names[#names + 1] = Data:LanguageName(code) end
	end
	panel.Languages:OverrideText(#names == 0 and L.DEFAULT or #names <= 2 and table.concat(names, ", ")
		or L.SELECTED_COUNT:format(#names))
end

local function SetupMultiMenus()
	local function Toggle(set)
		return function(key)
			panel[set][key] = not panel[set][key] or nil
			UpdateDropdownTexts()
			RefreshSections()
		end
	end

	panel.HideClasses:SetupMenu(function(_, root)
		root:SetTag("MENU_FOREVERGROUPS_HIDE_CLASSES")
		root:CreateButton(L.UNSELECT_ALL, function()
			wipe(panel.hideClasses)
			UpdateDropdownTexts()
			RefreshSections()
			return MenuResponse and MenuResponse.Refresh
		end)
		for _, class in ipairs(ns.classes) do
			local color = RAID_CLASS_COLORS[class]
			local text = color and color:WrapTextInColorCode(ns.ClassName(class)) or ns.ClassName(class)
			root:CreateCheckbox(text, function(key) return panel.hideClasses[key] == true end, Toggle("hideClasses"), class)
		end
	end)

	panel.Playstyle:SetupMenu(function(_, root)
		root:SetTag("MENU_FOREVERGROUPS_PLAYSTYLE")
		for _, style in ipairs(Data.playstyles) do
			if style.value then
				root:CreateCheckbox(Data:PlaystyleName(style.value),
					function(key) return panel.playstyles[key] == true end, Toggle("playstyles"), style.key)
			end
		end
	end)

	panel.Languages:SetupMenu(function(_, root)
		root:SetTag("MENU_FOREVERGROUPS_LANGUAGES")
		local offered, locked = Data:Languages()
		if #offered == 0 then
			root:CreateTitle(L.NO_LANGUAGES)
			return
		end
		for _, code in ipairs(offered) do
			local box = root:CreateCheckbox(Data:LanguageName(code),
				function(key) return locked[key] or panel.languages[key] == true end,
				function(key)
					if not locked[key] then Toggle("languages")(key) end
				end, code)
			if locked[code] then box:SetEnabled(false) end
		end
	end)
end


--[[ Sections ]]--

local function ChecksChanged(checks, default)
	for key, check in pairs(checks) do
		if (check:GetChecked() and true or false) ~= default(key) then return true end
	end
	return false
end

local function LayOutSections()
	local above = panel.SectionsTop
	for _, section in ipairs(panel.sections) do
		section:ClearAllPoints()
		section:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, above == panel.SectionsTop and 0 or -14)
		section:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
		above = section
	end
end

function RefreshSections()
	for _, section in ipairs(panel.sections) do section:Refresh() end
end

local function NewSection(key, title, rows)
	local section = W.Section(panel, title, rows * ROW + 2, function(self)
		ns.db.collapsed[key] = self.collapsed or nil
		LayOutSections()
	end)
	section.key = key
	table.insert(panel.sections, section)
	return section
end

local function Cell(section, column, row)
	return (column - 1) * COLUMN, -(row - 1) * ROW
end

local function HeaderLinks(section, links)
	local right
	for index = #links, 1, -1 do
		local link = links[index]
		if right then
			local separator = W.Separator(section.Header)
			separator:SetPoint("RIGHT", right, "LEFT", -4, 0)
			link:SetPoint("RIGHT", separator, "LEFT", -4, 0)
			link.Separator = separator
		else
			link:SetPoint("RIGHT", section.Header, "RIGHT", 0, 0)
		end
		link:SetFrameLevel(section.Header:GetFrameLevel() + 2)
		right = link
	end
end


--[[ My filters ]]--

local POPUP = "FOREVERGROUPS_SAVE_FILTER"

local function PopupEditBox(dialog)
	return dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox or dialog.EditBox
end

local function SaveFromPopup(dialog)
	local name = PopupEditBox(dialog):GetText()
	local problem = Data:MyFilterProblem(name)
	if problem then
		ns:Print(problem)
		return true -- keep the popup open
	end
	Data:SaveMyFilter(name, Snapshot())
	ns:Print(L.MY_FILTER_SAVED:format(strtrim(name)))
	Filters:UpdateMyFilters()
end

local function RegisterPopup()
	StaticPopupDialogs[POPUP] = {
		text = L.MY_FILTER_PROMPT,
		button1 = SAVE or OKAY,
		button2 = CANCEL,
		hasEditBox = 1,
		maxLetters = Data.MY_FILTER_NAME_MAX,
		OnShow = function(dialog)
			local box = PopupEditBox(dialog)
			box:SetText("")
			box:SetFocus()
		end,
		OnAccept = SaveFromPopup,
		EditBoxOnEnterPressed = function(box)
			local dialog = box:GetParent()
			if not SaveFromPopup(dialog) then dialog:Hide() end
		end,
		EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
		hideOnEscape = 1,
		timeout = 0,
		whileDead = 1,
	}
end

function Filters:UpdateMyFilters()
	local count = #ns.db.myFilters
	panel.MyFilters:SetShown(count > 0)
	if panel.MyFilters.Separator then panel.MyFilters.Separator:SetShown(count > 0) end
	panel.SaveFilter:SetEnabled(count < Data.MY_FILTERS_MAX)
end

local function SetupMyFiltersMenu()
	panel.MyFilters:SetupMenu(function(_, root)
		root:SetTag("MENU_FOREVERGROUPS_MY_FILTERS")
		for _, entry in ipairs(ns.db.myFilters) do
			root:CreateButton(entry.name, function()
				Apply(entry.filters)
				ns:Print(L.MY_FILTER_APPLIED:format(entry.name))
			end)
		end
		root:CreateDivider()
		local delete = root:CreateButton(DELETE or L.DELETE)
		for _, entry in ipairs(ns.db.myFilters) do
			delete:CreateButton(entry.name, function()
				Data:DeleteMyFilter(entry.name)
				Filters:UpdateMyFilters()
			end)
		end
	end)
end


--[[ Search row ]]--

function Filters:UpdateSearchButton()
	if not panel then return end
	panel.Search:SetEnabled(not Data.searching and (panel.category or 0) > 0)
end

local function CanRoleCheck()
	local inGroup = IsInGroup()
	if not ns.canaccess(inGroup) then return true end
	if not inGroup then return false end
	local leader, assistant = UnitIsGroupLeader("player"), UnitIsGroupAssistant("player")
	if not ns.canaccess(leader) or not ns.canaccess(assistant) then return true end
	return leader or assistant
end

local function UpdateRoleCheck()
	panel.RoleCheck:SetEnabled(not panel.RoleCheck.cooling and CanRoleCheck())
end


--[[ Build ]]--

local function BuildSearchRow()
	panel.Category = W.Dropdown(panel, 128, L.CATEGORY)
	panel.Category:SetPoint("TOPLEFT", PADDING, -PADDING)
	panel.Activity = W.Dropdown(panel, 180, L.ALL_ACTIVITIES)
	panel.Activity:SetPoint("LEFT", panel.Category, "RIGHT", 6, 0)

	local search = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	search:SetSize(96, 26)
	search:SetText(SEARCH or L.SEARCH)
	search:SetPoint("LEFT", panel.Activity, "RIGHT", 6, 0)
	search:SetScript("OnClick", function()
		ns.PlayClick()
		Data:Search(panel.category, CopyTable(panel.activities), Snapshot())
		Filters:UpdateSearchButton()
	end)
	panel.Search = search

	local text = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
	text:SetSize(230, 22)
	text:SetPoint("TOPLEFT", panel.Category, "BOTTOMLEFT", 6, -8)
	if text.Instructions then text.Instructions:SetText(L.TEXT_FILTER) end
	text:HookScript("OnTextChanged", function(self)
		ns.List:SetQuery(self:GetText())
	end)
	text:SetScript("OnEnter", function(self) ns.ShowTooltip(self, L.TEXT_FILTER, L.TEXT_FILTER_TIP) end)
	text:SetScript("OnLeave", GameTooltip_Hide)
	panel.Text = text

	local roleCheck = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	roleCheck:SetSize(130, 22)
	roleCheck:SetText(L.ROLE_CHECK)
	roleCheck:SetPoint("LEFT", text, "RIGHT", 8, 0)
	roleCheck:SetMotionScriptsWhileDisabled(true)
	roleCheck:SetScript("OnClick", function(self)
		if self.cooling or not CanRoleCheck() then return end
		ns.PlayClick()
		InitiateRolePoll()
		self.cooling = true
		UpdateRoleCheck()
		C_Timer.After(2, function()
			self.cooling = false
			UpdateRoleCheck()
		end)
	end)
	roleCheck:SetScript("OnEnter", function(self)
		if not CanRoleCheck() then ns.ShowTooltip(self, L.ROLE_CHECK, L.ROLE_CHECK_LEADER) end
	end)
	roleCheck:SetScript("OnLeave", GameTooltip_Hide)
	panel.RoleCheck = roleCheck
	for _, event in ipairs({"GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED"}) do
		ns:RegisterEvent(event, function() if panel then UpdateRoleCheck() end end)
	end

	local gear = CreateFrame("Button", nil, panel)
	gear:SetSize(18, 18)
	gear:SetPoint("LEFT", roleCheck, "RIGHT", 8, 0)
	gear.Icon = gear:CreateTexture(nil, "ARTWORK")
	gear.Icon:SetAllPoints()
	gear.Icon:SetAtlas("OptionsIcon-Brown")
	gear.Icon:SetAlpha(0.8)
	gear:SetScript("OnEnter", function(self)
		self.Icon:SetAlpha(1)
		ns.ShowTooltip(self, L.SETTINGS)
	end)
	gear:SetScript("OnLeave", function(self)
		self.Icon:SetAlpha(0.8)
		GameTooltip:Hide()
	end)
	gear:SetScript("OnClick", function()
		ns.PlayClick()
		ns:OpenSettings()
	end)

	local top = CreateFrame("Frame", nil, panel)
	top:SetPoint("TOPLEFT", panel.Category, "BOTTOMLEFT", 0, -46)
	top:SetSize(1, 1)
	panel.SectionsTop = top
end

local function BuildGroupSection()
	local section = NewSection("groups", L.SECTION_GROUPS, 3)
	local content = section.Content
	panel.groupChecks = {}
	local cells = {
		{"tankAvailable", "tank", L.GROUP_TANK_AVAILABLE, 1, 1},
		{"healerAvailable", "healer", L.GROUP_HEALER_AVAILABLE, 2, 1},
		{"damageAvailable", "dps", L.GROUP_DAMAGE_AVAILABLE, 3, 1},
		{"hasTank", "tank", L.GROUP_HAS_TANK, 1, 2},
		{"hasHealer", "healer", L.GROUP_HAS_HEALER, 2, 2},
	}
	for _, cell in ipairs(cells) do
		local check = W.IconCheck(content, ROLE_ATLAS[cell[2]], cell[3], function() section:Refresh() end)
		check:SetPoint("TOPLEFT", Cell(section, cell[4], cell[5]))
		panel.groupChecks[cell[1]] = check
	end
	local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", 4, -2 * ROW - 6)
	label:SetText(L.HIDE_GROUPS_WITH)
	panel.HideClasses = W.Dropdown(content, 170)
	panel.HideClasses:SetPoint("LEFT", label, "RIGHT", 8, 0)

	section.IsChanged = function()
		return ChecksChanged(panel.groupChecks, function() return false end) or next(panel.hideClasses) ~= nil
	end

	-- header: My filters ▾ | Save filter | Reset
	panel.MyFilters = CreateFrame("DropdownButton", nil, section.Header)
	local myLabel = panel.MyFilters:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	myLabel:SetPoint("LEFT")
	myLabel:SetText(L.MY_FILTERS .. " ▾")
	panel.MyFilters:SetSize(myLabel:GetStringWidth() + 2, 16)
	panel.MyFilters:SetScript("OnEnter", function() myLabel:SetFontObject(GameFontHighlightSmall) end)
	panel.MyFilters:SetScript("OnLeave", function() myLabel:SetFontObject(GameFontNormalSmall) end)
	panel.SaveFilter = W.Link(section.Header, L.SAVE_FILTER, function()
		StaticPopup_Show(POPUP)
	end)
	local reset = W.Link(section.Header, L.RESET, function() Filters:Reset() end)
	HeaderLinks(section, {panel.MyFilters, panel.SaveFilter, reset})
end

local function BuildPlayerSection()
	local section = NewSection("roles", L.SECTION_PLAYERS, 2)
	local content = section.Content
	panel.roleChecks = {}
	local roles = {{"tank", L.ROLE_TANK}, {"healer", L.ROLE_HEALER}, {"dps", L.ROLE_DAMAGE}}
	for index, role in ipairs(roles) do
		local check = W.IconCheck(content, ROLE_ATLAS[role[1]], role[2], function() section:Refresh() end)
		check:SetPoint("TOPLEFT", Cell(section, index, 1))
		panel.roleChecks[role[1]] = check
	end
	local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", 4, -ROW - 6)
	label:SetText(L.LEVEL)
	local range = CreateFrame("Frame", nil, content, "LevelRangeFrameTemplate")
	range:SetPoint("LEFT", label, "RIGHT", 8, 0)
	for _, box in ipairs({range.MinLevel, range.MaxLevel}) do
		box:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
		box:HookScript("OnTextChanged", function() section:Refresh() end)
	end
	panel.Level = range

	section.IsChanged = function()
		local low, high = range:GetLevelRange()
		return ChecksChanged(panel.roleChecks, function() return true end) or (low or 0) > 0 or (high or 0) > 0
	end
end

local function BuildClassSection()
	local section = NewSection("classes", L.SECTION_CLASSES, 3)
	local content = section.Content
	panel.classChecks = {}
	for index, class in ipairs(ns.classes) do
		local color = RAID_CLASS_COLORS[class]
		local check = W.IconCheck(content, ns.ClassAtlas(class), ns.ClassName(class), function() section:Refresh() end)
		if color then check.Text:SetTextColor(color.r, color.g, color.b) end
		check:SetPoint("TOPLEFT", Cell(section, (index - 1) % 3 + 1, math.floor((index - 1) / 3) + 1))
		panel.classChecks[class] = check
	end
	local function SetAll(value)
		for _, check in pairs(panel.classChecks) do check:SetChecked(value) end
		section:Refresh()
	end
	HeaderLinks(section, {
		W.Link(section.Header, L.SELECT_ALL, function() SetAll(true) end),
		W.Link(section.Header, L.UNSELECT_ALL, function() SetAll(false) end),
	})
	section.IsChanged = function()
		return ChecksChanged(panel.classChecks, function() return true end)
	end
end

local function BuildMoreSection()
	local section = NewSection("more", L.SECTION_MORE, 2)
	local content = section.Content
	local function Row(index, text, width)
		local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		label:SetPoint("TOPLEFT", 4, -(index - 1) * ROW - 6)
		label:SetWidth(90)
		label:SetJustifyH("LEFT")
		label:SetText(text)
		local dropdown = W.Dropdown(content, width)
		dropdown:SetPoint("LEFT", label, "RIGHT", 4, 0)
		return dropdown
	end
	panel.Playstyle = Row(1, L.PLAYSTYLE, 220)
	panel.Languages = Row(2, L.LANGUAGES, 220)
	section.IsChanged = function()
		return next(panel.playstyles) ~= nil or next(panel.languages) ~= nil
	end
end

local function BuildTabs(log)
	local tabs = CreateFrame("Frame", nil, panel, "TabSystemTemplate")
	tabs.tabTemplate = "TabSystemTopButtonTemplate"
	TabSystemMixin.OnLoad(tabs)
	tabs:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 18, 0)
	Mixin(panel, TabSystemOwnerMixin)
	TabSystemOwnerMixin.OnLoad(panel)
	panel:SetTabSystem(tabs)

	local whispers = W.Section(panel, L.WHISPERS, 0)
	whispers.Header:SetScript("OnClick", nil)
	whispers.Header.Icon:Hide()
	whispers:SetPoint("TOPLEFT", panel.Category, "BOTTOMLEFT", 0, -46)
	whispers:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
	HeaderLinks(whispers, {W.Link(whispers.Header, L.CLEAR, function() ns.Whispers:Clear() end)})
	log:SetPoint("TOPLEFT", whispers.Rule, "BOTTOMLEFT", 0, -6)
	log:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PADDING + 4, PADDING)

	panel.filtersTab = panel:AddNamedTab(L.FILTERS, unpack(panel.sections))
	panel.whispersTab = panel:AddNamedTab(L.WHISPERS, whispers, log)
	panel.TabSystem = tabs

	-- unread whispers: a small counter on the Whispers tab
	local button = tabs.GetTabButton and tabs:GetTabButton(panel.whispersTab)
	if button then
		local badge = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		badge:SetPoint("TOPRIGHT", -4, -2)
		badge:SetTextColor(1, 0.82, 0)
		panel.Badge = badge
	end
	hooksecurefunc(panel, "SetTab", function(_, tabID)
		panel.currentTab = tabID
		if tabID == panel.whispersTab then ns.Whispers:MarkRead() end
		Filters:UpdateBadge()
	end)
	panel:SetTab(panel.filtersTab)
end

function Filters:UpdateBadge()
	if not panel or not panel.Badge then return end
	local unread = ns.Whispers.unread
	panel.Badge:SetText(unread > 0 and unread or "")
end

function Filters:Create(parent)
	L, W, Data = ns.L, ns.Widgets, ns.Data
	panel = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	panel:SetWidth(PANEL_WIDTH)
	panel.activities = {}
	panel.sections = {}
	panel.hideClasses, panel.playstyles, panel.languages = {}, {}, {}

	BuildSearchRow()
	BuildGroupSection()
	BuildPlayerSection()
	BuildClassSection()
	BuildMoreSection()
	for _, section in ipairs(panel.sections) do
		section:SetCollapsed(ns.db.collapsed[section.key])
	end
	LayOutSections()
	BuildTabs(ns.WhisperLog:Create(panel))

	RegisterPopup()
	SetupMultiMenus()
	SetupMyFiltersMenu()
	SetupCategoryMenu()
	Apply(ns.db.filters)
	SelectDefaultCategory()
	self:UpdateMyFilters()
	self:UpdateBadge()
	UpdateRoleCheck()

	Data.selectedActivities = function() return CopyTable(panel.activities) end

	ns:On("SearchStarted", function() Filters:UpdateSearchButton() end)
	ns:On("SearchFinished", function() Filters:UpdateSearchButton() end)
	ns:On("Availability", function() SelectDefaultCategory() end)
	ns:On("LevelsChanged", function()
		panel.activities = {}
		SelectDefaultCategory()
	end)
	ns:On("WhisperReceived", function()
		if panel:IsVisible() and panel.currentTab == panel.whispersTab then
			ns.Whispers:MarkRead()
		end
		Filters:UpdateBadge()
	end)
	ns:On("WhispersRead", function() Filters:UpdateBadge() end)
	ns:On("WhispersChanged", function() Filters:UpdateBadge() end)
	panel:HookScript("OnShow", function()
		-- the finder may have loaded since the panel was built
		if (panel.category or 0) <= 0 then SelectDefaultCategory() end
		if panel.currentTab == panel.whispersTab then ns.Whispers:MarkRead() end
		Filters:UpdateBadge()
	end)
	return panel
end
