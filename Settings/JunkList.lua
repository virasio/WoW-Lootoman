local _, ns = ...
local Bus, Compat, L, Marks, Text = ns.Bus, ns.Compat, ns.L, ns.Marks, ns.Text

-- The junk list: a window of its own with every item the profile marks,
-- opened from the main page (Set up the junk list) and from the sort windows.
-- Two lists, Marked as junk and Not junk (gray items kept out of the junk),
-- each item with its icon, its name and a Remove button; Clear list removes
-- them all after a question. The window follows the marks and the profile
-- while it is shown; Escape and its close button hide it.
local JunkList = {}
ns.JunkList = JunkList

JunkList.ROW_HEIGHT = 26
JunkList.TOP = -60
JunkList.WIDTH = 560
JunkList.HEIGHT = 480
-- The window's global name, for UISpecialFrames.
JunkList.NAME = "LootomanJunkList"

local GROUPS = {
	{ mark = "junk", title = L["Marked as junk"] },
	{ mark = "notJunk", title = L["Not junk"] },
}

-- The page's lines, top to bottom: { kind = "header", text }, { kind =
-- "empty", text } for a list without items, and { kind = "item", itemID,
-- mark, text, icon } sorted by name. An item the client has not loaded yet
-- shows its ID.
function JunkList.Lines()
	local byMark = { junk = {}, notJunk = {} }
	for _, mark in ipairs(Marks.List()) do
		local info = Compat.GetItemInfo(mark.itemID)
		local icon = Compat.GetItemLook(mark.itemID)
		local line = {
			kind = "item",
			itemID = mark.itemID,
			mark = mark.mark,
			name = info and info.name or nil,
			text = info and info.link or L["Item %d"]:format(mark.itemID),
			icon = icon,
		}
		table.insert(byMark[mark.mark], line)
	end
	local lines = {}
	for _, group in ipairs(GROUPS) do
		lines[#lines + 1] = { kind = "header", text = group.title }
		local items = byMark[group.mark]
		table.sort(items, function(a, b)
			local nameA, nameB = Text.FoldCase(a.name or ""), Text.FoldCase(b.name or "")
			if nameA ~= nameB then
				return nameA < nameB
			end
			return a.itemID < b.itemID
		end)
		if #items == 0 then
			lines[#lines + 1] = { kind = "empty", text = L["None"] }
		end
		for _, line in ipairs(items) do
			lines[#lines + 1] = line
		end
	end
	return lines
end

local page

local function row(index)
	local entry = page.rows[index]
	if entry then
		return entry
	end
	entry = CreateFrame("Frame", nil, page.content)
	entry:SetHeight(JunkList.ROW_HEIGHT)
	entry:SetPoint("TOPLEFT", 0, -(index - 1) * JunkList.ROW_HEIGHT)
	entry:SetPoint("RIGHT", page.content, "RIGHT", 0, 0)
	entry.icon = entry:CreateTexture(nil, "ARTWORK")
	entry.icon:SetSize(20, 20)
	entry.icon:SetPoint("LEFT", 16, 0)
	entry.text = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	entry.text:SetPoint("LEFT", 42, 0)
	entry.text:SetJustifyH("LEFT")
	entry.header = entry:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	entry.header:SetPoint("LEFT", 0, 0)
	entry.remove = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
	entry.remove:SetSize(90, 20)
	entry.remove:SetPoint("RIGHT", -8, 0)
	entry.remove:SetText(L["Remove"])
	entry.remove:SetScript("OnClick", function()
		if entry.line and entry.line.kind == "item" then
			Marks.Set(entry.line.itemID, nil)
		end
	end)
	page.rows[index] = entry
	return entry
end

function JunkList.Refresh()
	if not page then
		return
	end
	local lines = JunkList.Lines()
	for index, line in ipairs(lines) do
		local entry = row(index)
		entry.line = line
		local isItem = line.kind == "item"
		entry.header:SetShown(line.kind == "header")
		entry.header:SetText(line.kind == "header" and line.text or "")
		entry.text:SetShown(line.kind ~= "header")
		entry.text:SetText(line.kind ~= "header" and line.text or "")
		entry.text:SetFontObject(line.kind == "empty" and "GameFontDisable" or "GameFontHighlight")
		entry.icon:SetShown(isItem)
		entry.icon:SetTexture(isItem and line.icon or nil)
		entry.remove:SetShown(isItem)
		entry:Show()
	end
	for index = #lines + 1, #page.rows do
		page.rows[index].line = nil
		page.rows[index]:Hide()
	end
	page.content:SetHeight(#lines * JunkList.ROW_HEIGHT)
	page.clear:SetEnabled(#Marks.List() > 0)
	page.lines = lines
end

local function build()
	local frame = CreateFrame("Frame", JunkList.NAME, UIParent, "DefaultPanelFlatTemplate")
	frame:Hide()
	frame:SetSize(JunkList.WIDTH, JunkList.HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle(L["Junk list"])
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	-- Escape closes it as it closes the game's own windows (see the look window:
	-- RegisterGameMenuEscHandler would taint the game menu).
	table.insert(UISpecialFrames, JunkList.NAME)
	page = { frame = frame, rows = {} }
	page.clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	page.clear:SetSize(120, 22)
	page.clear:SetPoint("TOPRIGHT", -20, -30)
	page.clear:SetText(L["Clear list"])
	-- The question names the profile, and clears nothing if the profile changed
	-- while it was open.
	page.clear:SetScript("OnClick", function()
		local profile = ns.Profiles.GetCurrent()
		ns.NameMenu.Confirm(L["Remove every mark of profile “%s” from the junk list?"], profile, L["Clear list"], function()
			if ns.Profiles.GetCurrent() == profile then
				Marks.Clear()
			end
		end)
	end)
	local scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 20, JunkList.TOP)
	scroll:SetPoint("BOTTOMRIGHT", -30, 14)
	page.content = CreateFrame("Frame", nil, scroll)
	page.content:SetSize(JunkList.WIDTH - 60, JunkList.ROW_HEIGHT)
	scroll:SetScrollChild(page.content)
	frame:SetScript("OnShow", JunkList.Refresh)
end

-- Opens the window; it is built the first time, which waits for the end of combat.
function JunkList.Open()
	if not page then
		if Compat.InCombat() then
			ns.Print(L["The junk list opens out of combat."])
			return false
		end
		build()
	end
	page.frame:Show()
	JunkList.Refresh()
	return true
end

-- The window, for tests: { frame, rows, lines, clear }.
function JunkList.Page()
	return page
end

local function refreshShown()
	if page and page.frame:IsShown() then
		JunkList.Refresh()
	end
end
Bus:On("MarksChanged", JunkList, refreshShown)
Bus:On("ProfileChanged", JunkList, refreshShown)
