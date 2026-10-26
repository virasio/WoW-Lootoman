local Loader = require("tests.helpers.loader")

describe("Text.FoldCase", function()
	local FoldCase

	before_each(function()
		FoldCase = Loader.LoadAddon().Text.FoldCase
	end)

	it("lowers A–Z", function()
		assert.equals("main raid 2", FoldCase("Main RAID 2"))
	end)

	it("lowers Cyrillic, including Ё", function()
		assert.equals("рейд ёлка жук", FoldCase("Рейд ЁЛКА ЖУК"))
		assert.equals("абвгдеёжзийклмнопрстуфхцчшщъыьэюя", FoldCase("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"))
	end)

	it("lowers Latin letters with accents", function()
		assert.equals("über élan ñandú çà", FoldCase("ÜBER Élan ÑANDÚ ÇÀ"))
	end)

	it("keeps lower case, signs and other scripts as they are", function()
		local text = "рейд × ß 한국 中文 ✓ 100%"
		assert.equals(text, FoldCase(text))
	end)
end)

describe("Text.Truncate", function()
	local Text

	before_each(function()
		Text = Loader.LoadAddon().Text
	end)

	it("keeps the first characters, not bytes", function()
		assert.equals("Main", Text.Truncate("Main raid", 4))
		assert.equals("Рейд", Text.Truncate("Рейд ёлка", 4))
		assert.equals("ü✓", Text.Truncate("ü✓ab", 2))
	end)

	it("keeps a text that is short enough as it is", function()
		assert.equals("Рейд", Text.Truncate("Рейд", 10))
		assert.equals("", Text.Truncate("Рейд", 0))
	end)
end)
