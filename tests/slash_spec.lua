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

	it("list the commands for help and for an unknown one", function()
		run("help")
		local lines = #printed
		run("dance")
		assert.matches("Commands:", printed[1])
		assert.matches("Commands:", printed[lines + 1])
		assert.equals(2 * lines, #printed)
		assert.matches("/lootoman design", table.concat(printed, "\n"))
	end)

	describe("debug", function()
		local function debugOn()
			return ns.Storage:GetGlobal("debug")
		end

		it("shows the switch without changing it", function()
			run("debug")
			assert.is_false(debugOn())
			assert.matches("off for all characters%.", printed[1])
			ns.Storage:SetGlobal("debug", true)
			run("DEBUG")
			assert.is_true(debugOn())
			assert.matches("on for all characters%.", printed[2])
		end)

		for _, value in ipairs({ "on", "On", "ON", "1" }) do
			it("turns debug messages on with “" .. value .. "”", function()
				run("debug " .. value)
				assert.is_true(debugOn())
				assert.matches("on for all characters%.", printed[1])
			end)
		end

		for _, value in ipairs({ "off", "Off", "OFF", "0" }) do
			it("turns debug messages off with “" .. value .. "”", function()
				ns.Storage:SetGlobal("debug", true)
				run("debug " .. value)
				assert.is_false(debugOn())
				assert.matches("off for all characters%.", printed[1])
			end)
		end

		it("explains an unknown value and changes nothing", function()
			ns.Storage:SetGlobal("debug", true)
			run("debug  maybe ")
			assert.is_true(debugOn())
			assert.equals(1, #printed)
			assert.matches("Unknown value “maybe”", printed[1])
		end)

		it("prints debug messages only while it is on", function()
			ns.Debug("hidden")
			run("debug on")
			ns.Debug("shown")
			run("debug off")
			ns.Debug("hidden again")
			assert.equals(3, #printed)
			assert.matches("shown", printed[2])
		end)
	end)

	describe("selftest", function()
		it("passes every check on a working client", function()
			run(" SelfTest ")
			assert.not_matches("FAILED", output())
			assert.matches("All checks passed%.", output())
			assert.matches("Has: OK", output())
			assert.matches("RegisterEvent: OK", output())
		end)

		it("reports a failing check", function()
			Test.state.capabilities["C_AddOns.GetAddOnMetadata"] = nil
			run("selftest")
			assert.matches("Has: FAILED, wrong answer", output())
			assert.matches("1 check%(s%) failed%.", output())
		end)

		it("reports a check that raises an error", function()
			Test.state.build = {}
			run("selftest")
			assert.matches("GetBuildInfo: FAILED", output())
		end)

		it("finishes the report when game calls raise errors", function()
			ns.Compat.GetBuildInfo = function() error("broken build info") end
			ns.Compat.GetAddOnMetadata = function() error("broken metadata") end
			run("selftest")
			assert.matches("GetBuildInfo: FAILED", output())
			assert.matches("GetAddOnMetadata: FAILED", output())
			assert.matches("%(.*broken build info%)", output())
			assert.matches("%(.*broken metadata%)", output())
			assert.matches("Character Tester%-Realm", output())
			assert.equals("2 check(s) failed.", printed[#printed]:match("[%d]+ check%(s%) failed%."))
		end)

		it("reports a timer that cannot be scheduled", function()
			ns.Compat.After = function() error("no timers") end
			run("selftest")
			assert.matches("After: FAILED, .*no timers", output())
			assert.matches("1 check%(s%) failed%.", output())
		end)

		it("describes the client, the character, the data and the modules", function()
			run("selftest")
			assert.matches("Client 12%.1%.5 %(70575%), interface 120105\n", output())
			assert.matches("Addon @project%-version@", output())
			assert.matches("Character Tester%-Realm, profile Default", output())
			assert.matches("Saved data: schema 1\n", output())
			assert.matches("Game Standard, family Mainline; data set: Mainline; locale: enUS", output())
		end)

		it("shows what WoW Forever calls itself and its data set", function()
			Test.state.printed = {}
			local fresh = Loader.LoadAddon({ gameType = "camelot" })
			Loader.Start(fresh)
			fresh.Compat.Test.RunSlashCommand("LOOTOMAN", "selftest")
			local text = table.concat(fresh.Compat.Test.state.printed, "\n")
			assert.matches("Game Camelot, family Mainline; data set: Forever; locale: enUS", text)
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
			fresh.Compat.Test.RunSlashCommand("LOOTOMAN", "selftest")
			local text = table.concat(fresh.Compat.Test.state.printed, "\n")
			assert.is_true(module:IsActive())
			assert.matches("Module Feed: on, events: CHAT_MSG_LOOT", text)
		end)

		it("checks that a profile text reads back", function()
			run("selftest")
			assert.matches("Encode: OK", output())
		end)

		it("reports a profile text that does not read back", function()
			ns.Compat.Decode = function() return nil end
			run("selftest")
			assert.matches("Encode: FAILED, a text did not read back", output())
			assert.matches("1 check%(s%) failed%.", output())
		end)

		it("does not count a client without an encoder as a failure", function()
			Test.state.encoder = false
			run("selftest")
			assert.matches("Encode: not available, no C_EncodingUtil, so Import and Share are off", output())
			assert.matches("All checks passed%.", output())
		end)

		it("lists the equipped bags with their families", function()
			Test.SetBags({
				[0] = { size = 16, items = { [1] = { itemID = 2589, count = 5 } } },
				[1] = { size = 20, family = 32 },
				[5] = { size = 36 },
			})
			run("selftest")
			assert.matches("Bags: 0 %(16 slots, 15 free%), 1 %(20 slots, 20 free, family 32%), "
				.. "reagent 5 %(36 slots, 36 free%)\n", output())
		end)

		it("says when no bag is equipped", function()
			run("selftest")
			assert.matches("Bags: none\n", output())
		end)

		it("counts the chat formats the loot feed can read", function()
			Test.SetGlobalStrings(Formats.ruRU)
			run("selftest")
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
			run("selftest")
			assert.matches("Loot feed chat formats: 18 of 20; LOOT_ITEM_SELF missing, "
				.. "FACTION_STANDING_DECREASED unreadable\n", output())
			assert.matches("All checks passed%.", output())
		end)

		it("confirms timers once they run", function()
			run("selftest")
			assert.not_matches("After: OK", output())
			Test.Advance(0)
			assert.matches("After: OK", output())
		end)
	end)
end)
