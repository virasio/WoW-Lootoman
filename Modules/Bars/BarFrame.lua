local _, ns = ...
local L = ns.L

-- One currency bar on screen: its entries from the left edge, an icon and a
-- count each, a gap apart; what does not fit hides behind a double arrow on
-- the right, whose click lists the rest. Outside Edit Mode an entry is dragged
-- along the bar to a new place (nothing goes onto the game's cursor). In Edit
-- Mode the bar is placed and its width, gap and size are set in its dialog, or
-- the width with the grip on its right edge; the dialog also adds a bar,
-- removes this one and opens the editor. Positions and settings live in the
-- bar itself, in its set (Sets.lua).
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
BarFrame.RED = { 1, 0.13, 0.13 }
BarFrame.WHITE = { 1, 1, 1 }

local SlotMixin = {}
SlotMixin.__index = SlotMixin

local function fontSize(bar)
	return math.max(8, math.floor(bar.size * 0.6 + 0.5))
end

local function setChanged()
	Sets.Changed(Sets.Current())
end

function SlotMixin:ShowTooltip(button)
	local entry = button.entry
	GameTooltip:SetOwner(button, "ANCHOR_TOP")
	if entry.kind == "currency" then
		GameTooltip:SetCurrencyByID(entry.id)
	else
		GameTooltip:SetItemByID(entry.id)
	end
	if not ns.EditMode.IsActive() then
		GameTooltip:AddLine(L["Drag it along the bar to move it."], 0, 1, 0)
	end
	GameTooltip:Show()
end

local function createButton(slot)
	local button = CreateFrame("Button", nil, slot.frame)
	button:RegisterForDrag("LeftButton")
	button.Icon = button:CreateTexture(nil, "ARTWORK")
	button.Icon:SetPoint("LEFT")
	button.Count = button:CreateFontString(nil, "OVERLAY")
	button.Count:SetPoint("LEFT", button.Icon, "RIGHT", BarFrame.SPACE, 0)
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
	return button
end

-- The entries that fit, then the rest: each { entry, index (in the bar's
-- entries), look (Bars.Describe), width }.
function SlotMixin:Measure()
	local bar = self.bar
	local list = {}
	local font = { NumberFontNormal:GetFont() }
	local measure = self.frame.Measure
	measure:SetFont(font[1], fontSize(bar), font[3])
	for index, entry in ipairs(Bars.Entries(bar)) do
		local look = Bars.Describe(entry)
		if look then
			measure:SetText(look.text)
			list[#list + 1] = { entry = entry, index = index, look = look,
				width = bar.size + BarFrame.SPACE + measure:GetUnboundedStringWidth() }
		end
	end
	local shown, used = {}, 0
	local total = 0
	for _, item in ipairs(list) do
		total = total + item.width + (total > 0 and bar.gap or 0)
	end
	-- With everything in, no arrow; otherwise the arrow takes its room.
	local room = total <= bar.width and bar.width or (bar.width - bar.size - bar.gap)
	local hidden = {}
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

-- Lays the entries out and fills them in.
function SlotMixin:Layout()
	local bar = self.bar
	if not bar then
		return
	end
	local frame = self.frame
	frame:SetSize(bar.width, bar.size)
	local shown, hidden = self:Measure()
	local font = { NumberFontNormal:GetFont() }
	for position, item in ipairs(shown) do
		local button = self.buttons[position] or createButton(self)
		self.buttons[position] = button
		button.entry, button.index, button.x, button.span = item.entry, item.index, item.x, item.width
		button:ClearAllPoints()
		button:SetPoint("LEFT", frame, "LEFT", item.x, 0)
		button:SetSize(item.width, bar.size)
		button.Icon:SetSize(bar.size, bar.size)
		button.Icon:SetTexture(item.look.icon)
		button.Count:SetFont(font[1], fontSize(bar), font[3])
		button.Count:SetText(item.look.text)
		button.Count:SetTextColor(unpack(item.look.red and BarFrame.RED or BarFrame.WHITE))
		button:Show()
	end
	for position = #shown + 1, #self.buttons do
		self.buttons[position].entry = nil
		self.buttons[position]:Hide()
	end
	self.hidden = hidden
	frame.More:SetSize(bar.size, bar.size)
	frame.More:SetShown(#hidden > 0)
	frame.Empty:SetShown(self.preview and #shown == 0)
	frame:SetShown(#shown > 0 or #hidden > 0 or self.preview == true)
end

-- The hidden entries, listed by the double arrow.
function SlotMixin:ShowHidden()
	MenuUtil.CreateContextMenu(self.frame.More, function(_, root)
		for _, item in ipairs(self.hidden or {}) do
			root:CreateButton(("|T%s:0|t %s  %s"):format(tostring(item.look.icon), item.look.name, item.look.text), function() end)
		end
	end)
end

function SlotMixin:StartDrag(button)
	if ns.EditMode.IsActive() or not button.entry then
		return
	end
	self.dragged = button
end

-- The place in the bar's entries a drop at this distance from the bar's left
-- edge goes to: before the first shown entry whose middle lies right of it.
function SlotMixin:DropIndex(x)
	local last
	for _, button in ipairs(self.buttons) do
		if button.entry then
			if x < button.x + button.span / 2 then
				return button.index
			end
			last = button.index
		end
	end
	return last and last + 1 or 1
end

function SlotMixin:StopDrag()
	local dragged = self.dragged
	self.dragged = nil
	if not dragged or not dragged.entry then
		return
	end
	local scale = self.frame:GetEffectiveScale()
	local cursor = GetCursorPosition() / scale
	local left = self.frame:GetLeft() or 0
	BarFrame.Move(self.bar, dragged.index, self:DropIndex(cursor - left))
	setChanged()
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

-- The grip on the right edge sets the width while Edit Mode is open.
function SlotMixin:StartResize()
	self.resizeFrom = { GetCursorPosition() / self.frame:GetEffectiveScale(), self.bar.width }
end

function SlotMixin:Resize()
	if not self.resizeFrom then
		return
	end
	local x = GetCursorPosition() / self.frame:GetEffectiveScale()
	local range = Sets.WIDTH
	local width = math.floor(self.resizeFrom[2] + (x - self.resizeFrom[1]) + 0.5)
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
	self.frame.Background:SetShown(active)
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

-- A bar's number in Edit Mode: its place in the set.
local function slotSettings(slot)
	local function value(key)
		return function()
			return slot.bar and slot.bar[key] or Sets[key:upper()][1]
		end
	end
	local function store(key)
		return function(number)
			if slot.bar then
				slot.bar[key] = number
				setChanged()
			end
		end
	end
	return {
		{ kind = "slider", key = "width", label = L["Width"], min = Sets.WIDTH[2], max = Sets.WIDTH[3], step = 10, format = "%d",
			default = Sets.WIDTH[1], get = value("width"), set = store("width") },
		{ kind = "slider", key = "gap", label = L["Gap"], min = Sets.GAP[2], max = Sets.GAP[3], step = 1, format = "%d",
			default = Sets.GAP[1], get = value("gap"), set = store("gap") },
		{ kind = "slider", key = "size", label = L["Size"], min = Sets.SIZE[2], max = Sets.SIZE[3], step = 1, format = "%d",
			default = Sets.SIZE[1], get = value("size"), set = store("size") },
	}
end

function BarFrame.Create(module, index)
	local slot = setmetatable({ index = index, buttons = {} }, SlotMixin)
	local frame = CreateFrame("Frame", nil, UIParent)
	slot.frame = frame
	frame:SetClampedToScreen(true)
	frame:Hide()
	frame.Background = frame:CreateTexture(nil, "BACKGROUND")
	frame.Background:SetAllPoints()
	frame.Background:SetColorTexture(0, 0, 0, 0.3)
	frame.Background:Hide()
	frame.Measure = frame:CreateFontString(nil, "OVERLAY")
	frame.Measure:Hide()
	frame.Empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.Empty:SetPoint("LEFT", 4, 0)
	frame.Empty:SetText(L["An empty bar: fill it in the bar editor."])
	frame.Empty:Hide()
	frame.More = CreateFrame("Button", nil, frame)
	frame.More:SetPoint("RIGHT")
	frame.More.Text = frame.More:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.More.Text:SetPoint("CENTER")
	frame.More.Text:SetText("»")
	frame.More:SetScript("OnClick", function()
		slot:ShowHidden()
	end)
	frame.More:Hide()
	frame.Grip = CreateFrame("Button", nil, frame)
	frame.Grip:SetPoint("TOPLEFT", frame, "TOPRIGHT", -BarFrame.GRIP / 2, 0)
	frame.Grip:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -BarFrame.GRIP / 2, 0)
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
				Sets.AddBar(Sets.Current())
			end },
			{ text = L["Remove this bar"], click = function()
				if slot.bar then
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
