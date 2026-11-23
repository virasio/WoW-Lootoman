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

	it("plays the demo with /ltm demo roll dung, with no group", function()
		Test.RunSlashCommand("LOOTOMAN", "demo roll dung")
		assert.is_true(ns.Rolls.Demo.IsRunning())
		assert.is_false(Test.state.group)
	end)

	it("says in the bug report how the loot rolls are set, in plain ASCII", function()
		local text = ns.BugReport.Build()
		assert.matches("\n  Loot rolls: on; detection off, strictness normal; classes with changed rules 0; history 0 groups, 0 drops; live window on; panels on; game's frames shown\n", text)
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
		assert.same({ "Demos, in the repository's version only:",
			"/ltm demo exceptions dung|raid: the Suspicious Needs window on a made-up group's marked needs, as after leaving it",
			"/ltm demo loot <pieces>: made-up loot in the feed (alone: the pieces it takes)",
			"/ltm demo roll dung|raid [IDs]: a boss's loot rolled on by a made-up group, you as Player (alone: more)",
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

	it("say so in the chat and keep the error in the journal when one fails", function()
		local ns = Loader.LoadAddon({ gameType = "camelot", debug = true })
		Loader.Start(ns)
		ns.Slash.RegisterDemo("broken", function()
			error("broken on purpose")
		end, "/ltm demo broken")
		local lines = printed(ns, "demo broken")
		assert.equals("demo broken failed: /ltm debug log", lines[#lines])
		assert.matches("broken on purpose", tostring(ns.Compat.Test.state.errors[#ns.Compat.Test.state.errors]))
	end)
end)
