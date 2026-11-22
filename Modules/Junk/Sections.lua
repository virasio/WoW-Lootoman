local _, ns = ...
local Compat, Inventory, L, Marks, Prices, SelfTest, Text = ns.Compat, ns.Inventory, ns.L, ns.Marks, ns.Prices, ns.SelfTest, ns.Text
local JunkRule, Suggest = ns.Rules.Junk, ns.Rules.Suggest

-- The sections of the junk window, from the bags as they are:
--   junk       gray and marked items (and, selling, what the player
--              sent there for this sale), the ones a quest in the log still
--              wants last, as a hint (entry.hint);
--   suggested  what the suggestion rules find (Rules.Suggest), by rule;
--   rest       everything else, by kind of item (the client's class names).
-- Each list is sorted by price, cheapest first, so what is least worth
-- keeping comes first; equal prices sort by name, then by bag and slot, so the
-- order never jumps.
--
-- kind "toss": the price is what deleting loses (Prices.Worth). Items in
-- equipment sets are not listed.
-- kind "sell": the price is the merchant's (Prices.Vendor). Also left out:
-- refundable items and items no merchant buys.
--
-- An entry: { item (an Inventory record), price, decision (Rules.Junk.Decide),
-- kept: its bag is left out of junk selling, suggestion (Rules.Suggest.Find),
-- hint (junk a quest still wants) }.
local Junk = ns.Modules:Get("Junk")
local Sections = {}
Junk.Sections = Sections

-- The rules' switches (module settings) by rule.
Sections.SWITCHES = {
	questDone = "suggestQuestDone",
	leftovers = "suggestLeftovers",
	unusable = "suggestUnusable",
	known = "suggestKnown",
	outgrown = "suggestOutgrown",
}

local function listed(kind, item)
	local facts = Inventory.Facts(item)
	if facts.equipmentSet then
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

-- Kinds of collection the "already known" rule counts; an appearance set not
-- collected yet is never suggested.
local KNOWN_COLLECTIONS = { pet = true, mount = true, toy = true, heirloom = true }

-- What the suggestion rules look at for a bag item (Rules/Suggest.lua).
function Sections.Facts(item, level)
	local info = Compat.GetItemInfo(item.link or item.itemID) or {}
	local use = Compat.GetBagItemUse(item.bag, item.slot) or {}
	local protections = Inventory.Facts(item)
	local collectible = Compat.GetCollectible(item.itemID)
	local facts = {
		mark = Marks.Get(item.itemID),
		equipmentSet = protections.equipmentSet,
		refundable = protections.refundable,
		uncollected = collectible ~= nil and not collectible.collected,
		collected = collectible ~= nil and collectible.collected and KNOWN_COLLECTIONS[collectible.kind] == true,
		quality = item.quality,
		bound = item.bound,
		equippable = Compat.IsEquippableItem(item.itemID),
		canUse = Compat.CanUseItem(item.itemID),
		requiredLevel = info.requiredLevel,
		classID = info.classID,
		subclassID = info.subclassID,
		isCraftingReagent = info.isCraftingReagent,
		level = level,
		startsQuest = use.questID,
		startsQuestDone = use.questID and Compat.IsQuestDone(use.questID) or false,
		questItem = use.questItem,
		recipeKnown = use.recipe == true and use.known == true,
		vendor = Prices.Vendor(item),
	}
	local auction = Prices.Auction(item)
	facts.auction = auction and math.floor(auction * (1 - Prices.AUCTION_CUT)) or nil
	local questie = ns.Integrations.QuestieDB
	local related = questie and questie.RelatedQuests(item.itemID) or nil
	if related then
		facts.related = related
		facts.relatedDone, facts.relatedActive = #related > 0, false
		for _, questID in ipairs(related) do
			facts.relatedDone = facts.relatedDone and Compat.IsQuestDone(questID) == true
			facts.relatedActive = facts.relatedActive or Compat.IsOnQuest(questID) == true
		end
	end
	local memory = Junk.QuestMemory
	if memory and item.name then
		facts.wantedByLog = memory.Wanted(item.name)
		facts.doneByMemory = memory.Done(item.name)
	end
	return facts
end

-- The rules' switches as Rules.Suggest.Find takes them.
function Sections.Enabled()
	local enabled = {}
	for rule, key in pairs(Sections.SWITCHES) do
		enabled[rule] = Junk:Get(key) ~= false
	end
	return enabled
end

-- A list of entries into groups by key, in the order of keys; empty groups left out.
local function grouped(byKey, keys, label)
	local groups = {}
	for _, key in ipairs(keys) do
		local entries = byKey[key]
		if entries and #entries > 0 then
			table.sort(entries, before)
			local total = 0
			for _, entry in ipairs(entries) do
				total = total + entry.price
			end
			groups[#groups + 1] = { key = key, name = label(key), entries = entries, total = total }
		end
	end
	return groups
end

-- { junk = { entries, hinted (how many of them, last), total },
--   suggested = { groups = { { key (the rule), entries, total } }, entries, total },
--   rest = { groups = { { key, name (the kind), entries, total } }, entries, total } }.
-- thisSale: the decisions for this sale while selling (Rules.Junk.Decide).
function Sections.Build(kind, thisSale)
	assert(kind == "toss" or kind == "sell", "the kind is toss or sell")
	local result = {
		junk = { entries = {}, hinted = 0, total = 0 },
		suggested = { groups = {}, entries = {}, total = 0 },
		rest = { groups = {}, entries = {}, total = 0 },
	}
	local kept, level, enabled = {}, Compat.GetPlayerLevel(), Sections.Enabled()
	local plain, hinted, byRule, byKind, kinds = {}, {}, {}, {}, {}
	for _, item in ipairs(Inventory.Items()) do
		if listed(kind, item) then
			if kept[item.bag] == nil then
				kept[item.bag] = Compat.IsBagKeptFromJunkSale(item.bag)
			end
			local decision = JunkRule.Decide(item, thisSale)
			local price = (kind == "sell" and Prices.Vendor(item) or Prices.Worth(item)) or 0
			local entry = { item = item, price = price, decision = decision, kept = kept[item.bag] }
			local facts = Sections.Facts(item, level)
			if decision.junk then
				entry.hint = Suggest.Hint(facts)
				table.insert(entry.hint and hinted or plain, entry)
				result.junk.total = result.junk.total + price
			else
				-- A decision of this sale or a mark keeps it from the suggestions.
				local suggestion
				if decision.reason == nil then
					suggestion = Suggest.Find(facts, enabled)
				end
				entry.suggestion = suggestion
				if suggestion then
					local rule = suggestion.rule
					byRule[rule] = byRule[rule] or {}
					table.insert(byRule[rule], entry)
					table.insert(result.suggested.entries, entry)
					result.suggested.total = result.suggested.total + price
				else
					local name = facts.classID and Compat.GetItemClassName(facts.classID) or nil
					name = name or L["Other"]
					if not byKind[name] then
						byKind[name] = {}
						kinds[#kinds + 1] = name
					end
					table.insert(byKind[name], entry)
					table.insert(result.rest.entries, entry)
					result.rest.total = result.rest.total + price
				end
			end
		end
	end
	table.sort(plain, before)
	table.sort(hinted, before)
	for _, entry in ipairs(plain) do
		table.insert(result.junk.entries, entry)
	end
	for _, entry in ipairs(hinted) do
		table.insert(result.junk.entries, entry)
	end
	result.junk.hinted = #hinted
	result.suggested.groups = grouped(byRule, Suggest.RULES, function(rule)
		return rule
	end)
	table.sort(kinds, function(a, b)
		return Text.FoldCase(a) < Text.FoldCase(b)
	end)
	result.rest.groups = grouped(byKind, kinds, function(name)
		return name
	end)
	table.sort(result.suggested.entries, before)
	table.sort(result.rest.entries, before)
	return result
end

-- Whether a listed item may still be sold as junk, asked again right before
-- its sale: still junk, by the sale's own decisions too (thisSale: what the
-- player moved for this sale only; the player may have moved it out of the
-- junk, or switched profiles), its bag not left out of junk selling, and
-- nothing that protects it now. Read from the client, not from the list.
function Sections.StillForSale(item, thisSale)
	local facts = Compat.GetBagItemFacts(item.bag, item.slot)
	return JunkRule.Decide(item, thisSale).junk and not Compat.IsBagKeptFromJunkSale(item.bag)
		and not facts.equipmentSet and not facts.refundable
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

-- For bug reports: the junk in the bags and the profile's marks.
SelfTest.AddReport(function()
	local sale, value = Sections.SaleList(), 0
	for _, entry in ipairs(sale) do
		value = value + entry.price
	end
	local kept = #Sections.Build("sell").junk.entries - #sale
	local marks = { junk = 0, notJunk = 0 }
	for _, mark in ipairs(Marks.List()) do
		marks[mark.mark] = marks[mark.mark] + 1
	end
	return ("Junk: %d stacks to sell for %d copper (%d in bags kept from junk selling); marks: %d junk, %d not junk"):format(
		#sale, value, kept, marks.junk, marks.notJunk)
end)
