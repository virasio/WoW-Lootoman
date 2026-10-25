local _, ns = ...

-- The loot feed's rows, without frames (techspec §7.3). Pure logic: every call
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
-- over at most PUSH_FADE seconds (the author chose this over a scrollable
-- history after trying both in game). While the pointer is over the feed
-- (SetHover), every timer stops.
--
--   local model = Model.New({ maxRows = 8, duration = 6, fade = 1, minQuality = 0,
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
	local model = setmetatable({ rows = {} }, ModelMixin)
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

-- Rows past maxRows start fading now, quickly.
local function pushOut(model, now)
	local fade = math.min(model.options.fade, Model.PUSH_FADE)
	for index = model.options.maxRows + 1, #model.rows do
		local row = model.rows[index]
		if row.fadeStart > now then
			row.fadeStart, row.fadeEnd = now, now + fade
		end
	end
end

-- New settings take effect at once: fewer rows push the oldest out.
function ModelMixin:SetOptions(options, now)
	self.options = options
	pushOut(self, clock(self, now))
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
	end
	restart(self, row, now)
	table.insert(self.rows, 1, row)
	pushOut(self, now)
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
-- rows, and after them the ones fading out after a push.
function ModelMixin:Visible(now)
	now = clock(self, now)
	local list = {}
	for _, row in ipairs(self.rows) do
		if row.fadeEnd > now then
			list[#list + 1] = { row = row, alpha = alpha(row, now) }
		end
	end
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
