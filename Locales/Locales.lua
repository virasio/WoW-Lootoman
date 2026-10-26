local _, ns = ...

-- English strings are the keys: L["Sell junk"]. A string with no
-- translation for the client locale falls back to its English key.
--
-- Locales load before Compat, so this is the one place outside Compat that
-- calls the game API directly.
local Locales = {
	current = GetLocale(),
	english = {},
	translation = {},
}
ns.Locales = Locales

function Locales.AddEnglish(keys)
	for _, key in ipairs(keys) do
		Locales.english[key] = true
	end
end

function Locales.AddTranslation(locale, strings)
	if locale ~= Locales.current then
		return
	end
	for key, value in pairs(strings) do
		Locales.translation[key] = value
	end
end

ns.L = setmetatable({}, {
	__index = function(_, key)
		return Locales.translation[key] or key
	end,
	__newindex = function()
		error("ns.L is read-only: add strings to the Locales files", 2)
	end,
})
