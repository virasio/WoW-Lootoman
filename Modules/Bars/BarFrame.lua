local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- One currency bar on screen: its entries from one edge (the left, or the
-- right for a bar that fills from the right), an icon and a count each, a gap
-- apart; what does not fit hides behind a double arrow at the other edge,
-- pointing that way, whose click lists the rest. Money shows in coins, as in
-- the bags. A bar can have a dark background of its own opacity and the bags'
-- coin-box border.
--
-- Outside Edit Mode an entry is dragged along the bar to a new place: a copy of
-- it follows the mouse and a line marks where it will go (nothing goes onto the
-- game's cursor); dropped off the bar, it is taken off the bar after a
-- question. An item dragged from the bags onto the bar is added where it is
-- dropped. While the question is on screen, no bar changes in any way (see
-- BarFrame.Asking). In Edit Mode the bar is placed and its width, gap, size, direction,
-- background and border are set in its dialog, or the width with the grip on
-- its far edge; the dialog also adds a bar, removes this one and opens the
-- editor. Positions and settings live in the bar itself, in its set (Sets.lua).
--
-- A frame belongs to a place in the set (the first bar, the second, …), not
-- to one bar, so it is kept when bars come and go; without a bar it is hidden,
-- which also leaves it out of Edit Mode.
local Bars = ns.Modules:Get("Bars")
local Sets = Bars.Sets
local BarFrame = {}
Bars.BarFrame = BarFrame

-- Between an entry's icon and its count.
BarFrame.SPACE = 3
BarFrame.GRIP = 8
BarFrame.MARKER = 2
BarFrame.RED = { 1, 0.13, 0.13 }
BarFrame.WHITE = { 1, 1, 1 }
-- The bags' coin box (ContainerFrameCurrencyBorderTemplate): its ends are 8 by
-- 17 pixels, its middle stretches.
BarFrame.BORDER_ATLAS = { left = "common-coinbox-left", middle = "_common-coinbox-center", right = "common-coinbox-right" }
BarFrame.BORDER_WIDTH, BarFrame.BORDER_HEIGHT = 8, 17
-- Money's coins are icons inside its text (|T…:0:0:2:0|t): as high as the
-- text, 2 pixels after their number.
BarFrame.COIN_OFFSET = 2

local SlotMixin = {}
SlotMixin.__index = SlotMixin

-- The question about taking an entry off, while it may be on screen: a
-- function that tells whether it still is (NameMenu.Confirm).
local question

-- Whether a bar is waiting for the answer to that question. Until it is
-- answered, no bar changes in any way (on screen, in Edit Mode or in the bar
-- editor), so the answer takes off the entry asked about and nothing else.
function BarFrame.Asking()
	if question and question() then
		return true
	end
	question = nil
	return false
end

local function fontSize(bar)
	return math.max(8, math.floor(bar.size * 0.6 + 0.5))
end

-- How wide a text is at a font size. The client measures icons inside a text
-- short (in game, money came out about one coin too narrow), so they are
-- counted here: each as wide as the text is high, after its offset.
local function textWidth(measure, text, size)
	local plain, icons = text:gsub("|T.-|t", "")
	measure:SetText(plain)
	return measure:GetUnboundedStringWidth() + icons * (size + BarFrame.COIN_OFFSET)
end

local function setChanged()
	Sets.Changed(Sets.Current())
end

-- Whether the bar fills from the right edge.
local function fromRight(bar)
	return bar.direction == "left"
end

function SlotMixin:ShowTooltip(button)
	local entry = button.entry
	GameTooltip:SetOwner(button, "ANCHOR_TOP")
	if entry.kind == "currency" then
		GameTooltip:SetCurrencyByID(entry.id)
	elseif entry.kind == "item" then
		GameTooltip:SetItemByID(entry.id)
	else
		GameTooltip_SetTitle(GameTooltip, L["Money"])
		GameTooltip:AddLine(GetMoneyString(Compat.GetMoney(), true), 1, 1, 1)
	end
	if not ns.EditMode.IsActive() then
		GameTooltip:AddLine(L["Drag it along the bar to move it, or off the bar to take it off."], 0, 1, 0)
	end
	GameTooltip:Show()
end

-- An item held on the game's cursor and let go over the bar: added there.
function SlotMixin:ReceiveItem()
	local itemID = Compat.GetCursorItemID()
	if not itemID or not self.bar or BarFrame.Asking() then
		return
	end
	Compat.ClearCursor()
	local editor = Bars.Editor
	if editor and editor.Add(self.bar, { kind = "item", id = itemID }) then
		local entries = Bars.OwnEntries(self.bar)
		BarFrame.Move(self.bar, #entries, self:DropIndex(self:CursorDistance()))
		setChanged()
	end
end

local function createButton(slot)
	local button = CreateFrame("Button", nil, slot.frame)
	button:RegisterForDrag("LeftButton")
	button.Icon = button:CreateTexture(nil, "ARTWORK")
	button.Count = button:CreateFontString(nil, "OVERLAY")
	button.Count:SetWordWrap(false)
	button:SetScript("OnEnter", function(self)
		slot:ShowTooltip(self)
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:SetScript("OnDragStart", function(self)
		slot:StartDrag(self)
	end)
	button:SetScript("OnDragStop", function()
		slot:StopDrag()
	end)
	button:SetScript("OnReceiveDrag", function()
		slot:ReceiveItem()
	end)
	button:SetScript("OnMouseUp", function()
		slot:ReceiveItem()
	end)
	return button
end

-- The entries that fit, then the rest: each { entry, index (in the bar's
-- entries), look (Bars.Describe), width, x (from the bar's starting edge) }.
function SlotMixin:Measure()
	local bar = self.bar
	local list = {}
	local font = { NumberFontNormal:GetFont() }
	local measure = self.frame.Measure
	measure:SetFont(font[1], fontSize(bar), font[3])
	for index, entry in ipairs(Bars.Entries(bar)) do
		local look = Bars.Describe(entry)
		if look then
			local iconWidth = look.icon and (bar.size + BarFrame.SPACE) or 0
			list[#list + 1] = { entry = entry, index = index, look = look, width = iconWidth + textWidth(measure, look.text, fontSize(bar)) }
		end
	end
	local total = 0
	for _, item in ipairs(list) do
		total = total + item.width + (total > 0 and bar.gap or 0)
	end
	-- With everything in, no arrow; otherwise the arrow takes its room.
	local room = total <= bar.width and bar.width or (bar.width - bar.size - bar.gap)
	local shown, hidden, used = {}, {}, 0
	for _, item in ipairs(list) do
		local width = item.width + (used > 0 and bar.gap or 0)
		if #hidden == 0 and used + width <= room then
			shown[#shown + 1] = item
			item.x = used + (used > 0 and bar.gap or 0)
			used = used + width
		else
			hidden[#hidden + 1] = item
		end
	end
	return shown, hidden
end

-- Puts a region at a distance from the bar's starting edge.
local function placeAlong(slot, region, distance, extra)
	local frame = slot.frame
	region:ClearAllPoints()
	if fromRight(slot.bar) then
		region:SetPoint("RIGHT", frame, "RIGHT", -distance, extra or 0)
	else
		region:SetPoint("LEFT", frame, "LEFT", distance, extra or 0)
	end
end

local function layoutButton(slot, button, item)
	local bar = slot.bar
	local font = { NumberFontNormal:GetFont() }
	button.entry, button.index, button.x, button.span = item.entry, item.index, item.x, item.width
	placeAlong(slot, button, item.x)
	button:SetSize(item.width, bar.size)
	local hasIcon = item.look.icon ~= nil
	button.Icon:SetShown(hasIcon)
	button.Icon:SetSize(bar.size, bar.size)
	button.Icon:ClearAllPoints()
	button.Icon:SetPoint("LEFT")
	button.Icon:SetTexture(item.look.icon)
	button.Count:ClearAllPoints()
	if hasIcon then
		button.Count:SetPoint("LEFT", button.Icon, "RIGHT", BarFrame.SPACE, 0)
	else
		button.Count:SetPoint("LEFT")
	end
	button.Count:SetFont(font[1], fontSize(bar), font[3])
	button.Count:SetText(item.look.text)
	button.Count:SetTextColor(unpack(item.look.red and BarFrame.RED or BarFrame.WHITE))
	button:SetAlpha(1)
	button:Show()
end

-- The background and the border, as the bar asks.
function SlotMixin:LayoutLook()
	local bar, frame = self.bar, self.frame
	frame.Background:SetColorTexture(0, 0, 0, (bar.opacity or 50) / 100)
	frame.Background:SetShown(bar.background == true or self.preview == true)
	local border = frame.Border
	local height = bar.size + 6
	local edge = math.floor(BarFrame.BORDER_WIDTH * height / BarFrame.BORDER_HEIGHT + 0.5)
	border.Left:SetSize(edge, height)
	border.Right:SetSize(edge, height)
	for _, piece in ipairs({ border.Left, border.Middle, border.Right }) do
		piece:SetShown(bar.border == true)
	end
end

-- Lays the entries out and fills them in.
function SlotMixin:Layout()
	local bar = self.bar
	if not bar then
		return
	end
	local frame = self.frame
	frame:SetSize(bar.width, bar.size)
	self:LayoutLook()
	local shown, hidden = self:Measure()
	for position, item in ipairs(shown) do
		local button = self.buttons[position] or createButton(self)
		self.buttons[position] = button
		layoutButton(self, button, item)
	end
	for position = #shown + 1, #self.buttons do
		self.buttons[position].entry = nil
		self.buttons[position]:Hide()
	end
	self.hidden = hidden
	local more = frame.More
	more:SetSize(bar.size, bar.size)
	more:ClearAllPoints()
	more:SetPoint(fromRight(bar) and "LEFT" or "RIGHT")
	more.Text:SetText(fromRight(bar) and "«" or "»")
	more:SetShown(#hidden > 0)
	frame.Grip:ClearAllPoints()
	local far = fromRight(bar) and "LEFT" or "RIGHT"
	frame.Grip:SetPoint("TOP", frame, "TOP" .. far, 0, 0)
	frame.Grip:SetPoint("BOTTOM", frame, "BOTTOM" .. far, 0, 0)
	frame.Empty:SetShown(self.preview and #shown == 0)
	frame:SetShown(#shown > 0 or #hidden > 0 or self.preview == true)
end

-- The hidden entries, listed by the double arrow.
function SlotMixin:ShowHidden()
	MenuUtil.CreateContextMenu(self.frame.More, function(_, root)
		for _, item in ipairs(self.hidden or {}) do
			local icon = item.look.icon and ("|T%s:0|t "):format(tostring(item.look.icon)) or ""
			root:CreateButton(("%s%s  %s"):format(icon, item.look.name, item.look.text), function() end)
		end
	end)
end

-- The mouse's distance from the bar's starting edge.
function SlotMixin:CursorDistance()
	local x = GetCursorPosition() / self.frame:GetEffectiveScale()
	if fromRight(self.bar) then
		return (self.frame:GetRight() or 0) - x
	end
	return x - (self.frame:GetLeft() or 0)
end

-- The place in the bar's entries a drop at this distance from the starting
-- edge goes to: before the first shown entry whose middle lies past it.
function SlotMixin:DropIndex(distance)
	local last
	for _, button in ipairs(self.buttons) do
		if button.entry then
			if distance < button.x + button.span / 2 then
				return button.index
			end
			last = button.index
		end
	end
	return last and last + 1 or 1
end

-- Where the line that marks a drop goes: in the gap before that entry, or
-- after the last one shown.
function SlotMixin:MarkerDistance(index)
	local after
	for _, button in ipairs(self.buttons) do
		if button.entry then
			if button.index >= index then
				return math.max(0, button.x - self.bar.gap / 2)
			end
			after = button.x + button.span + self.bar.gap / 2
		end
	end
	return after or 0
end

function SlotMixin:StartDrag(button)
	if ns.EditMode.IsActive() or not button.entry or BarFrame.Asking() then
		return
	end
	self.dragged = button
	button:SetAlpha(0.35)
	local ghost = BarFrame.Ghost()
	ghost.Icon:SetShown(button.Icon:IsShown())
	ghost.Icon:SetTexture(button.Icon:IsShown() and Bars.Describe(button.entry).icon or nil)
	ghost.Icon:SetSize(self.bar.size, self.bar.size)
	ghost.Text:SetText(button.Count:GetText())
	ghost.slot = self
	ghost:Show()
end

-- While a drag goes on: the copy follows the mouse; over the bar the line
-- shows where the entry will go, off the bar the copy turns red.
function SlotMixin:FollowDrag()
	local ghost = BarFrame.Ghost()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	ghost:ClearAllPoints()
	ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	local over = self.frame:IsMouseOver()
	ghost.Text:SetTextColor(unpack(over and BarFrame.WHITE or BarFrame.RED))
	ghost.Icon:SetDesaturated(not over)
	local marker = self.frame.Marker
	marker:SetShown(over)
	if over then
		marker:SetSize(BarFrame.MARKER, self.bar.size + 4)
		placeAlong(self, marker, self:MarkerDistance(self:DropIndex(self:CursorDistance())) - BarFrame.MARKER / 2)
	end
end

function SlotMixin:StopDrag()
	local dragged = self.dragged
	self.dragged = nil
	BarFrame.Ghost():Hide()
	self.frame.Marker:Hide()
	if not dragged or not dragged.entry then
		return
	end
	dragged:SetAlpha(1)
	local bar, entry = self.bar, dragged.entry
	if not self.frame:IsMouseOver() then
		local look = Bars.Describe(entry)
		question = ns.NameMenu.Confirm(L["Take “%s” off the bar?"], look and look.name or "", L["Take off"], function()
			-- The dialog is still on screen while it calls this.
			question = nil
			BarFrame.TakeOff(bar, entry)
		end)
		return
	end
	BarFrame.Move(bar, dragged.index, self:DropIndex(self:CursorDistance()))
	setChanged()
end

-- Takes an entry off a bar, wherever it stands on the bar now.
function BarFrame.TakeOff(bar, entry)
	for index, existing in ipairs(Bars.Entries(bar)) do
		if existing.kind == entry.kind and existing.id == entry.id then
			return Bars.Editor and Bars.Editor.Remove(bar, index)
		end
	end
end

-- Moves an entry of a bar from one place to another; to is a place before
-- which it goes, as DropIndex gives it.
function BarFrame.Move(bar, from, to)
	local entries = Bars.OwnEntries(bar)
	if from == to or from + 1 == to then
		return
	end
	local entry = table.remove(entries, from)
	if to > from then
		to = to - 1
	end
	table.insert(entries, to, entry)
end

local ghost

-- The copy of a dragged entry, one for every bar.
function BarFrame.Ghost()
	if not ghost then
		ghost = CreateFrame("Frame", nil, UIParent)
		ghost:SetFrameStrata("TOOLTIP")
		ghost:SetSize(1, 1)
		ghost.Icon = ghost:CreateTexture(nil, "OVERLAY")
		ghost.Icon:SetPoint("RIGHT", ghost, "CENTER", -2, 0)
		ghost.Text = ghost:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		ghost.Text:SetPoint("LEFT", ghost, "CENTER", 2, 0)
		ghost:SetAlpha(0.9)
		ghost:SetScript("OnUpdate", function(self)
			if self.slot and self.slot.dragged then
				self.slot:FollowDrag()
			end
		end)
		ghost:Hide()
	end
	return ghost
end

-- The grip on the far edge sets the width while Edit Mode is open.
function SlotMixin:StartResize()
	if BarFrame.Asking() then
		return
	end
	self.resizeFrom = { GetCursorPosition() / self.frame:GetEffectiveScale(), self.bar.width }
end

function SlotMixin:Resize()
	if not self.resizeFrom then
		return
	end
	local x = GetCursorPosition() / self.frame:GetEffectiveScale()
	local moved = x - self.resizeFrom[1]
	if fromRight(self.bar) then
		moved = -moved
	end
	local range = Sets.WIDTH
	local width = math.floor(self.resizeFrom[2] + moved + 0.5)
	self.bar.width = math.min(math.max(width, range[2]), range[3])
	self:Layout()
end

function SlotMixin:StopResize()
	if self.resizeFrom then
		self.resizeFrom = nil
		setChanged()
	end
end

function SlotMixin:SetPreview(active)
	self.preview = active
	self.frame.Grip:SetShown(active)
	self:Layout()
end

function SlotMixin:SetBar(bar)
	self.bar = bar
	if not bar then
		self.frame:Hide()
		return
	end
	self:Layout()
	ns.EditMode.Refresh(self.frame)
end

-- The bar's settings in its Edit Mode dialog, bound to the bar in this place.
local function slotSettings(slot)
	local defaults = Sets.NewBar(0)
	local function value(key)
		return function()
			local bar = slot.bar
			if bar and bar[key] ~= nil then
				return bar[key]
			end
			return defaults[key]
		end
	end
	local function store(key)
		return function(new)
			if BarFrame.Asking() then
				-- Back to what the bar has.
				ns.EditMode.Refresh(slot.frame)
			elseif slot.bar then
				slot.bar[key] = new
				setChanged()
			end
		end
	end
	local function setting(kind, key, label, extra)
		local object = { kind = kind, key = key, label = label, default = defaults[key], get = value(key), set = store(key) }
		for name, item in pairs(extra or {}) do
			object[name] = item
		end
		return object
	end
	return {
		setting("slider", "width", L["Width"], { min = Sets.WIDTH[2], max = Sets.WIDTH[3], step = 10, format = "%d" }),
		setting("slider", "gap", L["Gap"], { min = Sets.GAP[2], max = Sets.GAP[3], step = 1, format = "%d" }),
		setting("slider", "size", L["Size"], { min = Sets.SIZE[2], max = Sets.SIZE[3], step = 1, format = "%d" }),
		setting("dropdown", "direction", L["Fill from"],
			{ choices = { { "right", L["The left edge"] }, { "left", L["The right edge"] } } }),
		setting("checkbox", "background", L["Background"]),
		setting("slider", "opacity", L["Background opacity"], { min = 0, max = 100, step = 5, format = L["%d %%"] }),
		setting("checkbox", "border", L["Border"]),
	}
end

function BarFrame.Create(module, index)
	local slot = setmetatable({ index = index, buttons = {} }, SlotMixin)
	local frame = CreateFrame("Frame", nil, UIParent)
	slot.frame = frame
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()
	frame.Background = frame:CreateTexture(nil, "BACKGROUND")
	frame.Background:SetPoint("TOPLEFT", -2, 2)
	frame.Background:SetPoint("BOTTOMRIGHT", 2, -2)
	frame.Background:Hide()
	frame.Border = {}
	for _, part in ipairs({ "Left", "Middle", "Right" }) do
		local piece = frame:CreateTexture(nil, "BORDER")
		piece:SetTexelSnappingBias(0)
		piece:SetAtlas(BarFrame.BORDER_ATLAS[part:lower()])
		piece:Hide()
		frame.Border[part] = piece
	end
	frame.Border.Left:SetPoint("LEFT", frame, "LEFT", -4, 0)
	frame.Border.Right:SetPoint("RIGHT", frame, "RIGHT", 4, 0)
	frame.Border.Middle:SetPoint("TOPLEFT", frame.Border.Left, "TOPRIGHT")
	frame.Border.Middle:SetPoint("BOTTOMRIGHT", frame.Border.Right, "BOTTOMLEFT")
	frame.Measure = frame:CreateFontString(nil, "OVERLAY")
	frame.Measure:Hide()
	frame.Marker = frame:CreateTexture(nil, "OVERLAY")
	frame.Marker:SetColorTexture(1, 0.82, 0, 1)
	frame.Marker:Hide()
	frame.Empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.Empty:SetPoint("CENTER")
	frame.Empty:SetText(L["An empty bar: fill it in the bar editor, or drop items from your bags on it."])
	frame.Empty:Hide()
	frame:SetScript("OnReceiveDrag", function()
		slot:ReceiveItem()
	end)
	frame:SetScript("OnMouseUp", function()
		slot:ReceiveItem()
	end)
	frame.More = CreateFrame("Button", nil, frame)
	frame.More.Text = frame.More:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.More.Text:SetPoint("CENTER")
	frame.More:SetScript("OnClick", function()
		slot:ShowHidden()
	end)
	frame.More:Hide()
	frame.Grip = CreateFrame("Button", nil, frame)
	frame.Grip:SetWidth(BarFrame.GRIP)
	frame.Grip:SetFrameLevel(frame:GetFrameLevel() + 20)
	frame.Grip.Texture = frame.Grip:CreateTexture(nil, "OVERLAY")
	frame.Grip.Texture:SetAllPoints()
	frame.Grip.Texture:SetColorTexture(1, 0.82, 0, 0.6)
	frame.Grip:SetScript("OnMouseDown", function()
		slot:StartResize()
	end)
	frame.Grip:SetScript("OnMouseUp", function()
		slot:StopResize()
	end)
	frame.Grip:SetScript("OnUpdate", function()
		slot:Resize()
	end)
	frame.Grip:Hide()

	ns.EditMode.Register(module, frame, {
		key = "Bars" .. index,
		name = L["Currency bar %d"]:format(index),
		default = { point = "BOTTOM", x = 0, y = 160 + (index - 1) * 32 },
		position = {
			get = function(layout)
				return slot.bar and slot.bar.positions and slot.bar.positions[layout]
			end,
			set = function(layout, position)
				if slot.bar then
					slot.bar.positions = slot.bar.positions or {}
					slot.bar.positions[layout] = position
					setChanged()
				end
			end,
		},
		settings = slotSettings(slot),
		buttons = {
			{ text = L["Edit bars"], click = function()
				if Bars.Editor then
					Bars.Editor.Open(slot.bar and slot.bar.id)
				end
			end },
			{ text = L["New bar"], click = function()
				if not BarFrame.Asking() then
					Sets.AddBar(Sets.Current())
				end
			end },
			{ text = L["Remove this bar"], click = function()
				if slot.bar and not BarFrame.Asking() then
					Sets.RemoveBar(Sets.Current(), slot.bar.id)
				end
			end },
		},
		onEditMode = function(active)
			slot:SetPreview(active)
		end,
	})
	return slot
end

-- Positions of an Edit Mode layout that is copied, renamed or deleted, in every
-- bar of every set.
ns.EditMode.AddLayoutHandler(function(from, to, move)
	for _, name in ipairs(Sets.List()) do
		for _, bar in ipairs(Sets.Get(name).bars) do
			local positions = type(bar.positions) == "table" and bar.positions
			if positions and positions[from] then
				if to then
					positions[to] = positions[from]
				end
				if move then
					positions[from] = nil
				end
			end
		end
	end
end)
