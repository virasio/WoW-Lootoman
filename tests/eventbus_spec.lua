local Loader = require("tests.helpers.loader")

describe("event bus", function()
	local ns, Bus, Test

	before_each(function()
		ns = Loader.LoadAddon()
		Bus, Test = ns.Bus, ns.Compat.Test
	end)

	it("delivers messages with their name and payload, in the order listeners were added", function()
		local received = {}
		Bus:On("Ping", "a", function(...) received[#received + 1] = { "a", ... } end)
		Bus:On("Ping", "b", function(...) received[#received + 1] = { "b", ... } end)
		Bus:Send("Ping", 1, nil, 3)
		assert.same({ { "a", "Ping", 1, nil, 3 }, { "b", "Ping", 1, nil, 3 } }, received)
	end)

	it("keeps one listener per owner and name", function()
		local calls = {}
		Bus:On("Ping", "a", function() calls[#calls + 1] = "old" end)
		Bus:On("Ping", "a", function() calls[#calls + 1] = "new" end)
		Bus:Send("Ping")
		assert.same({ "new" }, calls)
	end)

	it("stops delivering to a removed listener", function()
		local calls = {}
		Bus:On("Ping", "a", function() calls[#calls + 1] = "a" end)
		Bus:On("Ping", "b", function() calls[#calls + 1] = "b" end)
		Bus:Off("Ping", "a")
		Bus:Send("Ping")
		assert.same({ "b" }, calls)
	end)

	it("registers a game event only while it has listeners", function()
		Bus:OnEvent("BAG_UPDATE", "a", function() end)
		Bus:OnEvent("BAG_UPDATE", "b", function() end)
		assert.is_true(Test.IsRegistered("BAG_UPDATE"))
		Bus:OffEvent("BAG_UPDATE", "a")
		assert.is_true(Test.IsRegistered("BAG_UPDATE"))
		Bus:OffEvent("BAG_UPDATE", "b")
		assert.is_false(Test.IsRegistered("BAG_UPDATE"))
	end)

	it("passes game events and their arguments to listeners", function()
		local received
		Bus:OnEvent("BAG_UPDATE", "a", function(...) received = { ... } end)
		Test.FireEvent("BAG_UPDATE", 2)
		assert.same({ "BAG_UPDATE", 2 }, received)
	end)

	it("removes everything of one owner at once", function()
		local calls = {}
		Bus:On("Ping", "module", function() calls[#calls + 1] = "module" end)
		Bus:On("Ping", "other", function() calls[#calls + 1] = "other" end)
		Bus:OnEvent("BAG_UPDATE", "module", function() end)
		Bus:OnEvent("PLAYER_MONEY", "module", function() end)
		Bus:OnEvent("PLAYER_MONEY", "other", function() end)
		assert.same({ "BAG_UPDATE", "PLAYER_MONEY" }, Bus:GetEvents("module"))

		Bus:OffAll("module")

		Bus:Send("Ping")
		assert.same({ "other" }, calls)
		assert.same({}, Bus:GetEvents("module"))
		assert.is_false(Test.IsRegistered("BAG_UPDATE"))
		assert.is_true(Test.IsRegistered("PLAYER_MONEY"))
	end)

	it("reports an error in one listener and still calls the others", function()
		local called = false
		Bus:On("Ping", "broken", function() error("boom") end)
		Bus:On("Ping", "fine", function() called = true end)
		Bus:Send("Ping")
		assert.is_true(called)
		assert.equals(1, #Test.state.errors)
		assert.matches("boom", Test.state.errors[1])
	end)

	it("does not call a listener removed during the same dispatch", function()
		local calls = {}
		Bus:On("Ping", "a", function()
			calls[#calls + 1] = "a"
			Bus:Off("Ping", "b")
		end)
		Bus:On("Ping", "b", function() calls[#calls + 1] = "b" end)
		Bus:Send("Ping")
		assert.same({ "a" }, calls)
	end)

	it("calls a listener added during a dispatch from the next message on", function()
		local calls = {}
		local added = false
		Bus:On("Ping", "a", function()
			calls[#calls + 1] = "a"
			if not added then
				added = true
				Bus:On("Ping", "b", function() calls[#calls + 1] = "b" end)
			end
		end)
		Bus:Send("Ping")
		assert.same({ "a" }, calls)
		Bus:Send("Ping")
		assert.same({ "a", "a", "b" }, calls)
	end)

	it("stops a replaced listener at once, even during a dispatch", function()
		local calls = {}
		Bus:On("Ping", "a", function()
			calls[#calls + 1] = "a"
			Bus:On("Ping", "b", function() calls[#calls + 1] = "new b" end)
		end)
		Bus:On("Ping", "b", function() calls[#calls + 1] = "old b" end)
		Bus:Send("Ping")
		assert.same({ "a" }, calls)
	end)
end)
