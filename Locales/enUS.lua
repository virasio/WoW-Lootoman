local _, ns = ...

-- Every user-visible string. English strings are their own keys, so this list
-- is for the tests and for translators: add each new L["..."] key here.
ns.Locales.AddEnglish({
	-- Core/Startup.lua
	"Your settings were saved by a newer version of Lootoman. They are kept as they are, and this version uses default settings until you update.",

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
