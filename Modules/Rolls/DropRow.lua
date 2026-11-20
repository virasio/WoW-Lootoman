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
ns.Rolls = ns.Rolls or {}
local DropRow = {}
ns.Rolls.DropRow = DropRow

local Panel, Marks = ns.Rolls.Panel, ns.Rolls.Marks

DropRow.ITEM_WIDTH = 230
DropRow.ICON = 32
DropRow.WIDTH = DropRow.ITEM_WIDTH + Panel.GAP + Panel.WIDTH
DropRow.MIN_HEIGHT = DropRow.ICON + 16
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

-- A row, hidden, in a window's list.
function DropRow.New(parent)
	local row = {}
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(DropRow.WIDTH, DropRow.MIN_HEIGHT)
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
	return row
end

-- Draws a view (marked already) on a row, with a note under the item if
-- given; returns the row's height.
function DropRow.Draw(row, view, note)
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
	local height = math.max(DropRow.MIN_HEIGHT, row.panel.frame:GetHeight() or 0)
	row.item:SetHeight(height)
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
