local _, ns = ...
local Compat, Prices, SelfTest = ns.Compat, ns.Prices, ns.SelfTest

-- Auction prices from Auctionator, through its API v1 (checked with
-- Auctionator 341): GetAuctionPriceByItemLink(callerID, itemLink) returns the
-- last scanned price of one item in copper, or nil; it raises an error for a
-- caller ID that is not a string or a link that is not a string, and returns
-- nil before its database has loaded. Auctionator has no callback for new
-- prices.
--
-- Used only while Auctionator is loaded and the function is there. A call that
-- raises an error turns the integration off until the next login; the
-- self-test shows the error, and prices fall back to the vendor price.
ns.Integrations = ns.Integrations or {}
local Integration = {}
ns.Integrations.Auctionator = Integration

local ADDON = "Auctionator"
local CALLER = "Lootoman"

local failure

local function api()
	local addon = Auctionator
	local v1 = type(addon) == "table" and type(addon.API) == "table" and addon.API.v1
	if type(v1) == "table" and type(v1.GetAuctionPriceByItemLink) == "function" then
		return v1
	end
	return nil
end

-- "missing" (not loaded), "noApi" (loaded without API v1), "working", or
-- "failed" and the error.
function Integration.State()
	if failure then
		return "failed", failure
	elseif not Compat.IsAddOnLoaded(ADDON) then
		return "missing"
	elseif not api() then
		return "noApi"
	end
	return "working"
end

-- The auction price of one item, in copper, or nil.
function Integration.Price(link)
	if Integration.State() ~= "working" or type(link) ~= "string" then
		return nil
	end
	local ok, price = pcall(api().GetAuctionPriceByItemLink, CALLER, link)
	if not ok then
		failure = tostring(price)
		ns.Debug("Auctionator: its price call failed, auction prices are off: " .. failure)
		return nil
	end
	if type(price) == "number" and price >= 0 then
		return math.floor(price)
	end
	return nil
end

Prices.AddAuctionSource(Integration)

SelfTest.AddReport(function()
	local state, problem = Integration.State()
	local texts = {
		missing = "not installed",
		noApi = "loaded, but without API v1: prices come from merchants",
		working = "working",
	}
	return "Auctionator: " .. (texts[state] or ("off after an error: " .. tostring(problem)))
end)
