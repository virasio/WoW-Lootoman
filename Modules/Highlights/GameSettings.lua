local _, ns = ...
local Bus, Compat, Storage = ns.Bus, ns.Compat, ns.Storage

-- The game settings (console variables) gathering highlights need, borrowed
-- while highlights are on and given back when they stop or the player logs
-- out, so turning Lootoman off leaves nothing behind. Soft targeting has to
-- pick objects all around, out to the 15 yards the client allows on WoW Forever
-- (measured by Lueur's author), and give them a nameplate to hang the sparkles
-- on.
--
-- A setting is changed only when it differs, and its old value and Lootoman's
-- are remembered account-wide (section highlightCVars). It goes back only if
-- it still holds Lootoman's value: when the player or another addon changed it
-- since, theirs stays and the memory is dropped, so nobody fights over it. The
-- client refuses changes in combat, so they wait for the fight to end; a
-- setting the client does not know is skipped.
--
-- Two more, learned from Lueur and Forever Loot Sparkles:
-- - The soft target's nameplate is on only while the target is an object
--   that sparkles (Gate), so NPCs and mailboxes get no label from Lootoman.
--   A player who keeps it on for everything keeps it on.
-- - Safe self-cast: a spell cast without a target can land on the soft
--   target when it is a living unit next to the player. So while Lootoman
--   itself turned soft targeting on (the player had it off), it pauses it on
--   a living unit until the player has moved a few yards, or for a few
--   seconds where the position is unknown, and as a fight begins until it
--   ends.
--
--   GameSettings.Start()      -- highlights start: Borrow, and the fight pause
--   GameSettings.Stop()       -- highlights stop: GiveBack
--   GameSettings.Gate(open)   -- each soft target
--   GameSettings.Pause("unit"); GameSettings.CheckPause()   -- a living unit; every few tenths of a second
ns.Highlights = ns.Highlights or {}
local GameSettings = {}
ns.Highlights.GameSettings = GameSettings

GameSettings.SECTION = "highlightCVars"

-- name, value, and whether a larger value will do too.
GameSettings.WANTED = {
	{ "SoftTargetInteract", "3" },
	{ "SoftTargetInteractRange", "15" },
	{ "SoftTargetInteractArc", "2" },
	{ "SoftTargetInteractOnlyInRange", "0" },
	{ "SoftTargetIconGameObject", "1" },
	{ "nameplateGameObjectMaxDistance", "15", true },
}

-- The memory: { schema = 1, values = { [name] = { old, ours } }, paused },
-- paused while soft targeting is paused (Pause).
function GameSettings.Memory()
	local section = Storage:GetGlobalSection(GameSettings.SECTION)
	section.schema = section.schema or 1
	if type(section.values) ~= "table" then
		section.values = {}
	end
	return section
end

-- What waits for the end of a fight: "borrow" or "give back".
local waiting

local function wait(what)
	waiting = what
	Bus:OnEvent("PLAYER_REGEN_ENABLED", GameSettings, function()
		Bus:OffEvent("PLAYER_REGEN_ENABLED", GameSettings)
		local due = waiting
		waiting = nil
		if due == "borrow" then
			GameSettings.Borrow()
		elseif due == "give back" then
			GameSettings.GiveBack()
		end
	end)
end

-- Sets one setting to Lootoman's value, remembering the one before. False
-- when the client does not know it or did not take it.
function GameSettings.Take(name, value)
	local current = Compat.GetCVar(name)
	if current == nil then
		return false
	end
	if current == value then
		return true
	end
	if not Compat.SetCVar(name, value) then
		return false
	end
	local values = GameSettings.Memory().values
	local entry = values[name]
	if entry then
		-- Lootoman's own value from before (a /reload, a crash) is not the old one.
		if current ~= entry.ours then
			entry.old = current
		end
		entry.ours = value
	else
		values[name] = { old = current, ours = value }
	end
	return true
end

-- The pause of safe self-cast: nil, or { reason = "unit" or "combat", at,
-- x, y } (where the player was).
local pause

-- Every setting highlights need; in combat, once it ends. A pause an earlier
-- session left ends here: the interact setting gets Lootoman's value again.
function GameSettings.Borrow()
	if Compat.InCombat() then
		wait("borrow")
		return
	end
	if waiting == "give back" then
		Bus:OffEvent("PLAYER_REGEN_ENABLED", GameSettings)
		waiting = nil
	end
	pause = nil
	GameSettings.Memory().paused = nil
	for _, wanted in ipairs(GameSettings.WANTED) do
		local name, value, atLeast = wanted[1], wanted[2], wanted[3]
		local current = tonumber(Compat.GetCVar(name))
		if not (atLeast and current and current >= tonumber(value)) then
			GameSettings.Take(name, value)
		end
	end
end

-- Every remembered setting that still holds Lootoman's value goes back; the
-- memory of each is dropped. In combat, once it ends.
function GameSettings.GiveBack()
	if Compat.InCombat() then
		wait("give back")
		return
	end
	if waiting == "borrow" then
		Bus:OffEvent("PLAYER_REGEN_ENABLED", GameSettings)
		waiting = nil
	end
	-- Paused, the interact setting holds the player's own value already.
	pause = nil
	GameSettings.Memory().paused = nil
	local values = GameSettings.Memory().values
	for name, entry in pairs(values) do
		if Compat.GetCVar(name) == entry.ours and entry.old ~= nil then
			Compat.SetCVar(name, entry.old)
		end
		values[name] = nil
	end
end

-- Whether Lootoman holds a setting at its own value now.
function GameSettings.Holds(name)
	local entry = GameSettings.Memory().values[name]
	return entry ~= nil and Compat.GetCVar(name) == entry.ours
end

local NAMEPLATE = "SoftTargetNameplateInteract"

-- The soft target's nameplate on (an object that sparkles) or off, out of
-- combat only: in a fight it stays as the fight found it. Off means the
-- player's own value again.
function GameSettings.Gate(open)
	if Compat.InCombat() then
		return
	end
	if open then
		GameSettings.Take(NAMEPLATE, "1")
	elseif GameSettings.Holds(NAMEPLATE) then
		local values = GameSettings.Memory().values
		Compat.SetCVar(NAMEPLATE, values[NAMEPLATE].old)
		values[NAMEPLATE] = nil
	end
end

GameSettings.RESUME_DISTANCE = 5
GameSettings.RESUME_TIME = 3

-- Whether Lootoman may pause soft targeting: it turned it on itself, from off.
function GameSettings.CanPause()
	local entry = GameSettings.Memory().values.SoftTargetInteract
	return entry ~= nil and entry.old == "0"
end

function GameSettings.IsPaused()
	return pause ~= nil
end

-- Pauses soft targeting, for a living unit ("unit") or a fight ("combat").
-- True when it is paused now.
function GameSettings.Pause(reason)
	if pause then
		if reason == "combat" then
			pause.reason = "combat"
		end
		return true
	end
	if Compat.InCombat() or not GameSettings.CanPause() or not GameSettings.Holds("SoftTargetInteract") then
		return false
	end
	if not Compat.SetCVar("SoftTargetInteract", "0") then
		return false
	end
	local x, y = Compat.GetPlayerPosition()
	pause = { reason = reason, at = Compat.GetTime(), x = x, y = y }
	GameSettings.Memory().paused = true
	return true
end

-- Soft targeting on again, out of combat, unless someone changed it meanwhile.
function GameSettings.Resume()
	if not pause or Compat.InCombat() then
		return false
	end
	pause = nil
	local memory = GameSettings.Memory()
	memory.paused = nil
	local entry = memory.values.SoftTargetInteract
	if entry and Compat.GetCVar("SoftTargetInteract") == "0" then
		Compat.SetCVar("SoftTargetInteract", entry.ours)
	end
	return true
end

-- A pause for a living unit ends once the player has moved a few yards away
-- from where it began, or after a few seconds without a position; a pause for
-- a fight waits for its end.
function GameSettings.CheckPause()
	if not pause or pause.reason ~= "unit" then
		return
	end
	local x, y = Compat.GetPlayerPosition()
	local done
	if x and pause.x then
		local dx, dy = x - pause.x, y - pause.y
		done = dx * dx + dy * dy >= GameSettings.RESUME_DISTANCE * GameSettings.RESUME_DISTANCE
	else
		done = Compat.GetTime() - pause.at >= GameSettings.RESUME_TIME
	end
	if done then
		GameSettings.Resume()
	end
end

-- The fight pause listens apart from the waiting above.
local fights = {}

function GameSettings.Start()
	GameSettings.Borrow()
	-- As a fight begins the client may still take the change; if it refuses,
	-- the pause can't happen until the fight is over.
	Bus:OnEvent("PLAYER_REGEN_DISABLED", fights, function()
		GameSettings.Pause("combat")
	end)
	Bus:OnEvent("PLAYER_REGEN_ENABLED", fights, function()
		if pause and pause.reason == "combat" then
			GameSettings.Resume()
		end
	end)
end

function GameSettings.Stop()
	Bus:OffAll(fights)
	GameSettings.GiveBack()
end

-- At logout the settings go back; at the next start, what an earlier session
-- left (a crash skips the logout) goes back too unless highlights are on.
Bus:OnEvent("PLAYER_LOGOUT", GameSettings, function()
	if next(GameSettings.Memory().values) then
		GameSettings.GiveBack()
	end
end)

Bus:On("Ready", GameSettings, function()
	local module = ns.Modules:Get("Highlights")
	if not (module and module:IsActive()) and next(GameSettings.Memory().values) then
		GameSettings.GiveBack()
	end
end)
