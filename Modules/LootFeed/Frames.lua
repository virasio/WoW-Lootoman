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
-- bottom edge, with "down" below the oldest one at the top edge, with "right"
-- right of the oldest one at the left edge, with "left" left of the oldest
-- one at the right edge (the sideways directions are for icons). When a row
-- leaves, the others slide to their new places. Rows pushed out when the feed
-- is full slide past the anchor edge as they fade.
--
-- Warnings (few free bag slots) take the first places at the anchor edge, one
-- row's height each, and the rows stack after them: lines of text, or with an
-- Icons layout a bag icon with the free slots in red and the text in its
-- tooltip. Filling sideways, they are lines above the strip of icons instead.
-- While there is a warning the feed stays shown.
--
-- Rows show tooltips but let clicks through to the game world, and the mouse
-- wheel keeps zooming the camera. Hovering pauses the model's timers. The
-- frame is hidden, and costs nothing, while there are no rows and no warnings.
--
--   local feed = Frames.Create(model)        -- out of combat, when the module starts
--   feed:SetOptions({ direction = "up", maxRows = 8, layout = Design.Layout(design, size),
--       opacity = 0.5, showOwned = true, showGlow = true })
--   feed:Wake()                              -- after model:Add
--   feed:RefreshOwned()                      -- after the bags change
--   feed:SetPreview(true)                    -- in Edit Mode
--   feed:SetWarnings({ { text = "Free bag slots: 2", count = 2 } }) -- or {} for none
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

-- The decimal point of the client's language.
local function decimalPoint()
	return Compat.GetGlobalString("DECIMAL_SEPERATOR") or "."
end

-- On an icon a gain needs no sign, and a loss shows a minus in red.
local function short(amount)
	if amount < 0 then
		return "-" .. ns.Text.ShortNumber(-amount, decimalPoint()), RED
	end
	return ns.Text.ShortNumber(amount, decimalPoint()), GREEN
end

-- Money on an icon: the short number and its coin, as big as the text.
local function shortMoney(copper, layout)
	local text, coin = ns.Text.ShortMoney(copper, decimalPoint())
	local size = layout.parts.amount.fontSize
	return text .. CreateAtlasMarkup("coin-" .. coin, size, size)
end

-- What a row shows: { icon, label, labelColor, amount, amountColor, border,
-- glow, owned }. border and glow are atlas names, owned a count; each can be
-- nil. options: showOwned, showGlow, layout (an icons layout makes the
-- amounts short: no "×" and no "+", thousands as "1.23K", money as a number
-- and a coin).
function Frames.Describe(row, options)
	options = options or {}
	local kind = row.kind
	local icons = options.layout ~= nil and Design.View(options.layout) == "icons"
	if kind == "item" or kind == "currency" then
		local look = { icon = row.icon, label = row.name, labelColor = qualityColor(row.quality) }
		if (row.amount or 1) > 1 then
			look.amount = icons and ns.Text.ShortNumber(row.amount, decimalPoint()) or ("×%d"):format(row.amount)
			look.amountColor = WHITE
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
		local look = { icon = ICONS.money, label = GetMoneyString(row.amount, true), labelColor = WHITE }
		if icons then
			look.amount, look.amountColor = shortMoney(row.amount, options.layout), WHITE
		end
		return look
	elseif kind == "xp" then
		local amount, color = (icons and short or signed)(row.amount)
		return { icon = ICONS.xp, label = L["Experience"], labelColor = WHITE, amount = amount, amountColor = color }
	elseif kind == "reputation" then
		-- A Russian client declines the faction name in most messages; each
		-- form gets a phrase that fits it.
		local phrase = row.declined and L["%s reputation"] or L["Reputation with %s"]
		local amount, color
		if row.amount then
			amount, color = (icons and short or signed)(row.amount)
		end
		return { icon = ICONS.reputation, label = phrase:format(row.name), labelColor = WHITE, amount = amount, amountColor = color }
	end
	return { label = tostring(row.name or kind), labelColor = WHITE }
end

-- An amount in full with its sign, for a tooltip ("+12,345").
local function fullSigned(amount)
	return (amount < 0 and "-" or "+") .. Compat.BreakUpLargeNumbers(math.abs(amount))
end

-- Over an item or a currency the game's tooltip; over money, experience and
-- reputation what their row says in full, as an icon cannot.
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
	elseif row.kind == "money" or row.kind == "xp" or row.kind == "reputation" then
		local look = Frames.Describe(row)
		GameTooltip:SetOwner(rowFrame, "ANCHOR_LEFT")
		if row.kind == "money" then
			GameTooltip_SetTitle(GameTooltip, L["Money"])
			GameTooltip:AddLine(look.label, 1, 1, 1)
		else
			GameTooltip_SetTitle(GameTooltip, look.label)
			if row.amount then
				local color = row.amount < 0 and RED or GREEN
				GameTooltip:AddLine(fullSigned(row.amount), color[1], color[2], color[3])
			end
		end
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
	-- The amount's own background, when the design asks: over the icon and its
	-- border, under the amount.
	rowFrame.AmountBackground = rowFrame:CreateTexture(nil, "OVERLAY", nil, 3)
	rowFrame.AmountBackground:SetPoint("TOPLEFT", rowFrame.Amount, "TOPLEFT", -2, 1)
	rowFrame.AmountBackground:SetPoint("BOTTOMRIGHT", rowFrame.Amount, "BOTTOMRIGHT", 2, -1)
	rowFrame.AmountBackground:Hide()
	rowFrame.Amount:SetDrawLayer("OVERLAY", 4)
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
	rowFrame.AmountBackground:SetColorTexture(0, 0, 0, parts.amount.opacity / 100)
	rowFrame.AmountBackground:SetShown(parts.amount.background and rowFrame.Amount:IsShown())
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
		{ row = { kind = "xp", amount = 12345 }, alpha = 1 },
	}
end

-- The warnings' text colour: the default UI's red for errors.
Frames.WARNING_COLOR = { 1, 0.25, 0.25 }
Frames.WARNING_ICON = [[Interface\Icons\INV_Misc_Bag_08]]

local SIDEWAYS = { left = true, right = true }

local function sideways(feed)
	return SIDEWAYS[feed.options.direction] == true
end

-- How far the rows start from the anchor edge: past the warnings, unless they
-- are lines above a sideways strip.
local function base(feed)
	return sideways(feed) and 0 or #feed.warnings * feed.step
end

-- Puts a row at a distance from the anchor edge.
local function place(feed, rowFrame, offset)
	rowFrame.offset = offset
	rowFrame:ClearAllPoints()
	local direction = feed.options.direction
	if direction == "down" then
		rowFrame:SetPoint("TOPLEFT", feed.frame, "TOPLEFT", 0, -offset)
	elseif direction == "right" then
		rowFrame:SetPoint("BOTTOMLEFT", feed.frame, "BOTTOMLEFT", offset, 0)
	elseif direction == "left" then
		rowFrame:SetPoint("BOTTOMRIGHT", feed.frame, "BOTTOMRIGHT", -offset, 0)
	else
		rowFrame:SetPoint("BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 0, offset)
	end
end

-- A warning line's height above a sideways strip: its text and a little room.
local function lineHeight(feed)
	return feed.options.layout.parts.name.fontSize + 6
end

local function release(feed, row, rowFrame)
	feed.frameOf[row] = nil
	rowFrame.data = nil
	hideTooltip(rowFrame)
	rowFrame:Hide()
	feed.free[#feed.free + 1] = rowFrame
end

-- The shared background spans the rows on screen, from the anchor edge to the
-- farthest row, with the gap as a margin; it fades out to the right, but for
-- icons. Filling sideways, it also spans the warning lines above the strip.
local function placeBackground(feed)
	local layout = feed.options.layout
	local length = sideways(feed) and layout.width or layout.height
	local far = (#feed.warnings > 0 and not sideways(feed)) and (base(feed) - layout.gap) or 0
	for _, rowFrame in pairs(feed.frameOf) do
		far = math.max(far, rowFrame.offset + length)
	end
	local background = feed.frame.Background
	local lines = sideways(feed) and #feed.warnings * lineHeight(feed) or 0
	background:SetShown(far > 0 or lines > 0)
	if far > 0 or lines > 0 then
		local margin = layout.gap
		local direction = feed.options.direction
		background:ClearAllPoints()
		if direction == "down" then
			background:SetPoint("TOPLEFT", feed.frame, "TOPLEFT", -margin, margin)
		elseif direction == "left" then
			background:SetPoint("BOTTOMRIGHT", feed.frame, "BOTTOMRIGHT", margin, -margin)
		else
			background:SetPoint("BOTTOMLEFT", feed.frame, "BOTTOMLEFT", -margin, -margin)
		end
		if sideways(feed) then
			-- Under warning lines, as wide as the strip they may take.
			local span = lines > 0 and (feed.options.maxRows * feed.step - layout.gap) or math.max(far, layout.width)
			background:SetSize(span + 2 * margin, layout.height + lines + 2 * margin)
		else
			background:SetSize(layout.width + 2 * margin, far + 2 * margin)
		end
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
		warnings = {},
		warningLines = {},
		warningIcons = {},
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

local function showWarningTooltip(icon)
	GameTooltip:SetOwner(icon, "ANCHOR_LEFT")
	GameTooltip_SetTitle(GameTooltip, icon.text)
	GameTooltip:Show()
end

-- Warnings as icons, in an Icons layout filling up or down: a bag icon with
-- the free slots in red where the amount sits, in the places of rows.
local function placeWarningIcons(feed)
	local layout = feed.options.layout
	local amount = layout.parts.amount
	local font = getFonts().number
	for index, warning in ipairs(feed.warnings) do
		local icon = feed.warningIcons[index]
		if not icon then
			icon = CreateFrame("Frame", nil, feed.frame)
			icon:SetMouseClickEnabled(false)
			icon:SetMouseMotionEnabled(true)
			icon.Icon = icon:CreateTexture(nil, "ARTWORK")
			icon.Icon:SetAllPoints()
			icon.Icon:SetTexture(Frames.WARNING_ICON)
			icon.Count = icon:CreateFontString(nil, "OVERLAY")
			icon.Count:SetWordWrap(false)
			icon:SetScript("OnEnter", showWarningTooltip)
			icon:SetScript("OnLeave", hideTooltip)
			feed.warningIcons[index] = icon
		end
		icon:SetSize(layout.width, layout.height)
		icon.Count:SetFont(font[1], amount.fontSize, font[3])
		icon.Count:SetTextColor(unpack(Frames.WARNING_COLOR))
		icon.Count:ClearAllPoints()
		icon.Count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
		icon.Count:SetText(tostring(warning.count or 0))
		icon.text = warning.text
		place(feed, icon, (index - 1) * feed.step)
		icon:Show()
	end
	for index = #feed.warnings + 1, #feed.warningIcons do
		feed.warningIcons[index]:Hide()
	end
end

-- The warnings, at the anchor edge in the order given, or above a sideways
-- strip, the first one nearest to it: lines of text, or icons (above).
local function placeWarnings(feed)
	local layout = feed.options.layout
	local across = sideways(feed)
	local asIcons = Design.View(layout) == "icons" and not across
	for index = 1, #feed.warningIcons do
		feed.warningIcons[index]:SetShown(asIcons and index <= #feed.warnings)
	end
	if asIcons then
		for index = 1, #feed.warningLines do
			feed.warningLines[index]:Hide()
		end
		placeWarningIcons(feed)
		return
	end
	local font = getFonts().text
	local height = across and lineHeight(feed) or layout.height
	local width = across and (feed.options.maxRows * feed.step - layout.gap) or layout.width
	for index, warning in ipairs(feed.warnings) do
		local line = feed.warningLines[index]
		if not line then
			line = CreateFrame("Frame", nil, feed.frame)
			line.Icon = line:CreateTexture(nil, "ARTWORK")
			line.Icon:SetTexture(Frames.WARNING_ICON)
			line.Text = line:CreateFontString(nil, "OVERLAY")
			line.Text:SetWordWrap(false)
			line.Text:SetJustifyH("LEFT")
			feed.warningLines[index] = line
		end
		line:SetSize(width, height)
		line.Icon:SetSize(height * 0.6, height * 0.6)
		line.Icon:ClearAllPoints()
		line.Icon:SetPoint("LEFT", line, "LEFT", 0, 0)
		line.Text:SetFont(font[1], layout.parts.name.fontSize, font[3])
		line.Text:SetTextColor(unpack(Frames.WARNING_COLOR))
		line.Text:ClearAllPoints()
		line.Text:SetPoint("LEFT", line.Icon, "RIGHT", 6, 0)
		line.Text:SetText(warning.text)
		if across then
			local edge = feed.options.direction == "left" and "BOTTOMRIGHT" or "BOTTOMLEFT"
			line.offset = nil
			line:ClearAllPoints()
			line:SetPoint(edge, feed.frame, edge, 0, layout.height + (index - 1) * height)
		else
			place(feed, line, (index - 1) * feed.step)
		end
		line:Show()
	end
	for index = #feed.warnings + 1, #feed.warningLines do
		feed.warningLines[index]:Hide()
	end
end

-- Shows these warnings at the anchor edge, each { text, count } (a text alone
-- will do); the rows move past them.
function FeedMixin:SetWarnings(warnings)
	self.warnings = {}
	for index, warning in ipairs(warnings) do
		self.warnings[index] = type(warning) == "table" and warning or { text = warning }
	end
	placeWarnings(self)
	self.version = self.version + 1
	if #warnings > 0 then
		self.frame:Show()
	end
end

function FeedMixin:SetOptions(options)
	self.options = options
	local layout = options.layout
	if sideways(self) then
		self.step = layout.width + layout.gap
		self.frame:SetSize(options.maxRows * self.step - layout.gap, layout.height)
	else
		self.step = layout.height + layout.gap
		self.frame:SetSize(layout.width, options.maxRows * self.step - layout.gap)
	end
	placeWarnings(self)
	-- Behind icons the background is even; behind rows it fades out to the right.
	local fadeTo = Design.View(layout) == "icons" and options.opacity or 0
	self.frame.Background:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, options.opacity), CreateColor(0, 0, 0, fadeTo))
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
	self.frame:SetShown(active or #self.model:Visible(Compat.GetTime()) > 0 or #self.warnings > 0)
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
		local target = base(self) + (live - index) * self.step
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

	if #views == 0 and not hovered and #self.warnings == 0 then
		self.frame:Hide()
	end
end
