local _, ns = ...
local Compat, L, Prices = ns.Compat, ns.L, ns.Prices
local JunkRule = ns.Rules.Junk

-- The bag-like window of the toss and sell windows: two sections, the junk on
-- top and everything else below (Sections.lua), with item buttons in rows of
-- eight like the game's bags. Under each button its stack's price in short
-- form; the tooltip is the game's own for the bag slot, with the comparison
-- to what is equipped, and the auction price. Each section scrolls on its own,
-- so both are in sight while an item is dragged between them.
--
-- The drag is the window's own: the item stays in its bag slot and nothing goes
-- onto the game's cursor; a copy of its icon follows the mouse, and dropping it
-- on the other section marks it (Rules.Junk.MarkJunk, MarkNotJunk). A right
-- click is the owner's: deleting, or selling.
--
--   local grid = ItemGrid.Create({
--       name = "LootomanTossWindow",          -- global name, for UISpecialFrames
--       title = <text>, kind = "toss" | "sell",
--       rightClick = <tooltip line>, onRightClick = function(entry) end,
--       footer = function(grid, footer) end,  -- adds the owner's buttons
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
-- Rows each section shows before it scrolls.
ItemGrid.ROWS = { junk = 3, rest = 6 }
ItemGrid.SIDE = 12
ItemGrid.SCROLL_BAR = 16
ItemGrid.TOP = 28
ItemGrid.FOOTER = 40
ItemGrid.WIDTH = ItemGrid.SIDE * 2 + ItemGrid.COLUMNS * ItemGrid.BUTTON + (ItemGrid.COLUMNS - 1) * ItemGrid.GAP + ItemGrid.SCROLL_BAR

local TITLES = { junk = L["Junk"], rest = L["Everything else"] }
local HINTS = {
	junk = L["Drag an item here to mark it as junk."],
	rest = L["Drag an item here to remove its mark."],
}

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

-- What dropping an entry on a section does: "junk" or "rest". Nothing when it
-- is dropped where it already is.
function ItemGrid.Drop(entry, target)
	if target == "junk" and not entry.decision.junk then
		JunkRule.MarkJunk(entry.item)
	elseif target == "rest" and entry.decision.junk then
		JunkRule.MarkNotJunk(entry.item)
	end
end

local GridMixin = {}
GridMixin.__index = GridMixin

local function sectionHeight(rows)
	return ItemGrid.HEADER_HEIGHT + rows * ItemGrid.ROW_HEIGHT
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
	GameTooltip:AddLine(self.options.rightClick, 0, 1, 0)
	GameTooltip:AddLine(entry.decision.junk and L["Drag it down to keep it."] or L["Drag it up to mark it as junk."], 0, 1, 0)
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
	for _, key in ipairs({ "junk", "rest" }) do
		if self.sections[key].frame:IsMouseOver() then
			return key
		end
	end
	return nil
end

function GridMixin:StopDrag()
	local entry = self.dragged
	self.dragged = nil
	self.ghost:Hide()
	local target = entry and self:Target()
	if target then
		ItemGrid.Drop(entry, target)
	end
end

local function createButton(grid, parent)
	local button = CreateFrame("ItemButton", nil, parent)
	button:SetSize(ItemGrid.BUTTON, ItemGrid.BUTTON)
	button:RegisterForClicks("RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button.price = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	button.price:SetPoint("TOP", button, "BOTTOM", 0, -2)
	button.kept = button:CreateTexture(nil, "OVERLAY")
	button.kept:SetAllPoints()
	button.kept:SetColorTexture(0, 0, 0, 0.5)
	button:SetScript("OnEnter", function(self)
		grid:ShowTooltip(self)
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" and self.entry then
			grid.options.onRightClick(self.entry)
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

local function createSection(grid, key, top)
	local section = { key = key, buttons = {} }
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
	section.hint:SetText(HINTS[key])
	section.scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	section.scroll:SetPoint("TOPLEFT", 0, -ItemGrid.HEADER_HEIGHT)
	section.scroll:SetPoint("BOTTOMRIGHT", -ItemGrid.SCROLL_BAR, 0)
	if section.scroll.ScrollBar then
		section.scroll.ScrollBar:SetHideIfUnscrollable(true)
	end
	section.content = CreateFrame("Frame", nil, section.scroll)
	section.content:SetSize(ItemGrid.WIDTH - ItemGrid.SIDE * 2 - ItemGrid.SCROLL_BAR, ItemGrid.ROW_HEIGHT)
	section.scroll:SetScrollChild(section.content)
	section.create = function()
		return createButton(grid, section.content)
	end
	return section
end

-- Shows a section's entries, with buttons made the first time they are needed.
local function fill(section, built)
	local entries = built.entries
	for index, entry in ipairs(entries) do
		local button = section.buttons[index]
		if not button then
			button = section.create()
			section.buttons[index] = button
		end
		local column, row = (index - 1) % ItemGrid.COLUMNS, math.floor((index - 1) / ItemGrid.COLUMNS)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", column * (ItemGrid.BUTTON + ItemGrid.GAP), -row * ItemGrid.ROW_HEIGHT)
		button.entry = entry
		button:SetItemButtonTexture(entry.item.icon)
		button:SetItemButtonQuality(entry.item.quality, entry.item.link, false, entry.item.bound)
		button:SetItemButtonCount(entry.item.count)
		button.price:SetText(ItemGrid.ShortPrice(entry.price))
		button.kept:SetShown(entry.kept == true and section.showKept == true)
		button:Show()
	end
	for index = #entries + 1, #section.buttons do
		section.buttons[index].entry = nil
		section.buttons[index]:Hide()
	end
	local rows = math.max(1, math.ceil(#entries / ItemGrid.COLUMNS))
	section.content:SetHeight(rows * ItemGrid.ROW_HEIGHT)
	section.total:SetText(built.total > 0 and GetMoneyString(built.total, true) or "")
	section.hint:SetShown(#entries == 0)
	section.shown = #entries
end

function GridMixin:Refresh()
	local built = Junk.Sections.Build(self.options.kind)
	self.built = built
	for _, key in ipairs({ "junk", "rest" }) do
		fill(self.sections[key], built[key])
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

-- While the module is on: the window follows the bags, the marks, the prices
-- and the profile while it is shown.
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
end

function ItemGrid.Create(options)
	local grid = setmetatable({ options = options, sections = {} }, GridMixin)
	local frame = CreateFrame("Frame", options.name, UIParent, "DefaultPanelFlatTemplate")
	grid.frame = frame
	frame:Hide()
	frame:SetWidth(ItemGrid.WIDTH)
	frame:SetHeight(ItemGrid.TOP + sectionHeight(ItemGrid.ROWS.junk) + 8 + sectionHeight(ItemGrid.ROWS.rest) + ItemGrid.FOOTER)
	frame:SetFrameStrata("HIGH")
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
		if options.onHide then
			options.onHide(grid)
		end
	end)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	-- Escape closes it as it closes the game's own windows (see the designer:
	-- RegisterGameMenuEscHandler would taint the game menu).
	table.insert(UISpecialFrames, options.name)

	grid.sections.junk = createSection(grid, "junk", -ItemGrid.TOP)
	grid.sections.rest = createSection(grid, "rest", -ItemGrid.TOP - sectionHeight(ItemGrid.ROWS.junk) - 8)
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
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
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
