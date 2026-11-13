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
-- Few free bag slots: one warning row takes the first place at the anchor
-- edge, drawn by the design as any row: a bag icon with a red border, the
-- warning as its name, and as its amount the free slots of each kind of bag
-- that is low, each in its colour, joined by "+" (general white, reagent
-- green: "3+2"). Its tooltip names each. While it shows the feed stays shown.
--
-- A stuck row (Model.lua: an item the character can use) comes next, after the
-- warning, and the fading rows stack after it. It shows a pin, or the bags'
-- quest mark for an item that starts a quest, and a badge with how many more
-- wait under it; a left click lets it go. In a fight the use button over it
-- cannot move (UseButton.lua), so the stuck row keeps its place: a warning that
-- comes meanwhile goes after it, and one that goes leaves a gap, until the
-- fight is over.
--
-- Rows show tooltips but let clicks through to the game world, but for the
-- stuck one, and the mouse wheel keeps zooming the camera. Hovering pauses the model's timers. The
-- frame is hidden, and costs nothing, while there are no rows and no warnings.
--
--   local feed = Frames.Create(model)        -- out of combat, when the module starts
--   feed:SetOptions({ direction = "up", maxRows = 8, layout = Design.Layout(design, size),
--       opacity = 0.5, showOwned = true, showGlow = true })
--   feed:Wake()                              -- after model:Add
--   feed:RefreshOwned()                      -- after the bags change
--   feed:SetPreview(true)                    -- in Edit Mode
--   feed:SetWarnings({ { kind = "general", count = 2, text = "Free bag slots: 2" } }) -- or {} for none
ns.Feed = ns.Feed or {}
local Frames = {}
ns.Feed.Frames = Frames
local Design = ns.Feed.Design

-- The most rows on screen: 20 rows, and a few fading out after a push.
Frames.POOL = 24
-- A stuck row's pin: the game's own map pin.
Frames.PIN = "Waypoint-MapPin-Tracked"
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
			-- The client counts only an item it is told of: in the bags and the bank,
			-- or as the layout says, in the bags only.
			if options.showOwned and (row.owned or row.link or row.id) then
				local bagsOnly = options.layout ~= nil and options.layout.parts.owned.count == "bags"
				look.owned = row.owned or Compat.GetItemCount(row.link or row.id, bagsOnly)
			end
		end
		-- Right after looting the bags may not have caught up; none is not shown.
		if look.owned == 0 then
			look.owned = nil
		end
		-- On icons the owned count is short too, as the amount is.
		if look.owned then
			look.ownedText = icons and ns.Text.ShortNumber(look.owned, decimalPoint()) or tostring(look.owned)
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
	elseif kind == "warning" then
		local counts = {}
		for _, warning in ipairs(row.warnings) do
			local color = Frames.WARNING_KINDS[warning.kind] or WHITE
			local function byte(value)
				return math.floor(value * 255 + 0.5)
			end
			counts[#counts + 1] = ("|cff%02x%02x%02x%d|r"):format(byte(color[1]), byte(color[2]), byte(color[3]), warning.count or 0)
		end
		return { icon = Frames.WARNING_ICON, label = L["Few free bag slots"], labelColor = Frames.WARNING_COLOR,
			amount = table.concat(counts, "+"), amountColor = WHITE, border = Frames.WARNING_BORDER, borderColor = Frames.WARNING_COLOR }
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
		if rowFrame.stuck then
			-- In a fight the use button may still hold the item of the row before.
			local use = rowFrame.feed and rowFrame.feed.useButton
			if use and Compat.InCombat() and not use:Uses(row) then
				GameTooltip:AddLine(L["Left-click: dismiss. Right-click: use, after the fight."], 0.5, 1, 0.5)
			else
				GameTooltip:AddLine(L["Left-click: dismiss. Right-click: use."], 0.5, 1, 0.5)
			end
		end
		GameTooltip:Show()
	elseif row.kind == "currency" and row.id then
		GameTooltip:SetOwner(rowFrame, "ANCHOR_LEFT")
		GameTooltip:SetCurrencyByID(row.id)
		GameTooltip:Show()
	elseif row.kind == "warning" then
		GameTooltip:SetOwner(rowFrame, "ANCHOR_LEFT")
		GameTooltip_SetTitle(GameTooltip, L["Few free bag slots"])
		for _, warning in ipairs(row.warnings) do
			local color = Frames.WARNING_KINDS[warning.kind] or WHITE
			GameTooltip:AddLine(warning.text, color[1], color[2], color[3])
		end
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
	-- The row's own background, when the design asks: behind all of it.
	rowFrame.RowBackground = rowFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
	rowFrame.RowBackground:SetAllPoints()
	rowFrame.RowBackground:Hide()
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
	-- The amount's and the owned count's own backgrounds, when the design asks:
	-- over the icon and its border, under the text.
	rowFrame.AmountBackground = rowFrame:CreateTexture(nil, "OVERLAY", nil, 3)
	rowFrame.AmountBackground:SetPoint("TOPLEFT", rowFrame.Amount, "TOPLEFT", -2, 1)
	rowFrame.AmountBackground:SetPoint("BOTTOMRIGHT", rowFrame.Amount, "BOTTOMRIGHT", 2, -1)
	rowFrame.AmountBackground:Hide()
	rowFrame.Amount:SetDrawLayer("OVERLAY", 4)
	rowFrame.OwnedBackground = rowFrame:CreateTexture(nil, "OVERLAY", nil, 3)
	rowFrame.OwnedBackground:SetPoint("TOPLEFT", rowFrame.Owned, "TOPLEFT", -2, 1)
	rowFrame.OwnedBackground:SetPoint("BOTTOMRIGHT", rowFrame.Owned, "BOTTOMRIGHT", 2, -1)
	rowFrame.OwnedBackground:Hide()
	rowFrame.Owned:SetDrawLayer("OVERLAY", 4)
	-- A stuck row's marks: the bags' quest mark over the icon of an item that
	-- starts a quest, else a pin at the icon's top left; and how many wait.
	-- Without the icon they go to the row's edges (placeMarks).
	rowFrame.QuestMark = rowFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	rowFrame.QuestMark:SetTexture(TEXTURE_ITEM_QUEST_BANG)
	rowFrame.QuestMark:Hide()
	rowFrame.Pin = rowFrame:CreateTexture(nil, "OVERLAY", nil, 5)
	rowFrame.Pin:SetAtlas(Frames.PIN)
	rowFrame.Pin:Hide()
	rowFrame.Waiting = rowFrame:CreateFontString(nil, "OVERLAY")
	rowFrame.Waiting:SetDrawLayer("OVERLAY", 5)
	rowFrame.Waiting:Hide()
	rowFrame:SetScript("OnMouseUp", function(self, button)
		-- A left click lets the stuck item go (its right click is the use button's).
		if self.stuck and button == "LeftButton" and self.feed then
			self.feed:Dismiss(self.data)
		end
	end)
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
	local r, g, b = Design.RGB(layout.color)
	rowFrame.RowBackground:SetColorTexture(r, g, b, layout.opacity / 100)
	rowFrame.RowBackground:SetShown(layout.background)
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

-- A kept row's marks: on the icon, or without it at the row's edges, the
-- quest mark or the pin just before its left edge (where the icon would be)
-- and the count of waiting rows inside its right edge.
local function placeMarks(rowFrame, iconShown, height)
	rowFrame.QuestMark:ClearAllPoints()
	rowFrame.Pin:ClearAllPoints()
	rowFrame.Waiting:ClearAllPoints()
	if iconShown then
		rowFrame.QuestMark:SetAllPoints(rowFrame.Icon)
		rowFrame.Pin:SetPoint("CENTER", rowFrame.Icon, "TOPLEFT", 2, -2)
		rowFrame.Waiting:SetPoint("BOTTOMLEFT", rowFrame.Icon, "BOTTOMLEFT", 2, 2)
	else
		rowFrame.QuestMark:SetSize(height, height)
		rowFrame.QuestMark:SetPoint("RIGHT", rowFrame, "LEFT", -2, 0)
		rowFrame.Pin:SetPoint("RIGHT", rowFrame, "LEFT", -2, 0)
		rowFrame.Waiting:SetPoint("RIGHT", rowFrame, "RIGHT", -2, 0)
	end
end

-- Shows a row in a row frame; options as for the feed (layout, showOwned,
-- showGlow); stuck, for the stuck row: { waiting = the rows under it }.
function Frames.Fill(rowFrame, row, options, stuck)
	local parts = options.layout.parts
	local look = Frames.Describe(row, options)
	local iconShown = parts.icon.shown and look.icon ~= nil
	rowFrame.Icon:SetShown(iconShown)
	rowFrame.Icon:SetTexture(look.icon)
	rowFrame.IconBorder:SetShown(iconShown and look.border ~= nil)
	if look.border then
		rowFrame.IconBorder:SetAtlas(look.border)
		local tint = look.borderColor or WHITE
		rowFrame.IconBorder:SetVertexColor(tint[1], tint[2], tint[3])
	end
	rowFrame.Glow:SetShown(iconShown and parts.glow.shown and look.glow ~= nil)
	if look.glow then
		rowFrame.Glow:SetAtlas(look.glow)
	end
	-- On the icon, the owned count goes with it.
	rowFrame.Owned:SetShown(parts.owned.shown and look.owned ~= nil and (iconShown or parts.owned.anchor ~= "icon"))
	rowFrame.Owned:SetText(look.ownedText or "")
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
	for name, texture in pairs({ amount = rowFrame.AmountBackground, owned = rowFrame.OwnedBackground }) do
		local part = parts[name]
		local r, g, b = Design.RGB(part.color)
		texture:SetColorTexture(r, g, b, part.opacity / 100)
		texture:SetShown(part.background and rowFrame[Frames.REGIONS[name]]:IsShown())
	end
	-- The quest mark as soon as the item is known to start a quest; the pin and
	-- the clicks for the stuck row.
	placeMarks(rowFrame, iconShown, options.layout.height)
	rowFrame.QuestMark:SetShown(row.sticky == "quest")
	rowFrame.Pin:SetShown(stuck ~= nil and row.sticky ~= "quest")
	local size = math.max(8, math.floor(parts.icon.pixels * 0.4 + 0.5))
	rowFrame.Pin:SetSize(size, size)
	local waiting = stuck and stuck.waiting or 0
	local font = getFonts().number
	rowFrame.Waiting:SetFont(font[1], parts.owned.fontSize, font[3])
	rowFrame.Waiting:SetText(waiting > 0 and ("+%d"):format(waiting) or "")
	rowFrame.Waiting:SetShown(waiting > 0)
	rowFrame.stuck, rowFrame.waiting = stuck ~= nil, waiting
	-- In the feed only the stuck row takes clicks; the designer's rows take
	-- them all (they choose the row).
	if rowFrame.feed then
		rowFrame:SetMouseClickEnabled(stuck ~= nil)
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
		{ row = { kind = "xp", amount = 12345 }, alpha = 1 },
		{ row = { kind = "item", name = L["Sample quest item"], icon = [[Interface\Icons\INV_Misc_Note_02]], quality = 1, amount = 1,
			owned = 1, sticky = "quest" }, alpha = 1, stuck = true, waiting = 1 },
	}
end

-- The warning's text and border colour: the default UI's red for errors.
Frames.WARNING_COLOR = { 1, 0.25, 0.25 }
Frames.WARNING_ICON = [[Interface\Icons\INV_Misc_Bag_08]]
-- The loot window's white quality border, tinted.
Frames.WARNING_BORDER = "loottoast-itemborder-white"
-- Each kind of bag's colour in the warning's amount: general white, reagent
-- the green of uncommon items (#1eff00).
Frames.WARNING_KINDS = { general = { 1, 1, 1 }, reagent = { 30 / 255, 1, 0 } }

-- The look window's sample of the warning: two general slots and one reagent
-- slot left.
function Frames.SampleWarning()
	return { kind = "warning", warnings = {
		{ kind = "general", count = 2, text = L["Free bag slots: %d"]:format(2) },
		{ kind = "reagent", count = 1, text = L["Free reagent bag slots: %d"]:format(1) },
	} }
end

local SIDEWAYS = { left = true, right = true }

local function sideways(feed)
	return SIDEWAYS[feed.options.direction] == true
end

-- The places the warning takes: one while it shows.
local function warningPlaces(feed)
	return feed.warning and 1 or 0
end

-- How many places come before the stuck row's: the warning's, but in a fight
-- as many as when it began (above).
local function stuckSlot(feed)
	return feed.stuckAfter or warningPlaces(feed)
end

-- Out of combat the stuck row's place follows the warning.
local function settle(feed)
	if not Compat.InCombat() or feed.stuckAfter == nil then
		feed.stuckAfter = warningPlaces(feed)
	end
end

-- The warning's distance from the anchor edge: the first place, but after the
-- stuck row when it came in a fight.
local function warningOffset(feed)
	if feed.hasStuck and stuckSlot(feed) < 1 then
		return feed.step
	end
	return 0
end

-- The stuck row's distance from the anchor edge.
local function stuckOffset(feed)
	return stuckSlot(feed) * feed.step
end

-- How far the fading rows start from the anchor edge: past the warning and
-- the stuck row, if any.
local function base(feed)
	if feed.hasStuck then
		return (math.max(warningPlaces(feed), stuckSlot(feed)) + 1) * feed.step
	end
	return warningPlaces(feed) * feed.step
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

-- The stuck row's place on the screen, { left, bottom, width, height }, or
-- nil before the client has placed the feed.
local function stuckPlace(feed)
	local frame, layout = feed.frame, feed.options.layout
	local left, bottom, right, top = frame:GetLeft(), frame:GetBottom(), frame:GetRight(), frame:GetTop()
	if not (left and bottom and right and top) then
		return nil
	end
	local direction, offset = feed.options.direction, stuckOffset(feed)
	local spot = { left = left, bottom = bottom + offset, width = layout.width, height = layout.height }
	if direction == "down" then
		spot.bottom = top - layout.height - offset
	elseif direction == "right" then
		spot.left, spot.bottom = left + offset, bottom
	elseif direction == "left" then
		spot.left, spot.bottom = right - layout.width - offset, bottom
	end
	return spot
end

local function release(feed, row, rowFrame)
	feed.frameOf[row] = nil
	rowFrame.data = nil
	hideTooltip(rowFrame)
	rowFrame:Hide()
	feed.free[#feed.free + 1] = rowFrame
end

-- The shared background spans the rows on screen and the warning, from the
-- anchor edge to the farthest one, with the gap as a margin; it fades out to
-- the right, but for icons.
local function placeBackground(feed)
	local layout = feed.options.layout
	local length = sideways(feed) and layout.width or layout.height
	local far = feed.warning and (warningOffset(feed) + length) or 0
	for _, rowFrame in pairs(feed.frameOf) do
		far = math.max(far, rowFrame.offset + length)
	end
	local background = feed.frame.Background
	background:SetShown(far > 0)
	if far > 0 then
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
			background:SetSize(math.max(far, layout.width) + 2 * margin, layout.height + 2 * margin)
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
	}, FeedMixin)
	for index = 1, Frames.POOL do
		feed.rows[index] = Frames.CreateRow(frame)
		feed.rows[index].feed = feed
		feed.free[index] = feed.rows[index]
	end
	-- The warning's own row, outside the pool.
	feed.warningRow = Frames.CreateRow(frame)
	feed.warningRow.feed = feed
	frame:SetScript("OnUpdate", function()
		feed:Draw(Compat.GetTime())
	end)
	frame:Hide()
	feed:SetOptions({ direction = "up", maxRows = 8, layout = Design.Layout(Design.LARGE, Design.BASE_SIZE), opacity = 0.5 })
	return feed
end

-- The warning row, drawn by the design, in its place; hidden without warnings.
local function placeWarnings(feed)
	local rowFrame = feed.warningRow
	if not feed.warning then
		hideTooltip(rowFrame)
		rowFrame:Hide()
		return
	end
	Frames.Fill(rowFrame, feed.warning, feed.options)
	place(feed, rowFrame, warningOffset(feed))
	rowFrame:SetAlpha(1)
	rowFrame:Show()
end

-- Shows these warnings in one row at the anchor edge, each { kind, count,
-- text }: kind "general" or "reagent", count the free slots, text for the
-- tooltip. The rows move past it.
function FeedMixin:SetWarnings(warnings)
	self.warnings = warnings
	self.warning = #warnings > 0 and { kind = "warning", warnings = warnings } or nil
	settle(self)
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
	Frames.ApplyLayout(self.warningRow, layout)
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

-- Brings the use button (UseButton.lua) in line with the stuck row now: none
-- while the feed is turned off.
function FeedMixin:SyncUse()
	if not self.useButton then
		return
	end
	local views = self.disabled and {} or self.model:Visible(Compat.GetTime())
	local last = views[#views]
	local stuck = last and last.stuck and last or nil
	self.useButton:Sync(stuck and stuck.row or nil, stuck and stuckPlace(self) or nil)
end

-- Lets a stuck row go, as a left click on it does; onDismiss(row) hears of it.
function FeedMixin:Dismiss(row)
	if row and self.model:Release(row) then
		if self.onDismiss then
			self.onDismiss(row)
		end
		self:Wake()
	end
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
		-- The rows that fit after the stuck sample, then the stuck sample.
		views = {}
		local samples = #self.preview - 1
		for index = 1, math.min(samples, self.options.maxRows - 1) do
			views[index] = self.preview[index]
		end
		views[#views + 1] = self.preview[#self.preview]
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

	-- The stuck row comes last and takes the place after the warnings.
	local last = views[#views]
	local stuck = last and last.stuck and last or nil
	local after = self.stuckAfter
	settle(self)
	if (stuck ~= nil) ~= (self.hasStuck == true) or self.stuckAfter ~= after then
		self.hasStuck = stuck ~= nil
		placeWarnings(self)
	end
	-- The other views come newest first; the oldest of the live rows takes the
	-- next place, and rows pushed out past maxRows get places beyond it.
	local live = math.min(#views - (stuck and 1 or 0), self.options.maxRows - (stuck and 1 or 0))
	local slide = self.step / Frames.SLIDE_TIME * elapsed
	for index, view in ipairs(views) do
		local row = view.row
		local target = view.stuck and stuckOffset(self) or base(self) + (live - index) * self.step
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
				or rowFrame.version ~= self.version or rowFrame.stuck ~= (view.stuck == true)
				or rowFrame.waiting ~= (view.waiting or 0) or rowFrame.sticky ~= row.sticky then
				Frames.Fill(rowFrame, row, self.options, view.stuck and { waiting = view.waiting } or nil)
				rowFrame.version, rowFrame.sticky = self.version, row.sticky
			end
			self.seen[row] = self.seen[row] or now
			local fadeIn = math.min(1, (now - self.seen[row]) / Frames.FADE_IN)
			rowFrame:SetAlpha(view.alpha * (self.preview and 1 or fadeIn))
			rowFrame:Show()
		end
	end
	placeBackground(self)
	if self.useButton then
		self.useButton:Sync(stuck and stuck.row or nil, stuck and stuckPlace(self) or nil)
	end

	if #views == 0 and not hovered and #self.warnings == 0 then
		self.frame:Hide()
	end
end
