--[[
	ForeverGroups: small UI building blocks shared by the window and the settings.
	Only templates that exist in the base UI are used here (no LFG templates:
	those load on demand with Blizzard's finder).
--]]

local _, ns = ...

local W = {}
ns.Widgets = W


--[[ Text link: "Reset filters", "Select all"... ]]--

function W.Link(parent, label, onClick)
	local link = CreateFrame("Button", nil, parent)
	local text = link:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	link:SetFontString(text)
	link:SetNormalFontObject(GameFontNormalSmall)
	link:SetHighlightFontObject(GameFontHighlightSmall)
	link:SetDisabledFontObject(GameFontDisableSmall)
	link:SetText(label)
	link:SetSize(text:GetStringWidth() + 2, 16)
	if onClick then
		link:SetScript("OnClick", function(self, ...)
			ns.PlayClick()
			onClick(self, ...)
		end)
	end
	return link
end

function W.Separator(parent)
	local separator = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	separator:SetText("||")
	return separator
end


--[[ Checkbox with an icon (roles, classes) ]]--

function W.IconCheck(parent, atlas, label, onClick)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(26, 26)
	local icon = check:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("LEFT", check, "RIGHT", 1, 0)
	if atlas then icon:SetAtlas(atlas, false) end
	check.Icon = icon
	check.Text:ClearAllPoints()
	check.Text:SetPoint("LEFT", icon, "RIGHT", 3, 0)
	check.Text:SetFontObject(GameFontHighlightSmall)
	check.Text:SetText(label)
	check:SetScript("OnClick", function(self)
		ns.PlayClick()
		if onClick then onClick(self, self:GetChecked()) end
	end)
	return check
end


--[[ Dropdown (the modern menu system) ]]--

function W.Dropdown(parent, width, defaultText)
	local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(width)
	if defaultText then dropdown:SetDefaultText(defaultText) end
	return dropdown
end


--[[ Scroll list with its bar and an empty-list notice ]]--

function W.ScrollList(parent)
	local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	box:SetPoint("TOPLEFT", 4, -4)
	box:SetPoint("BOTTOMRIGHT", -22, 4)
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 4, 0)
	bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 4, 0)
	local notice = parent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	notice:SetPoint("LEFT", box, 8, 0)
	notice:SetPoint("RIGHT", box, -8, 0)
	notice:SetWordWrap(true)
	notice:Hide()
	return box, bar, notice
end


--[[ Small square action button on a row (invite, ask to join) ]]--

function W.ActionButton(parent, atlas, tooltip)
	local button = CreateFrame("Button", nil, parent, "UIMenuButtonStretchTemplate")
	button:SetSize(24, 22)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAtlas(atlas)
	icon:SetSize(13, 13)
	icon:SetPoint("CENTER")
	button.Icon = icon
	button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	button:SetScript("OnClick", function(self) ns.RunAction(self.action) end)
	button:SetScript("OnEnter", function(self) ns.ShowTooltip(self, tooltip) end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	ns.RegisterActionButton(button)
	button:Hide()
	return button
end

-- A text link that runs through the shared action cooldown.
function W.ActionLink(parent, label)
	local link = W.Link(parent, label)
	link:SetScript("OnClick", function(self) ns.RunAction(self.action) end)
	ns.RegisterActionButton(link)
	return link
end


--[[
	Collapsible section: a clickable title with +/- and a rule under it, and a
	Content frame of a fixed height. A folded section whose filters differ from
	the defaults shows a warning icon, since those filters still apply.
--]]

local HEADER_HEIGHT, RULE_GAP = 18, 4

function W.Section(parent, title, contentHeight, onToggle)
	local section = CreateFrame("Frame", nil, parent)
	section.contentHeight = contentHeight

	local header = CreateFrame("Button", nil, section)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_HEIGHT)
	local icon = header:CreateTexture(nil, "ARTWORK")
	icon:SetSize(13, 13)
	icon:SetPoint("LEFT")
	header.Icon = icon
	local text = header:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
	text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
	header:SetFontString(text)
	header:SetNormalFontObject(GameFontNormalMed2)
	header:SetHighlightFontObject(GameFontHighlightMed2)
	header:SetText(title)
	section.Header = header

	local warning = CreateFrame("Frame", nil, header)
	warning:SetSize(14, 14)
	warning:SetPoint("LEFT", text, "RIGHT", 4, 0)
	local warningIcon = warning:CreateTexture(nil, "ARTWORK")
	warningIcon:SetAllPoints()
	warningIcon:SetTexture("Interface\\EncounterJournal\\UI-EJ-WarningTextIcon")
	warning:SetScript("OnEnter", function(self) ns.ShowTooltip(self, ns.L.SECTION_CHANGED) end)
	warning:SetScript("OnLeave", GameTooltip_Hide)
	warning:Hide()
	section.Warning = warning

	local rule = section:CreateTexture(nil, "ARTWORK")
	rule:SetAtlas("Options_HorizontalDivider", false)
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -RULE_GAP)
	rule:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -RULE_GAP)
	section.Rule = rule

	local content = CreateFrame("Frame", nil, section)
	content:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -4)
	content:SetPoint("TOPRIGHT", rule, "BOTTOMRIGHT", 0, -4)
	content:SetHeight(contentHeight)
	section.Content = content

	-- returns true when the section's filters differ from the defaults
	section.IsChanged = function() return false end

	function section:Refresh()
		local collapsed = self.collapsed
		header.Icon:SetAtlas(collapsed and "common-button-list-plus" or "common-button-list-minus")
		content:SetShown(not collapsed)
		warning:SetShown(collapsed and self:IsChanged() or false)
		self:SetHeight(HEADER_HEIGHT + RULE_GAP + 1 + (collapsed and 0 or (4 + self.contentHeight)))
	end

	function section:SetCollapsed(collapsed)
		self.collapsed = collapsed and true or false
		self:Refresh()
	end

	header:SetScript("OnClick", function()
		ns.PlayClick()
		section:SetCollapsed(not section.collapsed)
		if onToggle then onToggle(section) end
	end)

	section:SetCollapsed(false)
	return section
end


--[[ Settings controls ]]--

function W.Check(parent, label, get, set, tooltip)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check.Text:SetText(label)
	check.Text:SetFontObject(GameFontHighlight)
	check:SetScript("OnShow", function(self) self:SetChecked(get()) end)
	check:SetScript("OnClick", function(self)
		ns.PlayClick()
		set(self:GetChecked())
	end)
	if tooltip then
		check:SetScript("OnEnter", function(self) ns.ShowTooltip(self, label, tooltip) end)
		check:SetScript("OnLeave", GameTooltip_Hide)
	end
	check:SetChecked(get())
	return check
end

function W.Button(parent, label, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 140, 22)
	button:SetText(label)
	button:SetScript("OnClick", function(self)
		ns.PlayClick()
		onClick(self)
	end)
	return button
end

-- Multi-line message box with a label; saves when focus leaves or Enter is pressed.
function W.MessageBox(parent, label, width, get, set)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width, 44)
	local title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOPLEFT")
	title:SetText(label)
	local box = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
	box:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 6, -4)
	box:SetSize(width - 6, 22)
	box:SetAutoFocus(false)
	box:SetMaxLetters(255)
	local function Save(self)
		set(self:GetText())
		self:SetText(get())
		self:SetCursorPosition(0)
	end
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText(get())
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusLost", Save)
	holder:SetScript("OnShow", function()
		box:SetText(get())
		box:SetCursorPosition(0)
	end)
	holder.EditBox = box
	return holder
end

function W.Slider(parent, label, low, high, step, get, set, format)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(260, 40)
	local title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOPLEFT")
	local slider = CreateFrame("Slider", nil, holder, "MinimalSliderTemplate")
	slider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	slider:SetSize(200, 16)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	local function Label(value)
		title:SetText(label .. ": |cffffffff" .. (format or "%d"):format(value) .. "|r")
	end
	slider:SetScript("OnValueChanged", function(_, value)
		value = math.floor(value / step + 0.5) * step
		Label(value)
		set(value)
	end)
	holder:SetScript("OnShow", function()
		slider:SetValue(get())
		Label(get())
	end)
	slider:SetValue(get())
	Label(get())
	return holder
end

-- A button that cycles through choices: "Sort players: Newest first".
function W.Cycle(parent, label, choices, get, set, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 260, 22)
	local function Refresh()
		local current = get()
		for _, choice in ipairs(choices) do
			if choice[1] == current then
				button:SetText(("%s: |cffffffff%s|r"):format(label, choice[2]))
				return
			end
		end
		button:SetText(label)
	end
	button:SetScript("OnClick", function()
		ns.PlayClick()
		local current, index = get(), 1
		for i, choice in ipairs(choices) do
			if choice[1] == current then index = i end
		end
		set(choices[index % #choices + 1][1])
		Refresh()
	end)
	button:SetScript("OnShow", Refresh)
	Refresh()
	return button
end
