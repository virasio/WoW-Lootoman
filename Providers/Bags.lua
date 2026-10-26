local _, ns = ...
local Bus, Compat, SelfTest = ns.Bus, ns.Compat, ns.SelfTest

-- Free space in the player's bags: whether the stacks of a loot fit. The bags
-- are read on first use and read again after the next BAG_UPDATE_DELAYED.
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

-- The self-test lists every equipped bag with its family as the client gives
-- it: the family bits are known from the community, not from Blizzard, so
-- they are checked in game before anything names them.
SelfTest.AddReport(function()
	local bags, reagentBag = Compat.GetPlayerBags()
	local parts = {}
	local function describe(bag, label)
		local size = Compat.GetBagSize(bag)
		if size > 0 then
			local free, family = Compat.GetBagFreeSlots(bag)
			parts[#parts + 1] = ("%s%d (%d slots, %d free%s)"):format(label, bag, size, free,
				family ~= 0 and (", family " .. family) or "")
		end
	end
	for _, bag in ipairs(bags) do
		describe(bag, "")
	end
	if reagentBag then
		describe(reagentBag, "reagent ")
	end
	return "Bags: " .. (#parts > 0 and table.concat(parts, ", ") or "none")
end)

-- The space of one loot: the bags as they are now, minus what the items taken
-- before in the same plan need, so two items never count on the same free
-- slot or the same room in a stack.
--
--   local plan = Bags.Plan()
--   plan:Take(link, 3)   -- true, and the space is reserved; false if it does not fit
local PlanMixin = {}
PlanMixin.__index = PlanMixin

function Bags.Plan()
	local bags = current()
	local plan = setmetatable({ bags = bags.bags, free = {}, stacks = {} }, PlanMixin)
	for index, bag in ipairs(bags.bags) do
		plan.free[index] = bag.free
	end
	for itemID, stacks in pairs(bags.stacks) do
		plan.stacks[itemID] = { unpack(stacks) }
	end
	return plan
end

-- Whether a looted stack of an item (ID or link) fits, and if so its space is
-- reserved. The stack first fills partial stacks of the same item; what is
-- left needs a free slot per stack, taken from the most specific bags first,
-- as the game puts items: a profession bag of the item's family, the reagent
-- bag for crafting reagents, then general bags. An item the client has not
-- loaded yet counts as one stack that only a general bag takes.
function PlanMixin:Take(item, count)
	count = count or 1
	local itemID = type(item) == "string" and tonumber(item:match("item:(%d+)")) or item
	local info = Compat.GetItemInfo(item)
	local stackSize = math.max(info and info.stackSize or count, 1)
	local stacks = info and itemID and self.stacks[itemID] or {}

	local left, fills = count, {}
	for index, stack in ipairs(stacks) do
		local put = math.min(math.max(0, stackSize - stack), left)
		if put > 0 then
			fills[index], left = put, left - put
		end
	end

	local needed = math.ceil(left / stackSize)
	local family = info and Compat.GetItemFamily(item) or 0
	local reagent = info and info.isCraftingReagent
	local taken, found = {}, 0
	local function take(accepts)
		for index, bag in ipairs(self.bags) do
			if found < needed and accepts(bag) then
				local use = math.min(self.free[index] - (taken[index] or 0), needed - found)
				taken[index], found = (taken[index] or 0) + use, found + use
			end
		end
	end
	take(function(bag) return not bag.reagent and bag.family ~= 0 and sharesFamily(family, bag.family) end)
	take(function(bag) return bag.reagent and reagent end)
	take(function(bag) return not bag.reagent and bag.family == 0 end)
	if found < needed then
		return false
	end

	for index, use in pairs(taken) do
		self.free[index] = self.free[index] - use
	end
	if info and itemID then
		self.stacks[itemID] = stacks
		for index, put in pairs(fills) do
			stacks[index] = stacks[index] + put
		end
		for stack = 1, needed do
			stacks[#stacks + 1] = stack < needed and stackSize or left - (needed - 1) * stackSize
		end
	end
	return true
end
