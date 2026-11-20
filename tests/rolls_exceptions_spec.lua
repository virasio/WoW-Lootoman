local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- Exceptions: the right click on a marked need, and the Suspicious Needs
-- window on leaving a group (Modules/Rolls/SuspiciousNeeds.lua).

local MAIL = "|cff1eff00|Hitem:100::::::::40|h[Mail Helm]|h|r"
local ITEMS = {
	[100] = { name = "Mail Helm", link = MAIL, quality = 2, classID = 4, subclassID = 3, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = {} },
}

describe("exceptions", function()
	local ns, Test, Rolls, frames, list

	before_each(function()
		ns = Loader.LoadAddon({ gameType = "camelot", debug = true })
		Test = ns.Compat.Test
		frames = {}
		for index = 1, 4 do
			frames[index] = UI.NewFake(Loader.ui.UIParent)
			frames[index]:Hide()
		end
		Test.state.gameRollFrames = frames
		Test.SetItems(ITEMS)
		Test.state.group = true
		Test.SetUnits({ player = { name = "Tester", class = "WARRIOR", level = 30, guid = Test.state.playerGUID } })
		Loader.Start(ns)
		Rolls = ns.Rolls.Module
		ns.Storage:Set("Rolls", "ninja", true)
		list = 0
	end)

	local function player(name, class, state, guid)
		return { name = name, guid = guid or ("g-" .. name:lower()), class = class, state = state, roll = 50 }
	end

	local function roll(players)
		list = list + 1
		Test.StartRoll(list, { name = "Mail Helm", link = MAIL, quality = 2 })
		frames[1].rollID = list
		frames[1]:Hide()
		frames[1]:Show()
		Test.SetLootDrop({ encounterID = 1, listID = list, link = MAIL, rolls = players })
		return Rolls.PanelOf(frames[1])
	end

	local function lineOf(panel, name)
		for _, each in ipairs(panel.lines) do
			if each.player and each.player.name == name then
				return each
			end
		end
	end

	local function rightClick(owner)
		Loader.ui.contextMenu = nil
		owner.scripts.OnClick(owner, "RightButton")
		return Loader.ui.contextMenu
	end

	it("excuses a marked need from its right click, and takes it back", function()
		local panel = roll({ player("Brina", "MAGE", 0), player("Torg", "WARRIOR", 3) })
		assert.is_nil(rightClick(lineOf(panel, "Torg")))
		local menu = rightClick(lineOf(panel, "Brina"))
		assert.equals("Exception: Agreed in the Chat", menu.entries[1].text)
		menu.entries[1].callback()
		local brina = lineOf(Rolls.PanelOf(frames[1]), "Brina")
		assert.matches("ReadyCheck", brina.text:GetText())
		assert.is_true(ns.Rolls.History.Open().drops[1].rolls[1].excused)
		menu = rightClick(brina)
		assert.equals("Undo the Exception", menu.entries[1].text)
		menu.entries[1].callback()
		assert.matches("RaidTargetingIcon", lineOf(Rolls.PanelOf(frames[1]), "Brina").text:GetText())
	end)

	it("lets an excused need count nowhere: not towards needing nearly everything", function()
		for _ = 1, 3 do
			roll({ player("Corvin", "WARRIOR", 0) })
		end
		local panel = roll({ player("Corvin", "WARRIOR", 0) })
		local notes = lineOf(panel, "Corvin").player.notes
		assert.equals("Needed 4 of 4 items in this group", notes[#notes])
		local group = ns.Rolls.History.Open()
		ns.Rolls.History.SetExcused(group, group.drops[1].key, "g-corvin", true)
		ns.Rolls.Marks.Invalidate()
		Rolls.RedrawAll()
		assert.is_nil(lineOf(Rolls.PanelOf(frames[1]), "Corvin").player.mark)
	end)

	it("lists the group's marked needs on leaving it, each with its exception", function()
		roll({ player("Brina", "MAGE", 0), player("Torg", "WARRIOR", 3) })
		Test.state.group = false
		Test.FireEvent("GROUP_LEFT", 1, "Party-1")
		local window = ns.Rolls.SuspiciousNeeds.Frame()
		assert.same({ true, "Suspicious Needs", 1 }, { window.shown, window.title, window.count })
		local row = window.rows[1]
		assert.matches("Brina", row.who:GetText())
		assert.equals(MAIL, row.item:GetText())
		assert.equals("Mail: not a Mage's armor", row.reasons:GetText())
		row.exception:SetChecked(true)
		row.exception.scripts.OnClick(row.exception)
		local group = ns.Rolls.History.Groups()[#ns.Rolls.History.Groups()]
		assert.is_true(group.drops[1].rolls[1].excused)
		assert.same({ "Excused", true }, { window.rows[1].reasons:GetText(), window.rows[1].exception:GetChecked() })
		assert.is_true(Loader.ui.PressEscape())
	end)

	it("opens no window without marked needs, with its checkbox off, or with the detection off", function()
		roll({ player("Torg", "WARRIOR", 3) })
		Test.FireEvent("GROUP_LEFT", 1, "Party-1")
		assert.is_nil(ns.Rolls.SuspiciousNeeds.Frame())
		ns.Rolls.Groups.Joined(1, "Party-2")
		roll({ player("Brina", "MAGE", 0) })
		ns.Storage:Set("Rolls", "summary", false)
		Test.FireEvent("GROUP_LEFT", 1, "Party-2")
		assert.is_nil(ns.Rolls.SuspiciousNeeds.Frame())
	end)

	it("waits for the end of a fight to open", function()
		roll({ player("Brina", "MAGE", 0) })
		Test.SetCombat(true)
		Test.FireEvent("GROUP_LEFT", 1, "Party-1")
		assert.is_nil(ns.Rolls.SuspiciousNeeds.Frame())
		Test.SetCombat(false)
		assert.is_true(ns.Rolls.SuspiciousNeeds.Frame().shown)
		-- It no longer waits for a fight's end.
		for _, event in ipairs(ns.Bus:GetEvents(Rolls)) do
			assert.not_equals("PLAYER_REGEN_ENABLED", event)
		end
	end)

	it("shows the demo's marked needs when its made-up group leaves, its exceptions only the demo's", function()
		Test.state.worn = { [1] = MAIL }
		ns.Rolls.Demo.Start()
		-- The demo waits a moment for its own items first, then takes worn gear.
		Test.Advance(ns.Rolls.Demo.WAIT * ns.Rolls.Demo.TRIES + ns.Rolls.Demo.LENGTH + ns.Rolls.Demo.STEP)
		local window = ns.Rolls.SuspiciousNeeds.Frame()
		assert.is_true(window.shown)
		assert.is_true(window.count >= 1)
		local before = #ns.Rolls.History.Open().drops
		window.rows[1].exception:SetChecked(true)
		window.rows[1].exception.scripts.OnClick(window.rows[1].exception)
		assert.is_true(window.rows[1].exception:GetChecked())
		assert.equals(before, #ns.Rolls.History.Open().drops)
	end)
end)
