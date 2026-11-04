local _, ns = ...
local Bus, Compat = ns.Bus, ns.Compat

-- Prices of a bag item's whole stack (an Inventory record), in copper: what a
-- merchant pays, and what the auction house would. Auction prices come from
-- the integrations that add themselves (Auctionator). Prices are read when they
-- are asked for; after the auction house closes, PricesChanged tells open
-- windows that auction prices may be new.
local Prices = {}
ns.Prices = Prices

-- The auction house keeps this share of a sale.
Prices.AUCTION_CUT = 0.05

local sources = {}
local listening = false

-- An integration's auction prices: source.Price(link) returns the price of one
-- item in copper, or nil. The first source with a price is used.
function Prices.AddAuctionSource(source)
	sources[#sources + 1] = source
end

local function listen()
	if not listening then
		listening = true
		Bus:OnEvent("AUCTION_HOUSE_CLOSED", Prices, function()
			Bus:Send("PricesChanged")
		end)
	end
end

-- What a merchant pays for the stack, or nil when no merchant buys it.
function Prices.Vendor(item)
	if item.noValue then
		return nil
	end
	local info = Compat.GetItemInfo(item.link or item.itemID)
	local each = info and info.sellPrice
	if type(each) ~= "number" or each <= 0 then
		return nil
	end
	return each * item.count
end

-- The stack's auction price before the auction house's cut, or nil. A bound
-- item cannot be sold there, whatever the auction house asks for another copy.
function Prices.Auction(item)
	if item.bound then
		return nil
	end
	listen()
	for _, source in ipairs(sources) do
		local each = source.Price(item.link)
		if each then
			return each * item.count
		end
	end
	return nil
end

-- What deleting the stack loses: the better of selling it to a merchant and
-- selling it at the auction house after the cut; 0 without a price.
function Prices.Worth(item)
	local auction = Prices.Auction(item)
	return math.max(Prices.Vendor(item) or 0, auction and math.floor(auction * (1 - Prices.AUCTION_CUT)) or 0)
end
