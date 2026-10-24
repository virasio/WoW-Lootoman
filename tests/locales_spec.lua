local Loader = require("tests.helpers.loader")
local Strings = require("tests.helpers.strings")
local Toc = require("tests.helpers.toc")

local function read(path)
	local file = assert(io.open(path, "r"))
	local text = file:read("*a")
	file:close()
	return text
end

-- Lua files of the addon outside Locales/, and the locales that have a file.
local codeFiles, translatedLocales = {}, {}
for _, entry in ipairs(Toc.Parse("Lootoman.toc").files) do
	local locale = entry.path:match("^Locales/(%a%a%u%u)%.lua$")
	if locale then
		if locale ~= "enUS" then
			translatedLocales[#translatedLocales + 1] = locale
		end
	elseif entry.path:match("%.lua$") and not entry.path:match("^Locales/") then
		codeFiles[#codeFiles + 1] = entry.path
	end
end

describe("L", function()
	it("falls back to the English key", function()
		local ns = Loader.Load()
		assert.equals("Sell junk", ns.L["Sell junk"])
	end)

	it("uses the translation of the client locale", function()
		local ns = Loader.Load({ locale = "ruRU" })
		ns.Locales.AddTranslation("ruRU", { ["Sell junk"] = "Продать хлам" })
		assert.equals("Продать хлам", ns.L["Sell junk"])
	end)

	it("ignores translations for other locales", function()
		local ns = Loader.Load({ locale = "enUS" })
		ns.Locales.AddTranslation("ruRU", { ["Sell junk"] = "Продать хлам" })
		assert.equals("Sell junk", ns.L["Sell junk"])
	end)

	it("is read-only", function()
		local ns = Loader.Load()
		assert.has_error(function()
			ns.L["Sell junk"] = "Sell"
		end)
	end)
end)

describe("locale files", function()
	it("include ruRU", function()
		assert.same({ "ruRU" }, translatedLocales)
	end)

	for _, locale in ipairs(translatedLocales) do
		it(locale .. " translates only English keys, with the same placeholders", function()
			local ns = Loader.Load({ locale = locale })
			for key, value in pairs(ns.Locales.translation) do
				assert.is_true(ns.Locales.english[key] == true, ("%s: %q is not in enUS.lua"):format(locale, key))
				assert.same(Strings.Placeholders(key), Strings.Placeholders(value),
					("%s: placeholders differ for %q"):format(locale, key))
			end
		end)
	end

	it("enUS lists every key the code uses, and no others", function()
		local ns = Loader.Load()
		local used = {}
		for _, path in ipairs(codeFiles) do
			local keys, nonLiteral = Strings.FindKeys(read(path))
			assert.equals(0, nonLiteral, path .. ": L[...] keys must be plain string literals")
			for _, key in ipairs(keys) do
				assert.is_true(ns.Locales.english[key] == true, ("%s: %q is not in enUS.lua"):format(path, key))
				used[key] = true
			end
		end
		for key in pairs(ns.Locales.english) do
			assert.is_true(used[key] == true, ("enUS.lua: %q is not used in the code"):format(key))
		end
	end)
end)
