local _, ns = ...
local Compat, L, Prices = ns.Compat, ns.L, ns.Prices
local JunkRule = ns.Rules.Junk

-- The bag-like window of the junk windows: three sections (Sections.lua), each
-- scrolling on its own so all are in sight while an item is dragged between
-- them, with item buttons in rows of eight like the game's bags:
--   junk       the junk, the items a quest in the log still wants last, under
--              a highlighted subheading (a hint);
--   suggested  what the rules suggest, a subgroup per rule, each with a To
--              Junk button;
--   rest       not junk, a subgroup per kind of item.
-- Under each button its stack's price in short form; the tooltip is the
-- game's own for the bag slot, with the comparison to what is equipped, the
-- auction price, why an item is suggested or hinted, and what its clicks do.
--
-- Moving an item: a suggestion by a left click to the junk, a right click to
-- not junk; a hinted junk item by a left click to not junk; any item by
-- dragging it onto the junk or the not-junk section. The drag is the window's
-- own: the item stays in its bag slot and nothing goes onto the game's
-- cursor; a copy of its icon follows the mouse. Dropping it outside the window
-- is the owner's: the toss window deletes it.
--
-- The window's mode says what a move means: "sell" (the sell window), for
-- this sale only, and for good (a mark) with Shift held; "keep" (the toss
-- window and the junk list), always for good. This sale's decisions are the
-- window's own and go when it closes.
--
--   local grid = ItemGrid.Create({
--       name = "LootomanTossWindow",          -- global name, for UISpecialFrames
--       title = <text>, kind = "toss" | "sell", mode = "keep" | "sell",
--       dropOutside = <tooltip line>, onDropOutside = function(entry) end,  -- optional
--       footer = function(grid, footer) end,  -- adds the owner's buttons
--       top = <pixels>,                       -- room for the owner over the sections
--       strata = "DIALOG",                    -- default "HIGH"; DIALOG opens over the game's options
--   })
--   grid:Attach()      -- in the part's Enable: refresh on changes while shown
--   grid:Open() / grid:Close() / grid:Refresh()
local Junk = ns.Modules:Get("Junk")
local ItemGrid = {}
Junk.ItemGrid = ItemGrid

ItemGrid.COLUMNS = 8
ItemGrid.BUTTON = 37
ItemGrid.GAP = 5
-- A row: the button, its price under it, and a gap.
ItemGrid.ROW_HEIGHT = 54
ItemGrid.HEADER_HEIGHT = 22
ItemGrid.SUBHEADER = 20
-- Rows each section shows before it scrolls.
ItemGrid.ROWS = { junk = 2, suggested = 2, rest = 4 }
ItemGrid.SECTIONS = { "junk", "suggested", "rest" }
ItemGrid.SIDE = 12
ItemGrid.SCROLL_BAR = 16
ItemGrid.TOP = 28
ItemGrid.FOOTER = 40
ItemGrid.WIDTH = ItemGrid.SIDE * 2 + ItemGrid.COLUMNS * ItemGrid.BUTTON + (ItemGrid.COLUMNS - 1) * ItemGrid.GAP + ItemGrid.SCROLL_BAR

local TITLES = { junk = L["Junk"], suggested = L["Suggested as Junk"], rest = L["Not Junk"] }
local EMPTY = {
	junk = L["Drag an item here to mark it as junk."],
	suggested = L["Nothing to suggest."],
	rest = L["Drag an item here to keep it."],
}
ItemGrid.RULE_TITLES = {
	questDone = L["Quest Done"],
	leftovers = L["Leftovers from Quests"],
	unusable = L["Your Class Can't Use It"],
	known = L["Already Known"],
	outgrown = L["Outgrown"],
}

-- Why a suggestion is made, for its tooltip.
function ItemGrid.Reason(suggestion)
	local rule, why = suggestion.rule, suggestion.why
	if rule == "questDone" then
		if why == "started" then
			return L["Its quest is done."]
		elseif why == "notInLog" then
			return L["No quest in your log wants it."]
		end
		return L["The quests it was for are done."]
	elseif rule == "leftovers" then
		return L["Left over from quests you have done, and worth little more at the auction than at a merchant."]
	elseif rule == "unusable" then
		return L["Your class can't use it."]
	elseif rule == "known" then
		return why == "recipe" and L["You already know this recipe."] or L["Already in your collection."]
	end
	return L["Far below your level."]
end

-- The biggest coin of a price, the way the game writes coins ("12" and a gold
-- coin); nothing for no price.
function ItemGrid.ShortPrice(copper)
	local units = {
		{ 10000, "GOLD_AMOUNT_TEXTURE", "%dg" },
		{ 100, "SILVER_AMOUNT_TEXTURE", "%ds" },
		{ 1, "COPPER_AMOUNT_TEXTURE", "%dc" },
	}
	for _, unit in ipairs(units) do
		if copper >= unit[1] then
			local format = Compat.GetGlobalString(unit[2])
			local amount = math.floor(copper / unit[1])
			return format and format:format(amount, 0, 0) or unit[3]:format(amount)
		end
	end
	return ""
end

-- The section an entry is in.
function ItemGrid.SectionOf(entry)
	if entry.decision.junk then
		return "junk"
	elseif entry.suggestion then
		return "suggested"
	end
	return "rest"
end

local function shiftDown()
	return IsShiftKeyDown ~= nil and IsShiftKeyDown() == true
end

local GridMixin = {}
GridMixin.__index = GridMixin

-- Whether a move made now is for good: always in a "keep" window, with Shift
-- in the sell window.
function GridMixin:ForGood()
	return self.options.mode ~= "sell" or shiftDown()
end

-- Sends an entry to "junk" or "rest" (not junk), for good or for this sale.
function GridMixin:MoveTo(entry, target, forGood)
	local id = entry.item.itemID
	local sale = self.thisSale
	if not forGood then
		sale.junk[id] = target == "junk" or nil
		sale.keep[id] = target == "rest" or nil
		self:Refresh()
		return
	end
	sale.junk[id], sale.keep[id] = nil, nil
	if target == "junk" then
		JunkRule.MarkJunk(entry.item)
	else
		JunkRule.MarkNotJunk(entry.item)
	end
	-- A mark that changed refreshes the window; one that was already there not.
	self:Refresh()
end

-- What dropping an entry on a section does: to the junk or to not junk.
-- Nothing on the suggestions, nor where it already is.
function GridMixin:Drop(entry, target)
	if target == "suggested" or target == ItemGrid.SectionOf(entry) then
		return
	end
	self:MoveTo(entry, target, self:ForGood())
end

-- A click on an entry: a suggestion goes to the junk (left) or to not junk
-- (right); a hinted junk item to not junk (left); others wait for a drag.
function GridMixin:Click(entry, mouseButton)
	local section = ItemGrid.SectionOf(entry)
	if section == "suggested" then
		self:MoveTo(entry, mouseButton == "RightButton" and "rest" or "junk", self:ForGood())
	elseif section == "junk" and entry.hint and mouseButton == "LeftButton" then
		self:MoveTo(entry, "rest", self:ForGood())
	end
end

-- To Junk on a suggestion subgroup: every entry of it.
function GridMixin:AllToJunk(entries)
	local forGood = self:ForGood()
	for _, entry in ipairs(entries) do
		self:MoveTo(entry, "junk", forGood)
	end
end

local function sectionHeight(rows)
	return ItemGrid.HEADER_HEIGHT + rows * ItemGrid.ROW_HEIGHT
end

-- The tooltip's lines on what can be done with an entry here.
function GridMixin:Hints(entry)
	local lines = {}
	local section = ItemGrid.SectionOf(entry)
	if section == "suggested" then
		lines[#lines + 1] = L["Left-click: to junk. Right-click: not junk."]
	elseif section == "junk" and entry.hint then
		lines[#lines + 1] = L["Left-click: not junk."]
	end
	lines[#lines + 1] = section == "junk" and L["Drag it to Not Junk to keep it."] or L["Drag it to Junk to mark it as junk."]
	if self.options.mode == "sell" then
		lines[#lines + 1] = L["For this sale only; hold Shift for good."]
	end
	if self.options.dropOutside then
		lines[#lines + 1] = self.options.dropOutside
	end
	return lines
end

function GridMixin:ShowTooltip(button)
	local entry = button.entry
	if not entry then
		return
	end
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:SetBagItem(entry.item.bag, entry.item.slot)
	if TooltipUtil.ShouldDoItemComparison(GameTooltip) then
		GameTooltip_ShowCompareItem(GameTooltip)
	end
	local auction = Prices.Auction(entry.item)
	if auction then
		GameTooltip:AddLine(L["Auction price: %s"]:format(GetMoneyString(auction, true)), 1, 1, 1)
	end
	if entry.kept then
		GameTooltip:AddLine(L["Its bag is left out of junk selling."], 1, 0.82, 0)
	end
	if self.options.checked and self.options.checkedNote and self.options.checked(entry) then
		GameTooltip:AddLine(self.options.checkedNote, 0.4, 1, 0.4, true)
	end
	if entry.suggestion then
		GameTooltip:AddLine(ItemGrid.Reason(entry.suggestion), 1, 0.82, 0, true)
	elseif entry.hint then
		GameTooltip:AddLine(L["A quest in your log still wants it."], 1, 0.5, 0, true)
	end
	for _, line in ipairs(self:Hints(entry)) do
		GameTooltip:AddLine(line, 0, 1, 0, true)
	end
	GameTooltip:Show()
end

function GridMixin:StartDrag(button)
	if not button.entry then
		return
	end
	self.dragged = button.entry
	self.ghost.icon:SetTexture(button.entry.item.icon)
	self.ghost:Show()
	GameTooltip:Hide()
end

-- The section under the mouse when a drag ends, or nil.
function GridMixin:Target()
	for _, key in ipairs(ItemGrid.SECTIONS) do
		if self.sections[key].frame:IsMouseOver() then
			return key
		end
	end
	return nil
end

-- On a section, the drop moves; outside the window, it is the owner's; on the
-- rest of the window (its title, its bottom), nothing.
function GridMixin:StopDrag()
	local entry = self.dragged
	self.dragged = nil
	self.ghost:Hide()
	if not entry then
		return
	end
	local target = self:Target()
	if target then
		self:Drop(entry, target)
	elseif not self.frame:IsMouseOver() and self.options.onDropOutside then
		self.options.onDropOutside(entry)
	end
end

local function createButton(grid, parent)
	local button = CreateFrame("ItemButton", nil, parent)
	button:SetSize(ItemGrid.BUTTON, ItemGrid.BUTTON)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button.price = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	button.price:SetPoint("TOP", button, "BOTTOM", 0, -2)
	button.kept = button:CreateTexture(nil, "OVERLAY")
	button.kept:SetAllPoints()
	button.kept:SetColorTexture(0, 0, 0, 0.5)
	-- A mark for an owner's note on the item (the toss window's "cheaper than
	-- the loot").
	button.check = button:CreateTexture(nil, "OVERLAY", nil, 2)
	button.check:SetSize(14, 14)
	button.check:SetPoint("TOPRIGHT", 2, 2)
	button.check:SetAtlas("common-icon-checkmark")
	button.check:Hide()
	button:SetScript("OnEnter", function(self)
		grid:ShowTooltip(self)
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:SetScript("OnClick", function(self, mouseButton)
		if self.entry then
			grid:Click(self.entry, mouseButton)
		end
	end)
	button:SetScript("OnDragStart", function(self)
		grid:StartDrag(self)
	end)
	button:SetScript("OnDragStop", function()
		grid:StopDrag()
	end)
	return button
end

-- A subgroup's heading in a section: its title, its total and, for a
-- suggestion, To Junk.
local function createSubheader(grid, parent)
	local header = CreateFrame("Frame", nil, parent)
	header:SetHeight(ItemGrid.SUBHEADER)
	header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	header.title:SetPoint("LEFT", 0, 0)
	header.total = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	header.button = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
	header.button:SetSize(80, 18)
	header.button:SetPoint("RIGHT", 0, 0)
	header.button:SetText(L["To Junk"])
	header.button:SetScript("OnClick", function(self)
		if self.entries then
			grid:AllToJunk(self.entries)
		end
	end)
	header.total:SetPoint("RIGHT", header.button, "LEFT", -6, 0)
	return header
end

local function createSection(grid, key, top)
	local section = { key = key, buttons = {}, headers = {} }
	local frame = CreateFrame("Frame", nil, grid.frame)
	frame:SetPoint("TOPLEFT", ItemGrid.SIDE, top)
	frame:SetPoint("TOPRIGHT", -ItemGrid.SIDE, top)
	frame:SetHeight(sectionHeight(ItemGrid.ROWS[key]))
	section.frame = frame
	section.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	section.title:SetPoint("TOPLEFT", 0, -4)
	section.title:SetText(TITLES[key])
	section.total = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	section.total:SetPoint("TOPRIGHT", -ItemGrid.SCROLL_BAR, -4)
	section.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	section.hint:SetPoint("TOPLEFT", 0, -ItemGrid.HEADER_HEIGHT - 8)
	section.hint:SetText(EMPTY[key])
	section.scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	section.scroll:SetPoint("TOPLEFT", 0, -ItemGrid.HEADER_HEIGHT)
	section.scroll:SetPoint("BOTTOMRIGHT", -ItemGrid.SCROLL_BAR, 0)
	if section.scroll.ScrollBar then
		section.scroll.ScrollBar:SetHideIfUnscrollable(true)
	end
	section.content = CreateFrame("Frame", nil, section.scroll)
	section.content:SetSize(ItemGrid.WIDTH - ItemGrid.SIDE * 2 - ItemGrid.SCROLL_BAR, ItemGrid.ROW_HEIGHT)
	section.scroll:SetScrollChild(section.content)
	section.createButton = function()
		return createButton(grid, section.content)
	end
	section.createHeader = function()
		return createSubheader(grid, section.content)
	end
	return section
end

-- The subgroups a section shows: { title, total, entries, toJunk, highlight }.
local function subgroups(key, built)
	local list = {}
	if key == "junk" then
		local entries, plain, hinted = built.junk.entries, {}, {}
		for _, entry in ipairs(entries) do
			table.insert(entry.hint and hinted or plain, entry)
		end
		list[1] = { entries = plain }
		if #hinted > 0 then
			list[2] = { title = L["A quest in your log still wants these"], entries = hinted, highlight = true }
		end
	elseif key == "suggested" then
		for _, group in ipairs(built.suggested.groups) do
			list[#list + 1] = { title = ItemGrid.RULE_TITLES[group.key] or group.key, total = group.total, entries = group.entries,
				toJunk = true }
		end
	else
		for _, group in ipairs(built.rest.groups) do
			list[#list + 1] = { title = group.name, total = group.total, entries = group.entries }
		end
	end
	return list
end

-- Shows a section's subgroups, with headers and buttons made the first time
-- they are needed. section.buttons holds the shown ones first, in order.
local function fill(grid, section, built)
	local y, used, headersUsed, count = 0, 0, 0, 0
	for _, group in ipairs(subgroups(section.key, built)) do
		if group.title then
			headersUsed = headersUsed + 1
			local header = section.headers[headersUsed]
			if not header then
				header = section.createHeader()
				section.headers[headersUsed] = header
			end
			header:ClearAllPoints()
			header:SetPoint("TOPLEFT", 0, y)
			header:SetPoint("TOPRIGHT", 0, y)
			header.title:SetText(group.title)
			header.title:SetTextColor(group.highlight and 1 or 1, group.highlight and 0.5 or 0.82, 0)
			header.total:SetText(group.total and group.total > 0 and GetMoneyString(group.total, true) or "")
			header.button:SetShown(group.toJunk == true)
			header.button.entries = group.entries
			header:Show()
			y = y - ItemGrid.SUBHEADER
		end
		for index, entry in ipairs(group.entries) do
			used = used + 1
			local button = section.buttons[used]
			if not button then
				button = section.createButton()
				section.buttons[used] = button
			end
			local column, row = (index - 1) % ItemGrid.COLUMNS, math.floor((index - 1) / ItemGrid.COLUMNS)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", column * (ItemGrid.BUTTON + ItemGrid.GAP), y - row * ItemGrid.ROW_HEIGHT)
			button.entry = entry
			button:SetItemButtonTexture(entry.item.icon)
			button:SetItemButtonQuality(entry.item.quality, entry.item.link, false, entry.item.bound)
			button:SetItemButtonCount(entry.item.count)
			button.price:SetText(ItemGrid.ShortPrice(entry.price))
			button.kept:SetShown(entry.kept == true and section.showKept == true)
			button.check:SetShown(grid.options.checked ~= nil and grid.options.checked(entry) == true)
			button:Show()
		end
		y = y - math.max(#group.entries > 0 and 1 or 0, math.ceil(#group.entries / ItemGrid.COLUMNS)) * ItemGrid.ROW_HEIGHT
		count = count + #group.entries
	end
	for index = used + 1, #section.buttons do
		section.buttons[index].entry = nil
		section.buttons[index]:Hide()
	end
	for index = headersUsed + 1, #section.headers do
		section.headers[index]:Hide()
	end
	section.content:SetHeight(math.max(ItemGrid.ROW_HEIGHT, -y))
	local total = built[section.key].total
	section.total:SetText(total > 0 and GetMoneyString(total, true) or "")
	section.hint:SetShown(count == 0)
	section.shown = count
end

function GridMixin:Refresh()
	local built = Junk.Sections.Build(self.options.kind, self.options.mode == "sell" and self.thisSale or nil)
	self.built = built
	for _, key in ipairs(ItemGrid.SECTIONS) do
		fill(self, self.sections[key], built)
	end
	if self.options.onRefresh then
		self.options.onRefresh(self, built)
	end
end

function GridMixin:Open()
	self:Refresh()
	self.frame:Show()
end

function GridMixin:Close()
	self.frame:Hide()
end

function GridMixin:IsShown()
	return self.frame:IsShown()
end

-- While the module is on: the window follows the bags, the marks, the prices,
-- the quests and the profile while it is shown.
function GridMixin:Attach()
	local function refresh()
		if self.frame:IsShown() then
			self:Refresh()
		end
	end
	Junk.Listen("InventoryChanged", refresh)
	Junk.Listen("MarksChanged", refresh)
	Junk.Listen("PricesChanged", refresh)
	Junk.Listen("ProfileChanged", refresh)
	Junk.Listen("SettingChanged", refresh)
	Junk.ListenEvent("QUEST_TURNED_IN", refresh)
end

function ItemGrid.Create(options)
	options.mode = options.mode or (options.kind == "sell" and "sell" or "keep")
	local grid = setmetatable({ options = options, sections = {}, thisSale = { junk = {}, keep = {} } }, GridMixin)
	local frame = CreateFrame("Frame", options.name, UIParent, "DefaultPanelFlatTemplate")
	grid.frame = frame
	frame:Hide()
	frame:SetWidth(ItemGrid.WIDTH)
	local top = ItemGrid.TOP + (options.top or 0)
	local height = top
	for _, key in ipairs(ItemGrid.SECTIONS) do
		height = height + sectionHeight(ItemGrid.ROWS[key]) + 8
	end
	frame:SetHeight(height + ItemGrid.FOOTER)
	frame:SetFrameStrata(options.strata or "HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle(options.title)
	frame:SetScript("OnHide", function()
		grid.dragged = nil
		grid.ghost:Hide()
		-- This sale's decisions go with the window.
		grid.thisSale = { junk = {}, keep = {} }
		if options.onHide then
			options.onHide(grid)
		end
	end)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	-- Escape closes it as it closes the game's own windows (see the look window:
	-- RegisterGameMenuEscHandler would taint the game menu).
	if options.name then
		table.insert(UISpecialFrames, options.name)
	end
	-- The junk list (Settings/JunkList.lua), to see every mark.
	if not options.noListButton then
		grid.listButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		grid.listButton:SetSize(90, 20)
		grid.listButton:SetPoint("TOPRIGHT", -24, -1)
		grid.listButton:SetText(L["Junk List"])
		grid.listButton:SetScript("OnClick", function()
			if ns.JunkList then
				ns.JunkList.Open()
			end
		end)
	end

	local y = -top
	for _, key in ipairs(ItemGrid.SECTIONS) do
		grid.sections[key] = createSection(grid, key, y)
		y = y - sectionHeight(ItemGrid.ROWS[key]) - 8
	end
	grid.sections.junk.showKept = options.kind == "sell"

	-- The dragged item's icon at the mouse.
	local ghost = CreateFrame("Frame", nil, UIParent)
	ghost:SetSize(ItemGrid.BUTTON, ItemGrid.BUTTON)
	ghost:SetFrameStrata("TOOLTIP")
	ghost:Hide()
	ghost.icon = ghost:CreateTexture(nil, "OVERLAY")
	ghost.icon:SetAllPoints()
	ghost.icon:SetAlpha(0.8)
	ghost:SetScript("OnUpdate", function(self)
		local x, cursorY = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, cursorY / scale)
	end)
	grid.ghost = ghost

	grid.footer = CreateFrame("Frame", nil, frame)
	grid.footer:SetPoint("BOTTOMLEFT", ItemGrid.SIDE, 8)
	grid.footer:SetPoint("BOTTOMRIGHT", -ItemGrid.SIDE, 8)
	grid.footer:SetHeight(ItemGrid.FOOTER - 12)
	if options.footer then
		options.footer(grid, grid.footer)
	end
	return grid
end
