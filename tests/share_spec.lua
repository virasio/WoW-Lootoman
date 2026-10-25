local Loader = require("tests.helpers.loader")

describe("profile texts", function()
	local ns, Share, Storage, Profiles, Layouts, Test

	-- A text with this table in it, as another version or a broken copy could have it.
	local function text(data)
		return "LTM1:" .. ns.Compat.Encode(data)
	end

	local function height()
		return ns.Modules:Get("LootFeed").feed.options.layout.height
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		Share, Storage, Profiles, Layouts, Test = ns.Share, ns.Storage, ns.Profiles, ns.Feed.Layouts, ns.Compat.Test
	end)

	it("list each module's settings with the parts under it, and the collections", function()
		local list = {}
		for index, entry in ipairs(Share.Parts()) do
			list[index] = (entry.parent and (entry.parent .. " > ") or "") .. entry.name .. "=" .. Share.Label(entry.name, { layout = "Raid" })
		end
		assert.same({
			"module:AutoLoot=Fast autoloot settings", "module:LootFeed=Loot feed settings",
			"module:LootFeed > positions:LootFeed=Position", "module:LootFeed > layout:LootFeed=Use layout “Raid”",
		}, list)
		assert.same({ "layouts", "Loot feed layouts" }, { Share.Collections()[1].name, Share.Collections()[1].label })
		assert.same({ "layouts", "Raid" }, { Share.Needs("layout:LootFeed", { layout = "Raid" }) })
	end)

	it("hold the chosen parts of the current profile and the chosen layouts, and read back the same", function()
		Storage:Set("LootFeed", "maxRows", 12)
		Layouts.Create("Raid", "compact")
		Layouts.Use("Raid")
		Storage:GetSection("positions").LootFeed = { Modern = { point = "TOP", x = 10, y = -20 } }
		local exported = assert(Share.Export({
			parts = { "module:LootFeed", "positions:LootFeed", "layout:LootFeed" },
			collections = { layouts = { "Raid" } },
		}))
		assert.matches("^LTM1:", exported)
		local read = assert(Share.Read(exported))
		assert.same({ "module:LootFeed", "positions:LootFeed", "layout:LootFeed" }, read.names)
		-- The layout it uses goes with its own part, not with the settings.
		assert.same({ maxRows = 12 }, read.sections["module:LootFeed"])
		assert.same({ Modern = { point = "TOP", x = 10, y = -20 } }, read.sections["positions:LootFeed"])
		assert.same({ layout = "Raid" }, read.sections["layout:LootFeed"])
		assert.same({ names = { "Raid" }, items = { Raid = { schema = 2, base = "compact" } }, taken = { Raid = "Raid" } },
			read.collections.layouts)
		assert.same({ 0, {} }, { read.skipped, read.newer })
	end)

	it("hold a part at its defaults as empty, so importing it resets those values", function()
		local read = assert(Share.Read(assert(Share.Export({ parts = { "module:AutoLoot" } }))))
		assert.same({ ["module:AutoLoot"] = {} }, read.sections)
	end)

	it("read a text broken into lines with spaces", function()
		local exported = Share.Export({ parts = { "module:LootFeed" } })
		local wrapped = exported:sub(1, 3) .. "\n  " .. exported:sub(4) .. " \n"
		assert.is_not_nil(Share.Read(wrapped))
	end)

	it("refuse texts they cannot read", function()
		local function why(value)
			return select(2, Share.Read(value))
		end
		assert.same({ "empty", "empty" }, { why("  "), why(nil) })
		assert.equals("prefix", why("Hello there"))
		assert.equals("newer", why("LTM2:whatever"))
		assert.equals("newer", why(text({ format = 2, sections = {} })))
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
		assert.equals("broken", why(text({ format = 1, collections = { layouts = { Deep = deep } } })))
		local many = {}
		for index = 1, Share.MAX_VALUES do
			many[index] = index
		end
		assert.equals("broken", why(text({ format = 1, collections = { layouts = { Many = { changes = many } } } })))
		assert.equals("broken", why(text({ format = 1, sections = { ["module:LootFeed"] = { fade = 0 / 0 } } })))
		assert.equals("nothing", why(text({ format = 1, sections = "none", collections = { bags = {} } })))
		local good = text({ format = 1, sections = {} })
		Test.state.encoder = false
		assert.equals("encoder", why(good))
	end)

	it("leave out what this version does not know or cannot use, and count it", function()
		local read = assert(Share.Read(text({
			format = 1,
			sections = {
				["module:LootFeed"] = { fade = 2, maxRows = 99, size = "big", colour = 1, direction = "sideways", [1] = true, layout = "Raid" },
				["positions:LootFeed"] = { Modern = { point = "MIDDLE", x = 1, y = 2 }, Classic = { point = "TOP", x = "far", y = 0 },
					Mine = { point = "LEFT", x = 5, y = 6 } },
				["layout:LootFeed"] = { layout = 7 },
				bags = { sort = true },
			},
			collections = { layouts = { [" Spaced"] = {}, Fine = {}, Odd = "flat" }, bags = {} },
		})))
		assert.same({ "module:LootFeed", "positions:LootFeed" }, read.names)
		assert.same({ fade = 2 }, read.sections["module:LootFeed"])
		assert.same({ Mine = { point = "LEFT", x = 5, y = 6 } }, read.sections["positions:LootFeed"])
		assert.same({ "Fine" }, read.collections.layouts.names)
		-- maxRows, size, colour, direction, [1], layout; the link; bags; " Spaced", Odd; the bags collection.
		assert.equals(11, read.skipped)
	end)

	it("leave out slider values between their steps", function()
		local read = assert(Share.Read(text({
			format = 1,
			sections = { ["module:LootFeed"] = { maxRows = 1.5, fade = 1.3, duration = 6.5, size = 12, backgroundOpacity = 42 } },
		})))
		assert.same({ fade = 1.3, size = 12 }, read.sections["module:LootFeed"])
		assert.equals(3, read.skipped)
	end)

	it("leave out a layout from a newer version, and say so", function()
		local read = assert(Share.Read(text({ format = 1, collections = { layouts = { Future = { schema = 99 }, Now = { base = "huge", extra = 1 } } } })))
		assert.same({ { "Now" }, { "Future" } }, { read.collections.layouts.names, read.newer })
		assert.same({}, read.collections.layouts.items.Now)
	end)

	describe("imported", function()
		local read

		-- A text from another player: the loot feed's settings using their
		-- layout Raid (compact), also their Solo (minimal).
		before_each(function()
			read = assert(Share.Read(text({
				format = 1,
				sections = {
					["module:LootFeed"] = { maxRows = 12 },
					["layout:LootFeed"] = { layout = "Raid" },
				},
				collections = { layouts = { Raid = { schema = 2, base = "compact" }, Solo = { schema = 2, base = "minimal" } } },
			})))
			Storage:Set("LootFeed", "maxRows", 3)
			Storage:Set("LootFeed", "fade", 2)
		end)

		local function choice(how, parts)
			return {
				parts = parts or { "module:LootFeed", "layout:LootFeed" },
				collections = { layouts = { Raid = how, Solo = "both" } },
				newName = "Shared",
			}
		end

		it("into a new profile, which the character then uses, with the layouts it uses", function()
			local name, renamed = Share.Import(read, choice("both"))
			assert.same({ "Shared", { layouts = { Raid = "Raid", Solo = "Solo" } } }, { name, renamed })
			assert.same({ "Shared", 12, 1, "Raid", 24 },
				{ Profiles.GetCurrent(), Storage:Get("LootFeed", "maxRows"), Storage:Get("LootFeed", "fade"), Layouts.Current(), height() })
			assert.same({ "Default", "Raid", "Solo" }, Layouts.List())
		end)

		it("keeps the player's layout of a taken name, and the profile uses the player's", function()
			Layouts.Create("raid", "large")
			local _, renamed = Share.Import(read, choice("keep"))
			assert.same({ Raid = "raid", Solo = "Solo" }, renamed.layouts)
			assert.same({ "raid", 35, "large" }, { Layouts.Current(), height(), Layouts.Get("raid").base })
		end)

		it("replaces the player's layout of a taken name", function()
			Layouts.Create("raid", "large")
			Share.Import(read, choice("replace"))
			assert.same({ "raid", 24, "compact" }, { Layouts.Current(), height(), Layouts.Get("raid").base })
		end)

		it("keeps both under a free name, and the profile uses the imported one", function()
			Layouts.Create("Raid", "large")
			Layouts.Create("Raid 2", "large")
			local _, renamed = Share.Import(read, choice("both"))
			assert.same({ "Raid 3", "Raid 3", 24 }, { renamed.layouts.Raid, Layouts.Current(), height() })
			assert.equals("large", Layouts.Get("Raid").base)
		end)

		it("leaves the profile's layout alone without Use layout", function()
			Layouts.Create("Mine", "minimal")
			Layouts.Use("Mine")
			local current = choice("both", { "module:LootFeed" })
			current.newName = nil
			Share.Import(read, current)
			assert.same({ 12, "Mine" }, { Storage:Get("LootFeed", "maxRows"), Layouts.Current() })
			Share.Import(read, choice("both", { "module:LootFeed" }))
			assert.same({ "Shared", "Default" }, { Profiles.GetCurrent(), Layouts.Current() })
		end)

		it("only as layouts, touching no profile", function()
			local changed = 0
			ns.Bus:On("ProfileChanged", "test", function() changed = changed + 1 end)
			local name, renamed = Share.Import(read, { collections = { layouts = { Solo = "both" } } })
			assert.same({ nil, { layouts = { Solo = "Solo" } }, 0 }, { name, renamed, changed })
			assert.same({ "Default", 3, { "Default", "Solo" } }, { Profiles.GetCurrent(), Storage:Get("LootFeed", "maxRows"), Layouts.List() })
		end)

		it("into a new profile only with a name no profile has", function()
			Profiles.Create("Shared")
			assert.same({ nil, "exists" }, { Share.Import(read, choice("both")) })
			local empty = choice("both")
			empty.newName = " "
			assert.same({ nil, "empty" }, { Share.Import(read, empty) })
			assert.same({ { "Default", "Shared" }, "Default", { "Default" } }, { Profiles.List(), Profiles.GetCurrent(), Layouts.List() })
		end)

		it("into the current profile, replacing only the chosen parts, at once", function()
			local changed = 0
			ns.Bus:On("ProfileChanged", "test", function() changed = changed + 1 end)
			Storage:Set("AutoLoot", "confirmBind", false)
			local current = choice("both")
			current.newName = nil
			assert.equals("Default", Share.Import(read, current))
			-- The loot feed's settings are the text's, its fade-out included; fast autoloot's stay.
			assert.same({ 12, 1, false, "Raid" },
				{ Storage:Get("LootFeed", "maxRows"), Storage:Get("LootFeed", "fade"), Storage:Get("AutoLoot", "confirmBind"), Layouts.Current() })
			assert.same({ 1, 24 }, { changed, height() })
		end)

		it("with the position as a part of the profile", function()
			read = assert(Share.Read(text({ format = 1, sections = {
				["module:LootFeed"] = {}, ["positions:LootFeed"] = { Modern = { point = "TOP", x = 1, y = 2 } },
			} })))
			Share.Import(read, { parts = read.names })
			assert.same({ Modern = { point = "TOP", x = 1, y = 2 } }, Storage:GetSection("positions").LootFeed)
		end)

		it("as the layout Default too, kept as both under a name in the client language", function()
			read = assert(Share.Read(text({ format = 1, collections = { layouts = { Default = { schema = 2, base = "compact" } } } })))
			assert.equals("Default", read.collections.layouts.taken.Default)
			local _, renamed = Share.Import(read, { collections = { layouts = { Default = "both" } } })
			assert.same({ "Default 2", "compact", "large" }, { renamed.layouts.Default, Layouts.Get("Default 2").base, Layouts.Get("Default").base })
		end)
	end)
end)
