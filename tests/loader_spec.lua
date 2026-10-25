local Loader = require("tests.helpers.loader")

local FIXTURE = "tests/fixtures/toc/Fixture.toc"

describe("test loader", function()
	it("loads the addon with its name and a shared namespace", function()
		local ns = Loader.LoadAddon()
		assert.equals("Lootoman", ns.addonName)
	end)

	it("never loads the bundled libraries, even with nothing skipped", function()
		Loader.LoadAddon({ skip = {} })
		assert.is_nil(rawget(_G, "LibStub"))
	end)

	it("loads Lua files in TOC order for the standard game type", function()
		local ns = Loader.Load({ toc = FIXTURE })
		assert.same({ "First", "Standard" }, ns.loaded)
	end)

	it("follows game type directives", function()
		local ns = Loader.Load({ toc = FIXTURE, gameType = "camelot" })
		assert.same({ "First", "Forever" }, ns.loaded)
	end)

	describe("reads game type conditions as the clients do", function()
		local GAME_TYPES = "tests/fixtures/toc/GameTypes.toc"

		it("on retail, loading a file allowed only for camelot, which retail does not know, unless excluded", function()
			assert.same({ "Standard", "Unguarded", "Mainline" }, Loader.Load({ toc = GAME_TYPES }).loaded)
		end)

		it("on WoW Forever, loading the camelot files and those of the mainline family", function()
			local ns = Loader.Load({ toc = GAME_TYPES, gameType = "camelot" })
			assert.same({ "Forever", "Unguarded", "Mainline" }, ns.loaded)
		end)

		it("for clients it knows only", function()
			assert.has_error(function()
				Loader.Load({ toc = GAME_TYPES, gameType = "wrath" })
			end, "unknown game type wrath")
		end)
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
