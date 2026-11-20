local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- The live window, Loot Rolls, where the game has no loot history window of
-- its own (Modules/Rolls/LiveWindow.lua).

local function link(id, name)
	return ("|cff1eff00|Hitem:%d::::::::40|h[%s]|h|r"):format(id, name)
end

local HELM, RING, BOOTS = link(100, "Mail Helm"), link(200, "Ring"), link(300, "Boots")

describe("the live window", function()
	local ns, Test, LiveWindow, frames

	local function start(saved, before)
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		frames = {}
		for index = 1, 4 do
			frames[index] = UI.NewFake(Loader.ui.UIParent)
			frames[index]:Hide()
		end
		Test.state.gameRollFrames = frames
		Test.SetGlobalStrings({ NEED = "Need", GREED = "Greed", PASS = "Pass", LOOT_ROLLS = "Loot Rolls" })
		Test.SetGroup(true)
		Test.SetUnits({
			player = { name = "Tester", class = "WARRIOR", level = 30, guid = Test.state.playerGUID },
			party1 = { name = "Brina", class = "MAGE", level = 30, guid = "g-brina" },
		})
		if before then
			before()
		end
		Loader.Start(ns, saved)
		LiveWindow = ns.Rolls.LiveWindow
		ns.Rolls.Groups.Joined(1, "Party-1")
	end

	local function player(name, class, state, number)
		return { name = name, guid = "g-" .. name:lower(), class = class, state = state, roll = number }
	end

	-- The items of the shown rows, top to bottom.
	local function items()
		local list = {}
		local window = LiveWindow.Frame()
		for index = 1, window.count or 0 do
			list[index] = window.rows[index].item.name:GetText()
		end
		return list
	end

	before_each(function()
		start()
	end)

	it("opens at the player's choice, a pass too, with that roll at the top and the group's other rolls going", function()
		local window = LiveWindow.Frame()
		assert.same({ false, "Loot Rolls", "LootomanLootRolls" }, { window:IsShown(), window.title, window.name })
		Test.StartRoll(7, { name = "Mail Helm", link = HELM, quality = 2 })
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = HELM, rolls = { player("Brina", "MAGE", 4), player("Tester", "WARRIOR", 4) } })
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = RING, rolls = { player("Brina", "MAGE", 0, 50) } })
		Test.SetLootDrop({ encounterID = 1, listID = 3, link = BOOTS, rolls = { player("Brina", "MAGE", 5) }, allPassed = true })
		Test.ChooseRoll(7, 0)
		assert.is_true(window:IsShown())
		-- The finished drop before it opened is not taken in.
		assert.same({ "|cff1eff00Mail Helm|r", "|cff1eff00Ring|r" }, items())
		assert.is_true(window.rows[1].light:IsShown())
		-- Each row's panel is its own, with the drop's choices.
		assert.equals(window.rows[2].frame, window.rows[2].panel.frame.parent)
		assert.matches("Brina", window.rows[2].panel.lines[1].text:GetText())
	end)

	it("takes in drops new since it opened, newest first, follows their choices, and forgets them when closed", function()
		local window = LiveWindow.Frame()
		Test.StartRoll(7, { name = "Mail Helm", link = HELM, quality = 2 })
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = HELM, rolls = { player("Brina", "MAGE", 4) } })
		Test.ChooseRoll(7, 3)
		Test.SetLootDrop({ encounterID = 2, listID = 1, link = RING, rolls = { player("Brina", "MAGE", 4) } })
		assert.same({ "|cff1eff00Ring|r", "|cff1eff00Mail Helm|r" }, items())
		Test.SetLootDrop({ encounterID = 2, listID = 1, link = RING, rolls = { player("Brina", "MAGE", 0, 61) } })
		assert.equals("61", window.rows[1].panel.lines[1].roll:GetText())
		-- A second choice while it is open adds nothing twice.
		Test.ChooseRoll(7, 3)
		assert.equals(2, window.count)
		Loader.ui.PressEscape()
		assert.is_false(window:IsShown())
		-- The next choice opens it with that roll alone (the others are over).
		Test.SetLootDrop({ encounterID = 2, listID = 1, link = RING, rolls = { player("Brina", "MAGE", 0, 61) }, winner = player("Brina", "MAGE", 0, 61) })
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = HELM, rolls = { player("Brina", "MAGE", 5) }, allPassed = true })
		Test.StartRoll(8, { name = "Boots", link = BOOTS, quality = 2 })
		Test.ChooseRoll(8, 0)
		assert.same({ "|cff1eff00Boots|r" }, items())
	end)

	it("keeps its rows as they were after the game clears its loot history", function()
		local window = LiveWindow.Frame()
		Test.StartRoll(7, { name = "Mail Helm", link = HELM, quality = 2 })
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = HELM, rolls = { player("Brina", "MAGE", 0, 44) } })
		Test.ChooseRoll(7, 5)
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = HELM, rolls = { player("Brina", "MAGE", 0, 44) }, winner = player("Brina", "MAGE", 0, 44) })
		Test.FireEvent("LOOT_HISTORY_CLEAR_HISTORY")
		-- The roll is still open, its drop gone: the history draws it.
		assert.matches("Brina|r 44$", window.rows[1].item.status:GetText())
		Test.FireEvent("CANCEL_LOOT_ROLL", 7)
		assert.same({ "|cff1eff00Mail Helm|r" }, items())
		assert.matches("Brina|r 44$", window.rows[1].item.status:GetText())
	end)

	it("stays closed with its option off", function()
		ns.Storage:Set("Rolls", "liveWindow", false)
		Test.StartRoll(7, { name = "Mail Helm", link = HELM, quality = 2 })
		Test.ChooseRoll(7, 0)
		assert.is_false(LiveWindow.Frame():IsShown())
	end)

	it("never exists where the game has its own loot history window, nor while the loot rolls are off", function()
		start(nil, function()
			Test.state.gameLootHistory = true
		end)
		assert.is_nil(LiveWindow.Frame())
		Test.StartRoll(7, { name = "Mail Helm", link = HELM, quality = 2 })
		Test.ChooseRoll(7, 0)
		assert.is_nil(LiveWindow.Frame())
		start({ LootomanDB = { schema = 4, profiles = { Default = { modules = { Rolls = { enabled = false } } } } } })
		assert.is_nil(LiveWindow.Frame())
	end)

	it("closes as the loot rolls turn off", function()
		Test.StartRoll(7, { name = "Mail Helm", link = HELM, quality = 2 })
		Test.ChooseRoll(7, 0)
		ns.Modules:SetEnabled("Rolls", false)
		assert.is_false(LiveWindow.Frame():IsShown())
	end)
end)

describe("the live window's option", function()
	local function page(before)
		local SettingsAPI = require("tests.mocks.SettingsAPI")
		SettingsAPI.Install()
		local ns = Loader.LoadAddon({ gameType = "camelot", skip = {} })
		if before then
			before(ns.Compat.Test)
		end
		Loader.Start(ns)
		local labels = {}
		for _, item in ipairs(ns.SettingsPanel.main.items) do
			labels[item.text or ""] = true
		end
		return labels
	end

	it("is on the options page only where the game has no loot history window", function()
		assert.is_true(page()["Show the Loot Rolls Window After Your Choice"])
		assert.is_nil(page(function(Test) Test.state.gameLootHistory = true end)["Show the Loot Rolls Window After Your Choice"])
	end)
end)
