local _, ns = ...
local Compat, SelfTest = ns.Compat, ns.SelfTest

-- What an item would gain the player, from Forever Leveling BiS (WoW Forever
-- only; checked with its v1.4.5, API version 2): its public API is the global
-- ForeverLevelingBiS_API, whose version says whether it speaks the calls
-- Lootoman was written for, and whose GetGain(link) gives the score an item
-- gains the player's main spec over the gear worn (the green or red number
-- its own tooltip shows; 0 for an item worn, nil for one the player cannot
-- wear or that is not gear) and, second, whether that cannot be told yet
-- (still loading). OnChanged(func) tells when its answers may have changed.
-- The loot rolls' advice on whether to need uses it.
--
-- Used only while the addon is loaded and its API is new enough. A call that
-- raises an error turns the integration off until the next login; the
-- self-test shows the error.
ns.Integrations = ns.Integrations or {}
local Integration = {}
ns.Integrations.ForeverLevelingBiS = Integration

Integration.ADDON = "ForeverLevelingBiS"
Integration.NAME = "Forever Leveling BiS"
Integration.VERSION = 2
-- Where to get it, for the options' button while it is not installed.
Integration.ADDRESS = "https://www.curseforge.com/wow/addons/forever-leveling-bis"

local failure
local listening = false

local function api()
	local lib = ForeverLevelingBiS_API
	if type(lib) ~= "table" or (tonumber(lib.version) or 1) < Integration.VERSION or type(lib.GetGain) ~= "function" then
		return nil
	end
	return lib
end

-- "missing" (not loaded), "noApi" (loaded without the API, or an older
-- one), "working", or "failed" and the error.
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

local function fail(problem)
	failure = tostring(problem)
	ns.Debug("Forever Leveling BiS: its call failed, no advice from it: " .. failure)
end

-- What an item gains the player over the gear worn (a number; 0 for an item
-- worn), and whether it is still loading; nil when it cannot be told (the
-- player cannot wear it, it is not gear) or the integration does not work.
function Integration.Gain(link)
	if type(link) ~= "string" or not Integration.Working() then
		return nil
	end
	local ok, gain, loading = pcall(api().GetGain, link)
	if not ok then
		fail(gain)
		return nil
	end
	return type(gain) == "number" and gain or nil, loading == true
end

-- fn() whenever its answers may have changed (gear, level, spec, items
-- loading); asked of the addon once.
function Integration.OnChanged(fn)
	local lib = Integration.Working() and api()
	if listening or not lib or type(lib.OnChanged) ~= "function" then
		return
	end
	listening = true
	local ok, problem = pcall(lib.OnChanged, function()
		xpcall(fn, Compat.ReportError)
	end)
	if not ok then
		fail(problem)
	end
end

SelfTest.AddReport(function()
	local state, problem = Integration.State()
	local texts = {
		missing = "not installed",
		noApi = "loaded, but without the API (version " .. Integration.VERSION .. "): no advice from it",
		working = "working",
	}
	return "Forever Leveling BiS: " .. (texts[state] or ("off after an error: " .. tostring(problem)))
end)
