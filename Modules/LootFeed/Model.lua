local _, ns = ...

-- The loot feed's rows, without frames (techspec §7.3). Pure logic: every call
-- that depends on time takes the current time, so tests need no clock.
--
-- A row shows an entry from Sources for `duration` seconds, then fades out over
-- `fade` seconds and is removed. An entry that repeats one still on screen
-- (the same item, currency, faction, or money or experience) merges into it:
-- the amounts add up, the timer restarts and the row moves to the top.
--
-- Items below the minimum quality and turned-off kinds are dropped; rows about
-- items that did not fit ("skipped") are warnings and always shown.
--
-- When there are more than maxRows rows:
-- - push: the oldest rows fade out at once, over at most PUSH_FADE seconds;
-- - scroll: they stay in a history until they expire, and Scroll moves the view.
-- While the pointer is over the feed (SetHover), every timer stops.
--
--   local model = Model.New({ maxRows = 8, duration = 6, fade = 1, mode = "scroll", minQuality = 0,
--       kinds = { item = true, currency = true, money = true, reputation = true, xp = false } }, now)
--   model:Add(entry, now); model:Update(now)
--   for _, view in ipairs(model:Visible(now)) do -- view.row, view.alpha
ns.Feed = ns.Feed or {}
local Model = {}
ns.Feed.Model = Model

Model.PUSH_FADE = 0.5

local ModelMixin = {}
ModelMixin.__index = ModelMixin

function Model.New(options, now)
	local model = setmetatable({ rows = {}, offset = 0 }, ModelMixin)
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

local function shown(model, entry)
	if entry.kind == "skipped" then
		return true
	end
	if not model.options.kinds[entry.kind] then
		return false
	end
	return entry.kind ~= "item" or entry.quality == nil or entry.quality >= model.options.minQuality
end

-- While hovered, time stands still at the moment the hover began.
local function clock(model, now)
	return model.pausedAt or now
end

local function restart(model, row, now)
	row.fadeStart = now + model.options.duration
	row.fadeEnd = row.fadeStart + model.options.fade
end

-- Push mode: rows past maxRows start fading now, quickly.
local function pushOut(model, now)
	if model.options.mode ~= "push" then
		return
	end
	local fade = math.min(model.options.fade, Model.PUSH_FADE)
	for index = model.options.maxRows + 1, #model.rows do
		local row = model.rows[index]
		if row.fadeStart > now then
			row.fadeStart, row.fadeEnd = now, now + fade
		end
	end
end

local function clampOffset(model)
	local most = math.max(0, #model.rows - model.options.maxRows)
	model.offset = math.max(0, math.min(model.offset, most))
end

-- New settings take effect at once: fewer rows in push mode push the oldest out.
function ModelMixin:SetOptions(options, now)
	self.options = options
	pushOut(self, clock(self, now))
	clampOffset(self)
end

-- Adds an entry; returns its row, or nil when the entry is not shown.
function ModelMixin:Add(entry, now)
	if not shown(self, entry) then
		return nil
	end
	now = clock(self, now)
	local key = keyOf(entry)
	local row
	for index, existing in ipairs(self.rows) do
		if existing.key == key then
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
		row.total = entry.total or row.total
	else
		row = { key = key }
		for field, value in pairs(entry) do
			row[field] = value
		end
		-- A scrolled view keeps showing the same rows.
		if self.offset > 0 then
			self.offset = self.offset + 1
		end
	end
	restart(self, row, now)
	table.insert(self.rows, 1, row)
	pushOut(self, now)
	clampOffset(self)
	return row
end

-- Removes rows that have faded out; returns true when any was removed.
function ModelMixin:Update(now)
	now = clock(self, now)
	local removed = false
	for index = #self.rows, 1, -1 do
		if self.rows[index].fadeEnd <= now then
			table.remove(self.rows, index)
			removed = true
		end
	end
	clampOffset(self)
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

-- The rows to draw, newest first, each as { row, alpha }. Push mode shows
-- maxRows rows plus the ones fading out after a push; scroll mode shows
-- maxRows rows from the scroll position.
function ModelMixin:Visible(now)
	now = clock(self, now)
	local first, last = 1, #self.rows
	if self.options.mode == "scroll" then
		first = self.offset + 1
		last = math.min(#self.rows, self.offset + self.options.maxRows)
	end
	local list = {}
	for index = first, last do
		local row = self.rows[index]
		if row.fadeEnd > now then
			list[#list + 1] = { row = row, alpha = alpha(row, now) }
		end
	end
	return list
end

-- Scroll mode: delta > 0 goes back to older rows, delta < 0 to newer ones.
function ModelMixin:Scroll(delta)
	if self.options.mode == "scroll" then
		self.offset = self.offset + delta
		clampOffset(self)
	end
end

-- Whether there are newer rows above the view and older rows below it.
function ModelMixin:CanScroll()
	if self.options.mode ~= "scroll" then
		return false, false
	end
	return self.offset > 0, self.offset + self.options.maxRows < #self.rows
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
