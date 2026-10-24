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
	["Modules"] = "Модули",
	["Enabled"] = "Включено",

	-- Settings/Profiles.lua
	["Profiles"] = "Профили",
	["Profile"] = "Профиль",
	["Default"] = "По умолчанию",
	["The profile this character uses. Every character can use its own profile."] = "Профиль этого персонажа. У каждого персонажа может быть свой профиль.",
	["New profile"] = "Новый профиль",
	["New"] = "Создать",
	["Creates an empty profile and switches this character to it."] = "Создаёт пустой профиль и переключает на него этого персонажа.",
	["Name of the new profile:"] = "Название нового профиля:",
	["Copy profile"] = "Копия профиля",
	["Copy"] = "Копировать",
	["Creates a copy of the current profile and switches this character to it."] = "Создаёт копию текущего профиля и переключает на неё этого персонажа.",
	["Name of the copy of “%s”:"] = "Название копии профиля «%s»:",
	["Rename profile"] = "Переименовать профиль",
	["Rename"] = "Переименовать",
	["Renames the current profile for every character that uses it."] = "Переименовывает текущий профиль для всех персонажей, которые его используют.",
	["New name of “%s”:"] = "Новое название профиля «%s»:",
	["Reset profile"] = "Сбросить профиль",
	["Reset"] = "Сбросить",
	["Returns every setting of the current profile to its default."] = "Возвращает все настройки текущего профиля к значениям по умолчанию.",
	["Reset profile “%s” to the default settings?"] = "Сбросить профиль «%s» к настройкам по умолчанию?",
	["Delete profile"] = "Удалить профиль",
	["Delete"] = "Удалить",
	["Deletes the current profile. Characters that use it switch to the Default profile."] = "Удаляет текущий профиль. Персонажи, которые его используют, переключатся на профиль «По умолчанию».",
	["Delete profile “%s”? Characters that use it switch to the Default profile."] = "Удалить профиль «%s»? Персонажи, которые его используют, переключатся на профиль «По умолчанию».",
	["Enter a profile name."] = "Введите название профиля.",
	["The profile name is too long."] = "Слишком длинное название профиля.",
	["A profile with this name already exists."] = "Профиль с таким названием уже есть.",
	["The Default profile cannot be renamed or deleted."] = "Профиль «По умолчанию» нельзя переименовать или удалить.",
	["This profile no longer exists."] = "Этого профиля больше нет.",
})
