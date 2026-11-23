local Loader = require("tests.helpers.loader")

-- The loot rolls' model (Modules/Rolls/Model.lua): rolls, the loot history's
-- drops, and which drop is which roll's.

local HELM = "|cff1eff00|Hitem:100::::::::40|h[Mail Helm]|h|r"
local RING = "|cff0070dd|Hitem:200::::::::40|h[Ring]|h|r"

describe("the loot rolls' model", function()
	local ns, Test, Model, heard

	before_each(function()
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Loader.Start(ns)
		Test = ns.Compat.Test
		Model = ns.Rolls.Model
		Model.Clear()
		heard = {}
		Model.Subscribe(function(kind, value)
			heard[#heard + 1] = { kind, type(value) == "table" and value.key or value }
		end)
	end)

	local function roll(rollID, link)
		Test.state.rolls[rollID] = { rollID = rollID, name = "Item", link = link, quality = 2 }
		return Model.AddRoll(rollID)
	end

	local function drop(listID, link, players, extra)
		local entry = { encounterID = 1, listID = listID, link = link, rolls = players or {}, playerRollState = 4 }
		for key, value in pairs(extra or {}) do
			entry[key] = value
		end
		Test.state.lootDrops[#Test.state.lootDrops + 1] = entry
		for index, saved in ipairs(Test.state.lootDrops) do
			if saved.listID == listID and saved ~= entry then
				table.remove(Test.state.lootDrops, index)
				break
			end
		end
		Model.UpdateDrop(1, listID)
	end

	local function player(name, state, number, extra)
		local entry = { name = name, guid = "g-" .. name, class = "WARRIOR", state = state, roll = number }
		for key, value in pairs(extra or {}) do
			entry[key] = value
		end
		return entry
	end

	it("binds a roll to its drop whether the drop comes after or before it", function()
		roll(7, HELM)
		assert.is_false(Model.View(7).bound)
		drop(2, HELM, { player("Brina", 4) })
		assert.equals("1:2", Model.Roll(7).drop)
		drop(3, RING)
		roll(8, RING)
		assert.equals("1:3", Model.Roll(8).drop)
		assert.is_nil(Model.AddRoll(99))
	end)

	it("shows everyone's choice and roll as they arrive, the leader, then the winner", function()
		roll(7, HELM)
		drop(2, HELM, { player("Brina", 4), player("Corvin", 4) })
		local view = Model.View(7)
		assert.same({ "Brina", 4 }, { view.players[1].name, view.players[1].state })
		drop(2, HELM, { player("Brina", 0, 87), player("Corvin", 3, 40) }, { currentLeader = player("Brina", 0, 87) })
		view = Model.View(7)
		assert.same({ 0, 87, true, false }, { view.players[1].state, view.players[1].roll, view.players[1].isLeader, view.players[2].isLeader })
		drop(2, HELM, { player("Brina", 0, 87, { isWinner = true }), player("Corvin", 3, 40) },
			{ currentLeader = player("Brina", 0, 87), winner = player("Brina", 0, 87) })
		view = Model.View(7)
		assert.same({ "Brina", false, true }, { view.winner.name, view.players[1].isLeader, view.players[1].isWinner })
	end)

	it("binds two copies of one item in the order they came, and swaps them when the player's choice shows otherwise", function()
		roll(7, HELM)
		roll(8, HELM)
		drop(2, HELM)
		drop(3, HELM)
		assert.same({ "1:2", "1:3" }, { Model.Roll(7).drop, Model.Roll(8).drop })
		Model.Chose(7, 1)
		Model.Chose(8, 2)
		-- The history says the need was on the second copy.
		drop(2, HELM, nil, { playerRollState = 3 })
		drop(3, HELM, nil, { playerRollState = 0 })
		assert.same({ "1:3", "1:2" }, { Model.Roll(7).drop, Model.Roll(8).drop })
	end)

	it("never binds a roll to a drop that is over: won or all passed", function()
		drop(2, HELM, nil, { allPassed = true })
		drop(3, HELM, nil, { winner = player("Brina", 0, 50) })
		roll(7, HELM)
		assert.is_nil(Model.Roll(7).drop)
		drop(4, HELM)
		assert.equals("1:4", Model.Roll(7).drop)
	end)

	it("ends a cancelled roll, and forgets everything at once", function()
		roll(7, HELM)
		roll(8, RING)
		Model.RemoveRoll(7)
		assert.is_nil(Model.Roll(7))
		assert.equals(1, #Model.Rolls())
		Model.Clear()
		assert.same({ {}, nil }, { Model.Rolls(), Model.Record(7) })
	end)

	it("keeps a roll the game ended for a while, with its drop, bound to one that comes later too", function()
		roll(7, HELM)
		drop(2, HELM, { player("Brina", 4) })
		Model.RemoveRoll(7)
		-- Ended as the player chose: still known, with its drop and its view.
		assert.same({ "1:2", "1:2", "Brina" }, { Model.Record(7).drop, Model.DropOf(7).key, Model.View(7).players[1].name })
		-- A roll ended before its drop came gets it when it comes.
		roll(8, RING)
		Model.RemoveRoll(8)
		drop(3, RING)
		assert.equals("1:3", Model.Record(8).drop)
		-- An open roll of the same item comes first; past a while, an ended
		-- one waits no more.
		roll(11, RING)
		Model.RemoveRoll(11)
		roll(12, RING)
		drop(5, RING)
		assert.same({ "1:5", nil }, { Model.Roll(12).drop, Model.Record(11).drop })
		Test.Advance(Model.BIND_WAIT)
		drop(6, RING)
		assert.is_nil(Model.Record(11).drop)
		-- Forgotten after a while.
		Test.Advance(Model.ENDED + 1)
		roll(10, HELM)
		Model.RemoveRoll(10)
		assert.same({ nil, nil, true }, { Model.Record(7), Model.Record(8), Model.Record(10) ~= nil })
	end)

	it("never binds an ended roll again once the game clears its loot history", function()
		roll(7, HELM)
		drop(2, HELM)
		Model.RemoveRoll(7)
		Model.ClearDrops()
		-- The next dungeon's drop may carry the same numbers.
		roll(8, HELM)
		drop(2, HELM)
		assert.same({ nil, "1:2" }, { Model.Record(7).drop, Model.Roll(8).drop })
		drop(3, HELM)
		assert.is_nil(Model.Record(7).drop)
	end)

	it("reads every drop of the loot history at once, binding the rolls open after a /reload", function()
		Test.state.lootDrops = { { encounterID = 5, listID = 1, link = HELM, rolls = {} }, { encounterID = 5, listID = 2, link = RING, rolls = {} } }
		Test.state.rolls[7] = { rollID = 7, name = "Ring", link = RING }
		Model.AddRoll(7)
		Model.RefreshDrops()
		assert.equals("5:2", Model.Roll(7).drop)
		assert.is_table(Model.Drop("5:1"))
		-- The history cleared: the roll waits for its drop again.
		Model.ClearDrops()
		assert.is_nil(Model.Roll(7).drop)
	end)

	it("takes a drop made from the chat for a roll the history never showed, until the history's own comes", function()
		roll(7, HELM)
		Test.state.time = 3
		assert.is_true(Model.Unbound(7, 2))
		Model.SetChatDrop(7, { rolls = { player("Brina", 0, 70) } })
		assert.same({ true, "Brina" }, { Model.View(7).bound, Model.View(7).players[1].name })
		drop(2, HELM, { player("Corvin", 3, 20) })
		assert.same({ "1:2", "Corvin" }, { Model.Roll(7).drop, Model.View(7).players[1].name })
		assert.is_false(Model.Unbound(7, 2))
	end)

	it("tells its subscribers about every roll and drop", function()
		roll(7, HELM)
		drop(2, HELM)
		assert.same({ { "roll", 7 }, { "roll", 7 }, { "drop", "1:2" } }, heard)
	end)

	it("knows a roll's length from its start, and the share of it left", function()
		Test.state.rollTimes = { [7] = 30000 }
		Test.StartRoll(7, { name = "Mail Helm", link = HELM, quality = 2 })
		-- START_LOOT_ROLL's length (the fake client's 60 seconds).
		assert.equals(60000, ns.Rolls.Model.Roll(7).total)
		Test.state.rollTimes[7] = 15000
		assert.equals(0.25, ns.Rolls.Model.TimeShare(7))
		Test.state.rollTimes[7] = nil
		assert.is_nil(ns.Rolls.Model.TimeShare(7))
	end)
end)
