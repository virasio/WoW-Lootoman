local Loader = require("tests.helpers.loader")

describe("profile texts", function()
	local ns, Share, Storage, Profiles, Looks, Test

	-- A text with this table in it, as another version or a broken copy could have it.
	local function text(data)
		return ("LTM%d:"):format(data.format or 2) .. ns.Compat.Encode(data)
	end

	-- A module of the tests' own, whose slider and dropdown values are checked.
	local function registerBags()
		ns.Modules:Register({
			name = "Bags",
			defaults = { enabled = false, columns = 8, sort = "name", gap = 1 },
			mainSettings = { { kind = "dropdown", key = "sort", choices = { { "name", "Name" }, { "price", "Price" } } } },
			settings = function()
				return {
					{ kind = "slider", key = "columns", min = 4, max = 16, step = 2 },
					{ kind = "slider", key = "gap", min = 0.5, max = 3, step = 0.5 },
				}
			end,
		})
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		Share, Storage, Profiles, Looks, Test = ns.Share, ns.Storage, ns.Profiles, ns.Feed.Looks, ns.Compat.Test
	end)

	it("list each module's settings with the parts under it, and the collections", function()
		local list = {}
		for index, entry in ipairs(Share.Parts()) do
			list[index] = (entry.parent and (entry.parent .. " > ") or "") .. entry.name .. "=" .. Share.Label(entry.name, { look = "Raid" })
		end
		assert.same({
			"module:AutoLoot=Fast autoloot settings", "module:LootFeed=Loot feed settings",
			"module:LootFeed > positions:LootFeed=Position", "module:LootFeed > look:LootFeed=Use look “Raid”",
			"module:Junk=Junk settings",
		}, list)
		assert.same({ "looks", "Loot feed looks" }, { Share.Collections()[1].name, Share.Collections()[1].label })
		assert.same({ "looks", "Raid" }, { Share.Needs("look:LootFeed", { look = "Raid" }) })
	end)

	it("hold the chosen parts of the current profile and the chosen looks, and read back the same", function()
		Storage:Set("AutoLoot", "confirmBind", false)
		Looks.Create("Raid")
		Looks.Set("Raid", "maxRows", 12)
		Looks.Use("Raid")
		Storage:GetSection("positions").LootFeed = { Modern = { point = "TOP", x = 10, y = -20 } }
		local exported = assert(Share.Export({
			parts = { "module:AutoLoot", "module:LootFeed", "positions:LootFeed", "look:LootFeed" },
			collections = { looks = { "Raid" } },
		}))
		assert.matches("^LTM2:", exported)
		local read = assert(Share.Read(exported))
		assert.same({ "module:AutoLoot", "module:LootFeed", "positions:LootFeed", "look:LootFeed" }, read.names)
		-- The look it uses goes with its own part, not with the settings.
		assert.same({ confirmBind = false }, read.sections["module:AutoLoot"])
		assert.same({}, read.sections["module:LootFeed"])
		assert.same({ Modern = { point = "TOP", x = 10, y = -20 } }, read.sections["positions:LootFeed"])
		assert.same({ look = "Raid" }, read.sections["look:LootFeed"])
		assert.same({ names = { "Raid" }, items = { Raid = { schema = 1, base = "large", values = { maxRows = 12 } } }, taken = { Raid = "Raid" } },
			read.collections.looks)
		assert.same({ 0, {} }, { read.skipped, read.newer })
	end)

	it("hold a part at its defaults as empty, so importing it resets those values", function()
		local read = assert(Share.Read(assert(Share.Export({ parts = { "module:AutoLoot" } }))))
		assert.same({ ["module:AutoLoot"] = {} }, read.sections)
	end)

	it("read a text broken into lines with spaces", function()
		local exported = Share.Export({ parts = { "module:AutoLoot" } })
		local wrapped = exported:sub(1, 3) .. "\n  " .. exported:sub(4) .. " \n"
		assert.is_not_nil(Share.Read(wrapped))
	end)

	it("refuse texts they cannot read", function()
		local function why(value)
			return select(2, Share.Read(value))
		end
		assert.same({ "empty", "empty" }, { why("  "), why(nil) })
		assert.equals("prefix", why("Hello there"))
		assert.equals("newer", why("LTM3:whatever"))
		assert.equals("newer", why(text({ format = 3, sections = {} })))
		assert.equals("broken", why("LTM1:garbage"))
		assert.equals("broken", why("LTM1:" .. ns.Compat.Encode("a string")))
		assert.equals("broken", why("LTM1:" .. ("A"):rep(Share.MAX_LENGTH)))
		-- Only plain data, not too deep and not too much.
		local deep = {}
		local level = deep
		for _ = 1, Share.MAX_DEPTH do
			level.next = {}
			level = level.next
		end
		assert.equals("broken", why(text({ format = 2, collections = { looks = { Deep = deep } } })))
		local many = {}
		for index = 1, Share.MAX_VALUES do
			many[index] = index
		end
		assert.equals("broken", why(text({ format = 2, collections = { looks = { Many = { changes = many } } } })))
		assert.equals("broken", why(text({ format = 2, sections = { ["module:AutoLoot"] = { confirmBind = 0 / 0 } } })))
		assert.equals("nothing", why(text({ format = 2, sections = "none", collections = { bags = {} } })))
		local good = text({ format = 2, sections = {} })
		Test.state.encoder = false
		assert.equals("encoder", why(good))
	end)

	it("leave out what this version does not know or cannot use, and count it", function()
		local read = assert(Share.Read(text({
			format = 2,
			sections = {
				["module:AutoLoot"] = { confirmBind = false, colour = 1, [1] = true, enabled = "yes" },
				["positions:LootFeed"] = { Modern = { point = "MIDDLE", x = 1, y = 2 }, Classic = { point = "TOP", x = "far", y = 0 },
					Mine = { point = "LEFT", x = 5, y = 6 } },
				["look:LootFeed"] = { look = 7 },
				bags = { sort = true },
			},
			collections = { looks = { [" Spaced"] = {}, Fine = {}, Odd = "flat" }, bags = {} },
		})))
		assert.same({ "module:AutoLoot", "positions:LootFeed" }, read.names)
		assert.same({ confirmBind = false }, read.sections["module:AutoLoot"])
		assert.same({ Mine = { point = "LEFT", x = 5, y = 6 } }, read.sections["positions:LootFeed"])
		assert.same({ "Fine" }, read.collections.looks.names)
		-- colour, [1], enabled; the look part; bags; " Spaced", Odd; the bags collection.
		assert.equals(8, read.skipped)
	end)

	it("check every module's values against the settings it declares, slider steps too", function()
		registerBags()
		local read = assert(Share.Read(text({ format = 2, sections = { ["module:Bags"] = { columns = 7, sort = "size", gap = 1.3 } } })))
		assert.same({ {}, 3 }, { read.sections["module:Bags"], read.skipped })
		read = assert(Share.Read(text({ format = 2, sections = { ["module:Bags"] = { columns = 12, sort = "price", gap = 1.5 } } })))
		assert.same({ { columns = 12, sort = "price", gap = 1.5 }, 0 }, { read.sections["module:Bags"], read.skipped })
	end)

	it("leave out a look from a newer version, and say so", function()
		local read = assert(Share.Read(text({ format = 2, collections = { looks = { Future = { schema = 99 }, Now = { base = "huge", extra = 1 } } } })))
		assert.same({ { "Now" }, { "Future" } }, { read.collections.looks.names, read.newer })
		assert.same({}, read.collections.looks.items.Now)
	end)

	describe("of 0.1 to 0.4 (format 1)", function()
		it("turn the feed's settings and the layout it used into a look the profile uses, kept as 0.4 showed them", function()
			local read = assert(Share.Read(text({
				format = 1,
				sections = {
					["module:LootFeed"] = { maxRows = 12, direction = "left", enabled = false },
					["layout:LootFeed"] = { layout = "Strip" },
				},
				collections = { layouts = { Strip = { schema = 1, base = "icons" }, Spare = { schema = 1, base = "compact" } } },
			})))
			assert.same({ "module:LootFeed", "look:LootFeed" }, read.names)
			assert.same({ { enabled = false }, { look = "Strip" } }, { read.sections["module:LootFeed"], read.sections["look:LootFeed"] })
			assert.same({ "Spare", "Strip" }, read.collections.looks.names)
			local strip, spare = read.collections.looks.items.Strip, read.collections.looks.items.Spare
			assert.same({ "icons", 12, "left", false, 13, true, "all" }, { strip.base, strip.values.maxRows, strip.values.direction,
				strip.values.xp, strip.values.size, strip.changes.owned.shown, strip.changes.owned.count })
			-- Every other layout becomes a look with 0.4's defaults.
			assert.same({ "compact", 8 }, { spare.base, spare.values.maxRows })
			assert.equals(0, read.skipped)
		end)

		it("hide the owned count and show at least 3 rows when a 0.3.5 text said so", function()
			local read = assert(Share.Read(text({ format = 1, sections = { ["module:LootFeed"] = { owned = false, maxRows = 2 } } })))
			local look = read.collections.looks.items.Default
			assert.same({ false, 3 }, { look.changes.owned.shown, look.values.maxRows })
			assert.same({ look = "Default" }, read.sections["look:LootFeed"])
		end)

		it("turn layouts shared alone into looks", function()
			local read = assert(Share.Read(text({ format = 1, collections = { layouts = { Raid = { schema = 1, base = "minimal" } } } })))
			assert.same({ {}, { "Raid" } }, { read.names, read.collections.looks.names })
		end)

		it("take odd layouts as they can, and come in broken when an upgrade fails", function()
			local read = assert(Share.Read(text({ format = 1, collections = { layouts = { Raid = { base = "large", changes = "flat" } } } })))
			assert.same({ "Raid" }, read.collections.looks.names)
			Share.RegisterUpgrade(1, function() error("cannot") end)
			assert.same({ nil, "broken" }, { Share.Read(text({ format = 1, sections = {} })) })
			-- A text of the current format needs no upgrade.
			assert.same({ nil, "nothing" }, { Share.Read(text({ format = 2, sections = {} })) })
		end)
	end)

	describe("imported", function()
		local read

		-- A text from another player: fast autoloot's settings, and the loot
		-- feed using their look Raid (icons), also their Solo.
		before_each(function()
			read = assert(Share.Read(text({
				format = 2,
				sections = {
					["module:AutoLoot"] = { confirmBind = false },
					["module:LootFeed"] = {},
					["look:LootFeed"] = { look = "Raid" },
				},
				collections = { looks = { Raid = { schema = 1, base = "icons", values = { maxRows = 12 } }, Solo = { schema = 1, base = "large" } } },
			})))
		end)

		local function choice(how, parts)
			return {
				parts = parts or { "module:LootFeed", "look:LootFeed" },
				collections = { looks = { Raid = how, Solo = "both" } },
				newName = "Shared",
			}
		end

		local function feed()
			return ns.Modules:Get("LootFeed").feed.options
		end

		it("into a new profile, which the character then uses, with the looks it uses", function()
			local name, renamed = Share.Import(read, choice("both"))
			assert.same({ "Shared", { looks = { Raid = "Raid", Solo = "Solo" } } }, { name, renamed })
			assert.same({ "Shared", "Raid", "icons", 12 }, { Profiles.GetCurrent(), Looks.Current(), Looks.View("Raid"), feed().maxRows })
			assert.same({ "Default", "Raid", "Solo" }, Looks.List())
		end)

		it("keeps the player's look of a taken name, and the profile uses the player's", function()
			Looks.Create("raid")
			local _, renamed = Share.Import(read, choice("keep"))
			assert.same({ Raid = "raid", Solo = "Solo" }, renamed.looks)
			assert.same({ "raid", "rows", 5 }, { Looks.Current(), Looks.View("raid"), feed().maxRows })
		end)

		it("replaces the player's look of a taken name", function()
			Looks.Create("raid")
			Share.Import(read, choice("replace"))
			assert.same({ "raid", "icons", 12 }, { Looks.Current(), Looks.View("raid"), feed().maxRows })
		end)

		it("keeps both under a free name, and the profile uses the imported one", function()
			Looks.Create("Raid")
			Looks.Create("Raid 2")
			local _, renamed = Share.Import(read, choice("both"))
			assert.same({ "Raid 3", "Raid 3", "icons" }, { renamed.looks.Raid, Looks.Current(), Looks.View("Raid 3") })
			assert.equals("rows", Looks.View("Raid"))
		end)

		it("leaves the profile's look alone without Use look", function()
			Looks.Create("Mine")
			Looks.Use("Mine")
			local current = choice("both", { "module:LootFeed" })
			current.newName = nil
			Share.Import(read, current)
			assert.equals("Mine", Looks.Current())
			Share.Import(read, choice("both", { "module:LootFeed" }))
			assert.same({ "Shared", "Default" }, { Profiles.GetCurrent(), Looks.Current() })
		end)

		it("only as looks, touching no profile", function()
			local changed = 0
			ns.Bus:On("ProfileChanged", "test", function() changed = changed + 1 end)
			local name, renamed = Share.Import(read, { collections = { looks = { Solo = "both" } } })
			assert.same({ nil, { looks = { Solo = "Solo" } }, 0 }, { name, renamed, changed })
			assert.same({ "Default", "Default", { "Default", "Solo" } }, { Profiles.GetCurrent(), Looks.Current(), Looks.List() })
		end)

		it("into a new profile only with a name no profile has", function()
			Profiles.Create("Shared")
			assert.same({ nil, "exists" }, { Share.Import(read, choice("both")) })
			local empty = choice("both")
			empty.newName = " "
			assert.same({ nil, "empty" }, { Share.Import(read, empty) })
			assert.same({ { "Default", "Shared" }, "Default", { "Default" } }, { Profiles.List(), Profiles.GetCurrent(), Looks.List() })
		end)

		it("into the current profile, replacing only the chosen parts, at once", function()
			local changed = 0
			ns.Bus:On("ProfileChanged", "test", function() changed = changed + 1 end)
			Storage:Set("AutoLoot", "confirmBind", true)
			Storage:Set("AutoLoot", "enabled", false)
			local current = choice("both")
			current.newName = nil
			assert.equals("Default", Share.Import(read, current))
			-- The loot feed's look is the text's; fast autoloot's settings stay.
			assert.same({ "Raid", false, true }, { Looks.Current(), Storage:Get("AutoLoot", "enabled"), Storage:Get("AutoLoot", "confirmBind") })
			assert.same({ 1, 12 }, { changed, feed().maxRows })
		end)

		it("with the position as a part of the profile", function()
			read = assert(Share.Read(text({ format = 2, sections = {
				["module:LootFeed"] = {}, ["positions:LootFeed"] = { Modern = { point = "TOP", x = 1, y = 2 } },
			} })))
			Share.Import(read, { parts = read.names })
			assert.same({ Modern = { point = "TOP", x = 1, y = 2 } }, Storage:GetSection("positions").LootFeed)
		end)

		it("as the look Default too, kept as both under a name in the client language", function()
			read = assert(Share.Read(text({ format = 2, collections = { looks = { Default = { schema = 1, base = "icons" } } } })))
			assert.equals("Default", read.collections.looks.taken.Default)
			local _, renamed = Share.Import(read, { collections = { looks = { Default = "both" } } })
			assert.same({ "Default 2", "icons", "rows" }, { renamed.looks.Default, Looks.View("Default 2"), Looks.View("Default") })
		end)
	end)
end)
