local Loader = require("tests.helpers.loader")

describe("migrations", function()
	local Migrations

	before_each(function()
		Migrations = Loader.LoadAddon().Migrations
	end)

	it("creates the current schema for a fresh install", function()
		local db, status = Migrations.Run(Migrations.account, nil)
		assert.equals("new", status)
		assert.same({ schema = #Migrations.account, profiles = { Default = {} }, profileKeys = {}, global = {} }, db)
	end)

	it("leaves data at the current schema alone", function()
		local saved = { schema = #Migrations.account, profiles = { Default = {}, Main = { x = 1 } }, profileKeys = {}, global = {} }
		local db, status = Migrations.Run(Migrations.account, saved)
		assert.equals("current", status)
		assert.equals(saved, db)
		assert.same({ Default = {}, Main = { x = 1 } }, db.profiles)
	end)

	it("treats data without a schema as schema 0 and repairs it", function()
		local db, status = Migrations.Run(Migrations.account, { profiles = "broken", global = { debug = true } })
		assert.equals("upgraded", status)
		assert.same({ schema = #Migrations.account, profiles = { Default = {} }, profileKeys = {}, global = { debug = true } }, db)
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
		local db = Migrations.Run({ Migrations.account[1], Migrations.account[2] }, saved)
		assert.same({ layout = "Quiet" }, db.profiles.Default.modules.LootFeed)
		assert.same({ LootFeed = { layout = "Shown" }, AutoLoot = { confirmBind = false } }, db.profiles.Raid.modules)
		assert.same({ modules = {} }, db.profiles.Alt)
		local layouts = db.sections.feedLayouts
		assert.same({ owned = { shown = false }, row = { gap = 2 } }, layouts.Quiet.changes)
		assert.same({ owned = { shown = true } }, layouts.Shown.changes)
		assert.same({ schema = 1, base = "large", changes = { owned = { shown = false } } }, layouts.Default)
	end)

	it("hides the owned count in Default for a profile whose layout is gone, as it uses Default", function()
		local db = Migrations.Run({ Migrations.account[1], Migrations.account[2] }, { schema = 1, profiles = {
			Gone = { modules = { LootFeed = { layout = "Deleted", owned = false } } },
		}, sections = { feedLayouts = { Other = { schema = 1, base = "compact" } } } })
		local layouts = db.sections.feedLayouts
		assert.same({ schema = 1, base = "large", changes = { owned = { shown = false } } }, layouts.Default)
		assert.same({ nil, { schema = 1, base = "compact" } }, { layouts.Deleted, layouts.Other })
		assert.same({ layout = "Deleted" }, db.profiles.Gone.modules.LootFeed)
	end)

	it("gives the loot feed at least 3 rows", function()
		local db = Migrations.Run({ Migrations.account[1], Migrations.account[2] }, { schema = 1, profiles = {
			One = { modules = { LootFeed = { maxRows = 1 } } },
			Five = { modules = { LootFeed = { maxRows = 5 } } },
		} })
		assert.same({ 3, 5 }, { db.profiles.One.modules.LootFeed.maxRows, db.profiles.Five.modules.LootFeed.maxRows })
	end)

	describe("of the loot feed's settings and layouts into feed looks", function()
		-- 0.4's defaults where a look's differ: what a profile without values had.
		local OLD = { xp = false, keepRecipes = true, keepPets = true, keepMounts = true, keepToys = true, keepSets = true,
			keepHeirlooms = true, maxRows = 8, size = 13, backgroundOpacity = 50, warnGeneralAt = 2, warnReagent = false }

		local function with(changes)
			local values = {}
			for key, value in pairs(OLD) do
				values[key] = value
			end
			for key, value in pairs(changes) do
				if value == "nil" then
					values[key] = nil
				else
					values[key] = value
				end
			end
			return values
		end

		it("makes a look of each layout and its profiles' settings, kept as 0.4 showed them", function()
			local db = dofile("tests/fixtures/saved_0_4.lua")().LootomanDB
			Migrations.FeedLooks(db)
			local looks = db.sections.feedLooks
			assert.same({
				schema = 1, base = "icons",
				changes = { amount = { fontSize = 15, background = true }, owned = { shown = true, count = "all" } },
				values = with({ maxRows = 6, keepPets = "nil", direction = "left" }),
			}, looks.Strip)
			assert.same({
				schema = 1, base = "compact", changes = { owned = { shown = false, count = "all" } },
				values = with({ size = 14, xp = "nil" }),
			}, looks.Quiet)
			assert.same({ schema = 1, base = "large", changes = { owned = { shown = true, count = "all" } }, values = OLD }, looks.Default)
			-- A layout no profile used is kept as a look too.
			assert.same({ schema = 1, base = "minimal", changes = { owned = { count = "all" } }, values = OLD }, looks.Spare)
			-- The profiles name their looks; the moved values go; the rest stays.
			local profiles = db.profiles
			assert.same({ { look = "Strip" }, { look = "Quiet" }, { look = "Quiet" }, { enabled = false } }, { profiles.Default.modules.LootFeed,
				profiles.Raid.modules.LootFeed, profiles.Alt.modules.LootFeed, profiles.Solo.modules.LootFeed })
			assert.same({ sellOnOpen = false, swapClicks = true }, profiles.Default.modules.Junk)
			-- The layouts stay, unread.
			assert.equals("icons", db.sections.feedLayouts.Strip.base)
		end)

		it("names looks of one layout with different settings after their profiles", function()
			local db = { profiles = {
				Default = { modules = { LootFeed = { layout = "Quiet", maxRows = 6 } } },
				Raid = { modules = { LootFeed = { layout = "Quiet", maxRows = 7 } } },
				Alt = { modules = { LootFeed = { layout = "Quiet", maxRows = 7 } } },
				Solo = { modules = { LootFeed = { layout = "Gone", maxRows = 9 } } },
				Bank = { modules = { LootFeed = { layout = "Wide", maxRows = 4 } } },
				Mail = { modules = { LootFeed = { layout = "Wide", maxRows = 3 } } },
				Pvp = { modules = { LootFeed = { layout = "Wide", maxRows = 3 } } },
			}, sections = { feedLayouts = {
				Quiet = { schema = 1, base = "compact" }, Wide = { schema = 1, base = "large" },
			} } }
			Migrations.FeedLooks(db)
			local function lookOf(profile)
				local feed = db.profiles[profile].modules.LootFeed
				return feed and feed.look or "Default"
			end
			-- Default's group keeps the layout's name; a missing layout counts as Default.
			assert.same({ "Quiet", "Quiet (Alt)", "Quiet (Alt)", "Default" }, { lookOf("Default"), lookOf("Raid"), lookOf("Alt"), lookOf("Solo") })
			-- Without Default, the group of the most profiles keeps it.
			assert.same({ "Wide (Bank)", "Wide", "Wide" }, { lookOf("Bank"), lookOf("Mail"), lookOf("Pvp") })
			assert.same({ 6, 7, 9, 4, 3 }, { db.sections.feedLooks.Quiet.values.maxRows, db.sections.feedLooks["Quiet (Alt)"].values.maxRows,
				db.sections.feedLooks.Default.values.maxRows, db.sections.feedLooks["Wide (Bank)"].values.maxRows, db.sections.feedLooks.Wide.values.maxRows })
		end)

		it("keeps a rows look's direction up or down, and an icons look's as it was", function()
			local db = { profiles = {
				Default = { modules = { LootFeed = { direction = "left", otherViewDirection = "down" } } },
				Strip = { modules = { LootFeed = { layout = "Bar" } } },
				Tall = { modules = { LootFeed = { layout = "Bar", direction = "right" } } },
			}, sections = { feedLayouts = { Bar = { schema = 1, base = "icons" } } } }
			Migrations.FeedLooks(db)
			local looks = db.sections.feedLooks
			-- Default fills down, left over from icons; Strip up as 0.4 did, Tall right as a new icons look does.
			assert.same({ "down", "up" }, { looks.Default.values.direction, looks.Bar.values.direction })
			assert.same({ "Bar", "Bar (Tall)" }, { db.profiles.Strip.modules.LootFeed.look, db.profiles.Tall.modules.LootFeed.look })
			assert.is_nil(looks["Bar (Tall)"].values.direction)
		end)

		it("leaves a fresh install to the new defaults: no loot feed data, no looks", function()
			local db = { profiles = { Default = {} } }
			Migrations.FeedLooks(db)
			assert.same({ profiles = { Default = {} } }, db)
		end)

		it("shortens a long name to the longest a look may have", function()
			local long = ("x"):rep(45)
			local db = { profiles = {
				Default = { modules = { LootFeed = { layout = long } } },
				Raid = { modules = { LootFeed = { layout = long, maxRows = 9 } } },
			}, sections = { feedLayouts = { [long] = { schema = 1, base = "large" } } } }
			Migrations.FeedLooks(db)
			local name = db.profiles.Raid.modules.LootFeed.look
			assert.same({ 48, long .. " (R" }, { #name, name })
		end)
	end)

	it("turns junk's selling switches into one choice, keeping what 0.4 did", function()
		local JunkFrom = Migrations.JunkFrom
		-- 0.4's defaults: selling as a merchant opened, the small button.
		assert.same({ selling = "auto", tossStyle = "small" }, JunkFrom({}))
		assert.same({ selling = "button", tossStyle = "small" }, JunkFrom({ sellOnOpen = false }))
		assert.same({ tossStyle = "small" }, JunkFrom({ sellOnOpen = false, swapClicks = true }))
		assert.same({ selling = "auto", tossButton = "always" }, JunkFrom({ tossStyle = "large", tossSize = 48, tossSide = "left", tossOffset = 10, tossButton = "always" }))
		-- Turned off: no loot window button, the sell button opens the sort window.
		assert.same({ tossButton = "never" }, JunkFrom({ enabled = false, sellOnOpen = true }))
	end)

	it("moves junk's settings in every profile of 0.4's data, not in a fresh install's", function()
		local db = dofile("tests/fixtures/saved_0_4.lua")().LootomanDB
		db = Migrations.Run(Migrations.account, db)
		assert.same({ { tossStyle = "small" }, { selling = "auto", tossStyle = "small" } }, { db.profiles.Default.modules.Junk, db.profiles.Solo.modules.Junk })
		local fresh = Migrations.Run(Migrations.account, nil)
		assert.same({ Default = {} }, fresh.profiles)
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
