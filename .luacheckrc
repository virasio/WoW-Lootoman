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
	-- lua-language-server and the WoW annotations, ignored by git.
	".luals/",
}

-- Game globals are allowed per layer, so a game API call outside Compat shows
-- up as an undefined global. Add new globals to the right layer.
files["Locales/Locales.lua"] = {
	read_globals = { "GetLocale" },
}

files["Compat/"] = {
	globals = { "SlashCmdList" },
	read_globals = {
		"BreakUpLargeNumbers",
		"C_AddOns",
		"C_CVar",
		"C_Container",
		"C_CurrencyInfo",
		"C_Cursor",
		"C_EncodingUtil",
		"C_Heirloom",
		"C_Item",
		"C_MountJournal",
		"C_PetJournal",
		"C_PlayerInteractionManager",
		"C_Timer",
		"C_ToyBox",
		"C_TooltipInfo",
		"C_TransmogSets",
		"ClearCursor",
		"ConfirmLootSlot",
		"Constants",
		"CreateFrame",
		"DEFAULT_CHAT_FRAME",
		"DeleteCursorItem",
		"Enum",
		"GetBuildInfo",
		"GetCursorInfo",
		"GetGameMessageInfo",
		"GetLootSlotInfo",
		"GetLootSlotLink",
		"GetLootSlotType",
		"GetMoney",
		"GetNormalizedRealmName",
		"GetNumLootItems",
		"GetTime",
		"ITEM_SPELL_KNOWN",
		"PlayerHasToy",
		"InCombatLockdown",
		"IsFishingLoot",
		"IsInGroup",
		"IsModifiedClick",
		"ItemLocation",
		"LootSlot",
		"UnitFullName",
		"UnitXP",
		"UnitXPMax",
		"WOW_PROJECT_ID",
		"geterrorhandler",
		"issecretvalue",
	},
}

-- Third-party addons' APIs, each read only by its integration.
files["Integrations/Auctionator.lua"] = {
	read_globals = { "Auctionator" },
}

files["Modules/"] = {
	read_globals = {
		"CANCEL",
		"ColorManager",
		"CreateAtlasMarkup",
		"CreateColor",
		"CreateFrame",
		"CreateMinimalSliderFormatter",
		"GameFontNormal",
		"GameTooltip",
		"GameTooltip_AddNormalLine",
		"GameTooltip_SetTitle",
		"GameTooltip_ShowCompareItem",
		"GetCursorPosition",
		"GetMoneyString",
		"IsShiftKeyDown",
		"LibStub",
		"LootFrame",
		"MenuConstants",
		"MenuTemplates",
		"MenuUtil",
		"MenuVariants",
		"MerchantFrame",
		"MerchantSellAllJunkButton",
		"MinimalSliderWithSteppersMixin",
		"NumberFontNormal",
		"UISpecialFrames",
		"StaticPopup_Hide",
		"StaticPopup_Show",
		"TEXTURE_ITEM_QUEST_BANG",
		"TooltipUtil",
		"UIParent",
	},
}

files["Settings/"] = {
	read_globals = {
		"CANCEL",
		"CLOSE",
		"CreateAtlasMarkup",
		"CreateFrame",
		"CreateSettingsButtonInitializer",
		"CreateSettingsListSectionHeaderInitializer",
		"EventRegistry",
		"GameTooltip_AddNormalLine",
		"GameTooltip_SetTitle",
		"MenuConstants",
		"MenuTemplates",
		"MenuVariants",
		"MinimalSliderWithSteppersMixin",
		"UISpecialFrames",
		"Settings",
		"SettingsPanel",
		"SettingsTooltip",
		"StaticPopup_Show",
		"UIParent",
	},
}

files["tests/"] = {
	std = "+busted",
}
