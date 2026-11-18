local _, ns = ...
local Marks = ns.Marks

-- What is junk: gray items, and items the player marked as junk, but no item
-- marked "not junk" (a gray one kept for transmog, or anything the player
-- does not want suggested). Every part that shows or sells junk asks here, so
-- they never disagree. An item is { itemID, quality }; quality is nil while
-- the client has not loaded the item, and such an item is junk only when
-- marked.
--
-- The sell window's decisions for this sale only ({ junk = { [itemID] =
-- true }, keep = { [itemID] = true } }) win over the marks while it is open.
ns.Rules = ns.Rules or {}
local Junk = {}
ns.Rules.Junk = Junk

-- Enum.ItemQuality.Poor.
Junk.POOR = 0

-- { junk = true or false, reason }: reason is "thisSale" or "keptThisSale"
-- (the sell window's decisions), "marked" (marked junk), "gray", "notJunk"
-- (marked not junk) or nil (any other item).
function Junk.Decide(item, thisSale)
	if thisSale then
		if thisSale.junk and thisSale.junk[item.itemID] then
			return { junk = true, reason = "thisSale" }
		elseif thisSale.keep and thisSale.keep[item.itemID] then
			return { junk = false, reason = "keptThisSale" }
		end
	end
	local mark = Marks.Get(item.itemID)
	if mark == "junk" then
		return { junk = true, reason = "marked" }
	elseif mark == "notJunk" then
		return { junk = false, reason = "notJunk" }
	elseif item.quality == Junk.POOR then
		return { junk = true, reason = "gray" }
	end
	return { junk = false }
end

-- Junk for good. A gray item only loses its "not junk" mark, as being gray
-- makes it junk.
function Junk.MarkJunk(item)
	if item.quality == Junk.POOR then
		Marks.Set(item.itemID, nil)
	else
		Marks.Set(item.itemID, "junk")
	end
end

-- Not junk for good: marked "not junk", so it is neither junk nor suggested.
function Junk.MarkNotJunk(item)
	Marks.Set(item.itemID, "notJunk")
end
