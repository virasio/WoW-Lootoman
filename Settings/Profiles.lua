local _, ns = ...
local L, Profiles, Storage, Text = ns.L, ns.Profiles, ns.Storage, ns.Text
local Panel = ns.SettingsPanel

-- The Profiles page: which profile this character uses, and buttons to
-- create, copy, rename, reset and delete profiles (techspec §7.1). The buttons
-- act on the current profile; names are typed in Blizzard's input dialog.

local ERRORS = {
	empty = L["Enter a profile name."],
	too_long = L["The profile name is too long."],
	exists = L["A profile with this name already exists."],
	default = L["The Default profile cannot be renamed or deleted."],
	missing = L["This profile no longer exists."],
}

-- Default is stored under its English name and shown in the client language.
-- If another profile already has that shown name (created under another
-- client language), Default also shows its stored name, so the two differ.
local function displayName(name)
	if name ~= Storage.DEFAULT_PROFILE then
		return name
	end
	local label = L["Default"]
	local folded = Text.FoldCase(label)
	for _, other in ipairs(Profiles.List()) do
		if other ~= Storage.DEFAULT_PROFILE and Text.FoldCase(other) == folded then
			return ("%s (%s)"):format(label, Storage.DEFAULT_PROFILE)
		end
	end
	return label
end

local function report(result, err)
	if not result then
		ns.Print(ERRORS[err] or tostring(err))
	end
	return result
end

local function askName(text, textArg, initial, callback)
	local dialog = StaticPopup_Show("GENERIC_INPUT_BOX", nil, nil, {
		text = text,
		text_arg1 = textArg,
		callback = callback,
		maxLetters = Profiles.MAX_NAME_LENGTH,
	})
	if dialog and initial then
		dialog:GetEditBox():SetText(initial)
		dialog:GetEditBox():HighlightText()
	end
end

local function confirm(text, textArg, acceptText, callback)
	StaticPopup_Show("GENERIC_CONFIRMATION", nil, nil, {
		text = text,
		text_arg1 = textArg,
		acceptText = acceptText,
		cancelText = CANCEL,
		callback = callback,
	})
end

Panel.AddPage(function(category)
	local page, layout = Settings.RegisterVerticalLayoutSubcategory(category, L["Profiles"])

	local function options()
		local container = Settings.CreateControlTextContainer()
		for _, name in ipairs(Profiles.List()) do
			container:Add(name, displayName(name))
		end
		return container:GetData()
	end

	-- No default: the panel's Defaults button must not switch the profile.
	local profile = Settings.RegisterProxySetting(page, "LOOTOMAN_PROFILE", Settings.VarType.String, L["Profile"],
		Settings.CannotDefault, Profiles.GetCurrent,
		function(name)
			report(Profiles.Switch(name))
		end)
	Panel.Track(profile)
	Settings.CreateDropdown(page, profile, options, L["The profile this character uses. Every character can use its own profile."])

	local function addButton(label, buttonText, tooltip, onClick)
		layout:AddInitializer(CreateSettingsButtonInitializer(label, buttonText, onClick, tooltip, true))
	end

	addButton(L["New profile"], L["New"], L["Creates an empty profile and switches this character to it."], function()
		askName(L["Name of the new profile:"], nil, nil, function(name)
			local created = report(Profiles.Create(name))
			if created then
				Profiles.Switch(created)
			end
		end)
	end)

	addButton(L["Copy profile"], L["Copy"], L["Creates a copy of the current profile and switches this character to it."], function()
		local current = Profiles.GetCurrent()
		askName(L["Name of the copy of “%s”:"], displayName(current), nil, function(name)
			local copied = report(Profiles.Copy(current, name))
			if copied then
				Profiles.Switch(copied)
			end
		end)
	end)

	addButton(L["Rename profile"], L["Rename"], L["Renames the current profile for every character that uses it."], function()
		local current = Profiles.GetCurrent()
		if current == Storage.DEFAULT_PROFILE then
			report(nil, "default")
			return
		end
		askName(L["New name of “%s”:"], current, current, function(name)
			report(Profiles.Rename(current, name))
		end)
	end)

	addButton(L["Reset profile"], L["Reset"], L["Returns every setting of the current profile to its default."], function()
		local current = Profiles.GetCurrent()
		confirm(L["Reset profile “%s” to the default settings?"], displayName(current), L["Reset"], function()
			report(Profiles.Reset(current))
		end)
	end)

	addButton(L["Delete profile"], L["Delete"], L["Deletes the current profile. Characters that use it switch to the Default profile."], function()
		local current = Profiles.GetCurrent()
		if current == Storage.DEFAULT_PROFILE then
			report(nil, "default")
			return
		end
		confirm(L["Delete profile “%s”? Characters that use it switch to the Default profile."], current, L["Delete"], function()
			report(Profiles.Delete(current))
		end)
	end)
end)
