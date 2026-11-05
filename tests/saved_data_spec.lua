local Loader = require("tests.helpers.loader")

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

	it("is saved again with nothing lost or changed", function()
		local saved = ns.Compat.Test.state.saved
		holds(saved, fixture(), "saved")
	end)
end)

describe("saved data of version 0.3", function()
	local fixture = dofile("tests/fixtures/saved_0_3.lua")
	local ns

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon(), fixture())
	end)

	it("keeps the bar set the profile uses, its bars and the 0.3 settings", function()
		local Sets = ns.Modules:Get("Bars").Sets
		assert.same({ "Raid", "{free|33ff33} / {general}", 4 },
			{ Sets.Current(), ns.Storage:Get("FreeSlots", "template"), ns.Storage:Get("LootFeed", "warnGeneralAt") })
		local raid = Sets.Get("Raid")
		assert.same(fixture().LootomanDB.sections.barSets.Raid.bars, raid.bars)
		assert.is_nil(Sets.Get("Default").bars[1].entries)
	end)

	it("brings the bar sets to schema 2 and saves them again with nothing else lost or changed", function()
		local Sets = ns.Modules:Get("Bars").Sets
		assert.same({ 2, 2 }, { Sets.Get("Default").schema, Sets.Get("Raid").schema })
		local expected = fixture()
		for _, set in pairs(expected.LootomanDB.sections.barSets) do
			set.schema = 2
		end
		local function holds(actual, wanted, path)
			for key, value in pairs(wanted) do
				local where = path .. "." .. tostring(key)
				if type(value) == "table" then
					assert.equals("table", type(actual[key]), where)
					holds(actual[key], value, where)
				else
					assert.equals(value, actual[key], where)
				end
			end
		end
		holds(ns.Compat.Test.state.saved, expected, "saved")
	end)
end)
