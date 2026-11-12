local _, ns = ...
local Compat = ns.Compat

-- Which items the character can use right now, of the kinds the loot feed
-- keeps until the player lets them go: an item that starts a quest not taken
-- yet; a recipe the character can learn and does not know; a container it can
-- open (a locked box only once it is picked); a pet, mount, toy, appearance
-- set or heirloom not in its collection yet. Everything that disappears when
-- used. Each check reads the item's bag slot, so an item counts only once it
-- is in the bags.
ns.Rules = ns.Rules or {}
local Usable = {}
ns.Rules.Usable = Usable

-- The kinds, quest starters first: they are the reason for the rest.
Usable.KINDS = { "quest", "recipe", "container", "pet", "mount", "toy", "set", "heirloom" }

-- Kinds of collectible items (Compat.GetCollectible).
local COLLECTIONS = { pet = true, mount = true, toy = true, set = true, heirloom = true }

-- The kind of usable item in a bag slot, or nil.
function Usable.Kind(bag, slot)
	local use = Compat.GetBagItemUse(bag, slot)
	if not use then
		return nil
	elseif use.questID and not use.questTaken then
		return "quest"
	elseif use.recipe then
		return use.usable and not use.known and "recipe" or nil
	elseif use.openable and use.usable then
		return "container"
	end
	local collectible = Compat.GetCollectible(use.itemID)
	if collectible and not collectible.collected then
		return collectible.kind
	end
	return nil
end

-- The kind of usable item an item is, from the first bag slot that holds it,
-- and whether the bags hold it at all.
function Usable.Find(itemID)
	for _, item in ipairs(ns.Inventory.Items()) do
		if item.itemID == itemID then
			return Usable.Kind(item.bag, item.slot), true
		end
	end
	return nil, false
end

-- The kinds this client has: a collection it lacks is no kind here.
function Usable.Kinds()
	local collections, list = Compat.GetCollectionKinds(), {}
	for _, kind in ipairs(Usable.KINDS) do
		if not COLLECTIONS[kind] or collections[kind] then
			list[#list + 1] = kind
		end
	end
	return list
end
