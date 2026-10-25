local Loader = require("tests.helpers.loader")

describe("migrations", function()
	local Migrations

	before_each(function()
		Migrations = Loader.LoadAddon().Migrations
	end)

	it("creates the current schema for a fresh install", function()
		local db, status = Migrations.Run(Migrations.account, nil)
		assert.equals("new", status)
		assert.same({ schema = 2, profiles = { Default = {} }, profileKeys = {}, global = {} }, db)
	end)

	it("leaves data at the current schema alone", function()
		local saved = { schema = 2, profiles = { Default = {}, Main = { x = 1 } }, profileKeys = {}, global = {} }
		local db, status = Migrations.Run(Migrations.account, saved)
		assert.equals("current", status)
		assert.equals(saved, db)
		assert.same({ Default = {}, Main = { x = 1 } }, db.profiles)
	end)

	it("treats data without a schema as schema 0 and repairs it", function()
		local db, status = Migrations.Run(Migrations.account, { profiles = "broken", global = { debug = true } })
		assert.equals("upgraded", status)
		assert.same({ schema = 2, profiles = { Default = {} }, profileKeys = {}, global = { debug = true } }, db)
	end)

	it("moves the loot feed's row designs from the profiles to named layouts", function()
		local changes = { row = { height = 40 } }
		local db = Migrations.Run(Migrations.account, {
			schema = 1,
			profiles = {
				Default = { sections = { feedDesign = { schema = 2, changes = changes }, positions = {} } },
				Raid = { sections = { feedDesign = { schema = 2, base = "compact" } }, modules = { LootFeed = { size = 14 } } },
				Plain = { sections = { feedDesign = { schema = 2, changes = {} } } },
				Other = {},
			},
			profileKeys = {},
			global = {},
		})
		assert.same({
			Default = { schema = 2, changes = changes },
			Raid = { schema = 2, base = "compact" },
		}, db.sections.feedLayouts)
		assert.same({
			Default = { sections = { positions = {} } },
			Raid = { sections = {}, modules = { LootFeed = { size = 14, layout = "Raid" } } },
			Plain = { sections = {} },
			Other = {},
		}, db.profiles)
	end)

	it("runs every missing step in order", function()
		local ran = {}
		local steps = {
			function() ran[#ran + 1] = 1 end,
			function() ran[#ran + 1] = 2 end,
			function(data) ran[#ran + 1] = 3; data.done = true end,
		}
		local data, status = Migrations.Run(steps, { schema = 1 })
		assert.equals("upgraded", status)
		assert.same({ 2, 3 }, ran)
		assert.same({ schema = 3, done = true }, data)
	end)

	it("returns data from a newer version untouched", function()
		local saved = { schema = 99, profiles = "something new" }
		local db, status = Migrations.Run(Migrations.account, saved)
		assert.equals("newer", status)
		assert.equals(saved, db)
		assert.same({ schema = 99, profiles = "something new" }, db)
	end)

	it("creates the per-character table", function()
		local charDB, status = Migrations.Run(Migrations.character, nil)
		assert.equals("new", status)
		assert.same({ schema = 1 }, charDB)
	end)
end)
