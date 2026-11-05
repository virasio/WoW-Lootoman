local _, ns = ...
local Bus, Compat, Currencies, L, NameMenu, Text = ns.Bus, ns.Compat, ns.Currencies, ns.L, ns.NameMenu, ns.Text

-- The bar editor: what is on a bar and what is not.
--
-- On top, the set the profile uses, with a menu like the row designer's
-- layout menu (every set, with Copy, Rename and Reset under its gear and a
-- delete button; + New set; Import and Share), and the set's bars to choose
-- from, with New bar and Remove bar. Below, two lists: on the left what is on
-- the chosen bar, in its order (drop an item from the bags on the list, or
-- type its ID); on the right the currencies and money
-- not on it, by name, and the bag items taken off a bar while the window is
-- open, so a wrong click is undone quickly (closing the window forgets them).
-- The buttons between the lists move the chosen row across: up to the bar, or
-- off it. Rows are also dragged, as entries are on a bar: the row dims, a copy
-- follows the mouse, a line marks where it will go in the bar's list, and the
-- other list lights up when the row would leave the bar. Dropped in the bar's
-- list, a row goes there (from either list); dropped on the other list, it
-- leaves the bar; anywhere else, nothing happens.
--
-- While a bar asks whether to take an entry off, nothing here changes a bar
-- (BarFrame.Asking).
--
-- The window is the player's own, built the first time it opens, never in
-- combat; Escape and its close button hide it.
local Bars = ns.Modules:Get("Bars")
local Sets, BarFrame = Bars.Sets, Bars.BarFrame
local Editor = {}
Bars.Editor = Editor

Editor.NAME = "LootomanBarEditor"
Editor.WIDTH = 640
Editor.HEIGHT = 480
Editor.ROW_HEIGHT = 22
Editor.ROWS = 13
Editor.LIST_WIDTH = 270

local window
local barID
-- Bag items taken off a bar while the window is open, by item ID.
local removed = {}

local function forgetRemoved()
	for itemID in pairs(removed) do
		removed[itemID] = nil
	end
end

local ERRORS = {
	empty = L["Enter a set name."],
	too_long = L["The set name is too long."],
	exists = L["A set with this name already exists."],
	missing = L["This set no longer exists."],
	full = L["This set holds as many bars as it can."],
}

local function currentSet()
	return Sets.Current()
end

-- The chosen bar of the set in use: the one asked for, or the first.
function Editor.Bar()
	local set = Sets.Get(currentSet())
	local bar = barID and Sets.Bar(currentSet(), barID)
	bar = bar or set.bars[1]
	barID = bar and bar.id
	return bar
end

local function changed()
	Sets.Changed(currentSet())
end

local function keyOf(entry)
	return entry.kind .. ":" .. entry.id
end

-- The two lists of a bar: { left = { { entry, look } … } in the bar's order,
-- right = the same, by name: money and the currencies not on the bar, and the
-- items taken off while the window is open }.
function Editor.Lists(bar)
	local left, on = {}, {}
	for index, entry in ipairs(Bars.Entries(bar)) do
		on[keyOf(entry)] = true
		left[#left + 1] = { entry = entry, index = index, look = Bars.Describe(entry) or { name = keyOf(entry), text = "" } }
	end
	local right = {}
	local money = { kind = "money", id = 0 }
	if not on[keyOf(money)] then
		right[#right + 1] = { entry = money, look = Bars.Describe(money) }
	end
	for _, currencyID in ipairs(Currencies.IDs()) do
		local entry = { kind = "currency", id = currencyID }
		local look = not on[keyOf(entry)] and Bars.Describe(entry)
		if look then
			right[#right + 1] = { entry = entry, look = look }
		end
	end
	for itemID in pairs(removed) do
		local entry = { kind = "item", id = itemID }
		if not on[keyOf(entry)] then
			right[#right + 1] = { entry = entry, look = Bars.Describe(entry) }
		end
	end
	table.sort(right, function(a, b)
		local nameA, nameB = Text.FoldCase(a.look.name), Text.FoldCase(b.look.name)
		if nameA ~= nameB then
			return nameA < nameB
		end
		return keyOf(a.entry) < keyOf(b.entry)
	end)
	return { left = left, right = right }
end

-- Puts an entry at the end of a bar, unless it is on it already.
function Editor.Add(bar, entry)
	if not bar or BarFrame.Asking() then
		return false
	end
	local entries = Bars.OwnEntries(bar)
	for _, existing in ipairs(entries) do
		if keyOf(existing) == keyOf(entry) then
			return false
		end
	end
	entries[#entries + 1] = { kind = entry.kind, id = entry.id }
	removed[entry.kind == "item" and entry.id or 0] = nil
	changed()
	return true
end

-- Takes an entry off a bar; a bag item stays in the right list while the
-- window is open.
function Editor.Remove(bar, index)
	if not bar or BarFrame.Asking() then
		return nil
	end
	local entries = Bars.OwnEntries(bar)
	local entry = table.remove(entries, index)
	if entry and entry.kind == "item" and window and window:IsShown() then
		removed[entry.id] = true
	end
	changed()
	return entry
end

-- An item by its ID, typed or dropped from the bags.
function Editor.AddItem(bar, itemID)
	itemID = tonumber(itemID)
	if not itemID or itemID < 1 or itemID ~= math.floor(itemID) then
		ns.Print(L["Type an item's number (its ID), such as 2589."])
		return false
	end
	return Editor.Add(bar, { kind = "item", id = itemID })
end

function Editor.Move(bar, from, to)
	if not bar or BarFrame.Asking() then
		return
	end
	BarFrame.Move(bar, from, to)
	changed()
end

-- The items taken off while the window is open (for tests).
function Editor.Removed()
	return removed
end

local function report(result, err)
	if not result then
		ns.Print(ERRORS[err] or tostring(err))
	end
	Editor.Refresh()
	return result
end

-- A set action, and an answer to its question later: nothing while a bar
-- asks whether to take an entry off.
local function unlessAsking(action)
	return function(...)
		if not BarFrame.Asking() then
			return action(...)
		end
	end
end

local function askName(text, textArg, callback)
	NameMenu.AskName(text, textArg, nil, Sets.MAX_NAME_LENGTH, callback)
end

local function addSet(root, name)
	local isDefault = name == Sets.DEFAULT
	local actions = {
		{ text = L["Copy"], tooltip = L["Creates a copy of this set, and this profile uses it."], run = unlessAsking(function()
			askName(L["Name of the copy of “%s”:"], Sets.DisplayName(name), unlessAsking(function(newName)
				local copied = report(Sets.Copy(name, newName))
				if copied then
					report(Sets.Use(copied))
				end
			end))
		end) },
	}
	if not isDefault then
		actions[#actions + 1] = { text = L["Rename"], tooltip = L["Renames this set in every profile that uses it."], run = unlessAsking(function()
			NameMenu.AskName(L["New name of “%s”:"], name, name, Sets.MAX_NAME_LENGTH, unlessAsking(function(newName)
				report(Sets.Rename(name, newName))
			end))
		end) }
	end
	actions[#actions + 1] = { text = L["Reset"], tooltip = L["Leaves this set one bar with the backpack's currencies."], run = unlessAsking(function()
		NameMenu.Confirm(L["Reset bar set “%s”?"], Sets.DisplayName(name), L["Reset"], unlessAsking(function()
			report(Sets.Reset(name))
		end))
	end) }
	NameMenu.AddName(root, {
		text = Sets.DisplayName(name),
		data = name,
		isSelected = function()
			return currentSet() == name
		end,
		select = unlessAsking(function()
			barID = nil
			report(Sets.Use(name))
		end),
		actions = actions,
		gearTooltip = isDefault and L["Copy or reset"] or L["Copy, rename or reset"],
		deleteTooltip = L["Delete set"],
		delete = not isDefault and unlessAsking(function()
			NameMenu.Confirm(L["Delete bar set “%s”? Profiles that use it switch to the Default set."], name, L["Delete"], unlessAsking(function()
				report(Sets.Delete(name))
			end))
		end) or nil,
	})
end

local function buildSetMenu(_, root)
	NameMenu.OneColumn(root)
	for _, name in ipairs(Sets.List()) do
		addSet(root, name)
	end
	root:CreateDivider()
	NameMenu.AddNew(root, L["New set"], L["Starts a set with one bar, and this profile uses it."], unlessAsking(function()
		askName(L["Name of the new set:"], nil, unlessAsking(function(name)
			local created = report(Sets.Create(name))
			if created then
				barID = nil
				report(Sets.Use(created))
			end
		end))
	end))
	NameMenu.AddShareEntries(root, unlessAsking(function()
		Bus:Send("OpenImportDialog", "barSets")
	end), function()
		Bus:Send("OpenShareDialog", "barSets")
	end, L["Makes a text of your bar sets to copy and give to another character or player."])
end

local function buildBarMenu(_, root)
	for index, bar in ipairs(Sets.Get(currentSet()).bars) do
		root:CreateRadio(L["Bar %d"]:format(index), function()
			return bar.id == barID
		end, function()
			barID = bar.id
			Editor.Refresh()
		end)
	end
end

-- A row on the move: { list, row, item }; and the copy that follows the mouse.
local dragging, ghost

local function getGhost()
	if not ghost then
		ghost = CreateFrame("Frame", nil, UIParent)
		ghost:SetFrameStrata("TOOLTIP")
		ghost:SetSize(Editor.LIST_WIDTH - 24, Editor.ROW_HEIGHT)
		ghost.Background = ghost:CreateTexture(nil, "BACKGROUND")
		ghost.Background:SetAllPoints()
		ghost.Background:SetColorTexture(0, 0, 0, 0.6)
		ghost.Icon = ghost:CreateTexture(nil, "ARTWORK")
		ghost.Icon:SetSize(Editor.ROW_HEIGHT - 4, Editor.ROW_HEIGHT - 4)
		ghost.Icon:SetPoint("LEFT", 2, 0)
		ghost.Name = ghost:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		ghost.Name:SetPoint("LEFT", ghost.Icon, "RIGHT", 6, 0)
		ghost:SetAlpha(0.9)
		ghost:SetScript("OnUpdate", function()
			Editor.FollowDrag()
		end)
		ghost:Hide()
	end
	return ghost
end

-- The copy of a dragged row (for tests).
function Editor.Ghost()
	return getGhost()
end

-- Where a drag would end now: "left" and the place in the bar's entries
-- before which the row goes, "right" for off the bar, or nil for nowhere.
local function dropTarget()
	local left = window.left
	if left.box:IsMouseOver() then
		local _, y = GetCursorPosition()
		local top = left.content:GetTop() or 0
		local count = #Bars.Entries(Editor.Bar())
		local gap = math.floor((top - y / left.content:GetEffectiveScale()) / Editor.ROW_HEIGHT + 0.5)
		return "left", math.min(math.max(gap, 0), count) + 1
	elseif dragging.list == left and window.right.box:IsMouseOver() then
		return "right"
	end
end

-- While a row is dragged: the copy follows the mouse, the line shows where it
-- goes in the bar's list, the other list lights up when it would leave the bar.
function Editor.FollowDrag()
	if not dragging or not window then
		return
	end
	local copy = getGhost()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	copy:ClearAllPoints()
	copy:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale)
	local target, place = dropTarget()
	local marker = window.left.Marker
	marker:SetShown(target == "left")
	if target == "left" then
		local offset = -(place - 1) * Editor.ROW_HEIGHT + 1
		marker:ClearAllPoints()
		marker:SetPoint("TOPLEFT", window.left.content, "TOPLEFT", 0, offset)
		marker:SetPoint("TOPRIGHT", window.left.content, "TOPRIGHT", 0, offset)
	end
	window.right.box.Target:SetShown(target == "right")
end

local function startDrag(list, row)
	if not row.item or BarFrame.Asking() then
		return
	end
	dragging = { list = list, row = row, item = row.item }
	row:SetAlpha(0.35)
	local copy = getGhost()
	copy.Icon:SetTexture(row.item.look.icon or row.item.look.listIcon)
	copy.Name:SetText(row.item.look.name)
	copy:Show()
	Editor.FollowDrag()
end

-- Ends a drag without doing anything; returns what was dragged.
local function endDrag()
	local drag = dragging
	dragging = nil
	if ghost then
		ghost:Hide()
	end
	if window then
		window.left.Marker:Hide()
		window.right.box.Target:Hide()
	end
	if drag then
		drag.row:SetAlpha(1)
	end
	return drag
end

local function stopDrag()
	if not dragging then
		return
	end
	local target, place = dropTarget()
	local drag = endDrag()
	local bar = Editor.Bar()
	local item = drag.item
	if not bar or not target then
		return
	end
	if target == "right" then
		if Editor.Remove(bar, item.index) then
			window.right.chosen, window.left.chosen = keyOf(item.entry), nil
		end
	elseif drag.list == window.left then
		Editor.Move(bar, item.index, place)
	elseif Editor.Add(bar, item.entry) then
		window.left.chosen, window.right.chosen = keyOf(item.entry), nil
		Editor.Move(bar, #Bars.Entries(bar), place)
	end
	Editor.Refresh()
end

-- A list's row: an icon and the name, chosen with a click, and dragged.
local function createRow(list, index)
	local row = CreateFrame("Button", nil, list.content)
	row:SetSize(Editor.LIST_WIDTH - 24, Editor.ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * Editor.ROW_HEIGHT)
	row.Selected = row:CreateTexture(nil, "BACKGROUND")
	row.Selected:SetAllPoints()
	row.Selected:SetColorTexture(1, 0.82, 0, 0.25)
	row.Selected:Hide()
	row.Highlight = row:CreateTexture(nil, "HIGHLIGHT")
	row.Highlight:SetAllPoints()
	row.Highlight:SetColorTexture(1, 1, 1, 0.1)
	row.Icon = row:CreateTexture(nil, "ARTWORK")
	row.Icon:SetSize(Editor.ROW_HEIGHT - 4, Editor.ROW_HEIGHT - 4)
	row.Icon:SetPoint("LEFT", 2, 0)
	row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
	row.Name:SetPoint("RIGHT", -4, 0)
	row.Name:SetJustifyH("LEFT")
	row.Name:SetWordWrap(false)
	row:SetScript("OnClick", function(self)
		list.chosen = self.item and keyOf(self.item.entry)
		Editor.Refresh()
	end)
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnDragStart", function(self)
		startDrag(list, self)
	end)
	row:SetScript("OnDragStop", stopDrag)
	list.rows[index] = row
	return row
end

local function fill(list, items)
	list.items = items
	for index, item in ipairs(items) do
		local row = list.rows[index] or createRow(list, index)
		row.item = item
		row.Icon:SetTexture(item.look.icon or item.look.listIcon)
		row.Name:SetText(item.look.name)
		row.Selected:SetShown(list.chosen == keyOf(item.entry))
		row:Show()
	end
	for index = #items + 1, #list.rows do
		list.rows[index].item = nil
		list.rows[index]:Hide()
	end
	list.content:SetHeight(math.max(1, #items) * Editor.ROW_HEIGHT)
end

-- The chosen row of a list, as { entry, index, look }.
local function chosenItem(list)
	for _, item in ipairs(list.items or {}) do
		if keyOf(item.entry) == list.chosen then
			return item
		end
	end
end

function Editor.Refresh()
	if not window or not window:IsShown() then
		return
	end
	local bar = Editor.Bar()
	window.setMenu:GenerateMenu()
	window.barMenu:GenerateMenu()
	window.barMenu:SetDefaultText(bar and L["Bar %d"]:format(select(2, Sets.Bar(currentSet(), bar.id))) or L["No bars"])
	window.remove:SetEnabled(bar ~= nil)
	window.addItem:SetEnabled(bar ~= nil)
	if not bar then
		fill(window.left, {})
		fill(window.right, {})
		return
	end
	local lists = Editor.Lists(bar)
	fill(window.left, lists.left)
	fill(window.right, lists.right)
	window.toBar:SetEnabled(chosenItem(window.right) ~= nil)
	window.offBar:SetEnabled(chosenItem(window.left) ~= nil)
end

local function createList(parent, title, x)
	local list = { rows = {} }
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT", x, -96)
	label:SetText(title)
	local box = CreateFrame("Frame", nil, parent)
	box:SetPoint("TOPLEFT", x, -116)
	box:SetSize(Editor.LIST_WIDTH, Editor.ROWS * Editor.ROW_HEIGHT)
	box.Background = box:CreateTexture(nil, "BACKGROUND")
	box.Background:SetAllPoints()
	box.Background:SetColorTexture(0, 0, 0, 0.3)
	-- Lit while a row dragged from the bar's list would leave the bar here.
	box.Target = box:CreateTexture(nil, "BORDER")
	box.Target:SetAllPoints()
	box.Target:SetColorTexture(1, 0.82, 0, 0.15)
	box.Target:Hide()
	local scroll = CreateFrame("ScrollFrame", nil, box, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 2, -2)
	scroll:SetPoint("BOTTOMRIGHT", -20, 2)
	if scroll.ScrollBar then
		scroll.ScrollBar:SetHideIfUnscrollable(true)
	end
	list.content = CreateFrame("Frame", nil, scroll)
	list.content:SetSize(Editor.LIST_WIDTH - 24, Editor.ROW_HEIGHT)
	scroll:SetScrollChild(list.content)
	-- Where a dragged row goes in the bar's list.
	list.Marker = list.content:CreateTexture(nil, "OVERLAY")
	list.Marker:SetHeight(2)
	list.Marker:SetColorTexture(1, 0.82, 0, 1)
	list.Marker:Hide()
	list.box = box
	return list
end

-- An item dropped on the bar's list from the bags.
local function receiveItem()
	local itemID = Compat.GetCursorItemID()
	local bar = Editor.Bar()
	if itemID and bar and not BarFrame.Asking() then
		Compat.ClearCursor()
		Editor.AddItem(bar, itemID)
	end
end

local function build()
	local frame = CreateFrame("Frame", Editor.NAME, UIParent, "DefaultPanelFlatTemplate")
	window = frame
	frame:SetSize(Editor.WIDTH, Editor.HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetTitle(L["Currency bars"])
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	-- Escape closes it as it closes the game's own windows (see the designer).
	table.insert(UISpecialFrames, Editor.NAME)

	local setLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	setLabel:SetPoint("TOPLEFT", 20, -36)
	setLabel:SetText(L["Set:"])
	frame.setMenu = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	frame.setMenu:SetPoint("LEFT", setLabel, "RIGHT", 8, 0)
	frame.setMenu:SetWidth(200)
	frame.setMenu:SetupMenu(buildSetMenu)

	local barLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	barLabel:SetPoint("TOPLEFT", 20, -68)
	barLabel:SetText(L["Bar:"])
	frame.barMenu = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	frame.barMenu:SetPoint("LEFT", barLabel, "RIGHT", 8, 0)
	frame.barMenu:SetWidth(120)
	frame.barMenu:SetupMenu(buildBarMenu)
	frame.add = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.add:SetSize(110, 22)
	frame.add:SetPoint("LEFT", frame.barMenu, "RIGHT", 8, 0)
	frame.add:SetText(L["New bar"])
	frame.add:SetScript("OnClick", function()
		if BarFrame.Asking() then
			return
		end
		local id = report(Sets.AddBar(currentSet()))
		if id then
			barID = id
			Editor.Refresh()
		end
	end)
	frame.remove = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.remove:SetSize(110, 22)
	frame.remove:SetPoint("LEFT", frame.add, "RIGHT", 4, 0)
	frame.remove:SetText(L["Remove bar"])
	frame.remove:SetScript("OnClick", function()
		local bar = Editor.Bar()
		if bar and not BarFrame.Asking() then
			barID = nil
			report(Sets.RemoveBar(currentSet(), bar.id))
		end
	end)

	frame.left = createList(frame, L["On the bar"], 20)
	frame.right = createList(frame, L["Not on the bar"], Editor.WIDTH - 20 - Editor.LIST_WIDTH)
	frame.left.box:EnableMouse(true)
	frame.left.box:SetScript("OnReceiveDrag", receiveItem)
	frame.left.box:SetScript("OnMouseUp", receiveItem)

	-- Between the lists: up to the bar, and off it.
	local middle = Editor.WIDTH / 2
	frame.toBar = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.toBar:SetSize(40, 24)
	frame.toBar:SetPoint("TOP", frame, "TOPLEFT", middle, -200)
	frame.toBar:SetText("<")
	frame.toBar:SetScript("OnClick", function()
		local item = chosenItem(frame.right)
		if item and Editor.Add(Editor.Bar(), item.entry) then
			frame.left.chosen, frame.right.chosen = keyOf(item.entry), nil
			Editor.Refresh()
		end
	end)
	frame.offBar = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.offBar:SetSize(40, 24)
	frame.offBar:SetPoint("TOP", frame.toBar, "BOTTOM", 0, -8)
	frame.offBar:SetText(">")
	frame.offBar:SetScript("OnClick", function()
		local item = chosenItem(frame.left)
		if item and Editor.Remove(Editor.Bar(), item.index) then
			frame.right.chosen, frame.left.chosen = keyOf(item.entry), nil
			Editor.Refresh()
		end
	end)

	-- An item by its ID, under the bar's list.
	frame.itemID = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.itemID:SetSize(120, 22)
	frame.itemID:SetPoint("TOPLEFT", frame.left.box, "BOTTOMLEFT", 6, -10)
	frame.itemID:SetAutoFocus(false)
	frame.itemID:SetNumeric(true)
	frame.addItem = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.addItem:SetSize(130, 22)
	frame.addItem:SetPoint("LEFT", frame.itemID, "RIGHT", 6, 0)
	frame.addItem:SetText(L["Add item by ID"])
	local function addTyped()
		if Editor.AddItem(Editor.Bar(), frame.itemID:GetText()) then
			frame.itemID:SetText("")
		end
		frame.itemID:ClearFocus()
	end
	frame.addItem:SetScript("OnClick", addTyped)
	frame.itemID:SetScript("OnEnterPressed", addTyped)
	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", 20, 14)
	hint:SetPoint("BOTTOMRIGHT", -20, 14)
	hint:SetJustifyH("LEFT")
	hint:SetText(L["Drag rows up and down or from one list to the other, or drop an item from your bags on the left list. Width, gap and size: in Edit Mode."])

	frame:SetScript("OnShow", Editor.Refresh)
	frame:SetScript("OnHide", function()
		endDrag()
		forgetRemoved()
	end)
	Bus:On("BarSetChanged", Editor, Editor.Refresh)
	Bus:On("ProfileChanged", Editor, Editor.Refresh)
	Bus:On("CurrenciesChanged", Editor, Editor.Refresh)
	Bus:On("SettingChanged", Editor, function(_, module, key)
		if module == Bars.name and key == "set" then
			Editor.Refresh()
		end
	end)
end

-- Opens the editor on a bar of the set in use (its id), or the first.
function Editor.Open(id)
	if not window then
		if Compat.InCombat() then
			ns.Print(L["This window opens out of combat."])
			return
		end
		build()
	end
	barID = id or barID
	window:Show()
	Editor.Refresh()
end

function Editor.Window()
	return window
end

ns.Slash.Register("bars", function()
	Editor.Open()
end, L["/lootoman bars: open the currency bar editor"])

-- The Bars page: a button to the editor.
function Bars:BuildSettings(_, layout)
	ns.SettingsPanel.AddButton(layout, L["Bars"], L["Open the bar editor"], function()
		Editor.Open()
	end, L["Choose what each bar shows, add and remove bars, and switch, copy or share sets of bars."])
end
