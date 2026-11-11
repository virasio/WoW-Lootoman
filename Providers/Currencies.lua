local _, ns = ...
local Bus, Compat = ns.Bus, ns.Compat

-- The character's currencies and the counts of items in the bags, for the
-- currency bars. Read when asked; after Watch(), CURRENCY_DISPLAY_UPDATE sends
-- CurrenciesChanged.
local Currencies = {}
ns.Currencies = Currencies

-- A currency as Compat.GetCurrencyInfo has it, with atCap: it has a cap and
-- has reached it (for a seasonal cap, what was earned this season counts).
function Currencies.Info(currencyID)
	local info = Compat.GetCurrencyInfo(currencyID)
	if not info then
		return nil
	end
	local counted = info.capsTotalEarned and info.totalEarned or info.quantity
	info.atCap = info.max > 0 and counted >= info.max
	return info
end

-- Every currency of the character's currency list.
function Currencies.IDs()
	return Compat.GetCurrencyIDs()
end

-- The currencies the player shows on the backpack, in their order.
function Currencies.Backpack()
	return Compat.GetBackpackCurrencyIDs()
end

-- How many of an item there are in the bags (with the reagent bag), the bank
-- and the warband bank: { bags, bank, warband }.
function Currencies.ItemCounts(itemID)
	return Compat.GetItemCounts(itemID)
end

-- What an entry on a bar counts: "bags" (the default, the bags and the reagent
-- bag), "banks" (the bank and the warband bank) or "all" (both).
Currencies.COUNTS = { bags = true, banks = true, all = true }

-- How many of an item there are where count says.
function Currencies.ItemCount(itemID, count)
	if count == "banks" or count == "all" then
		local counts = Compat.GetItemCounts(itemID)
		local banks = counts.bank + counts.warband
		return count == "all" and counts.bags + banks or banks
	end
	return Compat.GetBagItemCount(itemID)
end

-- From now on, a change of a currency sends CurrenciesChanged(currencyID).
function Currencies.Watch()
	Bus:OnEvent("CURRENCY_DISPLAY_UPDATE", Currencies, function(_, currencyID)
		Bus:Send("CurrenciesChanged", currencyID)
	end)
end
