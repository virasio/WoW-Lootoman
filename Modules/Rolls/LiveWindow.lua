local _, ns = ...
local Compat, L, Storage = ns.Compat, ns.L, ns.Storage

-- The live window, Loot Rolls, where the game does not open a loot history
-- window of its own: retail opens its Loot Rolls window after the player's
-- choice, and then this one stays closed; WoW Forever has the game's frame
-- but never shows it. Once the player has chosen on a roll, with its option
-- on, the window waits a moment (WAIT) to see whether the game opens its own,
-- and if not opens with that roll and the group's other rolls still going,
-- and takes in every drop that comes while it is open, newest
-- at the top, each a row with its item, its outcome and its panel
-- (DropRow.lua). Closed, it forgets them, and the next choice opens it with
-- that roll alone. A drop is drawn from the model while the game has it and
-- from the open group's history after that, so the rows stay as they were
-- when the game clears its loot history. Built as the module starts, with
-- its first rows; it opens in a fight too (its frames are not protected).
ns.Rolls = ns.Rolls or {}
local LiveWindow = {}
ns.Rolls.LiveWindow = LiveWindow

local DropRow, History, Model = ns.Rolls.DropRow, ns.Rolls.History, ns.Rolls.Model
local Panel = ns.Rolls.Panel

LiveWindow.NAME = "LootomanLootRolls"
LiveWindow.PAD = 12
LiveWindow.TOP = 32
LiveWindow.GAP = 4
LiveWindow.WIDTH = DropRow.WIDTH + 2 * LiveWindow.PAD + 24
-- As tall as four rows of a group of five.
LiveWindow.HEIGHT = LiveWindow.TOP + 4 * (2 * Panel.PAD + Panel.GROUP * Panel.LINE + LiveWindow.GAP) + LiveWindow.PAD
LiveWindow.FIRST_ROWS = 4
-- How long it waits after the player's choice for the game's own window.
LiveWindow.WAIT = 0.5

local frame
-- What the window shows since it opened, newest first: { rollID, key, group,
-- last (the view drawn last) }; the drops known when it opened.
local entries, known = {}, {}

local function newRow()
	local row = DropRow.New(frame.content)
	-- Exceptions on its lines, as on the panels beside the game's frames.
	row.panel.onRightClick = function(...)
		if ns.Rolls.Module.OnRightClick then
			ns.Rolls.Module.OnRightClick(...)
		end
	end
	frame.rows[#frame.rows + 1] = row
	return row
end

-- Builds the window, hidden, with its first rows.
function LiveWindow.Build()
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", LiveWindow.NAME, UIParent, "DefaultPanelFlatTemplate")
	frame:Hide()
	frame:SetSize(LiveWindow.WIDTH, LiveWindow.HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(window)
		window:StopMovingOrSizing()
		window.placed = true
	end)
	frame:SetTitle(Compat.GetGlobalString("LOOT_ROLLS") or L["Loot Rolls"])
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	table.insert(UISpecialFrames, LiveWindow.NAME)
	frame.scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	frame.scroll:SetPoint("TOPLEFT", LiveWindow.PAD, -LiveWindow.TOP)
	frame.scroll:SetPoint("BOTTOMRIGHT", -LiveWindow.PAD - 24, LiveWindow.PAD)
	frame.content = CreateFrame("Frame", nil, frame.scroll)
	frame.content:SetSize(DropRow.WIDTH, 1)
	frame.scroll:SetScrollChild(frame.content)
	frame.rows = {}
	for _ = 1, LiveWindow.FIRST_ROWS do
		newRow()
	end
	-- Closed, it forgets what it showed.
	frame:SetScript("OnHide", function()
		entries, known = {}, {}
		for _, row in ipairs(frame.rows) do
			DropRow.Hide(row)
		end
	end)
	return frame
end

-- The key of the drop an entry shows now: its roll's drop while the roll is open.
local function keyOf(entry)
	local roll = entry.rollID and Model.Roll(entry.rollID)
	if roll and roll.drop then
		entry.key = roll.drop
	end
	return entry.key
end

-- An entry's view, marked: its own (a made-up one), from its roll, from the
-- model's drop, from the history, or as it was drawn last.
local function viewOf(entry)
	if entry.view then
		return entry.view
	end
	local view
	local key = keyOf(entry)
	local roll = entry.rollID and Model.Roll(entry.rollID)
	-- A roll whose drop went with the loot history is drawn from the history.
	if roll and (roll.drop or not key) then
		view = ns.Rolls.Module.View(entry.rollID)
	end
	if not view and key and Model.Drop(key) then
		view = DropRow.Marked(Model.DropView(key))
	end
	if not view and key and entry.group then
		local kept = History.Find(entry.group, key)
		if kept then
			view = DropRow.Marked(DropRow.EntryView(kept, entry.group), entry.group)
		end
	end
	entry.last = view or entry.last
	return entry.last
end

-- Draws the entries, newest first, each as tall as its panel.
function LiveWindow.Redraw()
	if not frame or not frame:IsShown() then
		return
	end
	local y = 0
	local shown = 0
	for _, entry in ipairs(entries) do
		local view = viewOf(entry)
		if view then
			shown = shown + 1
			local row = frame.rows[shown] or newRow()
			row.frame:ClearAllPoints()
			row.frame:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -y)
			y = y + DropRow.Draw(row, view) + LiveWindow.GAP
			if entry.light then
				entry.light = nil
				DropRow.Light(row)
			end
		end
	end
	for index = shown + 1, #frame.rows do
		DropRow.Hide(frame.rows[index])
	end
	frame.content:SetHeight(math.max(1, y))
	frame.count = shown
end

-- Whether an entry shows this roll or this drop already.
local function find(rollID, key)
	for _, entry in ipairs(entries) do
		if (rollID and entry.rollID == rollID) or (key and keyOf(entry) == key) then
			return entry
		end
	end
	return nil
end

-- A row at the top; lit for a moment unless quiet (the rolls already going
-- when the window opens: only the one that brought it is new).
local function add(entry, quiet)
	entry.group = History.Open()
	entry.light = not quiet or nil
	table.insert(entries, 1, entry)
end

-- Where the window first opens: on the screen, right of where the game
-- stacks its roll frames (half of their width) and their panels, near the
-- bottom. Not on the game's container of the roll frames: hidden, the game
-- lays it out nowhere, and a window placed on it would not show.
LiveWindow.LEFT = 140 + Panel.GAP + Panel.WIDTH + 16
LiveWindow.BOTTOM = 200

local function place()
	if frame.placed then
		return
	end
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", LiveWindow.LEFT, LiveWindow.BOTTOM)
end

-- Opens the window with a roll, and with the other rolls still going; open
-- already, it takes the roll in.
local function open(rollID)
	if not frame:IsShown() then
		entries, known = {}, {}
		local mine = Model.Roll(rollID) and Model.Roll(rollID).drop
		for _, drop in ipairs(Model.Drops()) do
			if drop.key ~= mine and Model.IsOpen(drop) then
				add({ key = drop.key }, true)
			end
			known[drop.key] = true
		end
		add({ rollID = rollID })
		place()
		frame:Show()
	elseif not find(rollID, nil) then
		add({ rollID = rollID })
	end
	LiveWindow.Redraw()
end

-- The player chose on a roll: open, the window takes it in at once; closed,
-- it opens a moment later, unless the game has opened its own meanwhile.
function LiveWindow.Chose(rollID)
	if not frame or not Storage:Get("Rolls", "liveWindow") then
		return
	end
	if frame:IsShown() then
		open(rollID)
		return
	end
	Compat.After(LiveWindow.WAIT, function()
		if frame and ns.Rolls.Module.active and not Compat.IsGameLootHistoryShown() then
			open(rollID)
		end
	end)
end

-- The model's news: a drop new since the window opened joins it; any
-- change redraws it.
function LiveWindow.OnModel(kind, value)
	if not frame or not frame:IsShown() then
		return
	end
	if kind == "drop" and value and value.key and not known[value.key] then
		known[value.key] = true
		if not find(nil, value.key) then
			add({ key = value.key })
		end
	end
	LiveWindow.Redraw()
end

-- Shows views of made-up drops (the repository's demo), the first at the
-- top; false where the window does not exist.
function LiveWindow.ShowViews(views)
	if not frame then
		return false
	end
	entries, known = {}, {}
	for index = #views, 1, -1 do
		add({ view = views[index] }, index > 1)
	end
	place()
	frame:Show()
	LiveWindow.Redraw()
	return true
end

function LiveWindow.Hide()
	if frame then
		frame:Hide()
	end
end

-- The window, for tests.
function LiveWindow.Frame()
	return frame
end
