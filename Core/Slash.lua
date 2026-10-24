local _, ns = ...
local Bus, Compat, L, Storage = ns.Bus, ns.Compat, ns.L, ns.Storage

-- /lootoman and /ltm. Without a command they open the settings.

Storage:RegisterGlobalDefaults({ debug = false })

-- Debug output for development and bug reports, shown after /lootoman debug.
-- It is not translated.
function ns.Debug(text)
	if Storage.db and Storage:GetGlobal("debug") then
		ns.Print("|cff999999" .. text .. "|r")
	end
end

local commands = {}

commands[""] = function()
	Bus:Send("OpenSettings")
end

commands.debug = function()
	local enabled = not Storage:GetGlobal("debug")
	Storage:SetGlobal("debug", enabled)
	ns.Print(enabled and L["Debug messages are on."] or L["Debug messages are off."])
end

commands.selftest = function()
	ns.SelfTest.Run()
end

local function help()
	ns.Print(L["Commands:"])
	ns.Print(L["/lootoman or /ltm: open the settings"])
	ns.Print(L["/lootoman debug: turn debug messages on or off"])
	ns.Print(L["/lootoman selftest: check the addon against the game client"])
end

Compat.RegisterSlashCommand("LOOTOMAN", { "/lootoman", "/ltm" }, function(message)
	local command = (message or ""):match("^%s*(%S*)"):lower()
	local handler = commands[command] or help
	handler()
end)
