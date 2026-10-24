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
