local _, ns = ...
local Bus, Compat = ns.Bus, ns.Compat

-- The player's bags and what is in them, read once per change: on first use,
-- and again on first use after a BAG_UPDATE_DELAYED, which also sends
-- InventoryChanged. What keeps an item from being tossed or sold (a quest, an
-- equipment set, a refund) is read only for the items that are asked about.
local Inventory = {}
ns.Inventory = Inventory

local scan
local listening = false

local function read()
	local bags, reagentBag = Compat.GetPlayerBags()
	local result = { bags = {}, items = {} }
	local function add(bag, reagent)
		local size = Compat.GetBagSize(bag)
		local free, family = Compat.GetBagFreeSlots(bag)
		result.bags[#result.bags + 1] = { bag = bag, size = size, free = free, family = family, reagent = reagent }
		for slot = 1, size do
			local item = Compat.GetBagItem(bag, slot)
			if item then
				item.bag, item.slot = bag, slot
				result.items[#result.items + 1] = item
			end
		end
	end
	for _, bag in ipairs(bags) do
		add(bag, false)
	end
	if reagentBag then
		add(reagentBag, true)
	end
	return result
end

local function current()
	if not listening then
		listening = true
		Bus:OnEvent("BAG_UPDATE_DELAYED", Inventory, function()
			scan = nil
			Bus:Send("InventoryChanged")
		end)
	end
	scan = scan or read()
	return scan
end

-- The bags in order, backpack first and the reagent bag last: { bag, size,
-- free, family, reagent }. family is 0 for a general bag; a bag slot without a
-- bag has size 0.
function Inventory.Bags()
	return current().bags
end

-- Every item in the bags, bag by bag and slot by slot, as Compat.GetBagItem
-- reads it, with its bag and slot. The records are shared: read them only.
function Inventory.Items()
	return current().items
end

-- An item's protections and its guid (Compat.GetBagItemFacts), read the first
-- time they are asked for.
function Inventory.Facts(item)
	item.facts = item.facts or Compat.GetBagItemFacts(item.bag, item.slot)
	return item.facts
end

-- Whether a bag slot still holds the item a list showed: the same guid, the
-- same count (a stack can grow and keep its guid), and not locked by a move or
-- a sale. Read from the client, not from the last scan.
function Inventory.StillThere(item)
	local now = Compat.GetBagItem(item.bag, item.slot)
	return now ~= nil and not now.locked and now.itemID == item.itemID and now.count == item.count
		and Compat.GetBagItemFacts(item.bag, item.slot).guid == Inventory.Facts(item).guid
end
