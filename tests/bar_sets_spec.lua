local Loader = require("tests.helpers.loader")

-- Named sets of currency bars.
describe("bar sets", function()
	local ns, Sets, Storage, changes

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon())
		Sets, Storage = ns.Modules:Get("Bars").Sets, ns.Storage
		changes = {}
		ns.Bus:On("BarSetChanged", "test", function(_, name) changes[#changes + 1] = name end)
	end)

	it("always have Default, with one bar of the backpack's currencies", function()
		assert.same({ "Default" }, Sets.List())
		assert.equals("Default", Sets.Current())
		local bar = Sets.Get("Default").bars[1]
		assert.same({ 1, 300, 6, 22, nil }, { bar.id, bar.width, bar.gap, bar.size, bar.entries })
		assert.same({ nil, "default" }, { Sets.Delete("Default") })
		assert.same({ nil, "default" }, { Sets.Rename("Default", "Mine") })
	end)

	it("are made, copied, listed in order and named without clashes", function()
		assert.equals("Raid", Sets.Create("Raid"))
		assert.equals("alts", Sets.Copy("Raid", "alts"))
		assert.same({ "Default", "alts", "Raid" }, Sets.List())
		assert.same({ nil, "exists" }, { Sets.Create("raid") })
		assert.same({ "Raid 2", "Default" }, { Sets.FreeName("Raid"), Sets.Taken("default") })
		assert.same({ "Raid", "alts" }, changes)
	end)

	it("renamed and deleted follow every profile that uses them", function()
		Sets.Create("Raid")
		Sets.Use("Raid")
		ns.Profiles.Copy("Default", "Alt")
		assert.equals("Party", Sets.Rename("Raid", "Party"))
		assert.equals("Party", Sets.Current())
		ns.Profiles.Switch("Alt")
		assert.equals("Party", Sets.Current())
		Sets.Delete("Party")
		assert.same({ "Default", nil }, { Sets.Current(), Storage.db.profiles.Default.modules.Bars.set })
	end)

	it("add and remove bars with ids of their own, up to the most a set holds", function()
		assert.equals(2, Sets.AddBar("Default"))
		assert.equals(3, Sets.AddBar("Default"))
		assert.same({}, Sets.Bar("Default", 3).entries)
		Sets.RemoveBar("Default", 2)
		assert.equals(4, Sets.AddBar("Default"))
		local ids = {}
		for index, bar in ipairs(Sets.Get("Default").bars) do
			ids[index] = bar.id
		end
		assert.same({ 1, 3, 4 }, ids)
		for _ = 4, Sets.MAX_BARS do
			Sets.AddBar("Default")
		end
		assert.same({ nil, "full" }, { Sets.AddBar("Default") })
		Sets.Reset("Default")
		assert.equals(1, #Sets.Get("Default").bars)
	end)

	it("from a profile text keep only well-formed bars, numbers in range and known entries", function()
		local clean = Sets.Clean({
			schema = 1,
			bars = {
				{ id = 1, width = 5000, gap = -3, size = 30.4, direction = "left", background = true, opacity = 150, border = "yes",
					entries = { { kind = "currency", id = 3008 }, { kind = "spell", id = 1 }, { kind = "item", id = "x" }, "junk" },
					positions = { Modern = { point = "TOP", x = 1, y = 2 }, Bad = { point = "UP", x = 1, y = 2 } } },
				{ id = 1 },
				"junk",
				{ width = 100 },
				{ id = 2 },
			},
		})
		assert.same({ schema = 1, bars = {
			{ id = 1, width = 1200, gap = 0, size = 30, direction = "left", background = true, opacity = 100, border = false,
				entries = { { kind = "currency", id = 3008 } }, positions = { Modern = { point = "TOP", x = 1, y = 2 } } },
			{ id = 2, width = 300, gap = 6, size = 22, direction = "right", background = false, opacity = 50, border = false,
				positions = {} },
		} }, clean)
		assert.same({ nil, "newer" }, { Sets.Clean({ schema = 99 }) })
	end)

	it("are shared and imported with profile texts, a taken name kept as both", function()
		local Share = ns.Share
		Sets.Create("Raid")
		Sets.AddBar("Raid")
		Sets.Bar("Raid", 2).entries = { { kind = "item", id = 2589 } }
		Sets.Use("Raid")
		local text = Share.Export({ parts = { "module:Bars", "set:Bars" }, collections = { barSets = { "Raid" } } })
		local read = assert(Share.Read(text))
		assert.same({ "Raid" }, read.collections.barSets.names)
		local _, renamed = Share.Import(read, {
			parts = { "module:Bars", "set:Bars" },
			collections = { barSets = { Raid = "both" } },
			newName = "Shared",
		})
		assert.same({ "Raid 2", "Raid 2", "Shared" }, { renamed.barSets.Raid, Sets.Current(), ns.Profiles.GetCurrent() })
		assert.same({ { kind = "item", id = 2589 } }, Sets.Bar("Raid 2", 2).entries)
	end)
end)
