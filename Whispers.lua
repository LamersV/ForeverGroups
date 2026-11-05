--[[
	ForeverGroups: whisper log (data)

	Whispers received this session, newest last, kept from login (the window
	does not need to have been opened). Memory only: nothing is saved.

	CHAT_MSG_WHISPER's text, sender and GUID can be secret in dungeons and raids.
	They are stored as they come and only ever shown with SetText; the plain
	name used for actions (invite, /who) is kept only when it is readable.
--]]

local _, ns = ...

local Whispers = {entries = {}, unread = 0}
ns.Whispers = Whispers

local Readable, canaccess = ns.Readable, ns.canaccess

function Whispers:Trim()
	local excess = #self.entries - (ns.db.whisperLogSize or 200)
	if excess > 0 then
		for _ = 1, excess do
			table.remove(self.entries, 1)
		end
		ns:Fire("WhispersChanged")
	end
end

function Whispers:Clear()
	wipe(self.entries)
	self.unread = 0
	ns:Fire("WhispersChanged")
end

function Whispers:Remove(entry)
	tDeleteItem(self.entries, entry)
	ns:Fire("WhispersChanged")
end

function Whispers:MarkRead()
	if self.unread > 0 then
		self.unread = 0
		ns:Fire("WhispersRead")
	end
end

local function OnWhisper(_, text, sender, _, _, _, _, _, _, _, _, lineID, guid)
	local class, level
	if guid and canaccess(guid) then
		-- the 8th value (level) exists in this client, not in every one
		local _, classFile, _, _, _, _, _, playerLevel = GetPlayerInfoByGUID(guid)
		class, level = Readable(classFile, nil), Readable(playerLevel, nil)
	end
	table.insert(Whispers.entries, {
		text = text,
		name = sender,
		actionName = Readable(sender, nil),
		guid = guid,
		lineID = lineID,
		class = class,
		level = level,
		time = time(),
	})
	Whispers.unread = Whispers.unread + 1
	Whispers:Trim()
	ns:Fire("WhisperReceived")
end

ns:On("Login", function()
	ns:RegisterEvent("CHAT_MSG_WHISPER", OnWhisper)
end)
