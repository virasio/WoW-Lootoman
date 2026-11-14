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
--   GameSettings.Borrow()     -- highlights start
--   GameSettings.GiveBack()   -- highlights stop, logout
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

-- The memory: { schema = 1, values = { [name] = { old, ours } } }.
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

-- Every setting highlights need; in combat, once it ends.
function GameSettings.Borrow()
	if Compat.InCombat() then
		wait("borrow")
		return
	end
	if waiting == "give back" then
		Bus:OffEvent("PLAYER_REGEN_ENABLED", GameSettings)
		waiting = nil
	end
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
