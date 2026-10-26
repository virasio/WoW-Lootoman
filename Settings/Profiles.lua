local _, ns = ...
local L, NameMenu, Profiles, Storage, Text = ns.L, ns.NameMenu, ns.Profiles, ns.Storage, ns.Text
local Panel = ns.SettingsPanel

-- The profile on top of the main page: the label "Profile",
-- under it a dropdown with the profile this character uses and a menu in the
-- spirit of Edit Mode's layout menu (NameMenu). Every profile shows, on hover,
-- a gear with Copy, Rename and Reset, and a button to delete it (Default can
-- be neither renamed nor deleted); below them, New profile. The actions work
-- on the profile they belong to. Right of the dropdown, Reset resets the
-- current profile; it takes the place of Blizzard's Defaults button, which is
-- hidden on Lootoman's pages. Import and Share at the end of the menu open the
-- dialogs of Share.lua.

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
	NameMenu.AskName(text, textArg, initial, Profiles.MAX_NAME_LENGTH, callback)
end

-- For the other profile dialogs (Share.lua).
Panel.ProfileTools = { displayName = displayName, report = report }

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
	NameMenu.Confirm(L["Reset profile “%s” to the default settings?"], displayName(name), L["Reset"], function()
		report(Profiles.Reset(name))
	end)
end

local function delete(name)
	NameMenu.Confirm(L["Delete profile “%s”? Characters that use it switch to the Default profile."], name, L["Delete"], function()
		report(Profiles.Delete(name))
	end)
end

local function addProfile(root, name)
	local isDefault = name == Storage.DEFAULT_PROFILE
	local actions = {
		{ text = L["Copy"], tooltip = L["Creates a copy of this profile and switches this character to it."], run = function()
			copy(name)
		end },
	}
	if not isDefault then
		actions[#actions + 1] = { text = L["Rename"], tooltip = L["Renames this profile for every character that uses it."], run = function()
			rename(name)
		end }
	end
	actions[#actions + 1] = { text = L["Reset"], tooltip = L["Returns every setting of this profile to its default."], run = function()
		reset(name)
	end }
	NameMenu.AddName(root, {
		text = displayName(name),
		data = name,
		isSelected = function()
			return Profiles.GetCurrent() == name
		end,
		select = function()
			report(Profiles.Switch(name))
		end,
		actions = actions,
		gearTooltip = isDefault and L["Copy or reset"] or L["Copy, rename or reset"],
		deleteTooltip = L["Delete profile"],
		delete = not isDefault and function()
			delete(name)
		end or nil,
	})
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

-- The whole menu: the profiles, then New profile, Import and Share.
local function buildMenu(_, root)
	NameMenu.OneColumn(root)
	for _, name in ipairs(Profiles.List()) do
		addProfile(root, name)
	end
	root:CreateDivider()
	NameMenu.AddNew(root, L["New profile"], L["Creates an empty profile and switches this character to it."], create)
	NameMenu.AddShareEntries(root, function()
		Panel.Share.OpenImport("profile")
	end, function()
		Panel.Share.OpenShare("profile")
	end, L["Makes a text of the current profile to copy and give to another character or player."])
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
