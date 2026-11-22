local _, ns = ...
local Compat = ns.Compat

-- The loot rolls' model: the rolls the game opened for the player
-- (START_LOOT_ROLL), the drops of the loot history with everyone's choice
-- (C_LootHistory), and which drop is which roll's. A roll is bound to the open
-- drop of the same item that came first and is not bound yet; when two copies
-- of one item are rolled on at once and the player's own choice shows the
-- other drop is his, the two swap. The panels beside the game's roll frames
-- read a roll's view from here; the history hears every drop.
ns.Rolls = ns.Rolls or {}
local Model = {}
ns.Rolls.Model = Model

local STATE = ns.Rules.Need.STATE
-- RollOnLoot's types as the loot history's states.
local CHOSEN = { [0] = STATE.PASS, [1] = STATE.NEED, [2] = STATE.GREED, [4] = STATE.TRANSMOG }

local rolls, drops, order = {}, {}, 0
local subscribers = {}

-- fn(kind, value) on every change: "roll" with a roll ID (its view changed),
-- "drop" with a drop (the loot history has news of it), "clear".
function Model.Subscribe(fn)
	subscribers[#subscribers + 1] = fn
end

local function notify(kind, value)
	for _, fn in ipairs(subscribers) do
		xpcall(function()
			fn(kind, value)
		end, Compat.ReportError)
	end
end

local function keyOf(drop)
	return drop.encounterID .. ":" .. tostring(drop.listID)
end

local function isOpen(drop)
	return not drop.winner and not drop.allPassed
end

-- Whether a drop's item is the roll's: the same link, or the same item ID
-- when the two links differ in their details.
local function sameItem(roll, drop)
	if not roll.link or not drop.link then
		return false
	end
	if roll.link == drop.link then
		return true
	end
	local a, b = roll.link:match("item:(%d+)"), drop.link:match("item:(%d+)")
	return a ~= nil and a == b
end

local function boundTo(key)
	for rollID, roll in pairs(rolls) do
		if roll.drop == key then
			return rollID
		end
	end
	return nil
end

-- Binds each roll without a drop, the oldest first, to the first open drop of
-- its item that no roll has yet.
local function bind()
	local waiting = {}
	for _, roll in pairs(rolls) do
		-- A drop made from the chat gives way to the loot history's.
		if not roll.drop or roll.drop:match("^chat:") then
			waiting[#waiting + 1] = roll
		end
	end
	table.sort(waiting, function(a, b) return a.order < b.order end)
	local changed = {}
	for _, roll in ipairs(waiting) do
		local best
		for key, drop in pairs(drops) do
			if not key:match("^chat:") and isOpen(drop) and sameItem(roll, drop) and not boundTo(key)
				and (not best or drop.seen < drops[best].seen) then
				best = key
			end
		end
		if best then
			roll.drop = best
			changed[#changed + 1] = roll.rollID
		end
	end
	return changed
end

-- After the player's choice shows in the loot history: a roll whose drop has
-- another choice of his than he made swaps with the other roll of the same
-- item whose drop has his choice.
local function verify(rollID)
	local roll = rolls[rollID]
	local drop = roll and roll.drop and drops[roll.drop]
	if not drop or not roll.chosen or drop.playerRollState == STATE.NONE or drop.playerRollState == nil then
		return false
	end
	local function matches(state, chosen)
		if chosen == STATE.NEED then
			return ns.Rules.Need.IsNeed(state)
		end
		return state == chosen
	end
	if matches(drop.playerRollState, roll.chosen) then
		return false
	end
	for otherID, other in pairs(rolls) do
		local otherDrop = other.drop and drops[other.drop]
		if otherID ~= rollID and otherDrop and sameItem(roll, otherDrop) and matches(otherDrop.playerRollState, roll.chosen) then
			roll.drop, other.drop = other.drop, roll.drop
			notify("roll", otherID)
			return true
		end
	end
	return false
end

local function changedRolls(list)
	for _, rollID in ipairs(list) do
		notify("roll", rollID)
	end
end

-- A roll the game opened, or nil when it is gone already; rollTime: its
-- length in milliseconds (START_LOOT_ROLL's), else what it has left when
-- first seen (a roll open before a /reload).
function Model.AddRoll(rollID, rollTime)
	if rolls[rollID] then
		return rolls[rollID]
	end
	local item = Compat.GetRollItem(rollID)
	if not item then
		return nil
	end
	order = order + 1
	rolls[rollID] = { rollID = rollID, link = item.link, item = item, order = order, started = Compat.GetTime(),
		total = rollTime or Compat.GetRollTimeLeft(rollID) }
	bind()
	notify("roll", rollID)
	return rolls[rollID]
end

function Model.RemoveRoll(rollID)
	if rolls[rollID] then
		rolls[rollID] = nil
		notify("roll", rollID)
	end
end

-- Every roll gone (CANCEL_ALL_LOOT_ROLLS, the module turned off).
function Model.Clear()
	rolls, drops = {}, {}
	notify("clear")
end

-- The player chose on a roll (RollOnLoot's type).
function Model.Chose(rollID, rollType)
	local roll = rolls[rollID]
	if roll then
		roll.chosen = CHOSEN[rollType]
		verify(rollID)
	end
end

local function store(drop)
	if not drop or drop.listID == nil then
		return nil
	end
	local key = keyOf(drop)
	local known = drops[key]
	order = order + 1
	drop.seen = known and known.seen or order
	drop.key = key
	drops[key] = drop
	return key
end

-- A drop of the loot history changed (LOOT_HISTORY_UPDATE_DROP).
function Model.UpdateDrop(encounterID, listID)
	local key = store(Compat.GetLootDrop(encounterID, listID))
	if not key then
		return
	end
	local changed = bind()
	if boundTo(key) then
		verify(boundTo(key))
		changed[#changed + 1] = boundTo(key)
	end
	-- Each roll once.
	local told = {}
	for _, rollID in ipairs(changed) do
		if not told[rollID] then
			told[rollID] = true
			notify("roll", rollID)
		end
	end
	notify("drop", drops[key])
end

-- Every drop the loot history holds (at the start, LOOT_HISTORY_UPDATE_ENCOUNTER).
function Model.RefreshDrops()
	for _, drop in ipairs(Compat.GetLootDrops()) do
		local key = store(drop)
		if key then
			notify("drop", drops[key])
		end
	end
	changedRolls(bind())
	for rollID in pairs(rolls) do
		notify("roll", rollID)
	end
end

-- The loot history was cleared: the drops go, the rolls stay unbound.
function Model.ClearDrops()
	drops = {}
	for rollID, roll in pairs(rolls) do
		roll.drop = nil
		notify("roll", rollID)
	end
end

-- A drop that is not in the loot history, made from the chat for a roll the
-- history never showed (Chat.lua). It takes the roll's place until a real
-- drop comes.
function Model.SetChatDrop(rollID, drop)
	local roll = rolls[rollID]
	if not roll or (roll.drop and not roll.drop:match("^chat:")) then
		return
	end
	drop.encounterID, drop.listID = "chat", rollID
	drop.link = drop.link or roll.link
	local key = store(drop)
	roll.drop = key
	notify("roll", rollID)
	notify("drop", drops[key])
end

function Model.Roll(rollID)
	return rolls[rollID]
end

-- The share of a roll's time it has left (1 to 0), or nil.
function Model.TimeShare(rollID)
	local roll = rolls[rollID]
	local left = roll and roll.total and roll.total > 0 and Compat.GetRollTimeLeft(rollID)
	if not left then
		return nil
	end
	return math.max(0, math.min(1, left / roll.total))
end

function Model.Rolls()
	local list = {}
	for _, roll in pairs(rolls) do
		list[#list + 1] = roll
	end
	table.sort(list, function(a, b) return a.order < b.order end)
	return list
end

function Model.Drop(key)
	return drops[key]
end

-- Every drop known now, in the order they came.
function Model.Drops()
	local list = {}
	for _, drop in pairs(drops) do
		list[#list + 1] = drop
	end
	table.sort(list, function(a, b) return (a.seen or 0) < (b.seen or 0) end)
	return list
end

-- Whether a drop is still rolled on.
function Model.IsOpen(drop)
	return drop ~= nil and isOpen(drop)
end

-- The drop a roll is bound to, or nil.
function Model.DropOf(rollID)
	local roll = rolls[rollID]
	return roll and roll.drop and drops[roll.drop] or nil
end

-- Whether a roll is waiting for a drop longer than seconds (the chat's cue).
function Model.Unbound(rollID, seconds)
	local roll = rolls[rollID]
	return roll ~= nil and roll.drop == nil and Compat.GetTime() - roll.started >= seconds
end

-- A roll's view for its panel: the item, whether its drop is known yet, and
-- the players in the game's order, each with his choice and roll, whether he
-- is the winner, the leader or the player himself:
-- { rollID, link, bound, players = { { name, guid, class, state, roll,
-- isSelf, isWinner, isLeader } }, winner, leader }.
local function fill(view, drop)
	local leader = drop.currentLeader and drop.currentLeader.guid
	for index, player in ipairs(drop.rolls) do
		local entry = {}
		for key, value in pairs(player) do
			entry[key] = value
		end
		entry.isLeader = leader ~= nil and player.guid == leader and not drop.winner
		view.players[index] = entry
	end
	view.winner, view.leader, view.allPassed, view.drop = drop.winner, drop.currentLeader, drop.allPassed, drop
	return view
end

function Model.View(rollID)
	local roll = rolls[rollID]
	if not roll then
		return nil
	end
	local drop = Model.DropOf(rollID)
	local view = { rollID = rollID, link = roll.link, item = roll.item, bound = drop ~= nil, players = {} }
	if not drop then
		return view
	end
	return fill(view, drop)
end

-- A drop's view as a roll's, without a roll: for the loot rolls' windows,
-- which show drops the player had no roll frame for too.
function Model.DropView(key)
	local drop = drops[key]
	if not drop then
		return nil
	end
	return fill({ link = drop.link, bound = true, players = {} }, drop)
end
