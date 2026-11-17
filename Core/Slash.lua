local _, ns = ...
local Bus, Compat, L, Storage, Text = ns.Bus, ns.Compat, ns.L, ns.Storage, ns.Text

-- /lootoman and /ltm. Without a command they open the settings.

Storage:RegisterGlobalDefaults({ debug = false })

-- Debug output for development and bug reports, shown after /lootoman debug on
-- and kept in the saved diagnostics. It is not translated.
function ns.Debug(text)
	if Storage.db and Storage:GetGlobal("debug") then
		ns.Print("|cff999999" .. text .. "|r")
		ns.Diagnostics.Log(text)
	end
end

-- Values accepted by on/off commands, compared in lower case.
local SWITCH = {
	on = true,
	["1"] = true,
	off = false,
	["0"] = false,
}

-- Each command gets the rest of the line after its name. Unknown commands show help.
---@type table<string, fun(argument: string)>
local commands = {}

commands[""] = function()
	Bus:Send("OpenSettings")
end

-- "debug" shows the switch; "debug on" and "debug off" set it. It is one switch
-- for the whole account, not part of a profile. "debug clear" empties the saved
-- diagnostics (the debug log and the last self-test).
commands.debug = function(argument)
	if Text.FoldCase(argument) == "clear" then
		ns.Diagnostics.Clear()
		ns.Print(L["The saved debug messages and self-test are cleared."])
		return
	end
	if argument ~= "" then
		local enabled = SWITCH[Text.FoldCase(argument)]
		if enabled == nil then
			ns.Print(L["Unknown value “%s”. Use /lootoman debug on, off or clear."]:format(argument))
			return
		end
		Storage:SetGlobal("debug", enabled)
	end
	ns.Print(Storage:GetGlobal("debug") and L["Debug messages are on for all characters."]
		or L["Debug messages are off for all characters."])
end

commands.selftest = function()
	ns.SelfTest.Run()
end

local moduleHelp = {}

-- Commands that modules add: handler(argument), and a line for the help.
ns.Slash = {}

function ns.Slash.Register(name, handler, help)
	assert(not commands[name], ("the command %s is already registered"):format(name))
	commands[name] = handler
	moduleHelp[#moduleHelp + 1] = help
end

commands.help = function()
	ns.Print(L["Commands:"])
	ns.Print(L["/lootoman or /ltm: open the settings"])
	ns.Print(L["/lootoman debug [on | off | clear]: show, turn on or turn off debug messages, or clear the saved ones"])
	ns.Print(L["/lootoman selftest: check the addon against the game client"])
	for _, line in ipairs(moduleHelp) do
		ns.Print(line)
	end
end

Compat.RegisterSlashCommand("LOOTOMAN", { "/lootoman", "/ltm" }, function(message)
	local command, argument = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
	local handler = commands[Text.FoldCase(command)] or commands.help
	handler(argument)
end)
