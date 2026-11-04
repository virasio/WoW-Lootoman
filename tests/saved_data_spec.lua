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

	it("is saved again as it was", function()
		local saved = ns.Compat.Test.state.saved
		assert.same(fixture(), { LootomanDB = saved.LootomanDB, LootomanCharDB = saved.LootomanCharDB })
	end)
end)
