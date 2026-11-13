local _, ns = ...
local Bus, L, NameMenu = ns.Bus, ns.L, ns.NameMenu

-- The menu of feed looks (Looks.lua), like the profile menu (NameMenu):
-- every look as a radio that the profile then uses, with Edit (its window,
-- LookWindow.lua), Copy, Rename and Reset under its gear and a delete button;
-- + New look; Import and Share, which open the dialogs of profile texts for
-- looks. Names are typed in the game's input dialog, and what cannot be
-- undone is confirmed. The options page and Edit Mode show it alike.
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

-- A new look, which the profile then uses.
function LookMenu.New()
	askName(L["Name of the new look:"], nil, nil, function(name)
		local created = report(Looks.Create(name))
		if created then
			LookMenu.Use(created)
		end
	end)
end

function LookMenu.Copy(source)
	askName(L["Name of the copy of “%s”:"], Looks.DisplayName(source), nil, function(name)
		local copied = report(Looks.Copy(source, name))
		if copied then
			LookMenu.Use(copied)
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

local function addLook(root, name)
	local isDefault = name == Looks.DEFAULT
	local actions = {
		{ text = L["Edit"], tooltip = L["Opens the window of this look, to change its settings and its row design."], run = function()
			LookMenu.Edit(name)
		end },
		{ text = L["Copy"], tooltip = L["Creates a copy of this look, and this profile uses it."], run = function()
			LookMenu.Copy(name)
		end },
	}
	if not isDefault then
		actions[#actions + 1] = { text = L["Rename"], tooltip = L["Renames this look in every profile that uses it."], run = function()
			LookMenu.Rename(name)
		end }
	end
	actions[#actions + 1] = { text = L["Reset"], tooltip = L["Returns every setting of this look to its default and starts its row design afresh."], run = function()
		LookMenu.Reset(name)
	end }
	NameMenu.AddName(root, {
		text = Looks.DisplayName(name),
		data = name,
		isSelected = function()
			return Looks.Current() == name
		end,
		select = function()
			LookMenu.Use(name)
		end,
		actions = actions,
		gearTooltip = isDefault and L["Edit, copy or reset"] or L["Edit, copy, rename or reset"],
		deleteTooltip = L["Delete look"],
		delete = not isDefault and function()
			LookMenu.Delete(name)
		end or nil,
	})
end

-- The menu, for a dropdown's SetupMenu: the looks, + New look, Import, Share.
function LookMenu.Build(_, root)
	NameMenu.OneColumn(root)
	for _, name in ipairs(Looks.List()) do
		addLook(root, name)
	end
	root:CreateDivider()
	NameMenu.AddNew(root, L["New look"], L["Starts a look with every setting at its default, and this profile uses it."], LookMenu.New)
	NameMenu.AddShareEntries(root, function()
		Bus:Send("OpenImportDialog", "looks")
	end, function()
		Bus:Send("OpenShareDialog", "looks")
	end, L["Makes a text of your looks to copy and give to another character or player."])
end
