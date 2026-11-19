local _, ns = ...
local Compat, Marks, Prices = ns.Compat, ns.Marks, ns.Prices

-- /ltm debug junk <link or ID>: why an item is junk or not, in English as all
-- debug output: the junk rule's decision and the item's mark, for an item in
-- the bags the suggestion rule and the quest hint, the kind of usable item it
-- is, and its prices. The rules sit below the junk module, so it works with
-- junk management off.
local Junk = ns.Modules:Get("Junk")

local REASONS = { gray = "gray", marked = "marked junk", notJunk = "marked not junk" }

-- What a suggestion says beside its rule.
local function details(found)
	local parts = {}
	for key, value in pairs(found) do
		if key ~= "rule" then
			parts[#parts + 1] = key .. " " .. tostring(value)
		end
	end
	table.sort(parts)
	return #parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or ""
end

ns.Slash.RegisterDebug("junk", function(argument)
	local itemID = tonumber(argument:match("item:(%d+)") or argument:match("^%s*(%d+)%s*$"))
	if not itemID then
		ns.Print("/ltm debug junk takes an item's link or ID.")
		return
	end
	local info = Compat.GetItemInfo(itemID)
	if not info then
		Compat.RequestItem(itemID)
		ns.Print(("debug junk: item %d is not loaded yet; try again in a moment."):format(itemID))
		return
	end
	local decision = ns.Rules.Junk.Decide({ itemID = itemID, quality = info.quality })
	ns.Print(("debug junk: %s (item %d), quality %s"):format(tostring(info.link or info.name), itemID, tostring(info.quality)))
	ns.Print(("  Junk: %s%s; mark %s"):format(decision.junk and "yes" or "no",
		decision.reason and (", " .. (REASONS[decision.reason] or decision.reason)) or "", tostring(Marks.Get(itemID) or "none")))
	local held = {}
	for _, item in ipairs(ns.Inventory.Items()) do
		if item.itemID == itemID then
			held[#held + 1] = item
		end
	end
	local item = held[1] or { itemID = itemID, link = info.link, count = 1, quality = info.quality }
	if #held == 0 then
		ns.Print("  In the bags: no; suggestions look only at what the bags hold")
	else
		local places = {}
		for _, stack in ipairs(held) do
			places[#places + 1] = ("bag %d slot %d ×%d"):format(stack.bag, stack.slot, stack.count or 1)
		end
		ns.Print("  In the bags: " .. table.concat(places, ", "))
		local facts = Junk.Sections.Facts(item, Compat.GetPlayerLevel())
		local found = ns.Rules.Suggest.Find(facts, Junk.Sections.Enabled())
		ns.Print(("  Suggested: %s; a quest in the log wants it: %s"):format(found and (found.rule .. details(found)) or "no",
			ns.Rules.Suggest.Hint(facts) and "yes" or "no"))
	end
	local kind = ns.Rules.Usable.Find(itemID)
	ns.Print(("  Usable now: %s"):format(kind or "no"))
	ns.Print(("  Prices, copper: merchant %s, auction %s, worth %s"):format(tostring(Prices.Vendor(item) or "none"),
		tostring(Prices.Auction(item) or "none"), tostring(Prices.Worth(item))))
end, "/ltm debug junk <link or ID>: why an item is junk or not, and its prices")
