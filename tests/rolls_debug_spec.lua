local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- The loot rolls' debug command, their lines in the bug report and the self-test (Modules/Rolls/Debug.lua).

local HELM = "|cff1eff00|Hitem:100::::::::40|h[Mail Helm]|h|r"

describe("the loot rolls' debugging", function()
	local ns, Test

	before_each(function()
		ns = Loader.LoadAddon({ gameType = "camelot", debug = true })
		Test = ns.Compat.Test
		local frames = {}
		for index = 1, 4 do
			frames[index] = UI.NewFake(Loader.ui.UIParent)
			frames[index]:Hide()
		end
		Test.state.gameRollFrames = frames
		Test.state.gameRollContainer = UI.NewFake(Loader.ui.UIParent)
		Loader.Start(ns)
	end)

	local function run()
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", "debug rolls")
		local lines = {}
		for index, line in ipairs(Test.state.printed) do
			lines[index] = line:gsub("^|cff%x+Lootoman|r: ", "")
		end
		return lines
	end

	it("prints the open rolls and the open group's last drops", function()
		assert.same({ "debug rolls: 0 open roll(s); detection off", "  no group open" }, run())
		Test.state.group = true
		ns.Rolls.Groups.Joined(1, "Party-1")
		Test.StartRoll(7, { name = "Mail Helm", link = HELM })
		local rolls = { { name = "Brina", guid = "g-b", class = "MAGE", state = 0, roll = 80 } }
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = HELM, rolls = rolls })
		assert.same({
			"debug rolls: 1 open roll(s); detection off",
			"  roll 7 Mail Helm: drop 1:2, 1 players",
			"  group Party-1, since 2025-11-20: 1 drop(s)",
			"  1:2 Mail Helm at The Deadmines: 1 players, winner none",
		}, run())
		Test.SetLootDrop({ encounterID = 1, listID = 2, link = HELM, rolls = rolls, winner = { name = "Brina", guid = "g-b" } })
		assert.equals("  1:2 Mail Helm at The Deadmines: 1 players, winner Brina", run()[4])
	end)

	it("plays the demo with /ltm demo roll, with no group", function()
		Test.RunSlashCommand("LOOTOMAN", "demo roll")
		assert.is_true(ns.Rolls.Demo.IsRunning())
		assert.is_false(Test.state.group)
	end)

	it("says in the bug report how the loot rolls are set, in plain ASCII", function()
		local text = ns.BugReport.Build()
		assert.matches("\n  Loot rolls: on; detection off, strictness normal; classes with changed rules 0; history 0 groups, 0 drops; live window on\n", text)
		assert.matches("\n  Loot roll frames: movable; in the game's place\n", text)
		assert.is_nil(text:find("[\128-\255]"))
	end)

	it("says in the self-test what the client has of the game's roll frames", function()
		local found = false
		for _, line in ipairs(ns.SelfTest.Run()) do
			found = found or line:find("Loot rolls: 4 of the game's roll frames found; their container found", 1, true) ~= nil
		end
		assert.is_true(found)
	end)
end)

describe("the demos", function()
	local function printed(ns, command)
		local Test = ns.Compat.Test
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", command)
		local lines = {}
		for _, line in ipairs(Test.state.printed) do
			lines[#lines + 1] = (line:gsub("^|cff%x+Lootoman|r: ", ""))
		end
		return lines
	end

	it("are listed by /ltm demo in the repository's version only, and in no help", function()
		local ns = Loader.LoadAddon({ gameType = "camelot", debug = true })
		Loader.Start(ns)
		assert.same({ "Demos, in the repository's version only:", "/ltm demo loot <pieces>: made-up loot in the feed (alone: the pieces it takes)",
			"/ltm demo lootrolls: the Loot Rolls window on made-up drops, where the client has no loot history window of its own",
			"/ltm demo roll: play the loot rolls' demo, with no group",
			"/ltm demo rollhistory [full]: the roll history on a made-up history, full to its limits" }, printed(ns, "demo"))
		for _, command in ipairs({ "help", "debug help" }) do
			assert.is_nil(table.concat(printed(ns, command), "\n"):find("demo", 1, true))
		end
		-- The released addon has none of them: /ltm demo opens the options as an unknown command does.
		local released = Loader.LoadAddon({ gameType = "camelot" })
		Loader.Start(released)
		assert.is_nil(released.Slash.RegisterDemo)
		assert.is_nil(released.Rolls.Demo.Start)
		assert.is_nil(released.Rolls.DemoHistory)
		assert.is_nil(released.Feed.Demo)
		assert.is_nil(table.concat(printed(released, "demo"), "\n"):find("Demos", 1, true))
	end)

	it("show the Loot Rolls window on made-up drops with /ltm demo lootrolls, where it exists", function()
		local ns = Loader.LoadAddon({ gameType = "camelot", debug = true })
		local Test = ns.Compat.Test
		Test.SetGlobalStrings({ NEED = "Need", GREED = "Greed", PASS = "Pass", LOOT_ROLLS = "Loot Rolls" })
		Test.SetItems({
			[5191] = { name = "Cruel Barb", link = "|cff0070dd|Hitem:5191::::::::40|h[Cruel Barb]|h|r", quality = 3 },
			[6460] = { name = "Cobrahn's Grasp", link = "|cff0070dd|Hitem:6460::::::::40|h[Cobrahn's Grasp]|h|r", quality = 3 },
		})
		Loader.Start(ns)
		Test.RunSlashCommand("LOOTOMAN", "demo lootrolls")
		for _ = 1, ns.Rolls.DemoHistory.TRIES do
			Test.Advance(ns.Rolls.DemoHistory.WAIT)
		end
		local window = ns.Rolls.LiveWindow.Frame()
		assert.same({ true, 4 }, { window:IsShown(), window.count })
		assert.same({ "Rolling…", "All passed" }, { window.rows[1].item.status:GetText(), window.rows[4].item.status:GetText() })
		assert.matches(ns.Rolls.Demo.Heroes()[1].name, window.rows[1].panel.lines[1].text:GetText(), 1, true)
		assert.same({}, ns.Rolls.History.Groups())
		-- Where the game has its own window, a line instead.
		local retail = Loader.LoadAddon({ gameType = "camelot", debug = true })
		retail.Compat.Test.state.gameLootHistory = true
		Loader.Start(retail)
		assert.matches("game's own loot history window", printed(retail, "demo lootrolls")[1], 1, true)
	end)
end)
