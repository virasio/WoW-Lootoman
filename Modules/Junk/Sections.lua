local _, ns = ...
local Compat, Inventory, Prices, Text = ns.Compat, ns.Inventory, ns.Prices, ns.Text
local JunkRule = ns.Rules.Junk

-- The two sections of the toss and sell windows, from the bags as they are:
-- the junk, and everything else. Each is sorted by price, cheapest first, so
-- what is least worth keeping comes first; equal prices sort by name, then by
-- bag and slot, so the order never jumps.
--
-- kind "toss": the price is what deleting loses (Prices.Worth). Quest items and
-- items in equipment sets are not listed.
-- kind "sell": the price is the merchant's (Prices.Vendor). Also left out:
-- refundable items and items no merchant buys.
--
-- An entry: { item (an Inventory record), price, decision (Rules.Junk.Decide),
-- kept: its bag is left out of junk selling }.
local Junk = ns.Modules:Get("Junk")
local Sections = {}
Junk.Sections = Sections

local function listed(kind, item)
	local facts = Inventory.Facts(item)
	if facts.quest or facts.equipmentSet then
		return false
	end
	return kind ~= "sell" or (not facts.refundable and Prices.Vendor(item) ~= nil)
end

local function before(a, b)
	if a.price ~= b.price then
		return a.price < b.price
	end
	local nameA, nameB = Text.FoldCase(a.item.name or ""), Text.FoldCase(b.item.name or "")
	if nameA ~= nameB then
		return nameA < nameB
	end
	if a.item.bag ~= b.item.bag then
		return a.item.bag < b.item.bag
	end
	return a.item.slot < b.item.slot
end

-- { junk = { entries, total }, rest = { entries, total } }.
function Sections.Build(kind)
	assert(kind == "toss" or kind == "sell", "the kind is toss or sell")
	local result = { junk = { entries = {}, total = 0 }, rest = { entries = {}, total = 0 } }
	local kept = {}
	for _, item in ipairs(Inventory.Items()) do
		if listed(kind, item) then
			if kept[item.bag] == nil then
				kept[item.bag] = Compat.IsBagKeptFromJunkSale(item.bag)
			end
			local decision = JunkRule.Decide(item)
			local price = (kind == "sell" and Prices.Vendor(item) or Prices.Worth(item)) or 0
			local section = decision.junk and result.junk or result.rest
			section.entries[#section.entries + 1] = { item = item, price = price, decision = decision, kept = kept[item.bag] }
			section.total = section.total + price
		end
	end
	table.sort(result.junk.entries, before)
	table.sort(result.rest.entries, before)
	return result
end

-- The junk the sell-junk button and a merchant's opening sell: junk the
-- merchant buys, outside the bags left out of junk selling.
function Sections.SaleList()
	local list = {}
	for _, entry in ipairs(Sections.Build("sell").junk.entries) do
		if not entry.kept then
			list[#list + 1] = entry
		end
	end
	return list
end
