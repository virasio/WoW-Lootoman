local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- Ninja detection on the panels (Modules/Rolls/Marks.lua).

local function link(id, name, color)
	return ("|cff%s|Hitem:%d::::::::40|h[%s]|h|r"):format(color or "1eff00", id, name)
end

local MAIL = link(100, "Mail Helm")
local CLOTH = link(101, "Cloth Robe")
local BRACERS = link(102, "Mail Bracers")
local RING = link(200, "Ring", "0070dd")
local ITEMS = {
	[100] = { name = "Mail Helm", link = MAIL, quality = 2, classID = 4, subclassID = 3, equipLoc = "INVTYPE_HEAD", bindType = 2, stats = {} },
	[101] = { name = "Cloth Robe", link = CLOTH, quality = 2, classID = 4, subclassID = 1, equipLoc = "INVTYPE_CHEST", bindType = 2, stats = {} },
	[102] = { name = "Mail Bracers", link = BRACERS, quality = 2, classID = 4, subclassID = 3, equipLoc = "INVTYPE_WRIST", bindType = 2, stats = {} },
	[200] = { name = "Ring", link = RING, quality = 3, classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER", bindType = 1,
		stats = { ITEM_MOD_INTELLECT_SHORT = 8 } },
}

describe("ninja detection", function()
	local ns, Test, Rolls, frames, list

	local function start(saved)
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		frames = {}
		for index = 1, 4 do
			frames[index] = UI.NewFake(Loader.ui.UIParent)
			frames[index]:Hide()
		end
		Test.state.gameRollFrames = frames
		Test.SetGlobalStrings({ NEED = "Need", GREED = "Greed", PASS = "Pass", ITEM_MOD_INTELLECT_SHORT = "Intellect" })
		Test.SetItems(ITEMS)
		Test.state.group = true
		Test.SetUnits({
			player = { name = "Tester", class = "WARRIOR", level = 30, guid = Test.state.playerGUID },
			party1 = { name = "Brina", class = "MAGE", level = 30, guid = "g-brina" },
			party2 = { name = "Torg", class = "WARRIOR", level = 45, guid = "g-torg" },
		})
		Loader.Start(ns, saved)
		Rolls = ns.Rolls.Module
		ns.Storage:Set("Rolls", "ninja", true)
		list = 0
	end

	before_each(function()
		start()
	end)

	local function player(name, class, state, extra)
		local entry = { name = name, guid = "g-" .. name:lower(), class = class, state = state, roll = state ~= 5 and state ~= 4 and 50 or nil }
		for key, value in pairs(extra or {}) do
			entry[key] = value
		end
		return entry
	end

	-- A roll on an item with its drop: the panel of the first frame shows it.
	local function roll(item, players, rollID)
		list = list + 1
		rollID = rollID or list
		Test.StartRoll(rollID, { name = "Item", link = item, quality = 2 })
		frames[1].rollID = rollID
		frames[1]:Hide()
		frames[1]:Show()
		Test.SetLootDrop({ encounterID = 1, listID = list, link = item, rolls = players })
		return Rolls.PanelOf(frames[1])
	end

	-- An earlier drop of the group, kept in the history without a roll of the player's.
	local function earlier(item, players)
		list = list + 1
		Test.SetLootDrop({ encounterID = 1, listID = list, link = item, rolls = players, winner = players[1] })
	end

	local function line(panel, name)
		for _, each in ipairs(panel.lines) do
			if each.player and each.player.name == name then
				return each
			end
		end
	end

	it("marks nothing while the detection is off", function()
		ns.Storage:Set("Rolls", "ninja", false)
		local panel = roll(MAIL, { player("Brina", "MAGE", 0) })
		assert.is_nil(line(panel, "Brina").player.mark)
	end)

	it("marks a need on armor not the class's own, with the reason in the tooltip", function()
		local panel = roll(MAIL, { player("Brina", "MAGE", 0), player("Torg", "WARRIOR", 3) })
		local brina = line(panel, "Brina")
		assert.matches("RaidTargetingIcon_8", brina.text:GetText())
		assert.same({ "Mail: not a Mage's armor (BoE)" }, brina.player.notes)
		brina.scripts.OnEnter(brina)
		assert.equals("Mail: not a Mage's armor (BoE)", Loader.ui.tooltip.lines[3])
		assert.is_nil(line(panel, "Torg").player.mark)
	end)

	it("marks a need past the level an armor type counts to, the needer's level read from his unit", function()
		local panel = roll(MAIL, { player("Torg", "WARRIOR", 0) })
		assert.same({ "Mail: not a Warrior's armor past level 40 (BoE)" }, line(panel, "Torg").player.notes)
	end)

	it("judges stats too, and spares friends and guild members", function()
		local panel = roll(RING, { player("Torg", "WARRIOR", 0), player("Brina", "MAGE", 0) })
		assert.same({ "Intellect: not a Warrior's stat" }, line(panel, "Torg").player.notes)
		assert.is_nil(line(panel, "Brina").player.mark)
		Test.state.friends["g-torg"] = true
		Rolls.RedrawAll()
		assert.is_nil(line(Rolls.PanelOf(frames[1]), "Torg").player.mark)
		ns.Storage:Set("Rolls", "spareFriends", false)
		assert.is_string(line(Rolls.PanelOf(frames[1]), "Torg").player.mark)
	end)

	it("says what a need on a BoE item that does not fit follows: a greed on one that fits", function()
		earlier(CLOTH, { player("Brina", "MAGE", 3) })
		local panel = roll(MAIL, { player("Brina", "MAGE", 0) })
		assert.same({ "Mail: not a Mage's armor", "Greed on a fitting BoE (" .. CLOTH .. "), need on this one" }, line(panel, "Brina").player.notes)
	end)

	it("says it of a player who needs every BoE item", function()
		earlier(CLOTH, { player("Brina", "MAGE", 0) })
		earlier(CLOTH, { player("Brina", "MAGE", 0) })
		local panel = roll(MAIL, { player("Brina", "MAGE", 0) })
		local notes = line(panel, "Brina").player.notes
		assert.equals("Needs every BoE: 3 of 3", notes[2])
	end)

	it("marks a player who needs nearly everything in the group, by the strictness", function()
		earlier(RING, { player("Corvin", "ROGUE", 0) })
		earlier(RING, { player("Corvin", "ROGUE", 0) })
		earlier(RING, { player("Corvin", "ROGUE", 0) })
		local panel = roll(CLOTH, { player("Corvin", "ROGUE", 0) })
		local notes = line(panel, "Corvin").player.notes
		assert.equals("Needed 4 of 4 items in this group", notes[#notes])
		ns.Storage:Set("Rolls", "strictness", "lenient")
		assert.not_equals("Needed 4 of 4 items in this group", line(Rolls.PanelOf(frames[1]), "Corvin").player.notes[2])
	end)

	it("brings back a mark from the last group shared with the player, known by GUID, until he is fair", function()
		for _ = 1, 4 do
			earlier(RING, { player("Corvin", "ROGUE", 0) })
		end
		ns.Rolls.Groups.Left(1, nil)
		Test.state.serverTime = Test.state.serverTime + 86400
		ns.Rolls.Groups.Joined(1, "Party-2")
		-- Another name now, the same GUID.
		local panel = roll(CLOTH, { player("Corvinus", "ROGUE", 0, { guid = "g-corvin" }) })
		local notes = line(panel, "Corvinus").player.notes
		assert.matches("^Last time: needed 4 of 4 items %(2025%-11%-20, The Deadmines%)$", notes[#notes])
		for _ = 1, 4 do
			earlier(RING, { player("Corvinus", "ROGUE", 3, { guid = "g-corvin" }) })
		end
		panel = roll(CLOTH, { player("Corvinus", "ROGUE", 0, { guid = "g-corvin" }) })
		-- Cloth is no rogue's armor still, but last time's mark is gone.
		for _, note in ipairs(line(panel, "Corvinus").player.notes) do
			assert.not_matches("^Last time", note)
		end
	end)

	it("judges stats once the game has loaded them, listening for the item only while it waits", function()
		Test.state.items[200].statsPending = true
		local panel = roll(RING, { player("Torg", "WARRIOR", 0) })
		assert.is_nil(line(panel, "Torg").player.mark)
		assert.is_true(Test.IsRegistered("ITEM_DATA_LOAD_RESULT"))
		Test.state.items[200].statsPending = nil
		Test.FireEvent("ITEM_DATA_LOAD_RESULT", 200, true)
		assert.same({ "Intellect: not a Warrior's stat" }, line(Rolls.PanelOf(frames[1]), "Torg").player.notes)
		assert.is_false(Test.IsRegistered("ITEM_DATA_LOAD_RESULT"))
	end)

	it("follows a change of the class's rules", function()
		local panel = roll(MAIL, { player("Brina", "MAGE", 0) })
		assert.is_string(line(panel, "Brina").player.mark)
		ns.NeedRules.Set("WARRIOR", "armor", 1, true)
		assert.is_false(ns.NeedRules.Set("MAGE", "armor", 3, true))
		ns.Storage:Set("Rolls", "checkArmor", false)
		assert.is_nil(line(Rolls.PanelOf(frames[1]), "Brina").player.mark)
	end)

	it("shows an excused need with a mark of its own", function()
		local panel = roll(MAIL, { player("Brina", "MAGE", 0) })
		local group = ns.Rolls.History.Open()
		assert.is_true(ns.Rolls.History.SetExcused(group, "1:" .. list, "g-brina", true))
		Rolls.RedrawAll()
		assert.matches("ReadyCheck", line(Rolls.PanelOf(frames[1]), "Brina").text:GetText())
		assert.is_nil(line(panel, "Brina").player.notes)
	end)

	it("counts the raid's ninjas and shows them as squares in class colours", function()
		local players = {}
		for index = 1, 18 do
			players[index] = player("Mage" .. index, "MAGE", 0, { guid = "g-m" .. index })
		end
		players[#players + 1] = player("Torg", "WARRIOR", 3)
		players[#players + 1] = player("Ann", "HUNTER", 4)
		local panel = roll(MAIL, players)
		local texts = {}
		for _, each in ipairs(panel.lines) do
			if each:IsShown() then
				texts[#texts + 1] = each.text:GetText()
			end
		end
		assert.equals("Need: 18, ninja: 18", texts[2])
		local squares = panel.lines[3].squares
		local shown = 0
		for _, square in ipairs(squares) do
			if square:IsShown() then
				shown = shown + 1
			end
		end
		assert.equals(18 - shown, tonumber(texts[3]:match("^%+(%d+)$")))
		squares[1].scripts.OnEnter(squares[1])
		assert.matches("Mage1", Loader.ui.tooltip.lines[1])
		-- Without ninjas, no squares' line.
		ns.Storage:Set("Rolls", "ninja", false)
		assert.equals("Need: 18", panel.lines[2].text:GetText())
		assert.is_false(panel.lines[5]:IsShown())
	end)

	it("marks the demo's made-up ninjas", function()
		Test.state.worn = { [1] = MAIL, [11] = RING }
		ns.Rolls.Demo.Start(true)
		local group, raid = ns.Rolls.Demo.cards[1], ns.Rolls.Demo.cards[2]
		group.view.players[2].state = 0
		group.view.players[5].state = 0
		ns.Rolls.Demo.Draw(group)
		assert.same({ "WARRIOR", 45 }, { group.view.players[2].class, group.view.players[2].level })
		assert.is_string(group.view.players[2].mark)
		assert.matches("^Last time", group.view.players[5].notes[1])
		for _, each in ipairs(raid.view.players) do
			each.state = 0
		end
		ns.Rolls.Demo.Draw(raid)
		assert.is_true(#raid.view.ninjas >= 3)
	end)
end)
