local _, ns = ...

-- Stand-in for Compat/Rolls.lua in tests: the same functions, backed by the
-- fake client of tests/mocks/Compat.lua (Compat.Test.state), with helpers in
-- Compat.Test to start rolls, fill the loot history and lay out the game's
-- roll frames.
local Compat = ns.Compat
local Test = Compat.Test
local state = Test.state

-- The rolls by ID ({ name, link, quality, texture, bindOnPickUp, canNeed, … }),
-- the loot history's drops as Compat gives them, the game's roll frames and
-- the hooks on their layout and on the player's choice.
state.rolls = {}
state.lootDrops = {}
state.gameRollFrames = {}
state.gameRollSlots = {}
state.gameRollContainer = nil
state.rollLayoutHooks = {}
state.rollChosenHooks = {}
-- What the character wears, by inventory slot: links.
state.worn = {}
state.playerClass = "WARRIOR"
state.playerGUID = "Player-1-00000001"
-- Units by token: { name, class, level, guid }; a raid while state.raid.
state.units = {}
state.raid = false
state.friends = {}
state.guild = {}
state.place = "The Deadmines"
state.serverTime = 1763600000

local CLASS_IDS = {
	WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7,
	MAGE = 8, WARLOCK = 9, MONK = 10, DRUID = 11, DEMONHUNTER = 12, EVOKER = 13,
}
local CLASS_NAMES = {
	"Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Death Knight", "Shaman", "Mage", "Warlock", "Monk",
	"Druid", "Demon Hunter", "Evoker",
}
local SUBCLASS_NAMES = {
	[2] = { [0] = "One-Handed Axes", [1] = "Two-Handed Axes", [2] = "Bows", [3] = "Guns", [4] = "One-Handed Maces",
		[5] = "Two-Handed Maces", [6] = "Polearms", [7] = "One-Handed Swords", [8] = "Two-Handed Swords", [9] = "Warglaives",
		[10] = "Staves", [13] = "Fist Weapons", [15] = "Daggers", [16] = "Thrown", [18] = "Crossbows", [19] = "Wands" },
	[4] = { [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate", [6] = "Shields", [7] = "Librams", [8] = "Idols",
		[9] = "Totems" },
}

local function copy(source)
	if type(source) ~= "table" then
		return source
	end
	local result = {}
	for key, value in pairs(source) do
		result[key] = copy(value)
	end
	return result
end

local function itemID(item)
	return type(item) == "string" and tonumber(item:match("item:(%d+)")) or item
end

function Compat.GetRollItem(rollID)
	return copy(state.rolls[rollID])
end

function Compat.GetActiveRolls()
	local ids = {}
	for rollID in pairs(state.rolls) do
		ids[#ids + 1] = rollID
	end
	table.sort(ids)
	return ids
end

local function findDrop(encounterID, listID)
	for index, drop in ipairs(state.lootDrops) do
		if drop.encounterID == encounterID and drop.listID == listID then
			return drop, index
		end
	end
end

function Compat.GetLootDrop(encounterID, listID)
	return copy((findDrop(encounterID, listID)))
end

function Compat.GetLootDrops()
	return copy(state.lootDrops)
end

Compat.ROLL_FRAMES = 4

function Compat.GetGameRollFrames()
	local frames = {}
	for index, frame in ipairs(state.gameRollFrames) do
		frames[index] = frame
	end
	return frames
end

-- The frames themselves, not copies.
function Compat.GetGameRollSlots()
	local slots = {}
	for index, slot in ipairs(state.gameRollSlots) do
		slots[index] = { frame = slot.frame, slot = slot.slot }
	end
	return slots
end

-- state.gameLootHistoryShown: whether the game's loot history window is on
-- the fake screen.
function Compat.IsGameLootHistoryShown()
	return state.gameLootHistoryShown == true
end

function Compat.GetGameRollContainer()
	return state.gameRollContainer
end

function Compat.AfterGameRollLayout(fn)
	state.rollLayoutHooks[#state.rollLayoutHooks + 1] = fn
	return true
end

function Compat.OnRollChosen(fn)
	state.rollChosenHooks[#state.rollChosenHooks + 1] = fn
	return true
end

-- Items are state.items' ({ classID, subclassID, equipLoc, stats, bindType }).
function Compat.GetItemKind(item)
	local id = itemID(item)
	local info = state.items[id]
	if not info or not info.classID then
		return nil
	end
	return { itemID = id, classID = info.classID, subclassID = info.subclassID, equipLoc = info.equipLoc or "", icon = info.icon }
end

-- An item with no stats yet (statsPending) answers nil, as the client does
-- before it has loaded the item.
function Compat.GetItemStats(link)
	local info = state.items[itemID(link)]
	if not info or info.statsPending then
		return nil
	end
	return copy(info.stats or {})
end

function Compat.GetItemSubClassName(classID, subclassID)
	return SUBCLASS_NAMES[classID] and SUBCLASS_NAMES[classID][subclassID]
end

function Compat.GetEquippedLink(slot)
	return state.worn[slot]
end

function Compat.GetPlayerClass()
	return state.playerClass
end

function Compat.GetPlayerGUID()
	return state.playerGUID
end

local function unit(token)
	return state.units[token] or {}
end

function Compat.GetUnitClass(token)
	return unit(token).class
end

function Compat.GetUnitLevel(token)
	return unit(token).level
end

function Compat.GetUnitGUID(token)
	return unit(token).guid
end

function Compat.GetUnitName(token)
	return unit(token).name
end

function Compat.IsInRaid()
	return state.raid
end

function Compat.GetGroupUnits()
	local units = {}
	if state.raid then
		local index = 1
		while state.units["raid" .. index] do
			units[#units + 1] = "raid" .. index
			index = index + 1
		end
	else
		units[1] = "player"
		local index = 1
		while state.units["party" .. index] do
			units[#units + 1] = "party" .. index
			index = index + 1
		end
	end
	return units
end

function Compat.IsFriend(guid)
	return state.friends[guid] == true
end

function Compat.IsGuildMember(guid)
	return state.guild[guid] == true
end

function Compat.GetClassName(classID)
	return CLASS_NAMES[classID]
end

-- Every class a colour of its own: its ID in the red.
function Compat.GetClassColor(classFile)
	local id = CLASS_IDS[classFile]
	if not id then
		return nil
	end
	return { r = id / 20, g = 0.5, b = 0.5, code = ("ff%02x8080"):format(id * 12) }
end

function Compat.GetPlace()
	return state.place
end

function Compat.GetServerTime()
	return state.serverTime
end

-- Test helpers.

-- StartRoll(7, { name = "Mail Helm", link = "|Hitem:100|h[Mail Helm]|h", quality = 2 })
-- as the game starts a roll: START_LOOT_ROLL(rollID, rollTime).
function Test.StartRoll(rollID, item)
	local facts = copy(item)
	facts.rollID = rollID
	state.rolls[rollID] = facts
	Test.FireEvent("START_LOOT_ROLL", rollID, 60000)
end

function Test.CancelRoll(rollID)
	state.rolls[rollID] = nil
	Test.FireEvent("CANCEL_LOOT_ROLL", rollID)
end

-- Puts a drop into the loot history (or replaces it) and fires
-- LOOT_HISTORY_UPDATE_DROP: { encounterID, listID, link, rolls = { { name,
-- guid, class, state, roll, isSelf, isWinner } }, winner, allPassed, playerRollState }.
function Test.SetLootDrop(drop)
	local _, index = findDrop(drop.encounterID, drop.listID)
	local saved = copy(drop)
	saved.rolls = saved.rolls or {}
	if index then
		state.lootDrops[index] = saved
	else
		state.lootDrops[#state.lootDrops + 1] = saved
	end
	Test.FireEvent("LOOT_HISTORY_UPDATE_DROP", drop.encounterID, drop.listID)
end

-- The player chose on a roll (RollOnLoot), as the hooks see it.
function Test.ChooseRoll(rollID, rollType)
	for _, hook in ipairs(state.rollChosenHooks) do
		hook(rollID, rollType)
	end
end

-- The game's layout of its roll frames (GroupLootContainer_Update): each
-- frame of state.gameRollSlots on its place above the container, then the hooks.
function Test.LayOutGameRolls()
	for _, slot in ipairs(state.gameRollSlots) do
		slot.frame:ClearAllPoints()
		slot.frame:SetPoint("CENTER", state.gameRollContainer, "BOTTOM", 0, 100 * (slot.slot - 0.5))
	end
	for _, hook in ipairs(state.rollLayoutHooks) do
		hook(state.gameRollContainer)
	end
end

-- SetUnits({ player = { name = "Tester", class = "WARRIOR", level = 60, guid = … },
-- party1 = { … } }, raid).
function Test.SetUnits(units, raid)
	state.units = copy(units)
	state.raid = raid == true
end
