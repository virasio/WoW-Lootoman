local Toc = require("tests.helpers.toc")

describe("TOC parser", function()
	local toc = Toc.Parse("tests/fixtures/toc/Fixture.toc")

	it("reads metadata", function()
		assert.equals("120105, 16001", toc.metadata.Interface)
		assert.equals("Тест", toc.metadata["Notes-ruRU"])
	end)

	it("reads file lines in order, with forward slashes", function()
		local paths = {}
		for i, entry in ipairs(toc.files) do
			paths[i] = entry.path
		end
		assert.same({ "Core/First.lua", "Data/Standard.lua", "Data/Forever.lua", "UI/Frame.xml", "Dev/Debug.lua" }, paths)
	end)

	it("reads inline directives", function()
		assert.same({}, toc.files[1].directives)
		assert.same({ AllowLoadGameType = { "camelot" }, ExcludeLoadGameType = { "standard" } }, toc.files[3].directives)
	end)

	it("reads directives with several values", function()
		local parsed = Toc.ParseText("Data\\Shared.lua [AllowLoadGameType standard, camelot]")
		assert.same({ "standard", "camelot" }, parsed.files[1].directives.AllowLoadGameType)
	end)

	it("marks files inside #@debug@ blocks", function()
		assert.is_false(toc.files[4].debug)
		assert.is_true(toc.files[5].debug)
	end)

	it("handles Windows line endings", function()
		local parsed = Toc.ParseText("## Title: X\r\nCore\\A.lua\r\n")
		assert.equals("X", parsed.metadata.Title)
		assert.equals("Core/A.lua", parsed.files[1].path)
	end)
end)
