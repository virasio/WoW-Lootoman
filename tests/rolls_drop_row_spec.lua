local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- A drop as a row of the loot rolls' windows (Modules/Rolls/DropRow.lua).

local function link(id, name, color)
	return ("|cff%s|Hitem:%d::::::::40|h[%s]|h|r"):format(color or "1eff00", id, name)
end

local MAIL = link(100, "Mail Helm")
local RING = link(200, "Ring", "0070dd")
local ITEMS = {
	[100] = { name = "Mail Helm", link = MAIL, quality = 2, icon = 1001, classID = 4, subclassID = 3, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = {} },
}

describe("a drop's row", function()
	local ns, Test, DropRow, Model, row

	before_each(function()
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		Test.SetGlobalStrings({ NEED = "Need", GREED = "Greed", PASS = "Pass" })
		Test.SetItems(ITEMS)
		Test.state.group = true
		Test.SetUnits({
			player = { name = "Tester", class = "WARRIOR", level = 30, guid = Test.state.playerGUID },
			party1 = { name = "Brina", class = "MAGE", level = 30, guid = "g-brina" },
		})
		Loader.Start(ns)
		DropRow, Model = ns.Rolls.DropRow, ns.Rolls.Model
		row = DropRow.New(UI.NewFake(Loader.ui.UIParent))
	end)

	local function player(name, class, state, number, extra)
		local entry = { name = name, guid = "g-" .. name:lower(), class = class, state = state, roll = number }
		for key, value in pairs(extra or {}) do
			entry[key] = value
		end
		return entry
	end

	local function shownTexts()
		local list = {}
		for _, line in ipairs(row.panel.lines) do
			if line:IsShown() then
				list[#list + 1] = line.text:GetText()
			end
		end
		return list
	end

	it("shows the item, its roll going on, and the panel's lines beside it in the row", function()
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = MAIL, rolls = { player("Brina", "MAGE", 4), player("Tester", "WARRIOR", 3, 40) } })
		local height = DropRow.Draw(row, DropRow.Marked(Model.DropView("1:1")))
		assert.same({ 1001, "|cff1eff00Mail Helm|r", "Rolling…" }, { row.item.icon.texture, row.item.name:GetText(), row.item.status:GetText() })
		-- The panel is the row's own, at the item's right, and the row is as tall as it.
		assert.equals(row.frame, row.panel.frame.parent)
		assert.same({ "LEFT", row.item, "RIGHT", 4, 0 }, row.panel.frame.points[1])
		assert.equals(2, #shownTexts())
		assert.same({ 48, 48, 48 }, { height, row.frame:GetHeight(), row.item:GetHeight() })
		-- A taller panel makes a taller row.
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = MAIL, rolls = { player("Brina", "MAGE", 4), player("Tester", "WARRIOR", 3, 40),
			player("Corvin", "ROGUE", 4), player("Dathra", "PRIEST", 4) } })
		assert.equals(2 * 6 + 4 * 15, DropRow.Draw(row, Model.DropView("1:1"), "14:05, The Deadmines"))
		assert.equals("14:05, The Deadmines", row.item.note:GetText())
		-- Its tooltip, and Shift-click to link it.
		row.item.scripts.OnEnter(row.item)
		assert.equals(MAIL, Loader.ui.tooltip.link)
		Test.state.modifiers.CHATLINK = true
		row.item.scripts.OnClick(row.item)
		assert.same({ MAIL }, Test.state.linked)
	end)

	it("says who won, with their button's icon and roll, or that all passed", function()
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = MAIL, rolls = { player("Brina", "MAGE", 3, 87, { isWinner = true }) },
			winner = player("Brina", "MAGE", 3, 87) })
		DropRow.Draw(row, Model.DropView("1:1"))
		assert.matches("^|A:lootroll%-toast%-icon%-greed%-up:14:14|a |c%x+Brina|r 87$", row.item.status:GetText())
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = MAIL, rolls = { player("Brina", "MAGE", 5) }, allPassed = true })
		DropRow.Draw(row, Model.DropView("1:2"))
		assert.equals("All passed", row.item.status:GetText())
	end)

	it("draws a raid's roll in the panel's short lines", function()
		local rolls = {}
		for index = 1, 8 do
			rolls[index] = player("Raider" .. index, "HUNTER", 4)
		end
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = MAIL, rolls = rolls })
		DropRow.Draw(row, Model.DropView("1:1"))
		local shown = shownTexts()
		assert.same({ 4, "Need: 0", "Not chosen: 8" }, { #shown, shown[2], shown[4] })
	end)

	it("marks a need against the rules with the detection on, and none with it off", function()
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = MAIL, rolls = { player("Brina", "MAGE", 0, 50) } })
		DropRow.Draw(row, DropRow.Marked(Model.DropView("1:1")))
		assert.is_nil(row.panel.lines[1].text:GetText():find("RaidTargetingIcon", 1, true))
		ns.Storage:Set("Rolls", "ninja", true)
		DropRow.Draw(row, DropRow.Marked(Model.DropView("1:1")))
		assert.is_truthy(row.panel.lines[1].text:GetText():find("RaidTargetingIcon", 1, true))
	end)

	it("shows an item the game has not loaded under a question mark, asks for it, and its icon once it came", function()
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = RING, rolls = { player("Brina", "MAGE", 4) } })
		DropRow.Draw(row, Model.DropView("1:1"))
		assert.same({ DropRow.QUESTION, "|cff0070ddRing|r" }, { row.item.icon.texture, row.item.name:GetText() })
		assert.same({ 200 }, Test.state.requested)
		Test.SetItems({ [200] = { name = "Ring", link = RING, quality = 3, icon = 2002 } })
		DropRow.Draw(row, Model.DropView("1:1"))
		assert.equals(2002, row.item.icon.texture)
	end)

	it("draws a kept drop of the history: the winner, the player's own line, an excused need", function()
		local entry = { key = "1:1", link = MAIL, winner = "g-brina", rolls = {
			{ guid = "g-brina", name = "Brina", class = "MAGE", state = 0, roll = 90, excused = true },
			{ guid = Test.state.playerGUID, name = "Tester", class = "WARRIOR", state = 3, roll = 20 },
		} }
		local view = DropRow.EntryView(entry, { drops = { entry } })
		assert.same({ true, false, true }, { view.players[1].isWinner, view.players[1].isSelf, view.players[2].isSelf })
		assert.same({ guid = "g-brina", name = "Brina", class = "MAGE" }, view.winner)
		ns.Storage:Set("Rolls", "ninja", true)
		DropRow.Draw(row, DropRow.Marked(view, view.group))
		assert.matches("Brina", row.item.status:GetText())
		assert.is_truthy(row.panel.lines[1].text:GetText():find("ReadyCheck-Ready", 1, true))
		assert.is_true(row.panel.lines[2].self:IsShown())
		DropRow.Hide(row)
		assert.same({ false, false }, { row.frame:IsShown(), row.panel.frame:IsShown() })
	end)

	it("puts the panel under the item in the narrow layout, as wide as the panel and a little indent", function()
		local narrow = DropRow.New(UI.NewFake(Loader.ui.UIParent), "below")
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = MAIL, rolls = { player("Brina", "MAGE", 4), player("Tester", "WARRIOR", 3, 40) } })
		local height = DropRow.Draw(narrow, Model.DropView("1:1"))
		assert.same({ "TOPLEFT", narrow.frame, "TOPLEFT", DropRow.INDENT, -(DropRow.BELOW_ITEM + 2) }, narrow.panel.frame.points[#narrow.panel.frame.points])
		assert.same({ DropRow.BELOW_WIDTH, DropRow.BELOW_ITEM }, { narrow.item:GetWidth(), narrow.item:GetHeight() })
		assert.equals(DropRow.BELOW_ITEM + 2 + 2 * 6 + 2 * 15, height)
		assert.equals(200, narrow.frame:GetWidth())
		-- The wide row keeps its panel at the item's right.
		DropRow.Draw(row, Model.DropView("1:1"))
		assert.same({ "LEFT", row.item, "RIGHT", 4, 0 }, row.panel.frame.points[1])
	end)

	-- A roll to choose on: its view as the window gives it.
	local function choosable(item, timer)
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = MAIL, rolls = { player("Brina", "MAGE", 4) } })
		local view = Model.DropView("1:1")
		view.rollID, view.item, view.choosable, view.timer = 7, item, true, timer
		return view
	end

	local function shownButtons(narrow)
		local list = {}
		for _, button in ipairs(narrow.buttons) do
			if button:IsShown() then
				list[#list + 1] = { button.choice.atlas, button:IsEnabled() }
			end
		end
		return list
	end

	it("gives a roll to choose on our buttons under the item and a timer, the panel under them", function()
		Test.SetGlobalStrings({ NEED = "Need", GREED = "Greed", PASS = "Pass", LOOT_ROLL_INELIGIBLE_REASON2 = "Your class may not roll need on this item." })
		local narrow = DropRow.New(UI.NewFake(Loader.ui.UIParent), "below")
		local chosen = {}
		narrow.onChoose = function(view, rollType) chosen[#chosen + 1] = { view.rollID, rollType } end
		local height = DropRow.Draw(narrow, choosable({ canNeed = false, canGreed = true, canTransmog = false, reasonNeed = 2 }, 0.5))
		-- Need greyed with the game's reason; no transmog on this roll.
		assert.same({ { "need", false }, { "greed", true }, { "pass", true } }, shownButtons(narrow))
		narrow.buttons[1].scripts.OnEnter(narrow.buttons[1])
		assert.same({ "Need", "Your class may not roll need on this item." }, Loader.ui.tooltip.lines)
		assert.same({ true, 0.5 }, { narrow.timer:IsShown(), narrow.timer:GetValue() })
		local y = DropRow.BELOW_ITEM + 2 + DropRow.BUTTON + 2 + DropRow.TIMER + 2
		assert.same({ "TOPLEFT", narrow.frame, "TOPLEFT", DropRow.INDENT, -y }, narrow.panel.frame.points[#narrow.panel.frame.points])
		assert.equals(y + 2 * 6 + 15, height)
		-- Each button rolls with RollOnLoot's type.
		narrow.buttons[2].scripts.OnClick(narrow.buttons[2])
		narrow.buttons[4].scripts.OnClick(narrow.buttons[4])
		assert.same({ { 7, 2 }, { 7, 0 } }, chosen)
		-- Transmog where the roll offers it.
		DropRow.Draw(narrow, choosable({ canNeed = true, canGreed = true, canTransmog = true }, 0.2))
		assert.same({ { "need", true }, { "greed", true }, { "transmog", true }, { "pass", true } }, shownButtons(narrow))
		-- Chosen: the same row without the buttons, the timer still running.
		local view = choosable({ canNeed = true, canGreed = true }, 0.1)
		view.choosable = nil
		DropRow.Draw(narrow, view)
		assert.same({ {}, true }, { shownButtons(narrow), narrow.timer:IsShown() })
		DropRow.SetTimer(narrow, 0.05)
		assert.equals(0.05, narrow.timer:GetValue())
	end)

	it("draws a plain row with the buttons when the full one fails, and reports the error", function()
		local narrow = DropRow.New(UI.NewFake(Loader.ui.UIParent), "below")
		local view = choosable({ canNeed = true, canGreed = true }, 0.5)
		view.players = "broken"
		DropRow.Draw(narrow, view)
		assert.same({ { "need", true }, { "greed", true }, { "pass", true } }, shownButtons(narrow))
		assert.same({ false, false }, { narrow.panel.frame:IsShown(), narrow.timer:IsShown() })
		assert.is_true(#Test.state.errors > 0)
	end)

	it("lights a new row for a moment", function()
		DropRow.Light(row)
		assert.is_true(row.light:IsShown())
		Test.Advance(DropRow.LIGHT)
		assert.is_false(row.light:IsShown())
	end)
end)
