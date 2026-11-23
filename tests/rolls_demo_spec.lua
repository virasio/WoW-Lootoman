local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

-- The loot rolls' demo, in the repository's version (Dev/DemoRoll.lua): a
-- boss's loot rolled on by a made-up group, the character as Player.

local function link(id, name, color)
	return ("|cff%s|Hitem:%d::::::::60|h[%s]|h|r"):format(color or "a335ee", id, name)
end

local BAND, SWORD, AXE = link(284716, "Band of the Better Half"), link(17075, "Vis'kag the Bloodletter"), link(17068, "Deathbringer")
local RING, CROWN, HELM = link(18813, "Ring of Binding"), link(16914, "Netherwind Crown"), link(16963, "Helm of Wrath")
local WORN = link(100, "Worn Helm", "1eff00")
local ITEMS = {
	[284716] = { name = "Band of the Better Half", link = BAND, quality = 4, classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER", icon = 1,
		bindType = 1, stats = { ITEM_MOD_INTELLECT_SHORT = 9 } },
	[17075] = { name = "Vis'kag the Bloodletter", link = SWORD, quality = 4, classID = 2, subclassID = 7, equipLoc = "INVTYPE_WEAPON", icon = 2,
		bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 9 } },
	[17068] = { name = "Deathbringer", link = AXE, quality = 4, classID = 2, subclassID = 0, equipLoc = "INVTYPE_WEAPON", icon = 3,
		bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 9 } },
	[18813] = { name = "Ring of Binding", link = RING, quality = 4, classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER", icon = 4,
		bindType = 1, stats = {} },
	[16914] = { name = "Netherwind Crown", link = CROWN, quality = 4, classID = 4, subclassID = 1, equipLoc = "INVTYPE_HEAD", icon = 5,
		bindType = 1, stats = { ITEM_MOD_INTELLECT_SHORT = 20 } },
	[16963] = { name = "Helm of Wrath", link = HELM, quality = 4, classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD", icon = 6,
		bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 20 } },
	[100] = { name = "Worn Helm", link = WORN, quality = 2, classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD", icon = 7, stats = {} },
}

describe("the loot rolls' demo", function()
	local ns, Test, Demo, settings, window

	local function start(gameType)
		settings = SettingsAPI.Install()
		ns = Loader.LoadAddon({ gameType = gameType or "camelot", skip = {}, debug = true })
		Test = ns.Compat.Test
		Test.state.gameRollFrames = {}
		Test.SetGlobalStrings({ NEED = "Need", GREED = "Greed", PASS = "Pass", LOOT_ROLLS = "Loot Rolls" })
		Test.SetItems(ITEMS)
		Test.state.worn = { [1] = WORN }
		Test.SetUnits({ player = { name = "Tester", class = "WARRIOR", level = 60, guid = Test.state.playerGUID } })
		Loader.Start(ns)
		Demo = ns.Rolls.Demo
		window = ns.Rolls.LiveWindow.Frame()
	end

	before_each(function()
		start()
	end)

	local function run(words)
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", "demo roll " .. words)
		local lines = {}
		for _, line in ipairs(Test.state.printed) do
			lines[#lines + 1] = (line:gsub("^|cff%x+Lootoman|r: ", ""))
		end
		return lines
	end

	local function names(players)
		local list = {}
		for _, player in ipairs(players) do
			list[#list + 1] = player.name
		end
		return list
	end

	local function plain(text)
		return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
	end

	local function click(owner, button)
		owner.scripts.OnClick(owner, button)
	end

	it("makes a dungeon's group of four heroes of the classic game and Player, and a raid of forty", function()
		local dungeon = Demo.Party("dung")
		assert.same({ "Varian", "Tyrande", "Jaina", "Shaw", "Player" }, names(dungeon))
		assert.same({ "WARRIOR", "PRIEST", "MAGE", "ROGUE" }, { dungeon[1].class, dungeon[2].class, dungeon[3].class, dungeon[4].class })
		-- Player is the character: its class, level and GUID, not its name.
		local me = dungeon[5]
		assert.same({ true, "WARRIOR", 60, Test.state.playerGUID }, { me.isSelf, me.class, me.level, me.guid })
		local raid = Demo.Party("raid")
		assert.equals(40, #raid)
		local named, passing, known = 0, 0, {}
		for _, class in ipairs(ns.Data.rolls.classes) do
			known[class[1]] = true
		end
		for index, player in ipairs(raid) do
			assert.is_true(known[player.class], player.class)
			if player.passes then
				passing = passing + 1
				assert.equals(("Test%d"):format(passing), player.name)
			elseif not player.isSelf then
				named = named + 1
				assert.is_nil(player.name:match("^Test"), player.name)
			end
			assert.equals(index == 14, player.isSelf == true)
		end
		assert.same({ 13, 26 }, { named, passing })
	end)

	it("plays a dungeon's roll on a look-alike of the game's roll frame with its panel, the heroes choosing one by one", function()
		assert.same({}, run("dung"))
		local card = Demo.cards[1]
		assert.same({ true, "Band of the Better Half", true }, { card.frame:IsShown(), card.frame.name:GetText(), card.panel.frame:IsShown() })
		assert.is_false(Demo.cards[2].frame:IsShown())
		-- Player's own line is lit, last of five.
		assert.same({ false, true }, { card.panel.lines[1].self:IsShown(), card.panel.lines[5].self:IsShown() })
		assert.equals("Player", plain(card.panel.lines[5].text:GetText()))
		Test.Advance(Demo.CHOSEN)
		local roll = Demo.rolls[1]
		for _, player in ipairs(roll.view.players) do
			assert.equals(player.isSelf == true, player.state == 4, player.name)
		end
		-- Waiting for the player: no winner, the timer running down.
		assert.same({ nil, false }, { roll.view.winner, roll.over == true })
		assert.is_true(card.frame.timer:GetValue() < Demo.LENGTH)
		assert.is_false(window:IsShown())
	end)

	it("takes the look-alike away at the player's choice, then opens the Loot Rolls window with the roll, which fills in", function()
		run("dung")
		local card = Demo.cards[1]
		click(card.buttons[2])
		assert.same({ false, false }, { card.frame:IsShown(), card.panel.frame:IsShown() })
		assert.is_false(window:IsShown())
		Test.Advance(ns.Rolls.LiveWindow.WAIT)
		assert.same({ true, 1, "Band of the Better Half" }, { window:IsShown(), window.count, plain(window.rows[1].item.name:GetText()) })
		assert.equals("Rolling…", window.rows[1].item.status:GetText())
		Test.Advance(Demo.CHOSEN)
		assert.is_true(Demo.rolls[1].over)
		assert.not_equals("Rolling…", window.rows[1].item.status:GetText())
		-- Nothing went to the game or into the history.
		assert.same({ nil, {}, nil }, { Test.state.rolledOn, ns.Rolls.Model.Rolls(), ns.Rolls.History.Open() })
	end)

	it("ends the roll at once when the player chooses last, and the window opens with its winner", function()
		run("dung")
		Test.Advance(Demo.CHOSEN)
		click(Demo.cards[1].buttons[1])
		local view = Demo.rolls[1].view
		assert.is_true(Demo.rolls[1].over)
		assert.is_true(view.winner ~= nil or view.allPassed == true)
		Test.Advance(ns.Rolls.LiveWindow.WAIT)
		assert.same({ true, 1 }, { window:IsShown(), window.count })
		assert.not_equals("Rolling…", window.rows[1].item.status:GetText())
	end)

	it("passes for the player when the time is up, as the game does, and opens no window without a choice", function()
		run("dung")
		Test.Advance(Demo.LENGTH + Demo.STEP)
		local roll = Demo.rolls[1]
		assert.same({ true, 5 }, { roll.over, roll.me.state })
		assert.same({ false, false }, { Demo.cards[1].frame:IsShown(), window:IsShown() })
		assert.is_false(Demo.IsRunning())
	end)

	it("opens no window at the choice with its option off", function()
		ns.Storage:Set("Rolls", "liveWindow", false)
		run("dung")
		click(Demo.cards[1].buttons[1])
		Test.Advance(ns.Rolls.LiveWindow.WAIT)
		assert.is_false(window:IsShown())
	end)

	it("rolls a raid of forty on five of Onyxia's items: four look-alikes at once, the fifth when one is free", function()
		run("raid")
		assert.equals(5, #Demo.rolls)
		assert.same({ true, true, true, true }, { Demo.cards[1].frame:IsShown(), Demo.cards[2].frame:IsShown(), Demo.cards[3].frame:IsShown(),
			Demo.cards[4].frame:IsShown() })
		assert.is_nil(Demo.rolls[5].card)
		local items = {}
		for index, roll in ipairs(Demo.rolls) do
			items[index] = roll.view.link
		end
		assert.same({ SWORD, AXE, RING, CROWN, HELM }, items)
		-- Those who only pass are counted on the panel, named only in its tooltip.
		Test.Advance(Demo.CHOSEN)
		local panel = Demo.cards[1].panel
		for _, line in ipairs(panel.lines) do
			if line:IsShown() then
				assert.is_nil(plain(line.text:GetText() or ""):find("Test1", 1, true))
			end
		end
		click(Demo.cards[1].buttons[3])
		assert.equals(Demo.cards[1], Demo.rolls[5].card)
		assert.same({ "Helm of Wrath", true }, { Demo.cards[1].frame.name:GetText(), Demo.cards[1].frame:IsShown() })
	end)

	it("takes the items given this time, split by commas, and says what it cannot read", function()
		run("dung 17075,18813")
		assert.same({ SWORD, RING }, { Demo.rolls[1].view.link, Demo.rolls[2].view.link })
		assert.equals(5, #Demo.rolls[1].view.players)
		assert.same({ "demo roll: “abc” is not an item's ID." }, { run("raid 17075,abc")[1] })
		assert.same({ "demo roll: the IDs go split by commas without spaces." }, { run("dung 17075, 18813")[1] })
		local usage = run("")
		assert.matches("^/ltm demo roll dung", usage[1])
		assert.matches("^/ltm demo roll raid", usage[2])
	end)

	it("waits a moment for an item the game has not given, leaves it out, and takes worn gear when none comes", function()
		run("dung 999,17075")
		assert.same({}, Demo.rolls)
		assert.same({ 999 }, { Test.state.requested[1] })
		Test.Advance(Demo.WAIT * Demo.TRIES)
		assert.same({ SWORD }, { Demo.rolls[1].view.link })
		assert.equals("demo roll: item 999 did not come; left out.", Test.state.printed[#Test.state.printed]:gsub("^|cff%x+Lootoman|r: ", ""))
		run("dung 998")
		Test.Advance(Demo.WAIT * Demo.TRIES)
		assert.same({ WORN }, { Demo.rolls[1].view.link })
	end)

	it("keeps taking the drops in while the window is open, as it does a boss's loot", function()
		run("dung")
		click(Demo.cards[1].buttons[1])
		Test.Advance(ns.Rolls.LiveWindow.WAIT)
		run("dung 17075")
		assert.equals(2, window.count)
		assert.equals("Vis'kag the Bloodletter", plain(window.rows[1].item.name:GetText()))
		-- The run before is over: its roll has its winner.
		assert.not_equals("Rolling…", window.rows[2].item.status:GetText())
	end)

	it("with the game's frames hidden, opens the window at once with the rolls on top to choose on, and asks before closing", function()
		ns.Storage:Set("Rolls", "hideGameFrames", true)
		ns.Storage:Set("Rolls", "liveWindow", false)
		run("raid")
		assert.same({ true, 5 }, { window:IsShown(), window.count })
		assert.is_false(Demo.cards[1] ~= nil and Demo.cards[1].frame:IsShown())
		for index = 1, 5 do
			assert.same({ true, true }, { window.rows[index].buttons[1]:IsShown(), window.rows[index].timer:IsShown() }, index)
		end
		-- The newest on top, as rolls come.
		assert.equals("Helm of Wrath", plain(window.rows[1].item.name:GetText()))
		Test.Advance(ns.Rolls.LiveWindow.GUARD)
		click(window.rows[1].buttons[2])
		assert.same({ "Helm of Wrath", false }, { plain(window.rows[5].item.name:GetText()), window.rows[5].buttons[1]:IsShown() })
		assert.same({ true, true }, { window.line:IsShown(), window.rows[5].timer:IsShown() })
		assert.is_nil(Test.state.rolledOn)
		window.close.scripts.OnClick(window.close)
		local popup = settings.popups[#settings.popups]
		assert.equals("Rolls are waiting for your choice; untouched, they end as a pass. Close the window?", popup.data.text)
		assert.is_true(window:IsShown())
		-- Untouched, they end as a pass; then it closes at once.
		Test.Advance(Demo.LENGTH + Demo.STEP)
		assert.same({ 5, 5 }, { Demo.rolls[1].me.state, Demo.rolls[4].me.state })
		assert.is_false(window.rows[1].timer:IsShown())
		local count = #settings.popups
		window.close.scripts.OnClick(window.close)
		assert.same({ false, count }, { window:IsShown(), #settings.popups })
	end)

	it("excuses a marked need from a right click in the window, in the demo only, with no Suspicious Needs window at the end", function()
		ns.Storage:Set("Rolls", "ninja", true)
		ns.Storage:Set("Rolls", "summary", true)
		run("dung")
		click(Demo.cards[1].buttons[1])
		Test.Advance(Demo.CHOSEN)
		-- The ring has intellect: the warrior or the rogue who needs it is marked.
		local view = Demo.rolls[1].view
		assert.equals(1, #view.ninjas)
		assert.is_true(view.ninjas[1].class == "WARRIOR" or view.ninjas[1].class == "ROGUE")
		local line
		for _, each in ipairs(window.rows[1].panel.lines) do
			if each.player and each.player.guid == view.ninjas[1].guid then
				line = each
			end
		end
		assert.matches("RaidTargetingIcon", line.text:GetText())
		Loader.ui.contextMenu = nil
		click(line, "RightButton")
		assert.equals("Exception: Agreed in the Chat", Loader.ui.contextMenu.entries[1].text)
		Loader.ui.contextMenu.entries[1].callback()
		assert.matches("ReadyCheck", line.text:GetText())
		assert.same({ 0, nil }, { #view.ninjas, ns.Rolls.History.Open() })
		Test.Advance(Demo.LENGTH)
		local suspicious = ns.Rolls.SuspiciousNeeds.Frame()
		assert.is_true(suspicious == nil or not suspicious:IsShown())
	end)

	it("in a raid, marks one more who needs as needing nearly everything", function()
		ns.Storage:Set("Rolls", "ninja", true)
		run("raid 18813")
		Test.Advance(Demo.CHOSEN)
		local view = Demo.rolls[1].view
		local everything = false
		for _, player in ipairs(view.ninjas) do
			for _, note in ipairs(player.notes) do
				everything = everything or note:find("^Needed 4 of 5") ~= nil
			end
		end
		-- The ring fits everyone: a mark of the past for one, needing everything for another.
		assert.is_true(everything)
		assert.is_true(#view.ninjas >= 1)
	end)

	it("waits until real rolls are over, starts out of combat only, and with the loot rolls on", function()
		Test.SetGroup(true)
		Test.StartRoll(7, { name = "Band of the Better Half", link = BAND })
		assert.same({ "demo roll: it waits until the rolls in progress are over." }, run("dung"))
		Test.CancelRoll(7)
		Test.SetCombat(true)
		assert.same({ "demo roll: it starts out of combat." }, run("dung"))
		Test.SetCombat(false)
		ns.Modules:SetEnabled("Rolls", false)
		assert.same({ "demo roll: the loot rolls are off." }, run("dung"))
	end)

	it("stops when the loot rolls are turned off, its rolls ended", function()
		run("dung")
		ns.Modules:SetEnabled("Rolls", false)
		assert.same({ false, true, false }, { Demo.cards[1].frame:IsShown(), Demo.rolls[1].over, Demo.IsRunning() })
	end)
end)
