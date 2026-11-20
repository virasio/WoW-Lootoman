local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- The made-up choices beside Edit Mode's look-alikes of the game's roll
-- frames: while the player moves the roll frames in Edit Mode (the roll
-- frames' module) and the loot rolls are on, a panel stands beside each
-- look-alike, at its right, with heroes of Azeroth choosing: five on the
-- group's item, twenty on the raid's, each hero with the class his stories
-- give him, among the classes the client has, and, with the detection on,
-- marks of their own made-up past. Everything in it is made up: nothing goes
-- to the game, nothing into the history. The items are the data's (a blue
-- dagger or WoW Forever's ring for the group, a sword of Onyxia's for the
-- raid), or worn gear for one the game has not loaded. The played demo is
-- in the repository's version only.
ns.Rolls = ns.Rolls or {}
local Demo = {}
ns.Rolls.Demo = Demo

local Panel = ns.Rolls.Panel
local STATE = ns.Rules.Need.STATE

-- The demo's players: heroes of Azeroth, each with the class of his stories.
Demo.HEROES = {
	{ L["Thrall"], "SHAMAN" }, { L["Jaina"], "MAGE" }, { L["Varian"], "WARRIOR" }, { L["Uther"], "PALADIN" },
	{ L["Sylvanas"], "HUNTER" }, { L["Tyrande"], "PRIEST" }, { L["Malfurion"], "DRUID" }, { L["Valeera"], "ROGUE" },
	{ L["Gul'dan"], "WARLOCK" }, { L["Rexxar"], "HUNTER" }, { L["Anduin"], "PRIEST" }, { L["Khadgar"], "MAGE" },
	{ L["Tirion"], "PALADIN" }, { L["Garrosh"], "WARRIOR" }, { L["Velen"], "PRIEST" }, { L["Alleria"], "HUNTER" },
	{ L["Muradin"], "WARRIOR" }, { L["Hamuul"], "DRUID" }, { L["Kel'Thuzad"], "WARLOCK" }, { L["Shaw"], "ROGUE" },
	{ L["Broll"], "DRUID" }, { L["Turalyon"], "PALADIN" }, { L["Drek'Thar"], "SHAMAN" }, { L["Antonidas"], "MAGE" },
	{ L["Garona"], "ROGUE" }, { L["Nobundo"], "SHAMAN" }, { L["Arthas"], "DEATHKNIGHT" }, { L["Darion"], "DEATHKNIGHT" },
	{ L["Chen"], "MONK" }, { L["Aysa"], "MONK" }, { L["Illidan"], "DEMONHUNTER" }, { L["Kayn"], "DEMONHUNTER" },
	{ L["Wrathion"], "EVOKER" }, { L["Ebyssian"], "EVOKER" },
}
Demo.RAID = 20

-- The demo's two items, the group's then the raid's (Modules/Shared/RollLookalike.lua).
function Demo.Items()
	return ns.RollLookalike.Items()
end

-- The heroes whose class the client has: { name, class, guid }.
function Demo.Heroes()
	local list = {}
	for index, hero in ipairs(Demo.HEROES) do
		if ns.Data.rolls.canEquip[hero[2]] then
			list[#list + 1] = { name = hero[1], class = hero[2], guid = "Demo-" .. index }
		end
	end
	return list
end

-- count heroes, from a turn of the clock so each demo differs. In the group
-- roll the first stands for the player (his line marked as one's own), with a
-- hero's name too: the demo is for pictures, and names no real character.
function Demo.NewPlayers(count, turn, withSelf)
	local players, heroes = {}, Demo.Heroes()
	for index = 1, math.min(#heroes, count) do
		local hero = heroes[((index + turn) % #heroes) + 1]
		players[index] = { name = hero.name, class = hero.class, guid = hero.guid, level = 30 + ((index * 7 + turn) % 30), state = STATE.NONE,
			isSelf = withSelf and index == 1 or nil }
	end
	return players
end

-- Makes a player of the card another hero, of the class given, who is not on
-- the card yet; false when there is none.
local function becomeHero(card, player, class)
	local taken = {}
	for _, other in ipairs(card.view.players) do
		taken[other.guid] = true
	end
	for _, hero in ipairs(Demo.Heroes()) do
		if hero.class == class and not taken[hero.guid] then
			player.name, player.class, player.guid = hero.name, hero.class, hero.guid
			return true
		end
	end
	return false
end

-- No history in the demo: its marks come from its own made-up past.
local NO_HISTORY = {
	Open = function() return nil end,
	Choices = function() return {} end,
	LastShared = function() return nil end,
}

-- The demo's marks, for the detection when it is on. In the group roll the
-- first made-up player needs an item that does not fit his class (a warrior
-- past 40 on mail, when the item is mail) after greeding a BoE item that
-- fits; the fourth carries a mark from a made-up last group. In the raid
-- roll, three of those who need are marked as needing nearly everything.
function Demo.Context(card, group, otherLink)
	local context = { history = NO_HISTORY, reasons = {}, levels = {}, excused = card.excused or {} }
	card.excused = context.excused
	local facts = ns.Rolls.Marks.Facts(card.view.link)
	local made = {}
	for _, player in ipairs(card.view.players) do
		if not player.isSelf then
			made[#made + 1] = player
		end
	end
	if group then
		local first, fourth = made[1], made[4]
		if first and facts then
			if facts.classID == ns.Rules.Need.ARMOR and facts.subclassID == 3 then
				becomeHero(card, first, "WARRIOR")
				first.level = 45
			else
				local breaking = ns.Rolls.Marks.BreakingClass(facts, first.level)
				if breaking and breaking ~= first.class then
					becomeHero(card, first, breaking)
				end
			end
			if facts.bindType == ns.Rolls.Marks.BOE then
				context.reasons[first.guid] = { { kind = "greedFitting", link = otherLink } }
			end
		end
		if fourth then
			context.reasons[fourth.guid] = { { kind = "lastTime", needs = 6, total = 7, day = Compat.FormatDay(Compat.GetServerTime() - 86400),
				place = Compat.GetPlace() } }
		end
	else
		local marked = 0
		for index, player in ipairs(made) do
			if index % 3 == 1 and marked < 3 then
				marked = marked + 1
				context.reasons[player.guid] = { { kind = "everything", needs = 5, total = 6 } }
			end
		end
	end
	for _, player in ipairs(card.view.players) do
		context.levels[player.guid] = player.level
	end
	return context
end

-- Edit Mode shows the roll frames' look-alikes (the roll frames' module's)
-- where the moved frames will stand; while the loot rolls are on, a panel of
-- made-up choices stands beside each, at its right, on the look-alikes'
-- strata and level, so Edit Mode's selection covers them too.
local previews = {}

function Demo.Preview(frames, strata, level)
	local items = Demo.Items()
	for slot, frame in ipairs(frames) do
		local panel = previews[slot] or Panel.New()
		previews[slot] = panel
		if strata then
			panel.frame:SetFrameStrata(strata)
			panel.frame:SetFrameLevel(level or 1)
		end
		local group = slot == 1
		local view = { rollID = "preview" .. slot, link = items[slot], bound = true, demo = true,
			players = Demo.NewPlayers(group and 5 or Demo.RAID, slot, group) }
		local card = { view = view }
		card.context = Demo.Context(card, group, items[group and 2 or 1])
		ns.Rolls.Marks.Add(view, card.context)
		Panel.Show(panel, frame, view, "right")
	end
end

function Demo.EndPreview()
	for _, panel in ipairs(previews) do
		Panel.Hide(panel)
	end
end
