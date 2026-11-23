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
-- Its options give its background's opacity, and its border or none
-- (ApplyLook).
--
-- With the game's roll frames kept away (Hide the Game's Roll Frames), the
-- window is where the player rolls: it opens as a roll starts, whatever its
-- option says, and the rolls still waiting for the player's choice stand on
-- top, newest first, each with our buttons and the roll's timer; under a thin
-- line the rest, as always, newest first, the chosen ones keeping their
-- timer while the roll goes on. A roll waits until the game ends it for the
-- player (CANCEL_LOOT_ROLL): the choice is final only then, so a need on an
-- item that binds stays on top while the game asks to confirm it, and comes
-- back to be chosen again if the player cancels. A row that has just moved
-- (another roll in its place, or pushed by more than its item's height)
-- takes no click for a moment (GUARD), so a click meant for the row that
-- stood there does not land on another roll. Closing the window while a roll
-- waits asks first: untouched, the roll ends as a pass; Escape closes it at
-- once, so it comes back and asks.
ns.Rolls = ns.Rolls or {}
local LiveWindow = {}
ns.Rolls.LiveWindow = LiveWindow

local DropRow, History, Model = ns.Rolls.DropRow, ns.Rolls.History, ns.Rolls.Model
local Panel = ns.Rolls.Panel

LiveWindow.NAME = "LootomanLootRolls"
LiveWindow.PAD = 12
LiveWindow.TOP = 32
LiveWindow.GAP = 4
-- Rows with the choices under each item: half as wide as the history's.
LiveWindow.WIDTH = DropRow.BELOW_WIDTH + 2 * LiveWindow.PAD + 24
-- As tall as three rows of a group of five.
LiveWindow.HEIGHT = LiveWindow.TOP + 3 * (DropRow.BELOW_ITEM + 2 + 2 * Panel.PAD + Panel.GROUP * Panel.LINE + LiveWindow.GAP) + LiveWindow.PAD
LiveWindow.FIRST_ROWS = 4
-- How long it waits after the player's choice for the game's own window.
LiveWindow.WAIT = 0.5
-- How long a moved row takes no click; how often the timers move; the room
-- of the line between the rolls to choose on and the rest.
LiveWindow.GUARD = 0.5
-- How far a row must move for a pointer on its buttons to reach another
-- row's: its item's height at least. A row the one above pushed a line or
-- two (its panel filling) keeps taking clicks.
LiveWindow.MOVE = DropRow.BELOW_ITEM
LiveWindow.TICK = 0.1
LiveWindow.LINE = 9

local frame
-- What the window shows since it opened, newest first: { rollID, key, group,
-- last (the view drawn last), started and total (its roll's, for the timer
-- once the roll is the player's no more) }; the drops known when it opened.
local entries, known = {}, {}
-- Hidden on purpose (closed after asking, or the module going off), not by
-- Escape.
local closing = false
local ticking = false

-- Whether the player rolls here: the game's roll frames are kept away.
local function rolling()
	local module = ns.Rolls.Module
	return module ~= nil and module.GameFramesAway ~= nil and module.GameFramesAway() == true
end

-- Whether a roll still waits for the player's choice: the game has not ended
-- it for him.
local function waits(rollID)
	return rollID ~= nil and Model.Roll(rollID) ~= nil
end

-- Whether any roll waits for the player, with the game's frames kept away
-- (or a made-up one of the demo's, in the window).
function LiveWindow.Waiting()
	for _, entry in ipairs(entries) do
		if entry.view and entry.view.choosable then
			return true
		end
	end
	if not rolling() then
		return false
	end
	for _, roll in ipairs(Model.Rolls()) do
		if waits(roll.rollID) then
			return true
		end
	end
	return false
end

-- Where the window opens: where the player last put it, kept for the
-- character across sessions (LootomanCharDB.sections.lootRolls: point,
-- relativePoint, x, y), else at the screen's left, vertically centred, about
-- as far from the edge as the game's action bars and bags stand.
-- Always on the screen itself: the game's container of the roll frames,
-- hidden while no roll is open, is laid out nowhere then, and a window placed
-- on it would not show.
LiveWindow.SECTION = "lootRolls"
LiveWindow.DEFAULT = { point = "LEFT", relativePoint = "LEFT", x = 40, y = 0 }

local function saved()
	local kept = Storage:GetCharacterSection(LiveWindow.SECTION)
	if type(kept.point) == "string" and type(kept.relativePoint) == "string" and type(kept.x) == "number" and type(kept.y) == "number" then
		return kept
	end
	return LiveWindow.DEFAULT
end

local function place()
	local where = saved()
	frame:ClearAllPoints()
	frame:SetPoint(where.point, UIParent, where.relativePoint, where.x, where.y)
end

-- Keeps where the player put the window.
local function keep(window)
	local point, _, relativePoint, x, y = window:GetPoint(1)
	if point then
		local kept = Storage:GetCharacterSection(LiveWindow.SECTION)
		kept.point, kept.relativePoint, kept.x, kept.y = point, relativePoint, x, y
	end
end

-- A click on a row's button: a roll still waiting is rolled on; a made-up
-- row (the demo) does what its view says.
local function choose(view, rollType)
	if type(view.onChoose) == "function" then
		view.onChoose(rollType)
	elseif waits(view.rollID) then
		Compat.RollOnLoot(view.rollID, rollType)
	end
end

local function newRow()
	local row = DropRow.New(frame.content, "below")
	row.onChoose = choose
	-- Exceptions on its lines, as on the panels beside the game's frames.
	row.panel.onRightClick = function(...)
		if ns.Rolls.Module.OnRightClick then
			ns.Rolls.Module.OnRightClick(...)
		end
	end
	frame.rows[#frame.rows + 1] = row
	return row
end

-- Where the template puts the background: under the title bar, inside the border.
LiveWindow.BG_INSET = { left = 6, top = 20, right = 2, bottom = 2 }

-- The window's look, as its options say: its background's opacity, and its
-- border, the game's frame with the title bar; without it, the background
-- reaches to the window's edges, under the title and the close button.
function LiveWindow.ApplyLook()
	if not frame then
		return
	end
	local bordered = Storage:Get("Rolls", "windowBorder") ~= false
	frame.NineSlice:SetShown(bordered)
	local inset = LiveWindow.BG_INSET
	frame.Bg:ClearAllPoints()
	if bordered then
		frame.Bg:SetPoint("TOPLEFT", inset.left, -inset.top)
		frame.Bg:SetPoint("BOTTOMRIGHT", -inset.right, inset.bottom)
	else
		frame.Bg:SetAllPoints(frame)
	end
	frame.Bg:SetAlpha(math.max(0, math.min(100, tonumber(Storage:Get("Rolls", "windowOpacity")) or 100)) / 100)
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
		keep(window)
	end)
	frame:SetTitle(Compat.GetGlobalString("LOOT_ROLLS") or L["Loot Rolls"])
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		LiveWindow.Close()
	end)
	frame.close = close
	table.insert(UISpecialFrames, LiveWindow.NAME)
	frame.scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	frame.scroll:SetPoint("TOPLEFT", LiveWindow.PAD, -LiveWindow.TOP)
	frame.scroll:SetPoint("BOTTOMRIGHT", -LiveWindow.PAD - 24, LiveWindow.PAD)
	frame.content = CreateFrame("Frame", nil, frame.scroll)
	frame.content:SetSize(DropRow.BELOW_WIDTH, 1)
	frame.scroll:SetScrollChild(frame.content)
	-- Between the rolls to choose on and the rest.
	frame.line = frame.content:CreateTexture(nil, "ARTWORK")
	frame.line:SetSize(DropRow.BELOW_WIDTH, 1)
	frame.line:SetColorTexture(1, 0.82, 0, 0.35)
	frame.line:Hide()
	frame.rows = {}
	for _ = 1, LiveWindow.FIRST_ROWS do
		newRow()
	end
	LiveWindow.ApplyLook()
	-- Closed, it forgets what it showed. Closed by Escape while a roll
	-- waits, it comes back and asks; hidden with the whole interface, it
	-- keeps everything.
	frame:SetScript("OnHide", function()
		if frame:IsShown() then
			return
		end
		if not closing and LiveWindow.Waiting() then
			Compat.After(0, function()
				if frame and not frame:IsShown() and LiveWindow.Waiting() then
					frame:Show()
					LiveWindow.Redraw()
					LiveWindow.Close()
				end
			end)
			return
		end
		entries, known = {}, {}
		for _, row in ipairs(frame.rows) do
			DropRow.Hide(row)
		end
	end)
	return frame
end

-- The key of the drop an entry shows now: its roll's drop, also after the
-- game ended the roll for the player (as soon as he chose).
local function keyOf(entry)
	local roll = entry.rollID and Model.Record(entry.rollID)
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
	local roll = entry.rollID and Model.Record(entry.rollID)
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

-- Whether an entry stands on top: a roll still waiting for the player's
-- choice, with the game's frames kept away (or a made-up one to choose on).
local function onTop(entry)
	if entry.view then
		return entry.view.choosable == true
	end
	return rolling() and waits(entry.rollID)
end

-- The share of an entry's roll time left (1 to 0) while its roll goes on, or
-- nil: from the game while the roll is the player's, then from its start
-- and length, while its drop is still rolled on (or not known yet).
local function timeShare(entry)
	if entry.view then
		return type(entry.view.timeShare) == "function" and entry.view.timeShare() or nil
	end
	if waits(entry.rollID) then
		return Model.TimeShare(entry.rollID)
	end
	if not entry.total or entry.total <= 0 then
		return nil
	end
	local drop = entry.key and Model.Drop(entry.key)
	if drop and not Model.IsOpen(drop) then
		return nil
	end
	local share = 1 - (Compat.GetTime() - entry.started) / (entry.total / 1000)
	return share > 0 and share or nil
end

-- A row that moved takes no click for a moment.
local function guard(row)
	row.guarded = true
	row.guard = (row.guard or 0) + 1
	local mine = row.guard
	Compat.After(LiveWindow.GUARD, function()
		if row.guard == mine then
			row.guarded = nil
		end
	end)
end

-- Moves the timers while any runs, without drawing the rows again.
local function tick()
	if ticking then
		return
	end
	ticking = true
	Compat.After(LiveWindow.TICK, function()
		ticking = false
		if not frame or not frame:IsShown() then
			return
		end
		local running = false
		for _, row in ipairs(frame.rows) do
			if row.entry and row.frame:IsShown() and row.timer and row.timer:IsShown() then
				local share = timeShare(row.entry) or 0
				DropRow.SetTimer(row, share)
				running = running or share > 0
			end
		end
		if running then
			tick()
		end
	end)
end

-- Draws the entries, newest first, each as tall as its panel: with the
-- game's frames kept away, the rolls waiting for the player's choice first,
-- then a line, then the rest.
function LiveWindow.Redraw()
	if not frame or not frame:IsShown() then
		return
	end
	local order, top = {}, 0
	for _, entry in ipairs(entries) do
		if onTop(entry) then
			top = top + 1
			table.insert(order, top, entry)
		else
			order[#order + 1] = entry
		end
	end
	local choosing = rolling()
	local y, shown, anyTimer = 0, 0, false
	local lined = false
	frame.line:Hide()
	for index, entry in ipairs(order) do
		local view = viewOf(entry)
		if view then
			if index > top and shown > 0 and not lined then
				lined = true
				frame.line:ClearAllPoints()
				frame.line:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -(y + math.floor(LiveWindow.LINE / 2) - LiveWindow.GAP))
				frame.line:Show()
				y = y + LiveWindow.LINE - LiveWindow.GAP
			end
			lined = lined or index > top
			if not entry.view then
				view.choosable = (index <= top) or nil
				view.timer = choosing and timeShare(entry) or nil
			elseif type(view.timeShare) == "function" then
				view.timer = view.timeShare()
			end
			anyTimer = anyTimer or view.timer ~= nil
			shown = shown + 1
			local row = frame.rows[shown] or newRow()
			if row.entry ~= entry or math.abs((row.y or y) - y) >= LiveWindow.MOVE then
				guard(row)
			end
			row.entry, row.y = entry, y
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
		local row = frame.rows[index]
		row.entry, row.y = nil, nil
		DropRow.Hide(row)
	end
	frame.content:SetHeight(math.max(1, y))
	frame.count = shown
	if anyTimer then
		tick()
	end
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

-- Keeps an entry's roll's start and length, for its timer once the roll is
-- the player's no more.
local function timed(entry)
	local roll = entry.rollID and Model.Record(entry.rollID)
	if roll and not entry.total then
		entry.started, entry.total = roll.started, roll.total
	end
	return entry
end

-- A row at the top; lit for a moment unless quiet (the rolls already going
-- when the window opens: only the one that brought it is new).
local function add(entry, quiet)
	entry.group = History.Open()
	entry.light = not quiet or nil
	table.insert(entries, 1, timed(entry))
end


-- Opens the window with a roll, and with the other rolls still going (with
-- the game's frames kept away, every roll still waiting for the player
-- too); open already, it takes the roll in.
local function open(rollID)
	local roll = Model.Record(rollID)
	if not frame:IsShown() then
		entries, known = {}, {}
		local taken = {}
		local others = {}
		if rolling() then
			for _, other in ipairs(Model.Rolls()) do
				if other.rollID ~= rollID then
					others[#others + 1] = other
					if other.drop then
						taken[other.drop] = true
					end
				end
			end
		end
		if roll and roll.drop then
			taken[roll.drop] = true
		end
		for _, drop in ipairs(Model.Drops()) do
			if not taken[drop.key] and Model.IsOpen(drop) then
				add({ key = drop.key }, true)
			end
			known[drop.key] = true
		end
		for _, other in ipairs(others) do
			add({ rollID = other.rollID }, true)
		end
		add({ rollID = rollID })
		place()
		frame:Show()
	else
		local entry = find(rollID, roll and roll.drop)
		if not entry then
			add({ rollID = rollID })
		elseif not entry.rollID and not entry.view then
			-- The drop came first; now it is a roll of the player's.
			entry.rollID = rollID
			timed(entry)
		end
	end
	LiveWindow.Redraw()
end

-- A roll started: with the game's frames kept away, the window opens with it
-- (or takes it in), whatever its option says.
function LiveWindow.Started(rollID)
	if frame and rolling() and Model.Roll(rollID) then
		open(rollID)
	end
end

-- The player chose on a roll: open, the window takes it in at once; closed,
-- it opens a moment later, unless the game has opened its own meanwhile.
function LiveWindow.Chose(rollID)
	if not frame then
		return
	end
	if frame:IsShown() then
		open(rollID)
		return
	end
	if not Storage:Get("Rolls", "liveWindow") then
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

-- Takes in a made-up drop's view (the repository's demo), as a roll's drop
-- comes: closed, the window opens with it and forgets what it showed; open,
-- the view goes on top, unless it is there already. quiet: not lit. False
-- where the window does not exist.
function LiveWindow.AddView(view, quiet)
	if not frame then
		return false
	end
	if not frame:IsShown() then
		entries, known = {}, {}
		place()
		frame:Show()
	end
	local there = false
	for _, entry in ipairs(entries) do
		there = there or entry.view == view
	end
	if not there then
		add({ view = view }, quiet)
	end
	LiveWindow.Redraw()
	return true
end

-- Whether the window shows a made-up drop's view now.
function LiveWindow.Shows(view)
	if not frame or not frame:IsShown() then
		return false
	end
	for _, entry in ipairs(entries) do
		if entry.view == view then
			return true
		end
	end
	return false
end

-- Closes the window; while a roll waits for the player's choice, after
-- asking.
function LiveWindow.Close()
	if not frame then
		return
	end
	if not LiveWindow.Waiting() then
		frame:Hide()
		return
	end
	ns.NameMenu.Confirm(L["Rolls are waiting for your choice; untouched, they end as a pass. Close the window?"], nil, L["Close"],
		function()
			LiveWindow.Hide()
		end)
end

-- Hides the window without asking.
function LiveWindow.Hide()
	if frame then
		closing = true
		frame:Hide()
		closing = false
	end
end

-- The window, for tests.
function LiveWindow.Frame()
	return frame
end
