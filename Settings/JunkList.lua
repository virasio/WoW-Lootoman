local _, ns = ...
local Bus, Compat, L, Marks, Text = ns.Bus, ns.Compat, ns.L, ns.Marks, ns.Text

-- The junk list window: the profile's marks, in three tabs.
--   Bags      the bags as the junk windows' item grid (ItemGrid.lua), where
--             every move marks the item for good;
--   Junk      every item marked junk, in the bags or not;
--   Not junk  every item marked not junk.
-- In the two lists each item has its icon, its name and Remove, and its
-- tooltip on hover. An item joins the tab's list when it is dropped on the
-- list from the bags, or through the field over the list: Shift-click an
-- item anywhere while the field is active (the game puts the link there, as
-- it does into the chat), or paste a link or type an item ID, then Add.
-- Clear List removes every mark of the profile after a question. Share and
-- Import make and read profile texts of the junk list alone (Share.lua, the
-- part "marks"); importing merges with the list or replaces it. Merged, an
-- item marked otherwise here than in the text keeps its mark, and a window
-- shows these one by one, with the item's tooltip: Keep mine or Take theirs.
--
-- It opens from the main page (Edit the Junk List) and from the toss and
-- sell windows, only while junk management is on. The first time, right of
-- the game's options window and level with its top (over the options' right
-- edge when the screen has no room for it there), or in the middle of the
-- screen while the options are closed; after that it stays where it is (or
-- where the player moved it); it is built the first time, out
-- of combat. While shown it follows the bags, the marks and the profile; it
-- closes when junk management is turned off. Escape and its close button
-- hide it.
local JunkList = {}
ns.JunkList = JunkList

-- The window's global name, for UISpecialFrames.
JunkList.NAME = "LootomanJunkList"
JunkList.CONFLICTS_NAME = "LootomanJunkConflicts"
JunkList.BAGS, JunkList.JUNK, JunkList.NOT_JUNK = 1, 2, 3
JunkList.ROW_HEIGHT = 26
-- Over the list: the field and its hint.
JunkList.LIST_TOP = 64
-- Its gap to the game's options window.
JunkList.GAP = 4

-- The mark each list tab holds.
local TAB_MARKS = { [JunkList.JUNK] = "junk", [JunkList.NOT_JUNK] = "notJunk" }

local Junk = ns.Modules:Get("Junk")
local window, conflicts
local active, hooked = false, false

-- The items with a mark, sorted by name: { itemID, mark, name, text, icon }.
-- An item the client has not loaded yet shows its ID.
function JunkList.Lines(mark)
	local lines = {}
	for _, entry in ipairs(Marks.List()) do
		if entry.mark == mark then
			local info = Compat.GetItemInfo(entry.itemID)
			lines[#lines + 1] = {
				itemID = entry.itemID,
				mark = entry.mark,
				name = info and info.name or nil,
				text = info and info.link or L["Item %d"]:format(entry.itemID),
				icon = Compat.GetItemLook(entry.itemID),
			}
		end
	end
	table.sort(lines, function(a, b)
		local nameA, nameB = Text.FoldCase(a.name or ""), Text.FoldCase(b.name or "")
		if nameA ~= nameB then
			return nameA < nameB
		end
		return a.itemID < b.itemID
	end)
	return lines
end

-- The item ID in a link ("item:12345…") or a typed number, or nil.
function JunkList.ParseItem(text)
	if type(text) ~= "string" then
		return nil
	end
	local id = tonumber(text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$"))
	if id and id > 0 and id == math.floor(id) then
		return id
	end
	return nil
end

-- Marks an item with the shown list tab's mark.
function JunkList.Add(itemID)
	local mark = window and TAB_MARKS[window.tab]
	if mark and itemID then
		Marks.Set(itemID, mark)
	end
end

local function addFromField()
	local itemID = JunkList.ParseItem(window.field:GetText())
	if not itemID then
		ns.Print(L["That is neither an item link nor an item ID."])
		return
	end
	JunkList.Add(itemID)
	window.field:SetText("")
end

-- An item dropped on the list from the bags: it goes back to its slot.
local function dropped()
	local itemID = Compat.GetCursorItemID()
	if itemID and TAB_MARKS[window.tab] then
		Compat.ClearCursor()
		JunkList.Add(itemID)
	end
end

local function row(index)
	local entry = window.rows[index]
	if entry then
		return entry
	end
	entry = CreateFrame("Frame", nil, window.content)
	entry:SetHeight(JunkList.ROW_HEIGHT)
	entry:SetPoint("TOPLEFT", 0, -(index - 1) * JunkList.ROW_HEIGHT)
	entry:SetPoint("RIGHT", window.content, "RIGHT", 0, 0)
	entry:EnableMouse(true)
	entry.icon = entry:CreateTexture(nil, "ARTWORK")
	entry.icon:SetSize(20, 20)
	entry.icon:SetPoint("LEFT", 4, 0)
	entry.text = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	entry.text:SetPoint("LEFT", 30, 0)
	entry.text:SetPoint("RIGHT", -84, 0)
	entry.text:SetJustifyH("LEFT")
	entry.text:SetWordWrap(false)
	entry.remove = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
	entry.remove:SetSize(76, 20)
	entry.remove:SetPoint("RIGHT", -4, 0)
	entry.remove:SetText(L["Remove"])
	entry.remove:SetScript("OnClick", function()
		if entry.line then
			Marks.Set(entry.line.itemID, nil)
		end
	end)
	entry:SetScript("OnEnter", function(self)
		if self.line then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(self.line.itemID)
			GameTooltip:Show()
		end
	end)
	entry:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	-- A drop on a row is a drop on the list.
	entry:SetScript("OnReceiveDrag", dropped)
	entry:SetScript("OnMouseUp", dropped)
	window.rows[index] = entry
	return entry
end

-- Fills the shown list tab.
function JunkList.Refresh()
	if not window then
		return
	end
	window.clear:SetEnabled(#Marks.List() > 0)
	local mark = TAB_MARKS[window.tab]
	if not mark then
		return
	end
	local lines = JunkList.Lines(mark)
	for index, line in ipairs(lines) do
		local entry = row(index)
		entry.line = line
		entry.text:SetText(line.text)
		entry.icon:SetTexture(line.icon)
		entry:Show()
	end
	for index = #lines + 1, #window.rows do
		window.rows[index].line = nil
		window.rows[index]:Hide()
	end
	window.empty:SetShown(#lines == 0)
	window.content:SetHeight(math.max(1, #lines) * JunkList.ROW_HEIGHT)
	window.lines = lines
end

-- Shows a tab: the item grid, or a list.
function JunkList.ShowTab(id)
	if not window then
		return
	end
	window.tab = id
	PanelTemplates_SetTab(window.frame, id)
	local bags = id == JunkList.BAGS
	for _, section in pairs(window.grid.sections) do
		section.frame:SetShown(bags)
	end
	window.list:SetShown(not bags)
	window.clear:SetShown(not bags)
	if bags then
		window.grid:Refresh()
	else
		window.field:SetText("")
		JunkList.Refresh()
	end
end

-- Shift-click on an item while the field is active: the game hands its link
-- to whatever text field has the focus, and to ours through this hook.
local function hookLinks()
	if hooked or not (ChatFrameUtil and ChatFrameUtil.InsertLink) then
		return
	end
	hooked = true
	hooksecurefunc(ChatFrameUtil, "InsertLink", function(text)
		if window and window.list:IsVisible() and window.field:HasFocus() and type(text) == "string"
			and text:find("item:", 1, true) then
			window.field:SetText(text)
		end
	end)
end

local function buildList(frame)
	local ItemGrid = Junk.ItemGrid
	local list = CreateFrame("Frame", nil, frame)
	list:SetPoint("TOPLEFT", ItemGrid.SIDE, -ItemGrid.TOP)
	list:SetPoint("BOTTOMRIGHT", -ItemGrid.SIDE, ItemGrid.FOOTER)
	list:EnableMouse(true)
	list:SetScript("OnReceiveDrag", dropped)
	list:SetScript("OnMouseUp", dropped)
	list:Hide()
	window.list = list
	window.field = CreateFrame("EditBox", nil, list, "InputBoxTemplate")
	window.field:SetSize(220, 22)
	window.field:SetPoint("TOPLEFT", 6, -4)
	window.field:SetAutoFocus(false)
	window.field:SetScript("OnEnterPressed", addFromField)
	window.field:SetScript("OnEscapePressed", function(field)
		field:ClearFocus()
	end)
	window.add = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
	window.add:SetSize(90, 22)
	window.add:SetPoint("LEFT", window.field, "RIGHT", 8, 0)
	window.add:SetText(L["Add"])
	window.add:SetScript("OnClick", addFromField)
	window.hint = list:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	window.hint:SetPoint("TOPLEFT", 0, -30)
	window.hint:SetPoint("TOPRIGHT", 0, -30)
	window.hint:SetJustifyH("LEFT")
	window.hint:SetText(L["Drop an item here from your bags, Shift-click one while the field is active, or paste a link or an item ID."])
	local scroll = CreateFrame("ScrollFrame", nil, list, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -JunkList.LIST_TOP)
	scroll:SetPoint("BOTTOMRIGHT", -ItemGrid.SCROLL_BAR, 0)
	window.content = CreateFrame("Frame", nil, scroll)
	window.content:SetSize(ItemGrid.WIDTH - ItemGrid.SIDE * 2 - ItemGrid.SCROLL_BAR, JunkList.ROW_HEIGHT)
	scroll:SetScrollChild(window.content)
	window.empty = window.content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	window.empty:SetPoint("TOPLEFT", 4, -6)
	window.empty:SetText(L["None"])
end

-- Its first place, as it is built: right of the game's options window, level
-- with its top, moved left over it as far as the screen needs; or in the
-- middle of the screen while the options are closed. (The grid leaves its
-- place to its owner; a frame with none is not drawn.)
local function place()
	local frame = window.frame
	frame:ClearAllPoints()
	local panel = SettingsPanel
	local right, top = panel and panel:IsVisible() and panel:GetRight(), panel and panel:GetTop()
	local screen = UIParent:GetRight()
	if not (right and top and screen) then
		frame:SetPoint("CENTER")
		return
	end
	-- The options window may have a scale of its own: in UIParent's units.
	local scale = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local x = math.min(right * scale + JunkList.GAP, screen - frame:GetWidth())
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top * scale)
end

local function build()
	local grid = Junk.ItemGrid.Create({
		name = JunkList.NAME,
		title = L["Junk List"],
		kind = "toss",
		mode = "keep",
		noListButton = true,
		-- Over the game's options window (HIGH), where its button is.
		strata = "DIALOG",
	})
	local frame = grid.frame
	window = { grid = grid, frame = frame, rows = {}, tab = JunkList.BAGS }
	buildList(frame)

	-- Clear List, under the lists.
	window.clear = CreateFrame("Button", nil, grid.footer, "UIPanelButtonTemplate")
	window.clear:SetSize(120, 22)
	window.clear:SetPoint("LEFT", 0, 0)
	window.clear:SetText(L["Clear List"])
	window.clear:Hide()
	-- The question names the profile, and clears nothing if the profile changed
	-- while it was open.
	window.clear:SetScript("OnClick", function()
		local profile = ns.Profiles.GetCurrent()
		ns.NameMenu.Confirm(L["Remove every mark of profile “%s” from the junk list?"], profile, L["Clear List"], function()
			if ns.Profiles.GetCurrent() == profile then
				Marks.Clear()
			end
		end)
	end)

	-- Profile texts of the junk list alone.
	window.import = CreateFrame("Button", nil, grid.footer, "UIPanelButtonTemplate")
	window.import:SetSize(90, 22)
	window.import:SetPoint("RIGHT", 0, 0)
	window.import:SetText(L["Import"])
	window.import:SetScript("OnClick", function()
		ns.SettingsPanel.Share.OpenImport("part:marks")
	end)
	window.share = CreateFrame("Button", nil, grid.footer, "UIPanelButtonTemplate")
	window.share:SetSize(90, 22)
	window.share:SetPoint("RIGHT", window.import, "LEFT", -4, 0)
	window.share:SetText(L["Share"])
	window.share:SetScript("OnClick", function()
		ns.SettingsPanel.Share.OpenShare("part:marks")
	end)

	-- The tabs, under the window as on the game's own.
	local tabs = {}
	for id, text in ipairs({ L["Bags"], L["Junk"], L["Not Junk"] }) do
		local tab = CreateFrame("Button", nil, frame, "PanelTabButtonTemplate")
		tab:SetID(id)
		tab:SetText(text)
		tab:SetScript("OnClick", function()
			JunkList.ShowTab(id)
		end)
		tabs[id] = tab
	end
	frame.Tabs = tabs
	tabs[1]:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2)
	PanelTemplates_SetNumTabs(frame, #tabs)
	place()
	JunkList.ShowTab(JunkList.BAGS)
	hookLinks()
	if active then
		grid:Attach()
	end
end

-- Opens the window, on a tab (Bags by default); it is built the first time,
-- which waits for the end of combat.
function JunkList.Open(tab)
	if not active then
		ns.Print(L["Junk management is off. Turn it on in the options."])
		return false
	end
	if not window then
		if Compat.InCombat() then
			ns.Print(L["The junk list opens out of combat."])
			return false
		end
		build()
	end
	window.grid:Open()
	JunkList.ShowTab(tab or window.tab)
	return true
end

-- The window, for tests: { grid, frame, list, field, add, rows, lines, tab,
-- clear, share, import }.
function JunkList.Window()
	return window
end

local MARK_NAMES = { junk = L["Junk"], notJunk = L["Not Junk"] }

local function showTooltip(owner, itemID)
	GameTooltip:SetOwner(owner, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPLEFT", conflicts, "TOPRIGHT", 4, 0)
	GameTooltip:SetItemByID(itemID)
	GameTooltip:Show()
end

-- Shows the conflict at conflicts.index, or closes the window after the last.
local function showConflict()
	local conflict = conflicts.list[conflicts.index]
	if not conflict then
		conflicts:Hide()
		return
	end
	local info = Compat.GetItemInfo(conflict.itemID)
	conflicts.count:SetText(L["%d of %d"]:format(conflicts.index, #conflicts.list))
	conflicts.icon:SetTexture(Compat.GetItemLook(conflict.itemID))
	conflicts.name:SetText(info and info.link or L["Item %d"]:format(conflict.itemID))
	conflicts.here:SetText(L["Here: %s"]:format(MARK_NAMES[conflict.mine]))
	conflicts.there:SetText(L["In the text: %s"]:format(MARK_NAMES[conflict.theirs]))
	showTooltip(conflicts, conflict.itemID)
end

local function settle(takeTheirs)
	local conflict = conflicts.list[conflicts.index]
	-- The marks are the profile's: after a switch, nothing is changed.
	if ns.Profiles.GetCurrent() ~= conflicts.profile then
		conflicts:Hide()
		return
	end
	if conflict and takeTheirs then
		Marks.Set(conflict.itemID, conflict.theirs)
	end
	conflicts.index = conflicts.index + 1
	showConflict()
end

local function buildConflicts()
	local frame = CreateFrame("Frame", JunkList.CONFLICTS_NAME, UIParent, "DefaultPanelFlatTemplate")
	frame:Hide()
	frame:SetSize(360, 170)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetTitle(L["Marked Otherwise"])
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	-- Escape closes it as it closes the game's own windows: the items left keep
	-- their marks.
	table.insert(UISpecialFrames, JunkList.CONFLICTS_NAME)
	frame.count = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.count:SetPoint("TOPRIGHT", -24, -34)
	frame.item = CreateFrame("Frame", nil, frame)
	frame.item:SetSize(300, 32)
	frame.item:SetPoint("TOPLEFT", 20, -50)
	frame.item:EnableMouse(true)
	frame.item:SetScript("OnEnter", function()
		local conflict = frame.list and frame.list[frame.index]
		if conflict then
			showTooltip(frame, conflict.itemID)
		end
	end)
	frame.icon = frame.item:CreateTexture(nil, "ARTWORK")
	frame.icon:SetSize(30, 30)
	frame.icon:SetPoint("LEFT")
	frame.name = frame.item:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.name:SetPoint("LEFT", frame.icon, "RIGHT", 8, 0)
	frame.name:SetPoint("RIGHT")
	frame.name:SetJustifyH("LEFT")
	frame.here = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.here:SetPoint("TOPLEFT", 20, -92)
	frame.there = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.there:SetPoint("TOPLEFT", frame.here, "BOTTOMLEFT", 0, -6)
	frame.keep = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.keep:SetSize(130, 22)
	frame.keep:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 14)
	frame.keep:SetText(L["Keep mine"])
	frame.keep:SetScript("OnClick", function()
		settle(false)
	end)
	frame.take = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.take:SetSize(130, 22)
	frame.take:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 14)
	frame.take:SetText(L["Take theirs"])
	frame.take:SetScript("OnClick", function()
		settle(true)
	end)
	frame:SetScript("OnHide", function()
		if GameTooltip:IsOwned(frame --[[@as Frame]]) then
			GameTooltip:Hide()
		end
	end)
	return frame
end

-- The items an imported junk list marks otherwise than the profile does, one
-- by one: { { itemID, mine, theirs }, … }.
function JunkList.ShowConflicts(list)
	conflicts = conflicts or buildConflicts()
	conflicts.list, conflicts.index = list, 1
	conflicts.profile = ns.Profiles.GetCurrent()
	conflicts:Show()
	showConflict()
end

-- The conflicts window, for tests.
function JunkList.Conflicts()
	return conflicts
end

-- Without the junk module (a build that leaves it out) the window never opens.
if Junk then
	Junk.AddPart({
		Enable = function()
			active = true
			if window then
				window.grid:Attach()
			end
		end,
		Disable = function()
			active = false
			if window then
				window.grid:Close()
			end
		end,
	})
end

local function refreshShown()
	if window and window.list:IsVisible() then
		JunkList.Refresh()
	end
end
Bus:On("MarksChanged", JunkList, refreshShown)
Bus:On("ProfileChanged", JunkList, refreshShown)
