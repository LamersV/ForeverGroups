--[[
	ForeverGroups: languages of the whisper messages.
	Each language has its default "ask to join" and "invite" messages and the words
	that fill them (class, roles, talent tree), so a message can go out in a language
	other than the game's. Activity names (%dungeon%) come from the game, so they stay
	in the game's language.
--]]

local _, ns = ...

local Messages = {}
ns.Messages = Messages

-- Order in the menus.
Messages.order = {"ptBR", "enUS", "esES"}

-- Class names (male, female) and talent trees in the order the game shows them.
Messages.languages = {
	ptBR = {
		name = "Português",
		ask = "Oi! Sou %class% (%talents%), nível %level%. Pode me convidar?",
		invite = "Oi! Quer entrar no grupo para %dungeon%?",
		tank = "tanque", healer = "cura", damage = "dano", word_or = "ou",
		classes = {
			WARRIOR = {"guerreiro", "guerreira"}, PALADIN = {"paladino", "paladina"},
			HUNTER = {"caçador", "caçadora"}, ROGUE = {"ladino", "ladina"},
			PRIEST = {"sacerdote", "sacerdotisa"}, SHAMAN = {"xamã", "xamã"},
			MAGE = {"mago", "maga"}, WARLOCK = {"bruxo", "bruxa"}, DRUID = {"druida", "druida"},
		},
		trees = {
			WARRIOR = {"armas", "fúria", "proteção"},
			PALADIN = {"sagrado", "proteção", "retribuição"},
			HUNTER = {"domínio das feras", "precisão", "sobrevivência"},
			ROGUE = {"assassinato", "combate", "subterfúgio"},
			PRIEST = {"disciplina", "sagrado", "sombra"},
			SHAMAN = {"elemental", "aperfeiçoamento", "restauração"},
			MAGE = {"arcano", "fogo", "gelo"},
			WARLOCK = {"suplício", "demonologia", "destruição"},
			DRUID = {"equilíbrio", "combate feral", "restauração"},
		},
	},
	enUS = {
		name = "English",
		ask = "Hi! I am a %talents% %class%, level %level%. Inv please?",
		invite = "Hey! Want to join %dungeon%?",
		tank = "tank", healer = "healer", damage = "dps", word_or = "or",
		classes = {
			WARRIOR = {"warrior"}, PALADIN = {"paladin"}, HUNTER = {"hunter"}, ROGUE = {"rogue"},
			PRIEST = {"priest"}, SHAMAN = {"shaman"}, MAGE = {"mage"}, WARLOCK = {"warlock"},
			DRUID = {"druid"},
		},
		trees = {
			WARRIOR = {"arms", "fury", "protection"},
			PALADIN = {"holy", "protection", "retribution"},
			HUNTER = {"beast mastery", "marksmanship", "survival"},
			ROGUE = {"assassination", "combat", "subtlety"},
			PRIEST = {"discipline", "holy", "shadow"},
			SHAMAN = {"elemental", "enhancement", "restoration"},
			MAGE = {"arcane", "fire", "frost"},
			WARLOCK = {"affliction", "demonology", "destruction"},
			DRUID = {"balance", "feral combat", "restoration"},
		},
	},
	esES = {
		name = "Español",
		ask = "¡Hola! Soy %class% (%talents%), nivel %level%. ¿Me invitas?",
		invite = "¡Hola! ¿Quieres unirte al grupo para %dungeon%?",
		tank = "tanque", healer = "sanador", damage = "dps", word_or = "o",
		classes = {
			WARRIOR = {"guerrero", "guerrera"}, PALADIN = {"paladín", "paladina"},
			HUNTER = {"cazador", "cazadora"}, ROGUE = {"pícaro", "pícara"},
			PRIEST = {"sacerdote", "sacerdotisa"}, SHAMAN = {"chamán", "chamán"},
			MAGE = {"mago", "maga"}, WARLOCK = {"brujo", "bruja"}, DRUID = {"druida", "druida"},
		},
		trees = {
			WARRIOR = {"armas", "furia", "protección"},
			PALADIN = {"sagrado", "protección", "reprensión"},
			HUNTER = {"dominio de bestias", "puntería", "supervivencia"},
			ROGUE = {"asesinato", "combate", "sutileza"},
			PRIEST = {"disciplina", "sagrado", "sombra"},
			SHAMAN = {"elemental", "mejora", "restauración"},
			MAGE = {"arcano", "fuego", "escarcha"},
			WARLOCK = {"aflicción", "demonología", "destrucción"},
			DRUID = {"equilibrio", "combate feral", "restauración"},
		},
	},
}

local FAMILY = {ptBR = "ptBR", ptPT = "ptBR", enUS = "enUS", enGB = "enUS", esES = "esES", esMX = "esES"}

-- The message language closest to the game's (English when there is none).
Messages.client = FAMILY[GetLocale()] or "enUS"

function Messages:Get(code)
	return self.languages[code] or self.languages[self.client]
end

-- Class name in a language ("xamã", "shaman"); female when the character is.
function Messages:ClassName(code, class)
	local names = self:Get(code).classes[class]
	if not names then return ns.ClassName(class) or "" end
	local female = UnitSex("player") == 3
	return female and names[2] or names[1]
end

-- Talent tree name in a language, from its position (1 to 3); gameName when unknown.
function Messages:TreeName(code, class, index, gameName)
	if code == self.client and gameName and gameName ~= "" then
		return gameName -- the game's own wording
	end
	local trees = self:Get(code).trees[class]
	return trees and trees[index] or gameName or ""
end
