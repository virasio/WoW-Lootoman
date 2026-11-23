local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

-- Rolling in the Loot Rolls window while the game's roll frames are kept
-- away (Modules/Rolls/LiveWindow.lua): the rolls to choose on on top, with
-- our buttons and a timer; the rest under a line.

local function link(id, name)
	return ("|cff1eff00|Hitem:%d::::::::40|h[%s]|h|r"):format(id, name)
end

local HELM, RING, BOOTS = link(100, "Mail Helm"), link(200, "Ring"), link(300, "Boots")
local QUESTION = "Rolls are waiting for your choice; untouched, they end as a pass. Close the window?"

describe("rolling in the Loot Rolls window", function()
	local ns, Test, LiveWindow, window, settings

	local function start(saved, before)
		settings = SettingsAPI.Install()
		ns = Loader.LoadAddon({ gameType = "camelot", skip = {} })
		Test = ns.Compat.Test
		Test.state.gameRollFrames = {}
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
		window = LiveWindow.Frame()
		ns.Rolls.Groups.Joined(1, "Party-1")
	end

	local function roll(rollID, itemLink, name)
		Test.StartRoll(rollID, { name = name, link = itemLink, quality = 2, canNeed = true, canGreed = true })
	end

	-- The shown rows, top to bottom: the item's name and whether it has buttons.
	local function rows()
		local list = {}
		for index = 1, window.count or 0 do
			local row = window.rows[index]
			local name = row.item.name:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			list[index] = { name, row.buttons[1]:IsShown() }
		end
		return list
	end

	local function click(index, choice)
		local button = window.rows[index].buttons[choice]
		button.scripts.OnClick(button)
	end

	before_each(function()
		start()
		ns.Storage:Set("Rolls", "hideGameFrames", true)
	end)

	it("opens as a roll starts, whatever its option says, with the roll on top, its buttons and its timer", function()
		ns.Storage:Set("Rolls", "liveWindow", false)
		Test.state.rollTimes = { [7] = 45000 }
		roll(7, HELM, "Mail Helm")
		assert.is_true(window:IsShown())
		assert.same({ { "Mail Helm", true } }, rows())
		local row = window.rows[1]
		assert.same({ true, 0.75 }, { row.timer:IsShown(), row.timer:GetValue() })
		-- The timer moves while the window is open.
		Test.state.rollTimes[7] = 30000
		Test.Advance(LiveWindow.TICK)
		assert.equals(0.5, row.timer:GetValue())
	end)

	it("puts a new roll on top, and a chosen one under the line once the game ends it for the player, its timer going on", function()
		roll(7, HELM, "Mail Helm")
		roll(8, BOOTS, "Boots")
		assert.same({ { "Boots", true }, { "Mail Helm", true } }, rows())
		assert.is_false(window.line:IsShown())
		Test.Advance(LiveWindow.GUARD)
		click(2, 1)
		assert.same({ 7, 1 }, Test.state.rolledOn[#Test.state.rolledOn])
		-- Until the game ends it (a need on an item that binds waits for the
		-- game's question), it stays on top with its buttons.
		assert.same({ { "Boots", true }, { "Mail Helm", true } }, rows())
		Test.CancelRoll(7)
		assert.same({ { "Boots", true }, { "Mail Helm", false } }, rows())
		assert.is_true(window.line:IsShown())
		assert.is_true(window.rows[2].timer:IsShown())
		-- A drop the player had no roll for joins the rest.
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = RING, rolls = {} })
		assert.same({ { "Boots", true }, { "Ring", false }, { "Mail Helm", false } }, rows())
		-- Over, the timer goes.
		Test.Advance(61)
		ns.Rolls.Module.RedrawAll()
		assert.is_false(window.rows[3].timer:IsShown())
	end)

	it("fills a chosen row from its drop when the drop comes after the game ended the roll", function()
		roll(7, HELM, "Mail Helm")
		Test.Advance(LiveWindow.GUARD)
		click(1, 2)
		Test.CancelRoll(7)
		assert.same({ { "Mail Helm", false } }, rows())
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = HELM, rolls = { { name = "Brina", guid = "g-brina", class = "MAGE", state = 4 } } })
		assert.same({ { "Mail Helm", false } }, rows())
		assert.matches("Brina", window.rows[1].panel.lines[1].text:GetText())
	end)

	it("lets no click land on a row that has just moved", function()
		roll(7, HELM, "Mail Helm")
		Test.Advance(LiveWindow.GUARD)
		roll(8, BOOTS, "Boots")
		local before = #(Test.state.rolledOn or {})
		click(1, 1)
		assert.equals(before, #(Test.state.rolledOn or {}))
		Test.Advance(LiveWindow.GUARD)
		click(1, 2)
		assert.same({ 8, 2 }, Test.state.rolledOn[#Test.state.rolledOn])
	end)

	it("takes a click on a row the one above pushed down a line, but not on one pushed past its item's height", function()
		roll(7, HELM, "Mail Helm")
		roll(8, BOOTS, "Boots")
		Test.Advance(LiveWindow.GUARD)
		local y = window.rows[2].y
		-- The top row's panel fills: two lines instead of the waiting one.
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = BOOTS, rolls = {
			{ name = "Brina", guid = "g-brina", class = "MAGE", state = 4 }, { name = "Tester", guid = Test.state.playerGUID, class = "WARRIOR", state = 4 } } })
		assert.equals(y + ns.Rolls.Panel.LINE, window.rows[2].y)
		click(2, 2)
		assert.same({ 7, 2 }, Test.state.rolledOn[#Test.state.rolledOn])
		-- Five lines: pushed more than its item's height.
		local players = {}
		for index = 1, 5 do
			players[index] = { name = "P" .. index, guid = "g-p" .. index, class = "MAGE", state = 4 }
		end
		roll(9, RING, "Ring")
		Test.Advance(LiveWindow.GUARD)
		Test.SetLootDrop({ encounterID = 1, listID = 3, link = RING, rolls = players })
		local before = #Test.state.rolledOn
		click(2, 1)
		assert.equals(before, #Test.state.rolledOn)
	end)

	it("keeps a row's buttons shown and in place as it is drawn again, so a press under way is not dropped", function()
		roll(7, HELM, "Mail Helm")
		local button = window.rows[1].buttons[2]
		local hidden, moved = 0, 0
		local setShown, clear = button.SetShown, button.ClearAllPoints
		button.SetShown = function(self, shown)
			if not shown then
				hidden = hidden + 1
			end
			setShown(self, shown)
		end
		button.ClearAllPoints = function(self)
			moved = moved + 1
			clear(self)
		end
		ns.Rolls.Module.RedrawAll()
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = HELM, rolls = { { name = "Brina", guid = "g-brina", class = "MAGE", state = 4 } } })
		assert.same({ 0, 0, true }, { hidden, moved, button:IsShown() })
	end)

	it("asks before closing while a roll waits, comes back to ask after Escape, and closes at once without one", function()
		roll(7, HELM, "Mail Helm")
		window.close.scripts.OnClick(window.close)
		local popup = settings.popups[#settings.popups]
		assert.same({ "GENERIC_CONFIRMATION", QUESTION, "Close" }, { popup.which, popup.data.text, popup.data.acceptText })
		-- Cancel: nothing happens, the window stays.
		assert.is_true(window:IsShown())
		popup.data.callback()
		assert.is_false(window:IsShown())
		-- The next roll opens it with every roll still waiting.
		roll(8, BOOTS, "Boots")
		assert.same({ { "Boots", true }, { "Mail Helm", true } }, rows())
		local count = #settings.popups
		Loader.ui.PressEscape()
		Test.Advance(0)
		assert.is_true(window:IsShown())
		assert.same({ count + 1, QUESTION }, { #settings.popups, settings.popups[#settings.popups].data.text })
		assert.equals(2, window.count)
		Test.CancelRoll(7)
		Test.CancelRoll(8)
		count = #settings.popups
		window.close.scripts.OnClick(window.close)
		assert.same({ false, count }, { window:IsShown(), #settings.popups })
	end)

	it("closes without asking as the loot rolls turn off", function()
		roll(7, HELM, "Mail Helm")
		local count = #settings.popups
		ns.Modules:SetEnabled("Rolls", false)
		Test.Advance(0)
		assert.is_false(window:IsShown())
		-- Only the reload's question: the game's frames are away.
		assert.equals(count + 1, #settings.popups)
		assert.matches("reload", settings.popups[#settings.popups].data.text)
	end)

	it("takes in a roll open before a reload as the loot rolls start", function()
		start({ LootomanDB = Test.state.saved.LootomanDB }, function()
			Test.state.rolls[9] = { rollID = 9, name = "Ring", link = RING, quality = 2, canNeed = true, canGreed = true }
		end)
		assert.is_true(window:IsShown())
		assert.same({ { "Ring", true } }, rows())
	end)

	it("looks as before with the game's frames shown: opens at the choice, no buttons, no timer, no line", function()
		start()
		roll(7, HELM, "Mail Helm")
		assert.is_false(window:IsShown())
		Test.ChooseRoll(7, 2)
		Test.Advance(LiveWindow.WAIT)
		assert.same({ { "Mail Helm", false } }, rows())
		assert.same({ false, false }, { window.rows[1].timer:IsShown(), window.line:IsShown() })
	end)
end)

-- The made-up rows of the demo choose through their own views.
describe("a made-up row to choose on", function()
	it("calls its view's own choice and runs its own timer", function()
		local ns = Loader.LoadAddon({ gameType = "camelot" })
		Loader.Start(ns)
		local chosen, share = {}, 0.8
		local view = { link = HELM, bound = false, players = {}, item = { canNeed = true, canGreed = true }, choosable = true,
			timer = share, timeShare = function() return share end, onChoose = function(rollType) chosen[#chosen + 1] = rollType end }
		assert.is_true(ns.Rolls.LiveWindow.AddView(view))
		local window = ns.Rolls.LiveWindow.Frame()
		ns.Compat.Test.Advance(ns.Rolls.LiveWindow.GUARD)
		local button = window.rows[1].buttons[4]
		button.scripts.OnClick(button)
		assert.same({ 0 }, chosen)
		share = 0.4
		ns.Compat.Test.Advance(ns.Rolls.LiveWindow.TICK)
		assert.equals(0.4, window.rows[1].timer:GetValue())
	end)
end)
