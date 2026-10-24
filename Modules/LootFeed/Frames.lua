local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- Draws the loot feed's rows from the model (techspec §7.3), in the default
-- UI's style: an icon with a quality border, the name in its quality colour
-- and the amount on the right; money with coin icons. New rows fade in, old
-- ones fade out as the model says.
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
--   feed:SetOptions({ direction = "up", maxRows = 8 })
--   feed:Wake()                              -- after model:Add
--   feed:SetPreview(true)                    -- in Edit Mode
ns.Feed = ns.Feed or {}
local Frames = {}
ns.Feed.Frames = Frames

Frames.WIDTH = 280
Frames.ROW_HEIGHT = 28
Frames.ROW_GAP = 2
-- The most rows on screen: 20 rows, and a few fading out after a push.
Frames.POOL = 24
Frames.FADE_IN = 0.2
-- Seconds a row takes to slide one place.
Frames.SLIDE_TIME = 0.15

local STEP = Frames.ROW_HEIGHT + Frames.ROW_GAP

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

-- What a row shows: { icon, label, labelColor, amount, amountColor, border }
-- (border is a colour, or nil for no quality border).
function Frames.Describe(row)
	local kind = row.kind
	if kind == "item" or kind == "currency" or kind == "skipped" then
		local color = qualityColor(row.quality)
		local amount, amountColor
		if kind == "skipped" then
			amount, amountColor = L["No room in bags"], RED
		elseif (row.amount or 1) > 1 then
			amount, amountColor = ("×%d"):format(row.amount), WHITE
		end
		return {
			icon = row.icon,
			label = row.name,
			labelColor = color,
			amount = amount,
			amountColor = amountColor,
			border = kind ~= "currency" and color or nil,
		}
	elseif kind == "money" then
		return { icon = ICONS.money, label = GetMoneyString(row.amount, true), labelColor = WHITE }
	elseif kind == "xp" then
		local amount, color = signed(row.amount)
		return { icon = ICONS.xp, label = L["Experience"], labelColor = WHITE, amount = amount, amountColor = color }
	elseif kind == "reputation" then
		-- A Russian client declines the faction name in most messages; each
		-- form gets a phrase that fits it (plans/0.1.md).
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
	if row.link and (row.kind == "item" or row.kind == "skipped") then
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

local function createRow(parent)
	local rowFrame = CreateFrame("Frame", nil, parent)
	rowFrame:SetSize(Frames.WIDTH, Frames.ROW_HEIGHT)
	rowFrame:SetMouseClickEnabled(false)
	rowFrame:SetMouseMotionEnabled(true)
	rowFrame.Background = rowFrame:CreateTexture(nil, "BACKGROUND")
	rowFrame.Background:SetAllPoints()
	rowFrame.Background:SetColorTexture(0, 0, 0, 0.35)
	rowFrame.Icon = rowFrame:CreateTexture(nil, "ARTWORK")
	rowFrame.Icon:SetSize(Frames.ROW_HEIGHT - 4, Frames.ROW_HEIGHT - 4)
	rowFrame.Icon:SetPoint("LEFT", 2, 0)
	rowFrame.IconBorder = rowFrame:CreateTexture(nil, "OVERLAY")
	rowFrame.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
	rowFrame.IconBorder:SetAllPoints(rowFrame.Icon)
	rowFrame.Amount = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	rowFrame.Amount:SetPoint("RIGHT", -6, 0)
	rowFrame.Amount:SetJustifyH("RIGHT")
	rowFrame.Label = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	rowFrame.Label:SetPoint("LEFT", rowFrame.Icon, "RIGHT", 6, 0)
	rowFrame.Label:SetPoint("RIGHT", rowFrame.Amount, "LEFT", -6, 0)
	rowFrame.Label:SetJustifyH("LEFT")
	rowFrame.Label:SetWordWrap(false)
	rowFrame:SetScript("OnEnter", showTooltip)
	rowFrame:SetScript("OnLeave", hideTooltip)
	rowFrame:Hide()
	return rowFrame
end

local function fill(rowFrame, row)
	local look = Frames.Describe(row)
	rowFrame.Icon:SetTexture(look.icon)
	rowFrame.IconBorder:SetShown(look.border ~= nil)
	if look.border then
		rowFrame.IconBorder:SetVertexColor(look.border[1], look.border[2], look.border[3])
	end
	rowFrame.Label:SetText(look.label)
	rowFrame.Label:SetTextColor(look.labelColor[1], look.labelColor[2], look.labelColor[3])
	rowFrame.Amount:SetText(look.amount or "")
	if look.amountColor then
		rowFrame.Amount:SetTextColor(look.amountColor[1], look.amountColor[2], look.amountColor[3])
	end
	rowFrame.data, rowFrame.amount, rowFrame.total = row, row.amount, row.total
end

local FeedMixin = {}
FeedMixin.__index = FeedMixin

-- Rows shown in Edit Mode, so the feed has something to place.
local PREVIEW = {
	{ row = { kind = "money", amount = 123456 }, alpha = 1 },
	{ row = { kind = "xp", amount = 1500 }, alpha = 1 },
}

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

function Frames.Create(model)
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(Frames.WIDTH, Frames.ROW_HEIGHT)
	frame:SetClampedToScreen(true)
	frame:SetMouseClickEnabled(false)
	frame:SetMouseMotionEnabled(false)
	frame.PreviewBackground = frame:CreateTexture(nil, "BACKGROUND")
	frame.PreviewBackground:SetAllPoints()
	frame.PreviewBackground:SetColorTexture(0, 0, 0, 0.3)
	frame.PreviewBackground:Hide()
	local feed = setmetatable({
		frame = frame,
		model = model,
		rows = {},
		free = {},
		-- The frame of each row on screen; a row keeps its frame while shown.
		frameOf = {},
		seen = setmetatable({}, { __mode = "k" }),
	}, FeedMixin)
	for index = 1, Frames.POOL do
		feed.rows[index] = createRow(frame)
		feed.free[index] = feed.rows[index]
	end
	frame:SetScript("OnUpdate", function()
		feed:Draw(Compat.GetTime())
	end)
	frame:Hide()
	feed:SetOptions({ direction = "up", maxRows = 8 })
	return feed
end

function FeedMixin:SetOptions(options)
	self.options = options
	self.frame:SetHeight(options.maxRows * STEP - Frames.ROW_GAP)
	for _, rowFrame in pairs(self.frameOf) do
		place(self, rowFrame, rowFrame.offset)
	end
end

-- Shows the feed after the model got a row; it hides itself when it has none.
function FeedMixin:Wake()
	self.frame:Show()
end

function FeedMixin:SetPreview(active)
	self.preview = active
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
	local views = self.preview and PREVIEW or model:Visible(now)

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
	local slide = STEP / Frames.SLIDE_TIME * elapsed
	for index, view in ipairs(views) do
		local row = view.row
		local target = (live - index) * STEP
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
			if rowFrame.data ~= row or rowFrame.amount ~= row.amount or rowFrame.total ~= row.total then
				fill(rowFrame, row)
			end
			self.seen[row] = self.seen[row] or now
			local fadeIn = math.min(1, (now - self.seen[row]) / Frames.FADE_IN)
			rowFrame:SetAlpha(view.alpha * (self.preview and 1 or fadeIn))
			rowFrame:Show()
		end
	end

	if #views == 0 and not hovered then
		self.frame:Hide()
	end
end
