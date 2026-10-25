local _, ns = ...

-- Maintained by the author. Every key must be in enUS.lua, with the same
-- format placeholders.
ns.Locales.AddTranslation("ruRU", {
	-- Core/Startup.lua
	["Your settings were saved by a newer version of Lootoman. They are kept as they are, and this version uses default settings until you update."] = "Настройки сохранены более новой версией Lootoman. Они останутся без изменений, а эта версия до обновления работает с настройками по умолчанию.",

	-- Core/Slash.lua
	["Debug messages are on for all characters."] = "Отладочные сообщения включены для всех персонажей.",
	["Debug messages are off for all characters."] = "Отладочные сообщения выключены для всех персонажей.",
	["Unknown value “%s”. Use /lootoman debug on or /lootoman debug off."] = "Неизвестное значение «%s». Используйте /lootoman debug on или /lootoman debug off.",
	["Commands:"] = "Команды:",
	["/lootoman or /ltm: open the settings"] = "/lootoman или /ltm: открыть настройки",
	["/lootoman debug [on | off]: show, turn on or turn off debug messages"] = "/lootoman debug [on | off]: показать, включить или выключить отладочные сообщения",
	["/lootoman selftest: check the addon against the game client"] = "/lootoman selftest: проверить работу аддона с клиентом игры",

	-- Settings/Panel.lua
	["Configure"] = "Настроить",
	["Enabled"] = "Включено",

	-- Settings/Profiles.lua
	["Profile"] = "Профиль",
	["Default"] = "По умолчанию",
	["The profile this character uses. Every character can use its own profile."] = "Профиль этого персонажа. У каждого персонажа может быть свой профиль.",
	["New profile"] = "Новый профиль",
	["Creates an empty profile and switches this character to it."] = "Создаёт пустой профиль и переключает на него этого персонажа.",
	["Name of the new profile:"] = "Название нового профиля:",
	["Copy"] = "Копировать",
	["Creates a copy of this profile and switches this character to it."] = "Создаёт копию этого профиля и переключает на неё этого персонажа.",
	["Name of the copy of “%s”:"] = "Название копии профиля «%s»:",
	["Rename"] = "Переименовать",
	["Renames this profile for every character that uses it."] = "Переименовывает этот профиль для всех персонажей, которые его используют.",
	["New name of “%s”:"] = "Новое название профиля «%s»:",
	["Reset"] = "Сбросить",
	["Returns every setting of this profile to its default."] = "Возвращает все настройки этого профиля к значениям по умолчанию.",
	["Reset profile “%s” to the default settings?"] = "Сбросить профиль «%s» к настройкам по умолчанию?",
	["Resets the current profile to the default settings."] = "Сбрасывает текущий профиль к настройкам по умолчанию.",
	["Copy or reset"] = "Копировать или сбросить",
	["Copy, rename or reset"] = "Копировать, переименовать или сбросить",
	["Delete profile"] = "Удалить профиль",
	["Delete"] = "Удалить",
	["Delete profile “%s”? Characters that use it switch to the Default profile."] = "Удалить профиль «%s»? Персонажи, которые его используют, переключатся на профиль «По умолчанию».",
	["Enter a profile name."] = "Введите название профиля.",
	["The profile name is too long."] = "Слишком длинное название профиля.",
	["A profile with this name already exists."] = "Профиль с таким названием уже есть.",
	["This profile no longer exists."] = "Этого профиля больше нет.",
})
