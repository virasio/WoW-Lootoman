local _, ns = ...
local Bus, Compat, L, Storage = ns.Bus, ns.Compat, ns.L, ns.Storage

-- /lootoman and /ltm. Without a command they open the settings.

Storage:RegisterGlobalDefaults({ debug = false })

-- Debug output for development and bug reports, shown after /lootoman debug on.
-- It is not translated.
function ns.Debug(text)
	if Storage.db and Storage:GetGlobal("debug") then
		ns.Print("|cff999999" .. text .. "|r")
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
-- for the whole account, not part of a profile.
commands.debug = function(argument)
	if argument ~= "" then
		local enabled = SWITCH[argument:lower()]
		if enabled == nil then
			ns.Print(L["Unknown value “%s”. Use /lootoman debug on or /lootoman debug off."]:format(argument))
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

commands.help = function()
	ns.Print(L["Commands:"])
	ns.Print(L["/lootoman or /ltm: open the settings"])
	ns.Print(L["/lootoman debug [on | off]: show, turn on or turn off debug messages"])
	ns.Print(L["/lootoman selftest: check the addon against the game client"])
end

Compat.RegisterSlashCommand("LOOTOMAN", { "/lootoman", "/ltm" }, function(message)
	local command, argument = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
	local handler = commands[command:lower()] or commands.help
	handler(argument)
end)
