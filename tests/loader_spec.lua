local Loader = require("tests.helpers.loader")

local FIXTURE = "tests/fixtures/toc/Fixture.toc"

describe("test loader", function()
	it("loads the addon with its name and a shared namespace", function()
		local ns = Loader.LoadAddon()
		assert.equals("Lootoman", ns.addonName)
	end)

	it("loads Lua files in TOC order for the standard game type", function()
		local ns = Loader.Load({ toc = FIXTURE })
		assert.same({ "First", "Standard" }, ns.loaded)
	end)

	it("follows game type directives", function()
		local ns = Loader.Load({ toc = FIXTURE, gameType = "camelot" })
		assert.same({ "First", "Forever" }, ns.loaded)
	end)

	it("loads files inside #@debug@ blocks only when asked", function()
		local ns = Loader.Load({ toc = FIXTURE, debug = true })
		assert.same({ "First", "Standard", "Debug" }, ns.loaded)
	end)

	it("replaces and skips files", function()
		local ns = Loader.Load({
			toc = FIXTURE,
			replace = { ["Core/First.lua"] = "tests/fixtures/toc/Replacement.lua" },
			skip = { "Data/" },
		})
		assert.same({ "Replacement" }, ns.loaded)
	end)
end)
