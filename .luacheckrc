std = "lua51"
max_line_length = false
self = false

exclude_files = {
	".release/",
	-- Lua and LuaRocks installed into the checkout by CI.
	".lua/",
	".luarocks/",
}

-- Game globals are allowed per layer, so a game API call outside Compat shows
-- up as an undefined global (techspec §3). Add new globals to the right layer.
files["Locales/Locales.lua"] = {
	read_globals = { "GetLocale" },
}

files["Compat/"] = {
	globals = { "SlashCmdList" },
	read_globals = {
		"C_AddOns",
		"C_Timer",
		"CreateFrame",
		"DEFAULT_CHAT_FRAME",
		"GetBuildInfo",
		"GetNormalizedRealmName",
		"InCombatLockdown",
		"UnitFullName",
		"geterrorhandler",
		"issecretvalue",
	},
}

files["Settings/"] = {
	read_globals = {
		"CreateSettingsListSectionHeaderInitializer",
		"Settings",
	},
}

files["tests/"] = {
	std = "+busted",
}
