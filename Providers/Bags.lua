local _, ns = ...
local Bus, Compat = ns.Bus, ns.Compat

-- Free space in the player's bags (techspec §3): free slots per bag type, and
-- whether a looted stack fits. The bags are read on first use and read again
-- after the next BAG_UPDATE_DELAYED.
local Bags = {}
ns.Bags = Bags

local cache
local listening = false

-- True when two bag families share a bit. Lua 5.1 has no bit operators, and the
-- game's bit library does not exist in tests.
local function sharesFamily(a, b)
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then
			return true
		end
		a, b = math.floor(a / 2), math.floor(b / 2)
	end
	return false
end

local function read()
	local bags, reagentBag = Compat.GetPlayerBags()
	local result = { bags = {}, stacks = {} }
	local function add(bag, reagent)
		local free, family = Compat.GetBagFreeSlots(bag)
		result.bags[#result.bags + 1] = { free = free, family = family, reagent = reagent }
		for slot = 1, Compat.GetBagSize(bag) do
			local item = Compat.GetBagItem(bag, slot)
			if item then
				local stacks = result.stacks[item.itemID] or {}
				stacks[#stacks + 1] = item.count
				result.stacks[item.itemID] = stacks
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
		Bus:OnEvent("BAG_UPDATE_DELAYED", "Bags", function()
			cache = nil
		end)
	end
	cache = cache or read()
	return cache
end

-- { total, general, reagent, families = { [bag family] = free } }: general
-- counts the backpack and the bags of family 0, families the profession bags.
function Bags.FreeSlots()
	local slots = { total = 0, general = 0, reagent = 0, families = {} }
	for _, bag in ipairs(current().bags) do
		slots.total = slots.total + bag.free
		if bag.reagent then
			slots.reagent = slots.reagent + bag.free
		elseif bag.family == 0 then
			slots.general = slots.general + bag.free
		else
			slots.families[bag.family] = (slots.families[bag.family] or 0) + bag.free
		end
	end
	return slots
end

-- Whether a looted stack of an item (ID or link) fits: into partial stacks of
-- the same item, a free slot in a general bag, in a profession bag of its
-- family or, for crafting reagents, in the reagent bag. An item the client has
-- not loaded yet counts as a single item that fits only a general bag.
function Bags.Fits(item, count)
	count = count or 1
	local bags = current()
	local itemID = type(item) == "string" and tonumber(item:match("item:(%d+)")) or item
	local info = Compat.GetItemInfo(item)
	local stackSize = info and info.stackSize or 1

	local room = 0
	for _, stack in ipairs(itemID and bags.stacks[itemID] or {}) do
		room = room + math.max(0, stackSize - stack)
	end
	if room >= count then
		return true
	end

	local family = info and Compat.GetItemFamily(item) or 0
	for _, bag in ipairs(bags.bags) do
		if bag.free > 0 then
			if bag.reagent then
				if info and info.isCraftingReagent then
					return true
				end
			elseif bag.family == 0 or sharesFamily(family, bag.family) then
				return true
			end
		end
	end
	return false
end
