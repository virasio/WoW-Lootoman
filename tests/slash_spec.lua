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

	describe("debug", function()
		local function debugOn()
			return ns.Storage:GetGlobal("debug")
		end

		it("shows the switch without changing it", function()
			run("debug log")
			assert.is_false(debugOn())
			assert.matches("off for all characters%.", printed[1])
			ns.Storage:SetGlobal("debug", true)
			run("DEBUG LOG")
			assert.is_true(debugOn())
			assert.matches("on for all characters%.", printed[2])
		end)

		for _, value in ipairs({ "on", "On", "ON", "1" }) do
			it("turns debug messages on with “" .. value .. "”", function()
				run("debug log " .. value)
				assert.is_true(debugOn())
				assert.matches("on for all characters%.", printed[1])
			end)
		end

		for _, value in ipairs({ "off", "Off", "OFF", "0" }) do
			it("turns debug messages off with “" .. value .. "”", function()
				ns.Storage:SetGlobal("debug", true)
				run("debug log " .. value)
				assert.is_false(debugOn())
				assert.matches("off for all characters%.", printed[1])
			end)
		end

		it("explains an unknown value and changes nothing", function()
			ns.Storage:SetGlobal("debug", true)
			run("debug log  maybe ")
			assert.is_true(debugOn())
			assert.equals(1, #printed)
			assert.matches("Unknown value “maybe”", printed[1])
		end)

		it("prints debug messages only while it is on", function()
			ns.Debug("hidden")
			run("debug log on")
			ns.Debug("shown")
			run("debug log off")
			ns.Debug("hidden again")
			assert.equals(3, #printed)
			assert.matches("shown", printed[2])
		end)
	end)

	describe("selftest", function()
		it("passes every check on a working client", function()
			run(" debug SelfTest ")
			assert.not_matches("FAILED", output())
			assert.matches("All checks passed%.", output())
			assert.matches("Has: OK", output())
			assert.matches("RegisterEvent: OK", output())
		end)

		it("reports a failing check", function()
			Test.state.capabilities["C_AddOns.GetAddOnMetadata"] = nil
			run("debug selftest")
			assert.matches("Has: FAILED, wrong answer", output())
			assert.matches("1 check%(s%) failed%.", output())
		end)

		it("reports a check that raises an error", function()
			Test.state.build = {}
			run("debug selftest")
			assert.matches("GetBuildInfo: FAILED", output())
		end)

		it("finishes the report when game calls raise errors", function()
			ns.Compat.GetBuildInfo = function() error("broken build info") end
			ns.Compat.GetAddOnMetadata = function() error("broken metadata") end
			run("debug selftest")
			assert.matches("GetBuildInfo: FAILED", output())
			assert.matches("GetAddOnMetadata: FAILED", output())
			assert.matches("%(.*broken build info%)", output())
			assert.matches("%(.*broken metadata%)", output())
			assert.matches("Character Tester%-Realm", output())
			assert.equals("2 check(s) failed.", printed[#printed]:match("[%d]+ check%(s%) failed%."))
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
				for _, text in ipairs(printed) do
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
			assert.matches("After: FAILED, .*no timers", output())
			assert.matches("1 check%(s%) failed%.", output())
		end)

		it("describes the client, the character, the data and the modules", function()
			run("debug selftest")
			assert.matches("Client 12%.1%.5 %(70575%), interface 120105\n", output())
			assert.matches("Addon @project%-version@", output())
			assert.matches("Character Tester%-Realm, profile Default", output())
			assert.matches("Saved data: schema 4\n", output())
			assert.matches("Game Standard, family Mainline, project 1; data set: Mainline; locale: enUS", output())
		end)

		it("shows what WoW Forever calls itself and its data set", function()
			Test.state.printed = {}
			local fresh = Loader.LoadAddon({ gameType = "camelot" })
			Loader.Start(fresh)
			-- The project number Forever will have is not known yet.
			fresh.Compat.Test.state.projectID = nil
			fresh.Compat.Test.RunSlashCommand("LOOTOMAN", "debug selftest")
			local text = table.concat(fresh.Compat.Test.state.printed, "\n")
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
			local text = table.concat(fresh.Compat.Test.state.printed, "\n")
			assert.is_true(module:IsActive())
			assert.matches("Module Feed: on, events: CHAT_MSG_LOOT", text)
		end)

		it("checks that a profile text reads back", function()
			run("debug selftest")
			assert.matches("Encode: OK", output())
		end)

		it("reports a profile text that does not read back", function()
			ns.Compat.Decode = function() return nil end
			run("debug selftest")
			assert.matches("Encode: FAILED, a text did not read back", output())
			assert.matches("1 check%(s%) failed%.", output())
		end)

		it("does not count a client without an encoder as a failure", function()
			Test.state.encoder = false
			run("debug selftest")
			assert.matches("Encode: not available, no C_EncodingUtil, so Import and Share are off", output())
			assert.matches("All checks passed%.", output())
		end)

		it("lists the equipped bags with their families", function()
			Test.SetBags({
				[0] = { size = 16, items = { [1] = { itemID = 2589, count = 5 } } },
				[1] = { size = 20, family = 32 },
				[5] = { size = 36 },
			})
			run("debug selftest")
			assert.matches("Bags: 0 %(16 slots, 15 free%), 1 %(20 slots, 20 free, family 32%), "
				.. "reagent 5 %(36 slots, 36 free%)\n", output())
		end)

		it("says when no bag is equipped", function()
			run("debug selftest")
			assert.matches("Bags: none\n", output())
		end)

		it("counts the chat formats the loot feed can read", function()
			Test.SetGlobalStrings(Formats.ruRU)
			run("debug selftest")
			assert.matches("Loot feed chat formats: 20 of 20\n", output())
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
				.. "FACTION_STANDING_DECREASED unreadable\n", output())
			assert.matches("All checks passed%.", output())
		end)

		it("confirms timers once they run", function()
			run("debug selftest")
			assert.not_matches("After: OK", output())
			Test.Advance(0)
			assert.matches("After: OK", output())
		end)
	end)
end)
