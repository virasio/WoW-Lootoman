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

	it("list the commands for an unknown one", function()
		run("dance")
		assert.matches("Commands:", printed[1])
		assert.equals(4, #printed)
	end)

	describe("debug", function()
		it("turns debug messages on and off, account-wide", function()
			ns.Debug("hidden")
			run("debug")
			ns.Debug("shown")
			run("DEBUG")
			ns.Debug("hidden again")
			assert.equals(3, #printed)
			assert.matches("on%.", printed[1])
			assert.matches("shown", printed[2])
			assert.matches("off%.", printed[3])
			assert.is_false(ns.Storage:GetGlobal("debug"))
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
