--[[
	ForeverGroups: data

	Everything that is not drawing: the finder's categories and activities, the
	filters model, starting a search, turning the results into the two sorted
	lists, guild/friend marks, talents and the whisper messages.

	Performance: each result is read once per build. Solo listings read their
	player info once and reuse it for every filter and for the sort key; group
	members are only read when the "hide groups with class" filter is on.
--]]

local _, ns = ...
local L

local Data = {}
ns.Data = Data

local Readable, canaccess = ns.Readable, ns.canaccess

ns:On("Loaded", function() L = ns.L end)


--[[ The finder UI (Blizzard_GroupFinder_VanillaStyle, load on demand) ]]--

local FINDER_ADDON = "Blizzard_GroupFinder_VanillaStyle"

function Data:IsFinderLoaded()
	return C_AddOns.IsAddOnLoaded(FINDER_ADDON)
end

-- The row and tooltip templates live in it. Loading a Blizzard addon is not
-- allowed in combat, so the caller retries later.
function Data:EnsureFinder()
	if self:IsFinderLoaded() then return true end
	if InCombatLockdown() then return false end
	if GroupFinderVanillaStyle_LoadUI then
		GroupFinderVanillaStyle_LoadUI()
	else
		pcall(C_AddOns.LoadAddOn, FINDER_ADDON)
	end
	return self:IsFinderLoaded()
end


--[[ Categories and activities ]]--

function Data:ActivityName(info)
	if not info then return "" end
	return LFGUtil_GetActivityInfoName and LFGUtil_GetActivityInfoName(info) or info.fullName or ""
end

-- Activities of a category, by default only those whose suggested level range
-- holds the player's level (activities of the player's own listing always stay).
function Data:Activities(categoryID, groupID)
	local activities = C_LFGList.GetAvailableActivities(categoryID, groupID) or {}
	if ns.db.showAllLevels then return activities end

	local entry = C_LFGList.GetActiveEntryInfo()
	local listed = entry and entry.activityIDs or {}
	local level = UnitLevel("player")
	local kept = {}
	for _, id in ipairs(activities) do
		local info = C_LFGList.GetActivityInfoTable(id)
		local low = info and info.minLevelSuggestion or 0
		local high = info and info.maxLevelSuggestion or 0
		if tContains(listed, id) or not ((low > 0 and low > level) or (high > 0 and high < level)) then
			kept[#kept + 1] = id
		end
	end
	return kept
end

function Data:Categories()
	local list = {}
	if not self:IsFinderLoaded() then return list end
	for _, id in ipairs(C_LFGList.GetAvailableCategories() or {}) do
		if #self:Activities(id) > 0 then
			local info = C_LFGList.GetLfgCategoryInfo(id)
			if info then
				list[#list + 1] = {id = id, name = info.name}
			end
		end
	end
	return list
end

-- "Deadmines (17 - 24)" when level ranges are on.
function Data:ActivityMenuText(info)
	local name = self:ActivityName(info)
	if not ns.db.showLevelRanges or not info then return name end
	local low, high = info.minLevelSuggestion or 0, info.maxLevelSuggestion or 0
	if low == high or high == 0 then
		return low > 0 and ("%s (%d)"):format(name, low) or name
	end
	return ("%s (%d - %d)"):format(name, low, high)
end

-- Highest content first inside each group, like Blizzard's own menu.
local function ActivityOrder(infos)
	return function(a, b)
		local x, y = infos[a], infos[b]
		if x.orderIndex ~= y.orderIndex then
			return x.orderIndex > y.orderIndex
		end
		local xh, yh = x.maxLevelSuggestion or 0, y.maxLevelSuggestion or 0
		if xh ~= yh then
			if xh == 0 or yh == 0 then return xh == 0 end
			return xh > yh
		end
		local xl, yl = x.minLevelSuggestion or 0, y.minLevelSuggestion or 0
		if xl ~= yl then return xl > yl end
		return Data:ActivityName(x) < Data:ActivityName(y)
	end
end

-- groupID -> sorted activity IDs, activity infos, and the sorted group IDs.
function Data:OrganizeActivities(activities)
	local organized, infos = {}, {}
	for _, id in ipairs(activities) do
		local info = C_LFGList.GetActivityInfoTable(id)
		if info then
			infos[id] = info
			local group = info.groupFinderActivityGroupID or 0
			organized[group] = organized[group] or {}
			table.insert(organized[group], id)
		end
	end
	local order = ActivityOrder(infos)
	local groups = {}
	for group, ids in pairs(organized) do
		table.sort(ids, order)
		groups[#groups + 1] = group
	end
	if LFGUtil_SortActivityGroupIDs then
		LFGUtil_SortActivityGroupIDs(groups)
	else
		table.sort(groups)
	end
	return organized, infos, groups
end

-- Names of activities, grouped and sorted, for the %dungeon% placeholder.
function Data:ActivityNames(activityIDs)
	if type(activityIDs) ~= "table" or #activityIDs == 0 then return nil end
	local organized, infos, groups = self:OrganizeActivities(activityIDs)
	local names = {}
	for _, group in ipairs(groups) do
		for _, id in ipairs(organized[group]) do
			local name = self:ActivityName(infos[id])
			if name ~= "" then
				names[#names + 1] = name
			end
		end
	end
	return #names > 0 and names or nil
end


--[[ Languages and playstyles ]]--

-- Languages the server offers, and those always searched (the game's own).
function Data:Languages()
	local offered, locked, seen = {}, {}, {}
	for _, code in ipairs(C_LFGList.GetAvailableLanguageSearchFilter() or {}) do
		if type(code) == "string" and not seen[code] then
			seen[code] = true
			offered[#offered + 1] = code
		end
	end
	local defaults = C_LFGList.GetDefaultLanguageSearchFilter() or {}
	for _, code in ipairs(offered) do
		if defaults[code] then
			locked[code] = true
		end
	end
	return offered, locked
end

function Data:LanguageName(code)
	return _G["LFG_LIST_LANGUAGE_" .. code:upper()] or code
end

-- nil (the game's default) unless the player ticked a language beyond the locked ones.
function Data:LanguageFilter(selected)
	local offered, locked = self:Languages()
	local filter, extra = {}, false
	for _, code in ipairs(offered) do
		if locked[code] then
			filter[code] = true
		elseif type(selected) == "table" and selected[code] then
			filter[code] = true
			extra = true
		end
	end
	return extra and filter or nil
end

local Playstyle = Enum.LFGEntryGeneralPlaystyle or {}
Data.playstyles = {
	{key = "Learning", value = Playstyle.Learning},
	{key = "FunRelaxed", value = Playstyle.FunRelaxed},
	{key = "FunSerious", value = Playstyle.FunSerious},
	{key = "Expert", value = Playstyle.Expert},
}

function Data:PlaystyleName(value)
	return value and GetGeneralPlaystyleString and GetGeneralPlaystyleString(value) or ""
end


--[[
	Filters model

	{
		group = {tankAvailable, healerAvailable, damageAvailable, hasTank, hasHealer},
		hideClasses = {CLASS = true}, -- groups with any of these are hidden
		roles = {tank, healer, dps}, -- solo players offering any ticked role
		classes = {CLASS = true}, -- solo players of these classes
		levelMin, levelMax, -- 0: no limit
		playstyles = {key = true}, -- none or all ticked: no filter
		languages = {code = true},
	}
	The text box narrows the list too, but is never saved.
--]]

function Data:DefaultFilters()
	local filters = {
		group = {},
		hideClasses = {},
		roles = {tank = true, healer = true, dps = true},
		classes = {},
		levelMin = 0,
		levelMax = 0,
		playstyles = {},
		languages = {},
	}
	for _, class in ipairs(ns.classes) do
		filters.classes[class] = true
	end
	return filters
end

-- Saved filters are a file anyone can edit: keep only known keys and types.
function Data:CleanFilters(saved)
	local filters = self:DefaultFilters()
	if type(saved) ~= "table" then return filters end
	for _, set in ipairs({"group", "hideClasses", "roles", "classes", "playstyles", "languages"}) do
		if type(saved[set]) == "table" then
			local clean = {}
			for key, value in pairs(saved[set]) do
				if type(key) == "string" and value == true then
					clean[key] = true
				end
			end
			if set == "roles" or set == "classes" then
				-- missing keys are unticked boxes
				for key in pairs(filters[set]) do
					filters[set][key] = clean[key] == true
				end
			else
				filters[set] = clean
			end
		end
	end
	for _, key in ipairs({"levelMin", "levelMax"}) do
		local value = tonumber(saved[key])
		if value and value >= 0 and value <= 999 then
			filters[key] = math.floor(value)
		end
	end
	return filters
end

function Data:SavedFilters()
	return self:CleanFilters(ns.db.filters)
end


--[[ My filters ]]--

Data.MY_FILTERS_MAX = 10
Data.MY_FILTER_NAME_MAX = 24

function Data:MyFilterProblem(name)
	name = strtrim(name or "")
	if name == "" then return L.MY_FILTER_EMPTY end
	if #ns.db.myFilters >= self.MY_FILTERS_MAX then return L.MY_FILTERS_FULL end
	for _, entry in ipairs(ns.db.myFilters) do
		if entry.name:lower() == name:lower() then
			return L.MY_FILTER_EXISTS
		end
	end
end

function Data:SaveMyFilter(name, filters)
	name = strtrim(name):sub(1, self.MY_FILTER_NAME_MAX)
	table.insert(ns.db.myFilters, {name = name, filters = CopyTable(filters)})
end

function Data:DeleteMyFilter(name)
	for index, entry in ipairs(ns.db.myFilters) do
		if entry.name == name then
			table.remove(ns.db.myFilters, index)
			return
		end
	end
end


--[[ Searching ]]--

local SEARCH_TIMEOUT = 15

Data.searching = false
Data.searchFailed = false
local timer

local function EndSearch(failed)
	if timer then
		timer:Cancel()
		timer = nil
	end
	Data.searching = false
	Data.searchFailed = failed
	ns:Fire("SearchFinished", failed)
end

-- Must run from a click: C_LFGList.Search is a restricted function.
function Data:Search(categoryID, activityIDs, filters)
	if self.searching or not categoryID or categoryID <= 0 then return end
	if not activityIDs or #activityIDs == 0 then
		activityIDs = self:Activities(categoryID) -- nothing ticked means every activity
	end

	C_LFGList.Search(categoryID, 0, 0, self:LanguageFilter(filters.languages), false, nil, activityIDs)

	ns.db.filters = CopyTable(filters)
	ns.db.category = categoryID
	self.filters = filters
	self.searching = true
	self.searchFailed = false
	timer = C_Timer.NewTimer(SEARCH_TIMEOUT, function()
		timer = nil
		if Data.searching then EndSearch(true) end
	end)
	ns:Fire("SearchStarted")
end

ns:On("Login", function()
	Data.filters = Data:SavedFilters()
	ns:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", function() EndSearch(false) end)
	ns:RegisterEvent("LFG_LIST_SEARCH_FAILED", function() EndSearch(true) end)
	ns:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED", function(_, resultID)
		ns:Fire("ResultUpdated", resultID)
	end)
	ns:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE", function() ns:Fire("Availability") end)
	-- a listing reported from the right-click menu leaves the filtered results
	ns:RegisterEvent("REPORT_PLAYER_RESULT", function(_, result, reportType)
		if Enum.SendReportResult and result == Enum.SendReportResult.Success
			and Enum.ReportType and reportType == Enum.ReportType.GroupFinderPosting then
			ns:Fire("ResultsChanged")
		end
	end)
end)


--[[ Guild and friends ]]--

Data.RELATION_GUILD, Data.RELATION_FRIEND = "guild", "friend"

local function InThisGame(account)
	return account and account.clientProgram == BNET_CLIENT_WOW and account.wowProjectID == WOW_PROJECT_ID
end

-- One lookup per list build: the Battle.net names are read once, not per row.
function Data:NewRelationLookup()
	local guild = ns.db.markGuild and IsInGuild()
	local legacy = ns.db.markFriends and C_FriendList.IsLegacyFriendSystemEnabled
		and C_FriendList.IsLegacyFriendSystemEnabled()
	local bnet = {}
	if ns.db.markFriends and BNGetNumFriends then
		for friend = 1, BNGetNumFriends() or 0 do
			for index = 1, C_BattleNet.GetFriendNumGameAccounts(friend) or 0 do
				local account = C_BattleNet.GetFriendGameAccountInfo(friend, index)
				if InThisGame(account) and account.characterName then
					bnet[account.characterName] = true
				end
			end
		end
	end
	return function(name)
		if name == nil or not canaccess(name) then return nil end
		if guild and C_GuildInfo.MemberExistsByName(name) then return Data.RELATION_GUILD end
		if legacy and C_FriendList.GetFriendInfo(name) then return Data.RELATION_FRIEND end
		if bnet[name] or bnet[Ambiguate(name, "short")] then return Data.RELATION_FRIEND end
	end
end

function Data:RelationByGUID(guid)
	if guid == nil or not canaccess(guid) then return nil end
	if ns.db.markGuild and IsInGuild() and IsGuildMember and IsGuildMember(guid) then
		return self.RELATION_GUILD
	end
	if ns.db.markFriends then
		if C_FriendList.IsFriend and C_FriendList.IsFriend(guid) then
			return self.RELATION_FRIEND
		end
		if C_BattleNet and InThisGame(C_BattleNet.GetGameAccountInfoByGUID(guid)) then
			return self.RELATION_FRIEND
		end
	end
end

function Data:RequestGuildRoster()
	if ns.db.markGuild and IsInGuild() then
		C_GuildInfo.GuildRoster()
	end
end


--[[ Building the lists ]]--

local GROUP_RULES = {
	{key = "tankAvailable", role = "TANK", enough = 1, covered = false},
	{key = "healerAvailable", role = "HEALER", enough = 1, covered = false},
	{key = "damageAvailable", role = "DAMAGER", enough = 3, covered = false},
	{key = "hasTank", role = "TANK", enough = 1, covered = true},
	{key = "hasHealer", role = "HEALER", enough = 1, covered = true},
}

-- Every ticked rule must hold; an unreadable count never hides a group.
local function GroupMatches(resultID, rules)
	local counts
	for _, rule in ipairs(GROUP_RULES) do
		if rules[rule.key] then
			counts = counts or Readable(C_LFGList.GetSearchResultMemberCounts(resultID), false)
			if not counts then return true end
			local have = Readable(counts[rule.role], nil)
			if have ~= nil and (have >= rule.enough) ~= rule.covered then
				return false
			end
		end
	end
	return true
end

local function GroupHasHiddenClass(resultID, members, hidden)
	for index = 1, members do
		local member = C_LFGList.GetSearchResultPlayerInfo(resultID, index)
		local class = member and Readable(member.classFilename, nil)
		if class and hidden[class] then return true end
	end
	return false
end

local function AnyTicked(set, all)
	local ticked, total = 0, 0
	for _, value in pairs(set) do
		total = total + 1
		if value then ticked = ticked + 1 end
	end
	return ticked > 0 and ticked < (all or total)
end

local function SoloMatches(member, filters)
	if not member then return true end
	local roles = filters.roles
	if not (roles.tank and roles.healer and roles.dps) and (roles.tank or roles.healer or roles.dps) then
		local offered = Readable(member.lfgRoles, nil)
		if offered and not ((roles.tank and Readable(offered.tank, false) == true)
			or (roles.healer and Readable(offered.healer, false) == true)
			or (roles.dps and Readable(offered.dps, false) == true)) then
			return false
		end
	end
	if filters.classFilter then
		local class = Readable(member.classFilename, nil)
		if class and not filters.classes[class] then return false end
	end
	local low, high = filters.levelMin or 0, filters.levelMax or 0
	if low > 0 or high > 0 then
		local level = Readable(member.level, nil)
		if level and ((low > 0 and level < low) or (high > 0 and level > high)) then
			return false
		end
	end
	return true
end

local function PlaystyleMatches(info, filters)
	if not filters.playstyleFilter then return true end
	local value = Readable(info.generalPlaystyle, nil)
	if value == nil or Data:PlaystyleName(value) == "" then return true end -- no playstyle: always shown
	for _, style in ipairs(Data.playstyles) do
		if style.value == value then
			return filters.playstyles[style.key] == true
		end
	end
	return false
end

-- Text search: leader, comment, activity and zone, readable parts only.
local activityNames = {}

local function ActivityText(activityIDs)
	local parts = {}
	for _, id in ipairs(activityIDs) do
		local name = activityNames[id]
		if not name then
			name = Data:ActivityName(C_LFGList.GetActivityInfoTable(id)):lower()
			activityNames[id] = name
		end
		parts[#parts + 1] = name
	end
	return table.concat(parts, " ")
end

local function TextMatches(query, info, member)
	if not query then return true end
	local function Has(value)
		value = Readable(value, nil)
		return type(value) == "string" and value:lower():find(query, 1, true) ~= nil
	end
	if Has(info.leaderName) or Has(info.comment) or Has(info.name) then return true end
	if member and Has(member.areaName) then return true end
	local ids = Readable(info.activityIDs, nil)
	return ids and ActivityText(ids):find(query, 1, true) ~= nil or false
end

local function Newest(a, b)
	if (a.age == nil) ~= (b.age == nil) then return a.age ~= nil end
	if a.age ~= b.age then return a.age < b.age end
	return a.index < b.index
end

local classRank = {}
for index, class in ipairs(ns.classes) do classRank[class] = index end

local PLAYER_ORDERS = {
	newest = Newest,
	oldest = function(a, b)
		if (a.age == nil) ~= (b.age == nil) then return a.age ~= nil end
		if a.age ~= b.age then return a.age > b.age end
		return a.index < b.index
	end,
	levelHigh = function(a, b)
		if (a.level or -1) ~= (b.level or -1) then return (a.level or -1) > (b.level or -1) end
		return Newest(a, b)
	end,
	levelLow = function(a, b)
		if (a.level or 1000) ~= (b.level or 1000) then return (a.level or 1000) < (b.level or 1000) end
		return Newest(a, b)
	end,
	class = function(a, b)
		if (a.classRank or 99) ~= (b.classRank or 99) then return (a.classRank or 99) < (b.classRank or 99) end
		return Newest(a, b)
	end,
}
Data.playerOrders = {"newest", "oldest", "levelHigh", "levelLow", "class"}

--[[
	Builds {groups = nodes, solos = nodes, unknown = nodes}: inside each list the
	player's own listing first, then guild/friends, then everyone else.
	Node: {resultID, relation, age, index, level, classRank}.
--]]
function Data:Build(filters, query)
	filters = filters or self.filters or self:DefaultFilters()
	filters.classFilter = AnyTicked(filters.classes, #ns.classes)
	filters.playstyleFilter = AnyTicked(filters.playstyles, #Data.playstyles)
	local hidden = AnyTicked(filters.hideClasses, #ns.classes) and filters.hideClasses or nil
	query = query and strtrim(query):lower()
	if query == "" then query = nil end

	local lookup = self:NewRelationLookup()
	local order = PLAYER_ORDERS[ns.db.playerSort] or Newest
	local groups = {mine = {}, known = {}, rest = {}}
	local solos = {mine = {}, known = {}, rest = {}}
	local unknown = {}

	local _, results = C_LFGList.GetFilteredSearchResults()
	for index, resultID in ipairs(results or {}) do
		local info = C_LFGList.GetSearchResultInfo(resultID)
		if info then
			local node = {resultID = resultID, age = Readable(info.age, nil), index = index}
			local members = Readable(info.numMembers, nil)
			local mine = Readable(info.hasSelf, false) == true
			local bucket
			if members == nil then
				unknown[#unknown + 1] = node
			elseif members <= 1 then
				local member = C_LFGList.GetSearchResultPlayerInfo(resultID, 1)
				if mine or (SoloMatches(member, filters) and PlaystyleMatches(info, filters)
					and TextMatches(query, info, member)) then
					bucket = solos
					if member then
						node.level = Readable(member.level, nil)
						local class = Readable(member.classFilename, nil)
						node.classRank = class and classRank[class]
					end
				end
			elseif mine or (GroupMatches(resultID, filters.group) and PlaystyleMatches(info, filters)
				and not (hidden and GroupHasHiddenClass(resultID, members, hidden))
				and TextMatches(query, info, nil)) then
				bucket = groups
			end
			if bucket then
				if mine then
					table.insert(bucket.mine, node)
				else
					node.relation = lookup(info.leaderName)
					table.insert(node.relation and bucket.known or bucket.rest, node)
				end
			end
		end
	end

	local function Flatten(bucket, sorter)
		local list = {}
		for _, part in ipairs({bucket.mine, bucket.known, bucket.rest}) do
			table.sort(part, sorter)
			for _, node in ipairs(part) do list[#list + 1] = node end
		end
		return list
	end
	table.sort(unknown, Newest)
	return {groups = Flatten(groups, Newest), solos = Flatten(solos, order), unknown = unknown}
end


--[[ Talents (classic trees read through the traits API) ]]--

-- {name, spent} per tree in display order, or nil.
function Data:ReadTalents()
	if not (C_SpecializationInfo and C_Traits) then return nil end
	local group = C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetActiveSpecGroup()
	local configID = group and C_SpecializationInfo.GetCombatConfigIDForSpecGroup(group)
	local config = configID and C_Traits.GetConfigInfo(configID)
	local treeID = config and config.treeIDs and config.treeIDs[1]
	local displays = treeID and C_Traits.GetGroupDisplayInfoByTreeID(treeID)
	if not displays or #displays == 0 then return nil end

	local ids = {}
	for _, display in ipairs(displays) do ids[#ids + 1] = display.groupID end
	local spent = {}
	for _, info in ipairs(C_Traits.GetGroupCurrencyInfo(configID, ids) or {}) do
		local currency = info.currencyInfos and info.currencyInfos[1]
		if currency then spent[info.traitNodeGroupID] = currency.spent end
	end
	local trees = {}
	for _, display in ipairs(displays) do
		trees[#trees + 1] = {name = display.displayName, order = display.orderIndex or 0, spent = spent[display.groupID] or 0}
	end
	table.sort(trees, function(a, b) return a.order < b.order end)
	return trees
end

-- "proteção" (the tree with most points, in the message language) and "11/5/35".
function Data:TalentWords(language)
	local ok, trees = pcall(self.ReadTalents, self)
	if not ok or not trees then return "", "" end
	local best, bestIndex, points = nil, nil, {}
	for index, tree in ipairs(trees) do
		points[#points + 1] = tree.spent
		if tree.spent > 0 and (not best or tree.spent > best.spent) then
			best, bestIndex = tree, index
		end
	end
	if not best then return "", table.concat(points, "/") end
	local _, class = UnitClass("player")
	local name = ns.Messages:TreeName(language, class, bestIndex, best.name and best.name:lower())
	return name, table.concat(points, "/")
end


--[[ Whisper messages ]]--

local function JoinWords(words, language)
	if #words <= 1 then return words[1] or "" end
	local word = ns.Messages:Get(language).word_or
	return table.concat(words, ", ", 1, #words - 1) .. " " .. word .. " " .. words[#words]
end

local function RoleWords(language)
	local roles = C_LFGListRoles and C_LFGListRoles.GetRoles and C_LFGListRoles.GetRoles()
	if not roles then return "" end
	local words, info = {}, ns.Messages:Get(language)
	if roles.tank then words[#words + 1] = info.tank end
	if roles.healer then words[#words + 1] = info.healer end
	if roles.dps then words[#words + 1] = info.damage end
	return JoinWords(words, language)
end

-- Fills %placeholders%; an empty one leaves no "()" or double space behind.
local function Fill(template, values)
	local text = template:gsub("%%(%a+)%%", function(key)
		local value = values[key]
		if value == nil then return nil end -- unknown placeholders stay as typed
		return tostring(value)
	end)
	text = text:gsub("%(%s*%)", ""):gsub("  +", " "):gsub(" ([,%.!%?])", "%1")
	return strtrim(text)
end

-- Language the messages go out in (chosen at the bottom of the window).
function Data:MessageLanguage()
	local code = ns.char.messageLanguage
	return ns.Messages.languages[code] and code or ns.Messages.client
end

function Data:SetMessageLanguage(code)
	ns.char.messageLanguage = code
	ns:Fire("MessageLanguageChanged")
end

-- The message the player wrote for a language, or its default.
-- kind: "ask" or "invite".
function Data:Message(kind, language)
	language = language or self:MessageLanguage()
	local own = ns.char.messages[language]
	return own and own[kind] or ns.Messages:Get(language)[kind]
end

-- Saves a message; empty or equal to the default goes back to the default.
function Data:SetMessage(kind, language, text)
	text = strtrim(text or "")
	local messages = ns.char.messages
	local own = messages[language] or {}
	own[kind] = (text ~= "" and text ~= ns.Messages:Get(language)[kind]) and text or nil
	messages[language] = next(own) and own or nil
end

function Data:AskMessage(language)
	return self:Message("ask", language)
end

function Data:InviteMessage(language)
	return self:Message("invite", language)
end

-- Messages saved before there were languages belong to the game's language.
ns:On("Loaded", function()
	local char = ns.char
	if char.askMessage or char.inviteMessage then
		local own = char.messages[ns.Messages.client] or {}
		own.ask = own.ask or char.askMessage
		own.invite = own.invite or char.inviteMessage
		char.messages[ns.Messages.client] = own
		char.askMessage, char.inviteMessage = nil, nil
	end
end)

-- The "ask to join" whisper, or nil when it is off or empty.
function Data:BuildAskMessage(target)
	if not ns.db.askWhisper then return nil end
	local language = self:MessageLanguage()
	local template = self:AskMessage(language)
	if not template:find("%S") then return nil end
	local _, class = UnitClass("player")
	local talents, points = self:TalentWords(language)
	return Fill(template, {
		class = ns.Messages:ClassName(language, class):lower(),
		level = UnitLevel("player"),
		talents = talents,
		points = points,
		role = RoleWords(language),
		name = target and Readable(target, nil) and Ambiguate(target, "short") or "",
	})
end

-- Activities for %dungeon%: the player's own listing, else what is ticked in the filters.
Data.selectedActivities = function() return nil end

local function LeadsOrSolo()
	local inGroup = IsInGroup()
	if not canaccess(inGroup) then return false end
	if not inGroup then return true end
	local leader = UnitIsGroupLeader("player")
	return canaccess(leader) and leader == true
end

-- The whisper that goes with an invite, or nil.
function Data:BuildInviteMessage(target)
	if not ns.db.inviteWhisper or not LeadsOrSolo() then return nil end
	local language = self:MessageLanguage()
	local template = self:InviteMessage(language)
	if not template:find("%S") then return nil end
	local entry = C_LFGList.GetActiveEntryInfo()
	local names = entry and self:ActivityNames(entry.activityIDs) or self:ActivityNames(self.selectedActivities())
	-- without an activity the message would read "join ?"
	if template:find("%%dungeon%%") and not names then return nil end
	return Fill(template, {
		dungeon = names and JoinWords(names, language) or "",
		name = target and Readable(target, nil) and Ambiguate(target, "short") or "",
	})
end
