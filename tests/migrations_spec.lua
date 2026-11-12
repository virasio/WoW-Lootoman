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

	it("turns the owned count off in the profiles of a layout that hid it, and drops that switch from layouts", function()
		local saved = {
			schema = 1,
			profileKeys = {},
			global = {},
			profiles = {
				Default = { modules = { LootFeed = { layout = "Quiet" } } },
				Raid = { modules = { LootFeed = { layout = "Shown" }, AutoLoot = { confirmBind = false } } },
				-- On the Default layout, which hides it too.
				Alt = {},
			},
			sections = { feedLayouts = {
				Default = { schema = 1, base = "large", changes = { owned = { shown = false } } },
				Quiet = { schema = 1, base = "compact", changes = { owned = { shown = false, x = 2 }, row = { gap = 2 } } },
				Shown = { schema = 1, base = "minimal", changes = { owned = { shown = true } } },
			} },
		}
		local db = Migrations.Run(Migrations.account, saved)
		assert.same({ layout = "Quiet", owned = false }, db.profiles.Default.modules.LootFeed)
		assert.same({ LootFeed = { layout = "Shown" }, AutoLoot = { confirmBind = false } }, db.profiles.Raid.modules)
		assert.same({ modules = { LootFeed = { owned = false } } }, db.profiles.Alt)
		assert.same({ owned = { x = 2 }, row = { gap = 2 } }, db.sections.feedLayouts.Quiet.changes)
		assert.same({ nil, nil }, { db.sections.feedLayouts.Shown.changes, db.sections.feedLayouts.Default.changes })
	end)

	it("gives the loot feed at least 3 rows", function()
		local db = Migrations.Run(Migrations.account, { schema = 1, profiles = {
			One = { modules = { LootFeed = { maxRows = 1 } } },
			Five = { modules = { LootFeed = { maxRows = 5 } } },
		} })
		assert.same({ 3, 5 }, { db.profiles.One.modules.LootFeed.maxRows, db.profiles.Five.modules.LootFeed.maxRows })
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
