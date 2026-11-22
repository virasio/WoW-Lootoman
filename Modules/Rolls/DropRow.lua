local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- A drop as a row of the loot rolls' windows (the live window and the
-- history): on the left the item (its icon, its name in its quality colour,
-- its tooltip, Shift-click to link it) and under it how the roll stands:
-- rolling, the winner in class colour with the icon of the button they won
-- with and their roll, or all passed; on the right the panel of the game's
-- roll frames drawn for that drop (Panel.lua), with its lines, marks and
-- clicks. A row is a child of its window's list, so it scrolls with it, and
-- is as tall as its panel.
--
-- In the narrow layout a roll can be rolled on in the row itself, while the
-- game's roll frames are kept away: a view marked choosable gets our buttons
-- under the item (need, greed, transmog where the roll offers it, pass; need
-- and greed greyed where the roll does not allow them, with the game's
-- reason in their tooltips), and a view with a timer (the share of the roll's
-- time left) a thin bar under them; a chosen roll keeps the timer while it
-- goes on, without the buttons. The buttons call row.onChoose(view, type),
-- the type as RollOnLoot takes it. Drawing such a row that fails shows a
-- plain one, the icon, the name and the buttons, so the roll can still be
-- rolled on; the error goes to the journal.
ns.Rolls = ns.Rolls or {}
local DropRow = {}
ns.Rolls.DropRow = DropRow

local Panel, Marks = ns.Rolls.Panel, ns.Rolls.Marks

DropRow.ITEM_WIDTH = 230
DropRow.ICON = 32
DropRow.WIDTH = DropRow.ITEM_WIDTH + Panel.GAP + Panel.WIDTH
DropRow.MIN_HEIGHT = DropRow.ICON + 16
-- The narrow row ("below"): the panel under the item, indented a little.
DropRow.INDENT = 10
DropRow.BELOW_WIDTH = DropRow.INDENT + Panel.WIDTH
DropRow.BELOW_ITEM = DropRow.ICON + 8
DropRow.BUTTON = 24
DropRow.TIMER = 6
-- RollOnLoot's types, and the game's atlas names and words for each.
DropRow.CHOICES = {
	{ type = 1, atlas = "need", word = "NEED" },
	{ type = 2, atlas = "greed", word = "GREED" },
	{ type = 4, atlas = "transmog", word = "TRANSMOGRIFICATION" },
	{ type = 0, atlas = "pass", word = "PASS" },
}
DropRow.QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
-- How long a new row of the live window stays lit.
DropRow.LIGHT = 2

-- The item's name in its quality colour, from its link.
local function nameOf(link)
	if type(link) ~= "string" then
		return "?"
	end
	local name = link:match("|h%[(.-)%]|h") or link
	local color = link:match("|c(%x%x%x%x%x%x%x%x)")
	return color and ("|c" .. color .. name .. "|r") or name
end

-- How the roll stands, under the item's name.
function DropRow.Status(view)
	if not view or not view.bound then
		return ""
	end
	if view.winner then
		local guid = view.winner.guid
		local winner = view.winner
		for _, player in ipairs(view.players) do
			if (guid and player.guid == guid) or (not guid and player.isWinner) then
				winner = player
			end
		end
		local icon = Panel.ICONS[winner.state]
		local text = Panel.ClassName(winner.name, winner.class)
		if icon then
			text = ("|A:%s:14:14|a %s"):format(icon, text)
		end
		if winner.roll then
			text = text .. " " .. tostring(winner.roll)
		end
		return text
	end
	if view.allPassed then
		return L["All passed"]
	end
	return L["Rolling…"]
end

-- A kept drop of the history as a view the panel draws: { link, bound,
-- players, winner, allPassed, drop = { key }, group, entry }.
function DropRow.EntryView(entry, group)
	local me = Compat.GetPlayerGUID()
	local view = { link = entry.link, bound = true, players = {}, allPassed = entry.allPassed, drop = { key = entry.key }, group = group,
		entry = entry }
	for index, kept in ipairs(entry.rolls) do
		local player = {}
		for key, value in pairs(kept) do
			player[key] = value
		end
		player.isWinner = entry.winner ~= nil and kept.guid == entry.winner
		player.isSelf = me ~= nil and kept.guid == me
		view.players[index] = player
		if player.isWinner then
			view.winner = { guid = kept.guid, name = kept.name, class = kept.class }
		end
	end
	return view
end

-- The marks on a view, judged in its group (the open one for a live drop),
-- with the history it belongs to (a stand-in for the made-up one).
function DropRow.Marked(view, group, history)
	if view and Marks then
		Marks.Add(view, group and { group = group, history = history } or nil)
	end
	return view
end

local function buttonTooltip(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(GameTooltip, Compat.GetGlobalString(button.choice.word) or button.choice.word)
	if button.reason then
		GameTooltip_AddNormalLine(GameTooltip, button.reason)
	end
	GameTooltip:Show()
end

-- The buttons and the timer of a narrow row, hidden.
local function addChoosing(row)
	row.buttons = {}
	for index, choice in ipairs(DropRow.CHOICES) do
		local button = CreateFrame("Button", nil, row.frame)
		button:SetSize(DropRow.BUTTON, DropRow.BUTTON)
		button:SetNormalAtlas("lootroll-toast-icon-" .. choice.atlas .. "-up")
		button:SetPushedAtlas("lootroll-toast-icon-" .. choice.atlas .. "-down")
		button:SetHighlightAtlas("lootroll-toast-icon-" .. choice.atlas .. "-highlight", "ADD")
		button:SetMotionScriptsWhileDisabled(true)
		button.choice = choice
		button:SetScript("OnClick", function(owner)
			if row.view and row.onChoose and not row.guarded then
				row.onChoose(row.view, owner.choice.type)
			end
		end)
		button:SetScript("OnEnter", buttonTooltip)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		button:Hide()
		row.buttons[index] = button
	end
	row.timer = CreateFrame("StatusBar", nil, row.frame)
	row.timer:SetSize(DropRow.BELOW_WIDTH - DropRow.INDENT, DropRow.TIMER)
	row.timer:SetMinMaxValues(0, 1)
	row.timer:SetStatusBarTexture(ns.RollLookalike.TIMER)
	row.timer:SetStatusBarColor(1, 0.82, 0)
	row.timer.background = row.timer:CreateTexture(nil, "BACKGROUND")
	row.timer.background:SetAllPoints(row.timer)
	row.timer.background:SetColorTexture(0, 0, 0, 0.6)
	row.timer:Hide()
end

-- The game's reason a choice is not allowed, from its strings.
local function reasonText(reason)
	if not reason or reason == 0 then
		return nil
	end
	return Compat.GetGlobalString("LOOT_ROLL_INELIGIBLE_REASON" .. reason)
end

-- Lays the buttons out under the item, from y down; the next y.
local function placeButtons(row, view, y)
	local item = view.item or {}
	local x = DropRow.INDENT
	for _, button in ipairs(row.buttons) do
		local choice = button.choice
		local shown = choice.type ~= 4 or item.canTransmog == true
		button:SetShown(shown)
		if shown then
			local allowed, reason = true, nil
			if choice.type == 1 then
				allowed, reason = item.canNeed ~= false, reasonText(item.reasonNeed)
			elseif choice.type == 2 then
				allowed, reason = item.canGreed ~= false, reasonText(item.reasonGreed)
			end
			button:SetEnabled(allowed)
			button.reason = not allowed and reason or nil
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x, -y)
			x = x + DropRow.BUTTON + 4
		end
	end
	return y + DropRow.BUTTON + 2
end

-- Shows a timer's share of the roll's time left.
function DropRow.SetTimer(row, share)
	if row.timer and row.timer:IsShown() and share then
		row.timer:SetValue(math.max(0, math.min(1, share)))
	end
end

-- A row, hidden, in a window's list: the panel at the item's right, or,
-- layout "below", under it (a window half as wide).
function DropRow.New(parent, layout)
	local row = { layout = layout or "right" }
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(row.layout == "below" and DropRow.BELOW_WIDTH or DropRow.WIDTH, DropRow.MIN_HEIGHT)
	frame:Hide()
	row.frame = frame
	-- A light over the row for a moment, when it is new.
	row.light = frame:CreateTexture(nil, "BACKGROUND")
	row.light:SetAllPoints(frame)
	row.light:SetColorTexture(1, 0.82, 0, 0.15)
	row.light:Hide()
	local item = CreateFrame("Button", nil, frame)
	item:SetSize(DropRow.ITEM_WIDTH, DropRow.MIN_HEIGHT)
	item:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	item:RegisterForClicks("LeftButtonUp")
	item.icon = item:CreateTexture(nil, "ARTWORK")
	item.icon:SetSize(DropRow.ICON, DropRow.ICON)
	item.icon:SetPoint("TOPLEFT", item, "TOPLEFT", 4, -4)
	item.name = item:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	item.name:SetPoint("TOPLEFT", item.icon, "TOPRIGHT", 6, 0)
	item.name:SetPoint("RIGHT", item, "RIGHT", -4, 0)
	item.name:SetJustifyH("LEFT")
	item.name:SetWordWrap(false)
	item.status = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	item.status:SetPoint("TOPLEFT", item.name, "BOTTOMLEFT", 0, -3)
	item.status:SetPoint("RIGHT", item, "RIGHT", -4, 0)
	item.status:SetJustifyH("LEFT")
	item.status:SetWordWrap(false)
	-- A note under it, such as the drop's time and place in the history.
	item.note = item:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	item.note:SetPoint("TOPLEFT", item.status, "BOTTOMLEFT", 0, -3)
	item.note:SetPoint("RIGHT", item, "RIGHT", -4, 0)
	item.note:SetJustifyH("LEFT")
	item.note:SetWordWrap(false)
	item:SetScript("OnEnter", function(owner)
		local link = row.view and row.view.link
		if link then
			GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(link)
			GameTooltip:Show()
		end
	end)
	item:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	item:SetScript("OnClick", function()
		local link = row.view and row.view.link
		if link then
			Compat.ModifiedItemClick(link)
		end
	end)
	row.item = item
	row.panel = Panel.New(frame)
	if row.layout == "below" then
		addChoosing(row)
	end
	return row
end

-- A plain row to roll on, when drawing the full one failed: the icon, the
-- name and the buttons.
function DropRow.DrawPlain(row, view)
	Panel.Hide(row.panel)
	row.item.icon:SetTexture(DropRow.QUESTION)
	row.item.name:SetText(nameOf(view and view.link))
	row.item.status:SetText("")
	row.item.note:SetText("")
	if row.timer then
		row.timer:Hide()
	end
	local height = DropRow.BELOW_ITEM + 2
	if row.buttons and view then
		height = placeButtons(row, view, height)
	end
	row.frame:SetHeight(height)
	row.frame:Show()
	return height
end

local draw

-- Draws a view (marked already) on a row, with a note under the item if
-- given; returns the row's height. A row to roll on that fails to draw is
-- drawn plain.
function DropRow.Draw(row, view, note)
	if view and view.choosable then
		local ok, height = xpcall(function()
			return draw(row, view, note)
		end, Compat.ReportError)
		if ok then
			return height
		end
		return DropRow.DrawPlain(row, view)
	end
	return draw(row, view, note)
end

draw = function(row, view, note)
	row.view = view
	local link = view and view.link
	local icon = link and Compat.GetItemLook(link)
	local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)"))
	if itemID and not icon then
		Compat.RequestItem(itemID)
		if ns.Rolls.Module then
			ns.Rolls.Module.WaitForItem()
		end
	end
	row.item.icon:SetTexture(icon or DropRow.QUESTION)
	row.item.name:SetText(nameOf(link))
	row.item.status:SetText(DropRow.Status(view))
	row.item.note:SetText(note or "")
	Panel.Show(row.panel, row.item, view, "right")
	local height
	if row.layout == "below" then
		row.item:SetSize(DropRow.BELOW_WIDTH, DropRow.BELOW_ITEM)
		local y = DropRow.BELOW_ITEM + 2
		local choosable = view and view.choosable == true
		for _, button in ipairs(row.buttons) do
			button:SetShown(false)
		end
		if choosable then
			y = placeButtons(row, view, y)
		end
		row.timer:SetShown(view ~= nil and view.timer ~= nil)
		if view and view.timer then
			row.timer:ClearAllPoints()
			row.timer:SetPoint("TOPLEFT", row.frame, "TOPLEFT", DropRow.INDENT, -y)
			DropRow.SetTimer(row, view.timer)
			y = y + DropRow.TIMER + 2
		end
		row.panel.frame:ClearAllPoints()
		row.panel.frame:SetPoint("TOPLEFT", row.frame, "TOPLEFT", DropRow.INDENT, -y)
		height = y + (row.panel.frame:GetHeight() or 0)
	else
		height = math.max(DropRow.MIN_HEIGHT, row.panel.frame:GetHeight() or 0)
		row.item:SetHeight(height)
	end
	row.frame:SetHeight(height)
	row.frame:Show()
	return height
end

-- Lights a row for a moment.
function DropRow.Light(row)
	row.light:Show()
	row.lit = (row.lit or 0) + 1
	local mine = row.lit
	Compat.After(DropRow.LIGHT, function()
		if row.lit == mine then
			row.light:Hide()
		end
	end)
end

function DropRow.Hide(row)
	row.frame:Hide()
	row.view = nil
	Panel.Hide(row.panel)
end
