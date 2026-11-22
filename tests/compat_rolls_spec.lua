-- The loot rolls' part of Compat (Compat/Rolls.lua) against stubbed game globals.

local function stub(globals)
	for name, value in pairs(globals) do
		rawset(_G, name, value)
	end
end

local function loadCompat()
	local ns = {}
	assert(loadfile("Compat/Compat.lua"))("Lootoman", ns)
	assert(loadfile("Compat/Rolls.lua"))("Lootoman", ns)
	return ns.Compat
end

describe("Compat for the loot rolls", function()
	local Compat

	before_each(function()
		rawset(_G, "issecretvalue", function(value) return value == "secret" end)
		rawset(_G, "hooksecurefunc", function(name, hook)
			local original = _G[name]
			_G[name] = function(...)
				original(...)
				hook(...)
			end
		end)
		Compat = loadCompat()
	end)

	it("rolls through the game's RollOnLoot, reads a roll's time left, and keeps the game's roll frames away where it can", function()
		local rolled, dropped = {}, {}
		stub({
			RollOnLoot = function(rollID, rollType) rolled[#rolled + 1] = { rollID, rollType } end,
			GetLootRollTimeLeft = function(rollID) return rollID == 7 and 45000 or "secret" end,
			GameEvent = { UnregisterInternalEvent = function(event) dropped[#dropped + 1] = event end },
		})
		Compat.RollOnLoot(7, 2)
		assert.same({ { 7, 2 } }, rolled)
		assert.same({ 45000, nil }, { Compat.GetRollTimeLeft(7), Compat.GetRollTimeLeft(8) })
		assert.is_true(Compat.KeepGameRollFramesAway())
		assert.same({ "START_LOOT_ROLL" }, dropped)
		-- A client without the game's internal routing.
		rawset(_G, "GameEvent", nil)
		assert.is_false(Compat.KeepGameRollFramesAway())
		stub({ RollOnLoot = nil, GetLootRollTimeLeft = nil })
	end)

	it("reads a roll's item, and nothing for a roll that is gone or kept secret", function()
		stub({
			GetLootRollItemInfo = function(rollID)
				if rollID == 7 then
					return 135000, "Mail Helm", 1, 2, true, false, true, false, 3, 0, 0, 0, true
				elseif rollID == 8 then
					return 135000, "secret", 1, 2
				end
			end,
			GetLootRollItemLink = function(rollID) return "|Hitem:100|h[Mail Helm]|h" .. rollID end,
		})
		assert.same({ rollID = 7, texture = 135000, name = "Mail Helm", count = 1, quality = 2, bindOnPickUp = true, canNeed = false,
			canGreed = true, canTransmog = true, reasonNeed = 3, reasonGreed = 0, link = "|Hitem:100|h[Mail Helm]|h7" }, Compat.GetRollItem(7))
		assert.is_nil(Compat.GetRollItem(8))
		assert.is_nil(Compat.GetRollItem(9))
	end)

	it("lists the open rolls the game reads at login", function()
		stub({ GetActiveLootRollIDs = function() return { 4, 9 } end })
		assert.same({ 4, 9 }, Compat.GetActiveRolls())
	end)

	it("reads a drop of the loot history by either name of its key, the live client's and the PTR's", function()
		local infos = {
			[11] = { lootListID = 2, itemHyperlink = "link-a", playerRollState = 4, allPassed = false, startTime = 50,
				rollInfos = { { playerName = "Brina", playerGUID = "g1", playerClass = "MAGE", state = 0, roll = 87, isSelf = false } },
				currentLeader = { playerName = "Brina", playerGUID = "g1", playerClass = "MAGE", state = 0, roll = 87 } },
			[12] = { lootListKey = 5, itemHyperlink = "link-b", playerRollState = 3,
				rollInfos = { { playerName = "secret", playerGUID = "g2", playerClass = "ROGUE", state = 3, roll = "secret", isSelf = true } } },
		}
		stub({ C_LootHistory = {
			GetSortedInfoForDrop = function(encounterID) return infos[encounterID] end,
			GetAllEncounterInfos = function() return { { encounterID = 11 }, { encounterID = 12 } } end,
			GetSortedDropsForEncounter = function(encounterID) return { infos[encounterID] } end,
		} })
		local first = Compat.GetLootDrop(11, 2)
		assert.same({ 11, 2, "link-a", 4, false }, { first.encounterID, first.listID, first.link, first.playerRollState, first.allPassed })
		assert.same({ name = "Brina", guid = "g1", class = "MAGE", isSelf = false, state = 0, isWinner = false, roll = 87 }, first.rolls[1])
		assert.equals("Brina", first.currentLeader.name)
		assert.is_nil(first.winner)
		local second = Compat.GetLootDrop(12, 5)
		assert.equals(5, second.listID)
		-- What the client keeps secret is left out, never read.
		assert.same({ nil, nil, true }, { second.rolls[1].name, second.rolls[1].roll, second.rolls[1].isSelf })
		local all = Compat.GetLootDrops()
		assert.same({ 2, 5 }, { all[1].listID, all[2].listID })
		assert.is_nil(Compat.GetLootDrop(13, 1))
	end)

	it("finds the game's roll frames and the order the game stacks them in", function()
		local one, three = { name = "GroupLootFrame1" }, { name = "GroupLootFrame3" }
		stub({ GroupLootFrame1 = one, GroupLootFrame3 = three })
		assert.same({ one, three }, Compat.GetGameRollFrames())
		-- The container keeps its frames with gaps.
		stub({ GroupLootContainer = { maxIndex = 4, rollFrames = { [1] = three, [3] = one } } })
		assert.same({ { frame = three, slot = 1 }, { frame = one, slot = 3 } }, Compat.GetGameRollSlots())
		rawset(_G, "GroupLootContainer", nil)
		assert.same({}, Compat.GetGameRollSlots())
	end)

	it("runs a function after the game's layout of its roll frames and after the player's choice, where the client has them", function()
		local laidOut, chosen = 0, {}
		rawset(_G, "GroupLootContainer_Update", nil)
		rawset(_G, "RollOnLoot", nil)
		assert.is_false(Compat.AfterGameRollLayout(function() end))
		assert.is_false(Compat.OnRollChosen(function() end))
		stub({ GroupLootContainer_Update = function() end, RollOnLoot = function() end })
		assert.is_true(Compat.AfterGameRollLayout(function() laidOut = laidOut + 1 end))
		assert.is_true(Compat.OnRollChosen(function(rollID, rollType) chosen = { rollID, rollType } end))
		_G.GroupLootContainer_Update()
		_G.RollOnLoot(7, 1)
		assert.same({ 1, { 7, 1 } }, { laidOut, chosen })
	end)

	it("reads what an item is and its stats, and nothing for stats not loaded yet", function()
		stub({ C_Item = {
			GetItemInfoInstant = function(item)
				if item == "link" then
					return 100, "Armor", "Mail", "INVTYPE_HEAD", 135000, 4, 3
				end
			end,
			GetItemStats = function(link)
				if link == "link" then
					return { ITEM_MOD_INTELLECT_SHORT = 12 }
				end
			end,
			GetItemSubClassInfo = function(classID, subclassID) return classID == 4 and subclassID == 3 and "Mail" or nil end,
		} })
		assert.same({ itemID = 100, classID = 4, subclassID = 3, equipLoc = "INVTYPE_HEAD", icon = 135000 }, Compat.GetItemKind("link"))
		assert.is_nil(Compat.GetItemKind("unknown"))
		assert.same({ ITEM_MOD_INTELLECT_SHORT = 12 }, Compat.GetItemStats("link"))
		assert.is_nil(Compat.GetItemStats("other"))
		assert.equals("Mail", Compat.GetItemSubClassName(4, 3))
	end)

	it("lists the group's units: raid1 to raidN in a raid, else the player and party1 to partyN", function()
		local raid = false
		stub({
			IsInRaid = function() return raid end,
			GetNumGroupMembers = function() return 3 end,
			GetNumSubgroupMembers = function() return 2 end,
		})
		assert.same({ "player", "party1", "party2" }, Compat.GetGroupUnits())
		raid = true
		assert.same({ "raid1", "raid2", "raid3" }, Compat.GetGroupUnits())
		assert.is_true(Compat.IsInRaid())
	end)

	it("reads a unit's class, level, GUID and name, leaving out secret ones", function()
		stub({
			UnitClass = function(unit) return "Warrior", unit == "party1" and "WARRIOR" or "secret" end,
			UnitLevel = function(unit) return unit == "party1" and 45 or "secret" end,
			UnitGUID = function(unit) return unit == "party1" and "g1" or "secret" end,
			UnitName = function(unit) return unit == "party1" and "Orlen" or "secret" end,
		})
		assert.same({ "WARRIOR", 45, "g1", "Orlen" }, { Compat.GetUnitClass("party1"), Compat.GetUnitLevel("party1"),
			Compat.GetUnitGUID("party1"), Compat.GetUnitName("party1") })
		assert.same({}, { Compat.GetUnitClass("boss1"), Compat.GetUnitLevel("boss1"), Compat.GetUnitGUID("boss1"), Compat.GetUnitName("boss1") })
	end)

	it("tells friends and guild members, without the guild function on a client that lacks it", function()
		stub({ C_FriendList = { IsFriend = function(guid) return guid == "g1" end } })
		rawset(_G, "IsGuildMember", nil)
		assert.is_true(Compat.IsFriend("g1"))
		assert.is_false(Compat.IsFriend("g2"))
		assert.is_false(Compat.IsGuildMember("g1"))
		stub({ IsGuildMember = function(guid) return guid == "g2" end })
		assert.is_true(Compat.IsGuildMember("g2"))
	end)

	it("names classes and gives their colours", function()
		stub({
			C_CreatureInfo = { GetClassInfo = function(classID) return classID == 1 and { className = "Warrior", classFile = "WARRIOR" } or nil end },
			RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc69b6d" } },
		})
		assert.equals("Warrior", Compat.GetClassName(1))
		assert.is_nil(Compat.GetClassName(99))
		assert.same({ r = 0.78, g = 0.61, b = 0.43, code = "ffc69b6d" }, Compat.GetClassColor("WARRIOR"))
		assert.is_nil(Compat.GetClassColor("NOBODY"))
	end)

	it("names the place: the instance inside one, else the zone", function()
		local inside = true
		stub({
			GetInstanceInfo = function() return inside and "The Deadmines" or "Westfall", inside and "party" or "none" end,
			GetRealZoneText = function() return "Westfall" end,
		})
		assert.equals("The Deadmines", Compat.GetPlace())
		inside = false
		assert.equals("Westfall", Compat.GetPlace())
	end)
end)
