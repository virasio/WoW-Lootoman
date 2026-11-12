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

	it("hides the owned count in the layout of a profile that turned it off, and drops the profile's switch", function()
		local saved = {
			schema = 1,
			profileKeys = {},
			global = {},
			profiles = {
				Default = { modules = { LootFeed = { layout = "Quiet", owned = false } } },
				Raid = { modules = { LootFeed = { owned = true, layout = "Shown" }, AutoLoot = { confirmBind = false } } },
				-- On the Default layout, which the saved data does not hold yet.
				Alt = { modules = { LootFeed = { owned = false } } },
			},
			sections = { feedLayouts = {
				Quiet = { schema = 1, base = "compact", changes = { row = { gap = 2 } } },
				Shown = { schema = 1, base = "minimal", changes = { owned = { shown = true } } },
			} },
		}
		local db = Migrations.Run(Migrations.account, saved)
		assert.same({ layout = "Quiet" }, db.profiles.Default.modules.LootFeed)
		assert.same({ LootFeed = { layout = "Shown" }, AutoLoot = { confirmBind = false } }, db.profiles.Raid.modules)
		assert.same({ modules = {} }, db.profiles.Alt)
		local layouts = db.sections.feedLayouts
		assert.same({ owned = { shown = false }, row = { gap = 2 } }, layouts.Quiet.changes)
		assert.same({ owned = { shown = true } }, layouts.Shown.changes)
		assert.same({ schema = 1, base = "large", changes = { owned = { shown = false } } }, layouts.Default)
	end)

	it("hides the owned count in Default for a profile whose layout is gone, as it uses Default", function()
		local db = Migrations.Run(Migrations.account, { schema = 1, profiles = {
			Gone = { modules = { LootFeed = { layout = "Deleted", owned = false } } },
		}, sections = { feedLayouts = { Other = { schema = 1, base = "compact" } } } })
		local layouts = db.sections.feedLayouts
		assert.same({ schema = 1, base = "large", changes = { owned = { shown = false } } }, layouts.Default)
		assert.same({ nil, { schema = 1, base = "compact" } }, { layouts.Deleted, layouts.Other })
		assert.same({ layout = "Deleted" }, db.profiles.Gone.modules.LootFeed)
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
