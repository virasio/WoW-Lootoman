local Loader = require("tests.helpers.loader")

describe("free-slot template", function()
	local Template

	local VALUES = { free = 26, total = 98, used = 72, general = 12, generalTotal = 52, reagent = 14, reagentTotal = 36,
		profession = 0, professionTotal = 10 }
	local WHITE = "ffffffff"

	before_each(function()
		Template = Loader.LoadAddon().Modules:Get("FreeSlots").Template
	end)

	it("puts each token's value in its colour, and the rest in the default colour", function()
		assert.equals("|cff33ff3326|r|cffffffff (|r|cffffd10014|r|cffffffff) / |r|cffffffff12|r",
			Template.Render("{free|33ff33} ({reagent|ffd100}) / {general}", VALUES, WHITE))
	end)

	it("knows every token, in any letter case, and colours with eight digits too", function()
		local list = {}
		for _, token in ipairs(Template.TOKENS) do
			list[#list + 1] = "{" .. token[1] .. "}"
		end
		assert.equals("|cffffffff26|r|cffffffff98|r|cffffffff72|r|cffffffff12|r|cffffffff52|r|cffffffff14|r|cffffffff36|r"
			.. "|cffffffff0|r|cffffffff10|r", Template.Render(table.concat(list), VALUES, WHITE))
		assert.equals("|c80ff000012|r", Template.Render("{ General | 80FF0000 }", VALUES, WHITE))
	end)

	it("leaves an unknown token, a broken colour and stray braces as typed", function()
		assert.same({ { text = "{herbs} {free|12345} { {" }, { token = "free" } }, Template.Parse("{herbs} {free|12345} { {{free}"))
		assert.equals("|cffffffff{herbs}|r", Template.Render("{herbs}", VALUES, WHITE))
	end)

	it("shows a typed | as itself, not as the start of a code", function()
		assert.equals("|cffffffffa || b|r", Template.Render("a | b", VALUES, WHITE))
	end)
end)
