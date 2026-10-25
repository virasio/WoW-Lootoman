local _, ns = ...
local L, Profiles, Storage, Text = ns.L, ns.Profiles, ns.Storage, ns.Text
local Panel = ns.SettingsPanel

-- The profile on top of the main page (techspec §7.1): the label "Profile",
-- under it a dropdown with the profile this character uses and a menu in the
-- spirit of Edit Mode's layout menu. Every profile shows, on hover, a gear
-- with Copy, Rename and Reset, and a button to delete it (Default can be
-- neither renamed nor deleted); below them, New profile. The actions work on
-- the profile they belong to; names are typed in Blizzard's input dialog.
-- Right of the dropdown, Reset resets the current profile; it takes the place
-- of Blizzard's Defaults button, which is hidden on Lootoman's pages.

local ERRORS = {
	empty = L["Enter a profile name."],
	too_long = L["The profile name is too long."],
	exists = L["A profile with this name already exists."],
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

local function create()
	askName(L["Name of the new profile:"], nil, nil, function(name)
		local created = report(Profiles.Create(name))
		if created then
			Profiles.Switch(created)
		end
	end)
end

local function copy(source)
	askName(L["Name of the copy of “%s”:"], displayName(source), nil, function(name)
		local copied = report(Profiles.Copy(source, name))
		if copied then
			Profiles.Switch(copied)
		end
	end)
end

local function rename(name)
	askName(L["New name of “%s”:"], name, name, function(newName)
		report(Profiles.Rename(name, newName))
	end)
end

local function reset(name)
	confirm(L["Reset profile “%s” to the default settings?"], displayName(name), L["Reset"], function()
		report(Profiles.Reset(name))
	end)
end

local function delete(name)
	confirm(L["Delete profile “%s”? Characters that use it switch to the Default profile."], name, L["Delete"], function()
		report(Profiles.Delete(name))
	end)
end

-- A menu entry's tooltip: its title and what it does.
local function describe(description, title, text)
	description:SetTooltip(function(tooltip)
		GameTooltip_SetTitle(tooltip, title)
		GameTooltip_AddNormalLine(tooltip, text)
	end)
end

-- One profile in the menu: chosen by a click; its gear opens the submenu with
-- the actions, which does not open on hover; the delete button sits left of
-- the gear. Both show while the pointer is over the profile.
local function addProfile(root, name)
	local isDefault = name == Storage.DEFAULT_PROFILE
	local radio = root:CreateRadio(displayName(name), function()
		return Profiles.GetCurrent() == name
	end, function()
		report(Profiles.Switch(name))
	end, name)
	describe(radio:CreateButton(L["Copy"], function()
		copy(name)
	end), L["Copy"], L["Creates a copy of this profile and switches this character to it."])
	if not isDefault then
		describe(radio:CreateButton(L["Rename"], function()
			rename(name)
		end), L["Rename"], L["Renames this profile for every character that uses it."])
	end
	describe(radio:CreateButton(L["Reset"], function()
		reset(name)
	end), L["Reset"], L["Returns every setting of this profile to its default."])
	radio:DeactivateSubmenu()
	radio:AddInitializer(function(button, description, menu)
		local gear = MenuTemplates.AttachAutoHideGearButton(button)
		MenuTemplates.SetUtilityButtonTooltipText(gear, isDefault and L["Copy or reset"] or L["Copy, rename or reset"])
		MenuTemplates.SetUtilityButtonAnchor(gear, MenuVariants.GearButtonAnchor, button)
		MenuTemplates.SetUtilityButtonClickHandler(gear, function()
			description:ForceOpenSubmenu()
		end)
		if not isDefault then
			local remove = MenuTemplates.AttachAutoHideCancelButton(button)
			MenuTemplates.SetUtilityButtonTooltipText(remove, L["Delete profile"])
			MenuTemplates.SetUtilityButtonAnchor(remove, MenuVariants.CancelButtonAnchor, gear)
			MenuTemplates.SetUtilityButtonClickHandler(remove, function()
				delete(name)
				menu:Close()
			end)
		end
	end)
end

-- Blizzard's Defaults button on top of every options page resets the settings
-- of that page only. On Lootoman's pages Reset takes its place: the button is
-- hidden there, shown again on other pages, and hidden again when Blizzard
-- shows it after a search is cleared.
local function hideDefaultsButton(main)
	local list = SettingsPanel and SettingsPanel.GetSettingsList and SettingsPanel:GetSettingsList()
	local button = list and list.Header and list.Header.DefaultsButton
	if not button or not EventRegistry then
		return
	end
	local function ours(category)
		return category ~= nil and (category == main or category:GetParentCategory() == main)
	end
	EventRegistry:RegisterCallback("Settings.CategoryChanged", function(_, category)
		button:SetShown(not ours(category))
	end, Panel)
	button:HookScript("OnShow", function()
		if ours(SettingsPanel:GetCurrentCategory()) then
			button:Hide()
		end
	end)
end

-- The whole menu: the profiles in one column, however many there are, then
-- New profile.
local function buildMenu(_, root)
	root:SetGridMode(MenuConstants.VerticalGridDirection, 1)
	for _, name in ipairs(Profiles.List()) do
		addProfile(root, name)
	end
	root:CreateDivider()
	local new = root:CreateButton(("%s |cnPURE_GREEN_COLOR:%s|r"):format(CreateAtlasMarkup("editmode-new-layout-plus"), L["New profile"]), create)
	describe(new, L["New profile"], L["Creates an empty profile and switches this character to it."])
end

-- A tooltip in the options panel's own style while the pointer is over a frame.
local function addTooltip(frame, title, text)
	frame:HookScript("OnEnter", function(owner)
		SettingsTooltip:SetOwner(owner, "ANCHOR_RIGHT")
		Settings.InitTooltip(title, text)
		SettingsTooltip:Show()
	end)
	frame:HookScript("OnLeave", function()
		SettingsTooltip:Hide()
	end)
end

Panel.AddToMain(function(page)
	local label = page.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetText(L["Profile"])
	page:Add("label", label, 14, { text = L["Profile"] })

	-- The options panel's own dropdown style.
	local dropdown = CreateFrame("DropdownButton", nil, page.frame, "WowStyle2DropdownTemplate")
	dropdown:SetWidth(220)
	dropdown:SetupMenu(buildMenu)
	addTooltip(dropdown, L["Profile"], L["The profile this character uses. Every character can use its own profile."])
	page:Add("dropdown", dropdown, 25, { gap = 4 })
	page.profile = dropdown
	-- The shown name follows a switch made anywhere.
	page:OnRefresh(function()
		dropdown:GenerateMenu()
	end)

	local resetButton = CreateFrame("Button", nil, page.frame, "UIPanelButtonTemplate")
	resetButton:SetSize(96, 22)
	resetButton:SetText(L["Reset"])
	resetButton:SetPoint("LEFT", dropdown, "RIGHT", 8, 0)
	resetButton:SetScript("OnClick", function()
		reset(Profiles.GetCurrent())
	end)
	addTooltip(resetButton, L["Reset"], L["Resets the current profile to the default settings."])
	page.reset = resetButton

	hideDefaultsButton(page.category)
end)
