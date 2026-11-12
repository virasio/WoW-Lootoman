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
		local Storage = ns.Storage
		assert.same({ "Raid", "down", 1.5, 2, 8, false, true }, {
			ns.Profiles.GetCurrent(),
			Storage:Get("LootFeed", "direction"),
			Storage:Get("LootFeed", "fade"),
			Storage:Get("LootFeed", "minQuality"),
			Storage:Get("LootFeed", "maxRows"),
			Storage:Get("AutoLoot", "confirmBind"),
			Storage:GetGlobal("debug"),
		})
	end)

	it("keeps the row layouts and the one the profile uses, with its changes", function()
		local Layouts, Design = ns.Feed.Layouts, ns.Feed.Design
		assert.same({ "Default", "Raid rows" }, Layouts.List())
		assert.equals("Raid rows", Layouts.Current())
		local design = Design.Current(Layouts.Get("Raid rows"))
		assert.same({ 80, 14 }, { design.parts.icon.size, design.parts.name.fontSize })
	end)

	it("is saved again with nothing lost or changed, at the current schema", function()
		local expected = fixture()
		expected.LootomanDB.schema = #ns.Migrations.account
		holds(ns.Compat.Test.state.saved, expected, "saved")
	end)
end)

describe("saved data of version 0.3", function()
	local fixture = dofile("tests/fixtures/saved_0_3.lua")
	local ns

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon(), fixture())
	end)

	it("keeps the 0.3 settings", function()
		assert.equals(4, ns.Storage:Get("LootFeed", "warnGeneralAt"))
	end)

	-- The bars left Lootoman: their sets and settings stay as 0.3 saved them,
	-- for an addon that may take them over.
	it("is saved again with nothing lost or changed, the bars' data too", function()
		local expected = fixture()
		expected.LootomanDB.schema = #ns.Migrations.account
		holds(ns.Compat.Test.state.saved, expected, "saved")
	end)
end)

describe("saved data of version 0.3.5", function()
	local fixture = dofile("tests/fixtures/saved_0_3_5.lua")
	local ns

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon(), fixture())
	end)

	it("loads without errors, with the profile, its feed settings and its layout", function()
		assert.same({}, ns.Compat.Test.state.errors)
		local Feed = ns.Feed
		assert.same({ "Raid", "Quiet", false }, { ns.Profiles.GetCurrent(), Feed.Layouts.Current(),
			Feed.Design.Current(Feed.Layouts.Get("Quiet")).parts.owned.shown })
	end)

	it("hides the owned count in the layout of a profile that had it off, when the layout showed it", function()
		-- The same data with a layout that shows the owned count, as 0.3.5 could save it too.
		local saved = fixture()
		saved.LootomanDB.sections.feedLayouts.Quiet.changes.owned = nil
		ns = Loader.Start(Loader.LoadAddon(), saved)
		local Feed = ns.Feed
		assert.same({ "Quiet", false }, { Feed.Layouts.Current(), Feed.Design.Current(Feed.Layouts.Get("Quiet")).parts.owned.shown })
		assert.is_nil(ns.Compat.Test.state.saved.LootomanDB.profiles.Raid.modules.LootFeed.owned)
	end)

	-- The bars left Lootoman: their sets, settings and positions stay as 0.3.5
	-- saved them, for an addon that may take them over.
	it("is saved again with nothing lost or changed, the bars' data too", function()
		local expected = fixture()
		expected.LootomanDB.schema = #ns.Migrations.account
		-- The profile's owned count switch goes; its layout hid the count already.
		expected.LootomanDB.profiles.Raid.modules.LootFeed.owned = nil
		-- The feed shows at least 3 rows.
		expected.LootomanDB.profiles.Default.modules.LootFeed.maxRows = 3
		expected.LootomanDB.profiles.Raid.modules.LootFeed.maxRows = 3
		holds(ns.Compat.Test.state.saved, expected, "saved")
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
		assert.same({ "module:AutoLoot", "module:LootFeed", "positions:LootFeed", "layout:LootFeed", "module:Junk", "layouts" }, names)
	end)

	it("reads a 0.3.5 profile text with bars: the feed's parts come in, the bars' are left out and counted", function()
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
		assert.same({ "module:LootFeed", "layout:LootFeed" }, read.names)
		assert.same({ "Quiet" }, read.collections.layouts.names)
		-- module:Bars, set:Bars and module:FreeSlots; the barSets collection.
		assert.equals(4, read.skipped)
	end)
end)
