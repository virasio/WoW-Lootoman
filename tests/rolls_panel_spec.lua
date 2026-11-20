local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- The loot rolls module and its panels beside the game's roll frames
-- (Modules/Rolls/Rolls.lua, Panel.lua).

local HELM = "|cff1eff00|Hitem:100::::::::40|h[Mail Helm]|h|r"

describe("the loot rolls' panels", function()
	local ns, Test, Rolls, frames

	local function start(saved, before)
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		frames = {}
		for index = 1, 4 do
			local frame = UI.NewFake(Loader.ui.UIParent)
			frame.name = "GroupLootFrame" .. index
			frame:Hide()
			frames[index] = frame
		end
		Test.state.gameRollFrames = frames
		Test.SetGlobalStrings({ NEED = "Need", GREED = "Greed", PASS = "Pass", TRANSMOGRIFICATION = "Transmogrification" })
		if before then
			before()
		end
		Loader.Start(ns, saved)
		Rolls = ns.Rolls.Module
	end

	local function player(name, class, state, number, extra)
		local entry = { name = name, guid = "g-" .. name, class = class, state = state, roll = number }
		for key, value in pairs(extra or {}) do
			entry[key] = value
		end
		return entry
	end

	local function open(rollID, frame)
		Test.StartRoll(rollID, { name = "Mail Helm", link = HELM, quality = 2 })
		frame.rollID = rollID
		frame:Show()
		return Rolls.PanelOf(frame)
	end

	local function texts(panel)
		local list = {}
		for _, line in ipairs(panel.lines) do
			if line:IsShown() then
				list[#list + 1] = line.text:GetText()
			end
		end
		return list
	end

	before_each(function()
		start()
	end)

	it("shows a panel at the right of a game's roll frame as it shows, waiting for the rolls until its drop comes", function()
		local panel = open(7, frames[1])
		assert.is_true(panel.frame:IsShown())
		assert.same({ "LEFT", frames[1], "RIGHT", 4, 0 }, panel.frame.points[1])
		assert.same({ "Waiting for the rolls…" }, texts(panel))
		frames[1]:Hide()
		assert.is_false(panel.frame:IsShown())
		-- The game's frame only gets hooks: none of its scripts is replaced.
		assert.same({}, frames[1].scripts)
		assert.equals(1, #frames[1].hooks.OnShow)
	end)

	it("stands at the frame's left when the right would run off the screen", function()
		frames[2].GetRight = function() return 1800 end
		Loader.ui.UIParent.GetRight = function() return 1920 end
		local panel = open(8, frames[2])
		assert.same({ "RIGHT", frames[2], "LEFT", -4, 0 }, panel.frame.points[1])
	end)

	it("lists every player of a group in the game's order: choice, roll, the leader, the winner, the player himself", function()
		local panel = open(7, frames[1])
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = HELM, rolls = {
			player("Brina", "MAGE", 0, 87), player("Tester", "WARRIOR", 3, 40, { isSelf = true }), player("Corvin", "ROGUE", 5),
			player("Dathra", "PRIEST", 4),
		}, currentLeader = player("Brina", "MAGE", 0, 87) })
		local lines = panel.lines
		assert.matches("Brina|r$", lines[1].text:GetText())
		assert.same({ "lootroll-toast-icon-need-up", "87", 1, false }, { lines[1].icon.atlas, lines[1].roll:GetText(), lines[1].text:GetAlpha(), lines[1].self:IsShown() })
		assert.same({ "lootroll-toast-icon-greed-up", "40", 0.8, true }, { lines[2].icon.atlas, lines[2].roll:GetText(), lines[2].text:GetAlpha(), lines[2].self:IsShown() })
		assert.same({ "lootroll-toast-icon-pass-up", "" }, { lines[3].icon.atlas, lines[3].roll:GetText() })
		assert.equals("lootroll-pendingdot", lines[4].icon.atlas)
		assert.is_false(lines[5]:IsShown())
		assert.equals(2 * 6 + 4 * 15, panel.frame:GetHeight())
		-- Its tooltip: the name, the choice and the roll.
		lines[1].scripts.OnEnter(lines[1])
		assert.equals("Need: 87", Loader.ui.tooltip.lines[2])
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = HELM, rolls = { player("Brina", "MAGE", 0, 87, { isWinner = true }) },
			winner = player("Brina", "MAGE", 0, 87) })
		assert.is_true(lines[1].winner:IsShown())
	end)

	it("never grows taller than the room the game leaves per frame", function()
		local panel = open(7, frames[1])
		local rolls = {}
		for index = 1, 5 do
			rolls[index] = player("P" .. index, "MAGE", 4)
		end
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = HELM, rolls = rolls })
		assert.is_true(panel.frame:GetHeight() <= 100)
	end)

	it("shows a raid's roll in short lines: the leader, the needs, greed and pass with counts, who has not chosen", function()
		local panel = open(7, frames[1])
		local rolls = { player("Brina", "MAGE", 0, 87), player("Corvin", "ROGUE", 0, 30), player("Dathra", "PRIEST", 3), player("Elric", "WARRIOR", 5) }
		for index = 1, 6 do
			rolls[#rolls + 1] = player("Raider" .. index, "HUNTER", 4)
		end
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = HELM, rolls = rolls, currentLeader = player("Brina", "MAGE", 0, 87) })
		local shown = texts(panel)
		assert.equals(4, #shown)
		assert.matches("^87 .*Brina", shown[1])
		assert.equals("Need: 2", shown[2])
		assert.equals("|A:lootroll-toast-icon-greed-up:13:13|a 1  |A:lootroll-toast-icon-pass-up:13:13|a 1", shown[3])
		assert.equals("Not chosen: 6", shown[4])
		panel.lines[4].scripts.OnEnter(panel.lines[4])
		assert.matches("Raider1", Loader.ui.tooltip.lines[2])
		assert.is_true(panel.frame:GetHeight() <= 100)
	end)

	it("keeps every drop of a group in the history while on, and none while off", function()
		Test.SetGroup(true)
		ns.Rolls.Groups.Joined(1, "Party-1")
		open(7, frames[1])
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = HELM, rolls = { player("Brina", "MAGE", 0, 87) } })
		assert.equals(1, #ns.Rolls.History.Open().drops)
		ns.Modules:SetEnabled("Rolls", false)
		assert.is_false(Rolls:IsActive())
		assert.is_false(Test.IsRegistered("START_LOOT_ROLL"))
		Test.SetLootDrop({ encounterID = 1, listID = 3, link = HELM, rolls = {} })
		assert.equals(1, #ns.Rolls.History.Open().drops)
		-- The hooks stay on the game's frames, but do nothing.
		frames[2].rollID = 9
		frames[2]:Show()
		assert.is_false(Rolls.PanelOf(frames[2]).frame:IsShown())
	end)

	it("creates no frames and listens to nothing while turned off", function()
		start({ LootomanDB = { schema = 4, profiles = { Default = { modules = { Rolls = { enabled = false } } } } } })
		assert.is_nil(Rolls.PanelOf(frames[1]))
		assert.is_false(Test.IsRegistered("LOOT_HISTORY_UPDATE_DROP"))
	end)

	it("shows the rolls open before a /reload, their frames shown again", function()
		start(nil, function()
			Test.state.rolls[7] = { rollID = 7, name = "Mail Helm", link = HELM }
			Test.state.lootDrops = { { encounterID = 1, listID = 2, link = HELM, rolls = { player("Brina", "MAGE", 0, 60) } } }
			frames[1].rollID = 7
			frames[1]:Show()
		end)
		local panel = Rolls.PanelOf(frames[1])
		assert.is_true(panel.frame:IsShown())
		assert.matches("Brina", panel.lines[1].text:GetText())
	end)

	it("hides only the panel that fails, and reports why", function()
		local panel = open(7, frames[1])
		ns.Rolls.Marks = { Add = function() error("broken") end }
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = HELM, rolls = { player("Brina", "MAGE", 0, 60) } })
		assert.is_false(panel.frame:IsShown())
		assert.matches("broken", Test.state.errors[#Test.state.errors])
		ns.Rolls.Marks = nil
	end)
end)
