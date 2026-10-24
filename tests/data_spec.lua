local Loader = require("tests.helpers.loader")

describe("client data sets", function()
	it("are Mainline on retail", function()
		assert.equals("Mainline", Loader.LoadAddon({ gameType = "standard" }).Data.set)
	end)

	it("are Forever on WoW Forever", function()
		assert.equals("Forever", Loader.LoadAddon({ gameType = "camelot" }).Data.set)
	end)
end)
