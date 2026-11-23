local _, ns = ...
local Compat, Text = ns.Compat, ns.Text

-- Exists only when the addon runs from the repository (Dev/Demo.lua):
-- /ltm demo exceptions dung|raid opens the Suspicious Needs window as after
-- leaving a group, on the marked needs of a group of the made-up roll
-- history (Dev/DemoRollHistory.lua): the dungeon's first run (Shaw needing
-- nearly everything, one of those needs excused already) or the raid (three
-- heroes needing everything). Its marks need Detect Ninja Looters on, as the
-- window does. What is ticked there touches only the made-up group.
-- Development text is not translated.
ns.Rolls = ns.Rolls or {}
local DemoExceptions = {}
ns.Rolls.DemoExceptions = DemoExceptions

local DemoHistory, Suspicious = ns.Rolls.DemoHistory, ns.Rolls.SuspiciousNeeds

-- Opens the window on a made-up group's marked needs; kind "dung" or "raid".
function DemoExceptions.Open(kind)
	if not ns.Storage:Get("Rolls", "ninja") then
		ns.Print("demo exceptions: its marks need Detect Ninja Looters on.")
		return false
	end
	return DemoHistory.WithItems("exceptions", function(items)
		local groups = DemoHistory.Groups(items, false, Compat.GetServerTime())
		local group = kind == "raid" and groups[3] or groups[1]
		DemoExceptions.group = group
		if not Suspicious.Open(function()
			return Suspicious.Rows(group)
		end) then
			ns.Print("demo exceptions: it opens out of combat.")
			return false
		end
		return true
	end)
end

ns.Slash.RegisterDemo("exceptions", function(rest)
	local kind = Text.FoldCase((rest or ""):match("^%s*(%S*)") or "")
	if kind == "dungeon" then
		kind = "dung"
	end
	if kind ~= "dung" and kind ~= "raid" then
		ns.Print("/ltm demo exceptions dung: the dungeon's run, Shaw needing nearly everything")
		ns.Print("/ltm demo exceptions raid: the raid of forty, three heroes needing everything")
		return
	end
	DemoExceptions.Open(kind)
end, "/ltm demo exceptions dung|raid: the Suspicious Needs window on a made-up group's marked needs, as after leaving it")
