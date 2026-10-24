local _, ns = ...

-- Every user-visible string. English strings are their own keys, so this list
-- is for the tests and for translators: add each new L["..."] key here.
ns.Locales.AddEnglish({
	-- Core/Startup.lua
	"Your settings were saved by a newer version of Lootoman. They are kept as they are, and this version uses default settings until you update.",

	-- Core/Slash.lua
	"Debug messages are on for all characters.",
	"Debug messages are off for all characters.",
	"Unknown value “%s”. Use /lootoman debug on or /lootoman debug off.",
	"Commands:",
	"/lootoman or /ltm: open the settings",
	"/lootoman debug [on | off]: show, turn on or turn off debug messages",
	"/lootoman selftest: check the addon against the game client",

	-- Modules/AutoLoot/AutoLoot.lua
	"Fast autoloot",
	"When the game loots automatically, picks up everything at once. The loot window opens only for what cannot be picked up.",
	"Confirm bind-on-pickup items when alone",
	"Picks up items that bind when picked up without asking, unless you are in a group.",

	-- Modules/LootFeed/Frames.lua
	"No room in bags",
	"Experience",
	-- A faction's reputation change. Russian clients decline the faction name in
	-- most messages: "%s reputation" gets the declined name, "Reputation with %s"
	-- the name as it is. English shows only the second.
	"Reputation with %s",
	"%s reputation",

	-- Modules/LootFeed/LootFeed.lua
	"Loot feed",
	"Shows what you pick up: items, currencies, money, reputation and, if you want, experience.",
	"Items",
	"Currencies",
	"Money",
	"Reputation",
	"Minimum quality",
	"Items of a lower quality are not shown.",
	"Rows",
	"How many rows are shown at once. When there are more, the oldest ones fade out at once.",
	"New rows appear",
	"On top: the oldest row stays at the bottom edge and new rows stack above it. At the bottom: the oldest row stays at the top edge and new rows stack below it.",
	"On top",
	"At the bottom",
	"Time on screen",
	"Seconds before a row starts to fade out.",
	"%d s",
	"Fade-out time",
	"%.1f s",

	-- Settings/Panel.lua
	"Modules",
	"Enabled",

	-- Settings/Profiles.lua
	"Profiles",
	"Profile",
	"Default",
	"The profile this character uses. Every character can use its own profile.",
	"New profile",
	"New",
	"Creates an empty profile and switches this character to it.",
	"Name of the new profile:",
	"Copy profile",
	"Copy",
	"Creates a copy of the current profile and switches this character to it.",
	"Name of the copy of “%s”:",
	"Rename profile",
	"Rename",
	"Renames the current profile for every character that uses it.",
	"New name of “%s”:",
	"Reset profile",
	"Reset",
	"Returns every setting of the current profile to its default.",
	"Reset profile “%s” to the default settings?",
	"Delete profile",
	"Delete",
	"Deletes the current profile. Characters that use it switch to the Default profile.",
	"Delete profile “%s”? Characters that use it switch to the Default profile.",
	"Enter a profile name.",
	"The profile name is too long.",
	"A profile with this name already exists.",
	"The Default profile cannot be renamed or deleted.",
	"This profile no longer exists.",
})
