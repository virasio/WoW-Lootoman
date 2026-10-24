local Loader = require("tests.helpers.loader")

describe("startup", function()
	local ns, Test

	before_each(function()
		ns = Loader.LoadAddon()
		Test = ns.Compat.Test
	end)

	it("waits for its own ADDON_LOADED", function()
		Test.FireEvent("ADDON_LOADED", "SomeOtherAddon")
		assert.is_nil(ns.Storage.db)
		assert.is_true(Test.IsRegistered("ADDON_LOADED"))
	end)

	it("creates and keeps the saved variables of a fresh install", function()
		Loader.Start(ns)
		assert.equals(1, Test.state.saved.LootomanDB.schema)
		assert.equals(1, Test.state.saved.LootomanCharDB.schema)
		assert.equals(ns.Storage.db, Test.state.saved.LootomanDB)
	end)

	it("chooses the character's profile and sends Ready", function()
		local ready = false
		ns.Bus:On("Ready", "test", function() ready = true end)
		Test.state.character = "Bo-Realm"
		Loader.Start(ns, {
			LootomanDB = { schema = 1, profiles = { Default = {}, Alt = {} }, profileKeys = { ["Bo-Realm"] = "Alt" }, global = {} },
		})
		assert.is_true(ready)
		assert.equals("Alt", ns.Profiles.GetCurrent())
	end)

	it("stops listening to start events once started", function()
		Loader.Start(ns)
		assert.is_false(Test.IsRegistered("ADDON_LOADED"))
		assert.is_false(Test.IsRegistered("PLAYER_LOGIN"))
	end)

	it("warns about settings from a newer version and leaves them alone", function()
		local newer = { schema = 99, profiles = {} }
		Loader.Start(ns, { LootomanDB = newer })
		assert.equals(newer, Test.state.saved.LootomanDB)
		assert.same({ schema = 99, profiles = {} }, newer)
		assert.equals(1, #Test.state.printed)
		assert.matches("newer version", Test.state.printed[1])
	end)
end)
