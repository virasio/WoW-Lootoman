local Loader = require("tests.helpers.loader")

describe("client data sets", function()
	it("are Mainline on retail", function()
		assert.equals("Mainline", Loader.LoadAddon({ gameType = "standard" }).Data.set)
	end)

	it("are Forever on WoW Forever", function()
		assert.equals("Forever", Loader.LoadAddon({ gameType = "camelot" }).Data.set)
	end)

	it("leave out the kept usable kinds WoW Forever has no items for: appearance sets and heirlooms", function()
		local forever = Loader.LoadAddon({ gameType = "camelot" })
		assert.same({ "quest", "recipe", "container", "pet", "mount", "toy" }, forever.Rules.Usable.Kinds())
		local keys = {}
		for _, setting in ipairs(forever.Feed.Looks.Settings("rows")) do
			keys[setting.key] = true
		end
		assert.same({ true, true, nil, nil }, { keys.keepToys, keys.keepPets, keys.keepSets, keys.keepHeirlooms })
		local retail = Loader.LoadAddon({ gameType = "standard" })
		assert.same({ "quest", "recipe", "container", "pet", "mount", "toy", "set", "heirloom" }, retail.Rules.Usable.Kinds())
	end)
end)
