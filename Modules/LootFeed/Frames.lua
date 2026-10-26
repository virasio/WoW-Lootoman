local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- Draws the loot feed's rows from the model in the default
-- UI's style, laid out by a design (Design.lua): a big icon with the quality
-- border of the default UI's loot roll, a glow over rare and better items, the
-- name in its quality colour with the amount after it, the owned count on the
-- icon, and one soft background behind all rows. New rows fade in, old ones
-- fade out as the model says.
--
-- The oldest row sits at the anchor edge of the feed and new rows stack away
-- from it: with direction "up" new rows appear on top of the oldest one at the
-- bottom edge, with "down" below the oldest one at the top edge. When a row
-- leaves, the others slide to their new places. Rows pushed out when the feed
-- is full slide past the anchor edge as they fade.
--
-- Rows show tooltips but let clicks through to the game world, and the mouse
-- wheel keeps zooming the camera. Hovering pauses the model's timers. The
-- frame is hidden, and costs nothing, while there are no rows.
--
--   local feed = Frames.Create(model)        -- out of combat, when the module starts
--   feed:SetOptions({ direction = "up", maxRows = 8, layout = Design.Layout(design, size),
--       opacity = 0.5, showOwned = true, showGlow = true })
--   feed:Wake()                              -- after model:Add
--   feed:RefreshOwned()                      -- after the bags change
--   feed:SetPreview(true)                    -- in Edit Mode
ns.Feed = ns.Feed or {}
local Frames = {}
ns.Feed.Frames = Frames
local Design = ns.Feed.Design

-- The most rows on screen: 20 rows, and a few fading out after a push.
Frames.POOL = 24
Frames.FADE_IN = 0.2
-- Seconds a row takes to slide one place.
Frames.SLIDE_TIME = 0.15
-- Items of this quality and better get a glow (Enum.ItemQuality.Rare).
Frames.GLOW_QUALITY = 3
-- The quality border is this much bigger than the icon, as on the loot roll.
Frames.BORDER_SCALE = 42 / 34

local ICONS = {
	money = [[Interface\Icons\inv_misc_coin_01]],
	xp = [[Interface\Icons\XP_Icon]],
	reputation = [[Interface\Icons\achievement_reputation_01]],
}

local WHITE = { 1, 1, 1 }
local GREEN = { 0.1, 1, 0.1 }
local RED = { 1, 0.13, 0.13 }

local function qualityColor(quality)
	local data = quality and ColorManager.GetColorDataForItemQuality(quality)
	return data and { data.r, data.g, data.b } or WHITE
end

local function signed(amount)
	return ("%+d"):format(amount), amount < 0 and RED or GREEN
end

-- What a row shows: { icon, label, labelColor, amount, amountColor, border,
-- glow, owned }. border and glow are atlas names, owned a count; each can be
-- nil. options: showOwned, showGlow.
function Frames.Describe(row, options)
	options = options or {}
	local kind = row.kind
	if kind == "item" or kind == "currency" then
		local look = { icon = row.icon, label = row.name, labelColor = qualityColor(row.quality) }
		if (row.amount or 1) > 1 then
			look.amount, look.amountColor = ("×%d"):format(row.amount), WHITE
		end
		if kind == "currency" then
			look.owned = options.showOwned and row.total or nil
		else
			look.border = ColorManager.GetAtlasDataForLootBorderItemQuality(row.quality or 1) or "loottoast-itemborder-white"
			if options.showGlow and (row.quality or 0) >= Frames.GLOW_QUALITY then
				look.glow = ColorManager.GetAtlasDataForNewItemQuality(row.quality)
			end
			if options.showOwned then
				look.owned = row.owned or Compat.GetItemCount(row.link or row.id)
			end
		end
		-- Right after looting the bags may not have caught up; none is not shown.
		if look.owned == 0 then
			look.owned = nil
		end
		return look
	elseif kind == "money" then
		return { icon = ICONS.money, label = GetMoneyString(row.amount, true), labelColor = WHITE }
	elseif kind == "xp" then
		local amount, color = signed(row.amount)
		return { icon = ICONS.xp, label = L["Experience"], labelColor = WHITE, amount = amount, amountColor = color }
	elseif kind == "reputation" then
		-- A Russian client declines the faction name in most messages; each
		-- form gets a phrase that fits it.
		local phrase = row.declined and L["%s reputation"] or L["Reputation with %s"]
		local amount, color
		if row.amount then
			amount, color = signed(row.amount)
		end
		return { icon = ICONS.reputation, label = phrase:format(row.name), labelColor = WHITE, amount = amount, amountColor = color }
	end
	return { label = tostring(row.name or kind), labelColor = WHITE }
end

local function showTooltip(rowFrame)
	local row = rowFrame.data
	if not row then
		return
	end
	if row.link and row.kind == "item" then
		GameTooltip:SetOwner(rowFrame, "ANCHOR_LEFT")
		GameTooltip:SetHyperlink(row.link)
		GameTooltip:Show()
	elseif row.kind == "currency" and row.id then
		GameTooltip:SetOwner(rowFrame, "ANCHOR_LEFT")
		GameTooltip:SetCurrencyByID(row.id)
		GameTooltip:Show()
	end
end

local function hideTooltip(rowFrame)
	if GameTooltip:IsOwned(rowFrame) then
		GameTooltip:Hide()
	end
end

local fonts

-- The default UI's text and number fonts, read once the game has them.
local function getFonts()
	fonts = fonts or { text = { GameFontNormal:GetFont() }, number = { NumberFontNormal:GetFont() } }
	return fonts
end

-- A row frame with all its parts; ApplyLayout sizes it, Fill shows a row.
function Frames.CreateRow(parent)
	local rowFrame = CreateFrame("Frame", nil, parent)
	rowFrame:SetMouseClickEnabled(false)
	rowFrame:SetMouseMotionEnabled(true)
	rowFrame.Icon = rowFrame:CreateTexture(nil, "ARTWORK")
	rowFrame.Glow = rowFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	rowFrame.Glow:SetBlendMode("ADD")
	rowFrame.IconBorder = rowFrame:CreateTexture(nil, "OVERLAY", nil, 2)
	rowFrame.Owned = rowFrame:CreateFontString(nil, "OVERLAY")
	rowFrame.Label = rowFrame:CreateFontString(nil, "OVERLAY")
	rowFrame.Amount = rowFrame:CreateFontString(nil, "OVERLAY")
	for _, text in ipairs({ rowFrame.Owned, rowFrame.Label, rowFrame.Amount }) do
		text:SetWordWrap(false)
	end
	rowFrame:SetScript("OnEnter", showTooltip)
	rowFrame:SetScript("OnLeave", hideTooltip)
	rowFrame:Hide()
	return rowFrame
end

-- The region of a row frame that draws each part of a design.
Frames.REGIONS = { icon = "Icon", name = "Label", amount = "Amount", owned = "Owned" }

local function regionOf(rowFrame, element)
	return element == "row" and rowFrame or rowFrame[Frames.REGIONS[element]]
end

-- Sizes and places a row's parts for a layout: each part on its anchor's
-- point, the texts in their fonts and alignment.
function Frames.ApplyLayout(rowFrame, layout)
	local font = getFonts()
	local parts = layout.parts
	rowFrame:SetSize(layout.width, layout.height)
	local size = parts.icon.pixels
	rowFrame.Icon:SetSize(size, size)
	local border = math.floor(size * Frames.BORDER_SCALE + 0.5)
	rowFrame.IconBorder:SetSize(border, border)
	rowFrame.IconBorder:ClearAllPoints()
	rowFrame.IconBorder:SetPoint("CENTER", rowFrame.Icon, "CENTER")
	rowFrame.Glow:ClearAllPoints()
	rowFrame.Glow:SetAllPoints(rowFrame.Icon)
	for _, name in ipairs(Design.PLACED) do
		local part, region = parts[name], regionOf(rowFrame, name)
		region:ClearAllPoints()
		region:SetPoint(Design.OwnPoint(layout, name), regionOf(rowFrame, part.anchor), part.point, part.x, part.y)
		if Design.TEXTS[name] then
			local face = name == "owned" and font.number or font.text
			region:SetFont(face[1], part.fontSize, face[3])
			region:SetJustifyH(part.align)
		end
	end
end

-- Shows a row in a row frame; options as for the feed (layout, showOwned, showGlow).
function Frames.Fill(rowFrame, row, options)
	local parts = options.layout.parts
	local look = Frames.Describe(row, options)
	local iconShown = parts.icon.shown and look.icon ~= nil
	rowFrame.Icon:SetShown(iconShown)
	rowFrame.Icon:SetTexture(look.icon)
	rowFrame.IconBorder:SetShown(iconShown and look.border ~= nil)
	if look.border then
		rowFrame.IconBorder:SetAtlas(look.border)
	end
	rowFrame.Glow:SetShown(iconShown and parts.glow.shown and look.glow ~= nil)
	if look.glow then
		rowFrame.Glow:SetAtlas(look.glow)
	end
	-- On the icon, the owned count goes with it.
	rowFrame.Owned:SetShown(parts.owned.shown and look.owned ~= nil and (iconShown or parts.owned.anchor ~= "icon"))
	rowFrame.Owned:SetText(look.owned and tostring(look.owned) or "")
	rowFrame.Amount:SetShown(parts.amount.shown and look.amount ~= nil)
	rowFrame.Amount:SetText(look.amount or "")
	if look.amountColor then
		rowFrame.Amount:SetTextColor(look.amountColor[1], look.amountColor[2], look.amountColor[3])
	end
	rowFrame.Label:SetShown(parts.name.shown)
	rowFrame.Label:SetText(look.label)
	rowFrame.Label:SetTextColor(look.labelColor[1], look.labelColor[2], look.labelColor[3])
	-- Each text takes the width of its words, as far as the design and the room
	-- up to the row's edge allow; a long name leaves room for the amount after it.
	local widths = {}
	for name in pairs(Design.TEXTS) do
		local region = rowFrame[Frames.REGIONS[name]]
		widths[name] = region:IsShown() and region:GetUnboundedStringWidth() or 0
	end
	local rects = Design.Arrange(options.layout, widths)
	for name in pairs(Design.TEXTS) do
		local region, width = rowFrame[Frames.REGIONS[name]], rects[name].width
		-- A width of 0 would let the text take all it wants.
		region:SetWidth(math.max(1, width))
		region:SetShown(region:IsShown() and width >= 1)
	end
	rowFrame.data, rowFrame.amount, rowFrame.total = row, row.amount, row.total
end

local FeedMixin = {}
FeedMixin.__index = FeedMixin

-- Sample rows, one of every kind, newest first: for Edit Mode, so the look can
-- be judged while placing the feed, and for the designer.
function Frames.PreviewRows()
	return {
		{ row = { kind = "item", name = L["Sample item"], icon = [[Interface\Icons\inv_potion_54]], quality = 1, amount = 3, owned = 42 }, alpha = 1 },
		{ row = { kind = "item", name = L["Sample rare item"], icon = [[Interface\Icons\inv_shield_1h_nzothraid_d_01]], quality = 4, amount = 1, owned = 1 }, alpha = 1 },
		{ row = { kind = "money", amount = 123456 }, alpha = 1 },
		{ row = { kind = "currency", name = L["Sample currency"], icon = [[Interface\Icons\inv_misc_coin_17]], quality = 3, amount = 5, total = 120 }, alpha = 1 },
		{ row = { kind = "reputation", name = L["Sample faction"], amount = 250 }, alpha = 1 },
	}
end

-- Puts a row at a distance from the anchor edge.
local function place(feed, rowFrame, offset)
	rowFrame.offset = offset
	rowFrame:ClearAllPoints()
	if feed.options.direction == "down" then
		rowFrame:SetPoint("TOPLEFT", feed.frame, "TOPLEFT", 0, -offset)
	else
		rowFrame:SetPoint("BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 0, offset)
	end
end

local function release(feed, row, rowFrame)
	feed.frameOf[row] = nil
	rowFrame.data = nil
	hideTooltip(rowFrame)
	rowFrame:Hide()
	feed.free[#feed.free + 1] = rowFrame
end

-- The shared background spans the rows on screen, from the anchor edge to the
-- farthest row, with the gap as a margin; it fades out to the right.
local function placeBackground(feed)
	local far = 0
	for _, rowFrame in pairs(feed.frameOf) do
		far = math.max(far, rowFrame.offset + feed.options.layout.height)
	end
	local background = feed.frame.Background
	background:SetShown(far > 0)
	if far > 0 then
		local margin = feed.options.layout.gap
		background:ClearAllPoints()
		if feed.options.direction == "down" then
			background:SetPoint("TOPLEFT", feed.frame, "TOPLEFT", -margin, margin)
		else
			background:SetPoint("BOTTOMLEFT", feed.frame, "BOTTOMLEFT", -margin, -margin)
		end
		background:SetSize(feed.options.layout.width + 2 * margin, far + 2 * margin)
	end
end

function Frames.Create(model)
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetClampedToScreen(true)
	frame:SetMouseClickEnabled(false)
	frame:SetMouseMotionEnabled(false)
	frame.PreviewBackground = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	frame.PreviewBackground:SetAllPoints()
	frame.PreviewBackground:SetColorTexture(0, 0, 0, 0.2)
	frame.PreviewBackground:Hide()
	frame.Background = frame:CreateTexture(nil, "BACKGROUND")
	frame.Background:SetColorTexture(1, 1, 1, 1)
	frame.Background:Hide()
	local feed = setmetatable({
		frame = frame,
		model = model,
		rows = {},
		free = {},
		-- The frame of each row on screen; a row keeps its frame while shown.
		frameOf = {},
		seen = setmetatable({}, { __mode = "k" }),
		version = 0,
	}, FeedMixin)
	for index = 1, Frames.POOL do
		feed.rows[index] = Frames.CreateRow(frame)
		feed.free[index] = feed.rows[index]
	end
	frame:SetScript("OnUpdate", function()
		feed:Draw(Compat.GetTime())
	end)
	frame:Hide()
	feed:SetOptions({ direction = "up", maxRows = 8, layout = Design.Layout(Design.LARGE, Design.BASE_SIZE), opacity = 0.5 })
	return feed
end

function FeedMixin:SetOptions(options)
	self.options = options
	local layout = options.layout
	self.step = layout.height + layout.gap
	self.frame:SetSize(layout.width, options.maxRows * self.step - layout.gap)
	self.frame.Background:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, options.opacity), CreateColor(0, 0, 0, 0))
	for _, rowFrame in ipairs(self.rows) do
		Frames.ApplyLayout(rowFrame, layout)
	end
	for _, rowFrame in pairs(self.frameOf) do
		place(self, rowFrame, rowFrame.offset)
	end
	self.version = self.version + 1
end

-- Shows the feed after the model got a row; it hides itself when it has none.
function FeedMixin:Wake()
	self.frame:Show()
end

-- Owned counts are read again on the next draw.
function FeedMixin:RefreshOwned()
	self.version = self.version + 1
end

function FeedMixin:SetPreview(active)
	self.preview = active and Frames.PreviewRows() or nil
	self.frame.PreviewBackground:SetShown(active)
	self.frame:SetShown(active or #self.model:Visible(Compat.GetTime()) > 0)
end

function FeedMixin:Draw(now)
	local model = self.model
	local elapsed = self.drawnAt and math.max(0, now - self.drawnAt) or 0
	self.drawnAt = now
	local hovered = self.frame:IsMouseOver()
	model:SetHover(hovered, now)
	model:Update(now)
	local views = model:Visible(now)
	if self.preview then
		views = {}
		for index = 1, math.min(#self.preview, self.options.maxRows) do
			views[index] = self.preview[index]
		end
	end

	local shown = {}
	for _, view in ipairs(views) do
		shown[view.row] = true
	end
	for row, rowFrame in pairs(self.frameOf) do
		if not shown[row] then
			release(self, row, rowFrame)
		end
	end

	-- Views come newest first; the oldest of the live rows takes the place at the
	-- anchor edge, and rows pushed out past maxRows get places beyond it.
	local live = math.min(#views, self.options.maxRows)
	local slide = self.step / Frames.SLIDE_TIME * elapsed
	for index, view in ipairs(views) do
		local row = view.row
		local target = (live - index) * self.step
		local rowFrame = self.frameOf[row]
		if not rowFrame and #self.free > 0 then
			rowFrame = table.remove(self.free)
			self.frameOf[row] = rowFrame
			place(self, rowFrame, target)
		elseif rowFrame and rowFrame.offset ~= target then
			local distance = target - rowFrame.offset
			place(self, rowFrame, math.abs(distance) <= slide and target
				or rowFrame.offset + (distance > 0 and slide or -slide))
		end
		if rowFrame then
			if rowFrame.data ~= row or rowFrame.amount ~= row.amount or rowFrame.total ~= row.total
				or rowFrame.version ~= self.version then
				Frames.Fill(rowFrame, row, self.options)
				rowFrame.version = self.version
			end
			self.seen[row] = self.seen[row] or now
			local fadeIn = math.min(1, (now - self.seen[row]) / Frames.FADE_IN)
			rowFrame:SetAlpha(view.alpha * (self.preview and 1 or fadeIn))
			rowFrame:Show()
		end
	end
	placeBackground(self)

	if #views == 0 and not hovered then
		self.frame:Hide()
	end
end
