local _, ns = ...
local Compat = ns.Compat

-- The game's data for the loot rolls, part of Compat: the rolls themselves,
-- the loot history with everyone's choice, the game's roll frames, what an
-- item is, the group's units and the classes. Tests replace this file with
-- tests/mocks/CompatRolls.lua, which has the same functions.

-- A value the code may read: nil when the client made it secret.
local function open(value)
	if Compat.IsSecret(value) then
		return nil
	end
	return value
end

-- What a roll is about (GetLootRollItemInfo; the item's link, which the loot
-- history names too), or nil when the roll is gone.
function Compat.GetRollItem(rollID)
	local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, _, reasonNeed, reasonGreed, _, _, canTransmog =
		GetLootRollItemInfo(rollID)
	if not open(name) then
		return nil
	end
	return {
		rollID = rollID,
		texture = texture,
		name = name,
		count = count,
		quality = quality,
		bindOnPickUp = bindOnPickUp == true,
		canNeed = canNeed == true,
		canGreed = canGreed == true,
		canTransmog = canTransmog == true,
		reasonNeed = reasonNeed,
		reasonGreed = reasonGreed,
		link = open(GetLootRollItemLink(rollID)),
	}
end

-- The rolls open now, as the game reads them at login (after a /reload).
function Compat.GetActiveRolls()
	local ids = {}
	for _, rollID in ipairs(GetActiveLootRollIDs() or {}) do
		ids[#ids + 1] = rollID
	end
	return ids
end

-- A player on a drop of the loot history, in the addon's own words.
local function rollInfo(info)
	if type(info) ~= "table" then
		return nil
	end
	return {
		name = open(info.playerName),
		guid = open(info.playerGUID),
		class = open(info.playerClass),
		isSelf = info.isSelf == true,
		state = info.state,
		isWinner = info.isWinner == true,
		roll = open(info.roll),
	}
end

-- A drop of the loot history (EncounterLootDropInfo), with its key as listID:
-- lootListID on the live client, lootListKey on the PTR and on WoW Forever.
local function drop(encounterID, info)
	if type(info) ~= "table" then
		return nil
	end
	local rolls = {}
	for index, roll in ipairs(info.rollInfos or {}) do
		rolls[index] = rollInfo(roll)
	end
	return {
		encounterID = encounterID,
		listID = info.lootListID or info.lootListKey,
		link = open(info.itemHyperlink),
		playerRollState = info.playerRollState,
		currentLeader = rollInfo(info.currentLeader),
		isTied = info.isTied == true,
		winner = rollInfo(info.winner),
		allPassed = info.allPassed == true,
		startTime = info.startTime,
		duration = info.duration,
		rolls = rolls,
	}
end

-- One drop, its players in the game's order (who rolled highest first).
function Compat.GetLootDrop(encounterID, listID)
	return drop(encounterID, C_LootHistory.GetSortedInfoForDrop(encounterID, listID))
end

-- Every drop the loot history holds now, encounter by encounter.
function Compat.GetLootDrops()
	local drops = {}
	for _, encounter in ipairs(C_LootHistory.GetAllEncounterInfos() or {}) do
		for _, info in ipairs(C_LootHistory.GetSortedDropsForEncounter(encounter.encounterID) or {}) do
			drops[#drops + 1] = drop(encounter.encounterID, info)
		end
	end
	return drops
end

Compat.ROLL_FRAMES = 4

-- The game's roll frames (GroupLootFrame1 to 4), the ones this client has.
function Compat.GetGameRollFrames()
	local frames = {}
	for index = 1, Compat.ROLL_FRAMES do
		local frame = _G["GroupLootFrame" .. index]
		if frame then
			frames[#frames + 1] = frame
		end
	end
	return frames
end

-- The game's roll frames in the order the game stacks them, from the bottom:
-- { { frame = …, slot = 1 }, … }; GroupLootContainer keeps them with gaps.
function Compat.GetGameRollSlots()
	local slots = {}
	local container = GroupLootContainer
	if type(container) ~= "table" or type(container.rollFrames) ~= "table" then
		return slots
	end
	local max = tonumber(container.maxIndex) or Compat.ROLL_FRAMES
	for index = 1, max do
		local frame = container.rollFrames[index]
		if frame then
			slots[#slots + 1] = { frame = frame, slot = index }
		end
	end
	return slots
end

-- Whether the game has a loot history window of its own (retail's Loot
-- Rolls, GroupLootHistoryFrame), which opens after the player's choice.
function Compat.HasGameLootHistory()
	return _G["GroupLootHistoryFrame"] ~= nil
end

-- The container the game stacks its roll frames from, where it stands now.
function Compat.GetGameRollContainer()
	return GroupLootContainer
end

-- fn() after each of the game's layouts of its roll frames; false on a client
-- without that layout.
function Compat.AfterGameRollLayout(fn)
	if type(GroupLootContainer_Update) ~= "function" then
		return false
	end
	hooksecurefunc("GroupLootContainer_Update", fn)
	return true
end

-- fn(rollID, rollType) after the player chose on a roll, through the game's
-- buttons or anything else (RollOnLoot: 0 pass, 1 need, 2 greed, 4 transmog).
function Compat.OnRollChosen(fn)
	if type(RollOnLoot) ~= "function" then
		return false
	end
	hooksecurefunc("RollOnLoot", fn)
	return true
end

-- What an item is (C_Item.GetItemInfoInstant): its class, subclass, slot and icon.
function Compat.GetItemKind(item)
	local itemID, _, _, equipLoc, icon, classID, subclassID = C_Item.GetItemInfoInstant(item)
	if not itemID then
		return nil
	end
	return { itemID = itemID, classID = classID, subclassID = subclassID, equipLoc = equipLoc, icon = icon }
end

-- The item's stats by their keys (ITEM_MOD_STRENGTH_SHORT = 12), or nil while
-- the game has not loaded the item.
function Compat.GetItemStats(link)
	local stats = C_Item.GetItemStats(link)
	if type(stats) ~= "table" then
		return nil
	end
	local copy = {}
	for key, value in pairs(stats) do
		copy[key] = value
	end
	return copy
end

-- An item's subclass as the game names it ("Daggers").
function Compat.GetItemSubClassName(classID, subclassID)
	return C_Item.GetItemSubClassInfo(classID, subclassID)
end

-- The link of what the character wears in an inventory slot, or nil.
function Compat.GetEquippedLink(slot)
	return GetInventoryItemLink("player", slot)
end

function Compat.GetPlayerClass()
	local _, classFile = UnitClass("player")
	return classFile
end

function Compat.GetPlayerGUID()
	return UnitGUID("player")
end

-- A group member's class file ("WARRIOR"), level, GUID and name; nil for what
-- the client keeps secret.
function Compat.GetUnitClass(unit)
	local _, classFile = UnitClass(unit)
	return open(classFile)
end

function Compat.GetUnitLevel(unit)
	return open(UnitLevel(unit))
end

function Compat.GetUnitGUID(unit)
	return open(UnitGUID(unit))
end

function Compat.GetUnitName(unit)
	return open(UnitName(unit))
end

function Compat.IsInRaid()
	return IsInRaid() == true
end

-- The units of the group's members, the player among them: raid1 to raidN in
-- a raid, else player and party1 to partyN.
function Compat.GetGroupUnits()
	local units = {}
	if IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			units[#units + 1] = "raid" .. index
		end
	else
		units[1] = "player"
		for index = 1, GetNumSubgroupMembers() do
			units[#units + 1] = "party" .. index
		end
	end
	return units
end

function Compat.IsFriend(guid)
	return C_FriendList.IsFriend(guid) == true
end

-- IsGuildMember is not in the generated docs: Blizzard's SocialQueue.lua calls it.
function Compat.IsGuildMember(guid)
	return type(IsGuildMember) == "function" and IsGuildMember(guid) == true
end

-- A class's name as the game shows it, from its class ID.
function Compat.GetClassName(classID)
	local info = C_CreatureInfo.GetClassInfo(classID)
	return info and info.className
end

-- A class's colour (RAID_CLASS_COLORS): r, g, b, and its "ffrrggbb" code.
function Compat.GetClassColor(classFile)
	local color = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[classFile]
	if not color then
		return nil
	end
	return { r = color.r, g = color.g, b = color.b, code = color.colorStr }
end

-- Where the character is: the instance's name inside one, else the zone's.
function Compat.GetPlace()
	local name, instanceType = GetInstanceInfo()
	if instanceType and instanceType ~= "none" and name and name ~= "" then
		return name
	end
	return GetRealZoneText()
end

-- The server's time in seconds (the Unix time), for the history.
function Compat.GetServerTime()
	return GetServerTime()
end
