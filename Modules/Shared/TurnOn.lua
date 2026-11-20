local _, ns = ...
local Bus, L = ns.Bus, ns.L

-- A menu entry or a command of a feature that is off asks to turn it on: the
-- game's own confirmation dialog (GENERIC_CONFIRMATION, nothing written into
-- the game's tables) says to turn on the feature's option, by its name on the
-- options page, with Options, which opens the options, and Cancel.
local TurnOn = {}
ns.TurnOn = TurnOn

function TurnOn.Ask(label)
	if type(StaticPopup_Show) ~= "function" then
		ns.Print((L["To use this, turn on “%s” in the addon's options."]):format(label))
		return
	end
	ns.NameMenu.Confirm(L["To use this, turn on “%s” in the addon's options."], label, L["Options"], function()
		Bus:Send("OpenSettings")
	end)
end

-- Runs open() while the module is on, else asks to turn it on by its switch.
function TurnOn.WhenOn(moduleName, open)
	local module = ns.Modules:Get(moduleName)
	if module and module:IsActive() then
		open()
	else
		TurnOn.Ask(module and (module.switchLabel or module.title) or moduleName)
	end
end
