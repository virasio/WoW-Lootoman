local _, ns = ...
local Compat = ns.Compat

-- Modules never call each other; they send and listen to messages here.
-- Game events go through the bus too, so all listeners of one owner can be
-- removed at once when a module is disabled.
--
-- Listeners are called as fn(name, ...), where name is the message or event.
-- Each owner has at most one listener per name; listeners run in the order
-- they were added.
local Bus = {}
ns.Bus = Bus

local messageListeners = {}
local eventListeners = {}

-- An error in one listener is reported and does not stop the others.
local function call(fn, ...)
	local count, args = select("#", ...), { ... }
	xpcall(function()
		fn(unpack(args, 1, count))
	end, Compat.ReportError)
end

-- Lists are replaced, never changed in place, so a dispatch in progress keeps
-- its own list. Removed listeners are marked inactive and skipped.
local function add(registry, name, owner, fn)
	local list = registry[name]
	local copy = {}
	for _, listener in ipairs(list or {}) do
		if listener.owner == owner then
			listener.active = false
		else
			copy[#copy + 1] = listener
		end
	end
	copy[#copy + 1] = { owner = owner, fn = fn, active = true }
	registry[name] = copy
	return list == nil
end

local function remove(registry, name, owner)
	local list = registry[name]
	if not list then
		return false
	end
	local copy = {}
	for _, listener in ipairs(list) do
		if listener.owner == owner then
			listener.active = false
		else
			copy[#copy + 1] = listener
		end
	end
	registry[name] = #copy > 0 and copy or nil
	return registry[name] == nil
end

local function dispatch(registry, name, ...)
	local list = registry[name]
	if not list then
		return
	end
	for _, listener in ipairs(list) do
		if listener.active then
			call(listener.fn, name, ...)
		end
	end
end

local function listens(registry, name, owner)
	for _, listener in ipairs(registry[name] or {}) do
		if listener.owner == owner then
			return true
		end
	end
	return false
end

function Bus:On(message, owner, fn)
	add(messageListeners, message, owner, fn)
end

function Bus:Off(message, owner)
	remove(messageListeners, message, owner)
end

function Bus:Send(message, ...)
	dispatch(messageListeners, message, ...)
end

local function onGameEvent(event, ...)
	dispatch(eventListeners, event, ...)
end

-- The game event is registered with the client only while it has listeners.
function Bus:OnEvent(event, owner, fn)
	if add(eventListeners, event, owner, fn) then
		Compat.RegisterEvent(event, onGameEvent)
	end
end

function Bus:OffEvent(event, owner)
	if remove(eventListeners, event, owner) then
		Compat.UnregisterEvent(event)
	end
end

function Bus:OffAll(owner)
	local messages, events = {}, {}
	for message in pairs(messageListeners) do
		if listens(messageListeners, message, owner) then
			messages[#messages + 1] = message
		end
	end
	for event in pairs(eventListeners) do
		if listens(eventListeners, event, owner) then
			events[#events + 1] = event
		end
	end
	for _, message in ipairs(messages) do
		self:Off(message, owner)
	end
	for _, event in ipairs(events) do
		self:OffEvent(event, owner)
	end
end

-- Game events an owner listens to, sorted; used by the self-test.
function Bus:GetEvents(owner)
	local events = {}
	for event in pairs(eventListeners) do
		if listens(eventListeners, event, owner) then
			events[#events + 1] = event
		end
	end
	table.sort(events)
	return events
end
