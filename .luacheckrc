std = "lua51"
max_line_length = false
self = false

exclude_files = {
	".release/",
	-- Third-party libraries, kept exactly as released.
	"Libs/",
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
		"C_CVar",
		"C_Container",
		"C_Item",
		"C_Timer",
		"CloseLoot",
		"ConfirmLootSlot",
		"Constants",
		"CreateFrame",
		"DEFAULT_CHAT_FRAME",
		"Enum",
		"GetBuildInfo",
		"GetGameMessageInfo",
		"GetLootSlotInfo",
		"GetLootSlotLink",
		"GetLootSlotType",
		"GetNormalizedRealmName",
		"GetNumLootItems",
		"GetTime",
		"InCombatLockdown",
		"IsFishingLoot",
		"IsInGroup",
		"IsModifiedClick",
		"LootSlot",
		"UnitFullName",
		"geterrorhandler",
		"issecretvalue",
	},
}

files["Modules/"] = {
	read_globals = {
		"CreateFrame",
		"LibStub",
		"LootFrame",
		"StaticPopup_Hide",
		"UIParent",
	},
}

files["Settings/"] = {
	read_globals = {
		"CANCEL",
		"CreateSettingsButtonInitializer",
		"CreateSettingsListSectionHeaderInitializer",
		"MinimalSliderWithSteppersMixin",
		"Settings",
		"StaticPopup_Show",
	},
}

files["Dev/"] = {
	read_globals = {
		"CreateFrame",
		"UIParent",
	},
}

files["tests/"] = {
	std = "+busted",
}
