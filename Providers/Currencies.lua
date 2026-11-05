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

-- How many of an item the bags and the reagent bag hold.
function Currencies.ItemCount(itemID)
	return Compat.GetBagItemCount(itemID)
end

-- From now on, a change of a currency sends CurrenciesChanged(currencyID).
function Currencies.Watch()
	Bus:OnEvent("CURRENCY_DISPLAY_UPDATE", Currencies, function(_, currencyID)
		Bus:Send("CurrenciesChanged", currencyID)
	end)
end
