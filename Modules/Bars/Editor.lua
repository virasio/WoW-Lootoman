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
-- How far a stack's members sit in from its row.
Editor.INDENT = 18

local window
local barID
-- Bag items taken off a bar while the window is open, whole (an item counting
-- the banks stays one), by their key.
local removed = {}

local function forgetRemoved()
	for key in pairs(removed) do
		removed[key] = nil
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

-- An entry's key: an item counting more than the bags is another entry; a
-- stack is known by its members.
local function keyOf(entry)
	if entry.kind == "stack" then
		local keys = {}
		for index, member in ipairs(entry.members or {}) do
			keys[index] = keyOf(member)
		end
		return "stack:" .. table.concat(keys, ",")
	end
	if entry.count and entry.count ~= "bags" then
		return entry.kind .. ":" .. entry.id .. ":" .. entry.count
	end
	return entry.kind .. ":" .. entry.id
end

-- What a stack holds.
local MEMBER_KINDS = { currency = true, item = true }

-- A bar's entries as the rows of its list, a stack's members under it: each
-- { entry, index (its place on the bar, or its stack's), stack (a stack's own
-- row), member (its place in its stack), parent (its stack) }.
local function flatten(entries)
	local rows = {}
	for index, entry in ipairs(entries) do
		if entry.kind == "stack" then
			rows[#rows + 1] = { entry = entry, index = index, stack = true }
			for position, member in ipairs(entry.members or {}) do
				rows[#rows + 1] = { entry = member, index = index, member = position, parent = entry }
			end
		else
			rows[#rows + 1] = { entry = entry, index = index }
		end
	end
	return rows
end

-- Whether an entry with this key is on the bar, alone or in a stack.
local function onBar(entries, key)
	for _, row in ipairs(flatten(entries)) do
		if not row.stack and keyOf(row.entry) == key then
			return true
		end
	end
	return false
end

local function indexOf(list, value)
	for index, item in ipairs(list) do
		if item == value then
			return index
		end
	end
end

-- A stack left with one member becomes that member; an empty one goes.
local function normalize(entries)
	for index = #entries, 1, -1 do
		local entry = entries[index]
		if entry.kind == "stack" then
			if #entry.members == 0 then
				table.remove(entries, index)
			elseif #entry.members == 1 then
				entries[index] = entry.members[1]
			end
		end
	end
end

-- The two lists of a bar: { left = { { entry, look } … } in the bar's order,
-- right = the same, by name: money and the currencies not on the bar, and the
-- items taken off while the window is open }. The left list's rows are those
-- of flatten, with their row number and look.
function Editor.Lists(bar)
	local left, on = {}, {}
	for number, row in ipairs(flatten(Bars.Entries(bar))) do
		on[keyOf(row.entry)] = true
		row.row = number
		row.look = Bars.Describe(row.entry) or { name = keyOf(row.entry), text = "" }
		left[#left + 1] = row
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
	for _, entry in pairs(removed) do
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
	if onBar(entries, keyOf(entry)) then
		return false
	end
	entries[#entries + 1] = { kind = entry.kind, id = entry.id, count = entry.count }
	removed[keyOf(entry)] = nil
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
	if window and window:IsShown() and entry then
		for _, taken in ipairs(entry.kind == "stack" and entry.members or { entry }) do
			if taken.kind == "item" then
				removed[keyOf(taken)] = { kind = "item", id = taken.id, count = taken.count }
			end
		end
	end
	changed()
	return entry
end

-- Takes a member out of a stack, and off the bar.
function Editor.RemoveMember(bar, index, member)
	if not bar or BarFrame.Asking() then
		return nil
	end
	local entries = Bars.OwnEntries(bar)
	local stack = entries[index]
	local entry = stack and stack.kind == "stack" and table.remove(stack.members, member)
	if not entry then
		return nil
	end
	normalize(entries)
	if entry.kind == "item" and window and window:IsShown() then
		removed[keyOf(entry)] = { kind = "item", id = entry.id, count = entry.count }
	end
	changed()
	return entry
end

-- A row dropped in the bar's list (from = { row = its number in the list } or
-- { entry = one from the other list }): target { on = a row's number }
-- stacks it with that row (on a stack or its member, as the stack's least
-- important member); target { gap = n } puts it before row n (after the last
-- row for one more), inside a stack when row n is one of its members.
function Editor.Drop(bar, from, target)
	if not bar or BarFrame.Asking() then
		return false
	end
	local entries = Bars.OwnEntries(bar)
	local rows = flatten(entries)
	local source, dragged = nil, nil
	if from.row then
		source = rows[from.row]
		dragged = source and source.entry
	elseif from.entry and not onBar(entries, keyOf(from.entry)) then
		dragged = { kind = from.entry.kind, id = from.entry.id, count = from.entry.count }
	end
	if not dragged then
		return false
	end
	-- Where it goes, known by the entries there before it moves.
	local stack, before, beside, atEnd
	if target.on then
		local row = rows[target.on]
		if not row or row.entry == dragged then
			return false
		end
		stack = row.parent or (row.stack and row.entry)
		beside = not stack and row.entry or nil
		atEnd = true
	else
		local row = rows[target.gap]
		if row and row.entry == dragged then
			return false
		end
		if row and row.member then
			stack, before = row.parent, row.entry
		else
			before = row and entries[row.index]
		end
	end
	if (stack or beside) and not (MEMBER_KINDS[dragged.kind] and MEMBER_KINDS[(beside or dragged).kind]) then
		return false
	end
	if stack and stack ~= (source and source.parent) and #stack.members >= Sets.MAX_MEMBERS then
		return false
	end
	-- Out of its place, then into the new one.
	if source then
		table.remove(source.parent and source.parent.members or entries, indexOf(source.parent and source.parent.members or entries, dragged))
	end
	if beside then
		entries[indexOf(entries, beside)] = { kind = "stack", members = { beside, dragged }, showEmpty = false }
	elseif stack then
		local members = stack.members
		table.insert(members, (not atEnd and before and indexOf(members, before)) or #members + 1, dragged)
	else
		table.insert(entries, before and indexOf(entries, before) or #entries + 1, dragged)
	end
	normalize(entries)
	removed[keyOf(dragged)] = nil
	changed()
	return true
end

-- A stack's members become entries in its place.
function Editor.BreakUp(bar, index)
	if not bar or BarFrame.Asking() then
		return false
	end
	local entries = Bars.OwnEntries(bar)
	local stack = entries[index]
	if not stack or stack.kind ~= "stack" then
		return false
	end
	table.remove(entries, index)
	for position, member in ipairs(stack.members) do
		table.insert(entries, index + position - 1, member)
	end
	changed()
	return true
end

-- Whether a stack whose members are all at zero still shows.
function Editor.SetShowEmpty(bar, index, showEmpty)
	if not bar or BarFrame.Asking() then
		return false
	end
	local stack = Bars.OwnEntries(bar)[index]
	if not stack or stack.kind ~= "stack" then
		return false
	end
	stack.showEmpty = showEmpty == true
	changed()
	return true
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

-- Whether an item stands on a bar counting this (Bars.COUNTS).
local function counted(bar, itemID, count)
	for _, row in ipairs(flatten(Bars.Entries(bar))) do
		local entry = row.entry
		if entry.kind == "item" and entry.id == itemID and (entry.count or "bags") == count then
			return true
		end
	end
	return false
end

-- An entry on a bar, or a member of a stack there.
local function entryAt(entries, index, member)
	local entry = entries[index]
	if member then
		return entry and entry.kind == "stack" and entry.members[member] or nil
	end
	return entry
end

-- What an item entry counts; not what another entry of the same item on the
-- bar counts already.
function Editor.SetCount(bar, index, count, member)
	if not bar or BarFrame.Asking() then
		return false
	end
	local entry = entryAt(Bars.OwnEntries(bar), index, member)
	if not entry or entry.kind ~= "item" or counted(bar, entry.id, count) then
		return false
	end
	entry.count = count ~= "bags" and count or nil
	changed()
	return true
end

-- The first count of an item that the bar does not show yet, or nil.
function Editor.FreeCount(bar, itemID)
	for _, count in ipairs(Bars.COUNTS) do
		if not counted(bar, itemID, count) then
			return count
		end
	end
end

-- The same item again, right after it, counting what the bar does not show
-- yet: bags and banks side by side.
function Editor.ShowAgain(bar, index, member)
	if not bar or BarFrame.Asking() then
		return false
	end
	local entries = Bars.OwnEntries(bar)
	local entry = entryAt(entries, index, member)
	if not entry or entry.kind ~= "item" then
		return false
	end
	local count = Editor.FreeCount(bar, entry.id)
	local list, place = entries, index + 1
	if member then
		list, place = entries[index].members, member + 1
	end
	if not count or (member and #list >= Sets.MAX_MEMBERS) then
		return false
	end
	table.insert(list, place, { kind = "item", id = entry.id, count = count ~= "bags" and count or nil })
	changed()
	return true
end

local COUNT_LABELS = { bags = L["Count the bags"], banks = L["Count the banks"], all = L["Count everything"] }

-- The right-click menu of an item on the bar: what it counts, and the same
-- item again.
local function itemMenu(row)
	local item, bar = row.item, Editor.Bar()
	MenuUtil.CreateContextMenu(row, function(_, root)
		local current = item.entry.count or "bags"
		for _, count in ipairs(Bars.COUNTS) do
			local radio = root:CreateRadio(COUNT_LABELS[count], function()
				return current == count
			end, function()
				Editor.SetCount(bar, item.index, count, item.member)
			end)
			radio:SetEnabled(count == current or not counted(bar, item.entry.id, count))
		end
		root:CreateDivider()
		root:CreateButton(L["Show it again"], function()
			Editor.ShowAgain(bar, item.index, item.member)
		end):SetEnabled(Editor.FreeCount(bar, item.entry.id) ~= nil)
	end)
end

-- The right-click menu of a stack: whether it shows when empty, and breaking
-- it up.
local function stackMenu(row)
	local item, bar = row.item, Editor.Bar()
	MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateCheckbox(L["Show when empty"], function()
			return item.entry.showEmpty == true
		end, function()
			Editor.SetShowEmpty(bar, item.index, not item.entry.showEmpty)
		end)
		root:CreateButton(L["Break up the stack"], function()
			Editor.BreakUp(bar, item.index)
		end)
	end)
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
-- Over the middle third of a row, a drop stacks the dragged row with it; else
-- it goes into the gap nearest to the mouse.
local function dropTarget()
	local left = window.left
	if left.box:IsMouseOver() then
		local _, y = GetCursorPosition()
		local top = left.content:GetTop() or 0
		local count = #(left.items or {})
		local at = (top - y / left.content:GetEffectiveScale()) / Editor.ROW_HEIGHT
		local row = math.floor(at)
		local part = at - row
		if row >= 0 and row < count and part >= 1 / 3 and part < 2 / 3 then
			return "left", { on = row + 1 }
		end
		return "left", { gap = math.min(math.max(math.floor(at + 0.5), 0), count) + 1 }
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
	place = place or {}
	local left = window.left
	local marker = left.Marker
	marker:SetShown(target == "left" and place.gap ~= nil)
	if target == "left" and place.gap then
		local offset = -(place.gap - 1) * Editor.ROW_HEIGHT + 1
		-- Inside a stack, the line is indented as its members are.
		local inside = left.items and left.items[place.gap] and left.items[place.gap].member
		marker:ClearAllPoints()
		marker:SetPoint("TOPLEFT", left.content, "TOPLEFT", inside and Editor.INDENT or 0, offset)
		marker:SetPoint("TOPRIGHT", left.content, "TOPRIGHT", 0, offset)
	end
	for number, row in ipairs(left.rows) do
		row.Target:SetShown(target == "left" and place.on == number)
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
		for _, row in ipairs(window.left.rows) do
			row.Target:Hide()
		end
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
		local taken
		if item.member then
			taken = Editor.RemoveMember(bar, item.index, item.member)
		else
			taken = Editor.Remove(bar, item.index)
		end
		if taken then
			window.right.chosen, window.left.chosen = keyOf(item.entry), nil
		end
	elseif drag.list == window.left then
		Editor.Drop(bar, { row = item.row }, place)
	elseif Editor.Drop(bar, { entry = item.entry }, place) then
		window.left.chosen, window.right.chosen = keyOf(item.entry), nil
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
	-- Lit while a row dropped here would be stacked with it.
	row.Target = row:CreateTexture(nil, "BORDER")
	row.Target:SetAllPoints()
	row.Target:SetColorTexture(1, 0.82, 0, 0.3)
	row.Target:Hide()
	row.Icon = row:CreateTexture(nil, "ARTWORK")
	row.Icon:SetSize(Editor.ROW_HEIGHT - 4, Editor.ROW_HEIGHT - 4)
	row.Icon:SetPoint("LEFT", 2, 0)
	row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
	row.Name:SetPoint("RIGHT", -4, 0)
	row.Name:SetJustifyH("LEFT")
	row.Name:SetWordWrap(false)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			if window and list == window.left and self.item then
				if self.item.stack then
					stackMenu(self)
				elseif self.item.entry.kind == "item" then
					itemMenu(self)
				end
			end
			return
		end
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
		-- A stack's members sit under it, indented.
		row.Icon:ClearAllPoints()
		row.Icon:SetPoint("LEFT", item.member and Editor.INDENT or 2, 0)
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
		local taken = item and (item.member and Editor.RemoveMember(Editor.Bar(), item.index, item.member)
			or not item.member and Editor.Remove(Editor.Bar(), item.index))
		if taken then
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
	hint:SetText(L["Drag rows up and down, onto each other to stack them, or from one list to the other; drop an item from your bags on the left list; right-click a row for more. Width, gap and size: in Edit Mode."])

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
