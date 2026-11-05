local _, ns = ...
local SelfTest = ns.SelfTest

-- Broker displays (Titan Panel, ElvUI's data texts and others) through
-- LibDataBroker-1.1. Every broker display ships that library, so Lootoman does
-- not: it looks the library up through LibStub once every addon has loaded,
-- and makes data objects only when it is there. LibDataBroker cannot remove
-- an object; one that is turned off is emptied and goes at the next /reload.
-- An error from the library turns the integration off until the next login;
-- the self-test shows it.
ns.Integrations = ns.Integrations or {}
local Broker = {}
ns.Integrations.Broker = Broker

local LIBRARY = "LibDataBroker-1.1"

local failure

local function library()
	local stub = LibStub
	local lib = type(stub) == "table" and stub.GetLibrary and stub:GetLibrary(LIBRARY, true)
		or type(stub) == "function" and stub(LIBRARY, true)
	if type(lib) == "table" and type(lib.NewDataObject) == "function" then
		return lib
	end
	return nil, type(lib) == "table"
end

-- "missing" (no broker display brought the library), "noApi" (it is there
-- without NewDataObject), "working", or "failed" and the error.
function Broker.State()
	if failure then
		return "failed", failure
	end
	local lib, found = library()
	if lib then
		return "working"
	end
	return found and "noApi" or "missing"
end

-- The data object of this name, made with these fields the first time, or nil
-- without a working library. Fields set on it later reach the displays.
function Broker.Object(name, fields)
	local lib = not failure and library()
	if not lib then
		return nil
	end
	local ok, object = pcall(function()
		return lib:GetDataObjectByName(name) or lib:NewDataObject(name, fields)
	end)
	if not ok then
		failure = tostring(object)
		ns.Debug("Broker: LibDataBroker failed, broker objects are off: " .. failure)
		return nil
	end
	return object
end

SelfTest.AddReport(function()
	local state, problem = Broker.State()
	local texts = {
		missing = "no broker display loaded",
		noApi = "LibDataBroker-1.1 without NewDataObject",
		working = "working",
	}
	return "Broker: " .. (texts[state] or ("off after an error: " .. tostring(problem)))
end)
