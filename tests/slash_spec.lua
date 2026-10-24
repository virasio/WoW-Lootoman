local Loader = require("tests.helpers.loader")

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
		run("dance")
		assert.matches("Commands:", printed[1])
		assert.matches("Commands:", printed[5])
		assert.equals(8, #printed)
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

		it("describes the client, the character, the data and the modules", function()
			run("selftest")
			assert.matches("Client 12%.1%.5 %(70575%), interface 120105; addon @project%-version@", output())
			assert.matches("Character Tester%-Realm, profile Default", output())
			assert.matches("Saved data: schema 1\n", output())
			assert.matches("Data set: Mainline; locale: enUS", output())
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

		it("confirms timers once they run", function()
			run("selftest")
			assert.not_matches("After: OK", output())
			Test.Advance(0)
			assert.matches("After: OK", output())
		end)
	end)
end)
