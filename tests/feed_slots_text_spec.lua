local Loader = require("tests.helpers.loader")

-- The low-space warning's template, as the free-slot bar of 0.3.5 had it.
describe("loot feed's slots text", function()
	local SlotsText

	local VALUES = { free = 26, total = 98, used = 72, general = 12, generalTotal = 52, reagent = 14, reagentTotal = 36,
		profession = 0, professionTotal = 10 }
	local WHITE = "ffffffff"

	before_each(function()
		SlotsText = Loader.LoadAddon().Feed.SlotsText
	end)

	it("puts each token's value in its colour, and the rest in the default colour", function()
		assert.equals("|cff33ff3326|r|cffffffff (|r|cffffd10014|r|cffffffff) / |r|cffffffff12|r",
			SlotsText.Render("{free|33ff33} ({reagent|ffd100}) / {general}", VALUES, WHITE))
	end)

	it("gives today's \"3+2\" by default", function()
		assert.equals("|cffffffff12|r|cffffffff+|r|cff1eff0014|r", SlotsText.Render(SlotsText.DEFAULT, VALUES, WHITE))
	end)

	it("knows every token, in any letter case, and colours with eight digits too", function()
		local list = {}
		for _, token in ipairs(SlotsText.TOKENS) do
			list[#list + 1] = "{" .. token[1] .. "}"
		end
		assert.equals("|cffffffff26|r|cffffffff98|r|cffffffff72|r|cffffffff12|r|cffffffff52|r|cffffffff14|r|cffffffff36|r"
			.. "|cffffffff0|r|cffffffff10|r", SlotsText.Render(table.concat(list), VALUES, WHITE))
		assert.equals("|c80ff000012|r", SlotsText.Render("{ General | 80FF0000 }", VALUES, WHITE))
	end)

	it("names every token in the note the look window shows under the template", function()
		local note = SlotsText.Note()
		for _, token in ipairs(SlotsText.TOKENS) do
			assert.truthy(note:find("{" .. token[1] .. "}", 1, true), token[1])
		end
		assert.equals(6, select(2, note:gsub("\n", "")) + 1)
	end)

	it("leaves an unknown token, a bag family's, a broken colour and stray braces as typed", function()
		assert.same({ { text = "{herbs} {free|12345} { {" }, { token = "free" } }, SlotsText.Parse("{herbs} {free|12345} { {{free}"))
		assert.equals("|cffffffff{herb}|r", SlotsText.Render("{herb}", VALUES, WHITE))
	end)

	it("shows a typed | as itself, not as the start of a code, and reads it doubled too", function()
		assert.equals("|cffffffffa || b|r", SlotsText.Render("a | b", VALUES, WHITE))
		assert.equals("|cffffffffa || b|r", SlotsText.Render("a || b", VALUES, WHITE))
		assert.equals("|cff33ff3326|r", SlotsText.Render("{free||33ff33}", VALUES, WHITE))
	end)
end)
