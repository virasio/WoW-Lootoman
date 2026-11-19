local Loader = require("tests.helpers.loader")
local Formats = require("tests.fixtures.globalstrings")

describe("slash commands", function()
	local ns, Test, printed

	local function run(message)
		Test.RunSlashCommand("LOOTOMAN", message)
	end

	local function output()
		return table.concat(printed, "\n")
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Test = ns.Compat.Test
		Test.state.capabilities["C_AddOns.GetAddOnMetadata"] = true
		Loader.Start(ns)
		printed = Test.state.printed
	end)

	it("are /lootoman and /ltm", function()
		assert.same({ "/lootoman", "/ltm" }, Test.state.slashCommands.LOOTOMAN.commands)
	end)

	it("open the settings without a command", function()
		local opened = 0
		ns.Bus:On("OpenSettings", "test", function() opened = opened + 1 end)
		run("")
		run("   ")
		assert.equals(2, opened)
	end)

	-- The printed lines without the chat prefix.
	local function lines(from, to)
		local found = {}
		for index = from or 1, to or #printed do
			found[#found + 1] = (printed[index]:gsub("^|cff%x+Lootoman|r: ", ""))
		end
		return found
	end

	it("list the player's commands for help and for an unknown one, nothing of debug", function()
		run("help")
		local count = #printed
		run("dance")
		local help = lines(1, count)
		assert.same({ "Commands:", "/ltm or /lootoman: open the options" }, { help[1], help[2] })
		assert.equals("/ltm help: list the commands", help[#help])
		assert.matches("\n/ltm feed: open the loot feed's look window\n/ltm junk: open the junk window\n", table.concat(help, "\n"))
		assert.same(help, lines(count + 1))
		assert.not_matches("debug", output())
	end)

	it("have no old names: design, toss and selftest show the help", function()
		for _, old in ipairs({ "design", "toss", "selftest" }) do
			Test.state.printed = {}
			printed = Test.state.printed
			run(old)
			assert.equals("Commands:", lines()[1], old)
		end
	end)

	describe("for debugging", function()
		it("say how to list them, alone", function()
			run("debug")
			assert.same({ "Debug commands for testing and bug reports: /ltm debug help" }, lines())
		end)

		it("are listed by debug help and for an unknown one, in English", function()
			run("debug help")
			local count = #printed
			run("debug dance")
			assert.equals("Debug commands:", lines()[1])
			assert.same(lines(1, count), lines(count + 1))
			local text = output()
			for _, name in ipairs({ "help", "log", "selftest" }) do
				assert.matches("/ltm debug " .. name, text)
			end
		end)

		it("are added by the parts that own them, each once", function()
			local heard
			ns.Slash.RegisterDebug("probe", function(argument) heard = argument end, "/ltm debug probe: test")
			run("DEBUG Probe  some words ")
			assert.equals("some words", heard)
			assert.has_error(function() ns.Slash.RegisterDebug("probe", function() end) end)
			assert.has_error(function() ns.Slash.Register("feed", function() end) end)
		end)
	end)

	describe("debug log", function()
		local function debugOn()
			return ns.Storage:GetGlobal("debug")
		end

		for _, value in ipairs({ "on", "On", "ON" }) do
			it("turns the extended log on with “" .. value .. "”", function()
				run("debug log " .. value)
				assert.is_true(debugOn())
				assert.same({ "The extended log is on for all characters." }, lines())
			end)
		end

		for _, value in ipairs({ "off", "Off", "OFF" }) do
			it("turns the extended log off with “" .. value .. "”", function()
				ns.Storage:SetGlobal("debug", true)
				run("debug log " .. value)
				assert.is_false(debugOn())
				assert.same({ "The extended log is off for all characters; errors are still kept." }, lines())
			end)
		end

		it("explains an unknown value or count and changes nothing", function()
			ns.Storage:SetGlobal("debug", true)
			for _, value in ipairs({ " maybe ", "0", "301", "2.5" }) do
				Test.state.printed = {}
				printed = Test.state.printed
				run("debug log " .. value)
				assert.is_true(debugOn())
				assert.matches("^Unknown value “" .. value:gsub("^%s*(.-)%s*$", "%1"):gsub("%p", "%%%0") .. "”", lines()[1])
			end
		end)

		it("never prints a debug line, and keeps it only while the log is on", function()
			ns.Debug("hidden")
			run("debug log on")
			ns.Debug("kept")
			run("debug log off")
			ns.Debug("hidden again")
			assert.equals(2, #printed)
			local log = ns.Diagnostics.Section().log
			assert.same({ 1, true }, { #log, log[1]:find("kept", 1, true) ~= nil })
		end)

		it("while the log is off, prints the errors kept and how to turn it on", function()
			run("debug log")
			assert.same({ "The extended log is off: /ltm debug log on" }, lines())
			Test.state.time = 7
			ns.Compat.ReportError("something broke")
			Test.state.printed = {}
			printed = Test.state.printed
			run("debug log 50")
			assert.same({ "7.00 Error: something broke", "The extended log is off: /ltm debug log on" }, lines())
		end)

		it("prints the last 20 entries, or as many as asked, errors and lines in time order", function()
			run("debug log on")
			for index = 1, 30 do
				Test.state.time = index
				ns.Debug("line " .. index)
				if index == 25 then
					ns.Compat.ReportError("broken at 25")
				end
			end
			Test.state.printed = {}
			printed = Test.state.printed
			run("debug log")
			local shown = lines()
			assert.same({ 20, "12.00 line 12", "25.00 line 25", "25.00 Error: broken at 25", "30.00 line 30" },
				{ #shown, shown[1], shown[14], shown[15], shown[20] })
			Test.state.printed = {}
			printed = Test.state.printed
			run("debug log 300")
			assert.same({ 31, "1.00 line 1" }, { #lines(), lines()[1] })
		end)

		it("clears the journal: the log, the errors and the saved self-test", function()
			run("debug log on")
			ns.Debug("something")
			ns.Compat.ReportError("broken")
			run("debug selftest")
			run("debug log clear")
			local section = ns.Diagnostics.Section()
			assert.same({ {}, {}, nil, {} }, { section.log, section.errors, section.selfTest, ns.Diagnostics.SessionErrors() })
			assert.equals("The journal is cleared: the extended log, the errors and the saved self-test.", lines()[#lines()])
			Test.state.printed = {}
			printed = Test.state.printed
			run("debug log")
			assert.same({ "The journal is empty." }, lines())
		end)
	end)

	describe("errors", function()
		it("are kept with the start of their stack, and still reach the game's error handler", function()
			Test.state.time = 3
			Test.state.stack = "one\ntwo\nthree\nfour\nfive\nsix\nseven"
			ns.Bus:On("ProfileChanged", "test", function() error("listener broke") end)
			ns.Bus:Send("ProfileChanged", "Raid", "Default")
			local kept = ns.Diagnostics.Section().errors
			assert.same({ 1, 3, "one\ntwo\nthree\nfour\nfive\nsix" }, { #kept, kept[1].at, kept[1].stack })
			assert.matches("listener broke", kept[1].message)
			assert.matches("listener broke", Test.state.errors[#Test.state.errors])
			assert.equals(kept[1], ns.Diagnostics.SessionErrors()[1])
		end)

		it("are kept, the last 20, whether or not the extended log is on", function()
			for index = 1, 25 do
				ns.Compat.ReportError("error " .. index)
			end
			local kept = ns.Diagnostics.Section().errors
			assert.same({ 20, "error 6", "error 25", 20 }, { #kept, kept[1].message, kept[20].message, #ns.Diagnostics.SessionErrors() })
			assert.is_false(ns.Storage:GetGlobal("debug"))
		end)
	end)

	describe("selftest", function()
		-- Every line of the last run, as the journal keeps it.
		local function report(target)
			return table.concat((target or ns).Diagnostics.Section().selfTest.lines, "\n")
		end

		it("says in the chat only the verdict when every check passes, and keeps every line", function()
			for _, need in pairs(ns.Compat.NEEDS) do
				for _, path in ipairs(need) do
					Test.state.capabilities[path] = true
				end
			end
			run("debug selftest")
			assert.same({ "All checks passed.", "The full report is in the bug report window." }, lines())
			assert.matches("Has: OK", report())
			assert.matches("Client 12%.1%.5", report())
		end)

		it("says in the chat the failed checks and their count, not what is not available", function()
			for _, need in pairs(ns.Compat.NEEDS) do
				for _, path in ipairs(need) do
					Test.state.capabilities[path] = true
				end
			end
			Test.state.build = {}
			ns.Compat.CanEncode = function() return false end
			run("debug selftest")
			assert.same({ "  GetBuildInfo: FAILED, no interface number", "1 check(s) failed.",
				"The full report is in the bug report window." }, lines())
			assert.matches("Encode: not available", report())
		end)

		it("passes every check on a working client", function()
			run(" debug SelfTest ")
			assert.not_matches("FAILED", report())
			assert.matches("All checks passed%.", report())
			assert.matches("Has: OK", report())
			assert.matches("RegisterEvent: OK", report())
		end)

		it("reports a failing check", function()
			Test.state.capabilities["C_AddOns.GetAddOnMetadata"] = nil
			run("debug selftest")
			assert.matches("Has: FAILED, wrong answer", report())
			assert.matches("1 check%(s%) failed%.", report())
		end)

		it("reports a check that raises an error", function()
			Test.state.build = {}
			run("debug selftest")
			assert.matches("GetBuildInfo: FAILED", report())
		end)

		it("finishes the report when game calls raise errors", function()
			ns.Compat.GetBuildInfo = function() error("broken build info") end
			ns.Compat.GetAddOnMetadata = function() error("broken metadata") end
			run("debug selftest")
			assert.matches("GetBuildInfo: FAILED", report())
			assert.matches("GetAddOnMetadata: FAILED", report())
			assert.matches("%(.*broken build info%)", report())
			assert.matches("%(.*broken metadata%)", report())
			assert.matches("Character Tester%-Realm", report())
			assert.equals("2 check(s) failed.", lines()[#lines() - 1])
		end)

		it("tells which Compat functions miss what they need, and what this client lacks", function()
			local total = 0
			for _, need in pairs(ns.Compat.NEEDS) do
				total = total + 1
				for _, path in ipairs(need) do
					Test.state.capabilities[path] = true
				end
				for _, path in ipairs(need.optional or {}) do
					Test.state.capabilities[path] = true
				end
			end
			local function line()
				local found
				for _, text in ipairs(ns.Diagnostics.Section().selfTest.lines) do
					found = text:match("Compat: .*") or found
				end
				return found
			end
			run("debug selftest")
			assert.equals(("Compat: %d of %d functions have what they need"):format(total, total), line())
			Test.state.capabilities["C_Timer.After"] = nil
			Test.state.capabilities["C_EncodingUtil.SerializeCBOR"] = nil
			run("debug selftest")
			assert.equals(("Compat: %d of %d functions have what they need; missing: After (C_Timer.After); "
				.. "not on this client: CanEncode (C_EncodingUtil.SerializeCBOR); Decode (C_EncodingUtil.SerializeCBOR); "
				.. "Encode (C_EncodingUtil.SerializeCBOR)"):format(total - 1, total), line())
		end)

		it("reports a timer that cannot be scheduled", function()
			ns.Compat.After = function() error("no timers") end
			run("debug selftest")
			assert.matches("After: FAILED, .*no timers", report())
			assert.matches("1 check%(s%) failed%.", report())
		end)

		it("describes the client, the character, the data and the modules", function()
			run("debug selftest")
			assert.matches("Client 12%.1%.5 %(70575%), interface 120105\n", report())
			assert.matches("Addon @project%-version@", report())
			assert.matches("Character Tester%-Realm, profile Default", report())
			assert.matches("Saved data: schema 4\n", report())
			assert.matches("Game Standard, family Mainline, project 1; data set: Mainline; locale: enUS", report())
		end)

		it("shows what WoW Forever calls itself and its data set", function()
			Test.state.printed = {}
			local fresh = Loader.LoadAddon({ gameType = "camelot" })
			Loader.Start(fresh)
			-- The project number Forever will have is not known yet.
			fresh.Compat.Test.state.projectID = nil
			fresh.Compat.Test.RunSlashCommand("LOOTOMAN", "debug selftest")
			local text = report(fresh)
			assert.matches("Game Camelot, family Mainline, project nil; data set: Forever; locale: enUS", text)
		end)

		it("shows each module with its events", function()
			Test.state.printed = {}
			local fresh = Loader.LoadAddon()
			local module = fresh.Modules:Register({
				name = "Feed",
				defaults = { enabled = true },
				OnEnable = function(self) self:OnEvent("CHAT_MSG_LOOT", function() end) end,
			})
			Loader.Start(fresh)
			fresh.Compat.Test.RunSlashCommand("LOOTOMAN", "debug selftest")
			local text = report(fresh)
			assert.is_true(module:IsActive())
			assert.matches("Module Feed: on, events: CHAT_MSG_LOOT", text)
		end)

		it("checks that a profile text reads back", function()
			run("debug selftest")
			assert.matches("Encode: OK", report())
		end)

		it("reports a profile text that does not read back", function()
			ns.Compat.Decode = function() return nil end
			run("debug selftest")
			assert.matches("Encode: FAILED, a text did not read back", report())
			assert.matches("1 check%(s%) failed%.", report())
		end)

		it("does not count a client without an encoder as a failure", function()
			Test.state.encoder = false
			run("debug selftest")
			assert.matches("Encode: not available, no C_EncodingUtil, so Import and Share are off", report())
			assert.matches("All checks passed%.", report())
		end)

		it("lists the equipped bags with their families", function()
			Test.SetBags({
				[0] = { size = 16, items = { [1] = { itemID = 2589, count = 5 } } },
				[1] = { size = 20, family = 32 },
				[5] = { size = 36 },
			})
			run("debug selftest")
			assert.matches("Bags: 0 %(16 slots, 15 free%), 1 %(20 slots, 20 free, family 32%), "
				.. "reagent 5 %(36 slots, 36 free%)\n", report())
		end)

		it("says when no bag is equipped", function()
			run("debug selftest")
			assert.matches("Bags: none\n", report())
		end)

		it("counts the chat formats the loot feed can read", function()
			Test.SetGlobalStrings(Formats.ruRU)
			run("debug selftest")
			assert.matches("Loot feed chat formats: 20 of 20\n", report())
		end)

		it("names the chat formats that are missing or unreadable", function()
			local strings = {}
			for name, format in pairs(Formats.enUS) do
				strings[name] = format
			end
			strings.LOOT_ITEM_SELF = nil
			strings.FACTION_STANDING_DECREASED = "Reputation with %s decreased by %i."
			Test.SetGlobalStrings(strings)
			run("debug selftest")
			assert.matches("Loot feed chat formats: 18 of 20; LOOT_ITEM_SELF missing, "
				.. "FACTION_STANDING_DECREASED unreadable\n", report())
			assert.matches("All checks passed%.", report())
		end)

		it("confirms timers once they run", function()
			run("debug selftest")
			assert.not_matches("After: OK", report())
			Test.Advance(0)
			assert.matches("After: OK", report())
		end)
	end)
end)
