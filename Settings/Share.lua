local _, ns = ...
local Bus, Compat, L, NameMenu, Profiles, Share = ns.Bus, ns.Compat, ns.L, ns.NameMenu, ns.Profiles, ns.Share
local Panel = ns.SettingsPanel

-- The Share and Import dialogs of profile texts (plans/0.1.md, task 16). They
-- open from the profile menu for a whole profile ("profile"), or from a
-- menu of named items, such as the loot feed's layouts, for the items only
-- ("layouts", the name of the collection).
--
-- Both list what a text can hold, with a checkbox each: every module's
-- settings, and indented under them the parts of the module, which can be
-- ticked only while the module's settings are; a part that needs an item
-- (Use layout “Name”) needs that item ticked too. Then each collection under
-- its header, an item per row.
--
-- Share: everything ticked but the items, of which only those the profile
-- uses are; the text of the ticked ones, selected for copying (the client
-- keeps the clipboard to itself). Import: a box to paste a text into; it says
-- what the text holds, all ticked. An item whose name is taken has a choice on
-- its row: keep both (the imported one gets a free name), replace, or keep
-- mine. Parts go into a new profile, which the character then uses, or, after
-- a confirmation, into the current profile. Both dialogs are the player's own
-- frames, built the first time they open, never in combat.
local Dialogs = {}
Panel.Share = Dialogs

Dialogs.WIDTH = 460
local BOX_WIDTH = Dialogs.WIDTH - 60
local ROW = 26
local INDENT = 24

local ERRORS = {
	prefix = L["This is not a Lootoman profile text."],
	newer = L["This text comes from a newer version of Lootoman. Update the addon to import it."],
	encoder = L["This game client cannot make or read profile texts."],
	broken = L["This text is damaged. Copy it again."],
	nothing = L["This text has nothing this version of Lootoman can import."],
}

-- What to do with an imported item whose name is taken, in the order shown.
local HOW = { "both", "replace", "keep" }
local HOW_NAMES = { both = L["Keep both"], replace = L["Replace"], keep = L["Keep mine"] }

local share, import

local function newDialog(title)
	local frame = CreateFrame("Frame", nil, UIParent, "DefaultPanelFlatTemplate")
	frame:SetWidth(Dialogs.WIDTH)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle(title)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	if RegisterGameMenuEscHandler then
		RegisterGameMenuEscHandler(GameMenuEscPriority.AddOn, function()
			if frame:IsShown() then
				frame:Hide()
				return true
			end
			return false
		end)
	end
	frame.rows, frame.headers = {}, {}
	frame.checked, frame.how = {}, {}
	return frame
end

local function newText(parent, font)
	local text = parent:CreateFontString(nil, "ARTWORK", font)
	text:SetWidth(BOX_WIDTH)
	text:SetJustifyH("LEFT")
	return text
end

-- A scrolling box for a long line of text (Blizzard's import dialogs use it).
local function newTextBox(parent, height)
	local box = CreateFrame("ScrollFrame", nil, parent, "InputScrollFrameTemplate")
	box:SetSize(BOX_WIDTH, height)
	-- The template sizes the text to the frame when it loads, before it has a size.
	box.EditBox:SetWidth(BOX_WIDTH - 18)
	box.CharCount:Hide()
	return box
end

local function newButton(parent, text, point, x, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(120, 22)
	button:SetPoint(point, x, 16)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

-- The key of an item in frame.checked: "<collection>/<item>".
local function itemKey(collection, item)
	return collection .. "/" .. item
end

-- The row at index, made the first time: a checkbox with its label, and on
-- an import a choice for a taken name.
local function row(frame, index)
	local entry = frame.rows[index]
	if entry then
		return entry
	end
	entry = {}
	entry.check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	entry.check:SetSize(24, 24)
	entry.check.label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	entry.check.label:SetPoint("LEFT", entry.check, "RIGHT", 2, 0)
	entry.check:SetScript("OnClick", function(check)
		frame.checked[entry.key] = check:GetChecked() and true or false
		frame.update()
	end)
	if frame == import then
		entry.how = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
		entry.how:SetWidth(130)
		entry.how:SetupMenu(function(_, root)
			for _, how in ipairs(HOW) do
				root:CreateRadio(HOW_NAMES[how], function()
					return frame.how[entry.item] == how
				end, function()
					frame.how[entry.item] = how
				end)
			end
		end)
	end
	frame.rows[index] = entry
	return entry
end

local function header(frame, index)
	frame.headers[index] = frame.headers[index] or frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	return frame.headers[index]
end

-- Whether a line can be ticked: a part under a module needs the module's
-- settings ticked, and the item it needs ticked too.
local function usable(frame, line)
	if line.parent and not frame.checked[line.parent] then
		return false
	end
	if line.needs then
		return frame.checked[line.needs] == true
	end
	return true
end

-- Lays the lines out from y down: { kind = "part" | "item" | "header", key,
-- label, indent, item, taken }. Returns the y under the last one.
local function layout(frame, lines, y)
	local rows, headers = 0, 0
	for _, line in ipairs(lines) do
		if line.kind == "header" then
			headers = headers + 1
			local text = header(frame, headers)
			text:ClearAllPoints()
			text:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y - 6)
			text:SetText(line.label)
			text:Show()
			y = y - ROW
		else
			rows = rows + 1
			local entry = row(frame, rows)
			entry.key, entry.item = line.key, line.item
			local enabled = usable(frame, line)
			entry.check:ClearAllPoints()
			entry.check:SetPoint("TOPLEFT", frame, "TOPLEFT", 20 + (line.indent or 0) * INDENT, y)
			entry.check:SetChecked(enabled and frame.checked[line.key] == true)
			entry.check:SetEnabled(enabled)
			entry.check.label:SetText(line.label)
			entry.check.label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
			entry.check:Show()
			entry.check.label:Show()
			if entry.how then
				entry.how:ClearAllPoints()
				entry.how:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, y)
				entry.how:SetShown(line.taken ~= nil)
				entry.how:GenerateMenu()
			end
			y = y - ROW
		end
	end
	for index = rows + 1, #frame.rows do
		local entry = frame.rows[index]
		entry.check:Hide()
		entry.check.label:Hide()
		if entry.how then
			entry.how:Hide()
		end
	end
	for index = headers + 1, #frame.headers do
		frame.headers[index]:Hide()
	end
	return y
end

-- The ticked lines that can be ticked: { parts = { name, … }, items = {
-- [collection] = { item, … } } }.
local function chosen(frame)
	local result = { parts = {}, items = {} }
	for _, line in ipairs(frame.lines) do
		if line.kind ~= "header" and frame.checked[line.key] and usable(frame, line) then
			if line.kind == "part" then
				result.parts[#result.parts + 1] = line.key
			else
				result.items[line.collection] = result.items[line.collection] or {}
				table.insert(result.items[line.collection], line.item)
			end
		end
	end
	return result
end

-- The lines of the parts, for the profile mode: each module's settings with
-- its parts indented under it. data(name) is a part's data, for its label.
local function partLines(names, data)
	local lines = {}
	for _, entry in ipairs(Share.Parts()) do
		if not names or names[entry.name] then
			local value = data(entry.name)
			local collection, item = Share.Needs(entry.name, value)
			lines[#lines + 1] = {
				kind = "part",
				key = entry.name,
				label = Share.Label(entry.name, value),
				parent = entry.parent,
				indent = entry.parent and 1 or 0,
				needs = collection and item and itemKey(collection, item) or nil,
			}
		end
	end
	return lines
end

-- The lines of a collection's items under its header.
local function itemLines(lines, collection, names, taken)
	if #names == 0 then
		return
	end
	lines[#lines + 1] = { kind = "header", label = collection.label }
	for _, item in ipairs(names) do
		lines[#lines + 1] = {
			kind = "item",
			key = itemKey(collection.name, item),
			collection = collection.name,
			item = item,
			label = collection.display(item),
			indent = 1,
			taken = taken and taken[item],
		}
	end
end

-- Share: the text of the ticked lines, made again whenever a checkbox changes.
function Dialogs.UpdateShare()
	local y = layout(share, share.lines, -84)
	share.box:ClearAllPoints()
	share.box:SetPoint("TOPLEFT", share, "TOPLEFT", 30, y - 10)
	share:SetHeight(-y + 10 + 110 + 60)
	local choice = chosen(share)
	local empty = #choice.parts == 0 and next(choice.items) == nil
	share.text = not empty and Share.Export({ parts = choice.parts, collections = choice.items }) or ""
	share.box.EditBox:SetText(share.text)
	share.box.EditBox:SetFocus()
	share.box.EditBox:HighlightText()
end

local function buildShare()
	local frame = newDialog(L["Share"])
	frame.hint = newText(frame, "GameFontHighlight")
	frame.hint:SetPoint("TOPLEFT", 24, -34)
	frame.box = newTextBox(frame, 110)
	-- The text stays as it was made: typing changes nothing, and it is selected again.
	frame.box.EditBox:HookScript("OnTextChanged", function(editBox, userInput)
		if userInput then
			editBox:SetText(frame.text or "")
			editBox:HighlightText()
		end
	end)
	frame.box.EditBox:HookScript("OnEditFocusGained", function(editBox)
		editBox:HighlightText()
	end)
	newButton(frame, CLOSE, "BOTTOMRIGHT", -20, function()
		frame:Hide()
	end)
	frame.update = Dialogs.UpdateShare
	return frame
end

-- A name for the new profile that no profile has yet.
local function freeName()
	local name, number = L["Imported"], 1
	while Profiles.Exists(name) do
		number = number + 1
		name = ("%s %d"):format(L["Imported"], number)
	end
	return name
end

-- Import: the lines, the place for the parts and the button follow what is
-- ticked.
function Dialogs.UpdateImport()
	local y = layout(import, import.lines, -210)
	local choice = chosen(import)
	local parts = #choice.parts > 0
	local showTarget = import.mode == "profile"
	import.nameLabel:SetShown(showTarget)
	import.name:SetShown(showTarget)
	import.replace:SetShown(showTarget)
	import.replace.label:SetShown(showTarget)
	if showTarget then
		import.nameLabel:ClearAllPoints()
		import.nameLabel:SetPoint("TOPLEFT", import, "TOPLEFT", 24, y - 10)
		import.name:ClearAllPoints()
		import.name:SetPoint("TOPLEFT", import, "TOPLEFT", 30, y - 28)
		import.replace:ClearAllPoints()
		import.replace:SetPoint("TOPLEFT", import, "TOPLEFT", 20, y - 54)
		y = y - 80
	end
	import:SetHeight(-y + 60)
	local replace = import.replace:GetChecked()
	import.name:SetEnabled(parts and not replace)
	import.replace:SetEnabled(parts)
	local named = not parts or replace or import.name:GetText():match("%S") ~= nil
	import.importButton:SetEnabled(import.read ~= nil and (parts or next(choice.items) ~= nil) and named)
end

-- Reads the pasted text again: what it holds, everything ticked, every taken
-- name kept as both.
function Dialogs.ReadImport()
	local read, err = Share.Read(import.box.EditBox:GetText())
	local lines = {}
	if read then
		if import.mode == "profile" then
			local names = {}
			for _, name in ipairs(read.names) do
				names[name] = true
			end
			lines = partLines(names, function(name)
				return read.sections[name]
			end)
		end
		for _, collection in ipairs(Share.Collections()) do
			local found = read.collections[collection.name]
			if found and (import.mode == "profile" or import.mode == collection.name) then
				itemLines(lines, collection, found.names, found.taken)
			end
		end
	end
	import.read = #lines > 0 and read or nil
	import.lines = lines
	import.checked, import.how = {}, {}
	for _, line in ipairs(lines) do
		if line.key then
			import.checked[line.key] = true
		end
		if line.taken then
			import.how[line.item] = "both"
		end
	end
	if read and #lines > 0 then
		import.status:SetText(#read.newer > 0
			and L["It holds the parts ticked below. Left out, from a newer version of Lootoman: %s."]:format(table.concat(read.newer, ", "))
			or L["It holds the parts ticked below."])
	elseif read then
		import.status:SetText(ERRORS.nothing)
	else
		import.status:SetText(err == "empty" and L["Paste a text made with Share."] or ERRORS[err])
	end
	Dialogs.UpdateImport()
end

local function finishImport(read, choice)
	local name, renamed = Share.Import(read, choice)
	if #choice.parts > 0 and not name then
		-- renamed is the reason the new profile's name was not taken.
		Panel.ProfileTools.report(nil, renamed)
		return
	end
	import:Hide()
	if name then
		ns.Print(L["Imported into profile “%s”."]:format(Panel.ProfileTools.displayName(name)))
	end
	for collectionName, items in pairs(renamed or {}) do
		local collection, names = Share.GetCollection(collectionName), {}
		for _, localName in pairs(items) do
			names[#names + 1] = collection.display(localName)
		end
		if #names > 0 then
			table.sort(names)
			ns.Print(L["Imported %s: %s."]:format(collection.label, table.concat(names, ", ")))
		end
	end
	if read.skipped > 0 then
		ns.Print(L["Values left out, unknown to this version of Lootoman or not valid: %d."]:format(read.skipped))
	end
end

function Dialogs.Import()
	local read = import.read
	if not read then
		return
	end
	local ticked = chosen(import)
	local choice = { parts = ticked.parts, collections = {} }
	for collectionName, items in pairs(ticked.items) do
		choice.collections[collectionName] = {}
		for _, item in ipairs(items) do
			choice.collections[collectionName][item] = import.how[item] or "both"
		end
	end
	if #choice.parts > 0 and import.replace:GetChecked() then
		local current = Profiles.GetCurrent()
		NameMenu.Confirm(L["Replace the ticked parts of profile “%s” with the imported ones?"],
			Panel.ProfileTools.displayName(current), L["Replace"], function()
				finishImport(read, choice)
			end)
	else
		choice.newName = #choice.parts > 0 and import.name:GetText() or nil
		finishImport(read, choice)
	end
end

local function buildImport()
	local frame = newDialog(L["Import"])
	local label = newText(frame, "GameFontNormal")
	label:SetPoint("TOPLEFT", 24, -36)
	label:SetText(L["Text:"])
	frame.box = newTextBox(frame, 100)
	frame.box:SetPoint("TOPLEFT", 30, -58)
	frame.box.EditBox:HookScript("OnTextChanged", Dialogs.ReadImport)
	frame.status = newText(frame, "GameFontHighlight")
	frame.status:SetPoint("TOPLEFT", 24, -170)
	frame.nameLabel = newText(frame, "GameFontNormal")
	frame.nameLabel:SetText(L["Name of the new profile:"])
	frame.name = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.name:SetSize(220, 20)
	frame.name:SetAutoFocus(false)
	frame.name:SetMaxLetters(Profiles.MAX_NAME_LENGTH)
	frame.name:HookScript("OnTextChanged", Dialogs.UpdateImport)
	frame.replace = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	frame.replace:SetSize(24, 24)
	frame.replace.label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.replace.label:SetPoint("LEFT", frame.replace, "RIGHT", 2, 0)
	frame.replace.label:SetText(L["Put the parts into the current profile instead"])
	frame.replace:SetScript("OnClick", Dialogs.UpdateImport)
	frame.importButton = newButton(frame, L["Import"], "BOTTOMRIGHT", -20, Dialogs.Import)
	newButton(frame, CANCEL, "BOTTOMLEFT", 20, function()
		frame:Hide()
	end)
	frame.update = Dialogs.UpdateImport
	return frame
end

-- The dialogs are built the first time, which waits for the end of combat.
local function ready()
	if share then
		return true
	end
	if Compat.InCombat() then
		ns.Print(L["This window opens out of combat."])
		return false
	end
	-- import first: rows ask which dialog they belong to.
	import = buildImport()
	share = buildShare()
	Dialogs.shareFrame, Dialogs.importFrame = share, import
	share:Hide()
	import:Hide()
	return true
end

-- mode: "profile", or the name of a collection to share only its items.
function Dialogs.OpenShare(mode)
	if not ready() then
		return
	end
	import:Hide()
	share.mode = mode
	share.hint:SetText(mode == "profile"
		and L["Copy this text with Ctrl+C and give it to another character or player: they paste it under Import in the profile menu. It holds the parts ticked below."]
		or L["Copy this text with Ctrl+C and give it to another character or player: they paste it under Import in the same menu. It holds the parts ticked below."])
	local lines = {}
	if mode == "profile" then
		lines = partLines(nil, Share.Get)
	end
	-- Ticked at first: every part, and the items the profile uses.
	share.checked = {}
	for _, line in ipairs(lines) do
		share.checked[line.key] = true
		if line.needs then
			share.checked[line.needs] = true
		end
	end
	for _, collection in ipairs(Share.Collections()) do
		if mode == "profile" or mode == collection.name then
			itemLines(lines, collection, collection.list())
		end
	end
	if mode ~= "profile" then
		for _, line in ipairs(partLines(nil, Share.Get)) do
			if line.needs then
				share.checked[line.needs] = true
			end
		end
	end
	share.lines = lines
	share:Show()
	Dialogs.UpdateShare()
end

function Dialogs.OpenImport(mode)
	if not ready() then
		return
	end
	share:Hide()
	import.mode = mode
	import.box.EditBox:SetText("")
	import.name:SetText(freeName())
	import.replace:SetChecked(false)
	Dialogs.ReadImport()
	import:Show()
	import.box.EditBox:SetFocus()
end

-- From the menus of named items in modules (the designer's layout menu).
Bus:On("OpenShareDialog", Dialogs, function(_, mode)
	Dialogs.OpenShare(mode)
end)
Bus:On("OpenImportDialog", Dialogs, function(_, mode)
	Dialogs.OpenImport(mode)
end)
