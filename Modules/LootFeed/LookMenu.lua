local _, ns = ...
local Bus, L, NameMenu = ns.Bus, ns.L, ns.NameMenu

-- The menu of feed looks (Looks.lua), like the profile menu (NameMenu):
-- every look as a radio that the profile then uses, with Edit (its window,
-- LookWindow.lua), Copy, Rename and Reset under its gear and a delete button;
-- + New look; Import and Share, which open the dialogs of profile texts for
-- looks. Names are typed in the game's input dialog, and what cannot be
-- undone is confirmed. The options page shows it; the look window's
-- dropdown is the same menu (Generator), its radios choosing the look the
-- window edits.
--
--   dropdown:SetupMenu(LookMenu.Build)
ns.Feed = ns.Feed or {}
local LookMenu = {}
ns.Feed.LookMenu = LookMenu
local Looks = ns.Feed.Looks

local ERRORS = {
	empty = L["Enter a look name."],
	too_long = L["The look name is too long."],
	exists = L["A look with this name already exists."],
	missing = L["This look no longer exists."],
}

local function report(result, err)
	if not result then
		ns.Print(ERRORS[err] or tostring(err))
	end
	return result
end

local function askName(text, textArg, initial, callback)
	NameMenu.AskName(text, textArg, initial, Looks.MAX_NAME_LENGTH, callback)
end

-- The profile uses this look from now on.
function LookMenu.Use(name)
	return report(Looks.Use(name))
end

-- A new look, which the profile then uses; then, given, created(name).
function LookMenu.New(created)
	askName(L["Name of the new look:"], nil, nil, function(name)
		local made = report(Looks.Create(name))
		if made then
			LookMenu.Use(made)
			if created then
				created(made)
			end
		end
	end)
end

function LookMenu.Copy(source, created)
	askName(L["Name of the copy of “%s”:"], Looks.DisplayName(source), nil, function(name)
		local copied = report(Looks.Copy(source, name))
		if copied then
			LookMenu.Use(copied)
			if created then
				created(copied)
			end
		end
	end)
end

function LookMenu.Rename(name)
	askName(L["New name of “%s”:"], name, name, function(newName)
		report(Looks.Rename(name, newName))
	end)
end

-- Every setting back to its default and the design afresh, after a confirmation.
function LookMenu.Reset(name)
	NameMenu.Confirm(L["Return look “%s” to the defaults? Its row design starts afresh."], Looks.DisplayName(name), L["Reset"], function()
		report(Looks.Reset(name))
	end)
end

function LookMenu.Delete(name)
	NameMenu.Confirm(L["Delete look “%s”? Profiles that use it switch to the Default look."], name, L["Delete"], function()
		report(Looks.Delete(name))
	end)
end

-- Opens the look's window, whichever look the profile uses.
function LookMenu.Edit(name)
	ns.Feed.LookWindow.Open(name)
end

local function addLook(root, name, how)
	local isDefault = name == Looks.DEFAULT
	local actions = {
		{ text = L["Edit"], tooltip = L["Opens the window of this look, to change its options and its row design."], run = function()
			LookMenu.Edit(name)
		end },
		{ text = L["Copy"], tooltip = L["Creates a copy of this look, and this profile uses it."], run = function()
			LookMenu.Copy(name, how.created)
		end },
	}
	if not isDefault then
		actions[#actions + 1] = { text = L["Rename"], tooltip = L["Renames this look in every profile that uses it."], run = function()
			LookMenu.Rename(name)
		end }
	end
	actions[#actions + 1] = { text = L["Reset"], tooltip = L["Returns every option of this look to its default and starts its row design afresh."], run = function()
		LookMenu.Reset(name)
	end }
	NameMenu.AddName(root, {
		text = Looks.DisplayName(name),
		data = name,
		isSelected = function()
			return how.isSelected(name)
		end,
		select = function()
			how.select(name)
		end,
		actions = actions,
		gearTooltip = isDefault and L["Edit, copy or reset"] or L["Edit, copy, rename or reset"],
		deleteTooltip = L["Delete look"],
		delete = not isDefault and function()
			LookMenu.Delete(name)
		end or nil,
	})
end

-- A menu for a dropdown's SetupMenu: the looks, + New look, Import, Share.
-- how: isSelected(name) and select(name) for the looks' radios, and
-- created(name) after a new look or a copy, which the profile then uses.
function LookMenu.Generator(how)
	return function(_, root)
		NameMenu.OneColumn(root)
		for _, name in ipairs(Looks.List()) do
			addLook(root, name, how)
		end
		root:CreateDivider()
		NameMenu.AddNew(root, L["New look"], L["Starts a look with every option at its default, and this profile uses it."], function()
			LookMenu.New(how.created)
		end)
	NameMenu.AddShareEntries(root, function()
		Bus:Send("OpenImportDialog", "looks")
	end, function()
		Bus:Send("OpenShareDialog", "looks")
	end, L["Makes a text of your looks to copy and give to another character or player."])
	end
end

-- The options page's menu: the radios choose the look the profile uses.
LookMenu.Build = LookMenu.Generator({
	isSelected = function(name)
		return Looks.Current() == name
	end,
	select = LookMenu.Use,
})
