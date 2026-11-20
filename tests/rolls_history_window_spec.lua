local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")
local UI = require("tests.mocks.UI")

-- The history window, Roll History (Modules/Rolls/HistoryWindow.lua).

local function link(id, name, color)
	return ("|cff%s|Hitem:%d::::::::40|h[%s]|h|r"):format(color or "1eff00", id, name)
end

local HELM = link(100, "Mail Helm")
local RING = link(200, "Ring", "0070dd")
local ITEMS = {
	[100] = { name = "Mail Helm", link = HELM, quality = 2, icon = 1001, classID = 4, subclassID = 3, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = {} },
	[200] = { name = "Ring", link = RING, quality = 3, icon = 2002, classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER", bindType = 1, stats = {} },
}

describe("the roll history window", function()
	local ns, Test, Window, History, Groups, settings

	before_each(function()
		settings = SettingsAPI.Install()
		ns = Loader.LoadAddon({ gameType = "camelot", skip = {} })
		Test = ns.Compat.Test
		Test.SetGlobalStrings({ NEED = "Need", GREED = "Greed", PASS = "Pass", ITEM_QUALITY2_DESC = "Uncommon", ITEM_QUALITY3_DESC = "Rare",
			ITEM_QUALITY4_DESC = "Epic" })
		Test.SetItems(ITEMS)
		Test.SetUnits({
			player = { name = "Tester", class = "WARRIOR", level = 30, guid = Test.state.playerGUID },
			party1 = { name = "Brina", class = "MAGE", level = 30, guid = "g-brina" },
		})
		Loader.Start(ns)
		Window, History, Groups = ns.Rolls.HistoryWindow, ns.Rolls.History, ns.Rolls.Groups
	end)

	local function choice(name, class, state, number)
		return { guid = "g-" .. name:lower(), name = name, class = class, state = state, roll = number }
	end

	-- Two groups: the first in two places, a mage needing mail and winning it;
	-- the second with one drop.
	local function fixture()
		Test.state.serverTime = 1763460000
		Test.SetGroup(true)
		Groups.Joined(1, "Party-1")
		Test.state.place = "The Deadmines"
		History.Record({ key = "1:1", link = HELM, rolls = { choice("Brina", "MAGE", 0, 90), choice("Kael", "PRIEST", 3, 40) },
			winner = { guid = "g-brina" } })
		Test.state.serverTime = Test.state.serverTime + 600
		Test.state.place = "Wailing Caverns"
		History.Record({ key = "1:2", link = RING, rolls = { choice("Brina", "MAGE", 5), choice("Kael", "PRIEST", 3, 12) },
			winner = { guid = "g-kael" } })
		local first = History.Open()
		Test.SetGroup(false)
		Groups.Left(1, "Party-1")
		Test.state.serverTime = Test.state.serverTime + 86400
		Test.SetGroup(true)
		Groups.Joined(1, "Party-2")
		History.Record({ key = "2:1", link = RING, rolls = { choice("Kael", "PRIEST", 5) }, allPassed = true })
		return first, History.Open()
	end

	local function shownLines(frame)
		local list = {}
		for _, line in ipairs(frame.playerLines) do
			if line:IsShown() then
				list[#list + 1] = line.counts:GetText()
			end
		end
		return list
	end

	it("opens with /ltm rolls, from the minimap menu's entry and from the options page's button", function()
		Test.RunSlashCommand("LOOTOMAN", "rolls")
		local frame = Window.Frame()
		assert.same({ true, "Roll History", "LootomanRollHistory" }, { frame:IsShown(), frame.title, frame.name })
		Loader.ui.PressEscape()
		assert.is_false(frame:IsShown())
		local button = ns.SettingsPanel.main.switchButtons.Rolls
		assert.same({ "UIPanelButtonTemplate", "Roll History" }, { button.template, button.text })
		button.scripts.OnClick(button)
		assert.is_true(frame:IsShown())
		frame:Hide()
		ns.MinimapIcon.ShowMenu(Loader.ui.UIParent)
		Loader.ui.contextMenu.entries[5].callback()
		assert.is_true(frame:IsShown())
	end)

	it("asks to turn on the loot rolls while they are off", function()
		ns.Modules:SetEnabled("Rolls", false)
		Test.RunSlashCommand("LOOTOMAN", "rolls")
		assert.is_nil(Window.Frame())
		local popup = settings.popups[#settings.popups]
		assert.same({ "GENERIC_CONFIRMATION", "Show Who Rolled What" }, { popup.which, popup.data.text_arg1 })
	end)

	it("opens the first time only out of combat", function()
		Test.SetCombat(true)
		assert.is_false(Window.Open())
		assert.is_nil(Window.Frame())
		assert.matches("The roll history opens out of combat.", Test.state.printed[#Test.state.printed], 1, true)
		Test.SetCombat(false)
		assert.is_true(Window.Open())
		Window.Hide()
		Test.SetCombat(true)
		assert.is_true(Window.Open())
	end)

	it("says so while no rolls are kept, and leaves out groups without drops", function()
		Test.SetGroup(true)
		Groups.Joined(1, "Party-1")
		Window.Open()
		local frame = Window.Frame()
		assert.is_true(frame.empty:IsShown())
		assert.same({ "", 0, false }, { frame.header:GetText(), frame.dropCount, frame.groupButtons[1] ~= nil and frame.groupButtons[1]:IsShown() })
	end)

	it("lists the groups newest first with their days, places and counts, and shows the newest", function()
		local first, second = fixture()
		Window.Open()
		local frame = Window.Frame()
		local buttons = frame.groupButtons
		assert.same({ second, first }, { buttons[1].group, buttons[2].group })
		assert.same({ "2025-11-19  Wailing Caverns", "1 drops, 1 players" }, { buttons[1].title:GetText(), buttons[1].counts:GetText() })
		assert.same({ "2025-11-18  The Deadmines, Wailing Caverns", "2 drops, 2 players" }, { buttons[2].title:GetText(), buttons[2].counts:GetText() })
		assert.same({ true, false }, { buttons[1].selected:IsShown(), buttons[2].selected:IsShown() })
		assert.is_false(frame.empty:IsShown())
		assert.equals(1, frame.dropCount)
		assert.equals("All passed", frame.dropRows[1].item.status:GetText())
	end)

	it("shows a group's players with their counts and its drops in time order, each with its time and place", function()
		local first = fixture()
		Window.Open()
		local frame = Window.Frame()
		frame.groupButtons[2].scripts.OnClick(frame.groupButtons[2], "LeftButton")
		assert.equals("2025-11-18  The Deadmines, Wailing Caverns", frame.header:GetText())
		assert.same({ "Need: 1, greed: 0, pass: 1, won: 1", "Need: 0, greed: 2, pass: 0, won: 1" }, shownLines(frame))
		assert.matches("Brina", frame.playerLines[1].name:GetText())
		assert.equals(2, frame.dropCount)
		local rows = frame.dropRows
		assert.same({ "|cff1eff00Mail Helm|r", "10:00, The Deadmines" }, { rows[1].item.name:GetText(), rows[1].item.note:GetText() })
		assert.same({ "|cff0070ddRing|r", "10:10, Wailing Caverns" }, { rows[2].item.name:GetText(), rows[2].item.note:GetText() })
		assert.matches("Brina|r 90$", rows[1].item.status:GetText())
		assert.equals(rows[1].frame, rows[1].panel.frame.parent)
		assert.equals(first, frame.group)
	end)

	it("marks a group with marked needs and counts each player's marks, with the detection on", function()
		fixture()
		ns.Storage:Set("Rolls", "ninja", true)
		Window.Open()
		local frame = Window.Frame()
		assert.is_nil(frame.groupButtons[1].counts:GetText():find("RaidTargetingIcon", 1, true))
		assert.is_truthy(frame.groupButtons[2].counts:GetText():find("RaidTargetingIcon", 1, true))
		frame.groupButtons[2].scripts.OnClick(frame.groupButtons[2], "LeftButton")
		assert.matches("RaidTargetingIcon_8:0|t 1$", frame.playerLines[1].counts:GetText())
		assert.is_truthy(frame.dropRows[1].panel.lines[1].text:GetText():find("RaidTargetingIcon", 1, true))
		-- Off, no marks.
		ns.Storage:Set("Rolls", "ninja", false)
		assert.is_nil(frame.groupButtons[2].counts:GetText():find("RaidTargetingIcon", 1, true))
	end)

	it("follows the history: a drop kept while it is open shows at once", function()
		local _, second = fixture()
		Window.Open()
		local frame = Window.Frame()
		Test.StartRoll(7, { name = "Mail Helm", link = HELM, quality = 2 })
		Test.SetLootDrop({ encounterID = 3, listID = 1, link = HELM, rolls = { choice("Kael", "PRIEST", 4) } })
		assert.equals(2, #second.drops)
		assert.equals(2, frame.dropCount)
	end)

	local function search(frame, text)
		frame.search:SetText(text)
		for _, hook in ipairs(frame.search.hooks.OnTextChanged) do
			hook(frame.search)
		end
	end

	it("shows a player over every group by GUID, under their latest name, and goes back to the group", function()
		local first, second = fixture()
		History.Record({ key = "2:2", link = HELM, rolls = { choice("Kael", "PRIEST", 0, 77) }, winner = { guid = "g-kael" } })
		second.drops[2].rolls[1].name = "Kaelán"
		Window.Open()
		local frame = Window.Frame()
		-- Kael's line in the newest group.
		frame.playerLines[1].scripts.OnClick(frame.playerLines[1])
		assert.same({ "g-kael", true }, { frame.player, frame.back:IsShown() })
		assert.matches("Kaelán", frame.header:GetText())
		assert.equals("Need: 1, greed: 2, pass: 1, won: 2", frame.playerLines[1].counts:GetText())
		-- The groups newest first, each with the drops they chose on and their choice.
		assert.same({ "2025-11-19  Wailing Caverns", "2025-11-18  The Deadmines, Wailing Caverns" },
			{ frame.groupHeadings[1]:GetText(), frame.groupHeadings[2]:GetText() })
		assert.equals(4, frame.dropCount)
		assert.equals("10:00  Greed 40", frame.dropRows[3].item.note:GetText())
		frame.back.scripts.OnClick(frame.back)
		assert.same({ nil, false, 2 }, { frame.player, frame.back:IsShown(), frame.dropCount })
		assert.equals(second, frame.group)
		-- A drop's line opens its player too.
		frame.groupButtons[2].scripts.OnClick(frame.groupButtons[2], "LeftButton")
		local line = frame.dropRows[1].panel.lines[1]
		line.scripts.OnClick(line, "LeftButton")
		assert.equals("g-brina", frame.player)
		assert.equals(first, frame.group)
	end)

	it("keeps the groups with a player whose name holds the search's text, whatever the case, and Enter shows that player", function()
		local first = fixture()
		first.drops[1].rolls[1].name = "Брина"
		first.drops[2].rolls[1].name = "Брина"
		Window.Open()
		local frame = Window.Frame()
		search(frame, "БРИ")
		local buttons = frame.groupButtons
		assert.same({ first, false }, { buttons[1].group, buttons[2]:IsShown() })
		-- The chosen group was the newest: the search shows the one it kept.
		assert.equals(first, frame.group)
		search(frame, "KAEL")
		assert.same({ true, true }, { buttons[1]:IsShown(), buttons[2]:IsShown() })
		search(frame, "nobody")
		assert.is_false(buttons[1]:IsShown())
		search(frame, "брин")
		for _, hook in ipairs(frame.search.hooks.OnEnterPressed) do
			hook(frame.search)
		end
		assert.equals("g-brina", frame.player)
		assert.matches("Брина", frame.header:GetText())
		search(frame, "")
		assert.same({ true, true }, { buttons[1]:IsShown(), buttons[2]:IsShown() })
	end)

	it("filters the drops by their lowest quality, kept in the profile", function()
		fixture()
		Window.Open()
		local frame = Window.Frame()
		frame.groupButtons[2].scripts.OnClick(frame.groupButtons[2], "LeftButton")
		assert.equals(2, frame.dropCount)
		local root = UI.OpenMenu(frame.quality)
		assert.same({ "Uncommon", "Rare", "Epic" }, { root.entries[1].text, root.entries[2].text, root.entries[3].text })
		assert.is_true(root.entries[1].isSelected())
		root.entries[2].setSelected()
		assert.equals(3, ns.Storage:Get("Rolls", "historyMinQuality"))
		assert.same({ 1, "|cff0070ddRing|r" }, { frame.dropCount, frame.dropRows[1].item.name:GetText() })
	end)

	it("shows only the drops with marked needs, with the detection on: in a player's view, their own", function()
		fixture()
		Window.Open()
		local frame = Window.Frame()
		frame.groupButtons[2].scripts.OnClick(frame.groupButtons[2], "LeftButton")
		-- Greyed while the detection is off.
		assert.is_false(frame.markedOnly:IsEnabled())
		ns.Storage:Set("Rolls", "ninja", true)
		assert.is_true(frame.markedOnly:IsEnabled())
		frame.markedOnly:SetChecked(true)
		frame.markedOnly.scripts.OnClick(frame.markedOnly)
		assert.is_true(ns.Storage:Get("Rolls", "historyMarkedOnly"))
		-- The mage's need on mail is marked; the ring had none.
		assert.same({ 1, "|cff1eff00Mail Helm|r" }, { frame.dropCount, frame.dropRows[1].item.name:GetText() })
		Window.ShowPlayer("g-kael")
		assert.equals(0, frame.dropCount)
		Window.ShowPlayer("g-brina")
		assert.equals(1, frame.dropCount)
		-- The detection off: every drop again.
		ns.Storage:Set("Rolls", "ninja", false)
		assert.equals(2, frame.dropCount)
	end)

	it("closes as the loot rolls turn off", function()
		Window.Open()
		ns.Modules:SetEnabled("Rolls", false)
		assert.is_false(Window.Frame():IsShown())
	end)
end)
