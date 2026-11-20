local Loader = require("tests.helpers.loader")

-- Groups and the roll history kept by group (Modules/Rolls/Groups.lua, History.lua).

local HELM = "|cff1eff00|Hitem:100::::::::40|h[Mail Helm]|h|r"
local RING = "|cff0070dd|Hitem:200::::::::40|h[Ring]|h|r"

describe("the roll history", function()
	local ns, Test, History, Groups

	local function start(saved, inGroup)
		ns = Loader.LoadAddon({ gameType = "camelot" })
		-- The module opens or closes the group as it starts.
		ns.Compat.Test.state.group = inGroup == true
		Loader.Start(ns, saved)
		Test = ns.Compat.Test
		History, Groups = ns.Rolls.History, ns.Rolls.Groups
	end

	local function saved()
		return Test.state.saved.LootomanCharDB.sections.rollHistory
	end

	local function drop(key, link, rolls, extra)
		local entry = { key = key, link = link, rolls = rolls or {} }
		for name, value in pairs(extra or {}) do
			entry[name] = value
		end
		return entry
	end

	before_each(function()
		start()
		Test.SetGroup(true)
		Test.SetUnits({
			player = { name = "Tester", class = "WARRIOR", level = 30, guid = Test.state.playerGUID },
			party1 = { name = "Brina", class = "ROGUE", level = 41, guid = "g-brina" },
		})
	end)

	it("opens a group on joining and closes it on leaving the same group", function()
		Groups.Joined(1, "Party-1")
		Test.state.serverTime = Test.state.serverTime + 60
		Groups.Left(1, "Party-2")
		assert.is_table(History.Open())
		Test.SetGroup(false)
		Groups.Left(1, "Party-1")
		assert.is_nil(History.Open())
		local group = saved().groups[1]
		assert.same({ "Party-1", 1, 60 }, { group.id, group.category, group.ended - group.started })
		assert.equals(1, saved().schema)
	end)

	it("keeps a party that became a raid as the same group", function()
		Groups.Joined(1, "Party-1")
		Groups.Joined(1, "Party-1")
		assert.equals(1, #saved().groups)
	end)

	it("goes on with the open group after a /reload in a group, and closes it at a login outside one", function()
		Groups.Joined(1, "Party-1")
		History.Record(drop("1:1", HELM, { { guid = "g-brina", name = "Brina", class = "ROGUE", state = 0, roll = 50 } }))
		local char = Test.state.saved.LootomanCharDB
		start({ LootomanCharDB = char }, true)
		assert.is_table(Groups.Login())
		assert.equals(1, #History.Open().drops)
		start({ LootomanCharDB = char }, false)
		assert.is_nil(Groups.Login())
		assert.is_number(saved().groups[1].ended)
	end)

	it("starts a group of its own for the home party after leaving an instance group", function()
		Groups.Joined(1, "Home")
		Groups.Joined(2, "Instance")
		assert.same({ "Instance", 2 }, { History.Open().id, History.Open().category })
		Groups.Left(2, "Instance")
		assert.is_table(History.Open())
		assert.is_nil(History.Open().id)
		Groups.Joined(1, "Home")
		assert.equals("Home", History.Open().id)
		assert.equals(3, #saved().groups)
	end)

	it("keeps a drop once with its time, place, quality and each player's GUID and level, and updates it", function()
		Groups.Joined(1, "Party-1")
		History.Record(drop("1:1", HELM, { { guid = "g-brina", name = "Brina", class = "ROGUE", state = 4 } }))
		History.Record(drop("1:1", HELM, { { guid = "g-brina", name = "Brina", class = "ROGUE", state = 0, roll = 77 } },
			{ winner = { guid = "g-brina" } }))
		local kept = History.Open().drops
		assert.equals(1, #kept)
		assert.same({ "1:1", Test.state.serverTime, "The Deadmines", HELM, 2, "g-brina" },
			{ kept[1].key, kept[1].time, kept[1].place, kept[1].link, kept[1].quality, kept[1].winner })
		assert.same({ guid = "g-brina", name = "Brina", class = "ROGUE", level = 41, state = 0, roll = 77 }, kept[1].rolls[1])
		-- An excused need stays excused as the drop changes.
		assert.is_true(History.SetExcused(History.Open(), "1:1", "g-brina", true))
		History.Record(drop("1:1", HELM, { { guid = "g-brina", name = "Brina", class = "ROGUE", state = 0, roll = 77 } }))
		assert.is_true(kept[1].rolls[1].excused)
		assert.is_false(History.SetExcused(History.Open(), "1:9", "g-brina", true))
	end)

	it("keeps nothing outside a group", function()
		assert.is_nil(History.Record(drop("1:1", HELM)))
		Test.SetGroup(false)
		assert.is_nil(Groups.Current())
		Test.SetGroup(true)
		assert.is_table(Groups.Current())
	end)

	it("reads a player's choices in a group, and the last group he was in with the character", function()
		Groups.Joined(1, "Party-1")
		History.Record(drop("1:1", HELM, { { guid = "g-brina", state = 0 } }))
		History.Record(drop("1:2", RING, { { guid = "g-brina", state = 3 } }))
		local first = History.Open()
		Groups.Left(1, "Party-1")
		Groups.Joined(1, "Party-2")
		History.Record(drop("2:1", RING, { { guid = "other", state = 0 } }))
		Groups.Left(1, "Party-2")
		Groups.Joined(1, "Party-3")
		assert.same({ 0, 3 }, { History.Choices(first, "g-brina")[1].state, History.Choices(first, "g-brina")[2].state })
		assert.equals(1, #History.Choices(first, "g-brina", "1:2"))
		assert.equals(first, History.LastShared("g-brina"))
		assert.is_nil(History.LastShared("nobody"))
	end)

	it("keeps the newest groups and drops, the oldest groups going first", function()
		History.MAX_GROUPS, History.MAX_DROPS = 3, 5
		for index = 1, 4 do
			Groups.Joined(1, "Party-" .. index)
			History.Record(drop(index .. ":1", HELM))
			History.Record(drop(index .. ":2", RING))
		end
		local groups = saved().groups
		assert.same({ 2, "Party-3", "Party-4" }, { #groups, groups[1].id, groups[2].id })
		for index = 3, 8 do
			History.Record(drop("4:" .. index, HELM))
		end
		assert.same({ 1, 5 }, { #groups, #groups[1].drops })
		assert.same({ 1, 5 }, { History.Size() })
	end)

	-- A fixture of two closed groups and an open one: Brina needs and wins,
	-- Kael greeds, passes and is renamed Kaelan; a need of Brina's is excused.
	local function fixture()
		Groups.Joined(1, "Party-1")
		Test.state.place = "The Deadmines"
		History.Record(drop("1:1", HELM, {
			{ guid = "g-brina", name = "Brina", class = "ROGUE", state = 0, roll = 90 },
			{ guid = "g-kael", name = "Kael", class = "MAGE", state = 3, roll = 40 },
		}, { winner = { guid = "g-brina" } }))
		Test.state.place = "Wailing Caverns"
		History.Record(drop("1:2", RING, {
			{ guid = "g-brina", name = "Brina", class = "ROGUE", state = 0, roll = 12 },
			{ guid = "g-kael", name = "Kael", class = "MAGE", state = 2, roll = 80 },
		}, { winner = { guid = "g-kael" } }))
		Test.state.place = "The Deadmines"
		History.Record(drop("1:3", HELM, {
			{ guid = "g-brina", name = "Brina", class = "ROGUE", state = 5 },
			{ guid = "g-kael", name = "Kael", class = "MAGE", state = 5 },
		}, { allPassed = true }))
		History.SetExcused(History.Open(), "1:2", "g-brina", true)
		local first = History.Open()
		Groups.Left(1, "Party-1")
		Test.state.serverTime = Test.state.serverTime + 3600
		Groups.Joined(1, "Party-2")
		History.Record(drop("2:1", RING, {
			{ guid = "g-kael", name = "Kaelan", class = "MAGE", state = 0, roll = 99 },
		}, { winner = { guid = "g-kael" } }))
		local second = History.Open()
		Groups.Left(1, "Party-2")
		Groups.Joined(1, "Party-3")
		return first, second, History.Open()
	end

	it("counts each player's choices in a group, a transmog as a greed, under their latest name", function()
		local first = fixture()
		local players = History.Players(first)
		assert.same({ guid = "g-brina", name = "Brina", class = "ROGUE", need = 2, greed = 0, pass = 1, won = 1 }, players[1])
		assert.same({ guid = "g-kael", name = "Kael", class = "MAGE", need = 0, greed = 2, pass = 1, won = 1 }, players[2])
		assert.same({}, History.Players(nil))
		assert.same({ "The Deadmines", "Wailing Caverns" }, History.Places(first))
	end)

	it("finds a player in every group by GUID, newest group first, under their latest name", function()
		local first, second = fixture()
		local kael = History.Across("g-kael")
		assert.same({ guid = "g-kael", name = "Kaelan", class = "MAGE", need = 1, greed = 2, pass = 1, won = 2 }, kael.player)
		assert.same({ second, first }, { kael.groups[1].group, kael.groups[2].group })
		assert.same({ "2:1" }, { kael.groups[1].drops[1].entry.key })
		assert.same({ 3, 80 }, { #kael.groups[2].drops, kael.groups[2].drops[2].choice.roll })
		assert.is_true(History.Across("g-brina").groups[1].drops[2].choice.excused)
		assert.is_nil(History.Across("nobody"))
	end)

	it("deletes a group, the open one too, and everything", function()
		local first, second, open = fixture()
		assert.is_true(History.Delete(first))
		assert.is_false(History.Delete(first))
		assert.same({ second, open }, saved().groups)
		assert.is_true(History.Delete(open))
		assert.is_nil(History.Open())
		-- Still in a group: the next drop starts a new one.
		assert.is_table(Groups.Current())
		assert.equals(2, #saved().groups)
		History.Clear()
		assert.same({}, saved().groups)
		assert.same({ 0, 0 }, { History.Size() })
		assert.equals(1, saved().schema)
	end)

	it("writes the times of drops as hours and minutes", function()
		assert.equals("01:05", ns.Compat.FormatTime(3900))
	end)

	it("writes nothing into saved data it must leave alone", function()
		local newer = { schema = 999, profiles = {} }
		local char = { schema = 999, sections = { rollHistory = { schema = 1, groups = {} } } }
		start({ LootomanDB = newer, LootomanCharDB = char })
		Test.SetGroup(true)
		Groups.Joined(1, "Party-1")
		History.Record(drop("1:1", HELM))
		assert.same({}, char.sections.rollHistory.groups)
	end)

	it("deletes nothing in saved data it must leave alone", function()
		local newer = { schema = 999, profiles = {} }
		local char = { schema = 999, sections = { rollHistory = { schema = 1, groups = { { started = 1, ended = 2, drops = {} } } } } }
		start({ LootomanDB = newer, LootomanCharDB = char })
		-- The session runs on an empty history in memory.
		History.Delete(History.Groups()[1])
		History.Clear()
		assert.equals(1, #char.sections.rollHistory.groups)
	end)
end)
