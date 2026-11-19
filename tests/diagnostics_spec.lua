local Loader = require("tests.helpers.loader")

describe("diagnostics", function()
	local ns, Test

	local function section()
		local sections = Test.state.saved.LootomanDB.sections or {}
		return sections.diagnostics
	end

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon())
		Test = ns.Compat.Test
	end)

	it("keep the last self-test's lines, the client and when it ran", function()
		Test.state.time = 120.5
		Test.RunSlashCommand("LOOTOMAN", "debug selftest")
		Test.Advance(0)
		local saved = section().selfTest
		assert.same({ 120.5, "12.1.5 (70575)" }, { saved.at, saved.client })
		assert.equals("Self-test", saved.lines[1])
		local text = table.concat(saved.lines, "\n")
		assert.matches("Character Tester%-Realm", text)
		-- The timer's line comes a moment later, and is kept too.
		assert.matches("After: OK", text)
		-- Without the chat prefix.
		assert.not_matches("Lootoman|r: ", text)
		-- Only the last run.
		Test.RunSlashCommand("LOOTOMAN", "debug selftest")
		assert.equals(1, select(2, table.concat(section().selfTest.lines, "\n"):gsub("Self%-test", "")))
	end)

	it("log debug messages while they are on, the last 300 in order, with the session time", function()
		ns.Debug("before")
		assert.is_true(section() == nil or #section().log == 0)
		Test.RunSlashCommand("LOOTOMAN", "debug log on")
		Test.state.time = 10
		ns.Debug("first")
		assert.equals("10.00 first", section().log[1])
		for index = 2, 310 do
			ns.Debug("line " .. index)
		end
		local log = section().log
		assert.same({ 300, "10.00 line 11", "10.00 line 310" }, { #log, log[1], log[300] })
		-- Turning debug off keeps the log, and logs nothing more.
		Test.RunSlashCommand("LOOTOMAN", "debug log off")
		ns.Debug("after")
		assert.same({ 300, "10.00 line 310" }, { #section().log, section().log[300] })
	end)

	it("never stop the self-test, which runs to its end when the settings could not be loaded", function()
		ns.Storage.db = nil
		local text = table.concat((ns.SelfTest.Run()), "\n")
		assert.matches("Self%-test", text)
		assert.matches("check%(s%) failed%.", text)
		-- Nothing to clear, and nothing breaks.
		Test.RunSlashCommand("LOOTOMAN", "debug log clear")
		assert.matches("cleared", Test.state.printed[#Test.state.printed])
	end)

	it("take the debug command in any letter case", function()
		Test.RunSlashCommand("LOOTOMAN", "DEBUG log On")
		assert.is_true(ns.Storage:GetGlobal("debug"))
		ns.Debug("something")
		Test.RunSlashCommand("LOOTOMAN", "debug log CLEAR")
		assert.same({}, section().log)
		assert.is_true(ns.Storage:GetGlobal("debug"))
		Test.RunSlashCommand("LOOTOMAN", "Debug log OFF")
		assert.is_false(ns.Storage:GetGlobal("debug"))
	end)

	it("are cleared by /lootoman debug clear", function()
		Test.RunSlashCommand("LOOTOMAN", "debug log on")
		ns.Debug("something")
		Test.RunSlashCommand("LOOTOMAN", "debug selftest")
		Test.RunSlashCommand("LOOTOMAN", "debug log clear")
		assert.same({}, section().log)
		assert.is_nil(section().selfTest)
		assert.matches("cleared", Test.state.printed[#Test.state.printed])
		-- Debug stays as it was.
		assert.is_true(ns.Storage:GetGlobal("debug"))
	end)

	it("are no part of a profile text", function()
		Test.RunSlashCommand("LOOTOMAN", "debug log on")
		ns.Debug("secret line")
		Test.RunSlashCommand("LOOTOMAN", "debug selftest")
		local text = assert(ns.Share.Export({ parts = { "module:AutoLoot" } }))
		local data = Test.state.encoded[tonumber(text:match("ENC(%d+)$"))]
		local function holds(value)
			if type(value) == "table" then
				for key, item in pairs(value) do
					if holds(key) or holds(item) then
						return true
					end
				end
			end
			return value == "diagnostics" or value == "10.00 secret line"
				or (type(value) == "string" and value:find("secret line", 1, true) ~= nil)
		end
		assert.is_false(holds(data))
	end)
end)
