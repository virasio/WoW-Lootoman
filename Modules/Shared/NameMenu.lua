local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- Menus for things the player names and keeps (profiles, the loot feed's
-- layouts), in the spirit of Edit Mode's layout menu: a radio per name, with
-- a gear that opens its actions and a button that deletes it, both shown while
-- the pointer is over it (Blizzard's MenuTemplates, as Edit Mode uses them);
-- and the green "+ New …" entry. Names are typed in Blizzard's input dialog,
-- and what cannot be undone is confirmed in its confirmation dialog.
local NameMenu = {}
ns.NameMenu = NameMenu

-- A menu entry's tooltip: its title and what it does.
function NameMenu.Describe(description, title, text)
	description:SetTooltip(function(tooltip)
		GameTooltip_SetTitle(tooltip, title)
		GameTooltip_AddNormalLine(tooltip, text)
	end)
	return description
end

-- One name in a menu. entry = { text, data, isSelected(), select(), actions =
-- { { text, tooltip, run() }, … }, gearTooltip, deleteTooltip, delete() };
-- without delete, a name that cannot be deleted. The gear opens the actions,
-- which do not open on hover; the delete button sits left of the gear.
function NameMenu.AddName(root, entry)
	local radio = root:CreateRadio(entry.text, entry.isSelected, entry.select, entry.data)
	for _, action in ipairs(entry.actions) do
		NameMenu.Describe(radio:CreateButton(action.text, action.run), action.text, action.tooltip)
	end
	radio:DeactivateSubmenu()
	radio:AddInitializer(function(button, description, menu)
		local gear = MenuTemplates.AttachAutoHideGearButton(button)
		MenuTemplates.SetUtilityButtonTooltipText(gear, entry.gearTooltip)
		MenuTemplates.SetUtilityButtonAnchor(gear, MenuVariants.GearButtonAnchor, button)
		MenuTemplates.SetUtilityButtonClickHandler(gear, function()
			description:ForceOpenSubmenu()
		end)
		if entry.delete then
			local remove = MenuTemplates.AttachAutoHideCancelButton(button)
			MenuTemplates.SetUtilityButtonTooltipText(remove, entry.deleteTooltip)
			MenuTemplates.SetUtilityButtonAnchor(remove, MenuVariants.CancelButtonAnchor, gear)
			MenuTemplates.SetUtilityButtonClickHandler(remove, function()
				entry.delete()
				menu:Close()
			end)
		end
	end)
	return radio
end

-- The names in one column, however many there are.
function NameMenu.OneColumn(root)
	root:SetGridMode(MenuConstants.VerticalGridDirection, 1)
end

-- The green "+ New …" entry with Edit Mode's plus; without a callback, it is
-- the parent of a submenu.
function NameMenu.AddNew(root, text, tooltip, callback)
	local entry = root:CreateButton(("%s |cnPURE_GREEN_COLOR:%s|r"):format(CreateAtlasMarkup("editmode-new-layout-plus"), text), callback)
	return NameMenu.Describe(entry, text, tooltip)
end

-- Import and Share, which open the dialogs of profile texts; greyed out, with
-- a tooltip, on a client that cannot make texts.
function NameMenu.AddShareEntries(root, openImport, openShare, shareTooltip)
	local import = root:CreateButton(L["Import"], openImport)
	local share = root:CreateButton(L["Share"], openShare)
	if Compat.CanEncode() then
		NameMenu.Describe(import, L["Import"], L["Reads a text made with Share, on another character or by another player."])
		NameMenu.Describe(share, L["Share"], shareTooltip)
	else
		for _, entry in ipairs({ import, share }) do
			entry:SetEnabled(false)
			NameMenu.Describe(entry, entry == import and L["Import"] or L["Share"], L["This game client cannot make or read profile texts."])
		end
	end
end

-- Asks for a name; initial, if given, is filled in and selected.
function NameMenu.AskName(text, textArg, initial, maxLetters, callback)
	local dialog = StaticPopup_Show("GENERIC_INPUT_BOX", nil, nil, {
		text = text,
		text_arg1 = textArg,
		callback = callback,
		maxLetters = maxLetters,
	})
	if dialog and initial then
		dialog:GetEditBox():SetText(initial)
		dialog:GetEditBox():HighlightText()
	end
end

function NameMenu.Confirm(text, textArg, acceptText, callback)
	StaticPopup_Show("GENERIC_CONFIRMATION", nil, nil, {
		text = text,
		text_arg1 = textArg,
		acceptText = acceptText,
		cancelText = CANCEL,
		callback = callback,
	})
end
