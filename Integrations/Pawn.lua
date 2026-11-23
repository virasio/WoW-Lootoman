local _, ns = ...
local Compat, SelfTest = ns.Compat, ns.SelfTest

-- Whether an item is an upgrade for the player, from Pawn (checked with
-- Pawn 2.14.8): PawnCanItemHaveStats(link) says whether an item is gear it
-- scores, PawnGetItemData(link) gives its item table (whose Link is nil while
-- its stats load), and PawnIsItemAnUpgrade(item) gives nothing for an item
-- that is not an upgrade, else the upgrades for the player's scales, best
-- first: { { LocalizedScaleName, PercentUpgrade (0.15 for 15%) }, … }.
-- PawnIsReady(), of Pawn's own API, says whether it can answer yet (not while
-- the game's interface still loads); the flag behind it is Pawn's own local,
-- not a global. The loot rolls' advice on whether to need uses it.
--
-- Used only while Pawn is loaded, ready and its functions are there. A
-- call that raises an error turns the integration off until the next login;
-- the self-test shows the error.
ns.Integrations = ns.Integrations or {}
local Integration = {}
ns.Integrations.Pawn = Integration

Integration.ADDON = "Pawn"
Integration.NAME = "Pawn"
-- Where to get it, for the options page on a client without Forever
-- Leveling BiS, while Pawn is not there.
Integration.ADDRESS = "https://www.curseforge.com/wow/addons/pawn"

local failure

local function api()
	if type(PawnIsReady) ~= "function" then
		return false
	end
	local ok, ready = pcall(PawnIsReady)
	return ok and ready == true and type(PawnCanItemHaveStats) == "function" and type(PawnGetItemData) == "function"
		and type(PawnIsItemAnUpgrade) == "function"
end

-- "missing" (not loaded), "noApi" (loaded without the API, or not ready
-- yet), "working", or "failed" and the error.
function Integration.State()
	if failure then
		return "failed", failure
	elseif not Compat.IsAddOnLoaded(Integration.ADDON) then
		return "missing"
	elseif not api() then
		return "noApi"
	end
	return "working"
end

function Integration.Working()
	return Integration.State() == "working"
end

local function call(fn, ...)
	local ok, result = pcall(fn, ...)
	if not ok then
		failure = tostring(result)
		ns.Debug("Pawn: its call failed, no advice from it: " .. failure)
		return nil, true
	end
	return result
end

-- Whether an item is an upgrade: its best upgrade's share (0.15 for 15%) and
-- the scale's name; false when it is not an upgrade; nil and true while its
-- stats load; nil when it is not gear Pawn scores, or the integration does
-- not work.
function Integration.Upgrade(link)
	if type(link) ~= "string" or not Integration.Working() then
		return nil
	end
	local scored, broken = call(PawnCanItemHaveStats, link)
	if broken or not scored then
		return nil
	end
	local item
	item, broken = call(PawnGetItemData, link)
	if broken or type(item) ~= "table" then
		return nil
	end
	if item.Link == nil then
		return nil, true
	end
	local upgrades
	upgrades, broken = call(PawnIsItemAnUpgrade, item)
	if broken then
		return nil
	end
	local best = type(upgrades) == "table" and upgrades[1]
	if type(best) == "table" and type(best.PercentUpgrade) == "number" then
		return best.PercentUpgrade, best.LocalizedScaleName
	end
	return false
end

SelfTest.AddReport(function()
	local state, problem = Integration.State()
	local texts = {
		missing = "not installed",
		noApi = "loaded, but without its API or not ready: no advice from it",
		working = "working",
	}
	return "Pawn: " .. (texts[state] or ("off after an error: " .. tostring(problem)))
end)
