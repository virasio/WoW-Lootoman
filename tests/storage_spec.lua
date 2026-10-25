local Loader = require("tests.helpers.loader")

describe("storage", function()
	local ns, Storage, Bus, changes

	before_each(function()
		ns = Loader.LoadAddon()
		Storage, Bus = ns.Storage, ns.Bus
		Storage:RegisterDefaults("Feed", { enabled = true, rows = 5, anchor = "TOP" })
		Storage:RegisterGlobalDefaults({ testFlag = false })
		changes = {}
		Bus:On("SettingChanged", "test", function(_, ...) changes[#changes + 1] = { ... } end)
		Bus:On("GlobalSettingChanged", "test", function(_, ...) changes[#changes + 1] = { "global", ... } end)
	end)

	local function load(account, character)
		local db, charDB = Storage:Load(account, character)
		Storage:SetCharacter("Ana-Realm")
		return db, charDB
	end

	it("returns defaults when nothing is saved", function()
		load(nil, nil)
		assert.is_true(Storage:Get("Feed", "enabled"))
		assert.equals(5, Storage:Get("Feed", "rows"))
		assert.is_false(Storage:GetGlobal("testFlag"))
	end)

	it("saves only values that differ from the defaults", function()
		local db = load(nil, nil)
		Storage:Set("Feed", "rows", 8)
		Storage:Set("Feed", "enabled", true)
		assert.same({ modules = { Feed = { rows = 8 } } }, db.profiles.Default)
		assert.equals(8, Storage:Get("Feed", "rows"))
	end)

	it("forgets a value set back to its default", function()
		local db = load(nil, nil)
		Storage:Set("Feed", "rows", 8)
		Storage:Set("Feed", "rows", 5)
		assert.same({}, db.profiles.Default)
	end)

	it("announces a changed value once", function()
		load(nil, nil)
		Storage:Set("Feed", "rows", 8)
		Storage:Set("Feed", "rows", 8)
		Storage:SetGlobal("testFlag", true)
		assert.same({ { "Feed", "rows", 8 }, { "global", "testFlag", true } }, changes)
	end)

	it("rejects unknown settings and values of the wrong type", function()
		load(nil, nil)
		assert.has_error(function() Storage:Get("Feed", "missing") end)
		assert.has_error(function() Storage:Get("Missing", "enabled") end)
		assert.has_error(function() Storage:Set("Feed", "rows", "eight") end)
		assert.has_error(function() Storage:GetGlobal("missing") end)
	end)

	it("rejects defaults that are not plain values", function()
		assert.has_error(function() Storage:RegisterDefaults("Bad", { color = { 1, 1, 1 } }) end)
		assert.has_error(function() Storage:RegisterDefaults("Feed", { enabled = false }) end)
	end)

	it("ignores a saved value of the wrong type", function()
		load({ schema = 1, profiles = { Default = { modules = { Feed = { rows = "8" } } } }, profileKeys = {}, global = {} })
		assert.equals(5, Storage:Get("Feed", "rows"))
	end)

	it("reads the profile of the current character", function()
		load({
			schema = 1,
			profiles = { Default = {}, Alt = { modules = { Feed = { rows = 2 } } } },
			profileKeys = { ["Bo-Realm"] = "Alt" },
			global = {},
		})
		assert.equals(5, Storage:Get("Feed", "rows"))
		Storage:SetCharacter("Bo-Realm")
		assert.equals("Alt", Storage:GetProfileName())
		assert.equals(2, Storage:Get("Feed", "rows"))
	end)

	it("falls back to Default when the character's profile is gone", function()
		load({ schema = 1, profiles = { Default = {} }, profileKeys = { ["Ana-Realm"] = "Deleted" }, global = {} })
		assert.equals("Default", Storage:GetProfileName())
	end)

	describe("sections", function()
		it("are tables in the current profile, created on first use", function()
			local db = load(nil, nil)
			local positions = Storage:GetSection("positions")
			positions.LootFeed = { Modern = { "CENTER", 200, 0 } }
			assert.equals(positions, Storage:GetSection("positions"))
			assert.same({ sections = { positions = { LootFeed = { Modern = { "CENTER", 200, 0 } } } } }, db.profiles.Default)
		end)

		it("are kept apart by name", function()
			load(nil, nil)
			assert.are_not.equal(Storage:GetSection("positions"), Storage:GetSection("rules"))
		end)

		it("follow the profile of the current character", function()
			load({ schema = 1, profiles = { Default = {}, Alt = {} }, profileKeys = { ["Bo-Realm"] = "Alt" }, global = {} })
			Storage:GetSection("positions").frame = "Ana"
			Storage:SetCharacter("Bo-Realm")
			assert.same({}, Storage:GetSection("positions"))
		end)

		it("replace saved values that are not tables", function()
			local db = load({ schema = 1, profiles = { Default = { sections = { positions = 5 } }, Alt = { sections = "x" } }, profileKeys = { ["Bo-Realm"] = "Alt" }, global = {} })
			assert.same({}, Storage:GetSection("positions"))
			Storage:SetCharacter("Bo-Realm")
			assert.same({}, Storage:GetSection("positions"))
			assert.same({ sections = { positions = {} } }, db.profiles.Alt)
		end)

		it("need a name", function()
			load(nil, nil)
			assert.has_error(function() Storage:GetSection() end)
		end)
	end)

	it("returns the saved tables to keep", function()
		local account, character = { schema = 1, profiles = { Default = {} }, profileKeys = {}, global = {} }, { schema = 1 }
		local db, charDB = load(account, character)
		assert.equals(account, db)
		assert.equals(character, charDB)
		assert.is_false(Storage.readOnly)
	end)

	it("keeps data from a newer version untouched and works on defaults in memory", function()
		local account = { schema = 99, profiles = { Default = { modules = { Feed = { rows = 9 } } } } }
		local db = load(account, nil)
		assert.is_true(Storage.readOnly)
		assert.equals(account, db)
		assert.equals(5, Storage:Get("Feed", "rows"))
		Storage:Set("Feed", "rows", 3)
		assert.equals(3, Storage:Get("Feed", "rows"))
		assert.same({ schema = 99, profiles = { Default = { modules = { Feed = { rows = 9 } } } } }, account)
	end)
end)
