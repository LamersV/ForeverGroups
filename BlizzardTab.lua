--[[
	ForeverGroups: a side tab on Blizzard's Group Finder that opens our window
	(below Blizzard's "Who List" tab). The finder loads on demand, so the tab is
	added when it does.
--]]

local _, ns = ...

local tab

local function Build()
	local parent = LFGParentFrame
	if tab or not parent or not parent.WhoListingTab then return end
	tab = CreateFrame("Frame", "ForeverGroupsBlizzardTab", parent, "LargeSideTabButtonTemplate")
	tab.Icon:SetAtlas(ns.icon)
	tab.Icon:SetSize(30, 30)
	tab:SetFillToInterior(true)
	-- below LFG Forever's tab while both addons are enabled
	tab:SetPoint("TOPLEFT", _G.LFGForeverBlizzardTab or parent.WhoListingTab, "BOTTOMLEFT", 0, -2)
	tab:SetChecked(false)
	tab.tooltipText = ns.name
	tab:SetCustomOnMouseUpHandler(function(_, button, inside)
		if button ~= "LeftButton" or not inside then return end
		ns:OpenWindow()
		-- Blizzard's panel manager refuses addon code in combat
		if not InCombatLockdown() then HideUIPanel(LFGParentFrame) end
	end)
end

-- one frame later, so another addon's tab built on the same load already exists
EventUtil.ContinueOnAddOnLoaded("Blizzard_GroupFinder_VanillaStyle", function()
	C_Timer.After(0, Build)
end)
