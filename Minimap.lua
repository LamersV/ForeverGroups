--[[
	ForeverGroups: minimap button
	Left click: window. Right click: settings. Drag: move it around the minimap.
	Shows the number of unread whispers in the log.
--]]

local _, ns = ...

local button

-- Around the edge. On a square minimap (ForeverMap) inside the square, along
-- its border and into its corners.
local function Position()
	local angle = math.rad(ns.db.minimap.angle or 225)
	local x, y = math.cos(angle), math.sin(angle)
	local halfWidth, halfHeight = Minimap:GetWidth() / 2 + 5, Minimap:GetHeight() / 2 + 5
	if GetMinimapShape and GetMinimapShape() == "SQUARE" then
		x = math.max(-1, math.min(1, x * 1.414))
		y = math.max(-1, math.min(1, y * 1.414))
		halfWidth, halfHeight = Minimap:GetWidth() / 2 - 18, Minimap:GetHeight() / 2 - 18
	end
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x * halfWidth, y * halfHeight)
end

local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local x, y = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	ns.db.minimap.angle = math.deg(math.atan2(y / scale - my, x / scale - mx)) % 360
	Position()
end

local function UpdateCount()
	if not button then return end
	local unread = ns.db.unreadCounter and ns.Whispers.unread or 0
	button.Count:SetText(unread > 0 and unread or "")
end

local function Create()
	button = CreateFrame("Button", "ForeverGroupsMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetAtlas(ns.icon)
	icon:SetPoint("TOPLEFT", 6, -6)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")
	local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	count:SetPoint("BOTTOMRIGHT", -4, 4)
	count:SetTextColor(1, 0.82, 0)
	button.Count = count

	button:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			ns:OpenSettings()
		else
			ns:ToggleWindow()
		end
	end)
	button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self)
		local text = ns.L.MINIMAP_HINT
		if ns.Whispers.unread > 0 then
			text = text .. "\n" .. ns.L.UNREAD_WHISPERS:format(ns.Whispers.unread)
		end
		ns.ShowTooltip(self, ns.title, text, "ANCHOR_LEFT")
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	Position()
	-- again once every addon has logged in: ForeverMap may make the minimap square
	C_Timer.After(0, Position)
	UpdateCount()
end

ns.UpdateMinimapCount = UpdateCount

function ns:SetMinimapShown(shown)
	ns.db.minimap.hide = not shown
	if shown and not button then Create() end
	if button then button:SetShown(shown) end
end

ns:On("Login", function()
	if not ns.db.minimap.hide then Create() end
	ns:On("WhisperReceived", UpdateCount)
	ns:On("WhispersRead", UpdateCount)
	ns:On("WhispersChanged", UpdateCount)
end)
