local _, ns = ...

-- Stand-in for Compat/Compat.lua in tests: the same functions, backed by a fake
-- client in Compat.Test.state. Compat.Test drives it: fire events, enter
-- combat, move time.
local Compat = {}
ns.Compat = Compat

local state = {
	capabilities = {},
	events = {},
	character = "Tester-Realm",
	combat = false,
	addons = { Lootoman = true },
	metadata = { Lootoman = { Title = "Lootoman", Version = "@project-version@" } },
	time = 0,
	timers = {},
	build = { "12.1.5", "70575", "Oct 23 2026", 120105 },
	saved = {},
	slashCommands = {},
	printed = {},
	errors = {},
}

function Compat.Has(path)
	return state.capabilities[path] == true
end

function Compat.RegisterEvent(event, handler)
	state.events[event] = handler
end

function Compat.UnregisterEvent(event)
	state.events[event] = nil
end

function Compat.GetCharacterKey()
	return state.character
end

function Compat.InCombat()
	return state.combat
end

function Compat.IsSecret(value)
	return type(value) == "table" and value.secret == true
end

function Compat.IsAddOnLoaded(name)
	return state.addons[name] == true
end

function Compat.GetAddOnMetadata(name, field)
	local fields = state.metadata[name]
	return fields and fields[field]
end

function Compat.After(seconds, callback)
	state.timers[#state.timers + 1] = { at = state.time + seconds, callback = callback }
end

function Compat.GetBuildInfo()
	return unpack(state.build)
end

function Compat.GetSaved(name)
	return state.saved[name]
end

function Compat.SetSaved(name, value)
	state.saved[name] = value
end

function Compat.RegisterSlashCommand(id, commands, handler)
	state.slashCommands[id] = { commands = commands, handler = handler }
end

function Compat.Print(text)
	state.printed[#state.printed + 1] = text
end

function Compat.ReportError(err)
	state.errors[#state.errors + 1] = err
end

local Test = { state = state }
Compat.Test = Test

function Test.FireEvent(event, ...)
	local handler = state.events[event]
	if handler then
		handler(event, ...)
	end
end

function Test.IsRegistered(event)
	return state.events[event] ~= nil
end

-- Fires PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED like the game does.
function Test.SetCombat(inCombat)
	state.combat = inCombat
	Test.FireEvent(inCombat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

-- Runs the timers that are due after the given number of seconds.
function Test.Advance(seconds)
	state.time = state.time + seconds
	local due, waiting = {}, {}
	for _, timer in ipairs(state.timers) do
		if timer.at <= state.time then
			due[#due + 1] = timer
		else
			waiting[#waiting + 1] = timer
		end
	end
	state.timers = waiting
	for _, timer in ipairs(due) do
		timer.callback()
	end
end

-- Runs a slash command as if the player typed "/<command> <message>".
function Test.RunSlashCommand(id, message)
	state.slashCommands[id].handler(message or "")
end
