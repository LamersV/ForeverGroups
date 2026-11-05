--[[
	ForeverGroups: the window

	A plain frame (not a Blizzard "UI panel"), so it can be moved, opened in
	combat and never closes other windows. Escape closes it. Results on the
	left, filters on the right; side tabs jump to Blizzard's own finder tabs
	(create a listing, browse, who list). Built on first open.
--]]

local _, ns = ...
local L

local WIDTH, HEIGHT = 1000, 600
local INSET_LEFT, INSET_TOP, INSET_RIGHT, INSET_BOTTOM = 4, -60, -6, 26

local window

local BLIZZARD_TABS = {
	{tab = 1, icon = "Interface\\ICONS\\INV_SideTab_GroupFinder_c60", key = "TAB_CREATE"},
	{tab = 2, icon = "Interface\\ICONS\\INV_SideTab_GroupBrowsing_c60", key = "TAB_BROWSE"},
	{tab = 3, icon = "Interface\\ICONS\\INV_SideTab_WhoList_c60", key = "TAB_WHO"},
}

function ns:OpenBlizzardTab(tab)
	if InCombatLockdown() then
		return ns:Print(L.COMBAT_BLIZZARD)
	end
	if not LFGVanilla_ToggleFrame and GroupFinderVanillaStyle_LoadUI then
		GroupFinderVanillaStyle_LoadUI()
	end
	if LFGVanilla_ToggleFrame then
		LFGVanilla_ToggleFrame(tab)
	end
end


--[[ Position and size (centre offset from the screen centre) ]]--

local function SaveGeometry(frame)
	local saved = ns.db.window
	local scale = frame:GetScale() / UIParent:GetScale()
	local x, y = frame:GetCenter()
	local cx, cy = UIParent:GetCenter()
	if x and cx then
		saved.x, saved.y = x * scale - cx, y * scale - cy
	end
	saved.width, saved.height = frame:GetSize()
end

local function Place(frame)
	local saved = ns.db.window
	frame:SetSize(math.max(saved.width or WIDTH, WIDTH), math.max(saved.height or HEIGHT, HEIGHT))
	FrameUtil.UpdateScaleForFit(frame, 20, 20)
	frame:ClearAllPoints()
	if saved.x and saved.y then
		local scale = frame:GetScale() / UIParent:GetScale()
		frame:SetPoint("CENTER", UIParent, "CENTER", saved.x / scale, saved.y / scale)
	else
		frame:SetPoint("TOP", UIParent, "TOP", 0, -116)
	end
end

function ns:ResetWindow()
	wipe(ns.db.window)
	if window then Place(window) end
	ns:Print(L.WINDOW_RESET)
end


--[[ Build ]]--

local function SideTabs(frame)
	local previous
	local function Add()
		local tab = CreateFrame("Frame", nil, frame, "LargeSideTabButtonTemplate")
		tab.Icon:SetSize(30, 30)
		tab:SetFillToInterior(true)
		if previous then
			tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
		else
			tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -60)
		end
		previous = tab
		return tab
	end
	for _, info in ipairs(BLIZZARD_TABS) do
		local tab = Add()
		tab.Icon:SetTexture(info.icon)
		tab.Icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
		tab.tooltipText = L[info.key]
		tab:SetChecked(false)
		tab:SetCustomOnMouseUpHandler(function(_, button, inside)
			if button == "LeftButton" and inside then ns:OpenBlizzardTab(info.tab) end
		end)
	end
	local own = Add()
	own.Icon:SetAtlas(ns.icon)
	own.tooltipText = ns.name
	own:SetChecked(true)
end

local function Build()
	L = ns.L
	local frame = CreateFrame("Frame", "ForeverGroupsFrame", UIParent)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetResizeBounds(WIDTH, HEIGHT)
	frame:SetClampedToScreen(true)
	frame:Hide()

	local content = CreateFrame("Frame", nil, frame, "PortraitFrameTemplateNoCloseButton")
	content:SetAllPoints()
	content:SetTitle(ns.name)
	content:SetPortraitAtlasRaw(ns.icon)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT")
	close:SetScript("OnClick", function() frame:Hide() end)

	local drag = CreateFrame("Button", nil, content, "PanelDragBarTemplate")
	drag:SetAllPoints(content.TitleContainer)
	drag:Init(frame)
	drag:HookScript("OnDragStop", function() SaveGeometry(frame) end)

	local grip = CreateFrame("Button", nil, content, "PanelResizeButtonTemplate")
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:Init(frame, WIDTH, HEIGHT)
	grip:SetOnResizeStoppedCallback(function() SaveGeometry(frame) end)

	local filters = ns.Filters:Create(content)
	filters:SetPoint("TOPRIGHT", INSET_RIGHT, INSET_TOP)
	filters:SetPoint("BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)

	local list = ns.List:Create(content)
	list:SetPoint("TOPLEFT", INSET_LEFT, INSET_TOP)
	list:SetPoint("BOTTOMRIGHT", filters, "BOTTOMLEFT", -9, 0)

	local footer = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	footer:SetPoint("BOTTOMLEFT", 14, 8)
	list.Footer = footer

	local hint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMRIGHT", -28, 8)
	hint:SetText(L.LIST_HINT)

	SideTabs(frame)

	frame:SetScript("OnShow", function()
		Place(frame)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
		ns.Data:RequestGuildRoster()
		if not ns.Data:EnsureFinder() then ns:Print(L.FINDER_COMBAT) end
	end)
	frame:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
	end)
	tinsert(UISpecialFrames, "ForeverGroupsFrame")
	return frame
end

function ns:ToggleWindow()
	if not ns.db then return end
	window = window or Build()
	window:SetShown(not window:IsShown())
end

function ns:OpenWindow()
	if not ns.db then return end
	window = window or Build()
	window:Show()
end

function ns:IsWindowShown()
	return window and window:IsShown()
end
