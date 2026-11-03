local _, ns = ...
local Bus, Compat, L, Marks, Text = ns.Bus, ns.Compat, ns.L, ns.Marks, ns.Text

-- The junk list: a page of its own under the Junk module's page, with every
-- item the profile marks. Two lists, Marked as junk and Not junk (gray items
-- kept out of the junk), each item with its icon, its name and a Remove
-- button; Clear list removes them all after a question. The page follows the
-- marks and the profile while it is shown.
local JunkList = {}
ns.JunkList = JunkList

JunkList.ROW_HEIGHT = 26
JunkList.TOP = -60

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

local function build(category, layout)
	local frame = CreateFrame("Frame")
	frame:Hide()
	page = { frame = frame, rows = {} }
	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 7, -22)
	title:SetText(L["Junk list"])
	page.clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	page.clear:SetSize(120, 22)
	page.clear:SetPoint("TOPRIGHT", -20, -20)
	page.clear:SetText(L["Clear list"])
	page.clear:SetScript("OnClick", function()
		ns.NameMenu.Confirm(L["Remove every mark of this profile from the junk list?"], nil, L["Clear list"], Marks.Clear)
	end)
	local scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 20, JunkList.TOP)
	scroll:SetPoint("BOTTOMRIGHT", -30, 10)
	page.content = CreateFrame("Frame", nil, scroll)
	page.content:SetSize(560, JunkList.ROW_HEIGHT)
	scroll:SetScrollChild(page.content)
	-- The options panel calls it when it shows the page.
	function frame.OnRefresh()
		JunkList.Refresh()
	end
	page.category = Settings.RegisterCanvasLayoutSubcategory(category, frame, L["Junk list"])
	ns.SettingsPanel.AddButton(layout, L["Junk list"], L["Open the list"], function()
		Settings.OpenToCategory(page.category:GetID())
	end, L["Every item you marked as junk or as not junk, to remove marks."])
	JunkList.Refresh()
end

-- The page, for tests: { frame, rows, lines, clear, category }.
function JunkList.Page()
	return page
end

local Junk = ns.Modules:Get("Junk")
if Junk then
	Junk.AddToPage(build)
	local function refreshShown()
		if page and page.frame:IsShown() then
			JunkList.Refresh()
		end
	end
	Bus:On("MarksChanged", JunkList, refreshShown)
	Bus:On("ProfileChanged", JunkList, refreshShown)
end
