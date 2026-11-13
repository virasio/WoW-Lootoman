local Loader = require("tests.helpers.loader")

-- Whether every value of expected is in actual, the same; actual may hold
-- more (sections a later version adds).
local function holds(actual, expected, path)
	for key, value in pairs(expected) do
		local where = path .. "." .. tostring(key)
		if type(value) == "table" then
			assert.equals("table", type(actual[key]), where)
			holds(actual[key], value, where)
		else
			assert.equals(value, actual[key], where)
		end
	end
end

-- Data that released versions saved still loads, with nothing lost.
describe("saved data of version 0.1", function()
	local fixture = dofile("tests/fixtures/saved_0_1.lua")
	local ns

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon(), fixture())
	end)

	it("keeps the character's profile, its settings and the account's switches", function()
		local feed = ns.Modules:Get("LootFeed")
		assert.same({ "Raid", "down", 1.5, 2, 8, false, true }, {
			ns.Profiles.GetCurrent(),
			feed:Get("direction"),
			feed:Get("fade"),
			feed:Get("minQuality"),
			feed:Get("maxRows"),
			ns.Storage:Get("AutoLoot", "confirmBind"),
			ns.Storage:GetGlobal("debug"),
		})
	end)

	it("turns the row layouts into looks, the profile's one with its changes", function()
		local Looks, Design = ns.Feed.Looks, ns.Feed.Design
		assert.same({ "Default", "Raid rows" }, Looks.List())
		assert.equals("Raid rows", Looks.Current())
		local design = Design.Current(Looks.Get("Raid rows"))
		assert.same({ 80, 14, true, "all" }, { design.parts.icon.size, design.parts.name.fontSize, design.parts.owned.shown, design.parts.owned.count })
		-- The other profile's settings went into Default, as 0.4 showed them.
		ns.Profiles.Switch("Default")
		assert.same({ 5, true, 13 }, { ns.Modules:Get("LootFeed"):Get("maxRows"), ns.Modules:Get("LootFeed"):Get("xp"), ns.Modules:Get("LootFeed"):Get("size") })
	end)

	it("is saved again with nothing lost or changed, at the current schema", function()
		local expected = fixture()
		expected.LootomanDB.schema = #ns.Migrations.account
		-- The loot feed's settings moved into looks.
		expected.LootomanDB.profiles.Default.modules.LootFeed = nil
		expected.LootomanDB.profiles.Raid.modules.LootFeed = { look = "Raid rows" }
		holds(ns.Compat.Test.state.saved, expected, "saved")
		assert.is_nil(ns.Compat.Test.state.saved.LootomanDB.profiles.Default.modules.LootFeed)
	end)
end)

describe("saved data of version 0.3", function()
	local fixture = dofile("tests/fixtures/saved_0_3.lua")
	local ns

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon(), fixture())
	end)

	it("keeps the 0.3 settings, in the look", function()
		assert.equals(4, ns.Modules:Get("LootFeed"):Get("warnGeneralAt"))
	end)

	-- The bars left Lootoman: their sets and settings stay as 0.3 saved them,
	-- for an addon that may take them over.
	it("is saved again with nothing lost or changed, the bars' data too", function()
		local expected = fixture()
		expected.LootomanDB.schema = #ns.Migrations.account
		expected.LootomanDB.profiles.Default.modules.LootFeed = nil
		holds(ns.Compat.Test.state.saved, expected, "saved")
	end)
end)

describe("saved data of version 0.3.5", function()
	local fixture = dofile("tests/fixtures/saved_0_3_5.lua")
	local ns

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon(), fixture())
	end)

	it("loads without errors, with the profile, its feed settings and its look", function()
		assert.same({}, ns.Compat.Test.state.errors)
		local Feed = ns.Feed
		assert.same({ "Raid", "Quiet", false, 3 }, { ns.Profiles.GetCurrent(), Feed.Looks.Current(),
			Feed.Design.Current(Feed.Looks.Get("Quiet")).parts.owned.shown, ns.Modules:Get("LootFeed"):Get("maxRows") })
	end)

	it("hides the owned count in the layout of a profile that had it off, when the layout showed it", function()
		-- The same data with a layout that shows the owned count, as 0.3.5 could save it too.
		local saved = fixture()
		saved.LootomanDB.sections.feedLayouts.Quiet.changes.owned = nil
		ns = Loader.Start(Loader.LoadAddon(), saved)
		local Feed = ns.Feed
		assert.same({ "Quiet", false }, { Feed.Looks.Current(), Feed.Design.Current(Feed.Looks.Get("Quiet")).parts.owned.shown })
		assert.is_nil(ns.Compat.Test.state.saved.LootomanDB.profiles.Raid.modules.LootFeed.owned)
	end)

	-- The bars left Lootoman: their sets, settings and positions stay as 0.3.5
	-- saved them, for an addon that may take them over.
	it("is saved again with nothing lost or changed, the bars' data too", function()
		local expected = fixture()
		expected.LootomanDB.schema = #ns.Migrations.account
		-- The loot feed's settings moved into looks: at least 3 rows, the owned
		-- count hidden in the look, as its layout hid it already.
		expected.LootomanDB.profiles.Default.modules.LootFeed = nil
		expected.LootomanDB.profiles.Raid.modules.LootFeed = { look = "Quiet" }
		holds(ns.Compat.Test.state.saved, expected, "saved")
		local looks = ns.Compat.Test.state.saved.LootomanDB.sections.feedLooks
		assert.same({ 3, 3 }, { looks.Default.values.maxRows, looks.Quiet.values.maxRows })
		assert.is_nil(ns.Compat.Test.state.saved.LootomanDB.profiles.Raid.modules.LootFeed.owned)
	end)

	it("makes profile texts without the bars", function()
		local names = {}
		for _, entry in ipairs(ns.Share.Parts()) do
			names[#names + 1] = entry.name
		end
		for _, collection in ipairs(ns.Share.Collections()) do
			names[#names + 1] = collection.name
		end
		assert.same({ "module:AutoLoot", "module:Junk", "module:LootFeed", "positions:LootFeed", "look:LootFeed", "looks" }, names)
	end)

	it("reads a 0.3.5 profile text with bars: the feed's parts come in as a look, the bars' are left out and counted", function()
		local saved = fixture().LootomanDB
		local text = "LTM1:" .. ns.Compat.Encode({
			format = 1,
			addon = "0.3.5",
			sections = {
				["module:LootFeed"] = { fade = 2 },
				["layout:LootFeed"] = { layout = "Quiet" },
				["module:Bars"] = { set = "Raid" },
				["set:Bars"] = { set = "Raid" },
				["module:FreeSlots"] = saved.profiles.Raid.modules.FreeSlots,
			},
			collections = { layouts = { Quiet = saved.sections.feedLayouts.Quiet }, barSets = { Raid = saved.sections.barSets.Raid } },
		})
		local read = assert(ns.Share.Read(text))
		assert.same({ "module:LootFeed", "look:LootFeed" }, read.names)
		assert.same({ look = "Quiet" }, read.sections["look:LootFeed"])
		assert.same({ "Quiet" }, read.collections.looks.names)
		assert.equals(2, read.collections.looks.items.Quiet.values.fade)
		-- module:Bars, set:Bars and module:FreeSlots; the barSets collection.
		assert.equals(4, read.skipped)
	end)
end)

describe("saved data of version 0.4", function()
	local fixture = dofile("tests/fixtures/saved_0_4.lua")
	local ns

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon(), fixture())
	end)

	it("loads without errors, the feed as 0.4 drew it from its look", function()
		assert.same({}, ns.Compat.Test.state.errors)
		local feed = ns.Modules:Get("LootFeed")
		assert.same({ "Default", "Strip", "left", 6, 13, false, true }, { ns.Profiles.GetCurrent(), ns.Feed.Looks.Current(),
			feed.feed.options.direction, feed.feed.options.maxRows, feed:Get("size"), feed:Get("xp"), feed.feed.options.showOwned })
		assert.same({ "Default", "Quiet", "Spare", "Strip" }, ns.Feed.Looks.List())
	end)

	it("is saved again with nothing else lost or changed, the bars' data too", function()
		local expected = fixture()
		expected.LootomanDB.schema = #ns.Migrations.account
		expected.LootomanDB.profiles.Default.modules.LootFeed = { look = "Strip" }
		expected.LootomanDB.profiles.Raid.modules.LootFeed = { look = "Quiet" }
		expected.LootomanDB.profiles.Alt.modules.LootFeed = { look = "Quiet" }
		holds(ns.Compat.Test.state.saved, expected, "saved")
	end)
end)
