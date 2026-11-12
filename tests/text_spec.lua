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

describe("Text.ShortNumber and Text.ShortMoney", function()
	local Text

	before_each(function()
		Text = Loader.LoadAddon().Text
	end)

	it("shorten a number for an icon, cut and never rounded", function()
		local shown = {}
		for _, number in ipairs({ 0, 850, 999, 1000, 1234, 1500, 12349, 99999, 100000, 123456, 999999, 1234567, 99999999, 123456789 }) do
			shown[#shown + 1] = Text.ShortNumber(number)
		end
		assert.same({ "0", "850", "999", "1K", "1.23K", "1.5K", "12.34K", "99.99K", "100K", "123K", "999K", "1.23M", "99.99M", "123M" },
			shown)
		assert.equals("12,34K", Text.ShortNumber(12345, ","))
	end)

	it("shorten money to a number and its coin: copper, silver with its copper, gold with its silver, then whole", function()
		local function money(copper)
			local text, coin = Text.ShortMoney(copper)
			return text .. " " .. coin
		end
		assert.same({ "78 copper", "1.00 silver", "1.23 silver", "99.99 silver", "1.02 gold", "1.00 gold", "12.34 gold",
			"123 gold", "999 gold", "1.23K gold", "123K gold" }, {
			money(78), money(100), money(123), money(9999), money(10245), money(10099), money(123456),
			money(1234500), money(9999999), money(12345600), money(1234560000) })
		assert.equals("1,02", (Text.ShortMoney(10245, ",")))
	end)
end)
