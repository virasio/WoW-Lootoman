local Loader = require("tests.helpers.loader")

-- The chat as a fallback for rolls the loot history never shows (Modules/Rolls/Chat.lua).

local HELM = "|cff1eff00|Hitem:100::::::::40|h[Mail Helm]|h|r"

local ENGLISH = {
	LOOT_ROLL_NEED = "%s has selected Need for: %s",
	LOOT_ROLL_GREED = "%s has selected Greed for: %s",
	LOOT_ROLL_PASSED = "%s passed on: %s",
	LOOT_ROLL_NEED_SELF = "You have selected Need for: %s",
	LOOT_ROLL_ROLLED_NEED = "Need Roll - %d for %s by %s",
	LOOT_ROLL_ROLLED_GREED = "Greed Roll - %d for %s by %s",
	LOOT_ROLL_WON = "%s won: %s",
	LOOT_ROLL_YOU_WON = "You won: %s",
	LOOT_ROLL_ALL_PASSED = "Everyone passed on: %s",
}

describe("the chat as a fallback", function()
	local ns, Test, Chat, Model

	before_each(function()
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Loader.Start(ns)
		Test = ns.Compat.Test
		Test.SetGlobalStrings(ENGLISH)
		Chat, Model = ns.Rolls.Chat, ns.Rolls.Model
		Chat.Reset()
		Model.Clear()
		Test.SetUnits({
			player = { name = "Tester", class = "WARRIOR", level = 30, guid = Test.state.playerGUID },
			party1 = { name = "Orlen Brightmoor", class = "MAGE", level = 41, guid = "g-orlen" },
			party2 = { name = "Brina", class = "ROGUE", level = 35, guid = "g-brina" },
		})
		Test.state.rolls[7] = { rollID = 7, name = "Mail Helm", link = HELM }
		Model.AddRoll(7)
	end)

	it("builds patterns from the game's strings, numbered arguments too", function()
		local pattern, args = Chat.Pattern("Need Roll - %d for %s by %s")
		assert.equals("^Need Roll %- (%-?%d+) for (.+) by (.+)$", pattern)
		assert.same({ 1, 2, 3 }, args)
		pattern, args = Chat.Pattern("%3$s: %1$d (%2$s)")
		assert.equals("^(.+): (%-?%d+) %((.+)%)$", pattern)
		assert.same({ 3, 1, 2 }, args)
	end)

	it("reads what a line tells: a choice, a roll, a win, all passed", function()
		assert.same({ state = 0, name = "Brina", item = HELM }, Chat.Read("Brina has selected Need for: " .. HELM))
		assert.same({ state = 0, roll = 87, item = HELM, name = "Orlen-Brightmoor" }, Chat.Read("Need Roll - 87 for " .. HELM .. " by Orlen-Brightmoor"))
		assert.same({ won = true, name = "Brina", item = HELM }, Chat.Read("Brina won: " .. HELM))
		-- The lines with fewer names come first: these are not "Everyone" and "You" by name.
		assert.same({ allPassed = true, item = HELM }, Chat.Read("Everyone passed on: " .. HELM))
		assert.same({ won = true, self = true, item = HELM }, Chat.Read("You won: " .. HELM))
		assert.same({ state = 0, self = true, item = HELM }, Chat.Read("You have selected Need for: " .. HELM))
		assert.is_nil(Chat.Read("Brina receives loot: " .. HELM))
		assert.is_nil(Chat.Read({ secret = true }))
	end)

	it("reads a translation that puts its arguments in another order", function()
		Test.SetGlobalStrings({ LOOT_ROLL_ROLLED_NEED = "%3$s: «Мне это нужно» %1$d за %2$s" })
		Chat.Reset()
		assert.same({ state = 0, roll = 55, item = HELM, name = "Брина" }, Chat.Read("Брина: «Мне это нужно» 55 за " .. HELM))
	end)

	it("stands in for a roll only once it has waited without its drop, with every member and what the lines told", function()
		Chat.Hear("Brina has selected Need for: " .. HELM)
		assert.is_false(Chat.Use(7))
		Test.state.time = 2
		assert.is_true(Chat.Use(7))
		local view = Model.View(7)
		assert.is_true(view.bound)
		assert.same({ "Brina", 0, "ROGUE", 35, "g-brina" }, { view.players[1].name, view.players[1].state, view.players[1].class,
			view.players[1].level, view.players[1].guid })
		assert.equals(3, #view.players)
		-- Later lines change it; a name written with a hyphen is the member's.
		Chat.Hear("Orlen-Brightmoor has selected Greed for: " .. HELM)
		Chat.Hear("You have selected Need for: " .. HELM)
		Chat.Hear("Need Roll - 87 for " .. HELM .. " by Brina")
		view = Model.View(7)
		local byName = {}
		for _, player in ipairs(view.players) do
			byName[player.name] = player
		end
		assert.same({ 3, "MAGE" }, { byName["Orlen Brightmoor"].state, byName["Orlen Brightmoor"].class })
		assert.same({ 0, true }, { byName.Tester.state, byName.Tester.isSelf })
		assert.equals(87, byName.Brina.roll)
		Chat.Hear("Brina won: " .. HELM)
		assert.equals("Brina", Model.View(7).winner.name)
	end)

	it("gives way to the loot history's drop when it comes", function()
		Test.state.time = 3
		Chat.Use(7)
		Test.state.lootDrops = { { encounterID = 1, listID = 2, link = HELM, rolls = { { name = "Corvin", guid = "g-c", class = "MAGE", state = 3 } } } }
		Model.UpdateDrop(1, 2)
		assert.equals("1:2", Model.Roll(7).drop)
		Chat.Hear("Brina has selected Need for: " .. HELM)
		assert.equals("Corvin", Model.View(7).players[1].name)
	end)
end)
