local _, ns = ...

-- The loot feed's rows, without frames. Pure logic: every call
-- that depends on time takes the current time, so tests need no clock.
--
-- A row shows an entry from Sources for `duration` seconds, then fades out over
-- `fade` seconds and is removed. An entry that repeats one still on screen
-- (the same item, currency, faction, or money or experience) merges into it:
-- the amounts add up, the timer restarts and the row moves to the top.
--
-- Items below the minimum quality and turned-off kinds are dropped.
--
-- When there are more than maxRows rows, the oldest ones fade out at once,
-- over at most PUSH_FADE seconds. While the pointer is over the feed
-- (SetHover), every timer stops.
--
-- A sticky row (SetSticky: an item the character can use) does not fade: when
-- its time is up, or a full feed would push it out, it sticks. The row stuck
-- first takes the first slot, at the anchor edge, and stays there; the others
-- stuck after it wait under it, and the rest of the rows go on fading in the
-- slots after it. Release lets a row go at once, and the next stuck row
-- takes the slot; Unstick lets it fade out instead, and it may stick again
-- before it is gone. Looting a stuck item again adds to its row in place.
--
--   local model = Model.New({ maxRows = 8, duration = 6, fade = 1, minQuality = 0,
--       kinds = { item = true, currency = true, money = true, reputation = true, xp = false } }, now)
--   model:Add(entry, now); model:Update(now)
--   for _, view in ipairs(model:Visible(now)) do -- view.row, view.alpha
--   model:SetSticky(row, "quest", now); model:Release(row)
ns.Feed = ns.Feed or {}
local Model = {}
ns.Feed.Model = Model

Model.PUSH_FADE = 0.5

local ModelMixin = {}
ModelMixin.__index = ModelMixin

function Model.New(options, now)
	local model = setmetatable({ rows = {}, stuckCount = 0 }, ModelMixin)
	model:SetOptions(options, now or 0)
	return model
end

-- What makes two entries one row.
local function keyOf(entry)
	local kind = entry.kind
	if kind == "money" or kind == "xp" then
		return kind
	elseif kind == "reputation" then
		return "reputation:" .. tostring(entry.name)
	end
	return kind .. ":" .. tostring(entry.id or entry.link or entry.name)
end

-- Whether an entry is shown; force: below the minimum quality too (an item
-- the character can use).
local function shown(model, entry, force)
	if not model.options.kinds[entry.kind] then
		return false
	end
	return force or entry.kind ~= "item" or entry.quality == nil or entry.quality >= model.options.minQuality
end

-- While hovered, time stands still at the moment the hover began.
local function clock(model, now)
	return model.pausedAt or now
end

local function restart(model, row, now)
	row.fadeStart = now + model.options.duration
	row.fadeEnd = row.fadeStart + model.options.fade
end

local function stick(model, row)
	row.stuck = true
	model.stuckCount = model.stuckCount + 1
	-- In the order they stuck, so the first one keeps the slot.
	row.stuckOrder = model.stuckCount
	row.fadeStart, row.fadeEnd = math.huge, math.huge
end

-- Sticky rows whose time is up stick, the oldest first (rows are newest first).
local function stickDue(model, now)
	for index = #model.rows, 1, -1 do
		local row = model.rows[index]
		if row.sticky and not row.stuck and now >= row.fadeStart then
			stick(model, row)
		end
	end
end

local function anyStuck(model)
	for _, row in ipairs(model.rows) do
		if row.stuck then
			return true
		end
	end
	return false
end

-- How many rows fit after the stuck one, if any.
local function room(model)
	return model.options.maxRows - (anyStuck(model) and 1 or 0)
end

-- Rows past maxRows start fading now, quickly. A stuck row takes the first
-- slot, and a sticky row a full feed would push out sticks instead, the
-- oldest first.
local function pushOut(model, now)
	local oldest
	repeat
		oldest = nil
		local seen = 0
		for _, row in ipairs(model.rows) do
			if not row.stuck then
				seen = seen + 1
				if seen > room(model) and row.sticky and row.fadeStart > now then
					oldest = row
				end
			end
		end
		if oldest then
			stick(model, oldest)
		end
	until not oldest
	local fade = math.min(model.options.fade, Model.PUSH_FADE)
	local fits = room(model)
	local seen = 0
	for _, row in ipairs(model.rows) do
		if not row.stuck then
			seen = seen + 1
			if seen > fits and row.fadeStart > now then
				row.fadeStart, row.fadeEnd = now, now + fade
			end
		end
	end
end

-- New settings take effect at once: fewer rows push the oldest out.
function ModelMixin:SetOptions(options, now)
	self.options = options
	pushOut(self, clock(self, now))
end

-- Adds an entry; returns its row, or nil when the entry is not shown. force
-- shows an item below the minimum quality.
function ModelMixin:Add(entry, now, force)
	if not shown(self, entry, force) then
		return nil
	end
	now = clock(self, now)
	stickDue(self, now)
	local key = keyOf(entry)
	local row
	for index, existing in ipairs(self.rows) do
		if existing.key == key and existing.stuck then
			-- In place, and stuck still.
			existing.amount = (existing.amount or 0) + (entry.amount or 0)
			for field, value in pairs(entry) do
				if field ~= "amount" then
					existing[field] = value
				end
			end
			return existing
		elseif existing.key == key then
			table.remove(self.rows, index)
			-- A row that has faded out is gone, even before Update removes it.
			row = existing.fadeEnd > now and existing or nil
			break
		end
	end
	if row then
		if row.amount or entry.amount then
			row.amount = (row.amount or 0) + (entry.amount or 0)
		end
		-- Everything else as the client knows it now: an item looted before its
		-- data was loaded came without an icon or a quality.
		for field, value in pairs(entry) do
			if field ~= "amount" then
				row[field] = value
			end
		end
	else
		row = { key = key }
		for field, value in pairs(entry) do
			row[field] = value
		end
	end
	restart(self, row, now)
	table.insert(self.rows, 1, row)
	pushOut(self, now)
	return row
end

-- Makes a row sticky (kind: what makes the item usable, as Rules.Usable says)
-- or, with nil, not sticky: a stuck row then goes at once.
function ModelMixin:SetSticky(row, kind, now)
	if kind then
		row.sticky = kind
		pushOut(self, clock(self, now))
	elseif row.stuck then
		self:Release(row)
	else
		row.sticky = nil
	end
end

-- A row that is no longer sticky though its item is still there: a stuck row
-- leaves its place and fades out as one whose time is up, and sticks again if
-- it is made sticky before it is gone.
function ModelMixin:Unstick(row, now)
	now = clock(self, now)
	row.sticky = nil
	if row.stuck then
		row.stuck, row.stuckOrder = nil, nil
		row.fadeStart, row.fadeEnd = now, now + self.options.fade
		pushOut(self, now)
	end
end

-- Lets a row go at once: the player dismissed it, or used up its item.
function ModelMixin:Release(row)
	for index, existing in ipairs(self.rows) do
		if existing == row then
			table.remove(self.rows, index)
			return true
		end
	end
	return false
end

-- Removes rows that have faded out; returns true when any was removed.
function ModelMixin:Update(now)
	now = clock(self, now)
	stickDue(self, now)
	local removed = false
	for index = #self.rows, 1, -1 do
		if self.rows[index].fadeEnd <= now then
			table.remove(self.rows, index)
			removed = true
		end
	end
	return removed
end

local function alpha(row, now)
	if now < row.fadeStart then
		return 1
	end
	local length = row.fadeEnd - row.fadeStart
	if length <= 0 then
		return 0
	end
	return math.max(0, math.min(1, (row.fadeEnd - now) / length))
end

-- The rows to draw, newest first, each as { row, alpha }: up to maxRows
-- rows, and after them the ones fading out after a push. The row stuck first
-- comes last, at the anchor edge, as { row, alpha = 1, stuck = true, waiting
-- = the stuck rows under it }.
function ModelMixin:Visible(now)
	now = clock(self, now)
	stickDue(self, now)
	local list, top, waiting = {}, nil, 0
	for _, row in ipairs(self.rows) do
		if row.stuck then
			if not top or row.stuckOrder < top.stuckOrder then
				top = row
			end
			waiting = waiting + 1
		elseif row.fadeEnd > now then
			list[#list + 1] = { row = row, alpha = alpha(row, now) }
		end
	end
	if top then
		list[#list + 1] = { row = top, alpha = 1, stuck = true, waiting = waiting - 1 }
	end
	return list
end

-- The stuck rows, the first one first.
function ModelMixin:Stuck()
	local list = {}
	for _, row in ipairs(self.rows) do
		if row.stuck then
			list[#list + 1] = row
		end
	end
	table.sort(list, function(a, b) return a.stuckOrder < b.stuckOrder end)
	return list
end

-- Pauses every timer while the pointer is over the feed; the time spent
-- hovering is added to every row when it ends.
function ModelMixin:SetHover(hovered, now)
	if hovered and not self.pausedAt then
		self.pausedAt = now
	elseif not hovered and self.pausedAt then
		local paused = now - self.pausedAt
		self.pausedAt = nil
		for _, row in ipairs(self.rows) do
			row.fadeStart = row.fadeStart + paused
			row.fadeEnd = row.fadeEnd + paused
		end
	end
end
