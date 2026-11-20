local _, ns = ...
local Compat, Storage = ns.Compat, ns.Storage

-- /ltm debug rolls: the open rolls and how each is bound to the loot history,
-- the history's drops the model knows, and the open group's last drops, in
-- English as all debug output; /ltm debug demoroll plays the demo. The bug
-- report says how the loot rolls are set, and the self-test what the client
-- has of the game's roll frames.
local Model, History = ns.Rolls.Model, ns.Rolls.History

local function nameOf(link)
	return type(link) == "string" and link:match("%[(.-)%]") or tostring(link)
end

ns.Slash.RegisterDebug("rolls", function()
	local rolls = Model.Rolls()
	ns.Print(("debug rolls: %d open roll(s); detection %s"):format(#rolls, Storage:Get("Rolls", "ninja") and "on" or "off"))
	for _, roll in ipairs(rolls) do
		local drop = Model.DropOf(roll.rollID)
		ns.Print(("  roll %s %s: %s"):format(tostring(roll.rollID), nameOf(roll.link),
			drop and ("drop " .. tostring(drop.key) .. ", " .. #drop.rolls .. " players") or "no drop yet"))
	end
	local group = History.Open()
	if not group then
		ns.Print("  no group open")
		return
	end
	ns.Print(("  group %s, since %s: %d drop(s)"):format(tostring(group.id or "(unknown)"), Compat.FormatDay(group.started or 0), #group.drops))
	for index = math.max(1, #group.drops - 4), #group.drops do
		local entry = group.drops[index]
		local winner = "none"
		for _, player in ipairs(entry.rolls) do
			if player.guid and player.guid == entry.winner then
				winner = tostring(player.name)
			end
		end
		ns.Print(("  %s %s at %s: %d players, winner %s"):format(tostring(entry.key), nameOf(entry.link), tostring(entry.place), #entry.rolls, winner))
	end
end, "/ltm debug rolls: the open rolls, their drops and the open group's last drops")

-- /ltm debug demoroll: the demo, the only way to play it.
ns.Slash.RegisterDebug("demoroll", function()
	ns.Rolls.Demo.Start()
end, "/ltm debug demoroll: play the loot rolls' demo, with no group")

-- In the bug report, under the options.
ns.BugReport.AddPart(function()
	local groups, drops = History.Size()
	return {
		("Loot rolls: %s; detection %s, strictness %s; classes with changed rules %d; history %d groups, %d drops"):format(
			Storage:Get("Rolls", "enabled") and "on" or "off", Storage:Get("Rolls", "ninja") and "on" or "off", tostring(Storage:Get("Rolls", "strictness")),
			ns.NeedRules.ChangedCount(), groups, drops),
	}
end)

-- In the self-test: the game's roll frames and their layout, which the panels
-- and the mover need.
ns.SelfTest.AddReport(function()
	return ("Loot rolls: %d of the game's roll frames found; their container %s"):format(#Compat.GetGameRollFrames(),
		Compat.GetGameRollContainer() and "found" or "NOT found")
end)
