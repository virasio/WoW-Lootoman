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

	it("keeps the 0.3 settings", function()
		assert.equals(4, ns.Storage:Get("LootFeed", "warnGeneralAt"))
	end)

	-- The bars left Lootoman: their sets and settings stay as 0.3 saved them,
	-- for an addon that may take them over.
	it("is saved again with nothing lost or changed, the bars' data too", function()
		holds(ns.Compat.Test.state.saved, fixture(), "saved")
	end)
end)
