local _, ns = ...
local Compat, SelfTest = ns.Compat, ns.SelfTest

-- The quests an item belongs to, from QuestieDB, the database Questie reads
-- (GPL-3.0; checked with QuestieDB 1.1.2, contract 4): its public API is the
-- global LibQuestieDB, whose RequireContract(4) says whether this release
-- still speaks the contract Lootoman was written for, and whose
-- Item.relatedQuests(itemID) gives the quest IDs an item is for, or nil.
-- Junk suggestions use it to tell leftovers of done quests; without it they
-- fall back on the quest log (QuestMemory).
--
-- Used only while QuestieDB is loaded, its contract holds and the function is
-- there. A call that raises an error turns the integration off until the next
-- login; the self-test shows the error. Answers are kept per item, and
-- dropped with Forget when a quest is turned in.
ns.Integrations = ns.Integrations or {}
local Integration = {}
ns.Integrations.QuestieDB = Integration

Integration.ADDON = "QuestieDB"
Integration.CONTRACT = 4
-- Where to get it: the game cannot open it, so the options page copies it.
Integration.ADDRESS = "https://www.curseforge.com/wow/addons/questiedb"

local failure, contract
local cache = {}

local function api()
	local lib = LibQuestieDB
	if type(lib) ~= "table" or type(lib.RequireContract) ~= "function" or type(lib.Item) ~= "table"
		or type(lib.Item.relatedQuests) ~= "function" then
		return nil
	end
	if contract == nil then
		local ok, holds = pcall(lib.RequireContract, Integration.CONTRACT)
		contract = ok and holds == true
	end
	return contract and lib or nil
end

-- "missing" (not loaded), "noApi" (loaded without the API, or with another
-- contract), "working", or "failed" and the error.
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

-- Whether its answers can be used now.
function Integration.Working()
	return Integration.State() == "working"
end

-- The quest IDs an item belongs to (a list, maybe empty), or nil while the
-- integration does not work.
function Integration.RelatedQuests(itemID)
	if not Integration.Working() or type(itemID) ~= "number" then
		return nil
	end
	local known = cache[itemID]
	if known then
		return known
	end
	local ok, quests = pcall(api().Item.relatedQuests, itemID)
	if not ok then
		failure = tostring(quests)
		ns.Debug("QuestieDB: its quest call failed, junk suggestions use the quest log: " .. failure)
		return nil
	end
	local list = {}
	for _, questID in ipairs(type(quests) == "table" and quests or {}) do
		if type(questID) == "number" then
			list[#list + 1] = questID
		end
	end
	cache[itemID] = list
	return list
end

-- Drops what is kept, after a quest is turned in.
function Integration.Forget()
	cache = {}
end

SelfTest.AddReport(function()
	local state, problem = Integration.State()
	local texts = {
		missing = "not installed: junk suggestions use the quest log",
		noApi = "loaded, but without the API (contract " .. Integration.CONTRACT .. "): junk suggestions use the quest log",
		working = "working",
	}
	return "QuestieDB: " .. (texts[state] or ("off after an error: " .. tostring(problem)))
end)
